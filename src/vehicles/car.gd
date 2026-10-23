class_name Car
extends Node3D
## A car of the Oststadt (doc/oststadt.md). Kinematic like the actors: an arcade bicycle
## model on the ParkMap. It drives only on drivable ground (streets, crossings, lots) and
## never into a person: it looks ahead along its way and brakes so that it stops in time;
## the last guard refuses any step that would touch somebody. Walls and other cars bounce
## it back softly. Driven by the player (driver), by the traffic (ai) or standing parked.
## The bumper cars of the Kirmes are cars too (kind "scooter"), driving in a closed rink, and so
## are the Möwenbucht's boats (spec "water": on the water only, bobbing, gliding on).

signal bumped(speed: float)

var kind := "small"
var spec := {}
var color := Color.WHITE
var world: World
var yaw := 0.0
var speed := 0.0                 # m/s along the heading (negative = reverse)
var steer := 0.0                 # current steering angle (radians)
var throttle_input := 0.0        # -1 (brake/reverse) .. 1 (gas)
var steer_input := 0.0           # -1 (left) .. 1 (right)
var max_speed_factor := 1.0      # a minigame or the AI may limit the top speed
var driver: Actor = null
var ai: RefCounted = null        # traffic agent (Traffic), sets the inputs
var job := ""                    # minigame vehicle ("taxi", "tow" …): only its job may use it
var locked := false              # nobody may get in (minigame props, the cinema's cars …)
var auto_braked := false         # the safety brake acted in the last step (HUD hint, tests)
var ignore: Car = null           # a car hanging on this one (tow truck) is no obstacle
var horn_time := 0.0
var base_y := 0.0                # ground height (the town is flat; the bumper rink is not at 0)
var arena := Rect2()             # a closed rink (bumper cars): drives only inside it
var arena_cars: Array[Node3D] = []   # the other cars in the rink (same size as this one)
var exit_hint := ""              # set: the driver can't get out (a ride), the toast says why
var mesh: MeshInstance3D
var far_mesh: MeshInstance3D     # the car without small details, beyond NEAR metres
var door: CarDoor
var _bump_cooldown := 0.0
var _stopped_time := 0.0
var held_time := 0.0             # seconds the driver has held the car still
var oars: Array[Node3D] = []     # a rowing boat's oars, a pedal boat's paddle wheel (they move with the speed)
var _stroke := 0.0

const SAFETY_MARGIN := 1.0       # metres kept to a person in front when stopping
const REST_AFTER := 3.0         # held still this long, the driver rests as on a bench
const NEAR := 45.0               # metres up to which the detailed car mesh is shown
const DODGE_RANGE := 9.0         # people this close in front of a fast car jump aside
const STEER_FADE := 20.0         # m/s at which the steering lock is halved (calmer at speed)


func setup(w: World, car_kind: String, col: Color, pos: Vector2, heading: float) -> void:
	world = w
	kind = car_kind
	spec = CarSpecs.spec(kind)
	color = col
	yaw = heading
	name = "Car_%s" % kind
	mesh = MeshInstance3D.new()
	mesh.mesh = CoastModels.boat(kind, col) if on_water() else CityModels.car(kind, col)
	add_child(mesh)
	if on_water():
		base_y = ParkLayout.WATER_Y - 0.08
		mesh.visibility_range_end = 170.0
		mesh.visibility_range_end_margin = 10.0
		oars = CoastModels.boat_parts(self, kind)
		add_to_group("bobbing")
	elif kind != "scooter":
		# Near the full car, further away the one without small details.
		mesh.visibility_range_end = NEAR
		far_mesh = MeshInstance3D.new()
		far_mesh.mesh = CityModels.car(kind, col, true)
		far_mesh.visibility_range_begin = NEAR
		far_mesh.visibility_range_end = 170.0
		far_mesh.visibility_range_end_margin = 10.0
		add_child(far_mesh)
	else:
		mesh.visibility_range_end = 170.0
		mesh.visibility_range_end_margin = 10.0
	door = CarDoor.new()
	door.car = self
	door.radius = length() * 0.5 + 1.4
	add_child(door)
	_set_pose(pos, heading)
	set_physics_process(false)


func length() -> float:
	return spec["length"]


## A boat (CarSpecs "water"): drives on the sea only.
func on_water() -> bool:
	return spec.get("water", false)


func width() -> float:
	return spec["width"]


func pos2() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func forward2(h := NAN) -> Vector2:
	var a := yaw if is_nan(h) else h
	return Vector2(sin(a), cos(a))


## Right-hand side of the heading (right-hand traffic: the lane is on this side).
static func right_of(fwd: Vector2) -> Vector2:
	return Vector2(-fwd.y, fwd.x)


## Puts the car somewhere (jobs, tests): the town sorts its cars again.
func place(p: Vector2, heading: float) -> void:
	_set_pose(p, heading)
	if world and world.city:
		world.city.moved_by_hand()


## Driving moves within a metre per frame: the town's car grid of this frame stays good enough.
func _set_pose(p: Vector2, heading: float) -> void:
	yaw = heading
	global_position = Vector3(p.x, base_y, p.y)
	rotation.y = yaw


func is_standing() -> bool:
	return absf(speed) < 0.6


## The driver has held the car still for REST_AFTER seconds: sitting, so fatigue recovers.
func resting() -> bool:
	return driver != null and held_time >= REST_AFTER


func is_parked() -> bool:
	return driver == null and ai == null


## Whether `actor` may get in now.
func can_enter(actor: Actor) -> bool:
	return actor.is_human() and driver == null and not locked and is_standing() and actor.vehicle == null


## The largest effective steering angle at the current speed (the AI scales its input by it).
func max_turn() -> float:
	return float(spec["steer"]) / (1.0 + absf(speed) / STEER_FADE)


func set_input(throttle: float, steering: float) -> void:
	throttle_input = clampf(throttle, -1.0, 1.0)
	steer_input = clampf(steering, -1.0, 1.0)
	if absf(throttle_input) > 0.01 or not is_standing():
		set_physics_process(true)


## Wakes the car up (driver or AI took over).
func activate() -> void:
	set_physics_process(true)


# --- Geometry ------------------------------------------------------------------------

## The four corners of the footprint at a pose (grown by `margin`).
func corners(p: Vector2, h: float, margin := 0.0) -> PackedVector2Array:
	var f := forward2(h) * (length() * 0.5 + margin)
	var r := right_of(forward2(h)) * (width() * 0.5 + margin)
	return PackedVector2Array([p + f + r, p + f - r, p - f - r, p - f + r])


## True if q lies within the footprint grown by `margin`.
func contains(q: Vector2, margin := 0.0) -> bool:
	var d := q - pos2()
	var f := forward2()
	return absf(d.dot(f)) <= length() * 0.5 + margin and absf(d.dot(right_of(f))) <= width() * 0.5 + margin


## Separating axis test of two car footprints.
static func overlap(a_pos: Vector2, a_yaw: float, a_size: Vector2, b_pos: Vector2, b_yaw: float, b_size: Vector2) -> bool:
	var af := Vector2(sin(a_yaw), cos(a_yaw))
	var bf := Vector2(sin(b_yaw), cos(b_yaw))
	var axes := [af, right_of(af), bf, right_of(bf)]
	var d := b_pos - a_pos
	for ax: Vector2 in axes:
		var ra := absf(af.dot(ax)) * a_size.y * 0.5 + absf(right_of(af).dot(ax)) * a_size.x * 0.5
		var rb := absf(bf.dot(ax)) * b_size.y * 0.5 + absf(right_of(bf).dot(ax)) * b_size.x * 0.5
		if absf(d.dot(ax)) > ra + rb:
			return false
	return true


func size2() -> Vector2:
	return Vector2(width(), length())


## Ground, obstacles, other cars and people at a pose. Returns "" when free, otherwise
## "wall", "car" or "person".
func pose_blocked(p: Vector2, h: float) -> String:
	var f := forward2(h)
	var r := right_of(f)
	var hl := length() * 0.5
	var hw := width() * 0.5
	for k: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var q := p + f * hl * k.x + r * hw * k.y
		if arena.has_area():
			if not arena.has_point(q):
				return "wall"
		elif not (CoastMap.sailable(world.map, q) if on_water() else world.map.is_drivable(q)):
			return "wall"
	for other: Node3D in arena_cars:
		if overlap(p, h, size2(), Vector2(other.position.x, other.position.z), other.rotation.y, size2()):
			return "car"
	if on_water() and world.coast:
		for other: Car in world.coast.boats:
			if other != self and other.pos2().distance_to(p) < 6.0 and overlap(p, h, size2(), other.pos2(), other.yaw, other.size2()):
				return "car"
	elif world.city:
		for other: Car in world.city.cars_near(p, 10.0):
			if other == self or other == ignore or other.ignore == self:
				continue
			if overlap(p, h, size2(), other.pos2(), other.yaw, other.size2()):
				return "car"
	for a in world.actors_near(Vector3(p.x, 0.0, p.y), 7.0):
		if a.vehicle != null or a == driver or not _in_arena(a):
			continue
		var d := Vector2(a.global_position.x, a.global_position.z) - p
		if absf(d.dot(f)) <= hl + a.radius and absf(d.dot(r)) <= hw + a.radius:
			return "person"
	return ""


## People outside a rink (watching the bumper cars) are not in its way.
func _in_arena(a: Actor) -> bool:
	return not arena.has_area() or arena.has_point(Vector2(a.global_position.x, a.global_position.z))


## Free distance in front of the car (behind it when reversing) up to the nearest person
## in its way, or INF. People within `dodge` metres in front of a fast player car jump aside.
func gap_to_people(reverse: bool) -> float:
	var f := forward2()
	var r := right_of(f)
	var p := pos2()
	var hl := length() * 0.5
	var corridor := width() * 0.5 + 0.55
	var best := INF
	var dodge := driver != null and absf(speed) > 2.5
	for a in world.actors_near(global_position, 30.0):
		if a.vehicle != null or a == driver or not _in_arena(a):
			continue
		var d := Vector2(a.global_position.x, a.global_position.z) - p
		var along := d.dot(f) * (-1.0 if reverse else 1.0)
		var side := d.dot(r)
		if along < hl - 0.3 or absf(side) > corridor + a.radius + absf(steer) * along * 0.5:
			continue
		var gap := along - hl - a.radius
		best = minf(best, gap)
		if dodge and gap < DODGE_RANGE and not a.controlled:
			a.dodge(Vector3(f.x, 0, f.y) * (-1.0 if reverse else 1.0), signf(side) if absf(side) > 0.05 else 1.0)
	return best


# --- Driving ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null:
		return
	if ai and driver == null:
		ai.call("drive", self, delta)
	_drive(delta)
	if driver:
		carry_driver()
	horn_time = maxf(0.0, horn_time - delta)
	_bump_cooldown = maxf(0.0, _bump_cooldown - delta)
	held_time = held_time + delta if driver and is_standing() else 0.0
	# Parked and still: sleep until somebody drives again.
	if driver == null and ai == null and is_standing() and absf(throttle_input) < 0.01:
		_stopped_time += delta
		if _stopped_time > 0.5:
			speed = 0.0
			set_physics_process(false)
	else:
		_stopped_time = 0.0


func _drive(delta: float) -> void:
	var sp := spec
	var top: float = sp["max"] * max_speed_factor
	# Wheels turn in at 3.2 rad/s and come back more than twice as fast (letting go of the
	# stick straightens the car without counter-steering).
	var want := steer_input * float(sp["steer"])
	var back := absf(want) < absf(steer) or want * steer < 0.0
	steer = move_toward(steer, want, delta * (7.5 if back else 3.2))
	var t := throttle_input
	if t > 0.05:
		if speed < -0.3:
			speed = move_toward(speed, 0.0, float(sp["brake"]) * delta)
		else:
			speed = minf(top, speed + float(sp["accel"]) * t * delta * (1.0 - 0.5 * clampf(speed / top, 0.0, 1.0)))
	elif t < -0.05:
		if speed > 0.3:
			speed = move_toward(speed, 0.0, float(sp["brake"]) * -t * delta)
		else:
			speed = maxf(-float(sp["reverse"]), speed - float(sp["accel"]) * 0.6 * -t * delta)
	else:
		speed = move_toward(speed, 0.0, float(sp.get("drag", 1.8)) * delta)
	if speed > top:
		speed = move_toward(speed, top, float(sp["brake"]) * delta)
	# Safety brake: stop in time before anybody in the way.
	auto_braked = false
	if absf(speed) > 0.05:
		var gap := gap_to_people(speed < 0.0)
		if gap < INF:
			var allowed := sqrt(2.0 * float(sp["brake"]) * maxf(0.0, gap - SAFETY_MARGIN))
			if absf(speed) > allowed:
				auto_braked = true
				speed = signf(speed) * maxf(allowed, absf(speed) - float(sp["brake"]) * 1.5 * delta)
	if on_water():
		_row(delta)
	if absf(speed) < 0.01:
		if on_water() and absf(steer_input) > 0.05:
			_turn_on_the_spot(delta)
		return
	var eff := steer / (1.0 + absf(speed) / STEER_FADE)
	# Positive steer turns right: yaw grows to the left (yaw 0 faces +z, PI/2 faces +x).
	var new_yaw := yaw - speed * tan(eff) / float(sp["wheelbase"]) * delta
	if on_water():
		# Paddling turns a slow boat round, too.
		new_yaw -= steer_input * float(sp["turn"]) * delta * (1.0 - clampf(absf(speed) / top, 0.0, 1.0))
	var p := pos2()
	var step := speed * delta
	var np := p + forward2(new_yaw) * step
	var hit := pose_blocked(np, new_yaw)
	if hit == "":
		_set_pose(np, new_yaw)
		return
	# Arcade: a glancing hit deflects the car along the wall or car (the player's car only;
	# the traffic keeps its lanes).
	if hit != "person" and driver and _glance(p, new_yaw, step, delta):
		return
	# Slide: keep the old heading, or only turn.
	var np2 := p + forward2() * step
	if hit != "person" and pose_blocked(np2, yaw) == "":
		_set_pose(np2, yaw)
		return
	if pose_blocked(p, new_yaw) == "":
		_set_pose(p, new_yaw)
	if hit == "person":
		auto_braked = true
		speed = 0.0
		return
	_bump(hit)


## A standing boat turns on the spot while the driver steers.
func _turn_on_the_spot(delta: float) -> void:
	var nh := yaw - steer_input * float(spec["turn"]) * delta
	if pose_blocked(pos2(), nh) == "":
		_set_pose(pos2(), nh)


## The oars sweep (the paddle wheel turns) with the boat's speed and the driver's pedalling.
func _row(delta: float) -> void:
	if oars.is_empty():
		return
	var effort := maxf(absf(throttle_input), absf(steer_input) * 0.6) if driver else 0.0
	_stroke += delta * (absf(speed) * 1.6 + effort * 2.5) * (signf(speed) if absf(speed) > 0.1 else 1.0)
	CoastModels.move_boat_parts(oars, kind, _stroke, effort > 0.05 or absf(speed) > 0.2)


## Angles (degrees) a glancing hit may deflect the car by; steeper hits bump.
const GLANCE_ANGLES := [6.0, 12.0, 20.0, 28.0, 36.0, 42.0]
## Steeper deflections, only towards the side the player steers to.
const STEER_ANGLES := [55.0, 70.0, 85.0]
## How fast a glancing car turns parallel to what it touches (radians per second).
const GLANCE_TURN := 2.2


## Tries to go on along the obstacle: the move turned by a small angle (to the freer side,
## the steering side first), the car turning a little that way too. Costs a bit of speed.
## Steering into it also turns along steeper obstacles, backing off a few centimetres.
func _glance(p: Vector2, h: float, step: float, delta: float) -> bool:
	var dir := signf(speed) if absf(speed) > 0.001 else 1.0
	var steering := absf(steer_input) > 0.3
	# Positive steering turns right (yaw down) going forward, the other way reversing.
	var side := -signf(steer_input) * dir if steering else 1.0
	var tries := []
	for deg: float in GLANCE_ANGLES:
		tries.append([deg, side])
		if not steering:
			tries.append([deg, -side])   # steering picks the side
	if steering:
		for deg: float in STEER_ANGLES:
			tries.append([deg, side])
	for t: Array in tries:
		var a := deg_to_rad(t[0])
		var s: float = t[1]
		var nh := h + s * minf(a, GLANCE_TURN * delta)
		var np := _about_rear_axle(p, h, nh) + forward2(h + s * a) * step * cos(a)
		if pose_blocked(np, nh) != "":
			continue
		_set_pose(np, nh)
		var impact := absf(speed) * sin(a)
		speed -= speed * sin(a) * 3.0 * delta
		if impact > 3.0 and _bump_cooldown <= 0.0:
			_bump_cooldown = 0.6
			bumped.emit(impact)   # jobs count a hard scrape as a bump
			Sound.play("bump", global_position, -10.0)
		return true
	if steering:
		# Nose against it: pivot out, backing off a little while turning.
		# The front corner moves forward by half the width times the turn: back off a bit more.
		var turn := GLANCE_TURN * 0.5 * delta
		var nh := h + side * turn
		var np := _about_rear_axle(p, h, nh) - forward2(h) * dir * (width() * 0.5 * turn + 0.02)
		if pose_blocked(np, nh) == "":
			_set_pose(np, nh)
			speed *= 0.5
			return true
	return false


## Where the car's centre goes when it turns from h to nh about its rear axle (like a car,
## so the tail does not swing into the curb).
func _about_rear_axle(p: Vector2, h: float, nh: float) -> Vector2:
	var axle := length() * 0.3
	return p - forward2(h) * axle + forward2(nh) * axle


func _bump(what: String) -> void:
	var hard := absf(speed)
	if hard > 2.5 and _bump_cooldown <= 0.0:
		_bump_cooldown = 0.6
		bumped.emit(hard)
		Sound.play("bump", global_position, -2.0 if hard > 6.0 else -8.0)
		if driver and driver.controlled and UI.game:
			UI.game.camera.shake(clampf(hard / 20.0, 0.1, 0.5))
	speed = -speed * 0.25 if hard > 2.5 else 0.0
	if what == "car":
		speed *= 0.5


## Keeps the driver (the player's actor) at the driver's seat.
func carry_driver() -> void:
	var f := forward2()
	var seat := pos2()
	var facing := yaw
	if kind == "scooter":
		seat += f * -0.35
	elif kind == "rowboat":
		seat += f * 0.15
		facing = yaw + PI   # rowers look back over the stern
	elif kind == "pedalo":
		seat += right_of(f) * -0.34 + f * -0.2
	elif spec["open"]:
		seat += right_of(f) * -width() * 0.22 + f * (-0.1 if kind != "kart" else -0.15)
	driver.global_position = Vector3(seat.x, global_position.y + seat_height(), seat.y)
	driver.yaw = facing
	driver.rotation.y = facing
	driver.velocity = Vector3(f.x, 0, f.y) * speed


## Hip height of the driver above the ground (open cars show the driver sitting).
func seat_height() -> float:
	match kind:
		"kart": return 0.12
		"scooter": return 0.3
		"pedalo": return 0.44
		"rowboat": return 0.4
	return 0.45


## Honk: people nearby turn round, animals jump.
func honk() -> void:
	if horn_time > 0.0:
		return
	horn_time = 0.8
	Sound.play(horn_sound(), global_position)
	for a in world.actors_near(global_position, 12.0):
		if a == driver or a.controlled or a.vehicle:
			continue
		a.face(global_position)
		if a.is_human() and randf() < 0.4:
			a.say(VoiceLines.pick(a, VoiceLines.HONKED), 2.0)


## The horn's sound: a bought horn (car parts at the scrapyard) for the player.
func horn_sound() -> String:
	if on_water():
		return "bell"
	if driver and driver.controlled:
		match Items.tool_tier(driver.inventory, "horn"):
			1: return "horn_duck"
			2: return "horn_cucaracha"
			3: return "horn_fanfare"
	return "horn"

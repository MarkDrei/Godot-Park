class_name Car
extends Node3D
## A car of the Oststadt (doc/oststadt.md). Kinematic like the actors: an arcade bicycle
## model on the ParkMap. It drives only on drivable ground (streets, crossings, lots) and
## never into a person: it looks ahead along its way and brakes so that it stops in time;
## the last guard refuses any step that would touch somebody. Walls and other cars bounce
## it back softly. Driven by the player (driver), by the traffic (ai) or standing parked.

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
var mesh: MeshInstance3D
var door: CarDoor
var _bump_cooldown := 0.0
var _stopped_time := 0.0

const SAFETY_MARGIN := 1.0       # metres kept to a person in front when stopping
const DODGE_RANGE := 9.0         # people this close in front of a fast car jump aside


func setup(w: World, car_kind: String, col: Color, pos: Vector2, heading: float) -> void:
	world = w
	kind = car_kind
	spec = CarSpecs.spec(kind)
	color = col
	yaw = heading
	name = "Car_%s" % kind
	mesh = MeshInstance3D.new()
	mesh.mesh = CityModels.car(kind, col)
	mesh.visibility_range_end = 170.0
	mesh.visibility_range_end_margin = 10.0
	add_child(mesh)
	door = CarDoor.new()
	door.car = self
	door.radius = length() * 0.5 + 1.4
	add_child(door)
	place(pos, heading)
	set_physics_process(false)


func length() -> float:
	return spec["length"]


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


func place(p: Vector2, heading: float) -> void:
	yaw = heading
	global_position = Vector3(p.x, 0.0, p.y)
	rotation.y = yaw


func is_standing() -> bool:
	return absf(speed) < 0.6


func is_parked() -> bool:
	return driver == null and ai == null


## Whether `actor` may get in now.
func can_enter(actor: Actor) -> bool:
	return actor.is_human() and driver == null and not locked and is_standing() and actor.vehicle == null


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
		if not world.map.is_drivable(q):
			return "wall"
	if world.city:
		for other: Car in world.city.cars:
			if other == self or other == ignore or other.ignore == self or other.pos2().distance_squared_to(p) > 100.0:
				continue
			if overlap(p, h, size2(), other.pos2(), other.yaw, other.size2()):
				return "car"
	for a in world.actors:
		if a.inside or not a.visible or a.vehicle != null or a == driver:
			continue
		var d := Vector2(a.global_position.x, a.global_position.z) - p
		if d.length_squared() > 49.0:
			continue
		if absf(d.dot(f)) <= hl + a.radius and absf(d.dot(r)) <= hw + a.radius:
			return "person"
	return ""


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
	for a in world.actors:
		if a.inside or not a.visible or a.vehicle != null or a == driver:
			continue
		var d := Vector2(a.global_position.x, a.global_position.z) - p
		if d.length_squared() > 900.0:
			continue
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
		_carry_driver()
	horn_time = maxf(0.0, horn_time - delta)
	_bump_cooldown = maxf(0.0, _bump_cooldown - delta)
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
	steer = move_toward(steer, steer_input * float(sp["steer"]), delta * 2.6)
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
		speed = move_toward(speed, 0.0, 1.8 * delta)
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
	if absf(speed) < 0.01:
		return
	var eff := steer / (1.0 + absf(speed) / 11.0)
	# Positive steer turns right: yaw grows to the left (yaw 0 faces +z, PI/2 faces +x).
	var new_yaw := yaw - speed * tan(eff) / float(sp["wheelbase"]) * delta
	var p := pos2()
	var step := speed * delta
	var np := p + forward2(new_yaw) * step
	var hit := pose_blocked(np, new_yaw)
	if hit == "":
		place(np, new_yaw)
		return
	# Slide: keep the old heading, or only turn.
	var np2 := p + forward2() * step
	if hit != "person" and pose_blocked(np2, yaw) == "":
		place(np2, yaw)
		return
	if pose_blocked(p, new_yaw) == "":
		place(p, new_yaw)
	if hit == "person":
		auto_braked = true
		speed = 0.0
		return
	_bump(hit)


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
func _carry_driver() -> void:
	var f := forward2()
	var seat := pos2()
	if spec["open"]:
		seat += right_of(f) * -width() * 0.22 + f * (-0.1 if kind != "kart" else -0.15)
	driver.global_position = Vector3(seat.x, seat_height(), seat.y)
	driver.yaw = yaw
	driver.rotation.y = yaw
	driver.velocity = Vector3(f.x, 0, f.y) * speed


## Hip height of the driver above the ground (open cars show the driver sitting).
func seat_height() -> float:
	return 0.12 if kind == "kart" else 0.45


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
			a.say(["Jaja, schon gut!", "Huch!", "Nicht so laut!", "Hallo auch!"][randi() % 4], 2.0)


## The horn's sound: a bought horn (car parts at the scrapyard) for the player.
func horn_sound() -> String:
	if driver and driver.controlled:
		match Items.tool_tier(driver.inventory, "horn"):
			1: return "horn_duck"
			2: return "horn_cucaracha"
			3: return "horn_fanfare"
	return "horn"

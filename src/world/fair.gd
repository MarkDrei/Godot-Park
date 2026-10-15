class_name Fair
extends Node3D
## The Westpark with the Kirmes at runtime (doc/kirmes.md): built when the player comes close
## (World.load_fair). Turns the Ferris wheel and the carousel, swings the chain swing and the
## swing boats, runs the roller coaster and the ghost-train car, lets the bumper cars drift.
## Keeps the spots of the rides, booths and oases for the gameplay.

var world: World
var rng := RandomNumberGenerator.new()
var time := 0.0

# Moving parts (set by FairBuilder).
var wheel: MeshInstance3D
var gondolas: Array[MeshInstance3D] = []
var carousel: Node3D
var horses: Array[MeshInstance3D] = []
var chain_crown: Node3D
var chain_seats: Array[MeshInstance3D] = []
var boats: Array[Node3D] = []
var coaster_track := PackedVector3Array()
var coaster_cars: Array[MeshInstance3D] = []
var ghost_car: MeshInstance3D
var ghost_base := Vector3.ZERO
var scooters: Array[MeshInstance3D] = []
var scooter_rect := Rect2()

## Where people stand to use a ride (id -> position), the booths' counters and vendors
## (kind -> {pos, vendor, yaw}), the oases (id -> centre) and the posts of the showmen
## (id -> [position, yaw]; HumanBrain "fair:<id>" spots).
var spots := {}
var booths := {}
var oases := {}
var posts := {}
var booth_deco := {}         # booth kind -> MeshInstance3D of its wares (hidden during its game)

## The food stands (Shop ids "fair_<kind>").
const FOOD := ["candy", "almonds", "sausage", "crepes"]

var wheel_angle := 0.0
# A ride takes over its part (FerrisRide, SwingRide, GhostRide, CoasterRide, BumperCars).
var ride_wheel := false
var ride_boat := -1
var ride_boat_amp := 0.0
var ride_ghost := false
var player_scooter := -1
var coaster_laps := 0         # times the train came back to the station
var chain_speed := 0.0       # rad/s of the chain swing
var _chain_phase := 0.0      # seconds into its cycle
var _coaster_s := 0.0        # metres along the track of the first car
var _coaster_len := 0.0
var _coaster_wait := 0.0
var _coaster_v := 0.0         # speed of the train (m/s)
var _coaster_cum := PackedFloat32Array()     # track distance at each point
var _coaster_tan := PackedVector3Array()     # smoothed direction at each point
var _coaster_lift := 0.0      # where the lift hill starts (metres along the track)
var _scooter_targets: Array[Vector2] = []
var _scooter_yaw: Array[float] = []

const WHEEL_SPEED := TAU / 80.0          # one turn in 80 s
const CAROUSEL_SPEED := 0.55
const CHAIN_CYCLE := [8.0, 22.0, 8.0, 14.0]   # spin up, run, slow down, rest (seconds)
const CHAIN_MAX := 1.5


## The Kirmes is built and open (FairLayout.OPENS until midnight).
static func open_now(w: World) -> bool:
	return w.fair != null and Clock.hour() >= FairLayout.OPENS


func setup(w: World) -> void:
	world = w
	name = "Fair"
	rng.seed = 2626


## The food stands as shops (their vendors come with the people of the Westpark).
func setup_gameplay() -> void:
	for kind: String in FOOD:
		var id := "fair_" + kind
		var b: Dictionary = booths[kind]
		world.shop_spots[id] = {"pos": b["pos"], "vendor": b["vendor"]}
		var shop := Shop.new()
		shop.setup(world, id, world.shop_spots[id])
		add_child(shop)
		world.shops[id] = shop


## Within `margin` of an oasis: the id, or "".
func oasis_at(p: Vector3, margin := 4.0) -> String:
	for id: String in oases:
		var c: Vector3 = oases[id]
		if Vector2(p.x - c.x, p.z - c.z).length() < FairLayout.PLACES[id]["r"] + margin:
			return id
	return ""


func ready_parts() -> void:
	_coaster_len = 0.0
	_coaster_cum.clear()
	_coaster_tan.clear()
	_coaster_lift = 0.0
	var n := coaster_track.size()
	for i in n:
		_coaster_cum.append(_coaster_len)
		_coaster_tan.append((coaster_track[(i + 1) % n] - coaster_track[(i - 1 + n) % n]).normalized())
		if _coaster_lift == 0.0 and _coaster_tan[i].y > 0.05:
			_coaster_lift = _coaster_len
		_coaster_len += coaster_track[i].distance_to(coaster_track[(i + 1) % n])
	for sc in scooters:
		_scooter_targets.append(_random_rink_point())
		_scooter_yaw.append(rng.randf() * TAU)
	_update_wheel()


func _process(delta: float) -> void:
	time += delta
	# Far away (the camera in the park) nothing needs to move every frame.
	var far := world.focus.distance_to(Vector3(-262, 0, 0)) > 220.0
	if far and Engine.get_process_frames() % 6 != 0:
		return
	if far:
		delta *= 6.0
	if not ride_wheel:
		wheel_angle = fmod(wheel_angle + WHEEL_SPEED * delta, TAU)
	_update_wheel()
	if carousel:
		carousel.rotation.y += CAROUSEL_SPEED * delta
		for i in horses.size():
			horses[i].position.y = 0.47 + 0.18 + sin(time * 2.2 + i * 1.3) * 0.18
	_update_chain(delta)
	for k in boats.size():
		var amp := 0.55 + 0.4 * sin(time * 0.11 + k * 2.0)
		if k == ride_boat:
			amp = ride_boat_amp
		boats[k].rotation.x = sin(time * 1.15 + k * PI) * amp
	_update_coaster(delta)
	_update_ghost_car()
	_update_scooters(delta)


func _update_wheel() -> void:
	if wheel == null:
		return
	wheel.rotation.z = wheel_angle
	for i in gondolas.size():
		var a := wheel_angle + TAU * i / gondolas.size()
		gondolas[i].position = Vector3(cos(a), sin(a), 0) * FairModels.WHEEL_R
		gondolas[i].rotation.z = sin(time * 0.9 + i) * 0.03


## Starts the chain swing's cycle from the beginning (a ride: spin up, run, slow down).
func start_chain_cycle() -> void:
	_chain_phase = 0.0


## The chain swing's ride time: spin up, run, slow down.
static func chain_ride_time() -> float:
	return CHAIN_CYCLE[0] + CHAIN_CYCLE[1] + CHAIN_CYCLE[2]


## The coaster train waits in the station, then goes round once.
func coaster_board(wait: float) -> void:
	_coaster_s = 0.0
	_coaster_v = 0.0
	_coaster_wait = wait


## 0..1: how far the train is round the track (0 while it waits in the station).
func coaster_progress() -> float:
	return clampf(_coaster_s / maxf(_coaster_len, 0.001), 0.0, 1.0)


## The gondola nearest the bottom (where people get in and out).
func lowest_gondola() -> int:
	var best := 0
	var best_y := INF
	for i in gondolas.size():
		if gondolas[i].position.y < best_y:
			best_y = gondolas[i].position.y
			best = i
	return best


func _update_chain(delta: float) -> void:
	if chain_crown == null:
		return
	_chain_phase += delta
	var total := 0.0
	for t: float in CHAIN_CYCLE:
		total += t
	_chain_phase = fmod(_chain_phase, total)
	var t := _chain_phase
	var target := 0.0
	if t < CHAIN_CYCLE[0]:
		target = CHAIN_MAX * t / CHAIN_CYCLE[0]
	elif t < CHAIN_CYCLE[0] + CHAIN_CYCLE[1]:
		target = CHAIN_MAX
	elif t < CHAIN_CYCLE[0] + CHAIN_CYCLE[1] + CHAIN_CYCLE[2]:
		target = CHAIN_MAX * (1.0 - (t - CHAIN_CYCLE[0] - CHAIN_CYCLE[1]) / CHAIN_CYCLE[2])
	chain_speed = target
	chain_crown.rotation.y += chain_speed * delta
	chain_crown.rotation.x = sin(time * 0.7) * 0.06 * chain_speed / CHAIN_MAX
	layout_chain_seats(chain_speed)


## Seats on the crown, swung out by the speed (rad/s).
func layout_chain_seats(speed: float) -> void:
	var tilt := clampf(speed * speed * 0.42, 0.0, 1.0)
	for i in chain_seats.size():
		var a := TAU * i / chain_seats.size()
		var out := Vector3(cos(a), 0, sin(a))
		var tangent := Vector3(-sin(a), 0, cos(a))
		var axis := Vector3.DOWN.cross(out).normalized()
		chain_seats[i].transform = Transform3D(Basis(axis, tilt) * Basis(Vector3.UP, atan2(-tangent.x, -tangent.z)),
			out * FairModels.CHAIN_R + Vector3(0, -0.3, 0))


## Point at `s` metres along the coaster track and the direction there. The direction blends
## between the points, so the cars (and a rider's camera) turn smoothly, not in steps.
func coaster_pose(s: float) -> Array:
	var n := coaster_track.size()
	if n < 2 or _coaster_cum.size() != n:
		return [Vector3.ZERO, Vector3.FORWARD]
	s = fposmod(s, _coaster_len)
	var i := clampi(_coaster_cum.bsearch(s, false) - 1, 0, n - 1)
	var a := coaster_track[i]
	var b := coaster_track[(i + 1) % n]
	var k := clampf((s - _coaster_cum[i]) / maxf(a.distance_to(b), 0.001), 0.0, 1.0)
	return [a.lerp(b, k), _coaster_tan[i].lerp(_coaster_tan[(i + 1) % n], k).normalized()]


## How fast the train wants to go at `s`: slowly out of the station, the chain up the lift
## hill, then what the height gives, braking into the station.
func _coaster_target_speed(s: float, pose: Array) -> float:
	var h: float = (pose[0] as Vector3).y - coaster_track[0].y
	if s < _coaster_lift:
		return 2.6
	if (pose[1] as Vector3).y > 0.05 and h < 10.5:
		return 2.4
	var v := 3.0 + 2.6 * sqrt(maxf(0.0, 10.6 - h))
	var left := _coaster_len - s
	if left < 16.0:
		v = lerpf(1.2, v, left / 16.0)
	return v


func _update_coaster(delta: float) -> void:
	if coaster_cars.is_empty() or _coaster_len <= 0.0:
		return
	if _coaster_wait > 0.0:
		_coaster_wait -= delta
	else:
		var target := _coaster_target_speed(_coaster_s, coaster_pose(_coaster_s))
		_coaster_v = move_toward(_coaster_v, target, (9.0 if target > _coaster_v else 6.0) * delta)
		_coaster_s += maxf(_coaster_v, 0.5) * delta
		if _coaster_s >= _coaster_len:
			_coaster_s = 0.0      # back in the station
			_coaster_v = 0.0
			_coaster_wait = 5.0
			coaster_laps += 1
	for k in coaster_cars.size():
		var pose: Array = coaster_pose(_coaster_s - k * 1.9)
		var dir: Vector3 = pose[1]
		var p: Vector3 = pose[0]
		coaster_cars[k].transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), p + Vector3(0, 0.05, 0))


## The ghost-train car rolls out of the exit, round the front and back in at the entrance.
func _update_ghost_car() -> void:
	if ghost_car == null or ride_ghost:
		return
	var period := 16.0
	var t := fmod(time, period) / period
	var b := ghost_base
	var exit := b + Vector3(5.5, 0, 7.5)
	var out := b + Vector3(5.5, 0, 10.0)
	var into := b + Vector3(-5.5, 0, 10.0)
	var entry := b + Vector3(-5.5, 0, 7.5)
	var pts := [exit - Vector3(0, 0, 2.5), exit, out, into, entry, entry - Vector3(0, 0, 2.5)]
	var seg := t * (pts.size() - 1)
	var i := mini(int(seg), pts.size() - 2)
	var a: Vector3 = pts[i]
	var c: Vector3 = pts[i + 1]
	var p := a.lerp(c, seg - i)
	ghost_car.visible = t > 0.02 and t < 0.98
	ghost_car.transform = Transform3D(Basis.looking_at(-(c - a).normalized(), Vector3.UP), p + Vector3(0, 0.1, 0))


func _random_rink_point() -> Vector2:
	return scooter_rect.position + Vector2(rng.randf(), rng.randf()) * scooter_rect.size


func _update_scooters(delta: float) -> void:
	for i in scooters.size():
		if i == player_scooter:
			continue
		var sc := scooters[i]
		var p := Vector2(sc.position.x, sc.position.z)
		var target := _scooter_targets[i]
		if p.distance_to(target) < 1.5:
			_scooter_targets[i] = _random_rink_point()
			target = _scooter_targets[i]
		var want := atan2(target.x - p.x, target.y - p.y)
		_scooter_yaw[i] = rotate_toward(_scooter_yaw[i], want, 1.6 * delta)
		var dir := Vector2(sin(_scooter_yaw[i]), cos(_scooter_yaw[i]))
		var q := p + dir * 2.4 * delta
		# Bump: two cars meet, both turn away.
		for j in scooters.size():
			if j != i and Vector2(scooters[j].position.x, scooters[j].position.z).distance_to(q) < 2.1:
				_scooter_targets[i] = _random_rink_point()
				q = p
		if scooter_rect.grow(-0.4).has_point(q):
			sc.position = Vector3(q.x, sc.position.y, q.y)
		else:
			_scooter_targets[i] = _random_rink_point()
		sc.rotation.y = _scooter_yaw[i]

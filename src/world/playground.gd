class_name Playground
extends Node3D
## The big playground in the city park (doc/playground.md): from the fountain path down to the
## hedge at the south fence, the ring path runs through it. Builds the play equipment and
## makes it usable for the player and for people alike:
## - things to sit on that move with their riders (seats, World seats): two swing sets, the
##   nest swing, the seesaw, the carousel and two spring animals;
## - things to do (scripted motions, use()): the slide tower ("slide"), the climbing net
##   ("climb"), the trampoline ("jump") and the balance beam with stumps ("balance").
## The player starts a motion at its FunctionSpot; people at the playground (Activities.Play)
## call use(). Minigames take a swing over with `swing_drive`.

const DEVICES := ["slide", "climb", "jump", "balance"]
const PROMPTS := {"slide": "Rutschen", "climb": "Klettern", "jump": "Hüpfen", "balance": "Balancieren"}
## Seat kinds of the playground (they move their rider): the prompt, what a person on it is
## doing, the rider's pose (Actor.pose_anim).
const SEATS := {
	"swing": {"verb": "Schaukeln", "doing": "schaukelt", "pose": "swing"},
	"nest": {"verb": "In die Nestschaukel", "doing": "liegt in der Nestschaukel", "pose": "swing"},
	"seesaw": {"verb": "Wippen", "doing": "wippt", "pose": "ride"},
	"carousel": {"verb": "Karussell fahren", "doing": "fährt Karussell", "pose": "ride"},
	"spring": {"verb": "Aufsitzen", "doing": "reitet auf dem Federtier", "pose": "ride"},
}

## Where everything stands (world x, z); the area is ParkLayout.AREAS["playground"].
const SWINGS := [Vector2(-50, 60), Vector2(-50, 67)]
const NEST := Vector2(-47, 82.8)
const SEESAW := Vector2(-42, 69.5)
const SANDBOX := Vector2(-38, 61)
const SANDBOX_SIZE := Vector2(7, 6)
const TOWER := Vector2(-29, 58)
const NET := Vector2(-28.5, 66)
const CAROUSEL := Vector2(-35, 68)
const SPRINGS := [[Vector2(-24, 62.5), "horse"], [Vector2(-24, 66.5), "duck"]]
const TRAMPOLINE := Vector2(-39, 82.5)
const BEAM := Vector2(-31.5, 81.5)
const BEAM_LENGTH := 5.0
const STUMPS := [[Vector2(-27.6, 81.8), 0.3], [Vector2(-26.5, 82.7), 0.45], [Vector2(-25.3, 83.4), 0.6], [Vector2(-24.1, 84.0), 0.4]]

var world: World
var map: ParkMap
var t := 0.0
## Moving seats: {"seat": Seat, "node": Node3D (what carries it), "local": Vector3 (hips in
## the node's space), "yaw": float (facing in the node's space)}.
var riders: Array[Dictionary] = []
var swing_pivots: Array[Node3D] = []          # swing sets first (2 × 2), then the nest swing
var swing_amp: Array[float] = []
## A minigame drives one swing pivot itself: pivot -> angle (radians).
var swing_drive := {}
var seesaw_beam: Node3D
var carousel_top: Node3D
var carousel_speed := 0.0
var spring_animals: Array[Node3D] = []
var motions: Array[Dictionary] = []          # running scripted motions (_motion)
var busy := {}                               # device -> Actor using it
var spots := {}                              # device -> FunctionSpot


func _init(w: World) -> void:
	world = w
	map = w.map
	name = "Playground"


func ground(p: Vector2) -> Vector3:
	return Vector3(p.x, map.height_at(p.x, p.y), p.y)


## Everything that does not move, merged into one mesh (one draw call per material).
var _kit := MeshKit.new()


func _static(mesh: Mesh, p: Vector2, yaw := 0.0, y := 0.0) -> void:
	_kit.add_mesh(mesh, Transform3D(Basis(Vector3.UP, yaw), ground(p) + Vector3(0, y, 0)))


## A moving part (its own node).
func _mesh(mesh: Mesh, p: Vector2, yaw := 0.0, y := 0.0, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = ground(p) + Vector3(0, y, 0)
	mi.rotation.y = yaw
	(parent if parent else self).add_child(mi)
	return mi


## A Bench (the interactable) for moving seats; `seats` are [Seat, node, local, yaw].
func _seat_group(id: String, at: Vector2, radius: float, kind: String, seats: Array) -> Bench:
	var b := Bench.new()
	b.bench_id = id
	b.position = ground(at)
	b.radius = radius
	b.verb = SEATS[kind]["verb"]
	for e: Array in seats:
		var node: Node3D = e[0]
		var local: Vector3 = e[1]
		var yaw: float = e[2]
		var s := Seat.new()
		s.kind = kind
		s.owner_id = id
		s.yaw = node.rotation.y + yaw
		s.position = node.transform * local      # the Playground sits at the world origin
		s.height = s.position.y - map.height_at(s.position.x, s.position.z)
		b.seats.append(s)
		riders.append({"seat": s, "node": node, "local": local, "yaw": yaw})
	add_child(b)
	world.register_bench(b, false)
	return b


func build() -> void:
	_swings()
	_nest()
	_seesaw()
	_sandbox()
	_tower()
	_net()
	_carousel()
	_springs()
	_trampoline()
	_beam()
	_surroundings()
	var mi := MeshInstance3D.new()
	mi.name = "PlaygroundStatic"
	mi.mesh = _kit.commit()
	add_child(mi)
	var c := ParkLayout.place("playground")
	world.landmarks.append({"id": "playground", "name": "Spielplatz", "pos": Vector3(c.x, map.height_at(c.x, c.y) + 1.5, c.y)})


# --- Seats that move ------------------------------------------------------------------------

func _swings() -> void:
	var k := 0
	for at: Vector2 in SWINGS:
		_static(PropModels.swing_set(), at)
		for x: float in [-1.8, 1.8]:
			for z: float in [-0.9, 0.9]:
				map.add_obstacle_circle(at + Vector2(x, z), 0.2, ParkMap.BLOCK_PEOPLE)
		var seats := []
		for x: float in [-0.9, 0.9]:
			var pivot := Node3D.new()
			pivot.position = ground(at) + Vector3(x, 2.4, 0)
			add_child(pivot)
			var seat_mesh := MeshInstance3D.new()
			seat_mesh.mesh = PropModels.swing_seat()
			pivot.add_child(seat_mesh)
			swing_pivots.append(pivot)
			swing_amp.append(0.0)
			seats.append([pivot, Vector3(0, -1.9, 0), 0.0])
		_seat_group("swings_%d" % k, at, 2.4, "swing", seats)
		k += 1


func _nest() -> void:
	_static(PlaygroundModels.nest_swing_frame(), NEST)
	for x: float in [-1.7, 1.7]:
		for z: float in [-1.0, 1.0]:
			map.add_obstacle_circle(NEST + Vector2(x, z), 0.2, ParkMap.BLOCK_PEOPLE)
	var pivot := Node3D.new()
	pivot.position = ground(NEST) + Vector3(0, PlaygroundModels.NEST_PIVOT, 0)
	add_child(pivot)
	var nest := MeshInstance3D.new()
	nest.mesh = PlaygroundModels.nest_seat()
	pivot.add_child(nest)
	swing_pivots.append(pivot)
	swing_amp.append(0.0)
	var drop := -PlaygroundModels.NEST_DROP + 0.08
	_seat_group("nest", NEST, 2.2, "nest", [[pivot, Vector3(-0.22, drop, 0), 0.0], [pivot, Vector3(0.22, drop, 0), PI]])


func _seesaw() -> void:
	_static(PlaygroundModels.seesaw_stand(), SEESAW)
	map.add_obstacle_circle(SEESAW, 0.35, ParkMap.BLOCK_PEOPLE)
	seesaw_beam = Node3D.new()
	seesaw_beam.position = ground(SEESAW) + Vector3(0, PlaygroundModels.SEESAW_PIVOT_Y, 0)
	add_child(seesaw_beam)
	var mi := MeshInstance3D.new()
	mi.mesh = PlaygroundModels.seesaw_beam()
	seesaw_beam.add_child(mi)
	var x := PlaygroundModels.SEESAW_SEAT_X
	_seat_group("seesaw", SEESAW, 2.4, "seesaw", [[seesaw_beam, Vector3(x, 0.1, 0), -PI / 2], [seesaw_beam, Vector3(-x, 0.1, 0), PI / 2]])


func _carousel() -> void:
	_static(PlaygroundModels.carousel_base(), CAROUSEL)
	map.add_obstacle_circle(CAROUSEL, 1.1, ParkMap.BLOCK_PEOPLE)
	carousel_top = _mesh(PlaygroundModels.carousel_top(), CAROUSEL)
	var seats := []
	for k in 4:
		var a := PI / 4 + k * PI / 2
		var d := Vector3(cos(a), 0, sin(a))
		# Facing outward, so getting on and off is from outside the deck.
		seats.append([carousel_top, d * 0.95 + Vector3(0, PlaygroundModels.CAROUSEL_DECK + 0.05, 0), atan2(d.x, d.z)])
	_seat_group("carousel", CAROUSEL, 2.6, "carousel", seats)


func _springs() -> void:
	var k := 0
	for e: Array in SPRINGS:
		var at: Vector2 = e[0]
		var yaw := -PI / 2      # facing west, into the playground
		_static(PlaygroundModels.spring_base(), at, yaw)
		map.add_obstacle_circle(at, 0.35, ParkMap.BLOCK_PEOPLE)
		var animal := _mesh(PlaygroundModels.spring_animal(e[1]), at, yaw, PlaygroundModels.SPRING_TOP)
		spring_animals.append(animal)
		_seat_group("spring_%d" % k, at, 1.6, "spring", [[animal, Vector3(0, PlaygroundModels.SPRING_SEAT, -0.05), 0.0]])
		k += 1


## Moves the seats and whoever sits on them.
func _process(delta: float) -> void:
	t += delta
	if not world.area_awake("park") and motions.is_empty():
		return
	for i in swing_pivots.size():
		var pivot := swing_pivots[i]
		if swing_drive.has(pivot):
			pivot.rotation.x = swing_drive[pivot]
			continue
		var used := false
		for r: Dictionary in riders:
			if r["node"] == pivot and (r["seat"] as Seat).occupant != null:
				used = true
		swing_amp[i] = move_toward(swing_amp[i], 0.55 if used else 0.04, delta * 0.25)
		pivot.rotation.x = sin(t * 2.0 + i * 1.3) * swing_amp[i]
	var on_seesaw := 0
	var on_carousel := 0
	for r: Dictionary in riders:
		if (r["seat"] as Seat).occupant:
			match (r["seat"] as Seat).kind:
				"seesaw": on_seesaw += 1
				"carousel": on_carousel += 1
	var tilt := sin(t * 1.7) * 0.19 if on_seesaw > 0 else 0.19
	seesaw_beam.rotation.z = lerp_angle(seesaw_beam.rotation.z, tilt, clampf(delta * 4.0, 0.0, 1.0))
	carousel_speed = move_toward(carousel_speed, 1.5 if on_carousel > 0 else 0.0, delta * 0.6)
	carousel_top.rotation.y = wrapf(carousel_top.rotation.y + carousel_speed * delta, -PI, PI)
	for i in spring_animals.size():
		var used := false
		for r: Dictionary in riders:
			if r["node"] == spring_animals[i] and (r["seat"] as Seat).occupant != null:
				used = true
		spring_animals[i].rotation.x = sin(t * 5.0 + i) * 0.22 if used else lerpf(spring_animals[i].rotation.x, 0.0, clampf(delta * 3.0, 0.0, 1.0))
	for r: Dictionary in riders:
		var a: Actor = (r["seat"] as Seat).occupant
		if a and a.seat == r["seat"]:
			_carry(a, r)
	_run_motions(delta)


## Puts a rider where its seat is now: hips on the seat, tilted with it.
func _carry(a: Actor, r: Dictionary) -> void:
	var node: Node3D = r["node"]
	var seat: Seat = r["seat"]
	var xf := node.global_transform
	var hips: Vector3 = xf * (r["local"] as Vector3)
	var b := xf.basis.orthonormalized() * Basis(Vector3.UP, r["yaw"])
	a.global_transform = Transform3D(b, hips - b.y * seat.height)
	a.yaw = atan2(b.z.x, b.z.z)


# --- Things to do (scripted motions) ----------------------------------------------------

## Where somebody starts `device` (in front of it, on the ground).
func start_point(device: String) -> Vector3:
	match device:
		"slide": return ground(TOWER + _v2(PlaygroundModels.LADDER_FOOT) + Vector2(-0.6, 0))
		"climb": return ground(NET + Vector2(0, -2.2))
		"jump": return ground(TRAMPOLINE + Vector2(0, -2.0))
		"balance": return ground(BEAM + Vector2(-BEAM_LENGTH * 0.5 - 0.8, 0))
	return ground(ParkLayout.place("playground"))


static func _v2(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Somebody is on `device` (a scripted motion, or a minigame holds it: TrampolineGame).
func is_busy(device: String) -> bool:
	var a: Actor = busy.get(device)
	return a != null and is_instance_valid(a) and (is_using(a) or a.custom_motion)


## Whether `a` is on a device right now.
func is_using(a: Actor) -> bool:
	for m: Dictionary in motions:
		if m["actor"] == a:
			return true
	return false


## Starts `device` for `a`, who stands at its start_point; false when somebody else is on it
## or `a` is not there.
## `done` is called with the actor at the end.
func use(a: Actor, device: String, done := Callable()) -> bool:
	if is_busy(device) or is_using(a) or a.global_position.distance_to(start_point(device)) > 3.0:
		return false
	var steps := _steps(device)
	if steps.is_empty():
		return false
	if a.seat:
		a.stand_up()
	a.stop_moving()
	a.custom_motion = true
	busy[device] = a
	motions.append({"actor": a, "device": device, "steps": steps, "i": 0, "time": 0.0, "from": a.global_position, "done": done})
	if a.is_player():
		GameState.add_to_set("playground_devices", device)
	return true


## A step: {"to": world position of the feet, "t": seconds, "anim", "yaw", "arc": height of a
## hop, "seated": the hips are on a surface (the feet go seat height lower)}.
func _steps(device: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var g := func(p: Vector2, y := 0.0) -> Vector3: return ground(p) + Vector3(0, y, 0)
	match device:
		"slide":
			var foot := TOWER + _v2(PlaygroundModels.LADDER_FOOT)
			var top := TOWER + _v2(PlaygroundModels.LADDER_TOP)
			var chute := TOWER + _v2(PlaygroundModels.SLIDE_TOP)
			var bottom := TOWER + _v2(PlaygroundModels.SLIDE_BOTTOM)
			out.append({"to": g.call(foot), "t": 0.5, "anim": "idle", "yaw": PI / 2})
			out.append({"to": g.call(top, PlaygroundModels.TOWER_TOP), "t": 1.8, "anim": "climb", "yaw": PI / 2})
			out.append({"to": g.call(chute + Vector2(-0.2, 0), PlaygroundModels.TOWER_TOP), "t": 0.6, "anim": "idle", "yaw": PI / 2})
			out.append({"to": g.call(chute, PlaygroundModels.TOWER_TOP + 0.05), "t": 0.3, "anim": "slide", "yaw": PI / 2, "seated": true})
			out.append({"to": g.call(bottom, PlaygroundModels.SLIDE_BOTTOM.y), "t": 1.3, "anim": "slide", "yaw": PI / 2, "seated": true, "ease": true})
			out.append({"to": g.call(bottom + Vector2(0.5, 0), PlaygroundModels.SLIDE_BOTTOM.y - 0.05), "t": 0.35, "anim": "slide", "yaw": PI / 2, "seated": true})
			out.append({"to": g.call(TOWER + _v2(PlaygroundModels.SLIDE_EXIT)), "t": 0.4, "anim": "idle", "yaw": PI / 2})
		"climb":
			var top := g.call(NET, PlaygroundModels.CLIMB_TOP) as Vector3
			out.append({"to": g.call(NET + Vector2(0, -1.75)), "t": 0.5, "anim": "idle", "yaw": 0.0})
			out.append({"to": top, "t": 2.6, "anim": "climb", "yaw": 0.0})
			out.append({"to": top, "t": 2.2, "anim": "cheer", "yaw": PI})
			out.append({"to": g.call(NET + Vector2(0, 1.75)), "t": 2.2, "anim": "climb", "yaw": PI})
			out.append({"to": g.call(NET + Vector2(0, 2.3)), "t": 0.4, "anim": "idle", "yaw": 0.0})
		"jump":
			var mid := g.call(TRAMPOLINE, 0.05) as Vector3
			out.append({"to": mid, "t": 0.6, "anim": "idle", "yaw": 0.0, "arc": 0.3})
			for i in 6:
				out.append({"to": mid, "t": 0.75, "anim": "bounce", "yaw": PI if i == 5 else 0.0, "arc": 0.7 + 0.12 * i})
			out.append({"to": g.call(TRAMPOLINE + Vector2(0, 2.0)), "t": 0.6, "anim": "idle", "yaw": 0.0, "arc": 0.4})
		"balance":
			var y := PlaygroundModels.BEAM_TOP
			var a := BEAM + Vector2(-BEAM_LENGTH * 0.5 + 0.2, 0)
			var e := BEAM + Vector2(BEAM_LENGTH * 0.5 - 0.2, 0)
			out.append({"to": g.call(a, y), "t": 0.5, "anim": "balance", "yaw": PI / 2, "arc": 0.25})
			out.append({"to": g.call(e, y), "t": 3.6, "anim": "balance", "yaw": PI / 2})
			for s: Array in STUMPS:
				out.append({"to": g.call(s[0], s[1] + 0.02), "t": 0.55, "anim": "balance", "yaw": PI / 2, "arc": 0.35})
			var last: Vector2 = STUMPS[-1][0]
			out.append({"to": g.call(last + Vector2(1.2, 0.4)), "t": 0.5, "anim": "cheer", "yaw": PI / 2, "arc": 0.4})
	return out


func _run_motions(delta: float) -> void:
	for m: Dictionary in motions.duplicate():
		var a: Actor = m["actor"]
		if not is_instance_valid(a) or a.inside:
			_finish(m)
			continue
		var steps: Array = m["steps"]
		var st: Dictionary = steps[m["i"]]
		m["time"] += delta
		var k := clampf(m["time"] / float(st["t"]), 0.0, 1.0)
		var f := k * k if st.get("ease", false) else k
		# Seated: `to` is where the hips go, the feet (the actor's origin) are lower.
		var to: Vector3 = st["to"] - Vector3(0, 0.47 if st.get("seated", false) else 0.0, 0)
		var p := (m["from"] as Vector3).lerp(to, f)
		p.y += float(st.get("arc", 0.0)) * 4.0 * k * (1.0 - k)
		a.global_position = p
		a.yaw = st["yaw"]
		a.rotation = Vector3(0, a.yaw, 0)
		a.anim = st["anim"]
		a.velocity = Vector3.ZERO
		if k >= 1.0:
			m["i"] += 1
			m["time"] = 0.0
			m["from"] = to
			if m["i"] >= steps.size():
				_finish(m)


func _finish(m: Dictionary) -> void:
	motions.erase(m)
	var a: Actor = m["actor"]
	if busy.get(m["device"]) == a:
		busy.erase(m["device"])
	if not is_instance_valid(a):
		return
	a.custom_motion = false
	a.anim = "idle"
	var p := a.global_position
	a.global_position = Vector3(p.x, map.walk_height(p.x, p.z), p.z)
	a.rotation = Vector3(0, a.yaw, 0)
	var done: Callable = m["done"]
	if done.is_valid():
		done.call(a)


## Stops whatever `a` does on a device (switching characters, a minigame starts).
func stop(a: Actor) -> void:
	for m: Dictionary in motions.duplicate():
		if m["actor"] == a:
			m["done"] = Callable()
			_finish(m)


# --- Equipment without riders ------------------------------------------------------------

func _tower() -> void:
	_static(PlaygroundModels.slide_tower(), TOWER)
	map.add_obstacle_rect(TOWER + Vector2(-0.2, 0), Vector2(2.4, 1.8), 0.0, ParkMap.BLOCK_PEOPLE)
	map.add_obstacle_rect(TOWER + Vector2(2.4, 0), Vector2(2.6, 0.8), 0.0, ParkMap.BLOCK_PEOPLE)
	_device_spot("slide", TOWER + _v2(PlaygroundModels.LADDER_FOOT) + Vector2(-0.5, 0), 1.6)


func _net() -> void:
	_static(PlaygroundModels.climbing_net(), NET)
	map.add_obstacle_rect(NET, Vector2(3.0, 3.0), 0.0, ParkMap.BLOCK_PEOPLE)
	_device_spot("climb", NET + Vector2(0, -2.1), 1.6)


func _trampoline() -> void:
	_static(PlaygroundModels.trampoline(), TRAMPOLINE)
	_device_spot("jump", TRAMPOLINE + Vector2(0, -1.9), 1.7)


func _beam() -> void:
	_static(PlaygroundModels.balance_beam(BEAM_LENGTH), BEAM)
	map.add_obstacle_rect(BEAM, Vector2(BEAM_LENGTH, 0.3), 0.0, ParkMap.BLOCK_PEOPLE)
	for s: Array in STUMPS:
		_static(PlaygroundModels.stump(s[1]), s[0])
		map.add_obstacle_circle(s[0], 0.22, ParkMap.BLOCK_PEOPLE)
	_device_spot("balance", BEAM + Vector2(-BEAM_LENGTH * 0.5 - 0.8, 0), 1.5)


func _device_spot(device: String, at: Vector2, r: float) -> void:
	var s := FunctionSpot.new()
	s.name = "Playground_" + device
	s.position = ground(at)
	s.radius = r
	s.users = "human"
	s.prompt_fn = func(a: Actor) -> String:
		if is_using(a):
			return ""
		return PROMPTS[device] if not is_busy(device) else "%s (besetzt)" % PROMPTS[device]
	s.available_fn = func(a: Actor) -> bool: return not is_busy(device) and not is_using(a) and a.vehicle == null
	s.action_fn = func(a: Actor) -> void: use(a, device)
	add_child(s)
	spots[device] = s


func _sandbox() -> void:
	_static(PlaygroundModels.sandbox_big(SANDBOX_SIZE), SANDBOX)
	_static(PlaygroundModels.toy_digger(), SANDBOX + Vector2(2.0, -1.6), -0.6)
	_static(PlaygroundModels.sand_castle(), SANDBOX + Vector2(-1.8, 1.4), 0.4)
	_static(PlaygroundModels.bucket(Color("d8463a")), SANDBOX + Vector2(-0.6, 1.9), 0.0, 0.1)
	_static(PlaygroundModels.bucket(Color("3a7fd8")), SANDBOX + Vector2(1.6, 1.2), 0.0, 0.1)
	_static(PlaygroundModels.spade(Color("f2c230")), SANDBOX + Vector2(0.4, -1.9), 1.1, 0.12)
	_static(PlaygroundModels.water_pump(), SANDBOX + Vector2(SANDBOX_SIZE.x * 0.5 + 1.2, -1.6), -PI / 2)
	map.add_obstacle_circle(SANDBOX + Vector2(SANDBOX_SIZE.x * 0.5 + 1.2, -1.6), 0.5, ParkMap.BLOCK_PEOPLE)
	map.add_obstacle_circle(SANDBOX + Vector2(2.0, -1.6), 0.6, ParkMap.BLOCK_PEOPLE)


## A point in the sandbox to dig at (people digging, the treasure hunt).
func sand_point(rng: RandomNumberGenerator) -> Vector3:
	var h := SANDBOX_SIZE * 0.5 - Vector2(0.8, 0.8)
	return ground(SANDBOX + Vector2(rng.randf_range(-h.x, h.x), rng.randf_range(-h.y, h.y * 0.3)))


## A free spot in the area to run to.
func run_point(rng: RandomNumberGenerator) -> Vector3:
	var area: Dictionary = ParkLayout.AREAS["playground"]
	var c: Vector2 = area["pos"]
	var h: Vector2 = area["size"] * 0.5 - Vector2(2, 2)
	for i in 12:
		var p := c + Vector2(rng.randf_range(-h.x, h.x), rng.randf_range(-h.y, h.y))
		if not map.is_solid(p):
			return ground(p)
	return ground(c)


func _surroundings() -> void:
	var area: Dictionary = ParkLayout.AREAS["playground"]
	var r := Rect2((area["pos"] as Vector2) - (area["size"] as Vector2) * 0.5, area["size"])
	# Benches for the parents.
	for e: Array in [[Vector2(-53.8, 56.5), PI / 2], [Vector2(-53.8, 63.5), PI / 2], [Vector2(-53.6, 82.5), PI / 2],
			[Vector2(-21.9, 61.5), -PI / 2], [Vector2(-31.0, 85.6), PI]]:
		_bench(e[0], e[1])
	# Shade trees and bushes.
	for p: Vector2 in [Vector2(-53.5, 52.5), Vector2(-53.2, 71.0), Vector2(-22.8, 70.8), Vector2(-22.6, 85.2)]:
		var tree := NatureModels.tree(["maple", "chestnut", "oak"][int(absf(p.x + p.y)) % 3], 0)
		_kit.add_mesh(tree, Transform3D(Basis(Vector3.UP, p.x).scaled(Vector3.ONE * 0.9), ground(p) - Vector3(0, 0.05, 0)))
		map.add_obstacle_circle(p, 0.45, ParkMap.BLOCK_WALKERS)   # like the park's trees
	# A low fence round it, open where the paths come in; the hedge closes the south side.
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in [3, 0, 1]:
		var a: Vector2 = corners[k]
		var e: Vector2 = corners[(k + 1) % 4]
		var n := int(a.distance_to(e) / 2.0)
		for i in n:
			var p0 := a.lerp(e, float(i) / n)
			var p1 := a.lerp(e, float(i + 1) / n)
			var mid := (p0 + p1) * 0.5
			if map.path_dist_at(mid) < 1.2:
				continue
			var d := p1 - p0
			var y := minf(map.height_at(p0.x, p0.y), map.height_at(p1.x, p1.y))
			_kit.add_mesh(PlaygroundModels.play_fence(d.length()), Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(p0.x, y, p0.y)))
			map.add_obstacle_segment(p0, p1, 0.2, ParkMap.BLOCK_PEOPLE)
	# The sign at the north entrance.
	var sp := Vector2(-41.5, 48.6)    # outside the fence, by the path from the fountain
	_static(PlaygroundModels.sign_board(), sp, PI)
	map.add_obstacle_rect(sp, Vector2(2.6, 0.3), 0.0, ParkMap.BLOCK_PEOPLE)
	var l := Label3D.new()
	l.text = "SPIELPLATZ"
	l.font_size = 64
	l.pixel_size = 0.0045
	l.modulate = Color("5a3a1e")
	l.outline_size = 0
	l.position = ground(sp) + Vector3(0, 1.75, -0.07)
	l.rotation.y = PI
	add_child(l)


## A bench for the parents (not one of the park's benches for Bankdrücker).
func _bench(p: Vector2, yaw: float) -> void:
	var b := Bench.new()
	b.setup("pg_bench_%d" % get_child_count(), ground(p), yaw, 3, 0.47)
	add_child(b)
	_static(PropModels.bench(1), p, yaw)
	map.add_obstacle_rect(p, Vector2(1.9, 0.6), -yaw, ParkMap.BLOCK_PEOPLE)
	world.register_bench(b, false)

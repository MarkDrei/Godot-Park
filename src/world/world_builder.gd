class_name WorldBuilder
extends RefCounted
## Shared helpers of the builders that put things into the world (ParkDecorator,
## ForestDecorator, CityBuilder, FairBuilder): ground height, directions, single meshes, signs
## and benches. Each builder has its own seeded RNG, so its random choices don't depend on what
## another builder drew.

## Colour of painted sign letters.
const SIGN := Color("f3ead2")
## Signs are not drawn beyond this (metres): their letters are too small to read there.
const SIGN_RANGE := 110.0

var world: World
var map: ParkMap
var root: Node3D               # where meshes, signs and benches go
var rng := RandomNumberGenerator.new()


func _init(w: World, parent: Node3D, rng_seed: int) -> void:
	world = w
	map = w.map
	root = parent
	rng.seed = rng_seed


## An own random sequence for one part of a builder: what it draws doesn't move the parts
## built after it.
func part_rng(part_seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = part_seed
	return r


## Ground height at p.
func gy(p: Vector2) -> float:
	return map.height_at(p.x, p.y)


## The direction yaw faces (yaw 0 faces +z) and its right-hand side.
static func fwd(yaw: float) -> Vector2:
	return Vector2(sin(yaw), cos(yaw))


static func right(yaw: float) -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


## The yaw that faces from `from` to `to`.
static func yaw_to(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(d.x, d.y)


## A mesh on its own (most things are merged or instanced instead) at p on the ground, raised
## by y and turned by yaw.
func add(mesh: Mesh, p: Vector2, yaw := 0.0, y := 0.0, shadow := true, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, gy(p) + y, p.y))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if name != "":
		mi.name = name
	root.add_child(mi)
	return mi


## Painted letters (a sign, a plaque, a street name) at pos facing yaw.
func label(text: String, pos: Vector3, yaw: float, size := 64, color := SIGN, outline := 10, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Color(0, 0, 0, 0.75)
	l.position = pos
	l.rotation.y = yaw
	l.double_sided = true
	l.visibility_range_end = SIGN_RANGE
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	root.add_child(l)
	return l


## A bench (or table) to sit on with `seats` places, registered with the world; `counts`: it
## counts for "Bankdrücker" (the park's benches). The caller draws it and adds its obstacle.
func place_bench(id: String, pos: Vector3, yaw: float, seats := 3, height := 0.47, counts := false) -> Bench:
	var b := Bench.new()
	b.setup(id, pos, yaw, seats, height)
	root.add_child(b)
	world.register_bench(b, counts)
	return b


## A picnic table with four seats (two each side) at p, drawn into `batch`; its id is `id`.
func picnic_table(id: String, p: Vector2, batch: InstanceBatcher) -> Bench:
	var ground := gy(p)
	batch.add(PropModels.picnic_table(), Transform3D(Basis(), Vector3(p.x, ground, p.y)))
	map.add_obstacle_rect(p, Vector2(2.0, 1.0), 0.0, ParkMap.BLOCK_PEOPLE)
	var b := Bench.new()
	b.bench_id = id
	b.position = Vector3(p.x, ground, p.y)
	b.radius = 2.2
	for side: float in [-1.0, 1.0]:
		for x: float in [-0.5, 0.5]:
			var s := Seat.new()
			s.position = Vector3(p.x + x, ground + 0.46, p.y + side * 0.75)
			s.yaw = 0.0 if side < 0 else PI
			s.owner_id = id
			s.kind = "table"
			s.height = 0.46
			b.seats.append(s)
	root.add_child(b)
	world.register_bench(b, false)
	return b

class_name FairBackdrop
extends RefCounted
## The Westpark as seen from the city park until it is loaded or while it sleeps
## (World.load_area, World.enter_area): a meadow, the main path and the Festplatz, the Ferris
## wheel, the big halls and rides standing still, and trees along the edges. It invites the
## player through the Westtor without costing the whole fair.

const MEADOW := Color("74a64c")
const PATH := Color("c4b79e")


static func build(world: World) -> Node3D:
	var root := Node3D.new()
	root.name = "FairBackdrop"
	var kit := MeshKit.new()
	var lo := ParkLayout.FAIR_MIN
	var hi := ParkLayout.FAIR_MAX
	kit.quad(Vector3(lo.x, 0.03, lo.y), Vector3(lo.x, 0.03, hi.y), Vector3(hi.x, 0.03, hi.y), Vector3(hi.x, 0.03, lo.y), MEADOW)
	kit.quad(Vector3(-240, 0.06, -2), Vector3(-240, 0.06, 8), Vector3(hi.x, 0.06, 8), Vector3(hi.x, 0.06, -2), PATH)
	kit.disc(Vector3(FairLayout.place("fest_square").x, 0.07, FairLayout.place("fest_square").y), 22.0, 20, PATH)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = kit.commit()
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ground)
	var wheel := FairLayout.place("ferris_wheel")
	_add(root, FairModels.ferris_frame(), wheel)
	_add(root, FairModels.ferris_wheel(), wheel, 0.0, FairModels.WHEEL_HUB)
	for i in FairModels.WHEEL_GONDOLAS:
		var a := TAU * i / FairModels.WHEEL_GONDOLAS
		_add(root, FairModels.gondola(FairModels.COLORS[i % FairModels.COLORS.size()]),
			wheel + Vector2(cos(a) * FairModels.WHEEL_R, 0), 0.0, FairModels.WHEEL_HUB + sin(a) * FairModels.WHEEL_R)
	_add(root, FairModels.ghost_train(), FairLayout.place("ghost_train"))
	_add(root, FairModels.arcade_hall(), FairLayout.place("arcade"))
	_add(root, FairModels.bumper_hall(), FairLayout.place("bumper_cars"))
	_add(root, FairModels.carousel_base(), FairLayout.place("carousel"))
	_add(root, FairModels.carousel_top(), FairLayout.place("carousel"))
	_add(root, FairModels.chain_tower(), FairLayout.place("chain_swing"))
	_add(root, FairModels.chain_crown(), FairLayout.place("chain_swing"), 0.0, FairModels.CHAIN_TOP)
	for b: Array in FairBuilder.BOOTHS:
		_add(root, FairModels.booth(b[0], b[3]), b[1], b[2])
		_add(root, FairModels.booth_deco(b[0]), b[1], b[2])
	var batch := InstanceBatcher.new(130.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6060
	for i in 160:
		var p := Vector2(rng.randf_range(lo.x + 4, hi.x - 4), rng.randf_range(lo.y + 4, hi.y - 4))
		var edge := minf(minf(p.x - lo.x, hi.x - p.x), minf(p.y - lo.y, hi.y - p.y))
		if edge > 14.0 and not (p.x > -195.0 and absf(p.y - 4.0) > 12.0):
			continue   # trees along the fence and around the meadows in the east
		if FairBuilder.near_place(p, 3.0):
			continue
		var kind: String = ["oak", "maple", "chestnut", "birch", "oak", "willow"][rng.randi() % 6]
		var s := rng.randf_range(0.9, 1.2)
		batch.add(NatureModels.tree(kind, rng.randi() % int(NatureModels.TREES[kind]["variants"])),
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, 0.0, p.y)))
	batch.build(root, "Trees")
	return root


static func _add(root: Node3D, mesh: Mesh, p: Vector2, yaw := 0.0, y := 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.y))
	root.add_child(mi)

class_name ForestDecorator
extends RefCounted
## Places the buildings and props of the Nordwald (doc/nordwald.md): lumber camp, sawmill,
## forest inn, the dwarves' office, mine and railway, quarry rocks and beehives.
## Registers obstacles with the map; gameplay hooks (shops, gathering) come on top.

var world: World
var map: ParkMap
var rng := RandomNumberGenerator.new()
var root: Node3D

## Mine railway: polylines (x, z) from the mine portal.
const RAILS := [
	[Vector2(74, -251.0), Vector2(73, -243), Vector2(68, -236)],
	[Vector2(73, -243), Vector2(84, -246), Vector2(94, -247)],
]


func _init(w: World) -> void:
	world = w
	map = w.map
	rng.seed = 777


func build() -> void:
	root = Node3D.new()
	root.name = "Nordwald"
	world.static_root.add_child(root)
	_lumber_camp()
	_sawmill()
	_inn()
	_dwarves()
	_quarry()
	_orchard()


func ground_y(p: Vector2) -> float:
	return map.height_at(p.x, p.y)


## Adds a mesh at p (ground height) turned by yaw; returns its transform.
func put(mesh: Mesh, p: Vector2, yaw := 0.0, obstacle := Vector2.ZERO, y := NAN) -> Transform3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, ground_y(p) if is_nan(y) else y, p.y))
	root.add_child(mi)
	if obstacle != Vector2.ZERO:
		map.add_obstacle_rect(p, obstacle, -yaw)
	return mi.transform


## Text on a sign board given in the mesh's local coordinates (front +Z).
func add_sign(text: String, xf: Transform3D, local: Vector3, size := 40) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = Color("f3ead2")
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.transform = xf * Transform3D(Basis(), local)
	l.double_sided = false
	root.add_child(l)


func _lumber_camp() -> void:
	var hut := put(ForestModels.hut(), Vector2(-46, -167), 0.0, Vector2(4.8, 4.0))
	add_sign("Holzfällerlager", hut, Vector3(0, 2.25, 1.75), 60)
	put(ForestModels.workbench(), Vector2(-35, -166), 0.0, Vector2(2.3, 1.2))
	put(ForestModels.chest(), Vector2(-38.5, -166.5), 0.0, Vector2(1.3, 0.9))
	var chest := FunctionSpot.new()
	chest.name = "StorageChest"
	chest.position = Vector3(-38.5, ground_y(Vector2(-38.5, -165.6)), -165.6)
	chest.radius = 2.0
	chest.prompt_text = "Lagerkiste öffnen"
	chest.action_fn = func(_a: Actor) -> void: UI.open_bag(true)
	world.add_child(chest)
	put(ForestModels.campfire(), Vector2(-40, -159))
	put(ForestModels.campfire_flames(), Vector2(-40, -159))
	map.add_obstacle_circle(Vector2(-40, -159), 0.9)
	put(ForestModels.chopping_block(), Vector2(-31, -158))
	map.add_obstacle_circle(Vector2(-31, -158), 0.5)
	put(ForestModels.log_pile(3), Vector2(-29, -164), PI / 2, Vector2(3.0, 1.8))
	put(ForestModels.log_pile(2), Vector2(-53, -160), 0.0, Vector2(3.0, 1.4))
	put(ForestModels.axe_target(), Vector2(-51, -151), PI / 2, Vector2(1.0, 2.0))
	put(ForestModels.hammock(), Vector2(-29, -151), 0.0)
	for s: float in [-1.0, 1.0]:
		map.add_obstacle_circle(Vector2(-29 + s * 1.6, -151), 0.2)


func _sawmill() -> void:
	var xf := put(ForestModels.sawmill(), Vector2(-72, -125), 0.0, Vector2(6.2, 1.4))
	add_sign("Sägewerk", xf, Vector3(0, 2.75, 2.6), 90)
	for p: Vector2 in [Vector2(-63, -124), Vector2(-81, -124)]:
		put(ForestModels.log_pile(3), p, PI / 2, Vector2(3.0, 1.8))


func _inn() -> void:
	# Faces west, towards the path; the terrace is in front.
	var p := Vector2(28, -152)
	var yaw := -PI / 2
	var xf := put(ForestModels.forest_inn(), p, yaw)
	add_sign("Waldschänke", xf, Vector3(0, 3.05, 1.4), 100)
	var back := xf * Vector3(0, 0, -2.0)
	map.add_obstacle_rect(Vector2(back.x, back.z), Vector2(10.6, 7.1), -yaw)
	for x: float in [-3.0, 3.0]:
		var r := xf * Vector3(x, 0, 5.45)
		map.add_obstacle_rect(Vector2(r.x, r.z), Vector2(4.0, 0.3), -yaw, 1)


func _dwarves() -> void:
	var office := put(ForestModels.dwarf_office(), Vector2(34, -238), 0.0, Vector2(5.2, 4.2))
	add_sign("Zwergenkontor", office, Vector3(0, 2.75, 2.4), 90)
	var portal := put(ForestModels.mine_portal(), Vector2(74, -251.0), 0.0)
	add_sign("Glück auf!", portal, Vector3(0, 4.1, 0.15), 70)
	for s: float in [-1.0, 1.0]:
		var post := portal * Vector3(s * 1.8, 0, 0)
		map.add_obstacle_circle(Vector2(post.x, post.z), 0.3)
	for line: Array in RAILS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var d := b - a
			put(ForestModels.rails(d.length()), a, atan2(d.x, d.y), Vector2.ZERO, ground_y(a) - 0.05)
	var carts := [[Vector2(73.6, -248), "", 0.0], [Vector2(68.8, -237.5), "rock", 0.6], [Vector2(90, -246.6), "ore", 1.5]]
	for c: Array in carts:
		put(ForestModels.mine_cart(c[1]), c[0], c[2], Vector2(1.2, 1.6))
	put(ForestModels.switch_tower(), Vector2(98, -240), -PI / 2, Vector2(3.4, 3.0))
	add_sign("Stellwerk", Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(98, ground_y(Vector2(98, -240)), -240)), Vector3(0, 3.0, 1.38), 70)


func _quarry() -> void:
	var faces := [[Vector2(47, -244), 7.0], [Vector2(55, -246), 8.0], [Vector2(44, -236), 5.0], [Vector2(80, -236), 5.5],
		[Vector2(63, -247), 6.0]]
	for i in faces.size():
		var p: Vector2 = faces[i][0]
		var s: float = faces[i][1]
		var to_floor := ParkLayout.place("quarry") - p
		put(ForestModels.rock_face(i, s), p, atan2(to_floor.x, to_floor.y), Vector2.ZERO, ground_y(p) - 0.3)
		map.add_obstacle_circle(p, s * 0.45)
	# Boulders on the quarry floor (they will be mined).
	for p: Vector2 in [Vector2(54, -232), Vector2(60, -227), Vector2(51, -226), Vector2(64, -232), Vector2(57, -238)]:
		put(NatureModels.rock(rng.randi() % 6), p, rng.randf() * TAU, Vector2.ZERO, ground_y(p) - 0.1)
		map.add_obstacle_circle(p, 0.7)


func _orchard() -> void:
	for p: Vector2 in [Vector2(106, -131), Vector2(108, -133.5), Vector2(110, -131)]:
		put(ForestModels.beehive(), p, rng.randf_range(-0.3, 0.3), Vector2(0.9, 0.8))

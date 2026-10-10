class_name ParkDecorator
extends RefCounted
## Places all man-made things: bridges, landmarks, stands, playground, benches,
## lamps, signs, fence, gates and the surrounding city. Registers obstacles,
## seats and points of interest with the World.

var world: World
var map: ParkMap
var batch: InstanceBatcher
## The view east of the park until the Oststadt is loaded (World.load_city frees it).
var east_batch := InstanceBatcher.new(130.0)
var _east_city: MeshInstance3D
var rng := RandomNumberGenerator.new()
var _bench_count := 0


func _init(w: World) -> void:
	world = w
	map = w.map
	batch = InstanceBatcher.new(130.0)
	rng.seed = 4242


func build() -> void:
	_bridges()
	_pier_and_stones()
	_pavilion()
	_fountain()
	_statue()
	_food_court()
	_playground()
	_boule()
	_chess()
	_shell_game()
	_dog_meadow()
	_grotto()
	_picnic()
	_fence_and_gates()
	_forest_fence()
	_mountain()
	_path_benches()
	_lamps_and_bins()
	_signposts()
	_city()
	_forest_backdrop()
	_seasonal()
	_city_fence()
	batch.build(world.static_root, "Props")
	east_batch.build(world.static_root, "EastBackdrop")
	world.static_root.get_node("EastBackdrop").add_child(_east_city)
	GameState.bench_count = world.benches.size()


# --- Helpers -------------------------------------------------------------------

func ground_y(p: Vector2) -> float:
	return map.height_at(p.x, p.y)


func xform(p: Vector2, yaw: float, y_offset := 0.0, scale := 1.0) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale))
	return Transform3D(basis, Vector3(p.x, ground_y(p) + y_offset, p.y))


func add_mesh(mesh: Mesh, p: Vector2, yaw: float, y_offset := 0.0, shadow := true, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform(p, yaw, y_offset)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if name != "":
		mi.name = name
	world.static_root.add_child(mi)
	return mi


static func yaw_to(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(d.x, d.y)


static func fwd(yaw: float) -> Vector2:
	return Vector2(sin(yaw), cos(yaw))


static func right(yaw: float) -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


func add_label(text: String, pos: Vector3, yaw: float, size := 64, color := Color.WHITE, outline := 10) -> Label3D:
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
	world.static_root.add_child(l)
	return l


func new_bench(pos: Vector2, yaw: float, style := -1, plaque := "") -> Bench:
	var b := Bench.new()
	_bench_count += 1
	var gy := ground_y(pos)
	b.setup("bench_%d" % _bench_count, Vector3(pos.x, gy, pos.y), yaw, 3, 0.47)
	b.plaque = plaque
	world.static_root.add_child(b)
	var st := style if style >= 0 else rng.randi() % 3
	batch.add(PropModels.bench(st), Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, gy, pos.y)))
	map.add_obstacle_rect(pos, Vector2(1.9, 0.6), -yaw, 1)
	world.register_bench(b)
	return b


## Bench placement is valid when it is dry, off paths, flat and not crowded.
func bench_spot_ok(p: Vector2, min_gap := 9.0) -> bool:
	if not ParkMap.in_park(p, 8.0):
		return false
	if map.water_dist_at(p.x, p.y) < 2.5 or map.path_dist_at(p) < 0.4:
		return false
	if not map.bridge_at(p).is_empty():
		return false
	if absf(ground_y(p + Vector2(1, 0)) - ground_y(p - Vector2(1, 0))) > 0.35:
		return false
	for b: Bench in world.benches:
		if Vector2(b.position.x, b.position.z).distance_to(p) < min_gap:
			return false
	for id: String in ["pavilion", "fountain", "donut_stand", "hotdog_stand", "icecream_cart", "fries_stand", "kiosk", "statue", "shell_game", "grotto",
			"vending_west", "vending_east"]:
		var pl: Dictionary = ParkLayout.PLACES[id]
		if p.distance_to(pl["pos"]) < pl["r"] + 1.0:
			return false
	for key: String in ParkLayout.AREAS:
		var a: Dictionary = ParkLayout.AREAS[key]
		if ParkMap.in_rect(p, a["pos"], a["size"] + Vector2(1, 1), a["rot"]):
			return false
	return true


# --- Water structures -------------------------------------------------------------

func _bridges() -> void:
	for b: Dictionary in map.bridges:
		var mesh := PropModels.bridge(b["length"], b["width"], b["arch"], b["h0"], b["h1"], b["style"])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var a: Vector2 = b["a"]
		var d: Vector2 = b["dir"]
		mi.position = Vector3(a.x, 0, a.y)
		mi.rotation.y = atan2(-d.y, d.x)
		mi.name = "Bridge_" + b["name"]
		world.static_root.add_child(mi)
		var c: Vector2 = b["center"]
		if not ParkLayout.in_forest(c):  # landmarks are where tourists go
			world.landmarks.append({"id": "bridge_" + b["name"], "name": b["name"],
				"pos": Vector3(c.x, map.walk_height(c.x, c.y) + 1.0, c.y)})
		# Name plate on the parapet.
		var side := Vector2(-d.y, d.x) * (float(b["width"]) * 0.5 + 0.3)
		var plate := c + side
		add_label(b["name"], Vector3(plate.x, map.walk_height(c.x, c.y) + 0.55, plate.y), atan2(side.x, side.y), 40,
			Color("f3ead2"), 6)


func _pier_and_stones() -> void:
	var pier := ParkLayout.PIER
	var from: Vector2 = pier["from"]
	var to: Vector2 = pier["to"]
	var deck: float = ParkLayout.WATER_Y + pier["height"] + 0.43
	var mi := MeshInstance3D.new()
	mi.mesh = PropModels.pier(from.distance_to(to), pier["width"], deck)
	mi.position = Vector3(from.x, 0, from.y)
	mi.rotation.y = yaw_to(from, to)
	mi.name = "Pier"
	world.static_root.add_child(mi)
	# Rowboats moored beside the pier, a life buoy at the end.
	for i in 2:
		var bp := to + Vector2(-2.2 if i == 0 else 2.2, 2.0 + i * 1.5)
		var boat := MeshInstance3D.new()
		boat.mesh = PropModels.rowboat()
		boat.position = Vector3(bp.x, ParkLayout.WATER_Y - 0.08, bp.y)
		boat.rotation.y = 0.15 * (1 - 2 * i)
		boat.name = "Rowboat%d" % i
		boat.add_to_group("bobbing")
		world.static_root.add_child(boat)
	var buoy := MeshKit.new()
	buoy.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	buoy.torus(Vector3.ZERO, 0.3, 0.09, 12, 5, Color("e8442e"))
	buoy.pop()
	var bm := MeshInstance3D.new()
	bm.mesh = buoy.commit()
	bm.position = Vector3(to.x + 0.75, deck + 0.05, to.y + 1.0)
	bm.rotation = Vector3(PI / 2, 0, 0)
	world.static_root.add_child(bm)
	for s: Vector2 in ParkLayout.STEPPING_STONES:
		batch.add(PropModels.stepping_stone(), Transform3D(Basis(Vector3.UP, s.x), Vector3(s.x, ParkLayout.WATER_Y - 0.05, s.y)))
	world.landmarks.append({"id": "pier", "name": "Bootssteg", "pos": Vector3(to.x, deck + 1.0, to.y)})


# --- Landmarks ---------------------------------------------------------------------

func _pavilion() -> void:
	var c := ParkLayout.place("pavilion")
	var yaw := 0.55
	var gy := ground_y(c)
	add_mesh(PropModels.pavilion(), c, yaw, 0.0, true, "Pavilion")
	map.platforms.append({"center": c, "radius": 5.0, "height": gy + 0.66})
	# Columns and railing block the sides, the front stays open.
	for cz in range(-7, 8):
		for cx in range(-7, 8):
			var p := c + Vector2(cx, cz)
			var d := p.distance_to(c)
			if d < 4.9 or d > 6.2:
				continue
			var ang := atan2(p.x - c.x, p.y - c.y)
			if absf(angle_difference(ang, yaw)) < 0.34:
				continue
			map.add_obstacle_circle(p, 0.5)
	world.landmarks.append({"id": "pavilion", "name": "Musikpavillon", "pos": Vector3(c.x, gy + 3.5, c.y)})
	world.pavilion_stage = Vector3(c.x, gy + 0.66, c.y) - Vector3(sin(yaw), 0, cos(yaw)) * 1.2
	world.pavilion_yaw = yaw
	# Benches facing the pavilion.
	for i in 5:
		var a := yaw + (i - 2) * 0.42
		var p := c + fwd(a) * 10.5
		if bench_spot_ok(p, 3.0):
			new_bench(p, yaw_to(p, c))
	add_label("Musikpavillon", Vector3(c.x, gy + 3.9, c.y) + Vector3(sin(yaw), 0, cos(yaw)) * 5.6, yaw, 64, Color("f3ead2"))


func _fountain() -> void:
	var c := ParkLayout.place("fountain")
	var gy := ground_y(c)
	add_mesh(PropModels.fountain(), c, 0.0, 0.0, true, "Fountain")
	map.add_obstacle_circle(c, 3.9)
	world.fountain_pos = Vector3(c.x, gy, c.y)
	world.landmarks.append({"id": "fountain", "name": "Brunnen", "pos": Vector3(c.x, gy + 2.0, c.y)})
	for jet: Array in [[Vector3(0, 3.5, 0), 2.6, 0.5], [Vector3(0, 1.95, 0), 1.3, 1.3]]:
		var p := CPUParticles3D.new()
		p.position = Vector3(c.x, gy, c.y) + jet[0]
		p.amount = 60
		p.lifetime = 1.0
		p.direction = Vector3.UP
		p.spread = 12.0 if jet[2] < 1.0 else 70.0
		p.initial_velocity_min = jet[1]
		p.initial_velocity_max = jet[1] * 1.2
		p.gravity = Vector3(0, -6.0, 0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.0
		var pm := SphereMesh.new()
		pm.radius = 0.05
		pm.height = 0.1
		pm.radial_segments = 4
		pm.rings = 2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.92, 1.0, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.material = mat
		p.mesh = pm
		p.add_to_group("fountain_jets")
		world.static_root.add_child(p)
	for i in 4:
		var a := PI / 4 + i * PI / 2
		var p2 := c + fwd(a) * 8.0
		new_bench(p2, yaw_to(p2, c))
	# Flower beds around the plaza.
	for i in 8:
		var a := i * TAU / 8.0
		var bed := c + fwd(a) * 11.6
		if map.path_dist_at(bed) < 0.5:
			continue
		for k in 10:
			var fp := bed + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
			batch.add(NatureModels.flower(rng.randi() % 7), xform(fp, rng.randf() * TAU), false, 70.0)


func _statue() -> void:
	var c := ParkLayout.place("statue")
	var yaw := yaw_to(c, Vector2(14, 17))
	add_mesh(PropModels.duck_statue(), c, yaw, 0.0, true, "DuckStatue")
	map.add_obstacle_rect(c, Vector2(1.9, 1.9), -yaw)
	world.statue_pos = Vector3(c.x, ground_y(c), c.y)
	var plate := c + fwd(yaw) * 0.83
	add_label("Der unbekannten Ente\n1887 – heute", Vector3(plate.x, ground_y(c) + 0.62, plate.y), yaw, 18, Color("3a2a10"), 0)
	world.landmarks.append({"id": "statue", "name": "Entendenkmal", "pos": Vector3(c.x, ground_y(c) + 2.4, c.y)})


func _food_court() -> void:
	var center := ParkLayout.place("food_court")
	for id: String in ["donut_stand", "hotdog_stand", "icecream_cart", "fries_stand", "kiosk"]:
		var p := ParkLayout.place(id)
		var yaw := yaw_to(p, ParkLayout.PLACES[id].get("face", center))
		var mesh: Mesh
		var size := Vector2(3.0, 2.2)
		match id:
			"donut_stand":
				mesh = PropModels.donut_stand()
			"hotdog_stand", "icecream_cart", "fries_stand":
				mesh = PropModels.food_cart(id)
				size = Vector2(2.4, 1.3)
			"kiosk":
				mesh = PropModels.kiosk()
				size = Vector2(4.4, 3.2)
		add_mesh(mesh, p, yaw, 0.0, true, id)
		map.add_obstacle_rect(p, size, -yaw)
		if id == "donut_stand":
			var donut := add_mesh(PropModels.giant_donut(), p, yaw, 3.7, true, "GiantDonut")
			donut.add_to_group("spinning")
		var counter := p + fwd(yaw) * (size.y * 0.5 + 0.9)
		# Carts: the vendor stands behind the cart; donut stand and kiosk: inside, behind
		# the open window.
		var vendor := p + fwd(yaw) * (-(size.y * 0.5 + 0.4) if size.y < 2.0 else size.y * 0.5 - 0.5)
		world.shop_spots[id] = {"pos": Vector3(counter.x, ground_y(counter), counter.y), "yaw": yaw + PI,
			"vendor": Vector3(vendor.x, ground_y(vendor), vendor.y)}
	for id: String in ["vending_west", "vending_east"]:
		var p := ParkLayout.place(id)
		var yaw := yaw_to(p, ParkLayout.PLACES[id]["face"])
		add_mesh(PropModels.snack_machine(), p, yaw, 0.0, true, id)
		map.add_obstacle_rect(p, Vector2(1.1, 0.9), -yaw)
		var front := p + fwd(yaw) * 1.3
		world.shop_spots[id] = {"pos": Vector3(front.x, ground_y(front), front.y), "yaw": yaw + PI,
			"vendor": Vector3(p.x, ground_y(p), p.y)}
	var kiosk := ParkLayout.place("kiosk")
	var ky := yaw_to(kiosk, center)
	var machine := kiosk + right(ky) * 3.1 + fwd(ky) * 0.6
	add_mesh(PropModels.bottle_machine(), machine, ky, 0.0, true, "BottleMachine")
	map.add_obstacle_rect(machine, Vector2(1.0, 0.8), -ky)
	world.bottle_machine = Vector3(machine.x, ground_y(machine), machine.y) + Vector3(fwd(ky).x, 0, fwd(ky).y) * 0.9
	world.landmarks.append({"id": "donut", "name": "Riesendonut", "pos": Vector3(-2, ground_y(Vector2(-2, 41)) + 3.6, 41)})
	# Picnic tables with four seats each.
	var tables := [Vector2(-1, 48.5), Vector2(13, 48.5), Vector2(3, 53), Vector2(9, 53)]
	var t := 0
	for tp: Vector2 in tables:
		t += 1
		var gy := ground_y(tp)
		batch.add(PropModels.picnic_table(), Transform3D(Basis(), Vector3(tp.x, gy, tp.y)))
		map.add_obstacle_rect(tp, Vector2(2.0, 1.0), 0.0, 1)
		var b := Bench.new()
		b.bench_id = "table_%d" % t
		b.position = Vector3(tp.x, gy, tp.y)
		b.radius = 2.2
		for side: float in [-1.0, 1.0]:
			for x: float in [-0.5, 0.5]:
				var s := Seat.new()
				s.position = Vector3(tp.x + x, gy + 0.46, tp.y + side * 0.75)
				s.yaw = 0.0 if side < 0 else PI
				s.owner_id = b.bench_id
				s.kind = "table"
				s.height = 0.46
				b.seats.append(s)
		world.static_root.add_child(b)
		world.register_bench(b, false)
	# Umbrella-free sunny spot: a couple of bicycles.
	for i in 3:
		var bp := Vector2(18.5, 55 + i * 0.8)
		batch.add(PropModels.bicycle([Color("c0392b"), Color("2e86de"), Color("27ae60")][i]), xform(bp, PI / 2 + 0.1 * i))


func _playground() -> void:
	var c := ParkLayout.place("playground")
	var items := [
		[PropModels.swing_set(), Vector2(-44, 63), 0.0, Vector2(4.2, 2.0)],
		[PropModels.slide(), Vector2(-32, 65), PI / 2, Vector2(2.0, 5.0)],
		[PropModels.sandbox(), Vector2(-36, 59), 0.0, Vector2(3.2, 3.2)],
		[PropModels.seesaw(), Vector2(-44, 67.5), 0.0, Vector2(3.4, 0.6)],
		[PropModels.spring_duck(), Vector2(-30, 59.5), -0.5, Vector2(0.8, 0.8)],
		[PropModels.climbing_frame(), Vector2(-38, 66.5), 0.2, Vector2(2.6, 2.6)],
	]
	for it: Array in items:
		add_mesh(it[0], it[1], it[2])
		if it[0] != PropModels.sandbox():
			map.add_obstacle_rect(it[1], it[3], -float(it[2]), 1)
	# Swings are seats that actually swing.
	var swing_pos := Vector2(-44, 63)
	var gy := ground_y(swing_pos)
	var swings := Bench.new()
	swings.bench_id = "swings"
	swings.position = Vector3(swing_pos.x, gy, swing_pos.y)
	swings.radius = 2.4
	for x: float in [-0.9, 0.9]:
		var pivot := Node3D.new()
		pivot.position = Vector3(swing_pos.x + x, gy + 2.4, swing_pos.y)
		var seat_mesh := MeshInstance3D.new()
		seat_mesh.mesh = PropModels.swing_seat()
		pivot.add_child(seat_mesh)
		pivot.add_to_group("swings")
		world.static_root.add_child(pivot)
		var s := Seat.new()
		s.position = Vector3(swing_pos.x + x, gy + 0.5, swing_pos.y)
		s.yaw = 0.0
		s.kind = "swing"
		s.owner_id = "swings"
		s.height = 0.5
		swings.seats.append(s)
		world.swing_pivots.append(pivot)
	world.static_root.add_child(swings)
	world.register_bench(swings, false)
	for bx: float in [-47.0, -30.0]:
		var bp := Vector2(bx, 55.6)
		new_bench(bp, 0.0)
	world.landmarks.append({"id": "playground", "name": "Spielplatz", "pos": Vector3(c.x, ground_y(c) + 1.5, c.y)})


func _boule() -> void:
	var area: Dictionary = ParkLayout.AREAS["boule"]
	var c: Vector2 = area["pos"]
	add_mesh(PropModels.boule_border(), c, 0.0, 0.0, false, "BouleCourt")
	for bx: float in [-95.0, -89.0]:
		new_bench(Vector2(bx, -11.3), PI)
	var post := Vector2(c.x - 6.0, c.y - 3.9)
	batch.add(PropModels.signpost(), xform(post, 0.0))
	map.add_obstacle_circle(post, 0.2, 1)
	var l := add_label("Boule-Platz", Vector3(post.x, ground_y(post) + 2.2, post.y), PI, 40)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y


func _chess() -> void:
	var c := ParkLayout.place("chess")
	var i := 0
	for x: float in [-4.0, 0.0, 4.0]:
		i += 1
		var tp := c + Vector2(x, -3.0)
		var gy := ground_y(tp) + 0.07
		batch.add(PropModels.chess_table(), Transform3D(Basis(), Vector3(tp.x, gy, tp.y)))
		map.add_obstacle_circle(tp, 0.55, 1)
		var b := Bench.new()
		b.bench_id = "chess_%d" % i
		b.position = Vector3(tp.x, gy, tp.y)
		b.radius = 1.8
		for side: float in [-1.0, 1.0]:
			var s := Seat.new()
			s.position = Vector3(tp.x, gy + 0.45, tp.y + side * 0.85)
			s.yaw = 0.0 if side < 0 else PI
			s.kind = "stool"
			s.owner_id = b.bench_id
			b.seats.append(s)
		world.static_root.add_child(b)
		world.register_bench(b, false)
		world.chess_tables.append(b)
	var board := c + Vector2(0, 2.0)
	add_mesh(PropModels.giant_board(), board, 0.0, 0.07, false, "GiantBoard")
	world.giant_board = Vector3(board.x, ground_y(board) + 0.13, board.y)
	var pieces := [["king", true, Vector2(-6.2, 3.8)], ["queen", false, Vector2(6.2, 3.8)], ["rook", true, Vector2(-6.2, -0.5)],
		["knight", false, Vector2(6.2, -0.5)], ["pawn", true, Vector2(-5.0, 4.4)], ["pawn", false, Vector2(5.0, 4.4)]]
	for pc: Array in pieces:
		var pp: Vector2 = c + pc[2]
		add_mesh(PropModels.chess_piece(pc[0], pc[1]), pp, rng.randf() * TAU, 0.07)
		map.add_obstacle_circle(pp, 0.4, 1)
	add_label("Schachecke", Vector3(c.x, ground_y(c) + 2.2, c.y + 5.2), 0.0, 56)


func _shell_game() -> void:
	var c := ParkLayout.place("shell_game")
	var yaw := yaw_to(c, Vector2(0, 80))
	add_mesh(PropModels.folding_table(), c, yaw, 0.07, true, "ShellTable")
	map.add_obstacle_rect(c, Vector2(1.0, 0.6), -yaw, 1)
	world.shell_table = {"pos": Vector3(c.x, ground_y(c) + 0.07 + 0.82, c.y), "yaw": yaw}


func _dog_meadow() -> void:
	var area: Dictionary = ParkLayout.AREAS["dog_meadow"]
	var c: Vector2 = area["pos"]
	var half: Vector2 = area["size"] * 0.5
	var corners := [c + Vector2(-half.x, -half.y), c + Vector2(half.x, -half.y), c + Vector2(half.x, half.y), c + Vector2(-half.x, half.y)]
	var gate := Vector2(c.x - half.x, 55.0)
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var steps := int(length / 3.0)
		for k in steps:
			var p0 := a.lerp(b, float(k) / steps)
			var p1 := a.lerp(b, float(k + 1) / steps)
			if p0.lerp(p1, 0.5).distance_to(gate) < 1.6:
				continue
			var d := p1 - p0
			batch.add(PropModels.low_fence(d.length()), Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(p0.x, ground_y(p0), p0.y)))
			map.add_obstacle_segment(p0, p1, 0.4)
	for hp: Vector2 in [Vector2(60, 51), Vector2(67, 57)]:
		add_mesh(PropModels.agility_hurdle(), hp, 0.3, 0.0, true)
	add_mesh(PropModels.dog_tunnel(), Vector2(57, 61), 0.0, 0.0, true)
	new_bench(Vector2(52.5, 49.2), 0.6)
	new_bench(Vector2(71, 62.6), PI + 0.4)
	add_label("Hundewiese", Vector3(gate.x - 0.4, ground_y(gate) + 1.4, gate.y - 1.8), -PI / 2, 56)
	world.dog_meadow = Rect2(c - half + Vector2(1, 1), area["size"] - Vector2(2, 2))


func _grotto() -> void:
	var c := ParkLayout.place("grotto")
	for i in 11:
		var a := -PI * 0.15 + i * PI * 1.3 / 10.0
		var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(3.0, 3.8)
		var s := rng.randf_range(1.4, 2.4)
		batch.add(NatureModels.rock(i % 6), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 1.3, s)),
			Vector3(p.x, ground_y(p) - 0.2, p.y)))
		map.add_obstacle_circle(p, s * 0.7)
	for i in 9:
		var p := c + Vector2(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.8, 1.8))
		batch.add(NatureModels.mushroom(true), xform(p, rng.randf() * TAU, 0.0, rng.randf_range(0.8, 1.6)), false)
	world.grotto_pos = Vector3(c.x, ground_y(c), c.y)


func _picnic() -> void:
	var c := ParkLayout.place("picnic")
	var colors := [Color("d8463a"), Color("3a7fd8"), Color("3aa86b")]
	for i in 3:
		var p := c + Vector2(-5 + i * 5, -1 + (i % 2) * 3)
		var yaw := rng.randf_range(-0.4, 0.4)
		add_mesh(PropModels.picnic_blanket(colors[i]), p, yaw, 0.0, false)
		var b := Bench.new()
		b.bench_id = "blanket_%d" % i
		b.position = Vector3(p.x, ground_y(p), p.y)
		b.radius = 2.0
		for k in 2:
			var s := Seat.new()
			var off := right(yaw) * (-0.45 + k * 0.9)
			s.position = Vector3(p.x + off.x, ground_y(p) + 0.12, p.y + off.y)
			s.yaw = yaw + PI * k
			s.kind = "blanket"
			s.height = 0.12
			s.owner_id = b.bench_id
			b.seats.append(s)
		world.static_root.add_child(b)
		world.register_bench(b, false)


# --- Perimeter ---------------------------------------------------------------------

func _fence_and_gates() -> void:
	var half := ParkLayout.HALF
	var gates := {}
	for id: String in ["gate_n", "gate_s", "gate_w", "gate_e"]:
		gates[id] = ParkLayout.place(id)
	var culvert := Vector2(130, 88)
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var steps := int(length / 3.0)
		for k in steps:
			var p0 := a.lerp(b, float(k) / steps)
			var p1 := a.lerp(b, float(k + 1) / steps)
			var mid := p0.lerp(p1, 0.5)
			var skip := false
			for id: String in gates:
				if mid.distance_to(gates[id]) < 3.6:
					skip = true
			if mid.distance_to(culvert) < 4.5:
				skip = true
			if skip:
				continue
			var d := p1 - p0
			batch.add(PropModels.fence_segment(d.length()), Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(p0.x, 0.0, p0.y)))
		# Hedge just inside the fence.
		var inward := (Vector2.ZERO - a.lerp(b, 0.5)).normalized()
		var hsteps := int(length / 6.0)
		for k in hsteps:
			var p := a.lerp(b, (k + 0.5) / hsteps) + inward * 2.4
			var near_gate := false
			for id: String in gates:
				if p.distance_to(gates[id]) < 8.0:
					near_gate = true
			if near_gate or p.distance_to(culvert) < 7.0 or map.path_dist_at(p) < 1.5 or map.water_dist_at(p.x, p.y) < 1.5:
				continue
			var d2 := b - a
			batch.add(NatureModels.hedge(5.6), Transform3D(Basis(Vector3.UP, atan2(-d2.y, d2.x)), Vector3(p.x, ground_y(p) - 0.05, p.y)))
			map.add_obstacle_segment(p - d2.normalized() * 2.8, p + d2.normalized() * 2.8, 1.2)
	# Culvert where the creek leaves the park.
	var ck := MeshKit.new()
	ck.box(Vector3(0, 0.6, 0), Vector3(1.0, 1.6, 9.0), PropModels.STONE, PropModels.STONE_LIGHT)
	for z in range(-3, 4):
		ck.beam(Vector3(-0.55, -0.6, z * 0.6), Vector3(-0.55, 0.0, z * 0.6), Vector2(0.06, 0.06), PropModels.IRON)
	var cm := MeshInstance3D.new()
	cm.mesh = ck.commit()
	cm.position = Vector3(culvert.x + 0.5, ParkLayout.WATER_Y, culvert.y - 1.0)
	world.static_root.add_child(cm)
	for id: String in gates:
		var gp: Vector2 = gates[id]
		var yaw := 0.0 if id in ["gate_n", "gate_s"] else PI / 2
		var mi := MeshInstance3D.new()
		mi.mesh = PropModels.gate(5.0)
		mi.position = Vector3(gp.x, 0.0, gp.y)
		mi.rotation.y = yaw
		world.static_root.add_child(mi)
		var inward := (Vector2.ZERO - gp).normalized()
		for s: float in [-1.0, 1.0]:
			var n := Vector3(sin(yaw), 0, cos(yaw)) * 0.05 * s
			# The Waldtor reads NORDWALD from the park and STADTPARK from the forest.
			var text := "STADTPARK"
			if id == "gate_n" and n.z * inward.y > 0.0:
				text = "NORDWALD"
			add_label(text, Vector3(gp.x, 3.3, gp.y) + n, yaw + (0.0 if s > 0 else PI), 52, Color("f3ead2"), 0)
		if id == "gate_n":
			continue  # inner gate: no bicycles, and visitors do not arrive here
		var bp := gp + inward * 7.0 + Vector2(-inward.y, inward.x) * 3.2
		_info_board(bp, yaw_to(bp, bp - inward))
		for k in 3:
			var rp := gp + inward * 5.0 - Vector2(-inward.y, inward.x) * (3.4 + k * 0.7)
			batch.add(PropModels.bicycle([Color("c0392b"), Color("2e86de"), Color("8e44ad")][k]),
				Transform3D(Basis(Vector3.UP, atan2(inward.x, inward.y) + PI / 2), Vector3(rp.x, ground_y(rp), rp.y)))
		world.gates.append(Vector3(gp.x, 0.0, gp.y) + Vector3(inward.x, 0, inward.y) * 3.0)
		world.gate_outside.append(Vector3(gp.x, 0.0, gp.y) - Vector3(inward.x, 0, inward.y) * 4.0)


## The fence between park/Nordwald and the Oststadt is a wall for walkers, except at the
## Osttor and the forest gate east (until the town is loaded, everything east is solid anyway).
func _city_fence() -> void:
	var x := ParkLayout.CITY_EDGE
	var gaps := [ParkLayout.place("gate_e").y, ParkLayout.place("gate_forest_e").y]
	var z := ParkLayout.WORLD_MIN.y
	while z < ParkLayout.WORLD_MAX.y:
		var z1 := minf(z + 1.0, ParkLayout.WORLD_MAX.y)
		var mid := (z + z1) * 0.5
		if not gaps.any(func(g: float) -> bool: return absf(mid - g) < 2.4):
			map.add_obstacle_rect(Vector2(x, mid), Vector2(0.6, z1 - z), 0.0, 3)
		z = z1


## Rustic split-rail fence around the Nordwald, with forest gates in the west and east.
func _forest_fence() -> void:
	var lo := ParkLayout.WORLD_MIN
	var hi := ParkLayout.WORLD_MAX
	var edge := ParkLayout.FOREST_EDGE
	var gates := [ParkLayout.place("gate_forest"), ParkLayout.place("gate_forest_e")]
	var sides := [[Vector2(lo.x, edge), Vector2(lo.x, lo.y)], [Vector2(lo.x, lo.y), Vector2(hi.x, lo.y)],
		[Vector2(hi.x, lo.y), Vector2(hi.x, edge)]]
	for side: Array in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var steps := int(a.distance_to(b) / 3.0)
		for k in steps:
			var p0 := a.lerp(b, float(k) / steps)
			var p1 := a.lerp(b, float(k + 1) / steps)
			var mid := p0.lerp(p1, 0.5)
			if gates.any(func(g: Vector2) -> bool: return mid.distance_to(g) < 3.2) or Vegetation.in_mountain(mid, -2.0):
				continue
			var d := p1 - p0
			batch.add(PropModels.low_fence(d.length()), Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(p0.x, ground_y(p0), p0.y)))
	# Forest gates: two log posts and a sign. People of the Nordwald come and go here.
	for gate: Vector2 in gates:
		var kit := MeshKit.new()
		for s: float in [-1.0, 1.0]:
			kit.cylinder(Vector3(0, 0, s * 2.4), 2.8, 0.16, 0.14, 7, PropModels.WOOD_DARK)
		kit.beam(Vector3(0, 2.6, -2.6), Vector3(0, 2.6, 2.6), Vector2(0.18, 0.18), PropModels.WOOD_DARK)
		kit.box(Vector3(0, 2.15, 0), Vector3(0.08, 0.55, 2.6), PropModels.WOOD)
		add_mesh(kit.commit(), gate, 0.0)
		for s: float in [-1.0, 1.0]:
			add_label("NORDWALD", Vector3(gate.x + s * 0.06, ground_y(gate) + 2.15, gate.y), PI / 2 * s, 40, Color("f3ead2"), 6)
		var inward := -signf(gate.x)
		world.forest_entrances.append([Vector3(gate.x - inward * 4.0, 0.0, gate.y), Vector3(gate.x + inward * 3.0, 0.0, gate.y)])
	# The forest side of the Waldtor (for the farm shop next to it).
	var wt := ParkLayout.place("gate_n") + Vector2(0, -5)
	world.forest_entrances.append([Vector3(wt.x, 0.0, wt.y), Vector3(wt.x, 0.0, wt.y)])


## The dwarves' rock massif at the north edge; nobody can walk on it.
func _mountain() -> void:
	var c := ParkLayout.MOUNTAIN_CENTER
	var r := ParkLayout.MOUNTAIN_RADII
	var mi := MeshInstance3D.new()
	mi.name = "Mountain"
	mi.mesh = NatureModels.massif(r, 17.0, 7, 0.2)
	mi.position = Vector3(c.x, -1.0, c.y)
	world.static_root.add_child(mi)
	map.add_obstacle_ellipse(c, r + Vector2(1.0, 1.0))
	# A wider range behind it frames the north.
	# Wooded hills behind it frame the north.
	var range_kit := [[Vector2(-60, -335), Vector2(80, 45), 22.0, 11], [Vector2(-180, -300), Vector2(60, 50), 18.0, 12],
		[Vector2(180, -315), Vector2(70, 60), 26.0, 13], [Vector2(40, -370), Vector2(120, 55), 34.0, 14]]
	for m: Array in range_kit:
		var bg := MeshInstance3D.new()
		bg.mesh = NatureModels.massif(m[1], m[2], m[3], 0.75)
		bg.position = Vector3(m[0].x, -1.5, m[0].y)
		bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.static_root.add_child(bg)


func _info_board(p: Vector2, yaw: float) -> void:
	add_mesh(PropModels.info_board(), p, yaw, 0.0, true)
	map.add_obstacle_rect(p, Vector2(2.0, 0.4), -yaw, 1)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.7, 1.0)
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = MapImage.view_texture(map, MapImage.PARK_VIEW)
	mat.roughness = 0.9
	quad.material_override = mat
	quad.position = Vector3(p.x, ground_y(p) + 1.38, p.y) + Vector3(sin(yaw), 0, cos(yaw)) * 0.0
	quad.rotation.y = yaw
	quad.position += Vector3(sin(yaw), 0, cos(yaw)) * 0.02
	world.static_root.add_child(quad)
	world.info_boards.append(Vector3(p.x, ground_y(p), p.y) + Vector3(sin(yaw), 0, cos(yaw)) * 1.2)


# --- Benches, lamps, signs -----------------------------------------------------------

func _path_benches() -> void:
	var plaques := ["Für Mark – Bank frei!", "Hier saß einmal ein Eichhörnchen.", "Gestiftet vom Verein der Taubenfreunde",
		"Psst! Unter der Steinbrücke wohnt jemand.", "Zum Andenken an Opa Herbert (der noch lebt)",
		"Diese Bank ist frisch gestrichen. Seit 1998.", "Für alle, die mal kurz durchatmen wollen."]
	var plaque_index := 0
	for path: Dictionary in map.paths:
		if path["kind"] == "trail":
			continue
		var pts: PackedVector2Array = path["points"]
		var half: float = path["width"] * 0.5
		var dist := 0.0
		var next := 7.0
		var side := 1.0
		for i in range(1, pts.size()):
			dist += pts[i].distance_to(pts[i - 1])
			if dist < next:
				continue
			next = dist + 19.0
			var t := (pts[i] - pts[i - 1]).normalized()
			var n := Vector2(-t.y, t.x) * side
			side = -side
			var p := pts[i] + n * (half + 1.25)
			if not bench_spot_ok(p):
				p = pts[i] - n * (half + 1.25)
				if not bench_spot_ok(p):
					continue
			var plaque := ""
			if rng.randf() < 0.18 and plaque_index < plaques.size():
				plaque = plaques[plaque_index]
				plaque_index += 1
			new_bench(p, yaw_to(p, pts[i]), -1, plaque)
	# Pond shore benches with a view.
	for a: float in [0.6, 1.4, 2.6, 3.6, 4.6]:
		var p := ParkLayout.POND_CENTER + Vector2(cos(a), sin(a)) * (ParkLayout.POND_RADII + Vector2(5.5, 5.0))
		if bench_spot_ok(p, 6.0):
			new_bench(p, yaw_to(p, ParkLayout.POND_CENTER))
	# A bench on top of the sled hill.
	var hill := ParkLayout.place("sled_hill")
	new_bench(hill + Vector2(0, 2.5), PI * 0.85)


func _lamps_and_bins() -> void:
	for path: Dictionary in map.paths:
		if path["kind"] != "main":
			continue
		var pts: PackedVector2Array = path["points"]
		var half: float = path["width"] * 0.5
		var dist := 0.0
		var next := 5.0
		var side := 1.0
		for i in range(1, pts.size()):
			dist += pts[i].distance_to(pts[i - 1])
			if dist < next:
				continue
			var t := (pts[i] - pts[i - 1]).normalized()
			var n := Vector2(-t.y, t.x) * side
			var p := pts[i] + n * (half + 0.6)
			if map.water_dist_at(p.x, p.y) < 1.5 or not map.bridge_at(p).is_empty() or map.path_dist_at(p) < 0.1 or not ParkMap.in_park(p, 3.0):
				next = dist + 4.0
				continue
			next = dist + 24.0
			side = -side
			batch.add(PropModels.lamp(), xform(p, 0.0))
			map.add_obstacle_circle(p, 0.25, 1)
			world.lamps.append(Vector3(p.x, ground_y(p) + 3.5, p.y))
	var count := 0
	for b: Bench in world.benches.duplicate():
		if b.bench_id.begins_with("bench_") and count % 3 == 0:
			var r := Vector3(cos(b.rotation.y), 0, -sin(b.rotation.y))
			var p3 := b.position + r * 1.4
			var p := Vector2(p3.x, p3.z)
			if map.path_dist_at(p) > 0.2:
				batch.add(PropModels.bin(), xform(p, 0.0))
				map.add_obstacle_circle(p, 0.3, 1)
				world.bins.append(Vector3(p.x, ground_y(p), p.y))
		count += 1


func _signposts() -> void:
	var junctions := [Vector2(-3, 9), Vector2(-17, -58), Vector2(80, 8), Vector2(-66, 16), Vector2(5, 60),
		Vector2(-11, -19), Vector2(14, 17), Vector2(-54, 40), Vector2(78, -30), Vector2(0, -76), Vector2(0, 76)]
	var targets := ["pavilion", "fountain", "food_court", "playground", "minigolf", "boule", "chess", "dog_meadow",
		"great_meadow", "pier", "statue", "sled_hill", "gate_n", "gate_s", "gate_w", "gate_e"]
	for j: Vector2 in junctions:
		var p := j + Vector2(2.6, 2.6)
		for attempt in 8:
			if map.path_dist_at(p) > 0.4 and map.water_dist_at(p.x, p.y) > 2.0:
				break
			p = j + Vector2(cos(attempt * 0.8), sin(attempt * 0.8)) * 3.0
		var gy := ground_y(p)
		batch.add(PropModels.signpost(), xform(p, 0.0))
		map.add_obstacle_circle(p, 0.2, 1)
		var sorted := targets.duplicate()
		sorted.sort_custom(func(a: String, b: String) -> bool:
			return ParkLayout.place(a).distance_to(j) < ParkLayout.place(b).distance_to(j))
		var shown := 0
		for id: String in sorted:
			var tp := ParkLayout.place(id)
			if tp.distance_to(j) < 12.0:
				continue
			var d := (tp - j).normalized()
			var arrow_yaw := atan2(-d.y, d.x)
			var y := gy + 2.3 - shown * 0.33
			var arrow := MeshInstance3D.new()
			arrow.mesh = PropModels.sign_arrow()
			arrow.position = Vector3(p.x, y, p.y)
			arrow.rotation = Vector3(0, arrow_yaw, 0)
			world.static_root.add_child(arrow)
			# Text on both faces.
			var label_pos := Vector3(p.x, y, p.y) + Vector3(d.x, 0, d.y) * 0.62
			for s: float in [1.0, -1.0]:
				var n := Vector3(-d.y, 0, d.x) * 0.03 * s
				var l := add_label(ParkLayout.place_name(id), label_pos + n, atan2(-d.y, d.x) + (0.0 if s > 0 else PI), 26, Color("3a2a10"), 0)
				l.double_sided = false
			shown += 1
			if shown >= 3:
				break


# --- City around the park -----------------------------------------------------------

func _city() -> void:
	var half := ParkLayout.HALF
	var start := 24.0
	var colors := [Color("b5654a"), Color("c9a37a"), Color("8d8a85"), Color("a85a3c"), Color("d8c8a8"), Color("6f7a86"), Color("9b6b4f")]
	var kit := MeshKit.new()
	var east_kit := MeshKit.new()   # low houses like the Oststadt's, replaced when it loads
	for side in 4:
		if side == 0:
			continue  # the Nordwald is north of the park
		var along := (half.x + 40.0) if side < 2 else (half.y + 40.0)
		var x := -along if side < 2 else ParkLayout.FOREST_EDGE - 6.0
		while x < along:
			var w := rng.randf_range(14.0, 26.0)
			var depth := rng.randf_range(14.0, 22.0)
			var h := rng.randf_range(14.0, 34.0) if rng.randf() < 0.75 else rng.randf_range(40.0, 70.0)
			var pos: Vector3
			var size: Vector3
			match side:
				0:
					pos = Vector3(x + w * 0.5, 0, -(half.y + start + depth * 0.5))
					size = Vector3(w - 1.0, h, depth)
				1:
					pos = Vector3(x + w * 0.5, 0, half.y + start + depth * 0.5)
					# Low next to the Oststadt, so no tower looms over its streets.
					size = Vector3(w - 1.0, h if x < 90.0 else 6.0 + fmod(h, 4.0), depth)
				2:
					pos = Vector3(-(half.x + start + depth * 0.5), 0, x + w * 0.5)
					size = Vector3(depth, h, w - 1.0)
				3:
					pos = Vector3(half.x + start + depth * 0.5, 0, x + w * 0.5)
					size = Vector3(depth, 6.0 + fmod(h, 4.0), w - 1.0)
			PropModels.building_into(east_kit if side == 3 else kit, pos, size, colors[rng.randi() % colors.size()], rng.randi())
			x += w
	var mi := MeshInstance3D.new()
	mi.name = "City"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.static_root.add_child(mi)
	var em := MeshInstance3D.new()
	em.name = "EastCity"
	em.mesh = east_kit.commit()
	em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_east_city = em
	# Parked cars and street trees.
	var car_colors := [Color("f2c230"), Color("f2c230"), Color("c0392b"), Color("2c3e50"), Color("ecf0f1"), Color("2e86de"), Color("7f8c8d")]
	var lane := 5.0 + 2.5
	for side in range(1, 4):
		var length := (half.x if side < 2 else half.y) * 2.0
		var k := -length * 0.5 + 6.0
		while k < length * 0.5 - 6.0:
			var pos2: Vector2
			var yaw := 0.0
			match side:
				0: pos2 = Vector2(k, -(half.y + lane)); yaw = PI / 2
				1: pos2 = Vector2(k, half.y + lane); yaw = -PI / 2
				2: pos2 = Vector2(-(half.x + lane), k); yaw = 0.0
				3: pos2 = Vector2(half.x + lane, k); yaw = PI
			if rng.randf() < 0.55:
				(east_batch if side == 3 else batch).add(PropModels.car(car_colors[rng.randi() % car_colors.size()]), Transform3D(Basis(Vector3.UP, yaw), Vector3(pos2.x, 0.0, pos2.y)))
			k += rng.randf_range(6.0, 11.0)
		var t := -length * 0.5 + 10.0
		while t < length * 0.5 - 10.0:
			var tp: Vector2
			match side:
				0: tp = Vector2(t, -(half.y + 3.0))
				1: tp = Vector2(t, half.y + 3.0)
				2: tp = Vector2(-(half.x + 3.0), t)
				3: tp = Vector2(half.x + 3.0, t)
			var near_gate := false
			for g: Vector3 in world.gate_outside:
				if Vector2(g.x, g.z).distance_to(tp) < 8.0:
					near_gate = true
			if not near_gate:
				(east_batch if side == 3 else batch).add(NatureModels.tree("maple", rng.randi() % 3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(0.8, 0.8, 0.8)), Vector3(tp.x, 0.0, tp.y)))
			t += 14.0


## Dense trees outside the Nordwald fence (no obstacles, far visibility).
func _forest_backdrop() -> void:
	var lo := ParkLayout.WORLD_MIN
	var hi := ParkLayout.WORLD_MAX
	var kinds := ["fir", "pine", "fir", "oak", "birch"]
	var zones := [Rect2(lo.x - 70, lo.y - 50, 44, ParkLayout.FOREST_EDGE - lo.y + 40),
		Rect2(hi.x + 26, lo.y - 50, 44, ParkLayout.FOREST_EDGE - lo.y + 40),
		Rect2(lo.x - 26, lo.y - 40, hi.x - lo.x + 52, 34)]
	for zi in zones.size():
		var zone: Rect2 = zones[zi]
		var target := east_batch if zi == 1 else batch   # east of the forest: the Oststadt
		var n := int(zone.get_area() / 60.0)
		for i in n:
			var p := zone.position + Vector2(rng.randf(), rng.randf()) * zone.size
			if Vegetation.in_mountain(p, 2.0):
				continue
			var kind: String = kinds[rng.randi() % kinds.size()]
			var s := rng.randf_range(0.9, 1.4)
			target.add(NatureModels.tree(kind, rng.randi() % int(NatureModels.TREES[kind]["variants"])),
				Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, -0.05, p.y)))


# --- Seasonal decoration -------------------------------------------------------------

func _seasonal() -> void:
	var winter := Node3D.new()
	winter.name = "Winter"
	winter.add_to_group("season_3")
	var autumn := Node3D.new()
	autumn.name = "Autumn"
	autumn.add_to_group("season_2")
	world.static_root.add_child(winter)
	world.static_root.add_child(autumn)
	for p: Vector2 in [Vector2(28, -38), Vector2(84, -52), Vector2(-50, 24), Vector2(-20, 28)]:
		var mi := MeshInstance3D.new()
		mi.mesh = PropModels.snowman()
		mi.transform = xform(p, rng.randf_range(-0.5, 0.5))
		winter.add_child(mi)
	for p: Vector2 in [Vector2(3, 61), Vector2(10.5, 60.5), Vector2(-19, -47), Vector2(-14, -50), Vector2(-60, 26), Vector2(18, 28)]:
		for k in 3:
			var mi := MeshInstance3D.new()
			mi.mesh = PropModels.pumpkin(k)
			mi.transform = xform(p + Vector2(k * 0.6, (k % 2) * 0.5), rng.randf() * TAU)
			autumn.add_child(mi)
	for i in 14:
		var p := Vector2(rng.randf_range(-110, 110), rng.randf_range(-70, 70))
		if map.path_dist_at(p) > 1.0 and map.water_dist_at(p.x, p.y) > 2.0 and map.ground_at(p) == ParkMap.Ground.GRASS:
			var mi := MeshInstance3D.new()
			mi.mesh = PropModels.leaf_pile()
			mi.transform = xform(p, rng.randf() * TAU)
			autumn.add_child(mi)
	# Sleds on the hill in winter.
	var hill := ParkLayout.place("sled_hill")
	var sled := MeshKit.new()
	sled.box(Vector3(0, 0.25, 0), Vector3(0.45, 0.04, 1.0), PropModels.WOOD_LIGHT)
	for x: float in [-0.2, 0.2]:
		sled.beam(Vector3(x, 0.02, -0.55), Vector3(x, 0.02, 0.45), Vector2(0.03, 0.03), Color("c0392b"))
		sled.beam(Vector3(x, 0.02, 0.45), Vector3(x, 0.25, 0.55), Vector2(0.03, 0.03), Color("c0392b"))
		sled.beam(Vector3(x, 0.02, 0.0), Vector3(x, 0.25, 0.0), Vector2(0.03, 0.03), Color("c0392b"))
	var sm := sled.commit()
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.transform = xform(hill + Vector2(-4 + i * 3, 6 + i), 0.3 * i)
		winter.add_child(mi)

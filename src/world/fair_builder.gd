class_name FairBuilder
extends RefCounted
## Builds the Westpark from FairLayout and the ground FairMap wrote into the ParkMap: terrain,
## pond, paths and plazas, the rides (their moving parts go to the Fair node), halls, booths,
## food stands, the oases, benches, lamps and string lights, the fence with its gates, trees
## and flowers. Registers obstacles, seats and lamps with the World.

const G := ParkMap.Ground
const SIGN := Color("f3ead2")

## Booths: [kind, position, yaw, colour, sign]. North of the booth street they face south
## (yaw 0), south of it north (yaw PI).
const BOOTHS := [
	["cans", Vector2(-232, -3.6), 0.0, Color("e8442e"), "DOSENWERFEN"],
	["ducks", Vector2(-220, -3.6), 0.0, Color("2e86de"), "ENTENANGELN"],
	["rings", Vector2(-208, -3.6), 0.0, Color("27ae60"), "RINGWURF"],
	["darts", Vector2(-196, -3.6), 0.0, Color("8e44ad"), "BALLON-DARTS"],
	["moles", Vector2(-184, -3.6), 0.0, Color("e67e22"), "HAU DEN MAULWURF"],
	["wheel", Vector2(-232, 9.6), PI, Color("f2c230"), "GLÜCKSRAD"],
	["candy", Vector2(-218, 9.6), PI, Color("f28db2"), "ZUCKERWATTE"],
	["almonds", Vector2(-204, 9.6), PI, Color("b87333"), "GEBRANNTE MANDELN"],
	["lots", Vector2(-190, 9.6), PI, Color("1abc9c"), "LOSE"],
	["sausage", Vector2(-246, 66), PI, Color("c0392b"), "BRATWURST"],
	["crepes", Vector2(-226, 66), PI, Color("e2c050"), "CRÊPES"],
]

var world: World
var map: ParkMap
var fair: Fair
var root: Node3D
var batch := InstanceBatcher.new(65.0)
var trees_batch := InstanceBatcher.new(130.0)
var small_batch := InstanceBatcher.new(48.0)
var rng := RandomNumberGenerator.new()
var _bench_count := 0
var _tree_grid := {}


func _init(w: World, f: Fair, parent: Node3D) -> void:
	world = w
	map = w.map
	fair = f
	root = parent
	rng.seed = 8080


## Terrain, pond, paths and plazas.
func build_ground() -> void:
	var tb := TerrainBuilder.new(map)
	var ground := Node3D.new()
	ground.name = "Ground"
	root.add_child(ground)
	tb.build_chunks(ground, 0, ParkMap.PARK_X0, ParkMap.FAIR_Z0, ParkMap.H)
	root.add_child(tb.paths_mesh(FairMap.paths(map)))
	root.add_child(tb.plazas_mesh(FairLayout.PLAZAS, FairLayout.AREAS))
	_pond()


## Rides, halls, booths, oases, furniture, fence, trees.
func build_props() -> void:
	_ferris_wheel()
	_carousel()
	_chain_swing()
	_swing_boats()
	_coaster()
	_ghost_train()
	_bumper_cars()
	_arcade()
	_booths()
	_high_striker()
	_prize_counter()
	_magic_stage()
	_fortune_tent()
	_oases()
	_fence_and_gates()
	_path_benches()
	_lamps()
	_string_lights()
	_signs()
	_trees()
	_flowers_and_grass()
	batch.build(root, "FairProps")
	trees_batch.build(root, "FairTrees")
	small_batch.build(root, "FairPlants")


# --- Helpers ---------------------------------------------------------------------------

func gy(p: Vector2) -> float:
	return map.height_at(p.x, p.y)


func add(mesh: Mesh, p: Vector2, yaw := 0.0, y := 0.0, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, gy(p) + y, p.y))
	(parent if parent else root).add_child(mi)
	return mi


func node(name: String, p: Vector2, yaw := 0.0, y := 0.0, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, gy(p) + y, p.y))
	(parent if parent else root).add_child(n)
	return n


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
	l.visibility_range_end = 110.0
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	root.add_child(l)
	return l


static func fwd(yaw: float) -> Vector2:
	return Vector2(sin(yaw), cos(yaw))


static func right(yaw: float) -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


## Within `margin` of a named place, area or plaza of the Westpark.
static func near_place(p: Vector2, margin: float) -> bool:
	for id: String in FairLayout.PLACES:
		var pl: Dictionary = FairLayout.PLACES[id]
		if p.distance_to(pl["pos"]) < pl["r"] + margin:
			return true
	for key: String in FairLayout.AREAS:
		var a: Dictionary = FairLayout.AREAS[key]
		if ParkMap.in_rect(p, a["pos"], a["size"] + Vector2(margin, margin) * 2.0, a["rot"]):
			return true
	return false


func new_bench(p: Vector2, yaw: float, style := -1, oasis := "") -> Bench:
	_bench_count += 1
	var b := Bench.new()
	b.setup("fair_bench_%d" % _bench_count, Vector3(p.x, gy(p), p.y), yaw, 3, 0.47)
	b.oasis = oasis
	for s in b.seats:
		s.oasis = oasis
	root.add_child(b)
	batch.add(PropModels.bench(style if style >= 0 else rng.randi() % 3), Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, gy(p), p.y)))
	map.add_obstacle_rect(p, Vector2(1.9, 0.6), -yaw, 1)
	world.register_bench(b, false)
	world.fair_benches.append(b)
	return b


func _post(id: String, p: Vector2, yaw: float) -> void:
	fair.posts[id] = [Vector3(p.x, gy(p), p.y), yaw]


func _yaw_to(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(d.x, d.y)


# --- Water --------------------------------------------------------------------------------

func _pond() -> void:
	var kit := MeshKit.new()
	kit.use("water")
	var c := FairLayout.POND_CENTER
	var r := FairLayout.POND_RADII + Vector2(1.6, 1.6)
	var y := ParkLayout.WATER_Y
	var n := 36
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		kit.tri(Vector3(c.x, y, c.y), Vector3(c.x + cos(a1) * r.x, y, c.y + sin(a1) * r.y), Vector3(c.x + cos(a0) * r.x, y, c.y + sin(a0) * r.y), Color("3d8aa0"))
	var mi := MeshInstance3D.new()
	mi.name = "Pond"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	for i in 14:
		var a := rng.randf() * TAU
		var k := rng.randf_range(0.2, 0.8)
		var p := c + Vector2(cos(a) * FairLayout.POND_RADII.x, sin(a) * FairLayout.POND_RADII.y) * k
		small_batch.add(NatureModels.lily_pad(rng.randi() % 3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y + 0.02, p.y)), false, 80.0)
	for i in 18:
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a) * (FairLayout.POND_RADII.x + 0.8), sin(a) * (FairLayout.POND_RADII.y + 0.8))
		if map.path_dist_at(p) < 1.5:
			continue
		small_batch.add(NatureModels.reeds(rng.randi() % 3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, gy(p) - 0.05, p.y)), false, 60.0)


# --- Rides --------------------------------------------------------------------------------

func _ferris_wheel() -> void:
	var p := FairLayout.place("ferris_wheel")
	add(FairModels.ferris_frame(), p)
	map.add_obstacle_rect(p, Vector2(14.6, 7.8), 0.0)
	var hub := node("FerrisWheel", p, 0.0, FairModels.WHEEL_HUB)
	var wheel := MeshInstance3D.new()
	wheel.mesh = FairModels.ferris_wheel()
	hub.add_child(wheel)
	fair.wheel = wheel
	for i in FairModels.WHEEL_GONDOLAS:
		var g := MeshInstance3D.new()
		g.name = "Gondola_%d" % i
		g.mesh = FairModels.gondola(FairModels.COLORS[i % FairModels.COLORS.size()])
		hub.add_child(g)
		fair.gondolas.append(g)
	label("RIESENRAD", Vector3(p.x + 4.3, gy(p) + 3.0, p.y + 3.1), 0.0, 36)
	_post("ferris", p + Vector2(4.3, 4.6), 0.0)
	fair.spots["ferris_wheel"] = Vector3(p.x, gy(p), p.y + 6.0)


func _carousel() -> void:
	var p := FairLayout.place("carousel")
	add(FairModels.carousel_base(), p)
	map.add_obstacle_circle(p, 6.4)
	var top := node("Carousel", p)
	var mi := MeshInstance3D.new()
	mi.mesh = FairModels.carousel_top()
	top.add_child(mi)
	fair.carousel = top
	for i in 12:
		var a := TAU * i / 12
		var r := 4.6 if i % 2 == 0 else 3.3
		var h := MeshInstance3D.new()
		h.mesh = FairModels.carousel_horse(FairModels.COLORS[i % FairModels.COLORS.size()].lightened(0.15) if i % 3 else Color("f1eee6"))
		h.transform = Transform3D(Basis(Vector3.UP, a + PI), Vector3(cos(a) * r, 0.47, -sin(a) * r))
		top.add_child(h)
		fair.horses.append(h)
	label("KARUSSELL", Vector3(p.x, gy(p) + 7.2, p.y), 0.0, 48, SIGN, 10, true)
	fair.spots["carousel"] = Vector3(p.x, gy(p), p.y + 7.6)


func _chain_swing() -> void:
	var p := FairLayout.place("chain_swing")
	add(FairModels.chain_tower(), p)
	map.add_obstacle_circle(p, 7.0)
	# A low fence keeps the swinging seats free; the gap faces the Festplatz.
	var kit := MeshKit.new()
	for i in 24:
		var a0 := TAU * i / 24
		var a1 := TAU * (i + 1) / 24
		if absf(angle_difference((a0 + a1) * 0.5, 0.35)) < 0.3:
			continue
		var q0 := Vector3(cos(a0) * 7.8, 0, sin(a0) * 7.8)
		var q1 := Vector3(cos(a1) * 7.8, 0, sin(a1) * 7.8)
		kit.box(q0 + Vector3(0, 0.45, 0), Vector3(0.1, 0.9, 0.1), FairModels.WHITE)
		kit.beam(q0 + Vector3(0, 0.8, 0), q1 + Vector3(0, 0.8, 0), Vector2(0.06, 0.06), FairModels.RED)
	add(kit.commit(), p)
	var crown := node("ChainSwing", p, 0.0, FairModels.CHAIN_TOP)
	var mi := MeshInstance3D.new()
	mi.mesh = FairModels.chain_crown()
	crown.add_child(mi)
	fair.chain_crown = crown
	for i in FairModels.CHAIN_SEATS:
		var s := MeshInstance3D.new()
		s.mesh = FairModels.chain_seat(FairModels.COLORS[i % FairModels.COLORS.size()])
		crown.add_child(s)
		fair.chain_seats.append(s)
	fair.layout_chain_seats(0.0)
	label("KETTENKARUSSELL", Vector3(p.x, gy(p) + 10.2, p.y), 0.0, 44, SIGN, 10, true)
	fair.spots["chain_swing"] = Vector3(p.x + cos(0.35) * 8.6, gy(p), p.y + sin(0.35) * 8.6)


func _swing_boats() -> void:
	var p := FairLayout.place("swing_boat")
	add(FairModels.swing_frame(), p)
	map.add_obstacle_rect(p, Vector2(10.6, 9.0), 0.0)
	for k in 2:
		var x := -2.2 if k == 0 else 2.2
		var bar := node("SwingBoat_%d" % k, p + Vector2(x, 0), 0.0, FairModels.SWING_BAR)
		var mi := MeshInstance3D.new()
		mi.mesh = FairModels.swing_boat([FairModels.BLUE, FairModels.GREEN][k])
		bar.add_child(mi)
		fair.boats.append(bar)
	label("SCHIFFSCHAUKEL", Vector3(p.x, gy(p) + 7.4, p.y + 0.3), 0.0, 44)
	fair.spots["swing_boat"] = Vector3(p.x, gy(p), p.y + 5.4)


## The roller coaster: a closed track with a lift hill, a drop, a camel back and a turn,
## the station on the south side.
func _coaster() -> void:
	var c := FairLayout.place("coaster")
	var pts2 := [Vector2(-18, 13), Vector2(-24, 6), Vector2(-25, -4), Vector2(-20, -11), Vector2(-8, -12),
		Vector2(4, -10), Vector2(14, -12), Vector2(23, -8), Vector2(25, 2), Vector2(20, 10), Vector2(10, 13),
		Vector2(0, 13)]
	var heights := [1.4, 4.5, 9.5, 12.0, 5.0, 1.8, 6.5, 3.5, 2.2, 4.5, 1.6, 1.4]
	var smooth := ParkLayout.smooth(pts2, 1.0, true)
	# Heights along the smoothed line: interpolate by the nearest control points.
	var track := PackedVector3Array()
	var base := gy(c)
	for q in smooth:
		var best := 0
		var best_d := INF
		for i in pts2.size():
			var d := q.distance_to(pts2[i])
			if d < best_d:
				best_d = d
				best = i
		var j := (best + 1) % pts2.size()
		var i0 := (best - 1 + pts2.size()) % pts2.size()
		var dn: float = q.distance_to(pts2[j])
		var dp: float = q.distance_to(pts2[i0])
		var other := j if dn < dp else i0
		var t := best_d / maxf(0.01, best_d + q.distance_to(pts2[other]))
		var h: float = lerpf(heights[best], heights[other], smoothstep(0.0, 1.0, t))
		track.append(Vector3(c.x + q.x, base + h, c.y + q.y))
	var mi := MeshInstance3D.new()
	mi.name = "CoasterTrack"
	mi.mesh = FairModels.coaster_track(track)
	root.add_child(mi)
	fair.coaster_track = track
	var station := c + Vector2(0, 13)
	add(FairModels.coaster_station(), station)
	map.add_obstacle_rect(c + Vector2(0, -1), Vector2(56, 28), 0.0)
	map.add_obstacle_rect(station, Vector2(10.4, 3.4), 0.0)
	var train := Node3D.new()
	train.name = "CoasterTrain"
	root.add_child(train)
	for k in 3:
		var car := MeshInstance3D.new()
		car.mesh = FairModels.coaster_car([FairModels.YELLOW, FairModels.RED, FairModels.BLUE][k], k == 0)
		train.add_child(car)
		fair.coaster_cars.append(car)
	label("ACHTERBAHN", Vector3(station.x, gy(station) + 4.3, station.y + 1.95), 0.0, 52)
	fair.spots["coaster"] = Vector3(station.x, gy(station), station.y + 3.4)


func _ghost_train() -> void:
	var p := FairLayout.place("ghost_train")
	add(FairModels.ghost_train(), p)
	map.add_obstacle_rect(p, Vector2(26.4, 14.4), 0.0)
	map.add_obstacle_rect(p + Vector2(0, 10.0), Vector2(15.0, 5.6), 0.0)
	label("GEISTERBAHN", Vector3(p.x, gy(p) + 5.6, p.y + 7.12), 0.0, 120, Color("b8ff8a"))
	var car := MeshInstance3D.new()
	car.name = "GhostCar"
	car.mesh = FairModels.ghost_car(FairModels.PURPLE)
	root.add_child(car)
	fair.ghost_car = car
	fair.ghost_base = Vector3(p.x, gy(p), p.y)
	_post("ghost", p + Vector2(8.0, 13.6), 0.0)
	fair.spots["ghost_train"] = Vector3(p.x, gy(p), p.y + 13.4)


func _bumper_cars() -> void:
	var p := FairLayout.place("bumper_cars")
	add(FairModels.bumper_hall(), p)
	map.add_obstacle_rect(p, Vector2(28.4, 18.4), 0.0)
	for s: float in [-1.0, 1.0]:
		label("AUTOSCOOTER", Vector3(p.x, gy(p) + 5.4, p.y + s * 9.58), 0.0 if s > 0 else PI, 96, Color("fff3c0"))
	for i in 6:
		var sc := MeshInstance3D.new()
		sc.name = "Scooter_%d" % i
		sc.mesh = FairModels.scooter(FairModels.COLORS[i % FairModels.COLORS.size()])
		sc.position = Vector3(p.x - 10 + i * 4.0, gy(p) + 0.3, p.y + (2.0 if i % 2 else -2.0))
		root.add_child(sc)
		fair.scooters.append(sc)
	fair.scooter_rect = Rect2(p.x - 12.8, p.y - 7.8, 25.6, 15.6)
	_post("bumper", p + Vector2(15.0, 3.5), PI / 2)
	fair.spots["bumper_cars"] = Vector3(p.x + 15.6, gy(p), p.y)


func _arcade() -> void:
	var p := FairLayout.place("arcade")
	add(FairModels.arcade_hall(), p)
	# Walls (the front is open), cabinets.
	map.add_obstacle_rect(p + Vector2(0, -7.8), Vector2(24.0, 0.6), 0.0)
	map.add_obstacle_rect(p + Vector2(-11.8, 0), Vector2(0.6, 16.0), 0.0)
	map.add_obstacle_rect(p + Vector2(11.8, 0), Vector2(0.6, 16.0), 0.0)
	for i in 7:
		map.add_obstacle_rect(p + Vector2(-9.0 + i * 3.0, -7.0), Vector2(0.9, 0.9), 0.0)
	for i in 4:
		map.add_obstacle_rect(p + Vector2(-6.0 + i * 4.0, 0.0), Vector2(0.9, 0.9), 0.0)
	for x: float in [-4.0, 4.0]:
		map.add_obstacle_circle(p + Vector2(x, 7.7), 0.25)
	label("SPIELHALLE", Vector3(p.x, gy(p) + 6.3, p.y + 8.3), 0.0, 150, Color("ff9af0"))
	fair.spots["arcade"] = Vector3(p.x, gy(p), p.y + 9.5)


# --- Booths and stands ------------------------------------------------------------------

func _booths() -> void:
	for b: Array in BOOTHS:
		var p: Vector2 = b[1]
		var yaw: float = b[2]
		add(FairModels.booth(b[0], b[3]), p, yaw)
		fair.booth_deco[b[0]] = add(FairModels.booth_deco(b[0]), p, yaw)
		map.add_obstacle_rect(p, Vector2(5.0, 3.0), -yaw)
		var f := fwd(yaw)
		var sign_pos := p + f * 1.53
		var letters := float((b[4] as String).length())
		label(b[4], Vector3(sign_pos.x, gy(p) + 3.3, sign_pos.y), yaw, int(minf(0.42, 4.6 / (letters * 0.62)) / 0.004), Color("2a2a30"), 0)
		var counter := p + f * 2.4
		var vendor := p + f * 0.4
		fair.booths[b[0]] = {"pos": Vector3(counter.x, gy(counter), counter.y), "vendor": Vector3(vendor.x, gy(vendor), vendor.y),
			"yaw": yaw}
		fair.posts[b[0]] = [Vector3(vendor.x, gy(vendor), vendor.y), yaw]
	# Tables in the Schlemmergasse.
	var t := 0
	for tp: Vector2 in [Vector2(-246, 56), Vector2(-236, 56), Vector2(-226, 56), Vector2(-241, 61), Vector2(-231, 61)]:
		t += 1
		var y := gy(tp)
		batch.add(PropModels.picnic_table(), Transform3D(Basis(), Vector3(tp.x, y, tp.y)))
		map.add_obstacle_rect(tp, Vector2(2.0, 1.0), 0.0, 1)
		var b := Bench.new()
		b.bench_id = "fair_table_%d" % t
		b.position = Vector3(tp.x, y, tp.y)
		b.radius = 2.2
		for side: float in [-1.0, 1.0]:
			for x: float in [-0.5, 0.5]:
				var s := Seat.new()
				s.position = Vector3(tp.x + x, y + 0.46, tp.y + side * 0.75)
				s.yaw = 0.0 if side < 0 else PI
				s.owner_id = b.bench_id
				s.kind = "table"
				s.height = 0.46
				b.seats.append(s)
		root.add_child(b)
		world.register_bench(b, false)
		world.fair_benches.append(b)


func _high_striker() -> void:
	var p := FairLayout.place("high_striker")
	add(FairModels.high_striker(), p)
	map.add_obstacle_rect(p + Vector2(0, 0.3), Vector2(1.8, 2.0), 0.0)
	label("HAU DEN LUKAS", Vector3(p.x, gy(p) + 7.4, p.y), 0.0, 44, SIGN, 10, true)
	fair.spots["high_striker"] = Vector3(p.x + 0.2, gy(p), p.y + 2.4)
	_post("striker", p + Vector2(-1.6, 1.4), 0.0)


func _prize_counter() -> void:
	var p := FairLayout.place("prize_counter")
	add(FairModels.prize_counter(), p)
	map.add_obstacle_rect(p, Vector2(4.2, 2.6), 0.0)
	label("GEWINNAUSGABE", Vector3(p.x, gy(p) + 3.2, p.y + 1.33), 0.0, 44, Color("fff3c0"), 6)
	fair.booths["prizes"] = {"pos": Vector3(p.x, gy(p), p.y + 2.2), "vendor": Vector3(p.x, gy(p), p.y + 0.2), "yaw": 0.0}
	_post("prizes", p + Vector2(0, 0.2), 0.0)


func _magic_stage() -> void:
	var c := FairLayout.place("magic_stage")
	var p := c + Vector2(0, 4.0)
	add(FairModels.magic_stage(), p, PI)
	map.add_obstacle_rect(p, Vector2(7.2, 4.2), 0.0)
	label("ZAUBERBÜHNE", Vector3(p.x, gy(p) + 4.55, p.y - 1.76), PI, 56, Color("ffe08a"), 6)
	for x: float in [-2.2, 2.2]:
		new_bench(c + Vector2(x, -2.5), 0.0, 1)
	fair.spots["magic_stage"] = Vector3(c.x, gy(c), c.y - 0.5)
	# The magician stands on the stage (a raised floor for him, the stage is solid for others).
	map.platforms.append({"center": p, "radius": 1.9, "height": gy(p) + 0.8})
	fair.posts["stage"] = [Vector3(p.x, gy(p) + 0.8, p.y - 0.6), PI]


func _fortune_tent() -> void:
	var p := FairLayout.place("fortune_teller")
	add(FairModels.fortune_tent(), p, PI)
	map.add_obstacle_circle(p, 3.3)
	var sign := p + Vector2(2.6, -4.0)
	add(PropModels.signpost(), sign)
	label("Madame Esmeralda\nWahrsagerin", Vector3(sign.x, gy(sign) + 2.3, sign.y), PI, 32, Color("e8d0ff"), 6)
	fair.spots["fortune_teller"] = Vector3(p.x, gy(p), p.y - 3.9)
	_post("fortune", p + Vector2(0, 1.2), PI)


# --- Oases, furniture -------------------------------------------------------------------

func _oases() -> void:
	# Lichtergarten: fountain, benches round it, string lights.
	var lg := FairLayout.place("oasis_lights")
	add(PropModels.fountain(), lg)
	map.add_obstacle_circle(lg, 4.0)
	for k in 4:
		var a := TAU * k / 4 + PI / 4
		var bp := lg + Vector2(cos(a), sin(a)) * 6.0
		new_bench(bp, _yaw_to(bp, lg) + PI, 0, "oasis_lights")
	var poles := []
	for k in 6:
		var a := TAU * k / 6
		var pp := lg + Vector2(cos(a), sin(a)) * 8.4
		add(FairModels.light_pole(), pp)
		map.add_obstacle_circle(pp, 0.2, 1)
		poles.append(Vector3(pp.x, gy(pp) + 4.5, pp.y))
	var spans := []
	for k in 6:
		spans.append([poles[k], poles[(k + 1) % 6]])
		spans.append([poles[k], Vector3(lg.x, gy(lg) + 4.0, lg.y)])
	var lights := MeshInstance3D.new()
	lights.mesh = FairModels.light_strings(spans)
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lights)
	world.lamps.append(Vector3(lg.x, gy(lg) + 3.8, lg.y))
	# Teichufer: benches looking over the pond.
	var tu := FairLayout.place("oasis_pond")
	for x: float in [-5.0, 0.0, 5.0]:
		new_bench(tu + Vector2(x, 0.6 + absf(x) * 0.15), PI, 1, "oasis_pond")
	# Lindenhain: a ring of big trees with benches under them.
	var lh := FairLayout.place("oasis_limes")
	for k in 6:
		var a := TAU * k / 6 + 0.3
		_plant(["chestnut", "maple"][k % 2], lh + Vector2(cos(a), sin(a)) * 7.5, 1.25)
	for a: float in [0.0, PI * 0.66, PI * 1.33]:
		var bp := lh + Vector2(cos(a), sin(a)) * 3.2
		new_bench(bp, _yaw_to(bp, lh) + PI, 1, "oasis_limes")
	small_batch.add(PropModels.lamp(), Transform3D(Basis(), Vector3(lh.x, gy(lh), lh.y)))
	map.add_obstacle_circle(lh, 0.25, 1)
	world.lamps.append(Vector3(lh.x, gy(lh) + 3.5, lh.y))
	# Rosenlaube: a bench under the rose arbour, two more beside it.
	var rl := FairLayout.place("oasis_roses")
	add(FairModels.rose_arbour(), rl)
	new_bench(rl + Vector2(0, -0.5), 0.0, 0, "oasis_roses")
	for x: float in [-4.0, 4.0]:
		new_bench(rl + Vector2(x, 0.5), 0.0, 1, "oasis_roses")
	# Bankrunde am Riesenrad: a flower bed with benches round it.
	var bw := FairLayout.place("oasis_wheel")
	var kit := MeshKit.new()
	kit.cylinder(Vector3.ZERO, 0.4, 1.5, 1.5, 12, PropModels.STONE, true, Color("5a3a2a"))
	add(kit.commit(), bw)
	map.add_obstacle_circle(bw, 1.5)
	for i in 12:
		var a := TAU * i / 12
		small_batch.add(NatureModels.flower(i % 4), Transform3D(Basis(), Vector3(bw.x + cos(a) * 0.9, gy(bw) + 0.4, bw.y + sin(a) * 0.9)), false, 50.0)
	for k in 4:
		var a := TAU * k / 4 + PI / 4
		var bp := bw + Vector2(cos(a), sin(a)) * 3.0
		new_bench(bp, _yaw_to(bw, bp), 0, "oasis_wheel")
	# A small sign at every oasis.
	for id: String in FairLayout.oases():
		var p := FairLayout.place(id)
		var sp := p + Vector2(0, FairLayout.PLACES[id]["r"] - 0.5)
		var kit2 := MeshKit.new()
		kit2.cylinder(Vector3.ZERO, 1.1, 0.05, 0.05, 5, PropModels.WOOD_DARK)
		kit2.box(Vector3(0, 1.1, 0), Vector3(1.4, 0.35, 0.06), Color("2e5e44"))
		add(kit2.commit(), sp)
		label(FairLayout.place_name(id), Vector3(sp.x, gy(sp) + 1.1, sp.y + 0.04), 0.0, 24, SIGN, 4)
		label(FairLayout.place_name(id), Vector3(sp.x, gy(sp) + 1.1, sp.y - 0.04), PI, 24, SIGN, 4)
		fair.oases[id] = Vector3(p.x, gy(p), p.y)


func _fence_and_gates() -> void:
	var lo := ParkLayout.FAIR_MIN
	var hi := ParkLayout.FAIR_MAX
	var gates := [FairLayout.place("gate_fair_w"), FairLayout.place("gate_fair_s")]
	var sides := [[Vector2(lo.x, lo.y), Vector2(lo.x, hi.y), true], [Vector2(lo.x, hi.y), Vector2(hi.x, hi.y), true],
		[Vector2(hi.x, lo.y), Vector2(lo.x, lo.y), false]]
	for side: Array in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var iron: bool = side[2]
		var steps := int(a.distance_to(b) / 3.0)
		var inward := Vector2(-(b - a).normalized().y, (b - a).normalized().x)
		if inward.dot(Vector2(-260, 0) - a) < 0.0:
			inward = -inward
		for k in steps:
			var p0 := a.lerp(b, float(k) / steps)
			var p1 := a.lerp(b, float(k + 1) / steps)
			var mid := p0.lerp(p1, 0.5)
			if gates.any(func(g: Vector2) -> bool: return mid.distance_to(g) < 3.6):
				continue
			var d := p1 - p0
			var mesh := PropModels.fence_segment(d.length()) if iron else PropModels.low_fence(d.length())
			batch.add(mesh, Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(p0.x, gy(p0) if not iron else 0.0, p0.y)))
		if not iron:
			continue
		var hsteps := int(a.distance_to(b) / 6.0)
		for k in hsteps:
			var p := a.lerp(b, (k + 0.5) / hsteps) + inward * 2.4
			if gates.any(func(g: Vector2) -> bool: return p.distance_to(g) < 8.0) or map.path_dist_at(p) < 1.5:
				continue
			var d2 := b - a
			batch.add(NatureModels.hedge(5.6), Transform3D(Basis(Vector3.UP, atan2(-d2.y, d2.x)), Vector3(p.x, gy(p) - 0.05, p.y)))
			map.add_obstacle_segment(p - d2.normalized() * 2.8, p + d2.normalized() * 2.8, 1.2)
	for gp: Vector2 in gates:
		var west := gp.x < lo.x + 1.0
		var yaw := PI / 2 if west else 0.0
		var mi := MeshInstance3D.new()
		mi.mesh = PropModels.gate(5.0)
		mi.position = Vector3(gp.x, 0.0, gp.y)
		mi.rotation.y = yaw
		root.add_child(mi)
		var inward := Vector2(1, 0) if west else Vector2(0, -1)
		for s: float in [-1.0, 1.0]:
			var n := Vector3(sin(yaw), 0, cos(yaw)) * 0.05 * s
			label("WESTPARK", Vector3(gp.x, 3.3, gp.y) + n, yaw + (0.0 if s > 0 else PI), 52, SIGN, 0)
		world.fair_entrances.append([Vector3(gp.x - inward.x * 4.0, 0.0, gp.y - inward.y * 4.0), Vector3(gp.x + inward.x * 3.0, 0.0, gp.y + inward.y * 3.0)])


func _path_benches() -> void:
	for path: Dictionary in FairMap.paths(map):
		if path["kind"] == "trail":
			continue
		var pts: PackedVector2Array = path["points"]
		var half: float = path["width"] * 0.5
		var dist := 0.0
		var next := 8.0
		var side := 1.0
		for i in range(1, pts.size()):
			dist += pts[i].distance_to(pts[i - 1])
			if dist < next:
				continue
			next = dist + 17.0
			var t := (pts[i] - pts[i - 1]).normalized()
			var n := Vector2(-t.y, t.x) * side
			side = -side
			var p := pts[i] + n * (half + 1.3)
			if not _bench_ok(p):
				next = dist + 4.0
				continue
			new_bench(p, _yaw_to(p, pts[i]))


func _bench_ok(p: Vector2) -> bool:
	if not ParkMap.in_fair(p, 6.0) or map.water_dist_at(p.x, p.y) < 2.5 or map.path_dist_at(p) < 0.4:
		return false
	if near_place(p, 1.5):
		return false
	for b: Bench in world.fair_benches:
		if Vector2(b.position.x, b.position.z).distance_to(p) < 8.0:
			return false
	var c := ParkMap.to_cell(p)
	return map.solid[c.y * ParkMap.W + c.x] == 0


func _lamps() -> void:
	for path: Dictionary in FairMap.paths(map):
		if path["kind"] == "trail":
			continue
		var pts: PackedVector2Array = path["points"]
		var half: float = path["width"] * 0.5
		var dist := 0.0
		var next := 6.0
		var side := -1.0
		for i in range(1, pts.size()):
			dist += pts[i].distance_to(pts[i - 1])
			if dist < next:
				continue
			var t := (pts[i] - pts[i - 1]).normalized()
			var p := pts[i] + Vector2(-t.y, t.x) * side * (half + 0.6)
			var c := ParkMap.to_cell(p)
			if not ParkMap.in_fair(p, 3.0) or map.solid[c.y * ParkMap.W + c.x] != 0 or near_place(p, 0.5) or map.path_dist_at(p) < 0.1:
				next = dist + 4.0
				continue
			next = dist + 26.0
			side = -side
			batch.add(PropModels.lamp(), Transform3D(Basis(), Vector3(p.x, gy(p), p.y)))
			map.add_obstacle_circle(p, 0.25, 1)
			world.lamps.append(Vector3(p.x, gy(p) + 3.5, p.y))


## Poles with strings of bulbs along the booth street and round the Festplatz.
func _string_lights() -> void:
	var spans := []
	var north := []
	var south := []
	for i in 6:
		var x := -238.0 + i * 12.0
		for side: int in [0, 1]:
			var p := Vector2(x, -1.6 if side == 0 else 7.6)
			batch.add(FairModels.light_pole(), Transform3D(Basis(), Vector3(p.x, gy(p), p.y)))
			map.add_obstacle_circle(p, 0.2, 1)
			(north if side == 0 else south).append(Vector3(p.x, gy(p) + 4.5, p.y))
	for i in 6:
		spans.append([north[i], south[i]])
		if i < 5:
			spans.append([north[i], south[i + 1]])
			spans.append([south[i], north[i + 1]])
	var c := FairLayout.place("fest_square")
	var ring := []
	for k in 10:
		var a := TAU * k / 10 + 0.1
		var p := c + Vector2(cos(a), sin(a)) * 21.0
		if absf(p.y - FairLayout.place("ferris_wheel").y) < 5.0 and absf(p.x - c.x) < 9.0:
			continue
		batch.add(FairModels.light_pole(), Transform3D(Basis(), Vector3(p.x, gy(p), p.y)))
		map.add_obstacle_circle(p, 0.2, 1)
		ring.append(Vector3(p.x, gy(p) + 4.5, p.y))
	for k in ring.size():
		spans.append([ring[k], ring[(k + 1) % ring.size()]])
	var mi := MeshInstance3D.new()
	mi.name = "StringLights"
	mi.mesh = FairModels.light_strings(spans)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	for p: Vector3 in [Vector3(-226, 0, 3), Vector3(-202, 0, 3), Vector3(c.x, 0, c.y + 14)]:
		world.lamps.append(Vector3(p.x, gy(Vector2(p.x, p.z)) + 3.8, p.z))


func _signs() -> void:
	var p := Vector2(-138, -1.0)
	add(FairModels.fair_sign(), p, 0.0)
	map.add_obstacle_circle(p, 0.2, 1)
	for s: float in [-1.0, 1.0]:
		label("KIRMES", Vector3(p.x, gy(p) + 2.2, p.y + s * 0.07), 0.0 if s > 0 else PI, 36, Color("2a2a30"), 0)


# --- Plants ------------------------------------------------------------------------------

func _free_for_tree(p: Vector2, trunk: float, gap: float) -> bool:
	if not ParkMap.in_fair(p, 5.0):
		return false
	if map.path_dist_at(p) < trunk + 1.6 or map.water_dist_at(p.x, p.y) < 1.2:
		return false
	var c := ParkMap.to_cell(p)
	if map.solid[c.y * ParkMap.W + c.x] != 0:
		return false
	var kind := map.ground_at(p)
	if kind != G.GRASS and kind != G.BANK:
		return false
	if near_place(p, 2.0):
		return false
	for m: Dictionary in FairLayout.MEADOWS:
		if ((p - m["pos"]) / m["radii"]).length() < 1.0:
			return false
	for b: Bench in world.fair_benches:
		if Vector2(b.position.x, b.position.z).distance_to(p) < 2.5:
			return false
	var c9 := Vector2i(floori(p.x / 9.0), floori(p.y / 9.0))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for q: Vector2 in _tree_grid.get(c9 + Vector2i(dx, dz), []):
				if q.distance_to(p) < gap:
					return false
	return true


func _plant(kind: String, p: Vector2, scale := 1.0) -> void:
	var info: Dictionary = NatureModels.TREES[kind]
	var y := gy(p)
	trees_batch.add(NatureModels.tree(kind, rng.randi() % int(info["variants"])),
		Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale, scale)), Vector3(p.x, y - 0.05, p.y)), true, 260.0)
	var trunk: float = info["trunk"] * scale
	map.add_obstacle_circle(p, trunk + 0.15)
	world.fair_trees.append({"pos": p, "kind": kind, "trunk": trunk, "ground": y})
	var c9 := Vector2i(floori(p.x / 9.0), floori(p.y / 9.0))
	if not _tree_grid.has(c9):
		_tree_grid[c9] = []
	_tree_grid[c9].append(p)


func _tree_kind(p: Vector2) -> String:
	if map.water_dist_at(p.x, p.y) < 7.0:
		return "willow" if rng.randf() < 0.6 else "birch"
	if p.x > -190.0:
		return ["oak", "maple", "cherry", "birch", "chestnut"][rng.randi() % 5]
	if p.y < -40.0 or p.x < -360.0:
		return ["oak", "chestnut", "birch", "pine", "maple"][rng.randi() % 5]
	return ["chestnut", "maple", "oak", "cherry"][rng.randi() % 4]


func _trees() -> void:
	var lo := ParkLayout.FAIR_MIN
	var hi := ParkLayout.FAIR_MAX
	# Chestnuts along the booth street and the main path.
	for x in range(-176, -132, 9):
		for s: float in [-1.0, 1.0]:
			var p := Vector2(float(x), 4.0 + s * 5.5)
			if _free_for_tree(p, 0.4, 4.0):
				_plant("chestnut", p, rng.randf_range(0.95, 1.15))
	var target := world.fair_trees.size() + 230
	for i in 9000:
		if world.fair_trees.size() >= target:
			break
		var p := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		# Denser along the fence and in the quiet east, open round the rides.
		var edge := minf(minf(p.x - lo.x, hi.x - p.x), minf(p.y - lo.y, hi.y - p.y))
		var gap := 6.5 if edge < 16.0 or p.x > -190.0 else 16.0
		var kind := _tree_kind(p)
		if not _free_for_tree(p, NatureModels.TREES[kind]["trunk"], gap):
			continue
		_plant(kind, p, rng.randf_range(0.85, 1.2))


func _flowers_and_grass() -> void:
	var lo := ParkLayout.FAIR_MIN
	var hi := ParkLayout.FAIR_MAX
	var placed := 0
	for i in 1800:
		if placed > 160:
			break
		var p := Vector2(rng.randf_range(lo.x + 4, hi.x - 4), rng.randf_range(lo.y + 4, hi.y - 4))
		if map.path_dist_at(p) < 1.2 or not _free_for_tree(p, 0.8, 1.8):
			continue
		var s := rng.randf_range(0.8, 1.3)
		small_batch.add(NatureModels.bush(rng.randi() % 5, rng.randf() < 0.4), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
			Vector3(p.x, gy(p) - 0.1, p.y)), true, 140.0)
		map.add_obstacle_circle(p, 0.7 * s, 1)
		placed += 1
	# Flower beds at the oases and along the main path.
	for id: String in FairLayout.oases():
		var c := FairLayout.place(id)
		for k in 18:
			var a := rng.randf() * TAU
			var r := rng.randf_range(FairLayout.PLACES[id]["r"] + 0.5, FairLayout.PLACES[id]["r"] + 3.0)
			var p := c + Vector2(cos(a), sin(a)) * r
			if map.ground_at(p) != G.GRASS or map.path_dist_at(p) < 0.5:
				continue
			small_batch.add(NatureModels.flower(rng.randi() % 4), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, gy(p), p.y)), false, 50.0)
	for i in 2600:
		var p := Vector2(rng.randf_range(lo.x + 2, hi.x - 2), rng.randf_range(lo.y + 2, hi.y - 2))
		if map.ground_at(p) != G.GRASS or map.path_dist_at(p) < 0.3:
			continue
		var s := rng.randf_range(0.9, 1.5)
		var mesh := NatureModels.grass_tuft(rng.randi() % 4) if rng.randf() < 0.85 else NatureModels.flower(rng.randi() % 4)
		small_batch.add(mesh, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, gy(p) - 0.02, p.y)), false, 45.0)

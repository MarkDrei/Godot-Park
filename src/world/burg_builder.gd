class_name BurgBuilder
extends WorldBuilder
## Builds the Ritterburg (doc/burg.md) when it is loaded: terrain, paths and plazas, the walls
## with towers and the gate house, the rock behind, the exhibition hall and the lookout tower,
## the tavern, the smithy, the stalls of the market, the tournament ground (lists, stands,
## paddock and stable, sword ring, tug pitch, archery range), the stage, the puppet theatre,
## the magician's corner, torches, banners, fences, gates, benches and trees.

const G := ParkMap.Ground
## The stalls of the market: [id, position, kind (BurgModels.stall), awning colour, sign].
## They face the nearest path.
const STALLS := [
	["herb_witch", Vector2(-334, -181), "herbs", Color("3f7a45"), "KRÄUTER"],
	["alchemist", Vector2(-195, -184), "potions", Color("4a2a66"), "ALCHEMIE"],
	["pig", Vector2(-298, -171), "food", Color("b8322a"), "SPANFERKEL"],
	["honey", Vector2(-334, -197), "food", Color("d9b44a"), "HONIGKUCHEN"],
	["fish", Vector2(-200, -199), "food", Color("2f5fa8"), "RÄUCHERFISCH"],
	["dice", Vector2(-238, -189), "dice", Color("7a4a8a"), "WÜRFEL"],
]

var burg: Burg
var batch := InstanceBatcher.new(65.0)
var trees_batch := InstanceBatcher.new(130.0)
var small_batch := InstanceBatcher.new(48.0)
var planter: TreePlanter
var _flames := MeshKit.new()
var _static := MeshKit.new()     # the single models merged (_put): one draw call per surface
var _bench_count := 0


func _init(w: World, b: Burg, parent: Node3D) -> void:
	super(w, parent, 6161)
	burg = b
	planter = TreePlanter.new(map, rng, trees_batch, _keeps_out, [world.burg_benches])


## Terrain, paths and plazas.
func build_ground() -> void:
	var tb := TerrainBuilder.new(map)
	var ground := Node3D.new()
	ground.name = "Ground"
	root.add_child(ground)
	tb.build_chunks(ground, 0, ParkMap.PARK_X0, 0, ParkMap.FAIR_Z0)
	root.add_child(tb.paths_mesh(BurgMap.paths(map)))
	root.add_child(tb.plazas_mesh(BurgLayout.PLAZAS, BurgLayout.AREAS))


## Walls, buildings, the market, the tournament ground, furniture, trees.
func build_props() -> void:
	_walls()
	_rock()
	_top()
	_tavern()
	_smithy()
	_stalls()
	_campfire()
	_square()
	_tournament()
	_gates_and_fences()
	_posts()
	_torches()
	_trees()
	_flowers()
	batch.build(root, "BurgProps")
	trees_batch.build(root, "BurgTrees")
	small_batch.build(root, "BurgPlants")
	var sm := MeshInstance3D.new()
	sm.name = "BurgStatic"
	sm.mesh = _static.commit()
	root.add_child(sm)
	var fm := MeshInstance3D.new()
	fm.name = "TorchFlames"
	fm.mesh = _flames.commit()
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fm)
	burg.flames = fm


# --- Helpers ---------------------------------------------------------------------------

## Within `margin` of a named place, area or plaza of the castle.
static func near_place(p: Vector2, margin: float) -> bool:
	for id: String in BurgLayout.PLACES:
		var pl: Dictionary = BurgLayout.PLACES[id]
		if p.distance_to(pl["pos"]) < pl["r"] + margin:
			return true
	for key: String in BurgLayout.AREAS:
		var a: Dictionary = BurgLayout.AREAS[key]
		if ParkMap.in_rect(p, a["pos"], a["size"] + Vector2(margin, margin) * 2.0, a["rot"]):
			return true
	return false


func new_bench(p: Vector2, yaw: float, y := -1.0, style := 1, draw := true) -> Bench:
	_bench_count += 1
	var h := gy(p) if y < 0.0 else y
	var b := place_bench("burg_bench_%d" % _bench_count, Vector3(p.x, h, p.y), yaw)
	if draw:
		batch.add(PropModels.bench(style), Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, h, p.y)))
		map.add_obstacle_rect(p, Vector2(1.9, 0.6), -yaw, ParkMap.BLOCK_PEOPLE)
	world.burg_benches.append(b)
	return b


## The yaw facing from p to the nearest point of the castle's paths.
func face_path(p: Vector2) -> float:
	var best := Vector2.INF
	for path: Dictionary in BurgMap.paths(map):
		for q: Vector2 in path["points"]:
			if q.distance_squared_to(p) < best.distance_squared_to(p):
				best = q
	return yaw_to(p, best)


## A model on the ground at p, merged into the castle's static mesh.
func _put(mesh: Mesh, p: Vector2, yaw := 0.0, y := 0.0) -> void:
	_static.add_mesh(mesh, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, gy(p) + y, p.y)))


func _torch(p: Vector2, y := 0.0, wall := false, yaw := 0.0) -> void:
	var base := Vector3(p.x, (gy(p) if y == 0.0 else y), p.y)
	batch.add(BurgModels.torch(wall), Transform3D(Basis(Vector3.UP, yaw), base))
	BurgModels.flames_into(_flames, base + Vector3(0, BurgModels.TORCH_Y - 0.05, 0))
	world.lamps.append(base + Vector3(0, BurgModels.TORCH_Y + 0.4, 0))
	if not wall:
		map.add_obstacle_circle(p, 0.2, ParkMap.BLOCK_PEOPLE)


# --- Walls and rock -----------------------------------------------------------------------

## The walls as one masonry mesh, stepped every 2 m with the ground on both sides, battlements
## on top; round towers at the corners; the gate house and the inner gate.
func _walls() -> void:
	var kit := MeshKit.new()
	kit.use("masonry")
	var t := BurgLayout.WALL_THICK
	for seg: Array in BurgMap.walls():
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var d := b - a
		var n := maxi(1, int(ceil(d.length() / 2.0)))
		var side := Vector2(-d.y, d.x).normalized() * (t * 0.5 + 0.8)
		for k in n:
			var p0 := a + d * float(k) / n
			var p1 := a + d * float(k + 1) / n
			var mid := (p0 + p1) * 0.5
			var lo := minf(gy(mid + side), gy(mid - side))
			var hi := maxf(gy(mid + side), gy(mid - side))
			var top := hi + 4.2
			var len := p0.distance_to(p1) + 0.05
			kit.push(Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(mid.x, 0, mid.y)))
			kit.box(Vector3(0, (lo - 1.0 + top) * 0.5, 0), Vector3(len, top - lo + 1.0, t), BurgModels.STONE)
			kit.box(Vector3(0, top + 0.08, 0), Vector3(len, 0.16, t + 0.25), BurgModels.STONE_LIGHT)
			for s: float in [-1.0, 1.0]:
				kit.box(Vector3(0, top + 0.6, s * (t * 0.5 - 0.15)), Vector3(len * 0.55, 0.9, 0.3), BurgModels.STONE_LIGHT)
			kit.pop()
	var mi := MeshInstance3D.new()
	mi.name = "Walls"
	mi.mesh = kit.commit()
	root.add_child(mi)
	var w := BurgLayout.WALL_W
	var e := BurgLayout.WALL_E
	for c: Vector2 in [Vector2(w, BurgLayout.WALL_S), Vector2(e, BurgLayout.WALL_S), Vector2(w, BurgLayout.INNER_Z),
			Vector2(e, BurgLayout.INNER_Z), Vector2(w, BurgLayout.ROCK_Z + 2.0), Vector2(e, BurgLayout.ROCK_Z + 2.0)]:
		var h := maxf(gy(c + Vector2(4, 4)), gy(c - Vector2(4, 4)))
		var tower := BurgModels.round_tower(3.4, h + 8.0 - gy(c))
		_put(tower, c)
		map.add_obstacle_circle(c, 3.6)
	# Gate house in the outer wall, the inner gate in the inner wall.
	var gh := BurgLayout.place("gatehouse")
	_put(BurgModels.gatehouse(BurgLayout.GATE_HALF * 2.0, 4.0), gh)
	for s: float in [-1.0, 1.0]:
		map.add_obstacle_rect(gh + Vector2(s * (BurgLayout.GATE_HALF + 2.1), 0), Vector2(4.2, 5.2), 0.0)
	label("RITTERBURG", Vector3(gh.x, gy(gh) + 7.4, gh.y + 2.02), 0.0, 110, BurgModels.GOLD, 12)
	var ig := BurgLayout.place("inner_gate")
	var iy := gy(ig + Vector2(0, -4))
	_static.add_mesh(BurgModels.gatehouse(BurgLayout.INNER_GATE_HALF * 2.0, 3.0), Transform3D(Basis(), Vector3(ig.x, iy - 0.5, ig.y)))
	for s: float in [-1.0, 1.0]:
		map.add_obstacle_rect(ig + Vector2(s * (BurgLayout.INNER_GATE_HALF + 2.1), 0), Vector2(4.2, 4.2), 0.0)


## Rocks behind the castle and along the north, the hill turning into the mountain.
func _rock() -> void:
	var prng := part_rng(4141)
	var x := ParkLayout.BURG_MIN.x - 4.0
	var i := 0
	while x < ParkLayout.BURG_MAX.x + 4.0:
		var r := Vector2(prng.randf_range(9.0, 14.0), prng.randf_range(6.0, 9.0))
		var behind := x > BurgLayout.WALL_W - 8.0 and x < BurgLayout.WALL_E + 8.0
		var p := Vector2(x, (BurgLayout.ROCK_Z - 5.0 if behind else -271.0) - prng.randf_range(0.0, 3.0))
		var rock := NatureModels.massif(r, prng.randf_range(11.0, 17.0), 30 + i % 7, 0.12)
		_static.add_mesh(rock, Transform3D(Basis(Vector3.UP, prng.randf_range(-0.3, 0.3)), Vector3(p.x, gy(Vector2(p.x, maxf(p.y, -269.0))) - 2.5, p.y)))
		x += r.x * 1.3
		i += 1
	_static.add_mesh(NatureModels.massif(Vector2(110, 26), 26.0, 21, 0.25), Transform3D(Basis(), Vector3(-262, 4.0, -292)))


# --- Buildings ----------------------------------------------------------------------------

## The top: the exhibition hall, the lookout tower, the secret door in the rock, armour and
## shields on display in front of the hall.
func _top() -> void:
	var ex := BurgLayout.place("exhibition")
	_put(BurgModels.hall(26.0, 11.0), ex)
	map.add_obstacle_rect(ex, Vector2(26.4, 11.4), 0.0)
	label("RITTERAUSSTELLUNG", Vector3(ex.x, gy(ex) + 6.6, ex.y + 5.62), 0.0, 90, BurgModels.GOLD, 10)
	var cols := [BurgModels.RED, BurgModels.BLUE, BurgModels.GOLD, BurgModels.GREEN]
	for k in 4:
		var p := ex + Vector2(-9.0 + k * 6.0, 8.5)
		if absf(p.x - ex.x) < 2.5:
			p.x += 3.0
		_put(BurgModels.armour(cols[k]), p, 0.0)
		map.add_obstacle_circle(p, 0.55, ParkMap.BLOCK_PEOPLE)
	var tw := BurgLayout.place("tower")
	_put(BurgModels.lookout_tower(), tw)
	map.add_obstacle_rect(tw, Vector2(5.8, 5.8), 0.0)
	var door := BurgLayout.place("passage")
	_put(BurgModels.secret_door(), door, 0.0)
	map.add_obstacle_rect(door + Vector2(0, -0.6), Vector2(2.6, 1.2), 0.0)
	for s: float in [-1.0, 1.0]:
		_torch(ex + Vector2(s * 4.0, 6.2))
	_torch(tw + Vector2(-3.6, 3.4))


func _tavern() -> void:
	var c := BurgLayout.place("tavern")
	_put(BurgModels.timber_house(16.0, 10.0, 5.0, BurgModels.ROOF), c)
	map.add_obstacle_rect(c, Vector2(16.4, 10.4), 0.0)
	label("TAVERNE ZUM GOLDENEN HUMPEN", Vector3(c.x, gy(c) + 3.35, c.y + 5.14), 0.0, 60, BurgModels.GOLD, 10)
	# Tables on the terrace in front.
	for k in 4:
		var p := Vector2(c.x - 7.5 + k * 5.0, c.y + 9.5)
		if absf(p.x - c.x) < 2.0:
			continue
		var t := picnic_table("burg_table_%d" % k, p, batch)
		world.burg_benches.append(t)
	_torch(c + Vector2(-2.4, 6.0))
	_torch(c + Vector2(2.4, 6.0))


func _smithy() -> void:
	var c := BurgLayout.place("smithy")
	var yaw := -PI / 2
	_put(BurgModels.smithy(), c, yaw)
	var back := c + fwd(yaw) * -1.5
	map.add_obstacle_rect(back, Vector2(8.6, 3.4), -yaw, ParkMap.BLOCK_WALKERS)
	map.add_obstacle_rect(c + fwd(yaw) * -3.3, Vector2(9.2, 0.6), -yaw)
	label("SCHMIEDE", Vector3(c.x - 4.1, gy(c) + 3.6, c.y), -PI / 2, 70, BurgModels.GOLD, 10)


func _stalls() -> void:
	for st: Array in STALLS:
		var p: Vector2 = st[1]
		var yaw := face_path(p)
		_put(BurgModels.stall(st[2], st[3]), p, yaw)
		map.add_obstacle_rect(p + fwd(yaw) * -0.1, Vector2(4.2, 2.6), -yaw, ParkMap.BLOCK_WALKERS)
		var front := p + fwd(yaw) * 1.7
		label(st[4], Vector3(front.x, gy(p) + 2.95, front.y), yaw, 54, Color("2a2a30"), 6)
		burg.spots[st[0]] = Vector3(front.x, gy(front), front.y) + Vector3(fwd(yaw).x, 0, fwd(yaw).y) * 0.6
		var behind := p + fwd(yaw) * -0.2
		burg.posts[st[0]] = [Vector3(behind.x, gy(behind), behind.y), yaw]
	var witch := BurgLayout.place("herb_witch") + Vector2(0, -3.4)
	_put(BurgModels.cauldron(), witch)
	map.add_obstacle_circle(witch, 0.7)


## The campfire on the west side of the market: a cooking station and log seats.
func _campfire() -> void:
	var fire := BurgLayout.place("campfire")
	_put(ForestModels.campfire(), fire)
	_put(ForestModels.campfire_flames(), fire)
	map.add_obstacle_circle(fire, 0.9)
	for off: Vector2 in [Vector2(0, -2.4), Vector2(-2.3, 0.6), Vector2(2.3, 0.8)]:
		var p := fire + off
		var yaw := yaw_to(p, fire)
		_put(ForestModels.log_seat(), p, yaw)
		map.add_obstacle_rect(p, Vector2(2.0, 0.5), -yaw, ParkMap.BLOCK_PEOPLE)
		var b := place_bench("burg_log_%d" % int(off.x * 10), Vector3(p.x, gy(p), p.y), yaw, 2, 0.44)
		world.burg_benches.append(b)
	var s := FunctionSpot.new()
	s.name = "BurgCampfire"
	s.position = Vector3(fire.x, gy(fire), fire.y + 2.0)
	s.radius = 2.2
	s.prompt_text = "Am Lagerfeuer kochen"
	s.action_fn = func(_a: Actor) -> void: UI.open_craft("campfire")
	root.add_child(s)


## The inner square: the jugglers' stage, the puppet theatre, the magician's corner, benches
## round the square, banners.
func _square() -> void:
	var st := BurgLayout.place("stage")
	_put(BurgModels.stage(BurgModels.RED), st, 0.0)
	map.add_obstacle_rect(st, Vector2(6.2, 4.2), 0.0)
	var pp := BurgLayout.place("puppets")
	_put(BurgModels.puppet_theatre(), pp, 0.0)
	map.add_obstacle_rect(pp, Vector2(2.8, 1.4), 0.0)
	label("KASPERS BURGTHEATER", Vector3(pp.x, gy(pp) + 4.2, pp.y + 0.7), 0.0, 40, Color("2a2a30"), 0)
	var mg := BurgLayout.place("magician")
	_put(BurgModels.magician_corner(), mg, PI * 0.25)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var post := mg + Vector2(sx * 1.8, sz * 1.5).rotated(-PI * 0.25)
			map.add_obstacle_circle(post, 0.2, ParkMap.BLOCK_PEOPLE)
	map.add_obstacle_circle(mg + Vector2(0, 0.3).rotated(-PI * 0.25), 0.7, ParkMap.BLOCK_PEOPLE)
	var c := BurgLayout.place("square")
	for k in 8:
		var a := TAU * k / 8 + 0.2
		var p := c + Vector2(cos(a), sin(a)) * 15.5
		if p.distance_to(st) < 6.0 or p.distance_to(pp) < 5.0 or p.distance_to(mg) < 5.0 or map.path_dist_at(p) < 1.0:
			continue
		new_bench(p, yaw_to(p, c))
	for k in 6:
		var a := TAU * k / 6 + 0.5
		var p := c + Vector2(cos(a), sin(a)) * 19.5
		batch.add(BurgModels.banner(BurgModels.RED if k % 2 == 0 else BurgModels.BLUE), Transform3D(Basis(Vector3.UP, yaw_to(p, c)), Vector3(p.x, gy(p), p.y)))
		map.add_obstacle_circle(p, 0.2, ParkMap.BLOCK_PEOPLE)


## The tournament ground: the lists with the tilt and the fence round them, two stands, the
## paddock with the stable, the sword ring with the betting booth, the tug pitch and the
## archery range.
func _tournament() -> void:
	var c := BurgLayout.LISTS
	var size := BurgLayout.LISTS_SIZE
	_put(BurgModels.tilt(size.x - 10.0), c, 0.0)
	map.add_obstacle_rect(c, Vector2(size.x - 9.0, 0.5), 0.0, ParkMap.BLOCK_PEOPLE)
	_rail_rect(c, size + Vector2(2, 2), [c + Vector2(0, size.y * 0.5 + 1.0), c + Vector2(0, -size.y * 0.5 - 1.0),
		c + Vector2(-size.x * 0.5 - 1.0, 0)])
	for side: float in [-1.0, 1.0]:
		var z := c.y + side * (size.y * 0.5 + 4.5)
		var yaw := PI if side > 0 else 0.0
		var p := Vector2(c.x, z)
		_put(BurgModels.stand(40.0, BurgModels.RED if side > 0 else BurgModels.BLUE), p, yaw)
		var depth := BurgModels.STAND_DEPTH * BurgModels.STAND_TIERS.size()
		map.add_obstacle_rect(p + fwd(yaw) * -(depth * 0.5 - 0.45), Vector2(40.4, depth + 0.4), -yaw, ParkMap.BLOCK_ANIMALS)
		for tier in 2:
			var y: float = gy(p) + BurgModels.STAND_TIERS[tier] - 0.47
			for k in 8:
				var bp := p + right(yaw) * (-17.5 + k * 5.0) + fwd(yaw) * -(tier * BurgModels.STAND_DEPTH)
				new_bench(bp, yaw, y + 0.02, 1, false)
	for side: float in [-1.0, 1.0]:
		var bp := c + Vector2(side * (size.x * 0.5 + 3.0), 0)
		batch.add(BurgModels.banner(BurgModels.RED if side < 0 else BurgModels.BLUE), Transform3D(Basis(), Vector3(bp.x, gy(bp), bp.y)))
		map.add_obstacle_circle(bp, 0.2, ParkMap.BLOCK_PEOPLE)
	# Paddock and stable.
	var pd := BurgLayout.PADDOCK
	_rail_rect(pd, BurgLayout.PADDOCK_SIZE, [pd + Vector2(BurgLayout.PADDOCK_SIZE.x * 0.5, -6.0)])
	var sb := BurgLayout.place("stable")
	_put(BurgModels.timber_house(12.0, 7.0, 3.2, BurgModels.ROOF.darkened(0.2)), sb, PI * 0.5)
	map.add_obstacle_rect(sb, Vector2(7.4, 12.4), 0.0)
	label("STALL", Vector3(sb.x + 3.62, gy(sb) + 3.9, sb.y), PI / 2, 60, BurgModels.GOLD, 8)
	for k in 3:
		var tp := pd + Vector2(-8.0 + k * 8.0, BurgLayout.PADDOCK_SIZE.y * 0.5 - 2.0)
		batch.add(PropModels.folding_table(), Transform3D(Basis(), Vector3(tp.x, gy(tp), tp.y)))
	# Sword ring: posts with a rope, the betting booth beside it.
	var sr := BurgLayout.place("sword_ring")
	for k in 10:
		var a := TAU * k / 10
		if absf(a - PI * 1.5) < 0.4:
			continue   # the way in from the north
		var p := sr + Vector2(cos(a), sin(a)) * 6.0
		var q := sr + Vector2(cos(a + TAU / 10), sin(a + TAU / 10)) * 6.0
		batch.add(BurgModels.rail_fence(p.distance_to(q)), Transform3D(Basis(Vector3.UP, atan2(-(q - p).y, (q - p).x)), Vector3(p.x, gy(p), p.y)))
		map.add_obstacle_segment(p, q, 0.4, ParkMap.BLOCK_PEOPLE)
	var bet := BurgLayout.place("betting")
	_put(BurgModels.stall("plain", BurgModels.GOLD), bet, 0.0)
	map.add_obstacle_rect(bet + Vector2(0, -0.1), Vector2(4.2, 2.6), 0.0)
	label("WETTEN", Vector3(bet.x, gy(bet) + 2.95, bet.y + 1.7), 0.0, 54, Color("2a2a30"), 6)
	# Tug of war: a rope across the pitch with a red ribbon in the middle.
	var tg := BurgLayout.place("tug")
	var kit := MeshKit.new()
	kit.rod(Vector3(-6, 0.1, 0), Vector3(6, 0.1, 0), 0.05, 0.05, 5, Color("c9a86a"))
	kit.box(Vector3(0, 0.12, 0), Vector3(0.12, 0.14, 0.2), BurgModels.RED)
	kit.box(Vector3(0, 0.02, 0), Vector3(0.1, 0.02, 3.0), Color("f1eee6"))
	_put(kit.commit(), tg)
	# Archery: the shooting line, the targets 36 m north.
	var ar := BurgLayout.place("archery")
	var at := BurgLayout.place("archery_targets")
	for k in 3:
		var p := at + Vector2(-3.0 + k * 3.0, 0)
		_put(BurgModels.target(), p, 0.0)
		map.add_obstacle_circle(p, 0.8)
	for k in 3:
		var p := ar + Vector2(-3.0 + k * 3.0, -1.2)
		batch.add(BurgModels.rail_fence(1.6), Transform3D(Basis(), Vector3(p.x - 0.8, gy(p), p.y)))
	_rail_line(at + Vector2(-5.0, 4.0), ar + Vector2(-5.0, -2.0))
	_rail_line(at + Vector2(5.0, 4.0), ar + Vector2(5.0, -2.0))


## A rail fence round a rectangle with gaps (4 m) at `gaps`.
func _rail_rect(c: Vector2, size: Vector2, gaps: Array) -> void:
	var h := size * 0.5
	var corners := [c + Vector2(-h.x, -h.y), c + Vector2(h.x, -h.y), c + Vector2(h.x, h.y), c + Vector2(-h.x, h.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var n := maxi(1, int(a.distance_to(b) / 3.0))
		for k in n:
			var p0 := a.lerp(b, float(k) / n)
			var p1 := a.lerp(b, float(k + 1) / n)
			var mid := (p0 + p1) * 0.5
			if gaps.any(func(g: Vector2) -> bool: return g.distance_to(mid) < 2.4):
				continue
			batch.add(BurgModels.rail_fence(p0.distance_to(p1)), Transform3D(Basis(Vector3.UP, atan2(-(p1 - p0).y, (p1 - p0).x)), Vector3(p0.x, gy(p0), p0.y)))
			map.add_obstacle_segment(p0, p1, 0.4)


func _rail_line(a: Vector2, b: Vector2) -> void:
	var n := maxi(1, int(a.distance_to(b) / 3.0))
	for k in n:
		var p0 := a.lerp(b, float(k) / n)
		var p1 := a.lerp(b, float(k + 1) / n)
		batch.add(BurgModels.rail_fence(p0.distance_to(p1)), Transform3D(Basis(Vector3.UP, atan2(-(p1 - p0).y, (p1 - p0).x)), Vector3(p0.x, gy(p0), p0.y)))
		map.add_obstacle_segment(p0, p1, 0.4)


## Fences along the area's borders (the obstacles are BurgMap's), the gates with their signs,
## the castle people's path in the west.
func _gates_and_fences() -> void:
	var lo := ParkLayout.BURG_MIN
	var hi := ParkLayout.BURG_MAX
	var gates := [BurgLayout.GATE_SOUTH, BurgLayout.GATE_EAST, BurgLayout.place("gate_burg_w")]
	var sides := [[Vector2(lo.x, hi.y), Vector2(hi.x, hi.y)], [Vector2(hi.x, hi.y), Vector2(hi.x, lo.y)], [Vector2(lo.x, lo.y), Vector2(lo.x, hi.y)]]
	for side: Array in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var steps := int(a.distance_to(b) / 3.0)
		for k in steps:
			var p0 := a.lerp(b, float(k) / steps)
			var p1 := a.lerp(b, float(k + 1) / steps)
			var mid := p0.lerp(p1, 0.5)
			if gates.any(func(g: Vector2) -> bool: return mid.distance_to(g) < 3.2) or mid.y < BurgLayout.ROCK_Z - 2.0:
				continue
			var d := p1 - p0
			batch.add(PropModels.low_fence(d.length()), Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(p0.x, gy(p0), p0.y)))
	var west := BurgLayout.place("gate_burg_w")
	var x := lo.x
	var z := lo.y
	while z < hi.y:
		if absf(z - west.y) >= 2.4 and z > -266.0:
			map.add_obstacle_rect(Vector2(x, z + 0.5), Vector2(0.6, 1.0), 0.0)
		z += 1.0
	for g: Array in [[BurgLayout.GATE_SOUTH, 0.0, "RITTERBURG"], [BurgLayout.GATE_EAST, PI / 2, "RITTERBURG"], [west, PI / 2, ""]]:
		var p: Vector2 = g[0]
		_put(BurgModels.border_gate(4.6), p, g[1], 0.0)
		if g[2] != "":
			for s: float in [-1.0, 1.0]:
				var n := fwd(g[1]) * 0.06 * s
				label(g[2], Vector3(p.x + n.x, gy(p) + 2.95, p.y + n.y), g[1] + (0.0 if s > 0 else PI), 56, Color("5a3e26"), 0)
	world.burg_entrances.append([Vector3(west.x - 4.0, 0.0, west.y), Vector3(west.x + 3.0, 0.0, west.y)])


## Where the castle's people work (BurgLayout.POSTS, HumanBrain "burg:<id>").
func _posts() -> void:
	for id: String in BurgLayout.POSTS:
		if burg.posts.has(id):
			continue   # a stall's (_stalls)
		var post: Array = BurgLayout.POSTS[id]
		var p: Vector2 = post[0]
		burg.posts[id] = [Vector3(p.x, map.walk_height(p.x, p.y), p.y), post[1]]


## Torches along the paths (every ~22 m) and at the gate house.
func _torches() -> void:
	for path: Dictionary in BurgMap.paths(map):
		if path["kind"] == "trail":
			continue
		var pts: PackedVector2Array = path["points"]
		var half: float = path["width"] * 0.5
		var dist := 0.0
		var next := 8.0
		var side := -1.0
		for i in range(1, pts.size()):
			dist += pts[i].distance_to(pts[i - 1])
			if dist < next:
				continue
			var t := (pts[i] - pts[i - 1]).normalized()
			var p := pts[i] + Vector2(-t.y, t.x) * side * (half + 0.6)
			var c := ParkMap.to_cell(p)
			if not ParkMap.in_burg(p, 2.0) or map.solid[c.y * ParkMap.W + c.x] != 0 or near_place(p, 0.5) or map.path_dist_at(p) < 0.1:
				next = dist + 4.0
				continue
			next = dist + 22.0
			side = -side
			_torch(p)
	var gh := BurgLayout.place("gatehouse")
	for s: float in [-1.0, 1.0]:
		_torch(gh + Vector2(s * 3.4, 3.2))


# --- Plants ------------------------------------------------------------------------------

## Outside the castle area, inside the walls (the market stays open), or on one of its places.
func _keeps_out(p: Vector2) -> bool:
	if not ParkMap.in_burg(p, 2.0) or BurgLayout.in_castle(p, -4.0) or near_place(p, 2.5):
		return true
	var c := ParkMap.to_cell(p)
	return map.ground[c.y * ParkMap.W + c.x] == G.ROCK or map.path_dist_at(p) < 2.0


func _trees() -> void:
	var prng := part_rng(5252)
	var lo := ParkLayout.BURG_MIN
	var hi := ParkLayout.BURG_MAX
	for i in 900:
		var p := Vector2(prng.randf_range(lo.x + 2, hi.x - 2), prng.randf_range(lo.y + 2, hi.y - 2))
		# Dense on the slopes beside the castle, sparse round the tournament ground.
		var slope := p.y < BurgLayout.WALL_S + 4.0
		if not slope and prng.randf() < 0.85:
			continue
		if _keeps_out(p) or not planter.free_at(p, 0.45, 4.5):
			continue
		var kind: String = (["fir", "pine", "oak", "birch"] if p.y < -200.0 else ["oak", "maple", "birch", "chestnut"])[prng.randi() % 4]
		var t := planter.plant(kind, p, prng.randf_range(0.85, 1.2))
		if not t.is_empty():
			world.burg_trees.append(t)


func _flowers() -> void:
	var prng := part_rng(5353)
	for i in 260:
		var p := Vector2(prng.randf_range(-386, -134), prng.randf_range(-262, -94))
		if _keeps_out(p) and not BurgLayout.in_castle(p, 2.0):
			continue
		var c := ParkMap.to_cell(p)
		if map.ground[c.y * ParkMap.W + c.x] != G.GRASS or map.solid[c.y * ParkMap.W + c.x] != 0 or map.path_dist_at(p) < 1.0:
			continue
		small_batch.add(NatureModels.flower(prng.randi() % 3), Transform3D(Basis(Vector3.UP, prng.randf() * TAU), Vector3(p.x, gy(p), p.y)), false, 60.0)

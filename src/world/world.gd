class_name World
extends Node3D
## The park: builds terrain, props and vegetation, owns the navigation and the
## registries every system queries (seats, trees, landmarks, actors, ...).

signal build_progress(fraction: float, text: String)
signal built
signal bottle_collected

var map: ParkMap
var nav: Navigator
var env: EnvironmentController
var static_root: Node3D
var actors_root: Node3D
var rng := RandomNumberGenerator.new()

# Registries filled while building.
var benches: Array[Bench] = []
var seats: Array[Seat] = []
var trees: Array[Dictionary] = []
var lamps: Array[Vector3] = []
var bins: Array[Vector3] = []
var landmarks: Array[Dictionary] = []
var shop_spots := {}
var gates: Array[Vector3] = []
var gate_outside: Array[Vector3] = []
var chess_tables: Array[Bench] = []
var swing_pivots: Array[Node3D] = []
var info_boards: Array[Vector3] = []
var fountain_pos := Vector3.ZERO
var statue_pos := Vector3.ZERO
var pavilion_stage := Vector3.ZERO
var pavilion_yaw := 0.0
var bottle_machine := Vector3.ZERO
var giant_board := Vector3.ZERO
var shell_table := {}
var dog_meadow := Rect2()
var grotto_pos := Vector3.ZERO

# Runtime.
var actors: Array[Actor] = []
var shops := {}                       # id -> Shop
var foods: Array[Dictionary] = []     # bread on the water / ground
var bottles: Array[Node3D] = []
var ice := 0.0
var stash_count := 0
var _stash_tree := {}
var _stash_mesh: MeshInstance3D
var _swing_time := 0.0
var _litter_timer := 30.0


func _ready() -> void:
	rng.randomize()


## Builds everything, yielding between steps so a loading screen can update.
func build() -> void:
	static_root = Node3D.new()
	static_root.name = "Static"
	add_child(static_root)
	actors_root = Node3D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	await _step(0.05, "Vermesse den Park …")
	map = ParkMap.new()
	await _step(0.25, "Gestalte das Gelände …")
	TerrainBuilder.new(map).build(static_root)
	await _step(0.4, "Stelle Bänke und Laternen auf …")
	ParkDecorator.new(self).build()
	await _step(0.55, "Pflanze Bäume und Blumen …")
	Vegetation.new(self).build()
	await _step(0.75, "Plane die Wege …")
	map.build_navigation()
	nav = Navigator.new(map)
	MapImage.reset()
	MapImage.texture(map, trees)
	await _step(0.85, "Hole das Wetter …")
	env = EnvironmentController.new()
	add_child(env)
	env.setup(self)
	for id: String in shop_spots:
		var shop := Shop.new()
		shop.setup(self, id, shop_spots[id])
		static_root.add_child(shop)
		shops[id] = shop
	_setup_stash()
	await _step(0.9, "Wecke die Parkbewohner …")
	built.emit()


func _step(fraction: float, text: String) -> void:
	build_progress.emit(fraction, text)
	await get_tree().process_frame
	await get_tree().process_frame


func register_bench(b: Bench, counts := true) -> void:
	if counts:
		benches.append(b)
	for s in b.seats:
		seats.append(s)


func _process(delta: float) -> void:
	_swing_time += delta
	for i in swing_pivots.size():
		var s: Seat = null
		for seat in seats:
			if seat.kind == "swing" and absf(seat.position.x - swing_pivots[i].position.x) < 0.1:
				s = seat
		var amp := 0.5 if s != null and s.occupant != null else 0.04
		swing_pivots[i].rotation.x = sin(_swing_time * 2.0 + i) * amp
	_update_foods(delta)
	_litter_timer -= delta
	if _litter_timer <= 0.0:
		_litter_timer = rng.randf_range(40.0, 90.0)
		_spawn_litter()
	for n in get_tree().get_nodes_in_group("spinning"):
		(n as Node3D).rotate_y(delta * 0.6)
	for n in get_tree().get_nodes_in_group("bobbing"):
		var node := n as Node3D
		node.position.y = ParkLayout.WATER_Y - 0.08 + sin(_swing_time * 1.3 + node.position.x) * 0.03
		node.rotation.z = sin(_swing_time * 0.9 + node.position.z) * 0.03


# --- Queries ------------------------------------------------------------------------

func ground_height(p: Vector3) -> float:
	return map.walk_height(p.x, p.z)


## Nearest free seat for `actor` within `max_dist`, optionally restricted to kinds.
func find_free_seat(near: Vector3, actor: Actor, max_dist := 40.0, kinds: Array = ["bench"], exclude_owner := "") -> Seat:
	var best: Seat = null
	var best_d := max_dist
	for s in seats:
		if not kinds.has(s.kind) or not s.is_free_for(actor) or s.owner_id == exclude_owner:
			continue
		var d := s.position.distance_to(near)
		if d < best_d:
			best_d = d
			best = s
	return best


func random_seat(actor: Actor, kinds: Array = ["bench"]) -> Seat:
	var free: Array[Seat] = []
	for s in seats:
		if kinds.has(s.kind) and s.is_free_for(actor):
			free.append(s)
	if free.is_empty():
		return null
	return free[rng.randi() % free.size()]


func nearest_tree(p: Vector3, max_dist := 30.0, kinds: Array = []) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for t in trees:
		if not kinds.is_empty() and not kinds.has(t["kind"]):
			continue
		var d := (t["pos"] as Vector2).distance_to(Vector2(p.x, p.z))
		if d < best_d:
			best_d = d
			best = t
	return best


func random_tree(kinds: Array = []) -> Dictionary:
	for i in 30:
		var t: Dictionary = trees[rng.randi() % trees.size()]
		if kinds.is_empty() or kinds.has(t["kind"]):
			return t
	return trees[0]


## Random point on a path (for strolling).
func random_path_point() -> Vector3:
	for i in 20:
		var path: Dictionary = map.paths[rng.randi() % map.paths.size()]
		var pts: PackedVector2Array = path["points"]
		var p := pts[rng.randi() % pts.size()]
		if ParkMap.in_park(p, 3.0) and not map.is_solid(p):
			return Vector3(p.x, map.walk_height(p.x, p.y), p.y)
	return Vector3.ZERO


## Random spot on a lawn (for picnics, dogs, squirrels).
func random_lawn_point(center := Vector2.ZERO, radius := 110.0) -> Vector3:
	for i in 40:
		var p := center + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius * 0.7, radius * 0.7))
		if ParkMap.in_park(p, 4.0) and map.ground_at(p) == ParkMap.Ground.GRASS and not map.is_solid(p):
			return Vector3(p.x, map.walk_height(p.x, p.y), p.y)
	return random_path_point()


func landmark(id: String) -> Dictionary:
	for l in landmarks:
		if l["id"] == id:
			return l
	return {}


func register_actor(a: Actor) -> void:
	actors.append(a)


func actors_near(p: Vector3, radius: float, filter := Callable()) -> Array[Actor]:
	var out: Array[Actor] = []
	var r2 := radius * radius
	for a in actors:
		if not a.visible or a.inside:
			continue
		if a.global_position.distance_squared_to(p) <= r2 and (not filter.is_valid() or filter.call(a)):
			out.append(a)
	return out


func find_actor(id: String) -> Actor:
	for a in actors:
		if a.actor_id == id:
			return a
	return null


# --- Food for birds ---------------------------------------------------------------

func add_food(p: Vector3, kind: String, feeder: Actor = null) -> void:
	var water := map.is_water(Vector2(p.x, p.z))
	var y := ParkLayout.WATER_Y + 0.02 if water else map.walk_height(p.x, p.z) + 0.03
	var mi := MeshInstance3D.new()
	mi.mesh = PropModels.item("bread")
	mi.scale = Vector3(0.6, 0.6, 0.6)
	mi.position = Vector3(p.x, y, p.z)
	add_child(mi)
	foods.append({"pos": Vector3(p.x, y, p.z), "kind": kind, "feeder": feeder, "node": mi, "age": 0.0})


func nearest_food(p: Vector3, radius: float):
	var best = null
	var best_d := radius
	for f in foods:
		var d := Vector2(p.x - f["pos"].x, p.z - f["pos"].z).length()
		if d < best_d:
			best_d = d
			best = f
	return best


## Removes the food; returns true when the eater got it.
func consume_food(f: Dictionary, eater: Actor) -> bool:
	if not foods.has(f):
		return false
	foods.erase(f)
	if is_instance_valid(f["node"]):
		f["node"].queue_free()
	var feeder: Actor = f["feeder"]
	if feeder and is_instance_valid(feeder) and feeder.controlled and eater.species in ["duck", "duckling", "goose"]:
		GameState.add_stat("ducks_fed")
		food_eaten.emit(eater, feeder)
	return true


signal food_eaten(eater: Actor, feeder: Actor)


func _update_foods(delta: float) -> void:
	for i in range(foods.size() - 1, -1, -1):
		var f: Dictionary = foods[i]
		f["age"] += delta
		if f["age"] > 45.0:
			if is_instance_valid(f["node"]):
				f["node"].queue_free()
			foods.remove_at(i)


# --- Bottles -------------------------------------------------------------------------

func spawn_bottle(p: Vector3) -> Bottle:
	var c := nav.nearest_open(Vector2(p.x, p.z))
	if c.x < 0:
		return null
	var q := ParkMap.cell_center(c) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
	var b := Bottle.new()
	b.position = Vector3(q.x, map.walk_height(q.x, q.y), q.y)
	add_child(b)
	bottles.append(b)
	return b


func nearest_bottle(p: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for b in bottles:
		var d := b.global_position.distance_to(p)
		if d < best_d:
			best_d = d
			best = b
	return best


func remove_bottle(b: Node3D) -> void:
	bottles.erase(b)
	if is_instance_valid(b):
		b.queue_free()


func _spawn_litter() -> void:
	if bottles.size() >= 14 or Clock.is_night():
		return
	var spots: Array[Vector3] = []
	for s in seats:
		if s.kind == "bench":
			spots.append(s.approach_point() + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5)))
	if spots.is_empty():
		return
	spawn_bottle(spots[rng.randi() % spots.size()])


func return_bottles(actor: Actor) -> void:
	var n: int = actor.inventory.get("empty_bottle", 0)
	if n <= 0:
		return
	actor.inventory.erase("empty_bottle")
	GameState.add_stat("bottles", n)
	GameState.add_money(n * 25, "Pfand für %d Flasche%s" % [n, "" if n == 1 else "n"])
	Sound.play("coin")


# --- Nussi's secret donut stash -------------------------------------------------------

func _setup_stash() -> void:
	var best_d := INF
	for t in trees:
		if t["kind"] != "oak":
			continue
		var d := (t["pos"] as Vector2).distance_to(Vector2(-12, 28))
		if d < best_d:
			best_d = d
			_stash_tree = t
	if _stash_tree.is_empty():
		_stash_tree = trees[0]
	var p: Vector2 = _stash_tree["pos"]
	# A dark hollow in the trunk.
	var kit := MeshKit.new()
	kit.sphere(Vector3(0, 0, 0), Vector3(0.22, 0.3, 0.08), Color("1e140c"), 3, 6)
	var hollow := MeshInstance3D.new()
	hollow.mesh = kit.commit()
	var side := Vector3(1, 0, 0) * (float(_stash_tree["trunk"]) + 0.02)
	hollow.position = Vector3(p.x, float(_stash_tree["ground"]) + 1.6, p.y) + side
	hollow.rotation.y = PI / 2
	add_child(hollow)
	_stash_mesh = MeshInstance3D.new()
	_stash_mesh.position = Vector3(p.x, float(_stash_tree["ground"]) + 1.45, p.y) + side * 1.05
	add_child(_stash_mesh)
	var stash := StashSpot.new()
	stash.position = Vector3(p.x, float(_stash_tree["ground"]), p.y) + side * 1.4
	add_child(stash)
	stash_count = GameState.stat("stash_donuts")
	_update_stash_mesh()


func stash_tree() -> Dictionary:
	return _stash_tree


func add_to_stash() -> void:
	stash_count += 1
	GameState.set_stat("stash_donuts", stash_count)
	_update_stash_mesh()


func _update_stash_mesh() -> void:
	var kit := MeshKit.new()
	var n := mini(stash_count + 2, 9)
	for i in n:
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0.0, i * 0.05, 0.0)))
		kit.torus(Vector3.ZERO, 0.07, 0.035, 8, 4, [Color("f28db2"), Color("6b3e26"), Color("d9a35c")][i % 3])
		kit.pop()
	_stash_mesh.mesh = kit.commit()

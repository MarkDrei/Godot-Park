class_name World
extends Node3D
## The park: builds terrain, props and vegetation, owns the navigation and the
## registries every system queries (seats, trees, landmarks, actors, ...).

signal build_progress(fraction: float, text: String)
signal built
signal bottle_collected
signal area_loaded(area: String)    # an area is built (load_area): the Oststadt or the Westpark
signal area_entered(area: String)   # the player's area is awake (enter_area)

var map: ParkMap
var nav: Navigator
var env: EnvironmentController
var static_root: Node3D
var actors_root: Node3D
var rng := RandomNumberGenerator.new()

# Registries filled while building.
var benches: Array[Bench] = []
var forest_benches: Array[Bench] = []      # Nordwald seats; not counted for "Bankdrücker"
var city_benches: Array[Bench] = []        # Oststadt seats; not counted either
var fair_benches: Array[Bench] = []        # Westpark seats and tables; not counted either
var fair_trees: Array[Dictionary] = []     # Westpark trees (not in `trees`: squirrels, felling and the map stay in the park)
var fair_entrances: Array = []             # Westpark gates: [outside, inside] (its people come and go here)
var seats: Array[Seat] = []
var trees: Array[Dictionary] = []
var gather_spots: Array[Dictionary] = []   # Nordwald resources (ForestDecorator.gather_spots, Gathering)
var tree_batch: InstanceBatcher        # trees as MultiMesh instances (felled ones are hidden)
var lamps: Array[Vector3] = []
var bins: Array[Vector3] = []
var landmarks: Array[Dictionary] = []
var shop_spots := {}
var gates: Array[Vector3] = []
var gate_outside: Array[Vector3] = []
var forest_entrances: Array = []          # Nordwald gates: [outside, inside] (forest NPCs come and go here)
var chess_tables: Array[Bench] = []
var playground: Playground               # the city park's playground (ParkDecorator)
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

# Areas (doc/arc42.md §8.8, Area): "park" (park and Nordwald), "city" (the Oststadt, `city`)
# and "fair" (the Westpark with the Kirmes, `fair`); the last two are built on demand
# (load_area). With split_areas only the player's area is awake; the others sleep (hidden,
# nobody in them is processed) and wake up as after a restart: everybody where the time of
# day puts them.
var areas := {}                       # id -> Area, in the order park, city, fair
var city: City
var fair: Fair
var fair_backdrop: Node3D             # the Westpark seen from the park until it is loaded
var split_areas := false
var player_area := "park"             # the area the player is in
var switching := false                # enter_area is busy (loading screen)
var park_root: Node3D                 # the park's scenery (seal_park)
var west_backdrop: Node3D             # cheap view of the sleeping park from the town
## Static nodes outside the park's scenery: horizon pieces stay while the park sleeps.
const HORIZON := ["Surroundings", "City", "Mountain", "EastSurroundings", "EastBackdrop", "Oststadt",
	"Park", "WestBackdrop", "FairCity", "WestForest", "FairBackdrop", "Westpark"]

# Runtime.
var actors: Array[Actor] = []
const ACTOR_GRID := 8.0               # metres per bucket of actors_near
var _actor_grid := {}                 # Vector2i -> Array of Actor
var _actor_grid_frame := -1
## Where the camera looks (CameraRig): far from here actors think and move less often
## (Actor.lod_distance) and the town's traffic rests while the player is in the park.
var focus := Vector3.ZERO
var shops := {}                       # id -> Shop
var foods: Array[Dictionary] = []     # bread on the water / ground
var bottles: Array[Node3D] = []
var ice := 0.0
var stash_count := 0
var _stash_tree := {}
var _stash_mesh: MeshInstance3D
var _bob_time := 0.0
var _litter_timer := 30.0


func _ready() -> void:
	rng.randomize()
	for a: Area in [ParkArea.new(self), CityArea.new(self), FairArea.new(self)]:
		areas[a.id] = a


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
	ForestDecorator.new(self).build()
	fair_backdrop = FairBackdrop.build(self)
	static_root.add_child(fair_backdrop)
	await _step(0.55, "Pflanze Bäume und Blumen …")
	Vegetation.new(self).build()
	ForestDecorator.new(self).gather_spots()
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


# --- Areas ----------------------------------------------------------------------------

func area(id: String) -> Area:
	return areas[id]


## Builds an area once (the Oststadt, the Westpark) behind a loading screen.
func load_area(id: String) -> void:
	var a := area(id)
	if a.is_built() or loading():
		return
	await a.load()


## An area is being built.
func loading() -> bool:
	return areas.values().any(func(a: Area) -> bool: return a.loading)


static func area_of(p: Vector3) -> String:
	if p.x > ParkLayout.CITY_EDGE:
		return "city"
	return "fair" if p.x < ParkLayout.FAIR_EDGE else "park"


static func home_area(a: Actor) -> String:
	return a.home_region if a.home_region in ["city", "fair"] else "park"


func area_awake(id: String) -> bool:
	return area(id).is_awake()


## Puts the park's scenery under one node (after Gameplay added its props), so the park can
## sleep with one switch. The horizon (skyline, mountain, backdrops) stays outside.
func seal_park() -> void:
	park_root = Node3D.new()
	park_root.name = "Park"
	static_root.add_child(park_root)
	for n in static_root.get_children():
		if not String(n.name) in HORIZON:
			n.reparent(park_root, false)
	area("park").root = park_root


## The player is in area `id` now. Split: the other area falls asleep and this one wakes up
## (behind a loading screen; an area is built the first time). Otherwise everything that is
## built stays awake.
func enter_area(id: String) -> void:
	if switching or loading():
		return
	switching = true
	player_area = id
	await load_area(id)
	var want := {}
	var changed := false
	for a: Area in areas.values():
		if a.is_built():
			want[a] = a.id == id or not split_areas
			changed = changed or want[a] != a.is_open()
	if changed and split_areas:
		UI.show_loading(area(id).loading_text)
		UI.loading_progress(0.3, "Räume auf …")
		await get_tree().process_frame
	# Sleep first, then wake: a woken area places its people by the time of day.
	for a: Area in want:
		if not want[a]:
			a.set_awake(false)
	for a: Area in want:
		if want[a]:
			a.set_awake(true)
	if changed and split_areas:
		UI.loading_progress(1.0, "Fertig!")
		await get_tree().process_frame
		await get_tree().process_frame
		UI.hide_loading()
	switching = false
	area_entered.emit(id)


## The split setting changed: the area the player is not in falls asleep or wakes up.
func set_split(on: bool) -> void:
	split_areas = on
	await enter_area(player_area)


## The people and animals of an area fall asleep with it, or wake up where the time of day
## puts them (like at the start). The character the player controls is never touched.
func set_people_awake(id: String, on: bool) -> void:
	var woken: Array[Actor] = []
	for a in actors:
		if a.controlled or home_area(a) != id or a.dormant != on:
			continue
		a.set_dormant(not on)
		if on:
			woken.append(a)
	for a in woken:
		UI.game.place_by_schedule(a)
		if a.brain:
			a.brain.resume()
	actors_moved()


## An actor the player let go of outside its area goes home: placed by the time of day in its
## area, or asleep with it.
func send_home_if_lost(a: Actor) -> void:
	if a.controlled or area_of(a.global_position) == home_area(a):
		return
	if area_awake(home_area(a)):
		UI.game.place_by_schedule(a)
	else:
		a.set_dormant(true)


func register_bench(b: Bench, counts := true) -> void:
	if counts:
		benches.append(b)
	for s in b.seats:
		seats.append(s)


func _process(delta: float) -> void:
	_bob_time += delta
	_update_foods(delta)
	_litter_timer -= delta
	if _litter_timer <= 0.0:
		_litter_timer = rng.randf_range(40.0, 90.0)
		_spawn_litter()
	for n in get_tree().get_nodes_in_group("spinning"):
		(n as Node3D).rotate_y(delta * 0.6)
	for n in get_tree().get_nodes_in_group("bobbing"):
		var node := n as Node3D
		node.position.y = ParkLayout.WATER_Y - 0.08 + sin(_bob_time * 1.3 + node.position.x) * 0.03
		node.rotation.z = sin(_bob_time * 0.9 + node.position.z) * 0.03


# --- Queries ------------------------------------------------------------------------

## Nearest free seat for `actor` within `max_dist`, optionally restricted to kinds.
func find_free_seat(near: Vector3, actor: Actor, max_dist := 40.0, kinds: Array = ["bench"], exclude_owner := "") -> Seat:
	var best: Seat = null
	var best_d := max_dist
	for s in seats:
		if not kinds.has(s.kind) or not s.is_free_for(actor) or s.owner_id == exclude_owner or not allowed(actor, s.position):
			continue
		var d := s.position.distance_to(near)
		if d < best_d:
			best_d = d
			best = s
	return best


func random_seat(actor: Actor, kinds: Array = ["bench"]) -> Seat:
	var free: Array[Seat] = []
	for s in seats:
		if kinds.has(s.kind) and s.is_free_for(actor) and allowed(actor, s.position):
			free.append(s)
	if free.is_empty():
		return null
	return free[rng.randi() % free.size()]


## Whether `actor` may go to `p` on its own: park people stay in the park, the people of
## the Nordwald in the forest, the people of the Oststadt in town; whoever the player
## controls goes anywhere.
static func allowed(actor: Actor, p: Vector3) -> bool:
	return actor == null or actor.controlled or actor.home_region == ParkLayout.region_of(Vector2(p.x, p.z))


## Where a Nordwald person comes from and goes home to: [outside, inside] (the forest gate,
## or the mine portal for the dwarves).
func home_of(actor: Actor) -> Array[Vector3]:
	if actor.home_region == "fair":
		return _fair_entrance(actor)
	if actor.home_region == "city":
		var h := city_house_of(actor)
		var d: Vector2 = h["door"]
		var q := Vector3(d.x, map.walk_height(d.x, d.y), d.y)
		return [q, q]
	if actor.def.get("home", "") == "mine":
		var m := ParkLayout.place("mine_portal")
		var p := Vector3(m.x, map.walk_height(m.x, m.y + 3.0), m.y + 3.0)
		return [p, p]
	# The entrance nearest the workplace (or the lumber camp).
	var work: Vector3
	var shop: Shop = shops.get(actor.def.get("work", {}).get("shop", ""))
	if shop:
		work = shop.vendor_pos()
	else:
		var c := ParkLayout.place("lumber_camp")
		work = Vector3(c.x, 0, c.y)
	var best: Array = forest_entrances[0]
	for e: Array in forest_entrances:
		if (e[1] as Vector3).distance_to(work) < (best[1] as Vector3).distance_to(work):
			best = e
	return [best[0], best[1]]


## The Westpark gate nearest the person's work (a random one, fixed by the id, for visitors).
func _fair_entrance(actor: Actor) -> Array[Vector3]:
	var best: Array = fair_entrances[absi(hash(actor.actor_id)) % fair_entrances.size()]
	var work := Vector3.INF
	var shop: Shop = shops.get(actor.def.get("work", {}).get("shop", ""))
	if shop:
		work = shop.vendor_pos()
	var spot: String = actor.def.get("work", {}).get("spot", "")
	if spot.begins_with("fair:") and fair and fair.posts.has(spot.substr(5)):
		work = fair.posts[spot.substr(5)][0]
	if work != Vector3.INF:
		for e: Array in fair_entrances:
			if (e[1] as Vector3).distance_to(work) < (best[1] as Vector3).distance_to(work):
				best = e
	return [best[0], best[1]]


## The house a person of the Oststadt lives in (fixed by the id): a resident with a workplace
## lives within 150 m of it (the town is too big to walk across every morning), the others
## anywhere.
func city_house_of(actor: Actor) -> Dictionary:
	var houses := CityLayout.houses()
	var preferred: String = actor.def.get("house", "")
	if preferred != "":
		return CityLayout.house(preferred)
	var work := Vector2.INF
	var w: Dictionary = actor.def.get("work", {})
	if CityLayout.POSTS.has(w.get("spot", "")):
		work = CityLayout.POSTS[w["spot"]][0]
	for sh: Array in City.SHOPS:
		if sh[0] == w.get("shop", ""):
			work = sh[1]
	if work != Vector2.INF:
		var near := houses.filter(func(h: Dictionary) -> bool: return (h["door"] as Vector2).distance_to(work) < 150.0)
		if not near.is_empty():
			return near[absi(hash(actor.actor_id)) % near.size()]
	return houses[absi(hash(actor.actor_id)) % houses.size()]


## Nearest tree on the same side of the Waldtor fence as `p`.
func nearest_tree(p: Vector3, max_dist := 30.0, kinds: Array = []) -> Dictionary:
	var best := {}
	var best_d := max_dist
	var forest := ParkLayout.in_forest(Vector2(p.x, p.z))
	for t in trees:
		if (not kinds.is_empty() and not kinds.has(t["kind"])) or t["forest"] != forest:
			continue
		var d := (t["pos"] as Vector2).distance_to(Vector2(p.x, p.z))
		if d < best_d:
			best_d = d
			best = t
	return best


## Random tree in the city park.
func random_tree(kinds: Array = []) -> Dictionary:
	for i in 60:
		var t: Dictionary = trees[rng.randi() % trees.size()]
		if (kinds.is_empty() or kinds.has(t["kind"])) and not t["forest"]:
			return t
	return trees[0]


## Random point on a path (for strolling): in the city park, or in the Nordwald for its
## people.
func random_path_point(actor: Actor = null) -> Vector3:
	if actor != null and actor.home_region == "city":
		var q := CityLayout.random_sidewalk_point(rng)
		return Vector3(q.x, map.walk_height(q.x, q.y), q.y)
	if actor != null and actor.home_region == "fair":
		var fair_paths := FairMap.paths(map)
		for i in 40:
			var fp: Dictionary = fair_paths[rng.randi() % fair_paths.size()]
			var pts2: PackedVector2Array = fp["points"]
			var q := pts2[rng.randi() % pts2.size()]
			if ParkMap.in_fair(q, 3.0) and not map.is_solid(q):
				return Vector3(q.x, map.walk_height(q.x, q.y), q.y)
		var c2 := FairLayout.place("fest_square") + Vector2(0, 16)
		return Vector3(c2.x, map.walk_height(c2.x, c2.y), c2.y)
	var forest := actor != null and actor.home_region == "forest"
	for i in 40:
		var path: Dictionary = map.paths[rng.randi() % map.paths.size()]
		var pts: PackedVector2Array = path["points"]
		var p := pts[rng.randi() % pts.size()]
		var ok := (ParkMap.in_world(p, 3.0) and p.y < ParkLayout.FOREST_EDGE - 4.0) if forest else ParkMap.in_park(p, 3.0)
		if ok and not map.is_solid(p):
			return Vector3(p.x, map.walk_height(p.x, p.y), p.y)
	if forest:
		var c := ParkLayout.place("lumber_camp")
		return Vector3(c.x, map.walk_height(c.x, c.y), c.y)
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
	var f := Engine.get_physics_frames()
	if f != _actor_grid_frame:
		_actor_grid_frame = f
		_actor_grid.clear()
		for a in actors:
			if not a.visible or a.inside:
				continue
			var k := Vector2i(floori(a.global_position.x / ACTOR_GRID), floori(a.global_position.z / ACTOR_GRID))
			if _actor_grid.has(k):
				(_actor_grid[k] as Array).append(a)
			else:
				_actor_grid[k] = [a]
	var out: Array[Actor] = []
	var r2 := radius * radius
	for gx in range(floori((p.x - radius) / ACTOR_GRID), floori((p.x + radius) / ACTOR_GRID) + 1):
		for gz in range(floori((p.z - radius) / ACTOR_GRID), floori((p.z + radius) / ACTOR_GRID) + 1):
			var bucket: Variant = _actor_grid.get(Vector2i(gx, gz))
			if bucket == null:
				continue
			for a: Actor in bucket:
				if not is_instance_valid(a) or not a.visible or a.inside:
					continue
				var d := Vector2(a.global_position.x - p.x, a.global_position.z - p.z)
				if d.length_squared() <= r2 and (not filter.is_valid() or filter.call(a)):
					out.append(a)
	return out


## Someone was teleported or came out of a house: sort everybody again before the next query.
func actors_moved() -> void:
	_actor_grid_frame = -1


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
			var p := s.approach_point()
			if area_awake(area_of(p)):   # nobody litters in a sleeping area
				spots.append(p + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5)))
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
		var d := (t["pos"] as Vector2).distance_to(ParkLayout.STASH_NEAR)
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
	static_root.add_child(hollow)   # sleeps with the park (seal_park)
	_stash_mesh = MeshInstance3D.new()
	_stash_mesh.position = Vector3(p.x, float(_stash_tree["ground"]) + 1.45, p.y) + side * 1.05
	static_root.add_child(_stash_mesh)
	var stash := StashSpot.new()
	stash.position = Vector3(p.x, float(_stash_tree["ground"]), p.y) + side * 1.4
	static_root.add_child(stash)
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

extends Scenario
## Gathering in the Nordwald with real input: walk up to a spot, press Action, wait for the
## work to finish (doc/nordwald.md, src/game/gathering.gd).


func _g() -> Gathering:
	return Gameplay.gathering


func _spot(kind: String, index := 0) -> Dictionary:
	var n := 0
	for s: Dictionary in _g().spots:
		if s["kind"] == kind:
			if n == index:
				return s
			n += 1
	return {}


## Stands next to a spot, facing it.
func _go(s: Dictionary, dist := 1.3) -> void:
	var p: Vector3 = s["pos"]
	var from := p + Vector3(dist, 0, 0.3)
	if world.map.is_solid(Vector2(from.x, from.z)):
		from = p + Vector3(-dist, 0, -0.3)
	await put_player(from, p)
	await wait(0.3)


## Presses Action and waits until the job is done.
func _work() -> void:
	await press("interact")
	await wait_until(func() -> bool: return _g().job.is_empty(), 15.0)
	await wait(0.2)


func test_fell_tree_with_axe() -> void:
	var a := player()
	var s := _spot("tree", 40)
	await _go(s)
	check(prompt().contains("brauchst du eine Axt"), "without an axe the prompt asks for one (%s)" % prompt())
	await press("interact")
	check(_g().job.is_empty(), "no felling without an axe")
	a.add_item("stone_axe")
	await wait(0.3)
	check_eq(prompt(), "Baum fällen", "prompt with an axe")
	await press("interact")
	check(a.anim == "chop" and a.item == "axe", "chopping with the axe in hand")
	await shot("chopping", {"player": head(a)})
	await wait_until(func() -> bool: return _g().job.is_empty(), 15.0)
	check_eq(int(a.inventory.get("log", 0)), 3, "three logs from a tree")
	check(a.has_item("twig"), "and some twigs")
	check(not _g().is_ready(s), "the tree is felled")
	check(_g()._stumps.has(s["id"]), "a stump is left")
	await shot("felled", {"player": head(a)})


func test_better_axe_is_faster() -> void:
	var a := player()
	a.add_item("stone_axe")
	var s1 := _spot("tree", 50)
	await _go(s1)
	var t0 := Time.get_ticks_msec()
	await _work()
	var slow := Time.get_ticks_msec() - t0
	a.add_item("dwarf_axe")
	var s2 := _spot("tree", 60)
	await _go(s2)
	t0 = Time.get_ticks_msec()
	await _work()
	var fast := Time.get_ticks_msec() - t0
	check(fast < slow * 0.5, "the dwarf axe fells much faster (%d ms vs %d ms)" % [fast, slow])
	check_eq(int(a.inventory.get("log", 0)), 3 + 4, "the dwarf axe gets one log more")


func test_walking_away_stops_work() -> void:
	var a := player()
	a.add_item("stone_axe")
	var s := _spot("tree", 70)
	await _go(s)
	await press("interact")
	await wait(0.5)
	await move(Vector2(0, -1), 0.5)
	check(_g().job.is_empty() and _g().is_ready(s), "walking away stops felling, the tree stays")
	check(not a.has_item("log"), "no logs")


func test_tree_regrows() -> void:
	var a := player()
	a.add_item("iron_axe")
	var s := _spot("tree", 80)
	await _go(s)
	await _work()
	check(not _g().is_ready(s), "felled")
	Clock.day += 2
	Clock.set_time(Clock.hour() + 1.0)
	await frames(2)
	check(_g().is_ready(s) and not _g()._stumps.has(s["id"]), "the tree grows back after two days")


func test_mine_rock_and_luck() -> void:
	var a := player()
	var s := _spot("rock", 0)
	await _go(s, 1.6)
	check(prompt().contains("Spitzhacke"), "the boulder needs a pickaxe (%s)" % prompt())
	a.add_item("dwarf_pickaxe")
	await wait(0.3)
	await _work()
	check(int(a.inventory.get("stone", 0)) >= 3, "stones from the boulder")
	await shot("quarry_mined", {"player": head(a)})
	# Luck: many boulders with the dwarf pickaxe find ore.
	var ore := 0
	for i in 40:
		ore += int(_g()._yields(_spot("rock", 1), 3).get("ore", 0))
	check(ore >= 6, "ore turns up with the dwarf pickaxe (%d of 40)" % ore)


func test_gather_by_hand() -> void:
	var a := player()
	for kind: String in ["twigs", "pebbles", "berries", "mushroom", "apple"]:
		var s := _spot(kind, 0)
		check(not s.is_empty(), "there is a %s spot" % kind)
		await _go(s, 1.6 if kind in ["berries", "apple"] else 1.0)
		check(prompt() == Gathering.KINDS[kind]["verb"], "%s prompt (%s)" % [kind, prompt()])
		await _work()
		check(not _g().is_ready(s), "%s gathered" % kind)
	for id: String in ["twig", "stone", "berries", "mushroom", "apple"]:
		check(a.has_item(id), "got %s" % id)
	await shot("orchard", {"player": head(a)})


func test_fishing() -> void:
	var a := player()
	var s := _spot("fishing", 0)
	await _go(s, 0.5)
	check(prompt().contains("Angel"), "fishing needs a rod (%s)" % prompt())
	a.add_item("fishing_rod")
	await wait(0.3)
	await press("interact")
	check(a.anim == "fish", "casting")
	await press("interact")
	check(toasted("Zu früh"), "pulling too early loses the fish")
	await press("interact")
	await wait_until(func() -> bool: return _g().fishing.get("bite_left", 0.0) > 0.0, 10.0)
	await shot("fishing_bite", {"player": head(a)})
	await press("interact")
	check_eq(int(a.inventory.get("fish", 0)), 1, "a trout caught")


func test_secret_cherry_tree() -> void:
	var a := player()
	var t: Dictionary = Gathering.secret_trees(world)[0]
	var s: Dictionary = {}
	for sp: Dictionary in _g().spots:
		if sp.get("tree", {}) == t:
			s = sp
	check(not s.is_empty() and not t["forest"], "a secret tree in the city park")
	await _go(s)
	check_eq(prompt(), "", "nothing hints at it without an axe")
	a.add_item("stone_axe")
	await wait(0.3)
	check_eq(prompt(), "Kirschbaum fällen", "with an axe it can be felled")
	await _work()
	check_eq(int(a.inventory.get("cherry_wood", 0)), 2, "cherry wood")


func test_full_bag_and_tired() -> void:
	var a := player()
	for id: String in ["twig", "log", "stone", "ore", "board", "slab", "berries", "apple", "mushroom", "fish", "carving"]:
		a.add_item(id, Items.stack_size(id))
	a.add_item("stone_axe")
	var s := _spot("tree", 90)
	await _go(s)
	await press("interact")
	check(_g().job.is_empty() and toasted("Rucksack ist voll"), "a full bag stops felling")
	a.inventory.clear()
	a.add_item("stone_axe")
	a.needs.fatigue = 95.0
	await press("interact")
	check(_g().job.is_empty() and toasted("zu müde"), "too tired to work")


func test_gather_state_saved() -> void:
	var a := player()
	a.add_item("stone_axe")
	var s := _spot("tree", 100)
	await _go(s)
	await _work()
	GameState.save_game()
	GameState.gather.clear()
	GameState.load_game()
	_g().refresh()
	check(not _g().is_ready(s), "the felled tree stays felled after loading")


## Nordwald achievements: the counters they watch (real play for each is covered above).
func test_nordwald_achievements() -> void:
	for id: String in ["lumberjack", "lucky_strike", "angler", "craftsman", "trader", "honorary_dwarf"]:
		var def := Achievements.get_def(id)
		check(not GameState.is_unlocked(id), "%s locked at first" % id)
		GameState.add_stat(def["stat"], def["target"])
		check(GameState.is_unlocked(id), "%s unlocks at %d %s" % [id, def["target"], def["stat"]])


## A gem found while mining counts for "Glück auf!".
func test_gem_counts() -> void:
	var a := player()
	a.add_item("dwarf_pickaxe")
	var g := _g()
	g.rng.seed = 1
	var before := GameState.stat("gems_found")
	for i in 3:
		var s := _spot("rock", i + 2)
		g._finish(a, s, 3)
	var gems := int(a.inventory.get("gem", 0))
	check_eq(GameState.stat("gems_found") - before, gems, "every gem in the bag is counted (%d)" % gems)

extends Scenario
## The people of the Nordwald: traders (buy into the bag, sell from the bag), the inn with
## hot meals and a room, the dwarves' quests and their tool rewards, the campfire, and
## that they stay in the forest.


## Talks to an NPC standing at `at` (away from shop counters, which would take the focus).
func _talk(npc: Actor, at := Vector3.INF) -> void:
	npc.brain.suspend()
	if at != Vector3.INF:
		npc.teleport(at)
	await put_player(npc.global_position + Vector3(1.4, 0, 0), npc.global_position)
	await wait(0.3)
	await press("interact")
	await wait(0.3)


func test_sawmill_buys_wood() -> void:
	var a := player()
	a.add_item("log", 8)
	a.add_item("twig", 5)
	var shop := await open_shop("sawmill")
	check(shop != null, "the sawmill opens (Sepp at work)")
	await at_shop("sawmill")
	check(prompt() == "Handeln: Sägewerk", "trade prompt (%s)" % prompt())
	await press("interact")
	check(dialog_options().any(func(o: String) -> bool: return o.contains("Alles verkaufen")), "sell-all option")
	await shot("sawmill_trade")
	var money := GameState.money
	await choose("Verkaufen: Holzscheit")
	check_eq(GameState.money - money, 8 * Items.value("log"), "8 logs sold at their value")
	check(not a.has_item("log") and a.has_item("twig"), "only the logs are gone")


func test_buy_axe_at_lumber_camp() -> void:
	var a := player()
	GameState.money = 1000
	await open_shop("lumber_camp")
	await at_shop("lumber_camp")
	await press("interact")
	await choose("Kaufen: Steinaxt")
	check(a.has_item("stone_axe"), "stone axe in the bag")
	check_eq(GameState.money, 1000 - 450, "paid 4,50 €")


func test_farm_shop_and_dwarf_office() -> void:
	var a := player()
	a.add_item("jam", 2)
	a.add_item("gem", 1)
	await open_shop("farm_shop")
	await at_shop("farm_shop")
	await press("interact")
	var money := GameState.money
	await choose("Verkaufen: Beerenmarmelade")
	check_eq(GameState.money - money, 2 * Items.value("jam"), "the farm shop buys jam")
	check(a.has_item("gem"), "but not the gem")
	UI.close_dialog("")
	await open_shop("dwarf_office")
	await at_shop("dwarf_office")
	await press("interact")
	await choose("Verkaufen: Edelstein")
	check(not a.has_item("gem"), "the dwarves buy the gem")


func test_gnome_insult() -> void:
	player().add_item("stone_gnome")
	await open_shop("dwarf_office")
	await at_shop("dwarf_office")
	await press("interact")
	await choose("Steinzwerg anbieten")
	check(GameState.is_unlocked("gnome_insult"), "Fettnäpfchen")
	check(world.find_actor("grimbart").last_said.contains("GARTENZWERG"), "Grimbart is outraged")


func test_inn_meal_and_room() -> void:
	var a := player()
	GameState.money = 3000
	a.needs.hunger = 80.0
	await open_shop("forest_inn")
	await at_shop("forest_inn")
	await press("interact")
	await shot("inn_menu")
	await choose("Kaiserschmarrn")
	await wait(4.5)
	check(a.needs.hunger < 40.0, "Kaiserschmarrn fills up (%.0f)" % a.needs.hunger)
	Clock.set_time(21.0)
	a.needs.fatigue = 90.0
	await press("interact")
	await choose("Zimmer für die Nacht")
	await wait_until(func() -> bool: return not game.player._sleeping_through, 20.0)
	check(Clock.hour() >= 6.0 and Clock.hour() < 7.0, "woke up at sunrise (%s)" % Clock.time_string())
	check(a.needs.fatigue < 1.0, "rested")
	check_eq(GameState.money, 3000 - 450 - 1200, "paid meal and room")


func test_campfire_rest() -> void:
	var a := player()
	var seat := world.find_free_seat(DwarfQuests.CAMPFIRE, a, 4.0)
	check(seat != null, "logs to sit on at the campfire")
	await put_player(seat.approach_point(), seat.position)
	a.sit_on(seat)
	a.needs.fatigue = 80.0
	a.needs.joy = 40.0
	await wait(20.0)
	var f_fire := a.needs.fatigue
	check(a.needs.joy > 40.0, "the campfire cheers up")
	a.stand_up()
	var bench := world.find_free_seat(place("great_meadow"), a, 60.0)
	await put_player(bench.approach_point(), bench.position)
	a.sit_on(bench)
	a.needs.fatigue = 80.0
	await wait(20.0)
	check(f_fire < a.needs.fatigue - 3.0, "rests faster than on a park bench (%.0f vs %.0f)" % [f_fire, a.needs.fatigue])


func test_dwarf_quest_props_gives_iron_pickaxe() -> void:
	var a := player()
	var grimbart := present("grimbart")
	var spot := place("dwarf_office") + Vector3(-8, 0, 10)
	await _talk(grimbart, spot)
	await choose("Hast du Arbeit")
	check(dialog_text().contains("6 Holzscheite"), "Grimbart asks for logs and stones")
	await choose("Mach ich")
	check_eq(DwarfQuests.state("props"), "active", "quest accepted")
	await wait(2.5)  # his "Glück auf!" bubble is gone
	await press("tasks")
	await shot("dwarf_task")
	UI.close_screens()
	a.add_item("log", 6)
	a.add_item("stone", 6)
	await _talk(grimbart, spot)
	await choose("Auftrag abgeben")
	check(a.has_item("iron_pickaxe") and not a.has_item("log"), "iron pickaxe for the props")
	check_eq(DwarfQuests.state("props"), "done", "done")
	UI.close_dialog("")
	await _talk(grimbart, spot)
	await choose("Hast du Arbeit")
	check(dialog_text().contains("Meisterprobe"), "then the master test")


func test_dwarf_quests_rewards() -> void:
	var a := player()
	# Brakka: food -> recipe.
	var brakka := present("brakka")
	brakka.teleport(place("dwarf_office") + Vector3(-4, 0, 5))
	check(not Crafting.for_station("campfire").has("dwarf_stew"), "the stew is a secret at first")
	await _talk(brakka)
	await choose("Hast du Arbeit")
	await choose("Mach ich")
	a.add_item("mushroom_pan")
	a.add_item("jam")
	await _talk(brakka)
	await choose("Auftrag abgeben")
	check(Crafting.for_station("campfire").has("dwarf_stew"), "Brakka's recipe unlocked")
	UI.close_dialog("")
	# Nori: gems -> dwarf axe.
	var nori := present("nori")
	nori.teleport(place("quarry") + Vector3(2, 0, 4))
	await _talk(nori)
	await choose("Hast du Arbeit")
	await choose("Mach ich")
	a.add_item("gem", 3)
	await _talk(nori)
	await choose("Auftrag abgeben")
	check(a.has_item("dwarf_axe"), "dwarf axe from Nori")
	UI.close_dialog("")
	# Thrain: switch tower score -> dwarf bag.
	var thrain := present("thrain")
	thrain.teleport(place("switch_tower") + Vector3(-4, 0, 3))
	await _talk(thrain)
	await choose("Hast du Arbeit")
	await choose("Mach ich")
	GameState.set_stat_max("switch_best", 15)
	await _talk(thrain)
	await choose("Auftrag abgeben")
	check(a.has_item("big_bag") and a.bag_slots() == 18, "dwarf bag from Thrain")


func test_quest_ring_on_dwarves() -> void:
	var grimbart := present("grimbart")
	grimbart.brain.suspend()
	grimbart.teleport(place("dwarf_office") + Vector3(3, 0, 6))
	await put_player(grimbart.global_position + Vector3(6, 0, 0))
	var whats: Array = Gameplay.markers.targets(player()).map(func(t: Dictionary) -> String: return t["what"])
	check(whats.has("grimbart"), "a gold ring at Grimbart with an open job")


## Forest people arrive by the forest gate or out of the mine, work, and stay in the forest.
func test_forest_people_live_in_the_forest() -> void:
	Clock.set_time(8.0)
	await wait(180.0)  # three game hours
	var seen := 0
	for id: String in ["holger", "sepp", "grimbart", "thrain", "nori", "hanna"]:
		var a := world.find_actor(id)
		if not a.inside:
			seen += 1
			check(ParkLayout.in_forest(a.ground_pos()), "%s is in the Nordwald" % id)
	check(seen >= 5, "most forest people came (%d)" % seen)
	check(world.shops["sawmill"].is_open() and world.shops["dwarf_office"].is_open(), "sawmill and dwarf office open at 11")

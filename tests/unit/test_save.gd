extends TestCase
## Save format: old versions are migrated on load (GameState.migrate), quest stages and days.


## Version 1 kept quest states as flags; they become stages in the stats.
func test_migrate_version_1() -> void:
	var data := {
		"version": 1,
		"stats": {"dwarf_quests": 1, "mime_freed": 1, "teddy_found": 1, "gnomes": 3},
		"flags": {"dq_props": "done", "dq_hunger": "active", "fs_teddy": "done", "fs_ghost": "active",
			"fs_delivery": "active", "mime_stuck": true, "mime_freed": true, "rusty_key_found": true,
			"troll_today_4": true, "kart_best_lap": 31.5},
	}
	GameState.migrate(data)
	var st: Dictionary = data["stats"]
	check_eq(data["version"], GameState.VERSION, "now the current version")
	check(not data.has("flags"), "no flags any more")
	check_eq(st["dq_props"], QuestModule.DONE, "dwarf quest done")
	check_eq(st["dq_hunger"], QuestModule.ACTIVE, "dwarf quest active")
	check_eq(st["teddy"], QuestModule.DONE, "teddy done")
	check_eq(st["ghost"], QuestModule.ACTIVE, "ghost active")
	check_eq(st["max_order"], 1, "Max waits for his food")
	check_eq(st["mime"], QuestModule.DONE, "mime freed")
	check_eq(st["rusty_key_found"], 1, "key found")
	check(not st.has("mime_freed") and not st.has("teddy_found"), "helper stats gone")
	check_eq(st["gnomes"], 3, "other stats kept")


## Version 2 kept a bag per character: the bag of the character played last becomes the
## player's, the others are dropped.
func test_migrate_version_2() -> void:
	var data := {
		"version": 2,
		"controlled": "lena",
		"actors": {"lena": {"needs": {}, "inv": {"log": 5.0, "teddy": 1.0}}, "jens": {"inv": {"gem": 2.0}}},
	}
	GameState.migrate(data)
	check_eq(data["version"], GameState.VERSION, "now the current version")
	check_eq(data["inventory"], {"log": 5.0, "teddy": 1.0}, "Lena's bag is the player's")
	check(not data["actors"]["lena"].has("inv") and not data["actors"]["jens"].has("inv"), "no bags per character")


## Every achievement waits for a stat or set that the game writes somewhere.
func test_achievement_stats_are_written() -> void:
	var src := ""
	for dir: String in ["res://src/game", "res://src/minigames", "res://src/actors", "res://src/interact",
			"res://src/world", "res://src/ai", "res://src/vehicles", "res://src/autoload", "res://src/ui"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				src += FileAccess.get_file_as_string(dir.path_join(f))
	for d: Dictionary in Achievements.DEFS:
		var key: String = d["stat"]
		check(src.contains('"%s"' % key), "%s: stat %s is written" % [d["id"], key])


func test_days_and_stages() -> void:
	GameState.new_game()
	check(not GameState.done_today("x_day"), "never done")
	GameState.mark_today("x_day")
	check(GameState.done_today("x_day"), "done today")
	check(not GameState.done_today("x_day", Clock.day + 1), "not tomorrow")
	GameState.set_stage("x_quest", QuestModule.ACTIVE)
	check_eq(GameState.stage("x_quest"), QuestModule.ACTIVE, "stage kept")
	GameState.new_game()


## Achievement targets that count content match the content.
func test_achievement_targets_match_the_content() -> void:
	var counts := {"gnomes": EasterEggs.GNOMES.size(), "dwarf_quests": DwarfQuests.QUESTS.size(),
		"stamps": FairPass.STAMPS.size(), "rides_thrice": FairPass.RIDES.size(), "tricks": FairStories.TRICKS.size(),
		"pg_step": PlaygroundQuests.ALL_HAPPY, "playground_devices": Playground.DEVICES.size(),
		"assistant_step": 6}
	for d: Dictionary in Achievements.DEFS:
		if counts.has(d["stat"]):
			check_eq(d["target"], counts[d["stat"]], "%s: target" % d["id"])


## A stat the game reads is written somewhere (a typo in a key would read 0 forever).
func test_read_stats_are_written() -> void:
	var src := ""
	for dir: String in ["res://src/game", "res://src/minigames", "res://src/actors", "res://src/interact",
			"res://src/world", "res://src/ai", "res://src/vehicles", "res://src/autoload", "res://src/ui"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				src += FileAccess.get_file_as_string(dir.path_join(f))
	var read := RegEx.create_from_string('GameState\\.(?:stat|stage|done_today|has_in_set)\\("([a-z_0-9]+)"')
	var written := RegEx.create_from_string('(?:add_stat|set_stat|set_stat_max|set_stage|mark_today|add_to_set)\\("([a-z_0-9]+)"')
	var keys := {}
	for m in written.search_all(src):
		keys[m.get_string(1)] = true
	for m in read.search_all(src):
		check(keys.has(m.get_string(1)), "stat %s is read and written" % m.get_string(1))

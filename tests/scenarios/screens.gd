extends Scenario
## Menus and screens: map (open, walk by clicking), notebook, pause menu, settings,
## save/load, title screen with new game, toasts.


func test_map_opens_and_closes_with_m() -> void:
	await press("map")
	check(UI._modal == "map", "M opens the map")
	await press("map")
	check(UI._modal == "", "M closes it again")
	await press("map")
	await press("pause")
	check(UI._modal == "", "Esc closes the map")
	check(not get_tree().paused, "Esc on the map does not pause")


func test_map_hud_button() -> void:
	check(await click_button("Karte"), "HUD button Karte")
	check(UI._modal == "map", "button opens the map")
	check(await click_button("Schließen"), "Schließen button")
	check(UI._modal == "", "closed")


## Clicking a place on the map walks there.
func test_map_click_walks_there() -> void:
	await press("map")
	await wait(0.2)
	var ms: MapScreen = UI.map_screen
	var target := place("food_court")
	var p := ms.tex_rect.get_global_transform_with_canvas() * ms.world_to_map(target)
	await click_at(p)
	check(UI._modal == "", "map closes after the click")
	check(player().is_moving(), "player walks")
	check(toasted("Unterwegs"), "toast Unterwegs")
	# The middle of the food court is full of tables; arriving close by is enough.
	check(await wait_until(func() -> bool: return not player().is_moving(), 120.0), "walk ends")
	check(player().distance_to(target) < 8.0, "arrived at the food court (%.1f m)" % player().distance_to(target))


func test_notebook_tabs() -> void:
	await press("tasks")
	check(UI._modal == "tasks", "J opens the notebook")
	var tabs: TabContainer = UI.tasks_screen.tabs
	check_eq(tabs.get_tab_count(), 3, "three tabs")
	var titles := []
	for i in tabs.get_tab_count():
		titles.append(tabs.get_tab_title(i))
	check(titles == ["Aufgaben", "Erfolge", "Parkbewohner"], "tab titles %s" % str(titles))
	var text := ""
	for l in UI.tasks_screen.find_children("*", "Label", true, false):
		text += (l as Label).text + "\n"
	check(text.contains("von 29 Erfolgen"), "achievement count shown")
	check(text.contains("Minispiel: Boule"), "boule task listed")
	await press("tasks")
	check(UI._modal == "", "J closes it")


func test_notebook_marks_done_task() -> void:
	GameState.add_stat("boule_wins")
	await press("tasks")
	var found := false
	for l in UI.tasks_screen.find_children("*", "Label", true, false):
		if (l as Label).text.contains("Boule") and (l as Label).text.contains("geschafft"):
			found = true
	check(found, "boule task shows geschafft after a win")


func test_pause_menu_stops_time() -> void:
	await press("pause")
	check(UI._modal == "pause", "Esc opens the pause menu")
	check(get_tree().paused, "game paused")
	var t := Clock.minutes
	await frames(30)
	check(is_equal_approx(Clock.minutes, t), "clock stands still while paused")
	check(await click_button("Weiterspielen"), "Weiterspielen")
	check(not get_tree().paused, "game runs again")


func test_save_from_pause_menu_and_load() -> void:
	GameState.add_money(123, "")
	GameState.add_stat("wishes")
	await press("pause")
	check(await click_button("Spiel speichern"), "Spiel speichern")
	check(toasted("Gespeichert!"), "toast Gespeichert")
	await click_button("Weiterspielen")
	var money := GameState.money
	GameState.new_game()
	check(GameState.load_game(), "save file loads")
	check_eq(GameState.money, money, "money restored")
	check_eq(GameState.stat("wishes"), 1, "stats restored")
	check_eq(GameState.controlled_actor, "jens", "controlled character restored")


func test_settings_quality_and_back() -> void:
	await press("pause")
	check(await click_button("Einstellungen"), "Einstellungen")
	check(await click_button("Niedrig"), "quality button Niedrig")
	check_eq(GameState.settings["quality"], "low", "quality set to low")
	check(game.camera.far == 400.0, "low quality shortens the view distance")
	await click_button("Hoch")
	check(await click_button("Zurück"), "Zurück")
	check(find_button("Weiterspielen") != null, "back in the pause menu")
	await click_button("Weiterspielen")


func test_help_screen() -> void:
	await press("pause")
	check(await click_button("Steuerung & Hilfe"), "Steuerung & Hilfe")
	check(await click_button("Zurück"), "Zurück from help")
	await click_button("Weiterspielen")


func test_title_new_game_with_starter() -> void:
	GameState.add_money(1000, "")
	game.title_mode = true
	UI.show_title(false, game._continue, game._new_game)
	await wait(0.2)
	check(UI._modal == "title", "title screen shown")
	check(find_button("Weiterspielen") == null, "no Weiterspielen without a save")
	await press("interact")
	check(UI._modal == "title", "game input blocked on the title screen")
	check(await click_button("Neues Spiel"), "Neues Spiel")
	check(await click_button("Opa Herbert"), "starter Herbert offered")
	await wait(0.3)
	check_eq(player().actor_id, "herbert", "playing Herbert")
	check_eq(GameState.money, 500, "new game starts with 5 €")
	check(toasted("Willkommen im Stadtpark"), "welcome toast")
	check(not game.title_mode, "title mode ended")


func test_title_continue() -> void:
	game.title_mode = true
	GameState.controlled_actor = "jens"
	UI.show_title(true, game._continue, game._new_game)
	await wait(0.2)
	check(await click_button("Weiterspielen"), "Weiterspielen on the title")
	check_eq(player().actor_id, "jens", "continues with the saved character")


## Regression: the 6th toast within ~4 s froze the game and ate all memory.
func test_many_toasts_at_once() -> void:
	for i in 12:
		GameState.toast.emit("Toast %d" % i, "info")
	await frames(2)
	check(UI._toasts.get_child_count() <= 5, "at most five toasts (%d)" % UI._toasts.get_child_count())


func test_hud_shows_money_and_clock() -> void:
	GameState.add_money(250, "Test")
	await wait(0.5)
	var hud: Hud = UI.hud
	check(hud.money_label.text == "7,50 €", "money label (%s)" % hud.money_label.text)
	check(hud.clock_label.text.begins_with("11:"), "clock label (%s)" % hud.clock_label.text)
	check(toasted("+2,50 €  Test"), "money toast")

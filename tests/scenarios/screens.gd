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
	check(text.contains("von %d Erfolgen" % Achievements.DEFS.size()), "achievement count shown")
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
	# What a saved game leaves behind when it is loaded for the title screen.
	Clock.set_time(19.5)
	Clock.day = 5
	var herbert := present("herbert")
	herbert.add_item("apple", 3)
	herbert.needs.hunger = 0.0
	herbert.needs.fatigue = 0.0
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
	check(Clock.time_string() == "09:00" or Clock.time_string() == "09:01", "the clock starts at 9:00 (%s)" % Clock.time_string())
	check_eq(Clock.day, 0, "on the first day")
	check(player().inventory.is_empty(), "an empty bag (%s)" % str(player().inventory))
	check(player().needs.hunger >= 5.0 and player().needs.fatigue >= 5.0, "needs as at the first start (hunger %.0f, fatigue %.0f)" % [player().needs.hunger, player().needs.fatigue])
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


## The game saves itself every minute while a character is played.
func test_autosave_every_minute() -> void:
	GameState.delete_save()
	GameState._autosave = 55.0
	await wait(2.0)
	check(not GameState.has_save(), "no save before the minute is up")
	await wait(4.0)
	check(GameState.has_save(), "saved after a minute")


## Needs and the bag come back with a loaded game (the load path of the start-up, Game._ready).
func test_needs_and_bag_survive_loading() -> void:
	var a := player()
	a.needs.hunger = 42.0
	a.needs.fatigue = 33.0
	a.needs.joy = 61.0
	a.add_item("apple", 2)
	GameState.save_game()
	a.needs.hunger = 90.0
	a.needs.joy = 5.0
	a.inventory.clear()
	check(GameState.load_game(), "the save loads")
	for o in world.actors:
		o.load_state()
	check(absf(a.needs.hunger - 42.0) < 0.5 and absf(a.needs.fatigue - 33.0) < 0.5 and absf(a.needs.joy - 61.0) < 0.5,
		"needs restored (%.0f/%.0f/%.0f)" % [a.needs.hunger, a.needs.fatigue, a.needs.joy])
	check_eq(a.inventory.get("apple", 0), 2, "apples back in the bag")


## "Neues Spiel" in the pause menu asks first; "Nein" goes back and keeps the game. ("Ja"
## reloads the scene, which ends the scenario runner with it: not testable here.)
func test_new_game_from_pause_menu_asks() -> void:
	GameState.add_money(300, "")
	var money := GameState.money
	await press("pause")
	check(await click_button("Neues Spiel"), "Neues Spiel in the pause menu")
	check(dialog_text().contains("Wirklich neu anfangen"), "asks first (%s)" % dialog_text())
	check(await choose("Nein"), "Nein")
	await wait(0.2)
	check(UI._modal == "pause" and find_button("Weiterspielen") != null, "back in the pause menu")
	check_eq(GameState.money, money, "the game goes on unchanged")
	await click_button("Weiterspielen")
	check(not get_tree().paused, "game runs again")


## The settings' sliders, moved with the mouse: volume (Sound), music, camera sensitivity.
func test_settings_sliders() -> void:
	await press("pause")
	check(await click_button("Einstellungen"), "Einstellungen")
	var sliders: Array[HSlider] = []
	for n in UI.root.find_children("*", "HSlider", true, false):
		if (n as HSlider).is_visible_in_tree():
			sliders.append(n)
	check_eq(sliders.size(), 3, "volume, music and camera sliders")
	if sliders.size() < 3:
		return
	await _click_slider(sliders[0], 0.0)
	check(GameState.settings["volume"] < 0.1 and Sound._volume < 0.1, "volume down (%.2f)" % Sound._volume)
	Sound._ui.stream = null
	Sound.play("bark")
	check(Sound._ui.stream == null, "no sound at volume 0")
	await _click_slider(sliders[0], 1.0)
	Sound.play("bark")
	check(Sound._ui.stream == Sound._stream("bark"), "sound plays again")
	await _click_slider(sliders[1], 0.0)
	check(GameState.settings["music"] < 0.1 and Sound._ambient_volume < 0.1, "music down (%.2f)" % Sound._ambient_volume)
	await _click_slider(sliders[2], 1.0)
	check(game.camera.sensitivity > 2.0, "camera sensitivity up (%.2f)" % game.camera.sensitivity)
	for i in 3:   # back to the defaults for the later tests
		sliders[i].value = GameState.DEFAULT_SETTINGS[["volume", "music", "camera_sensitivity"][i]]
	await click_button("Zurück")
	await click_button("Weiterspielen")


## The notebook's "Parkbewohner" tab lists everybody, the played ones marked.
func test_notebook_residents_tab() -> void:
	GameState.add_to_set("characters", "herbert")
	await press("tasks")
	var tabs: TabContainer = UI.tasks_screen.tabs
	var bar := tabs.get_tab_bar()
	await click_at(bar.get_global_transform_with_canvas() * bar.get_tab_rect(2).get_center())
	check_eq(tabs.current_tab, 2, "a click opens the Parkbewohner tab")
	var text := ""
	for l in tabs.get_current_tab_control().find_children("*", "Label", true, false):
		text += (l as Label).text + "\n"
	check(text.contains("Opa Herbert  (schon gespielt)"), "Herbert is marked as played")
	check(text.contains("wird gerade von dir gespielt"), "the played character says so")
	check(text.contains("Hundesitterin Mia\n") and text.contains("Gerade: "), "the others with what they do")
	await press("tasks")


## Clicks a slider at `fraction` of its width (0 = left end).
func _click_slider(s: HSlider, fraction: float) -> void:
	var r := s.get_global_rect()
	await click_at(Vector2(r.position.x + r.size.x * clampf(fraction, 0.02, 0.98), r.get_center().y))
	await frames(2)

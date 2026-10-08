extends Scenario
## UI layout on desktop, phone and tablet screens, with keyboard and touch controls:
## every panel and button on screen, nothing overlapping, and the things the player
## looks at (own character, the NPC they talk to, minigame objects) not hidden by UI.
## Natively these are layout checks (check_layout); the browser run
## (scripts/web_test.sh scenario:layout) also takes a phone-sized screenshot of each.


## Runs check_layout / shot for every screen and both control modes (only touch on the
## phone-sized browser window). `targets` is a Callable returning name -> world position.
func _each(label: String, targets := Callable(), allow: Array[String] = [], before := Callable()) -> void:
	for s: String in screens():
		await set_screen(s)
		for touch: bool in ([true] if s == "browser" else [false, true]):
			Controls.set_touch_mode(touch)
			if before.is_valid():
				before.call()  # e.g. toasts, which fade after a few seconds
			await frames(2)
			var t: Dictionary = targets.call() if targets.is_valid() else {}
			await shot("%s_%s%s" % [label, s, "_touch" if touch else ""], t, allow)
	Controls.set_touch_mode(false)
	await set_screen("desktop")


func _me() -> Dictionary:
	return {"player": head(player())}


func _talk_to(id: String) -> Actor:
	var npc := present(id)
	npc.brain.suspend()
	await next_to(id, 2.0)
	game.camera.follow(player(), false)
	await press("interact")
	await wait(0.3)
	return npc


func test_hud_walking() -> void:
	await _each("hud", _me)


func test_hud_with_prompt_and_inventory() -> void:
	player().add_item("bread", 3)
	player().add_item("nut", 2)
	var g: Interactable = spots_with_prompt("Was ist das da?")[0]
	await put_player(g.global_position + Vector3(1.0, 0, 0), g.global_position)
	await _each("prompt", func() -> Dictionary: return {"player": head(player()), "gnome": g.global_position})


func test_toasts_and_achievement() -> void:
	await _each("toasts", _me, [], func() -> void:
		for i in 4:
			GameState.toast.emit("Ein ziemlich langer Hinweis Nummer %d, der umbricht" % (i + 1), "info")
		UI._on_achievement("saver"))


func test_quest_dialog_mia() -> void:
	var mia := present("mia")
	mia.teleport(place("great_meadow") + Vector3(4, 0, 0))
	await _talk_to("mia")
	check(UI.is_dialog_open(), "Mia's dialog")
	await _each("dialog_mia", func() -> Dictionary: return {"player": head(player()), "mia": head(mia)})


func test_quest_dog_walk_running() -> void:
	var mia := present("mia")
	for d: String in mia.def["dogs"]:
		present(d)
	mia.teleport(place("great_meadow") + Vector3(4, 0, 0))
	await _talk_to("mia")
	await choose("Gassi-Auftrag annehmen")
	UI.close_dialog("")
	await wait(0.5)
	await _each("dog_walk", _me)  # the dog trots behind the player, often behind the camera
	await press("tasks")
	await _each("dog_walk_tasks")


func test_quest_mime_and_lena() -> void:
	GameState.set_flag("mime_stuck")
	var pierre := await _talk_to("pierre")
	await choose("Was ist los, Pierre?")
	await _each("mime_dialog", func() -> Dictionary: return {"player": head(player()), "pierre": head(pierre)})
	UI.close_dialog("")
	var lena := await _talk_to("lena")
	await choose("Hast du etwas gefunden?")
	await _each("lena_dialog", func() -> Dictionary: return {"player": head(player()), "lena": head(lena)})


func test_quest_troll_riddle_at_night() -> void:
	await reset("jens", 23.0)
	var bruno := await _talk_to("bruno")
	await choose("Ein Rätsel lösen")
	await _each("riddle", func() -> Dictionary: return {"player": head(player()), "bruno": head(bruno)})


func test_shop_menu() -> void:
	var shop := await open_shop("donut_stand")
	check(shop != null, "donut stand opens")
	await at_shop("donut_stand")
	await press("interact")
	await wait(0.3)
	var v := present(shop.vendor_id)
	await _each("shop_kiosk", func() -> Dictionary: return {"player": head(player()), "vendor": head(v)})


func test_on_bench() -> void:
	await on_bench(90.0)
	await _each("bench", _me)


func test_screens_map_tasks_pause_switch() -> void:
	await press("map")
	await _each("map")
	UI.close_screens()
	await press("tasks")
	await _each("tasks")
	UI.close_screens()
	await press("pause")
	await _each("pause")
	await click_button("Einstellungen")
	await _each("settings")
	UI.close_pause()
	for id: String in ["lena", "herbert", "peggy"]:
		present(id).teleport(player().global_position + Vector3(randf_range(-6, 6), 0, randf_range(3, 8)))
	UI.open_switch_menu()
	await wait(0.3)
	await _each("switch")


func test_title_and_starter() -> void:
	game.title_mode = true
	UI.show_hud(false)  # like at the start of the game
	UI.show_title(true, game._continue, game._new_game)
	await wait(0.3)
	await _each("title")
	await click_button("Neues Spiel")
	await wait(0.3)
	await _each("starter")


# --- Minigames ------------------------------------------------------------------------------

func test_mg_boule() -> void:
	var m: BouleGame = await in_minigame("boule")
	await wait(2.0)
	await _each("mg_boule", func() -> Dictionary: return {"court": Vector3(m.court_c.x, m.court_y, m.court_c.y)})


func test_mg_minigolf() -> void:
	var m: MinigolfGame = await in_minigame("minigolf")
	await wait(1.5)
	await _each("mg_minigolf", func() -> Dictionary: return {"ball": Vector3(m.ball.p.x, m.base_y, m.ball.p.y),
		"cup": Vector3(m.cup_world.x, m.base_y, m.cup_world.y)})


func test_mg_shell() -> void:
	var m: ShellGame = await in_minigame("shell")
	await wait(1.0)
	await _each("mg_shell", func() -> Dictionary:
		var out := {}
		for i in m.cups.size():
			out["cup%d" % i] = m.cups[i].global_position
		return out)


func test_mg_ttt() -> void:
	var m: TicTacToeGame = await in_minigame("ttt")
	await wait(1.0)
	await _each("mg_ttt", func() -> Dictionary:
		var out := {}
		for i in 9:
			out["cell%d" % i] = m.cell_pos(i)
		return out)


func test_mg_photo() -> void:
	await in_minigame("photo")
	await wait(1.0)
	await _each("mg_photo")


func test_mg_ducks() -> void:
	var m: DuckFeedingGame = await in_minigame("ducks")
	await wait(1.0)
	await _each("mg_ducks", func() -> Dictionary: return {"player": head(player()), "target": m.target})


func test_mg_frisbee() -> void:
	await in_minigame("frisbee")
	await wait(1.0)
	await _each("mg_frisbee", _me)


func test_mg_bottles() -> void:
	await in_minigame("bottles")
	await wait(1.0)
	await _each("mg_bottles", _me)


## An achievement during a minigame: both panels sit at the top centre.
func test_achievement_during_minigame() -> void:
	await in_minigame("shell")
	await wait(1.0)
	await _each("mg_achievement", Callable(), [], func() -> void: UI._on_achievement("saver"))

extends Scenario
## Reach tests: every minigame can be started by playing (walk there + Aktion, or talk
## to the host). The per-game scenario files start inside the game (in_minigame).


func _reach_spot(id: String, money_needed := 0) -> void:
	var m: Minigame = Gameplay.minigames[id]
	if m.host():
		present(m.host_id).brain.suspend()
	var spot := minigame_spot(id)
	check(spot != Vector3.INF, "%s has a start spot" % id)
	check(await walk_to(spot, 240.0), "walked to the %s spot" % id)
	await wait(0.4)
	check(prompt() != "" and not prompt().contains("nicht da"), "%s prompt (got '%s')" % [id, prompt()])
	var money := GameState.money
	await press("interact")
	await wait(0.5)
	check(m.active, "Aktion starts %s (prompt was '%s')" % [id, prompt()])
	check_eq(money - GameState.money, money_needed, "%s entry fee" % id)


func _reach_talk(id: String, option: String) -> void:
	var m: Minigame = Gameplay.minigames[id]
	present(m.host_id).brain.suspend()
	await next_to(m.host_id)
	await press("interact")
	await wait(0.3)
	check(await choose(option), "%s: dialog offers '%s' (options %s)" % [m.host_id, option, str(dialog_options())])
	await wait(0.5)
	check(m.active, "talking to %s starts %s" % [m.host_id, id])


func test_boule_spot() -> void:
	await _reach_spot("boule")


func test_minigolf_spot_costs_two_euro() -> void:
	await _reach_spot("minigolf", 200)


func test_minigolf_needs_money() -> void:
	GameState.money = 100
	await put_player(minigame_spot("minigolf"))
	await wait(0.4)
	await press("interact")
	await wait(0.3)
	check(not Gameplay.minigames["minigolf"].active, "no start without 2 €")
	check_eq(GameState.money, 100, "money unchanged")


func test_shell_spot_costs_two_euro() -> void:
	await _reach_spot("shell", 200)


func test_ttt_spot() -> void:
	await _reach_spot("ttt")


func test_ducks_spot() -> void:
	await _reach_spot("ducks")


func test_bottles_spot() -> void:
	await _reach_spot("bottles")


func test_frisbee_by_talking_to_lukas() -> void:
	await _reach_talk("frisbee", "Frisbee")


func test_photo_by_talking_to_peggy() -> void:
	await _reach_talk("photo", "Foto")


func test_shell_by_talking_to_harry() -> void:
	await _reach_talk("shell", "Hütchenspiel")


func test_spot_says_host_missing() -> void:
	var h := present("jacques")
	var brain := h.brain
	h.brain = null  # keep him at home for this test
	h.inside = true
	h.visible = false
	await put_player(minigame_spot("boule"))
	await wait(0.4)
	check(prompt().contains("nicht da"), "prompt says Jacques is away (got '%s')" % prompt())
	await press("interact")
	check(not Gameplay.minigames["boule"].active, "no start without the host")
	h.brain = brain

extends Scenario
## Holiday photo for Peggy: look around, zoom, take three photos, score and pay.


func test_look_zoom_and_shoot() -> void:
	var m := await in_minigame("photo") as PhotoGame
	var y0 := m.yaw
	await hold("move_left", 0.5)
	check(absf(m.yaw - y0) > 0.1, "keys turn the camera")
	var f0 := m.fov
	check(await click_button("+"), "zoom button +")
	check(m.fov < f0, "+ zooms in")
	await press("interact")
	check_eq(m.shots, 1, "one photo taken")
	check(m._busy, "busy while the photo is shown")
	await press("interact")
	check_eq(m.shots, 1, "no second photo while busy")


func test_three_photos_end_the_game() -> void:
	var m := await in_minigame("photo") as PhotoGame
	var money := GameState.money
	var result := await play_until_done(m, func() -> void:
		if not m._busy:
			_action("interact", true)
			_action("interact", false), 60.0)
	check(not m.active, "game over after three photos (or a perfect one)")
	check(GameState.money - money >= 100, "at least 1 € (got %d ct)" % (GameState.money - money))
	check(result.has("won"), "result reported")


## Regression: shots were not reset, so a second game with Peggy could never end.
func test_play_twice() -> void:
	for round in 2:
		var m := await in_minigame("photo") as PhotoGame
		check_eq(m.shots, 0, "round %d starts with no photos" % round)
		await play_until_done(m, func() -> void:
			if not m._busy:
				_action("interact", true)
				_action("interact", false), 60.0)
		check(not m.active, "round %d ends" % round)
		UI.close_dialog("")

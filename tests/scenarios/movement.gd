extends Scenario
## Walking, running, tap-to-walk, camera orbit and zoom (keyboard, mouse and touch).


func test_walk_with_keys() -> void:
	var a := player()
	var p0 := a.global_position
	await move(Vector2(0, 1), 2.0)
	var d := a.global_position.distance_to(p0)
	check(d > 3.0, "walked forward (%.1f m in 2 s)" % d)


func test_run_is_faster_than_walking() -> void:
	var a := player()
	var p0 := a.global_position
	await move(Vector2(0, 1), 1.5)
	var walk := a.global_position.distance_to(p0)
	p0 = a.global_position
	await move(Vector2(0, -1), 1.5, true)
	var run := a.global_position.distance_to(p0)
	check(run > walk * 1.6, "running is faster (walk %.1f m, run %.1f m)" % [walk, run])


## Player is twice as fast as NPCs, but fast walking does not count as running for needs.
func test_player_walk_does_not_tire_like_running() -> void:
	var a := player()
	a.needs.fatigue = 20.0
	await move(Vector2(0, 1), 20.0)
	check(a.needs.fatigue < 20.0 + 3.0, "walking 20 game minutes adds little fatigue (%.1f)" % a.needs.fatigue)


func test_touch_run_toggle() -> void:
	Controls.set_touch_mode(true)
	await wait(0.2)
	check(await tap_button("Rennen"), "Rennen button visible")
	check(game.player.touch_run, "Rennen toggles running on")
	await tap_button("Rennen")
	check(not game.player.touch_run, "second tap toggles it off")


## Tap on the ground walks there (touch).
func test_tap_to_walk() -> void:
	Controls.set_touch_mode(true)
	var a := player()
	await wait(0.5)
	var target := a.global_position + a.forward() * 8.0
	var screen: Vector2 = game.camera.unproject_position(target)
	await tap_screen(screen)
	await wait(0.2)
	check(a.is_moving(), "tap starts walking")
	check(await wait_until(func() -> bool: return not a.is_moving(), 15.0), "arrives")
	check(a.distance_to(target) < 2.5, "arrived near the tapped point (%.1f m)" % a.distance_to(target))


## Desktop: left click on the ground walks there.
func test_click_to_walk_with_mouse() -> void:
	var a := player()
	await wait(0.5)
	var target := a.global_position + a.forward() * 8.0
	await click_at(game.camera.unproject_position(target))
	await wait(0.2)
	check(a.is_moving(), "click starts walking")
	check(await wait_until(func() -> bool: return not a.is_moving(), 15.0), "arrives")
	check(a.distance_to(target) < 2.5, "arrived near the clicked point (%.1f m)" % a.distance_to(target))


## Tap on the sky (no ground under the finger): nothing happens.
func test_tap_on_sky_does_nothing() -> void:
	Controls.set_touch_mode(true)
	await wait(0.5)
	await tap_screen(Vector2(640, 20))
	await wait(0.5)
	check(not player().is_moving(), "does not walk")


func test_mouse_wheel_zoom() -> void:
	var cam: CameraRig = game.camera
	var z0: float = cam.zoom
	for i in 3:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		Input.parse_input_event(ev)
		await frames(2)
	check(cam.zoom > z0 * 1.2, "wheel down zooms out (%.2f -> %.2f)" % [z0, cam.zoom])


func test_touch_zoom_buttons_and_limits() -> void:
	Controls.set_touch_mode(true)
	await wait(0.2)
	var cam: CameraRig = game.camera
	for i in 12:
		await tap_button("-")
	check(is_equal_approx(cam.zoom, 3.5), "zoom out is limited to 3.5 (%.2f)" % cam.zoom)
	for i in 12:
		await tap_button("+")
	check(is_equal_approx(cam.zoom, 0.45), "zoom in is limited to 0.45 (%.2f)" % cam.zoom)


func test_pinch_zoom() -> void:
	Controls.set_touch_mode(true)
	await wait(0.2)
	var cam: CameraRig = game.camera
	var z0: float = cam.zoom
	var c := Vector2(640, 300)
	for i in 2:
		var ev := InputEventScreenTouch.new()
		ev.index = i
		ev.position = c + Vector2(-60 if i == 0 else 60, 0)
		ev.pressed = true
		Input.parse_input_event(ev)
	await frames(2)
	for step in 6:
		for i in 2:
			var d := InputEventScreenDrag.new()
			d.index = i
			d.position = c + Vector2((-60 - step * 25) if i == 0 else (60 + step * 25), 0)
			Input.parse_input_event(d)
		await frames(2)
	for i in 2:
		var ev := InputEventScreenTouch.new()
		ev.index = i
		ev.position = c
		ev.pressed = false
		Input.parse_input_event(ev)
	await frames(2)
	check(cam.zoom < z0 * 0.6, "spreading two fingers zooms in (%.2f -> %.2f)" % [z0, cam.zoom])
	check(not player().is_moving(), "pinching does not walk")


func test_camera_keys_turn() -> void:
	var cam: CameraRig = game.camera
	var y0: float = cam.yaw
	await hold("cam_left", 0.5)
	check(absf(cam.yaw - y0) > 0.3, "cam_left turns the camera")

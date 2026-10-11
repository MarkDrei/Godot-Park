extends Scenario
## Performance: actors far from the camera update less often (and still get where they go),
## the town's traffic rests while the player is in the park, the bucket grids for cars and
## people find the same as a full search, and the performance overlay in the settings.

const PARK := Vector3(60, 0, -40)
const TOWN := Vector3(240, 0, -51)   # market square


func test_far_actors_update_less_often() -> void:
	await put_player(PARK)
	await wait(0.5)
	var far: Actor = null
	for a in world.actors:
		if a.is_human() and not a.inside and not a.controlled and a.lod_distance > 170.0:
			far = a
	check(far != null, "somebody far away")
	if far == null:
		return
	check_eq(far.lod_step(), 8, "far away: every 8th physics frame")
	check_eq(player().lod_step(), 1, "the player: every frame")
	# Still walks to its goal, in coarser steps.
	far.brain.suspend()
	(far.brain as HumanBrain).think = 600.0
	var goal := far.global_position
	for i in 16:
		var q := far.global_position + Vector3(cos(i * TAU / 16.0), 0, sin(i * TAU / 16.0)) * 12.0
		if not world.map.is_solid(Vector2(q.x, q.z), far.nav_profile) and Vector2(q.x - PARK.x, q.z - PARK.z).length() > 170.0:
			goal = q
			break
	check(goal != far.global_position, "a free spot 12 m away")
	far.go_to(goal)
	check(await wait_until(func() -> bool: return far.path.is_empty() and far.global_position.distance_to(goal) < 1.5, 30.0),
		"far walker arrives (%.1f m left)" % far.global_position.distance_to(goal))
	# Fewer updates than actors.
	var t0 := Actor.ticks
	var f0 := Engine.get_physics_frames()
	await frames(30)
	var per_step := float(Actor.ticks - t0) / maxi(1, Engine.get_physics_frames() - f0)
	check(per_step < world.actors.size() * 0.8, "%.0f of %d actors update per physics frame" % [per_step, world.actors.size()])


func test_traffic_rests_in_the_park() -> void:
	var t := (await city()).traffic
	await put_player(TOWN)
	await wait(1.0)
	check(not t.resting, "traffic drives while the player is in town")
	await put_player(PARK)
	await wait(0.5)
	check(t.resting, "traffic rests while the player is in the park")
	var before := {}
	for a: Traffic.Agent in t.agents:
		before[a.car] = a.car.pos2()
	await wait(2.0)
	var moved := 0
	for c: Car in before:
		if is_instance_valid(c) and c.pos2().distance_to(before[c]) > 0.05:
			moved += 1
	check_eq(moved, 0, "no AI car moved while resting")
	await put_player(TOWN)
	await wait(4.0)
	check(not t.resting, "back in town: the traffic drives again")
	moved = 0
	for c: Car in before:
		if is_instance_valid(c) and c.pos2().distance_to(before[c]) > 1.0:
			moved += 1
	check(moved >= 3, "%d AI cars drove on" % moved)


func test_grids_find_the_same_as_a_full_search() -> void:
	await city()
	await wait(0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 40:
		var p := Vector2(rng.randf_range(135, 385), rng.randf_range(-265, 85))
		var r := rng.randf_range(3.0, 30.0)
		var full := world.city.cars.filter(func(c: Car) -> bool: return c.pos2().distance_to(p) <= r)
		check_eq(world.city.cars_near(p, r).size(), full.size(), "cars within %.0f m of %s" % [r, str(p.round())])
	for i in 40:
		var q := Vector3(rng.randf_range(-130, 390), 0, rng.randf_range(-270, 90))
		var r := rng.randf_range(2.0, 40.0)
		var full := world.actors.filter(func(a: Actor) -> bool:
			return a.visible and not a.inside and Vector2(a.global_position.x - q.x, a.global_position.z - q.z).length() <= r)
		check_eq(world.actors_near(q, r).size(), full.size(), "people within %.0f m of %s" % [r, str(q.round())])
	# A car put somewhere by hand is found there at once.
	var c := await new_car("small", Vector2(208.25, -30.0))
	c.place(Vector2(208.25, -20.0), 0.0)
	check(world.city.car_at(Vector2(208.25, -20.0)) == c, "moved car found at its new place")


func test_performance_overlay() -> void:
	GameState.settings["show_fps"] = false   # settings.cfg is shared by all runs
	await press("pause")
	check(await click_button("Einstellungen"), "Einstellungen")
	check(await tap_button("Leistung anzeigen"), "checkbox Leistung anzeigen")
	check(GameState.settings.get("show_fps", false), "setting on")
	await click_button("Zurück")
	await click_button("Weiterspielen")
	await wait(3.0)
	var text := UI.hud.fps_label.text
	check(UI.hud.fps_label.visible and text.contains("FPS") and text.contains("Skript") and text.contains("Draws")
		and text.contains("Figuren aktiv") and not text.contains(" 0/"), "overlay shows frame rate, script time, draw calls, actors (%s)" % text)
	for screen in screens():
		await set_screen(screen)
		check_layout("perf overlay " + screen)
	await set_screen("desktop")
	GameState.settings["show_fps"] = false
	GameState.save_settings()

extends Scenario
## Benches: sitting, fatigue recovery, nap, night sleep (keyboard and touch).


## Reach: walk to the nearest bench by pathfinding and sit down with "Aktion".
func test_reach_bench_and_sit() -> void:
	var a := player()
	var bench: Bench = null
	for b in world.benches:
		if b.free_seat(a) and (bench == null or a.distance_to(b.position) < a.distance_to(bench.position)):
			bench = b
	var front := bench.position + Vector3(sin(bench.rotation.y), 0, cos(bench.rotation.y)) * 1.2
	check(await walk_to(front), "walked to the bench")
	a.face(bench.position, true)
	await wait(0.4)
	check(prompt().begins_with("Hinsetzen"), "prompt offers sitting (got '%s')" % prompt())
	await press("interact")
	await wait(1.0)
	check(a.seat != null, "sits after Aktion")
	check(GameState.has_in_set("benches", bench.bench_id), "bench counted for Bankdrücker")
	await press("interact")
	await wait(0.5)
	check(a.seat == null, "Aktion again stands up")


func test_sitting_recovers_fatigue() -> void:
	await on_bench(80.0)
	var before := player().needs.fatigue
	await wait(20.0)  # 20 game seconds ≈ 20 game minutes
	check(player().needs.fatigue < before - 15.0, "fatigue drops while sitting (%.0f -> %.0f)" % [before, player().needs.fatigue])


func test_nap_with_special_and_wake_with_action() -> void:
	await on_bench(80.0)
	check(prompt().contains("Nickerchen"), "prompt mentions the nap (got '%s')" % prompt())
	await press("special")
	check(game.player.is_napping(), "Spezial starts a nap")
	var before := player().needs.fatigue
	await wait(10.0)
	check(player().needs.fatigue < before - 20.0, "nap recovers fast (%.0f -> %.0f)" % [before, player().needs.fatigue])
	check(prompt() == "Aufwachen", "prompt says Aufwachen (got '%s')" % prompt())
	await press("interact")
	check(not game.player.is_napping(), "Aktion wakes up")
	check(player().seat != null, "still sitting after waking up")


func test_nap_ends_when_rested() -> void:
	await on_bench(20.0)
	await press("special")
	check(await wait_until(func() -> bool: return not game.player.is_napping(), 30.0), "wakes up by itself when rested")
	check(player().needs.fatigue <= 1.5, "fatigue is ~0 after the nap")


func test_walking_away_ends_nap() -> void:
	await on_bench(80.0)
	await press("special")
	check(game.player.is_napping(), "napping before walking")
	await move(Vector2(0, 1), 1.5)
	check(player().seat == null, "walking stands up")
	check(not game.player.is_napping(), "no longer napping")


## Phone: "Spezial" button on a bench must nap, not stand up (bug fixed in 4d5025a).
func test_nap_via_touch_button() -> void:
	Controls.set_touch_mode(true)
	await on_bench(80.0)
	check(await tap_button("Spezial"), "Spezial button visible")
	await wait(0.5)
	check(game.player.is_napping(), "touch Spezial naps")
	check(await tap_button("Aktion"), "Aktion button visible")
	await wait(0.3)
	check(not game.player.is_napping(), "touch Aktion wakes up")


func test_night_sleep_until_morning() -> void:
	await reset("jens", 23.0)
	await on_bench(70.0)
	var day := Clock.day
	await press("special")
	check(await wait_until(func() -> bool: return Clock.day == day + 1 and Clock.hour() >= 6.0 and Clock.hour() < 8.0, 20.0),
		"night skipped to the morning (now day %d %s)" % [Clock.day, Clock.time_string()])
	await wait(4.0)
	check(not game.player.is_napping(), "woke up in the morning")
	check(player().needs.fatigue < 5.0, "rested after the night")
	check(GameState.stat("nights_on_bench") == 1, "stat nights_on_bench")

extends Scenario
## The Möwenbucht's games (doc/moewenbucht.md, phase 3), played as a player sees them: the
## pedal boat race steered towards the light pillar, stone skipping thrown on the "JETZT!" cue
## (and too steep), the lighthouse, the coin telescope.


func _v(p: Vector2) -> Vector3:
	return Vector3(p.x, world.map.walk_height(p.x, p.y), p.y)


## Steers the player's boat towards p for a moment with real input (gas, left/right).
func _steer_to(p: Vector2, secs := 0.25) -> void:
	var b: Car = player().vehicle
	var f := b.forward2()
	var to := p - b.pos2()
	var alpha := atan2(f.x * to.y - f.y * to.x, f.dot(to))
	await drive(1.0 if absf(alpha) < 1.4 else 0.4, secs, clampf(alpha * 2.5, -1.0, 1.0))


## Ole's race: start at the boat rental, the countdown, then round the buoys 1, 2, 3 (the next
## one green with the light pillar) and back through the flags; a buoy out of turn counts nothing.
func test_boat_race() -> void:
	Clock.set_time(11.0)
	await coast()
	var m: CoastBoatRace = Gameplay.minigames["coast_race"]
	var ole := hold_npc("ole", (world.coast.posts["boat_rental"] as Array)[0])
	await put_player(minigame_spot("coast_race"), ole.global_position)
	await wait(0.3)
	check(prompt().begins_with("Tretbootrennen"), "prompt at the boat rental (%s)" % prompt())
	GameState.money = 1000
	await press("interact")
	check(m.active and player().vehicle != null and player().vehicle.kind == "pedalo", "in a pedal boat at the start")
	check(await wait_until(func() -> bool: return m.countdown > 0.0 and m._cue.text == "3", 2.0), "the countdown shows 3")
	check(await wait_until(func() -> bool: return m.countdown <= 0.0, 5.0), "and then goes")
	check((m.marks[0] as MeshInstance3D).material_override == m._green, "buoy 1 glows green")
	check(m.target == CoastBoatRace.BUOYS[0], "the light pillar stands on buoy 1")
	var others := [m.boats[1], m.boats[2]]
	var starts := others.map(func(o: Car) -> Vector2: return o.pos2())
	var seen := []
	var t := 0.0
	while m.active and t < 200.0:
		var n: int = m.next[m.boats[0]]
		if not seen.has(n):
			seen.append(n)
			if n < 3:
				check(m.target == CoastBoatRace.BUOYS[n], "the pillar moves to buoy %d" % (n + 1))
		await _steer_to(m.target)
		t += 0.25
	check(seen.size() == 4, "round all three buoys and into the finish (%s)" % str(seen))
	for i in 2:
		var o: Car = others[i]
		check(o.pos2().distance_to(starts[i]) > 30.0 or m.next.get(o, 0) > 0, "the other boat %d races too" % (i + 1))
	check(not m.active and dialog_text().contains("Platz"), "the result says the place (%s)" % dialog_text())
	check(GameState.stat("boat_races") >= 1, "counted")
	UI.close_dialog("")


## A buoy out of turn counts nothing: buoy 2 before buoy 1 leaves the player at buoy 1.
func test_boat_race_buoys_in_turn() -> void:
	Clock.set_time(11.0)
	await coast()
	var m: CoastBoatRace = Gameplay.minigames["coast_race"]
	hold_npc("ole", (world.coast.posts["boat_rental"] as Array)[0])
	m.try_start(player())
	await wait_until(func() -> bool: return m.countdown <= 0.0, 6.0)
	var me := m.boats[0]
	me.place(CoastBoatRace.BUOYS[1] + Vector2(3, 0), 0.0)
	await wait(0.5)
	check_eq(m.next[me], 0, "buoy 2 first: still on buoy 1")
	check(m.target == CoastBoatRace.BUOYS[0], "the pillar stays on buoy 1")
	check(m.pointer.text.begins_with("Boje 1") and absf(m.pointer.angle) > 1.5, "the arrow points back to buoy 1 (%s, %.1f)" % [m.pointer.text, m.pointer.angle])
	await shot("coast_race_buoys")
	m.quit()
	UI.close_dialog("")


## Stone skipping: thrown when "JETZT!" shows (the needle in the green) it skips five times or
## more, each hop counted big; thrown steep (the needle in the red) it plops in; the best counts.
func test_stone_skipping() -> void:
	await coast()
	var m: CoastSkipping = Gameplay.minigames["coast_skipping"]
	await put_player(minigame_spot("coast_skipping"))
	await wait(0.3)
	check(prompt() == "Steine flitschen", "prompt at the water's edge (%s)" % prompt())
	await press("interact")
	check(m.active and m.gauge != null, "the angle gauge is shown")
	# 1: on the cue.
	check(await wait_until(func() -> bool: return m._cue.text == "JETZT!", 5.0), "JETZT! when the needle comes into the green")
	m.set_process(false)
	await shot("coast_skipping_now")
	m.set_process(true)
	await press("interact")
	check(m.last >= 5, "on the cue: %d skips" % m.last)
	var hops := [0]
	check(await wait_until(func() -> bool:
		if m._cue.text.is_valid_int():
			hops[0] = maxi(hops[0], m._cue.text.to_int())
		return m.state == "landed", 8.0), "the stone lands")
	check(hops[0] >= 3, "each skip shown big (up to %d seen)" % hops[0])
	await shot("coast_skipping_hops")
	check(await wait_until(func() -> bool: return m.state == "aim", 4.0), "the next stone")
	# 2: steep (the needle in the red).
	check(await wait_until(func() -> bool: return m.gauge.angle > 30.0, 4.0), "the needle swings steep")
	await press("interact")
	check_eq(m.last, 0, "too steep: no skip")
	check(await wait_until(func() -> bool: return m._cue.text.begins_with("Plopp"), 3.0), "Plopp! Zu steil (%s)" % m._cue.text)
	check(await wait_until(func() -> bool: return m.state == "aim", 5.0), "the last stone")
	await wait_until(func() -> bool: return m._cue.text == "JETZT!", 5.0)
	await press("interact")
	check(await wait_until(func() -> bool: return not m.active, 12.0), "three throws, the end")
	check(dialog_text().contains("Sprünge"), "the result names the best throw (%s)" % dialog_text())
	check(GameState.stat("skips_best") >= 5, "the best throw counted (%d)" % GameState.stat("skips_best"))
	UI.close_dialog("")


## The lighthouse with Hinnerk: up to the gallery and once round, the view counted.
func test_lighthouse() -> void:
	Clock.set_time(11.0)
	await coast()
	var m: CoastLighthouse = Gameplay.minigames["coast_lighthouse"]
	hold_npc("hinnerk", (world.coast.posts["lighthouse"] as Array)[0])
	await put_player(minigame_spot("coast_lighthouse"))
	await wait(0.3)
	check(prompt().begins_with("Auf den Leuchtturm"), "prompt at the lighthouse (%s)" % prompt())
	GameState.money = 500
	await press("interact")
	check(m.active, "climbing")
	await wait(6.0)
	check(game.camera.global_position.y > CoastLayout.MOLE_Y + 15.0, "the view from the gallery (%.1f m)" % game.camera.global_position.y)
	await shot("coast_lighthouse_view")
	check(await wait_until(func() -> bool: return not m.active, 20.0), "down again")
	check(GameState.stat("lighthouse_view") == 1, "counted")
	UI.close_dialog("")


## The coin telescope on the pier head: a narrow round view towards the seals, "Rechts" turns it,
## "Fertig" ends it.
func test_telescope() -> void:
	await coast()
	var m: CoastTelescope = Gameplay.minigames["coast_telescope"]
	await put_player(minigame_spot("coast_telescope"))
	await wait(0.3)
	check(prompt().begins_with("Durchs Münzfernrohr"), "prompt at the telescope (%s)" % prompt())
	var fov := game.camera.fov
	await press("interact")
	check(m.active and game.camera.fov < 20.0, "a narrow view (%.0f°)" % game.camera.fov)
	await shot("coast_telescope")
	var yaw := m.yaw
	var to_bank := CoastLayout.SANDBANK - Vector2(m.eye.x, m.eye.z)
	check(Vector2(sin(m.yaw), cos(m.yaw)).dot(to_bank.normalized()) > 0.99, "it first looks at the sandbank with the seals")
	var b := find_button("Rechts")
	b.button_down.emit()
	await wait(1.0)
	b.button_up.emit()
	check(absf(angle_difference(m.yaw, yaw)) > 0.3, "„Rechts“ turns the telescope")
	check(await click_button("Fertig"), "Fertig")
	check(not m.active and absf(game.camera.fov - fov) < 0.1, "the view is back")
	UI.close_dialog("")

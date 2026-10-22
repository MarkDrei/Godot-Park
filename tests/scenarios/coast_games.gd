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


## Sandcastle with Opa Fietje: dropped on "JETZT!" (the ring green) a storey more; dropped beside
## the castle the top crumbles; far beside it nothing; the tide ends it and the storeys count.
func test_sandcastle() -> void:
	Clock.set_time(11.0)
	await coast()
	var m: CoastSandcastle = Gameplay.minigames["coast_sandcastle"]
	hold_npc("fietje", (world.coast.posts["sandcastles"] as Array)[0])
	await put_player(minigame_spot("coast_sandcastle"))
	await wait(0.3)
	check(prompt() == "Sandburg bauen", "prompt at the sandcastles (%s)" % prompt())
	await press("interact")
	check(m.active, "building")
	for i in 3:
		check(await wait_until(func() -> bool: return m._cue.text == "JETZT!", 6.0), "JETZT! with the bucket above the castle (%d)" % i)
		if i == 0:
			check(m.ring.material_override == m._green, "the ring glows green")
			m.set_process(false)
			await shot("coast_sandcastle_now")
			m.set_process(true)
		await press("interact")
		await wait_until(func() -> bool: return m.state == "swing", 2.0)
	check_eq(m.storeys, 3, "three storeys on the cue")
	# Beside the castle: the top crumbles.
	# Beside it and swinging outwards (so it is still beside it when the press arrives).
	check(await wait_until(func() -> bool: return absf(m.offset) > 0.5 and absf(m.offset) < 0.62 and signf(m.offset) == signf(cos(m.phase)), 6.0), "the bucket beside the castle")
	await press("interact")
	await wait_until(func() -> bool: return m.state == "swing", 2.0)
	check_eq(m.storeys, 2, "beside it: the top storey crumbles")
	# Far beside it: nothing.
	check(await wait_until(func() -> bool: return absf(m.offset) > 1.2, 6.0), "the bucket far beside the castle")
	await press("interact")
	await wait_until(func() -> bool: return m.state == "swing", 2.0)
	check_eq(m.storeys, 2, "far beside it: nothing happens")
	m.t = CoastSandcastle.DURATION - 0.1
	check(await wait_until(func() -> bool: return not m.active, 5.0), "the tide ends it")
	check(dialog_text().contains("2 Stockwerke"), "the result counts the storeys (%s)" % dialog_text())
	UI.close_dialog("")


## Beachvolleyball against Piet: "Baggern!" on "JETZT!" (the ball green) plays it back over the
## net; too early and not at all are points for Piet; first to five.
func test_volleyball() -> void:
	Clock.set_time(14.0)
	await coast()
	var m: CoastVolleyball = Gameplay.minigames["coast_volleyball"]
	hold_npc("piet")
	await put_player(minigame_spot("coast_volleyball"))
	await wait(0.3)
	check(prompt() == "Beachvolleyball spielen", "prompt at the court (%s)" % prompt())
	await press("interact")
	check(m.active, "playing")
	check(await wait_until(func() -> bool: return m.state == "in" and m.marker.visible, 4.0), "the ball comes, its ring shows where it lands")
	check(await wait_until(func() -> bool: return m._cue.text == "JETZT!", 4.0), "JETZT! when it is in reach")
	check(m.ball.material_override == m._green, "the ball glows green")
	m.set_process(false)
	await shot("coast_volleyball_now")
	m.set_process(true)
	await press("interact")
	check(m.state == "out", "bumped back over the net")
	# Too early: as soon as the ball is high on the player's side.
	check(await wait_until(func() -> bool: return m.state == "in" and m._t / m._dur > 0.4 and m._ball_height(m._t) > CoastVolleyball.REACH.y, 8.0), "the next ball high above")
	var piet := m.piet
	await press("interact")
	check(m.piet == piet + 1 and m._cue.text.begins_with("Zu früh"), "too early: a point for Piet (%s)" % m._cue.text)
	# Not at all.
	check(await wait_until(func() -> bool: return m.state == "in", 6.0), "the next ball")
	piet = m.piet
	check(await wait_until(func() -> bool: return m.piet == piet + 1, 6.0), "not played: a point for Piet")
	check(m._cue.text.begins_with("Verpasst"), "Verpasst! (%s)" % m._cue.text)
	await shot("coast_volleyball_point")
	# Play the rest on the cue.
	check(await wait_until(func() -> bool:
		if m.active and m._cue.text == "JETZT!":
			m.bump()
		return not m.active, 120.0), "played to the end")
	check(dialog_text().contains(":"), "the result shows the score (%s)" % dialog_text())
	UI.close_dialog("")


## Möwenalarm at Uwe's: a red ring with "!" over the roll a gull dives at; its button shoos the
## gull; a button where none comes costs nothing; a gull nobody shoos steals its roll.
func test_gull_alarm() -> void:
	Clock.set_time(14.0)
	await coast()
	var m: CoastGulls = Gameplay.minigames["coast_gulls"]
	hold_npc("uwe")
	await put_player(minigame_spot("coast_gulls"))
	await wait(0.3)
	check(prompt() == "Auf die Fischbrötchen aufpassen", "prompt at the fish stand (%s)" % prompt())
	await press("interact")
	check(m.active, "on guard")
	var warned := func() -> int:
		if not m.active:
			return -1
		for i in 3:
			if m.warnings[i].visible:
				return i
		return -1
	check(await wait_until(func() -> bool: return warned.call() >= 0, 4.0), "a red ring over a roll")
	var i: int = warned.call()
	m.set_process(false)
	await shot("coast_gulls_now")
	m.set_process(true)
	var free := (i + 1) % 3 if not m.warnings[(i + 1) % 3].visible else (i + 2) % 3
	check(await click_button(CoastGulls.SIDES[free]), "a button where no gull comes")
	check(m.alive.count(true) == 3 and m.shooed == 0, "costs nothing")
	check(await click_button(CoastGulls.SIDES[i]), "the button below the ring")
	check(m.shooed == 1 and m._cue.text == "Husch!", "the gull flies away (%s)" % m._cue.text)
	# One gull left alone steals its roll.
	check(await wait_until(func() -> bool: return warned.call() >= 0, 5.0), "the next gull")
	var j: int = warned.call()
	check(await wait_until(func() -> bool: return not m.alive[j], 5.0), "unguarded, it steals the roll")
	check(m._cue.text.begins_with("Geklaut"), "Geklaut! (%s)" % m._cue.text)
	# The rest guarded.
	check(await wait_until(func() -> bool:
		var k: int = warned.call()
		if k >= 0 and m.active:
			m.shoo(k)
		return not m.active, 60.0), "to the end")
	check(dialog_text().contains("2 von 3"), "two rolls saved (%s)" % dialog_text())
	UI.close_dialog("")


## Angelwettbewerb with Gesche: needs a rod; on the pier head 90 s (shortened here), the catches
## counted, Gesche's too; leaving the pier head ends it.
func test_fishing_contest() -> void:
	Clock.set_time(11.0)
	await coast()
	var m: CoastFishingContest = Gameplay.minigames["coast_contest"]
	hold_npc("gesche", (world.coast.posts["cutter"] as Array)[0])
	await put_player(minigame_spot("coast_contest"))
	await wait(0.3)
	check(prompt().contains("erst eine Angel"), "without a rod (%s)" % prompt())
	player().add_item("sea_rod")
	GameState.money = 500
	await wait(0.3)
	await press("interact")
	check(m.active and player().ground_pos().distance_to(CoastFishingContest.SPOT) < 1.0, "on the pier head at a fishing place")
	m.duration = 40.0
	for k in 2:
		await press("interact")
		if await wait_until(func() -> bool: return prompt().begins_with("Biss!"), 8.0):
			await press("interact")
		await wait(0.4)
	check(m.mine >= 2, "the catches counted (%d)" % m.mine)
	await shot("coast_contest")
	m._her_next = 0.0
	await wait(0.2)
	check(m.hers >= 1, "Gesche's catch counted")
	check(await wait_until(func() -> bool: return not m.active, 45.0), "the time runs out")
	check(dialog_text().contains("Fische gegen"), "the result (%s)" % dialog_text())
	UI.close_dialog("")

extends Scenario
## The booths of the Kirmes (doc/kirmes.md, phase 4): seven booth games played with real
## input, tickets as the second currency, Los-Lothar's lottery tickets, the prize counter.

const HOSTS := {"booth_cans": "cans", "booth_ducks": "ducks", "booth_rings": "rings", "booth_darts": "darts",
	"booth_moles": "moles", "booth_wheel": "wheel", "booth_striker": "striker"}


## The host at the post, the player at the booth; "Aktion" starts the game (and pays).
func _start(id: String) -> BoothGame:
	await fair()
	Clock.set_time(14.0)
	var m: BoothGame = Gameplay.minigames[id]
	var h := hold_npc(m.host_id)
	h.teleport(world.fair.posts[HOSTS[id]][0])
	GameState.money = 2000
	var spot := minigame_spot(id)
	await put_player(spot)
	await wait(0.3)
	check(prompt().contains(m.title), "%s prompt (%s)" % [id, prompt()])
	await press("interact")
	await frames(3)
	check(m.active, "%s runs" % id)
	check_eq(GameState.money, 2000 - m.cost, "%s costs %s" % [id, GameState.format_money(m.cost)])
	return m


func _done(m: BoothGame) -> void:
	check(await wait_until(func() -> bool: return not m.active, 20.0), "%s ends" % m.title)
	await wait(0.2)
	UI.close_dialog("")
	check(FairPass.has(m.booth), "%s stamped" % m.title)


func test_can_throw_king() -> void:
	var m := await _start("booth_cans") as CanThrow
	m.pace = 0.5       # a calm hand: the marker moves slowly
	var target := m.lp(m._can_xy(1).x, m._can_xy(1).y, -0.2)
	check(await wait_until(func() -> bool: return m._marker.global_position.distance_to(target) < 0.05, 90.0), "the marker passes the bottom middle can")
	await press("interact")
	await _done(m)
	check(GameState.is_unlocked("can_king"), "Dosenkönig")
	check(GameState.tickets >= 11, "six cans plus five extra (%d tickets)" % GameState.tickets)


func test_duck_fishing() -> void:
	var m := await _start("booth_ducks") as DuckFishing
	for i in DuckFishing.TRIES:
		await wait_until(func() -> bool: return m.duck_under_hook() >= 0 and m._lift < 0, 15.0)
		await press("interact")
		await wait(0.3)
	check(m.caught >= 3, "caught ducks (%d)" % m.caught)
	await _done(m)
	check(GameState.tickets >= m.caught, "tickets for the ducks (%d)" % GameState.tickets)


func test_ring_toss() -> void:
	var m := await _start("booth_rings") as RingToss
	m.pace = 0.3
	for r in RingToss.RINGS:
		var b: Vector3 = m.bottles[r]
		var rel := b - m.lp(0, 0, 0)
		var bx := rel.dot(m.right())
		var bz := rel.dot(m.fwd())
		await wait_until(func() -> bool: return absf(m._x - bx) < 0.03, 40.0)
		await press("interact")
		await frames(2)   # _z still holds the last ring's value until the marker moves on
		await wait_until(func() -> bool: return absf(m._z - bz) < 0.03, 40.0)
		await press("interact")
		await wait_until(func() -> bool: return m._stage == 0 or not m.active, 5.0)
	check(m.ringed >= 3, "rings on bottles (%d)" % m.ringed)
	await _done(m)
	check_eq(GameState.tickets, m.ringed * 3, "three tickets per ring")


## During a booth game the host steps out of the booth (in it they stood between the camera
## and the targets) and goes back to the counter afterwards.
func test_host_steps_aside() -> void:
	for id: String in ["booth_rings", "booth_moles", "booth_striker"]:
		var m := await _start(id)
		var h := m.host()
		var post: Vector3 = world.fair.posts[HOSTS[id]][0]
		var eye: Vector3 = game.camera.global_position
		var to_target: Vector3 = (m.lp(0, 1.2, -0.6) - eye).normalized()
		var to_host := (h.global_position + Vector3.UP - eye).normalized()
		check(h.global_position.distance_to(post) > 2.0, "%s: the host stepped aside" % id)
		check(to_host.angle_to(to_target) > deg_to_rad(30.0) or id == "booth_striker", "%s: not in the picture" % id)
		await shot("host_aside_" + id.substr(6))
		m.quit()
		await wait(0.2)
		UI.close_dialog("")
		check(h.global_position.distance_to(post) < 0.5, "%s: back at the counter" % id)


func test_balloon_darts() -> void:
	var m := await _start("booth_darts") as BalloonDarts
	m.pace = 0.2
	for d in BalloonDarts.DARTS:
		await wait_until(func() -> bool:
			for b in m.balloons:
				if b.visible and b.global_position.distance_to(m._cross.global_position) < 0.08:
					return true
			return false, 15.0)
		await press("interact")
		await wait(0.5)
	check(m.popped >= 3, "balloons popped (%d)" % m.popped)
	await _done(m)


func test_whack_a_mole() -> void:
	var m := await _start("booth_moles") as WhackAMole
	await wait_until(func() -> bool:
		if not m.active:
			return true   # the moles are gone with the game
		for i in WhackAMole.HOLES:
			if m._up[i] > 0.0 and m.moles[i].global_position.y > m.hole(i).y - 0.2:
				key(WhackAMole.KEYS[i])
		return not m.active, 40.0)
	await wait(0.2)
	UI.close_dialog("")
	check(GameState.stat("moles_best") >= 10, "moles whacked (%d)" % GameState.stat("moles_best"))
	check(GameState.stat("moles_hit") >= 10, "counted for Maulwurf-Jäger")
	check(FairPass.has("moles"), "stamped")


func test_wheel_of_fortune() -> void:
	var m := await _start("booth_wheel") as WheelOfFortune
	await key(KEY_1)
	check_eq(m.choice, "Rot", "set on red")
	await _done(m)
	var expect := 25 if m.result == "Gold" else (6 if m.result == "Rot" else 0)
	check_eq(GameState.tickets, expect, "the wheel stopped on %s" % m.result)


func test_high_striker() -> void:
	var m := await _start("booth_striker") as HighStriker
	m.pace = 0.3
	for s in 3:
		await wait_until(func() -> bool: return m._fly < 0.0 and Minigame.pingpong(m._bar_t, 1.0) > 0.975, 15.0)
		await press("interact")
		await wait(0.2)
	await _done(m)
	check(GameState.stat("bells_rung") >= 1, "the bell rang")
	check(GameState.tickets >= 12, "tickets (%d)" % GameState.tickets)


## Lottery tickets from Los-Lothar; tickets into the bag at the prize counter; the biggest prize.
func test_lots_and_prizes() -> void:
	var f := await fair()
	Clock.set_time(14.0)
	for id: String in ["lothar", "sascha"]:
		var h := hold_npc(id)
		h.teleport(f.posts["lots" if id == "lothar" else "prizes"][0])
	GameState.money = 1000
	await put_player(f.booths["lots"]["pos"])
	await wait(0.3)
	check(prompt().begins_with("Los kaufen"), "lottery prompt (%s)" % prompt())
	for i in 4:
		await press("interact")
		await wait(0.2)
	check_eq(GameState.money, 1000 - 4 * FairTrade.LOT_PRICE, "four lottery tickets")
	check(FairPass.has("lots"), "stamped")
	GameState.tickets = 0
	GameState.add_tickets(220)
	await put_player(f.booths["prizes"]["pos"])
	await wait(0.3)
	check(prompt().begins_with("Gewinnausgabe"), "prize counter prompt (%s)" % prompt())
	await press("interact")
	await wait(0.2)
	check(await choose("Edelstein – 60 Tickets"), "a gem")
	check(player().has_item("gem") and GameState.tickets == 160, "gem in the bag, 160 tickets left (%d)" % GameState.tickets)
	await press("interact")
	await wait(0.2)
	check(await choose("Bauchladen – 150 Tickets"), "the Bauchladen")
	check(GameState.is_unlocked("grand_prize"), "Hauptgewinn")
	check_eq(player().bag_slots(), Items.BAG_SLOTS + 6, "six more bag slots")
	await press("interact")
	await wait(0.2)
	check(await choose("Edelstein – 60 Tickets"), "another gem")
	check(toasted("Nicht genug Tickets"), "not enough tickets")
	UI.close_dialog("")


## Tickets show in the HUD and are saved.
func test_tickets_saved_and_shown() -> void:
	GameState.add_tickets(7, "Test")
	await frames(2)
	check(UI.hud.tickets_label.visible and UI.hud.tickets_label.text == "7 Tickets", "HUD (%s)" % UI.hud.tickets_label.text)
	GameState.save_game()
	GameState.tickets = 0
	GameState.load_game()
	check_eq(GameState.tickets, 7, "tickets saved")

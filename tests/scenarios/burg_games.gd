extends Scenario
## The Ritterburg's games (doc/burg.md, phase 3), played with real input: Tjost and Ringstechen
## on horseback, Bogenschießen, Tauziehen, the sword fight bet, the dice, the crystal ball and the
## lookout tower; their achievements.


## The host at the post, the player at the game's spot; "Aktion" starts the game (and pays).
func _start(id: String) -> Minigame:
	await burg()
	Clock.set_time(14.5)   # on the hour the knights' show would take the lists
	if world.burg.show_t >= 0.0:
		world.burg.end_show()   # it starts at 11:00, the tests' start time
	var m: Minigame = Gameplay.minigames[id]
	var h := hold_npc(m.host_id)
	var post := (h.brain as HumanBrain).work_pos()
	if post != Vector3.INF:
		h.teleport(post)
	GameState.money = 3000
	var spot := minigame_spot(id)
	check(spot != Vector3.INF, "%s has a start spot" % id)
	await put_player(spot)
	await wait(0.3)
	check(prompt().begins_with(m.title) or prompt().contains(m.title) or prompt() != "", "%s prompt (%s)" % [id, prompt()])
	await press("interact")
	await frames(3)
	check(m.active, "%s runs (prompt %s)" % [id, prompt()])
	check_eq(GameState.money, 3000 - m.cost, "%s costs %s" % [id, GameState.format_money(m.cost)])
	return m


func _done(m: Minigame, secs := 30.0) -> void:
	check(await wait_until(func() -> bool: return not m.active, secs), "%s ends" % m.title)
	await wait(0.2)
	UI.close_dialog("")


## Tjost: striking when the crosshair is on the shield's middle wins the runs' points.
func test_joust() -> void:
	var m := await _start("burg_joust") as BurgJoust
	check(m.horse != null and m.horse.global_position.distance_to(player().global_position) < 2.0, "the player sits on Blitz")
	check(player().item == "lance", "with a lance")
	await wait_until(func() -> bool: return m.t > 1.6, 5.0)
	await shot("burg_joust")
	for r in BurgJoust.RUNS:
		check(await wait_until(func() -> bool:
			return m.state == "run" and m.t < BurgJoust.RUN_TIME * BurgJoust.MEET - 0.1 and m.aim.length() < 0.12, 10.0), "run %d: the crosshair crosses the middle" % (r + 1))
		m.strike()   # the very frame (a key press takes frames, the crosshair moves on)
		check(await wait_until(func() -> bool: return m.last_points >= 0, 8.0), "run %d: the riders meet" % (r + 1))
		check(m.last_points >= 2, "run %d: the lance hits the shield (%d)" % [r + 1, m.last_points])
	var won := m.score > m.knight_score
	var before := GameState.stat("joust_wins")
	await _done(m)
	check(GameState.stat("joust_wins") == before + (1 if won else 0), "a win counts")
	check(not player().custom_motion and player().item == "", "off the horse, no lance")
	var blitz := world.find_actor("blitz")
	check((blitz.brain as AnimalBrain).state != "ridden" and not blitz.custom_motion, "Blitz is back in the paddock")


## Ringstechen: stabbing as the tip passes each ring takes all five.
func test_ring_tilting() -> void:
	var m := await _start("burg_rings") as BurgRings
	await wait(0.6)
	await shot("burg_rings")
	for i in BurgRings.POSTS:
		# A key press takes a few frames, the horse runs ~0.6 m meanwhile: press a little early.
		check(await wait_until(func() -> bool: return m.tip_x() > m.posts_x[i] - 0.7, 12.0), "ring %d comes" % (i + 1))
		await press("interact")
	check(m.taken == BurgRings.POSTS, "all five rings (%d)" % m.taken)
	await _done(m)
	check(GameState.is_unlocked("ring_master"), "Ringmeister")


## Bogenschießen: shooting when the crosshair is in the middle (no wind) scores bullseyes.
func test_archery() -> void:
	var m := await _start("burg_archery") as BurgArchery
	await shot("burg_archery")
	for i in BurgArchery.ARROWS:
		await wait_until(func() -> bool: return m.state == "aim", 5.0)
		m.wind = 0.0
		check(await wait_until(func() -> bool: return m.aim.length() < 0.07, 20.0), "arrow %d: the crosshair passes the middle" % (i + 1))
		m.shoot()   # the very frame
		await wait_until(func() -> bool: return m.state != "flying", 5.0)
	check(m.bullseyes >= 3, "bullseyes (%d)" % m.bullseyes)
	await _done(m)
	check(GameState.is_unlocked("bullseye"), "Ins Schwarze")


## Tauziehen: pulling on every beat pulls Kunibert over the line.
func test_tug_of_war() -> void:
	var m := await _start("burg_tug") as BurgTug
	await shot("burg_tug")
	var last := -1
	check(await wait_until(func() -> bool:
		if m.state != "pull":
			return true
		if m.last_beat != last and absf(m.beat_offset()) < 0.06:
			last = m.last_beat
			key(KEY_SPACE)
		return false, 45.0), "the game ends")
	await _done(m)
	check(GameState.stat("tug_wins") > 0, "won the tug of war")


## The bet: 2 € on Till; the payout is three times the stake if he wins.
func test_sword_fight_bet() -> void:
	var m := await _start("burg_bet") as BurgBet
	m.pace = 4.0
	check(await click_button("Till"), "bet on Till")
	var money := GameState.money
	check(await click_button("2,00 €"), "2 € stake")
	check(GameState.money == money - 200, "the stake is paid")
	# The last test's achievement (5 s) would lie over the fighters' speech.
	await wait_until(func() -> bool: return not is_instance_valid(UI._achievement), 8.0)
	await shot("burg_bet")
	check(await wait_until(func() -> bool: return m.state == "done", 20.0), "the fight ends")
	var won: bool = m.hits["till"] >= BurgBet.WINS
	money = GameState.money
	await _done(m)
	check(GameState.money - money == (600 if won else 0), "payout %d" % (GameState.money - money))


## Dice: keep the sixes, roll the rest; the sums decide.
func test_dice() -> void:
	var m := await _start("burg_dice") as BurgDice
	check(await click_button("Würfeln"), "roll")
	await shot("burg_dice")
	for i in 3:
		if m.dice[i] >= 5:
			check(await click_button("Würfel %d behalten" % (i + 1)), "keep die %d" % (i + 1))
	check(await click_button("Nachwürfeln"), "roll again")
	var mine: int = m.dice[0] + m.dice[1] + m.dice[2]
	var his: int = m.fritz[0] + m.fritz[1] + m.fritz[2]
	var money := GameState.money
	await _done(m)
	check(GameState.money - money == (200 if mine > his else (100 if mine == his else 0)), "pays by the sums %d : %d" % [mine, his])


## The crystal ball: repeating the shown colours makes the row grow; a wrong one ends it.
func test_crystal_ball() -> void:
	var m := await _start("burg_crystal") as BurgCrystal
	await wait_until(func() -> bool: return m.ball.visible, 5.0)
	await shot("burg_crystal")
	for round in 3:
		check(await wait_until(func() -> bool: return m.state == "input", 15.0), "round %d shown" % (round + 1))
		for c: String in m.row.duplicate():
			check(await click_button(c), "press %s" % c)
	check(m.best == BurgCrystal.START + 2, "three rows repeated (best %d)" % m.best)
	await wait_until(func() -> bool: return m.state == "input", 15.0)
	var wrong: String = "Rot" if m.row[0] != "Rot" else "Blau"
	await click_button(wrong)
	await _done(m)
	check(GameState.stat("crystal_best") >= 5, "best row saved")


## The lookout tower: up, once round, down; Turmblick.
func test_tower() -> void:
	var m := await _start("burg_tower") as BurgTower
	await wait(8.0)
	await shot("burg_tower")
	await _done(m, 30.0)
	check(GameState.is_unlocked("tower_view"), "Turmblick")
	check(player().visible, "the player is back")


## The joust show on the hour: Kunibert and Adelheid ride three runs on Donner and Wolke, then
## the horses go back to the paddock and the knights to their day.
func test_joust_show() -> void:
	await burg()
	Clock.set_time(11.0)
	for id: String in ["kunibert", "adelheid"]:
		present(id)
	check(await wait_until(func() -> bool: return world.burg.show_t >= 0.0, 5.0) or world.burg.start_show(), "the show starts on the hour")
	await wait(2.0)
	var k := world.find_actor("kunibert")
	var donner := world.find_actor("donner")
	check(k.global_position.distance_to(donner.global_position + Vector3(0, BurgHorseGame.SADDLE, 0)) < 0.3 and k.anim == "ride", "Kunibert rides Donner")
	check(not (Gameplay.minigames["burg_joust"] as Minigame).can_start(player()), "no Tjost for the player during the show")
	await shot("burg_joust_show")
	check(await wait_until(func() -> bool: return world.burg.show_t < 0.0, 20.0), "the show ends")
	check(not k.custom_motion and (donner.brain as AnimalBrain).state != "ridden", "Kunibert off the horse, Donner grazes again")

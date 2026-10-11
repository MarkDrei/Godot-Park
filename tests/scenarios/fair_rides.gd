extends Scenario
## The rides of the Kirmes (doc/kirmes.md, phase 3): started at their spot with "Aktion",
## the ride runs with the rider on it and the camera along, then joy, a stamp on the stamp card
## and back on the ground. Closed at night; bumper cars as a little game.

const RIDES := {"ride_ferris": "ferris_wheel", "ride_carousel": "carousel", "ride_chain": "chain_swing",
	"ride_swing": "swing_boat", "ride_ghost": "ghost_train", "ride_coaster": "coaster", "bumper": "bumper_cars"}


func _host_ready(m: Minigame) -> void:
	if m.host_id == "":
		return
	var h := present(m.host_id)
	h.brain.suspend()
	(h.brain as HumanBrain).think = 600.0
	h.teleport(world.fair.spots[_spot_of(m)] + Vector3(2.5, 0, 0.5))


func _spot_of(m: Minigame) -> String:
	for id: String in RIDES:
		if Gameplay.minigames[id] == m:
			return RIDES[id]
	return ""


## At the ride's spot, "Aktion" starts it (and pays).
func _start(id: String) -> Ride:
	await fair()
	Clock.set_time(14.0)
	var m: Ride = Gameplay.minigames[id]
	_host_ready(m)
	GameState.money = 2000
	await put_player(world.fair.spots[RIDES[id]])
	await wait(0.3)
	check(prompt().contains(m.title), "%s prompt (%s)" % [id, prompt()])
	await press("interact")
	await frames(3)
	check(m.active, "%s runs" % id)
	check_eq(GameState.money, 2000 - m.cost, "%s costs %s" % [id, GameState.format_money(m.cost)])
	return m


func _ride_through(m: Ride, timeout := 120.0) -> void:
	var start := m.exit_spot
	check(await wait_until(func() -> bool: return not m.active, timeout), "%s ends" % m.title)
	await wait(0.3)
	UI.close_dialog("")
	check(FairPass.has(m.ride_id), "%s stamped" % m.title)
	check(player().global_position.distance_to(start) < 1.0, "back where the ride started")
	check(not player().custom_motion, "walking again")


func test_ferris_wheel_view() -> void:
	var m := await _start("ride_ferris") as FerrisRide
	var joy := player().needs.joy
	check(await wait_until(func() -> bool: return m.at_top(), 30.0), "up at the top")
	check(player().global_position.y > 18.0, "the rider is high up (%.1f m)" % player().global_position.y)
	check(m.camera_pose()[1].x > -100.0, "the camera looks over the park")
	await shot("ferris_top")
	await _ride_through(m)
	check(player().needs.joy > joy, "joy up")


func test_carousel_and_chain_swing() -> void:
	for id: String in ["ride_carousel", "ride_chain"]:
		var m := await _start(id)
		var p0 := player().global_position
		await wait(4.0)
		check(player().global_position.distance_to(p0) > 2.0, "%s: the rider goes round" % id)
		if id == "ride_chain":
			await wait(8.0)
			check(world.fair.chain_speed > 1.0, "the chain swing spins (%.2f)" % world.fair.chain_speed)
			await shot("chain_swing")
		await _ride_through(m)


func test_swing_boat() -> void:
	var m := await _start("ride_swing")
	await wait(10.0)
	check(absf(world.fair.boats[0].rotation.x) > 0.2 or world.fair.ride_boat_amp > 0.8, "the boat swings high (%.2f)" % world.fair.ride_boat_amp)
	await _ride_through(m)
	check_eq(world.fair.ride_boat, -1, "the boat swings on its own again")


func test_ghost_train() -> void:
	var m := await _start("ride_ghost") as GhostRide
	check(m.get_node_or_null("GhostInside") != null, "the inside is built for the ride")
	await wait(m.duration * 0.55)
	var b := world.fair.ghost_base
	check(absf(player().global_position.z - b.z) < 7.0, "the car is inside the building")
	await shot("ghost_inside")
	await _ride_through(m)
	check(m.get_node_or_null("GhostInside") == null, "and freed again")


func test_roller_coaster() -> void:
	var m := await _start("ride_coaster")
	var top := [0.0]
	var travelled := [0.0]
	var last := [player().global_position]
	await wait_until(func() -> bool:
		top[0] = maxf(top[0], player().global_position.y)
		travelled[0] += player().global_position.distance_to(last[0])
		last[0] = player().global_position
		return not m.active, 120.0)
	check(top[0] > world.map.height_at(-344, -64) + 9.0, "up the lift hill (%.1f)" % top[0])
	check(travelled[0] > 80.0, "once round the track (%.0f m)" % travelled[0])
	await wait(0.3)
	UI.close_dialog("")
	check(FairPass.has("coaster"), "stamped")


func test_bumper_cars() -> void:
	var m := await _start("bumper") as BumperCars
	var f := world.fair
	# Another car right in front, side on: full throttle into it.
	var sc := f.scooters[0]
	var other := f.scooters[1]
	var dir := Vector3(sin(sc.rotation.y), 0, cos(sc.rotation.y))
	other.position = sc.position + dir * 5.0
	other.rotation.y = sc.rotation.y + PI / 2
	f._scooter_targets[1] = Vector2(other.position.x, other.position.z)
	Input.action_press("move_forward")
	await wait(2.0)
	_release_all()
	check(m.score >= 1, "a bump from the side counts (%d)" % m.score)
	await shot("bumper_cars")
	await _ride_through(m, 90.0)
	check(GameState.stat("bumper_best") >= 1, "best score kept")


## Closed before 10:00; the stamp card is in the notebook; three rides of each: Karussell-Profi.
func test_closed_card_and_profi() -> void:
	await fair()
	Clock.set_time(8.0)
	await put_player(world.fair.spots["coaster"])
	await wait(0.3)
	check(prompt().contains("geschlossen"), "closed in the morning (%s)" % prompt())
	FairPass.stamp("ferris")
	var entry: Array = TaskBoard.entries().filter(func(e: Dictionary) -> bool: return (e["title"] as String).begins_with("Kirmes: Stempelpass"))
	check(entry.size() == 1 and (entry[0]["desc"] as String).contains("Riesenrad"), "the stamp card is in the notebook")
	for r: String in FairPass.RIDES:
		for i in 3:
			FairPass.rode(r)
	check(GameState.is_unlocked("ride_pro"), "Karussell-Profi")

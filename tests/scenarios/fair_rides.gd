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
	var m := await _start("ride_coaster") as CoasterRide
	var f := world.fair
	var top := [0.0]
	var travelled := [0.0]
	var last := [player().global_position]
	var dir := [f.coaster_cars[0].global_transform.basis.z]
	var turn := [0.0]       # the sharpest turn of the front car (degrees per metre; a kink is huge)
	var at := [f.coaster_cars[0].global_position]
	var bar := [0.0, 0.0]   # the bar never goes back; its last value
	var back := [false]
	await wait_until(func() -> bool:
		top[0] = maxf(top[0], player().global_position.y)
		travelled[0] += player().global_position.distance_to(last[0])
		last[0] = player().global_position
		var d := f.coaster_cars[0].global_transform.basis.z
		var ds := f.coaster_cars[0].global_position.distance_to(at[0])
		if ds > 0.05 and ds < 3.0:
			turn[0] = maxf(turn[0], rad_to_deg(d.angle_to(dir[0])) / ds)
		dir[0] = d
		at[0] = f.coaster_cars[0].global_position
		if m.active:
			var p := m.progress()
			back[0] = back[0] or p < bar[0] - 0.01
			bar[0] = p
		return not m.active, 120.0)
	check(top[0] > world.map.height_at(-344, -64) + 9.0, "up the lift hill (%.1f)" % top[0])
	check(travelled[0] > 80.0, "once round the track (%.0f m)" % travelled[0])
	check(turn[0] < 20.0, "the cars turn smoothly (at most %.1f° a metre)" % turn[0])
	check(not back[0] and bar[0] > 0.9, "the bar follows the train round the track (last %.2f)" % bar[0])
	await wait(0.3)
	UI.close_dialog("")
	await frames(3)
	check(FairPass.has("coaster"), "stamped")
	# Off the ride where it started, upright, the camera follows again, and walking works.
	check(player().global_position.distance_to(m.exit_spot) < 1.0, "back at the station (%s)" % player().global_position)
	check(player().global_transform.basis.y.dot(Vector3.UP) > 0.99, "standing upright")
	check(not game.camera._override, "the camera follows the player again")
	var p0 := player().global_position
	await move(Vector2(0, 1), 1.0)
	check(player().global_position.distance_to(p0) > 1.5, "walks away from the coaster (%.1f m)" % player().global_position.distance_to(p0))


func test_bumper_cars() -> void:
	var m := await _start("bumper") as BumperCars
	var f := world.fair
	# A scooter is a car: the player drives it with the controls of the Oststadt.
	var car := player().vehicle
	check(car != null and car.kind == "scooter", "at the wheel of a scooter (%s)" % (car.kind if car else "none"))
	check(car != null and car.arena.has_area(), "in the rink")
	# The other scooters wait at the far end of the rink.
	var r := f.scooter_rect
	for i in range(1, f.scooters.size()):
		var q := Vector2(r.position.x + 2.0, r.position.y + 2.0 + i * 2.2)
		f.scooters[i].position = Vector3(q.x, f.scooters[i].position.y, q.y)
		f._scooter_targets[i] = q
	Input.action_press("move_forward")
	Input.action_press("move_right")
	var yaw0 := car.yaw
	await wait(0.8)
	_release_all()
	check(car.speed > 1.0, "gas: it drives (%.1f m/s)" % car.speed)
	check(car.yaw < yaw0 - 0.2, "steering right turns it right (yaw %.2f -> %.2f)" % [yaw0, car.yaw])
	await press("interact")
	await frames(2)
	check(player().vehicle == car, "no getting out in the middle of the round")
	# Another car right in front, side on: full throttle into it.
	await brake_to_stop()
	var ahead := Vector3(car.forward2().x, 0, car.forward2().y)
	var other := f.scooters[1]
	var spot := car.pos2() + car.forward2() * 4.0
	if not f.scooter_rect.grow(-2.0).has_point(spot):
		car.place(f.scooter_rect.get_center() + Vector2(4, 0), -PI / 2)
		ahead = Vector3(car.forward2().x, 0, car.forward2().y)
	other.position = car.global_position + ahead * 4.0
	other.position.y = f.scooters[0].position.y
	other.rotation.y = car.yaw + PI / 2
	f._scooter_targets[1] = Vector2(other.position.x, other.position.z)
	Input.action_press("move_forward")
	await wait(2.0)
	_release_all()
	check(m.score >= 1, "a bump from the side counts (%d)" % m.score)
	await shot("bumper_cars")
	await _ride_through(m, 90.0)
	check(player().vehicle == null and not is_instance_valid(car), "out of the scooter, it is gone")
	check(f.scooters[0].visible, "the rink's own scooter is back")
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

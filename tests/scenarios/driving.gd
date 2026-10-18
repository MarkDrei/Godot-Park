extends Scenario
## Driving in the Oststadt (doc/oststadt.md): getting into any standing car, gas, brake,
## steering, getting out, fatigue and rest, safety for pedestrians, soft bumps, touch pedals.


func _parked_car() -> Car:
	var c := await city()
	for car in c.cars:
		if car.job == "" and car.is_parked() and car.kind == "small" and car.pos2().x > 200.0:
			return car
	return null


## Walk up to a parked car, "Einsteigen", drive off, stop, "Aussteigen".
func test_get_into_a_parked_car() -> void:
	var car := await _parked_car()
	check(car != null, "a parked car in town")
	if car == null:
		return
	var side := Car.right_of(car.forward2()) * -(car.width() * 0.5 + 0.9)
	var spot := car.pos2() + side
	await put_player(Vector3(spot.x, 0, spot.y), car.global_position)
	await wait(0.4)
	check(prompt().begins_with("Einsteigen"), "prompt to get in (%s)" % prompt())
	await press("interact")
	check(player().vehicle == car, "sitting in the car")
	check(not player().rig.visible, "driver hidden in a closed car")
	await wait(0.4)
	check(UI.hud.doing_label.text.contains("km/h"), "speed in the HUD (%s)" % UI.hud.doing_label.text)
	await shot("in_car", {"car": car.global_position + Vector3(0, 1, 0)})
	check(prompt() == "Aussteigen", "prompt to get out while standing (%s)" % prompt())
	await press("interact")
	check(player().vehicle == null, "out again")
	check(car.contains(player().ground_pos(), 0.2) == false, "standing beside the car, not in it")
	check(not world.map.is_solid(player().ground_pos()), "on walkable ground")


func test_any_standing_car_but_not_a_moving_one() -> void:
	var car := await new_car("kombi", Vector2(208.25, -40.0), 0.0)
	check(car.can_enter(player()), "a standing car can be taken")
	car.speed = 5.0
	check(not car.can_enter(player()), "a moving car not")
	car.speed = 0.0
	car.locked = true
	check(not car.can_enter(player()), "a locked car not")


func test_drive_forward_and_stop() -> void:
	var car := await in_car()
	var start := car.pos2()
	await drive(1.0, 3.0)
	check(car.pos2().y - start.y > 10.0, "drove south (%.1f m)" % (car.pos2().y - start.y))
	check(car.speed > 5.0, "at speed (%.1f m/s)" % car.speed)
	check(await brake_to_stop(), "braked to a stop")
	await press("interact")
	check(player().vehicle == null, "got out")


func test_steering_right() -> void:
	var car := await in_car()
	await drive(1.0, 1.0)
	var x0 := car.pos2().x
	await drive(0.6, 1.5, 1.0)
	check(car.pos2().x < x0 - 1.0, "facing south, steering right turns to the west (%.1f → %.1f)" % [x0, car.pos2().x])
	await wait(0.15)
	check(absf(car.steer) < 0.05, "let go: the wheels are straight again at once (%.2f)" % car.steer)


## Driving tires like walking; held still for three seconds, the car is a seat: fatigue
## recovers, the HUD says "Pause" and the fatigue bar shows falling arrows. Gas ends it.
func test_driving_tires_and_a_stop_rests() -> void:
	var car := await in_car()
	var a := player()
	a.needs.fatigue = 40.0
	a.needs.hunger = 20.0
	await drive(0.4, 12.0)
	check(a.needs.fatigue > 40.2, "driving tires (%.2f)" % a.needs.fatigue)
	check(a.needs.hunger > 20.0, "hunger goes on (%.2f)" % a.needs.hunger)
	check(car.pos2().distance_to(Vector2(208.25, -40.0)) > 5.0, "drove meanwhile")
	check(await brake_to_stop(), "stopped")
	_release_all()
	await wait(1.5)
	check(not car.resting(), "a short stop is no rest yet")
	var f0 := a.needs.fatigue
	await wait(2.5)
	check(car.resting(), "held still for 3 s: resting")
	await wait(1.5)
	check(a.needs.fatigue < f0 - 0.5, "fatigue recovers as on a bench (%.2f → %.2f)" % [f0, a.needs.fatigue])
	check(UI.hud.doing_label.text.ends_with("Pause"), "the HUD says so (%s)" % UI.hud.doing_label.text)
	var bar: NeedBar = UI.hud.bars["fatigue"]
	check(bar.trending() and bar.rate < 0.0, "the fatigue bar shows it falling (%.2f/s)" % bar.rate)
	await shot("car_rest", {"car": car.global_position + Vector3(0, 1, 0)})
	await drive(0.6, 0.6)
	check(not car.resting(), "gas: the rest is over")


## Somebody who doesn't jump aside: the car stops in time on its own.
func test_brakes_for_a_pedestrian() -> void:
	var car := await in_car("small", Vector2(208.25, -60.0), 0.0)
	var npc := hold_npc("thorsten")
	npc.teleport(Vector3(208.25, 0, -20.0))
	npc._dodge_cooldown = 1e9   # stands still, like somebody who doesn't see the car
	var min_gap := [INF]
	Input.action_press("move_forward")
	await wait_until(func() -> bool:
		var d := car.pos2().distance_to(npc.ground_pos()) - car.length() * 0.5 - npc.radius
		min_gap[0] = minf(min_gap[0], d)
		return false, 8.0)
	_release_all()
	check(min_gap[0] > 0.2, "never touched the pedestrian (closest %.2f m)" % min_gap[0])
	check(absf(car.speed) < 0.5, "car stopped in front of him (%.1f m/s)" % car.speed)
	check(car.auto_braked or absf(car.speed) < 0.1, "the safety brake acted")
	npc._dodge_cooldown = 0.0
	(npc.brain as HumanBrain).think = 1.0


## People in front of a fast car jump aside; the car never touches them.
func test_pedestrians_jump_aside() -> void:
	var car := await in_car("small", Vector2(208.25, -70.0), 0.0)
	var npc := hold_npc("peggy")
	npc.teleport(Vector3(208.6, 0, -25.0))
	var touched := [false]
	Input.action_press("move_forward")
	await wait_until(func() -> bool:
		if car.contains(npc.ground_pos(), npc.radius * 0.5):
			touched[0] = true
		return car.pos2().y > -15.0, 12.0)
	_release_all()
	check(not touched[0], "never touched")
	check(absf(npc.ground_pos().x - 208.6) > 0.8 or car.pos2().y < -26.0, "she jumped aside (x %.1f) or the car waited" % npc.ground_pos().x)
	(npc.brain as HumanBrain).think = 1.0


## Curbs stop the car softly; it stays on the road.
## Parked cars and AI traffic out of a stretch of street (which bays are taken is random).
func _clear_street(a: Vector2, b: Vector2) -> void:
	await city()
	traffic_off((a + b) * 0.5, a.distance_to(b) * 0.5 + 10.0)
	var box := Rect2(a, Vector2.ZERO).expand(b).grow(4.0)
	for c: Car in world.city.cars.duplicate():
		if box.has_point(c.pos2()) and c.driver == null and c.ai == null and c.job == "" and not _cars.has(c):
			_parked.append([c, c.pos2(), c.yaw])   # teardown puts them back
			c.place(Vector2(395.0 + _parked.size() * 6.0, 130.0), 0.0)


func test_curb_stops_softly() -> void:
	await _clear_street(Vector2(206.0, -48.0), Vector2(216.0, -32.0))
	var car := await in_car("small", Vector2(214.0, -40.0), PI / 2)   # facing east towards the sidewalk
	await drive(1.0, 2.5)
	check(world.map.is_drivable(car.pos2()), "still on the road")
	check(car.pos2().x < 216.0 - 1.0, "stopped at the curb (x %.1f)" % car.pos2().x)
	await drive(-1.0, 1.5)
	check(car.pos2().x < 214.0, "backs off the curb again")


func test_cars_stay_out_of_the_park() -> void:
	var car := await in_car("small", Vector2(139.0, -12.0), -PI / 2)  # Parkstraße, facing the Osttor
	await drive(1.0, 3.0)
	check(car.pos2().x > ParkLayout.CITY_EDGE + 4.0, "the car stops at the curb, the park is car-free (x %.1f)" % car.pos2().x)


func test_bump_into_a_car_softly() -> void:
	var other := await new_car("van", Vector2(208.25, -20.0), 0.0)
	var car := await in_car("small", Vector2(208.25, -45.0), 0.0)
	var other_pos := other.pos2()
	await drive(1.0, 4.0)
	check(not Car.overlap(car.pos2(), car.yaw, car.size2(), other.pos2(), other.yaw, other.size2()), "cars never overlap")
	check(other.pos2().distance_to(other_pos) < 0.01, "the parked van stays where it is")
	check(car.pos2().y < other_pos.y - 3.0, "stopped behind it")


func test_walkers_cannot_walk_into_cars() -> void:
	var car := await new_car("van", Vector2(208.25, -40.0), 0.0)
	await put_player(Vector3(205.0, 0, -40.0), car.global_position)
	await move(Vector2(0, 1), 2.0)
	check(not car.contains(player().ground_pos(), 0.05), "the van blocks the way")


func test_get_out_only_when_standing() -> void:
	var car := await in_car()
	await drive(1.0, 2.0)
	Input.action_press("move_forward")
	await press("interact")
	_release_all()
	check(player().vehicle == car, "still driving")
	check(toasted("anhalten"), "told to stop first")


func test_horn() -> void:
	var car := await in_car()
	var npc := present("thorsten")
	npc.brain.suspend()
	npc.teleport(car.global_position + Vector3(4, 0, 2))
	await press("special")
	check(car.horn_time > 0.0, "honked")


## Switching characters from the car: out first, the car stays parked.
func test_switch_leaves_the_car() -> void:
	var car := await in_car()
	await press("switch")
	await frames(3)
	check(player().vehicle == null, "got out to switch")
	check(car.is_parked(), "car stays parked")
	UI.close_screens()
	UI.close_dialog("")


## Touch: hold "Gas" with one finger; the pedal counts while the finger stays.
func test_touch_pedals() -> void:
	Controls.set_touch_mode(true)
	var car := await in_car()
	await frames(3)
	var gas := find_button("Gas")
	check(gas != null, "Gas button")
	if gas == null:
		return
	var p := get_tree().root.get_final_transform() * gas.get_global_rect().get_center()
	var ev := InputEventScreenTouch.new()
	ev.index = 1
	ev.position = p
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait(2.0)
	check(car.speed > 4.0, "accelerating with the finger on Gas (%.1f)" % car.speed)
	await shot("drive_touch", {"car": car.global_position + Vector3(0, 1, 0)})
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await frames(2)
	check(not game.player.touch_gas, "released")
	var brake := find_button("Bremse")
	check(brake != null and find_button("Aussteigen") != null and find_button("Hupe") != null, "brake, get out and horn buttons")
	Controls.set_touch_mode(false)


## Arcade: at an acute angle into the curb the car slides along it and turns parallel,
## it does not stick.
func test_glancing_the_curb_slides_along() -> void:
	await _clear_street(Vector2(206.0, -82.0), Vector2(217.0, -30.0))
	var car := await in_car("small", Vector2(212.0, -80.0), 0.26)   # south, 15° towards the east curb
	await drive(1.0, 3.2)   # a street tree stands in the parking strip at z -52
	check(world.map.is_drivable(car.pos2()), "still on the road")
	check(car.pos2().y > -80.0 + 16.0, "slid along the curb (%.1f m)" % (car.pos2().y + 80.0))
	check(absf(wrapf(car.yaw, -PI, PI)) < 0.2, "turned along the curb (yaw %.2f)" % car.yaw)
	check(absf(car.speed) > 3.0, "kept going (%.1f m/s)" % car.speed)


## Nose against an obstacle (here a street tree in the parking strip, after sliding along the
## curb): steering away with gas pivots the car out, no reversing.
func test_free_from_the_curb_without_reversing() -> void:
	await city()
	for c in world.city.cars_near(Vector2(213.0, -60.0), 9.0):
		if c.driver == null and c.ai == null and c.job == "":
			c.place(Vector2(c.pos2().x, c.pos2().y + 40.0), c.yaw)   # parked cars out of the way
	var car := await in_car("small", Vector2(213.0, -60.0), 0.7)    # 40° towards the east curb
	check_eq(car.pose_blocked(car.pos2(), car.yaw), "", "free start pose")
	await drive(1.0, 1.2)
	var stuck := car.pos2()
	await drive(1.0, 0.9, 1.0)    # steer right, away from the curb (east is on the car's left)
	await drive(1.0, 0.6)         # and straight on (a full lock would only drive a tight circle)
	check(car.pos2().distance_to(stuck) > 5.0, "drove free (%.1f m)" % car.pos2().distance_to(stuck))


## Brushing past a parked car at a slight angle: the car goes on, the parked one stays.
func test_glancing_a_parked_car() -> void:
	var other := await new_car("van", Vector2(206.5, -40.0), 0.0)
	var car := await in_car("small", Vector2(209.0, -42.0), -0.15)  # beside it, drifting into its side
	var other_pos := other.pos2()
	await drive(1.0, 3.0)
	check(car.pos2().y > -40.0 + 8.0, "went past the van (z %.1f)" % car.pos2().y)
	check(other.pos2().distance_to(other_pos) < 0.01, "the van stays")
	check(not Car.overlap(car.pos2(), car.yaw, car.size2(), other.pos2(), other.yaw, other.size2()), "no overlap")

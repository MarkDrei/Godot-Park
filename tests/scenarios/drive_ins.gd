extends Scenario
## The two drive-ins of the Oststadt: the drive-in burger "Zum Durchfahrer" (order at the
## post, pick up at the window, family order as a memory game) and the drive-in cinema.


## Chooses the option whose text ends with `name` (the menu's "(Burger, Pommes, Cola)" contains
## other names too).
func _answer(name: String) -> bool:
	for b: Button in UI._dialog_buttons:
		if is_instance_valid(b) and b.text.ends_with(name):
			b.pressed.emit()
			await frames(2)
			return true
	return false


func _at_order_post() -> Car:
	var p: Vector2 = CityBuilder.drive_in_points()["order_car"]
	var car := await in_car("small", p, 0.0)
	await wait(0.4)
	return car


func _to_window(car: Car) -> void:
	car.place(CityBuilder.drive_in_points()["window_car"], 0.0)
	await wait(0.4)


func test_order_and_pick_up() -> void:
	var car := await _at_order_post()
	check(prompt() == "Bestellen", "prompt at the order post (%s)" % prompt())
	await shot("drive_in_order", {"car": car.global_position + Vector3(0, 1, 0)})
	await press("interact")
	check(await choose("Cheeseburger"), "menu with a cheeseburger (%s)" % str(dialog_options()))
	check(prompt().contains("Abholfenster"), "sent on to the window (%s)" % prompt())
	await _to_window(car)
	check(prompt() == "Bestellung abholen", "prompt at the window (%s)" % prompt())
	player().needs.hunger = 70.0
	var money := GameState.money
	await press("interact")
	check_eq(money - GameState.money, 390, "paid 3,90 €")
	check(player().needs.hunger < 30.0, "eaten in the car (hunger %.0f)" % player().needs.hunger)
	check_eq(GameState.stat("drive_in_orders"), 1, "order counted")


## The way there by driving: down the lane, brake at the post.
func test_reach_the_order_post_by_driving() -> void:
	var car := await in_car("small", Vector2(160.3, -80.0), 0.0)
	Input.action_press("move_forward")
	await wait_until(func() -> bool: return car.pos2().y > -71.5, 10.0)
	_release_all()
	check(await brake_to_stop(), "stopped")
	await wait(0.4)
	check(prompt() == "Bestellen", "stopped at the order post (z %.1f, prompt %s)" % [car.pos2().y, prompt()])


func test_family_order_memory_game() -> void:
	var car := await _at_order_post()
	await press("interact")
	check(await choose("Familienbestellung"), "family order offered")
	var text := dialog_text()
	var dw: DriveIn = world.city.drive_in
	check(dw.family.size() >= 3, "the family calls out at least three dishes")
	check(text.contains(dw.family[0][0]), "the dialog lists who wants what")
	var wanted: Array = dw.family.duplicate(true)
	await choose("gemerkt")
	await _to_window(car)
	var money := GameState.money
	await press("interact")
	for f: Array in wanted:
		check(dialog_text().contains(f[0]), "asks what %s wanted" % f[0])
		check(await _answer(Food.ITEMS[f[1]]["name"]), "answer %s" % Food.ITEMS[f[1]]["name"])
	check(GameState.money > money, "tip for the perfect order")
	check_eq(GameState.stat("family_orders_perfect"), 1, "perfect order counted")


func test_family_order_wrong_answer() -> void:
	var car := await _at_order_post()
	await press("interact")
	await choose("Familienbestellung")
	var dw: DriveIn = world.city.drive_in
	var right: String = dw.family[0][1]
	await choose("gemerkt")
	await _to_window(car)
	await press("interact")
	var wrong := ""
	for f: String in Food.DRIVE_IN:
		if f != right and dialog_options().any(func(o: String) -> bool: return o.ends_with(Food.ITEMS[f]["name"])):
			wrong = Food.ITEMS[f]["name"]
			break
	check(await _answer(wrong), "a wrong answer offered")
	check(dw.family.is_empty(), "the order is over after a wrong answer")
	check(toasted("Falsch"), "told what was wrong")
	check_eq(GameState.stat("family_orders_perfect"), 0, "not counted")


func test_no_order_on_foot() -> void:
	await city()
	var p: Vector2 = CityBuilder.drive_in_points()["order_car"]
	await put_player(Vector3(p.x, 0, p.y), Vector3(p.x + 3, 0, p.y))
	await wait(0.4)
	check(prompt().contains("nur im Auto"), "on foot: orders only from a car (%s)" % prompt())


func test_drive_in_closed_at_night() -> void:
	await _at_order_post()
	Clock.set_time(3.0)
	await wait(0.4)
	check(prompt().contains("geschlossen"), "closed at 3:00 (%s)" % prompt())


# --- Cinema ---------------------------------------------------------------------------

func _cinema_spot() -> Dictionary:
	return CityBuilder.cinema_spots()[3]


func test_film_in_the_evening() -> void:
	await city()
	Clock.set_time(20.0)
	var cin: Cinema = world.city.cinema
	var karla := present("karla")
	karla.brain.suspend()
	(karla.brain as HumanBrain).think = 600.0
	karla.teleport(Vector3(185.3, 0, -173.5))
	var car := await in_car("small", Vector2(179.5, -170.5), PI)
	await wait(0.4)
	check(prompt().begins_with("Ticket kaufen"), "ticket at the booth (%s)" % prompt())
	var money := GameState.money
	await press("interact")
	check_eq(money - GameState.money, Cinema.PRICE, "paid the ticket")
	check(cin.has_ticket(), "has a ticket")
	var s := _cinema_spot()
	car.place(s["pos"], s["yaw"])
	await wait(0.4)
	check(prompt() == "Film schauen", "parked facing the screen (%s)" % prompt())
	player().needs.joy = 40.0
	await press("interact")
	check(cin.active, "the film runs")
	await wait(2.0)
	await shot("cinema_film", {"screen": cin.screen.global_position})
	check(await wait_until(func() -> bool: return not cin.active, 60.0), "film over")
	UI.close_dialog("")
	check(player().needs.joy > 70.0, "joy rose (%.0f)" % player().needs.joy)
	check_eq(GameState.stat("films_watched"), 1, "film counted")
	check(player().vehicle == car, "still in the car")
	(karla.brain as HumanBrain).think = 1.0


func test_popcorn_during_the_film() -> void:
	await city()
	Clock.set_time(21.0)
	var cin: Cinema = world.city.cinema
	var s := _cinema_spot()
	var car := await in_car("small", s["pos"], s["yaw"])
	cin.ticket_day = Cinema.show_day()
	await wait(0.3)
	await press("interact")
	check(cin.active, "the film runs")
	player().needs.hunger = 50.0
	var money := GameState.money
	check(await click_button("Popcorn"), "popcorn button")
	check_eq(money - GameState.money, 200, "paid the popcorn")
	check(player().needs.hunger < 40.0, "popcorn eaten")
	cin.quit()
	UI.close_dialog("")
	check(car != null, "car")


func test_no_film_by_day() -> void:
	await city()
	Clock.set_time(14.0)
	await in_car("small", Vector2(179.5, -170.5), PI)
	await wait(0.4)
	check(prompt().contains("ab 19 Uhr"), "booth closed by day (%s)" % prompt())


func test_must_face_the_screen() -> void:
	await city()
	Clock.set_time(20.0)
	world.city.cinema.ticket_day = Cinema.show_day()
	var s := _cinema_spot()
	await in_car("small", s["pos"], 0.0)
	await wait(0.4)
	check(prompt().contains("Parkbucht"), "facing away: park properly first (%s)" % prompt())

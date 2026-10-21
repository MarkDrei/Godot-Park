extends Scenario
## Areas (AreaGates, World.enter_area): park with Nordwald and the Oststadt. With split areas
## ("Bereiche: Getrennt") the gates ask and only the player's area is awake; in every mode
## what belongs to an area stays there (dog walk, leashes, games, cars).

const OSTTOR := Vector3(130, 0, -12)


func _init() -> void:
	start_areas = "all"   # the gates' and areas' behaviour in both modes; split tests ask for it


func _split(on: bool) -> void:
	GameState.settings["areas"] = "split" if on else "all"
	await world.set_split(on)
	await frames(2)


func _in(id: String) -> bool:
	return world.player_area == id and not world.switching and not world.loading()


## The dog walk for Mia, started at her (the way there: quests.gd).
func _start_dog_walk() -> Actor:
	var mia := present("mia")
	mia.brain.suspend()
	for id: String in mia.def["dogs"]:
		var d := present(id)
		d.teleport(mia.global_position + Vector3(-1.5, 0, 0))
		mia.attach_leash(d)
	Gameplay.quests._start_walk(player(), mia)
	check(Gameplay.quests.walk_state == "to_meadow", "dog walk started")
	return Gameplay.quests.walk_dog


func test_split_gate_asks_then_swaps_the_areas() -> void:
	await _split(true)
	check(world.city == null, "the town is not built while the player is in the park")
	await put_player(OSTTOR + Vector3(-10, 0, 0))
	check(await walk_to(OSTTOR + Vector3(-1.4, 0, 0), 30.0, true, 1.0), "walked up to the Osttor")
	check(await wait_until(func() -> bool: return dialog_text().contains("Oststadt"), 3.0), "the gate asks (%s)" % dialog_text())
	check(world.city == null, "nothing is loaded before the answer")
	check(await choose("Nein, hierbleiben"), "say no")
	await wait(1.0)
	check(_in("park") and dialog_text() == "", "no: still in the park and not asked again on the spot")
	check(await walk_to(OSTTOR + Vector3(-9, 0, 0), 30.0), "step away from the gate")
	check(await walk_to(OSTTOR + Vector3(-1.4, 0, 0), 30.0, true, 1.0), "back to the gate")
	check(await wait_until(func() -> bool: return dialog_text().contains("Oststadt"), 3.0), "asks again after stepping away")
	check(await choose("Ja, in die Oststadt"), "say yes")
	check(await wait_until(func() -> bool: return _in("city"), 60.0), "the town is loaded")
	await wait(0.5)
	check(player().global_position.x > ParkLayout.CITY_EDGE + 1.0, "the player stands in town (x %.1f)" % player().global_position.x)
	check(not world.map.park_open and not world.park_root.visible, "the park sleeps (hidden)")
	check(world.west_backdrop != null and world.west_backdrop.visible, "from town a backdrop shows the park")
	check(world.map.is_solid(Vector2(125, -12)), "nobody walks into the sleeping park")
	var lena := world.find_actor("lena")
	check(lena.dormant and not lena.visible and lena.process_mode == Node.PROCESS_MODE_DISABLED, "park people sleep")
	check(world.actors.all(func(a: Actor) -> bool: return a.dormant or a.controlled or World.home_area(a) == "city"),
		"only town people are awake")
	var t0 := Actor.ticks
	var f0 := Engine.get_physics_frames()
	await frames(20)
	var awake := world.actors.filter(func(a: Actor) -> bool: return not a.dormant).size()
	check(float(Actor.ticks - t0) / maxi(1, Engine.get_physics_frames() - f0) <= awake, "sleeping people are not updated")
	# And back into the park.
	check(await walk_to(OSTTOR + Vector3(9, 0, 0), 30.0), "into the town a bit")
	check(await walk_to(OSTTOR + Vector3(1.4, 0, 0), 30.0, true, 1.0), "back to the Osttor")
	check(await wait_until(func() -> bool: return dialog_text().contains("zurück in den Park"), 3.0), "the gate asks (%s)" % dialog_text())
	check(await choose("Ja, in den Park"), "say yes")
	check(await wait_until(func() -> bool: return _in("park"), 30.0), "back in the park")
	await wait(0.5)
	check(player().global_position.x < ParkLayout.CITY_EDGE - 1.0, "the player stands in the park")
	check(world.map.park_open and world.park_root.visible and not world.west_backdrop.visible, "the park is awake")
	check(not world.map.city_open and not world.city.visible and world.city.process_mode == Node.PROCESS_MODE_DISABLED,
		"the town sleeps (hidden, traffic stopped)")
	check(world.static_root.get_node("EastBackdrop").visible, "the park's view of the east is back")
	check(world.map.is_solid(Vector2(140, -12)), "nobody walks into the sleeping town")
	var out := world.actors.filter(func(a: Actor) -> bool:
		return World.home_area(a) == "park" and a.is_human() and not a.inside and not a.dormant)
	check(out.size() >= 15, "%d park people are out again at 11:00" % out.size())
	check(world.actors.all(func(a: Actor) -> bool: return World.home_area(a) == "park" or a.dormant), "town people sleep")


## A woken area is a fresh start: people stand where the time of day puts them.
func test_woken_park_follows_the_clock() -> void:
	await _split(true)
	await put_player(Vector3(150, 0, -5))
	check(await wait_until(func() -> bool: return _in("city"), 60.0), "in town (put there: no question)")
	Clock.set_time(23.5)
	await put_player(place("great_meadow"))
	check(await wait_until(func() -> bool: return _in("park"), 30.0), "back in the park")
	var out := world.actors.filter(func(a: Actor) -> bool:
		return a.home_region == "park" and a.is_human() and not a.inside and not a.controlled)
	var night: Array = out.filter(func(a: Actor) -> bool: return not (a.brain as HumanBrain).in_hours())
	check(night.is_empty(), "nobody is out of their hours at 23:30 (%s)" % str(night.map(func(a: Actor) -> String: return a.actor_id)))


func test_split_gate_names_what_stays_behind() -> void:
	await _split(true)
	var dog := await _start_dog_walk()
	await put_player(OSTTOR + Vector3(-1.6, 0, 0))
	check(await wait_until(func() -> bool: return dialog_text().contains("Gassi-Auftrag endet"), 3.0),
		"the gate says the dog walk ends (%s)" % dialog_text())
	check(await choose("Ja, in die Oststadt"), "say yes")
	check(await wait_until(func() -> bool: return _in("city"), 60.0), "in town")
	check_eq(Gameplay.quests.walk_state, "", "dog walk ended")
	check(dog.dormant and dog.leash_owner == null, "the dog sleeps with the park, off the leash")


## Also with everything loaded: the dog stays in the park and the job ends.
func test_dog_walk_ends_at_the_border() -> void:
	await city()
	var dog := await _start_dog_walk()
	await put_player(OSTTOR + Vector3(-4, 0, 0))
	dog.teleport(OSTTOR + Vector3(-5, 0, 0))
	check(await walk_to(OSTTOR + Vector3(5, 0, 0), 30.0, true, 1.2), "walked through the Osttor")
	await wait(0.3)
	check_eq(Gameplay.quests.walk_state, "", "dog walk ended")
	check(dog.leash_owner != player() and World.area_of(dog.global_position) == "park", "the dog stayed in the park")
	check(toasted("bleibt im Park"), "told why (%s)" % str(toasts))


func test_own_dogs_stay_in_the_park() -> void:
	await city()
	await reset("mia")
	var mia := player()
	for id: String in mia.def["dogs"]:
		var d := present(id)
		d.teleport(mia.global_position + Vector3(-1.5, 0, 0))
		mia.attach_leash(d)
	await put_player(OSTTOR + Vector3(5, 0, 0))
	await wait(0.3)
	check(mia.leash_dogs.is_empty(), "Mia's dogs stay behind")
	check(toasted("bleibt im Park"), "told (%s)" % str(toasts))


func test_park_game_ends_in_town() -> void:
	await city()
	var m := await in_minigame("bottles")
	check(m.active, "Pfandjagd runs")
	await put_player(Vector3(150, 0, -5))
	await wait(0.3)
	check(not m.active, "it ends in town")
	check(toasted("Pfandjagd endet"), "told (%s)" % str(toasts))


func test_cars_stay_in_town() -> void:
	var c := await in_car("small", Vector2(160.0, -10.25), -PI / 2)
	await drive(0.7, 5.0)
	await brake_to_stop()
	check(c.pos2().x > ParkLayout.CITY_EDGE + 1.0, "the car stops before the fence (x %.1f)" % c.pos2().x)
	check(toasted("Autos bleiben in der Stadt"), "told at the gate (%s)" % str(toasts))


## Someone the player leaves in the other area goes home.
func test_character_left_in_town_goes_home() -> void:
	await city()
	await put_player(Vector3(150, 0, -5))
	await wait(0.3)
	var jens := player()
	var resident: Actor = null
	for a in world.actors:
		if a.home_region == "city" and a.is_human() and not a.inside:
			resident = a
	check(resident != null, "a town resident is out")
	resident.teleport(Vector3(152, 0, -5))
	game.player.control(resident)
	await wait(0.3)
	check(jens.inside or World.area_of(jens.global_position) == "park", "Jens went home to the park")


func test_setting_bereiche() -> void:
	await city()
	await press("pause")
	check(await click_button("Einstellungen"), "Einstellungen")
	check(await tap_button("Getrennt"), "button Getrennt")
	check(await wait_until(func() -> bool: return not world.switching, 10.0), "swapped")
	check(world.split_areas and not world.map.city_open and world.map.park_open, "Getrennt: the town sleeps while the player is in the park")
	check(UI.blocks_game_input(), "the settings stay open")
	check(UI.root.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.begins_with("Getrennt: nur der Bereich")),
		"a line explains the choice")
	for screen in screens():
		await set_screen(screen)
		check_layout("settings areas " + screen)
	await set_screen("desktop")
	check(await tap_button("Alles"), "button Alles")
	check(await wait_until(func() -> bool: return not world.switching, 10.0), "swapped")
	check(not world.split_areas and world.map.city_open and world.map.park_open, "Alles: both areas awake")
	GameState.settings["areas"] = "auto"
	await click_button("Zurück")
	await click_button("Weiterspielen")


## The whole map ("Gesamtkarte") and the maps of sleeping areas: drawn from the baked image, so
## they are there before the Oststadt and the Westpark are loaded or while they sleep.
func test_whole_map_and_sleeping_areas() -> void:
	await put_player(place("food_court"))
	await _split(true)
	check(_in("park") and not (world.area("city").is_built() and world.map.city_open), "the town sleeps or is not built")
	await press("map")
	await frames(3)
	var ms: MapScreen = UI.map_screen
	check(ms.view == MapImage.PARK_VIEW, "map opens on the city park")
	for n: String in ["Ritterburg", "Westpark", "Oststadt Nord", "Oststadt Süd", "Gesamtkarte"]:
		check(ms.view_buttons[n].visible, "button %s while the area sleeps" % n)
	check(await click_button("Gesamtkarte"), "button Gesamtkarte")
	check(ms.view == MapImage.WORLD_VIEW and ms.title.text == "Gesamtkarte", "whole map shown (%s)" % ms.title.text)
	check(not ms.view_buttons["Gesamtkarte"].visible and ms.view_buttons["Stadtpark"].visible, "buttons for the other maps")
	await shot("map_whole")
	var at := func(p: Vector2) -> Vector2:
		return ms.tex_rect.get_global_transform_with_canvas() * ms.world_to_map(Vector3(p.x, 0, p.y))
	await click_at(at.call(Vector2(390, -150)))
	check(ms.view == MapImage.CITY_NORTH_VIEW, "a tap on the town opens its north half")
	check(UI._modal == "map", "map stays open")
	await click_at(at.call(Vector2(CityLayout.ALLEE_X, -200)))
	check(toasted("Unterwegs zum Waldweg Ost"), "a tap into the sleeping town walks to its nearest gate")
	check(UI._modal == "" and player().is_moving(), "map closed, walking")
	check(player().path.size() > 0 and Vector2(player().path[-1].x, player().path[-1].z).distance_to(ParkLayout.place("gate_forest_e")) < 2.0,
		"the way ends at the gate")
	await press("map")
	await frames(2)
	check(await click_button("Gesamtkarte"), "back to the whole map")
	await click_at(at.call(Vector2(-260, 0)))
	check(ms.view == MapImage.FAIR_VIEW, "a tap on the Westpark opens its map")
	UI.close_screens()


## The baked map image (scripts/bake_map.sh) shows the Oststadt and the Westpark as they are drawn
## once loaded.
func test_baked_map_is_up_to_date() -> void:
	await city()
	await fair()
	await burg()
	var stale := MapImage.stale_parts()
	check(stale.is_empty(), "baked map up to date, run scripts/bake_map.sh (differs: %s)" % ", ".join(stale))

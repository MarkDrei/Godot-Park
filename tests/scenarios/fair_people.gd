extends Scenario
## The Westpark's people and food (doc/kirmes.md, phase 2): showmen at their posts, visitors
## and children who stay in the Westpark, the four food stands, oases that rest faster, joy
## that rises at the Kirmes, the organ music near the rides.

const SHOWMEN := ["doris", "erna", "rita", "dieter", "moritz", "gisela", "lothar", "max", "karl", "aylin", "geistgustav", "sascha"]


func _open_menu(id: String) -> Shop:
	var shop := await open_shop(id)
	check(shop != null, "%s opens (vendor at work)" % id)
	await at_shop(id)
	check(prompt().begins_with("Einkaufen"), "%s prompt (got '%s')" % [id, prompt()])
	await press("interact")
	await wait(0.2)
	check(UI.is_dialog_open(), "%s menu dialog opens" % id)
	return shop


func _buy(id: String, food: String) -> int:
	await _open_menu(id)
	var money := GameState.money
	check(await choose(Food.ITEMS[food]["name"] + " –"), "%s sells %s (options %s)" % [id, food, str(dialog_options())])
	var spent := money - GameState.money
	await wait(5.0)
	return spent


## In the afternoon the showmen stand at their booths and rides.
func test_showmen_at_their_posts() -> void:
	var f := await fair()
	Clock.set_time(15.0)
	var away := []
	await wait_until(func() -> bool:
		away = SHOWMEN.filter(func(id: String) -> bool:
			var a := world.find_actor(id)
			var post: Array = f.posts[(a.def["work"]["spot"] as String).substr(5)]
			return a.inside or a.distance_to(post[0]) > 1.0)
		return away.is_empty(), 400.0)
	check(away.is_empty(), "every showman at the post (away: %s)" % str(away))
	var zambini := world.find_actor("zambini")
	await wait_until(func() -> bool: return zambini.distance_to(f.posts["stage"][0]) < 1.0, 200.0)
	check(zambini.global_position.y > world.map.height_at(zambini.global_position.x, zambini.global_position.z) + 0.6,
		"the magician stands on the stage")
	await put_player(Vector3(-210, 0, 3), Vector3(-210, 0, -6))
	await shot("fair_people", {"booths": Vector3(-210, 1.5, -4)})


## Every food stand sells its menu; the three sweets give "Zuckerschock 2.0".
func test_food_stands() -> void:
	await fair()
	Clock.set_time(14.0)
	for id: String in ["fair_candy", "fair_almonds", "fair_sausage", "fair_crepes"]:
		var shop: Shop = world.shops[id]
		for food: String in shop.menu:
			GameState.money = 2000
			var spent := await _buy(id, food)
			check_eq(spent, int(Food.ITEMS[food]["price"]), "%s: %s price" % [id, food])
			UI.close_dialog("")
	check(GameState.is_unlocked("sugar_rush_2"), "Zuckerschock 2.0 (sweets %s)" % str(GameState.sets.get("fair_sweets", {}).keys()))


## Sitting at an oasis rests twice as fast as on a normal bench; all five give an achievement.
func test_oases_rest_faster() -> void:
	var f := await fair()
	var a := player()
	var rates := {}
	for which: String in ["park", "oasis"]:
		var seat: Seat = null
		for s in world.seats:
			if s.kind == "bench" and s.is_free_for(a) and ((which == "oasis") == (s.oasis != "")) \
					and (which == "oasis" or World.area_of(s.position) == "park"):
				seat = s
				break
		check(seat != null, "a free %s bench" % which)
		a.teleport(seat.approach_point())
		a.sit_on(seat)
		a.needs.fatigue = 90.0
		await wait(6.0)
		rates[which] = 90.0 - a.needs.fatigue
		a.stand_up()
	check(rates["oasis"] > rates["park"] * 1.7, "an oasis rests faster (%.1f vs %.1f)" % [rates["oasis"], rates["park"]])
	for id: String in FairLayout.oases():
		for s in world.seats:
			if s.oasis == id and s.is_free_for(a):
				a.teleport(s.approach_point())
				a.sit_on(s)
				await frames(2)
				a.stand_up()
				break
	check(GameState.is_unlocked("oasis_explorer"), "Oasen-Entdecker (%s)" % str(GameState.sets.get("oases", {}).keys()))
	check(f.oasis_at(f.oases["oasis_lights"]) == "oasis_lights", "oasis lookup")


## At the Kirmes joy rises by itself; in the park it fades.
func test_joy_rises_at_the_fair() -> void:
	await fair()
	var a := player()
	a.needs.joy = 50.0
	await wait(20.0)
	var park := a.needs.joy
	await put_player(Vector3(-170, 0, 18))
	a.needs.joy = 50.0
	await wait(20.0)
	check(park < 50.0, "joy fades in the park (%.1f)" % park)
	check(a.needs.joy > 50.0, "joy rises at the Kirmes (%.1f)" % a.needs.joy)


## Visitors and children of the Kirmes stay in the Westpark; park people stay out.
func test_fair_people_stay_in_the_westpark() -> void:
	await fair()
	Clock.set_time(16.0)
	var v := world.find_actor("fairgoer_0")
	check(v != null and v.home_region == "fair", "a Kirmes visitor")
	for i in 30:
		var q := world.random_path_point(v)
		if q.x >= ParkLayout.FAIR_EDGE:
			check(false, "strolling stays in the Westpark (%s)" % str(q))
			break
	check(not World.allowed(v, Vector3(0, 0, 0)), "a Kirmes visitor may not go to the city park")
	check(not World.allowed(world.find_actor("peggy"), Vector3(-200, 0, 5)), "Peggy may not go to the Kirmes")
	await wait(30.0)
	var out := world.actors.filter(func(a: Actor) -> bool:
		return a.home_region == "fair" and not a.inside and a.is_human())
	check(out.size() >= 20, "%d people at the Kirmes in the afternoon" % out.size())
	var wrong := out.filter(func(a: Actor) -> bool: return a.global_position.x > ParkLayout.FAIR_EDGE + 1.0)
	check(wrong.is_empty(), "none of them in the park (%s)" % str(wrong.map(func(a: Actor) -> String: return a.actor_id)))


## A hungry visitor of the Kirmes eats at a Kirmes stand.
func test_visitors_eat_at_the_stands() -> void:
	await fair()
	Clock.set_time(14.0)
	for id: String in ["fair_candy", "fair_almonds", "fair_sausage", "fair_crepes"]:
		await open_shop(id)
	var v := present("fairgoer_1")
	v.teleport(Vector3(-200, 0, 3))
	v.needs.hunger = 95.0
	v.brain.suspend()
	(v.brain as HumanBrain).think = 0.1
	var shop_id := [""]
	check(await wait_until(func() -> bool:
		var b := v.brain as HumanBrain
		if b.current is Activities.Eat and (b.current as Activities.Eat).shop:
			shop_id[0] = (b.current as Activities.Eat).shop.shop_id
		return shop_id[0] != "", 20.0), "goes to eat")
	check((shop_id[0] as String).begins_with("fair_"), "at a Kirmes stand (%s)" % shop_id[0])


## The organ waltz plays near the rides, softly at the oases, not in the park.
func test_music_near_the_rides() -> void:
	var f := await fair()
	await put_player(Vector3(-240, 0, 3))
	await _camera_there()
	check(Sound.fair_music_level() > 0.8, "loud at the booth street (%.2f)" % Sound.fair_music_level())
	await put_player(f.oases["oasis_lights"] + Vector3(0, 0, 6))
	await _camera_there()
	check(Sound.fair_music_level() < 0.4, "soft at the light garden (%.2f)" % Sound.fair_music_level())
	await put_player(place("great_meadow"))
	await _camera_there()
	check_eq(Sound.fair_music_level(), 0.0, "silent in the city park")


func _camera_there() -> void:
	game.camera.follow(player(), false)
	await wait_until(func() -> bool: return world.focus.distance_to(player().global_position) < 3.0, 5.0)

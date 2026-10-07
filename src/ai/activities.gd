class_name Activities
extends RefCounted
## Human NPC activities. Each inner class is one behaviour the HumanBrain can pick.


## Stroll to a path point or landmark and look around.
class Wander extends Activity:
	var target: Vector3
	var linger := 0.0

	func start() -> void:
		kind = "wander"
		label = "schlendert herum"
		if world.rng.randf() < 0.35 and not world.landmarks.is_empty():
			var l: Dictionary = world.landmarks[world.rng.randi() % world.landmarks.size()]
			var p: Vector3 = l["pos"]
			target = p + Vector3(world.rng.randf_range(-6, 6), 0, world.rng.randf_range(-6, 6))
			label = "bummelt zum Ort „%s“" % l["name"]
		else:
			target = world.random_path_point()
		linger = world.rng.randf_range(3.0, 9.0)
		walk_to(target, false)

	func update(delta: float) -> void:
		if walked():
			linger -= delta
			actor.anim = "idle"
			if linger <= 0.0:
				done = true


## Sit on a free seat for a while (optionally reading, sleeping, phoning...).
class Sit extends Activity:
	var seat: Seat
	var kinds: Array = ["bench"]
	var duration := 60.0
	var sit_anim := "idle"
	var near := Vector3.INF
	var max_dist := 70.0
	var seated := false

	func _init(seat_kinds: Array = ["bench"], secs := 60.0, anim_name := "idle", near_pos := Vector3.INF) -> void:
		kinds = seat_kinds
		duration = secs
		sit_anim = anim_name
		near = near_pos

	func start() -> void:
		kind = "sit"
		label = {"sleep": "macht ein Nickerchen", "read": "liest Zeitung", "phone": "telefoniert im Sitzen",
			"eat": "isst etwas", "chess": "spielt Schach", "feed": "füttert die Tauben"}.get(sit_anim, "ruht sich auf einer Bank aus")
		var origin := near if near != Vector3.INF else actor.global_position
		seat = world.find_free_seat(origin, actor, max_dist, kinds)
		if seat == null:
			seat = world.random_seat(actor, kinds)
		if seat == null:
			failed = true
			return
		seat.reserved_by = actor
		walk_to(seat.approach_point())
		timeout = duration + 240.0

	func update(delta: float) -> void:
		if not seated:
			if not walked():
				return
			if not seat.is_free_for(actor) or actor.distance_to(seat.approach_point()) > 2.5:
				failed = true
				return
			actor.sit_on(seat)
			actor.anim = sit_anim
			seated = true
			if sit_anim == "read":
				actor.set_item("newspaper")
			return
		duration -= delta
		actor.anim = sit_anim
		if sit_anim == "idle" and world.rng.randf() < delta * 0.02:
			actor.play_anim("talk" if world.rng.randf() < 0.3 else "idle", 2.0)
		if duration <= 0.0 or actor.seat == null:
			done = true

	func end() -> void:
		if seat and seat.reserved_by == actor:
			seat.reserved_by = null
		if actor.seat:
			actor.stand_up()
		if actor.item == "newspaper":
			actor.set_item("")
		actor.anim = "idle"


## Buy food at an open stand and eat it sitting down.
class Eat extends Activity:
	var shop: Shop
	var step := 0
	var wait := 0.0
	var food := ""
	var sit: Sit

	func start() -> void:
		kind = "eat"
		label = "holt sich etwas zu essen"
		var options: Array[Shop] = []
		for s: Shop in world.shops.values():
			if s.is_open() and s.food_entries().size() > 0:
				options.append(s)
		if options.is_empty():
			failed = true
			return
		options.sort_custom(func(a: Shop, b: Shop) -> bool: return a.distance_to(actor) < b.distance_to(actor))
		shop = options[0] if world.rng.randf() < 0.7 else options[world.rng.randi() % options.size()]
		walk_to(shop.customer_spot())
		timeout = 400.0

	func update(delta: float) -> void:
		match step:
			0:
				if walked():
					if not shop.is_open():
						failed = true
						return
					actor.face(shop.vendor_pos())
					step = 1
					wait = 2.5
			1:
				wait -= delta
				if wait <= 0.0:
					food = shop.serve_npc(actor)
					if food == "":
						failed = true
						return
					actor.set_item(Food.item_for(food))
					sit = Sit.new(["table", "bench"], world.rng.randf_range(25.0, 45.0), "eat", actor.global_position)
					sit.max_dist = 30.0
					sit.begin(actor)
					label = "isst gemütlich"
					step = 2
			2:
				sit.tick(delta)
				if sit.failed:
					# Eat standing.
					actor.anim = "eat"
					wait += delta
					if wait > 20.0:
						_finish()
				elif sit.done:
					_finish()

	func _finish() -> void:
		Food.apply(actor, food)
		done = true
		if world.rng.randf() < 0.35 and food in ["water", "lemonade"]:
			world.spawn_bottle(actor.global_position + actor.forward() * 0.6)

	func end() -> void:
		if sit:
			sit.end()
		actor.set_item("")
		actor.anim = "idle"


## Jogging laps on the ring path.
class Jog extends Activity:
	var laps := 1
	var points: PackedVector2Array
	var idx := 0
	var stretch := 0.0
	var dir := 1

	func start() -> void:
		kind = "jog"
		label = "dreht eine Joggingrunde"
		for p: Dictionary in world.map.paths:
			if p["id"] == "ring":
				points = p["points"]
		var best := 0
		var best_d := INF
		for i in points.size():
			var d := points[i].distance_to(actor.ground_pos())
			if d < best_d:
				best_d = d
				best = i
		idx = best
		dir = 1 if world.rng.randf() < 0.5 else -1
		laps = world.rng.randi_range(1, 2)
		timeout = 900.0
		walk_to(_pt(idx), true)

	func _pt(i: int) -> Vector3:
		var p := points[posmod(i, points.size())]
		return Vector3(p.x, world.map.walk_height(p.x, p.y), p.y)

	func update(delta: float) -> void:
		if stretch > 0.0:
			stretch -= delta
			actor.anim = "stretch"
			if stretch <= 0.0:
				done = true
			return
		if not walked():
			return
		if actor.needs.fatigue > 85.0:
			stretch = 8.0
			return
		# Follow the ring a few points at a time (no pathfinding needed).
		var path := PackedVector3Array()
		for k in 6:
			idx += dir
			path.append(_pt(idx))
		if absi(idx) > points.size() * laps + 6:
			stretch = 8.0
			return
		actor.path = path
		actor.path_i = 0
		actor.running = true
		_walking = true

	func end() -> void:
		actor.running = false
		actor.anim = "idle"


## Feed ducks at the pond or pigeons from a bench.
class Feed extends Activity:
	var target := "ducks"
	var step := 0
	var wait := 0.0
	var spot: Vector3
	var sit: Sit
	var feed_time := 0.0

	func _init(what := "ducks") -> void:
		target = what

	func start() -> void:
		kind = "feed"
		label = "füttert die Enten" if target == "ducks" else "füttert die Tauben"
		timeout = 420.0
		if not actor.has_item("bread"):
			var kiosk: Shop = world.shops.get("kiosk")
			if kiosk == null or not kiosk.is_open():
				# Bring your own bread from home.
				actor.add_item("bread", 6)
				step = 2
			else:
				walk_to(kiosk.customer_spot())
				step = 0
				return
		else:
			step = 2
		_go_feed()

	func _go_feed() -> void:
		if target == "ducks":
			var pier := ParkLayout.PIER
			var ends: Array[Vector3] = []
			var to: Vector2 = pier["to"]
			ends.append(Vector3(to.x, 0, to.y + 0.6))
			for a: float in [3.6, 4.2, 5.4, 0.3]:
				var p := ParkLayout.POND_CENTER + Vector2(cos(a), sin(a)) * (ParkLayout.POND_RADII + Vector2(1.8, 1.8))
				if not world.map.is_solid(p):
					ends.append(Vector3(p.x, 0, p.y))
			spot = ends[world.rng.randi() % ends.size()]
			walk_to(spot)
			step = 2
		else:
			sit = Sit.new(["bench"], 50.0, "feed", world.fountain_pos)
			sit.begin(actor)
			step = 4

	func update(delta: float) -> void:
		match step:
			0:
				if walked():
					step = 1
					wait = 2.0
					actor.face(world.shops["kiosk"].vendor_pos())
			1:
				wait -= delta
				if wait <= 0.0:
					world.shops["kiosk"].serve_npc(actor, "bread")
					_go_feed()
			2:
				if walked():
					actor.face(Vector3(ParkLayout.POND_CENTER.x, 0, ParkLayout.POND_CENTER.y))
					step = 3
					feed_time = world.rng.randf_range(30.0, 50.0)
			3:
				actor.anim = "feed"
				_drop_food(delta)
				feed_time -= delta
				if feed_time <= 0.0:
					done = true
			4:
				sit.tick(delta)
				if sit.seated:
					_drop_food(delta)
				if sit.done or sit.failed:
					done = true

	func _drop_food(delta: float) -> void:
		wait -= delta
		if wait <= 0.0:
			wait = world.rng.randf_range(1.6, 2.6)
			var p := actor.global_position + actor.forward() * world.rng.randf_range(2.0, 4.5) + Vector3(world.rng.randf_range(-1.5, 1.5), 0, world.rng.randf_range(-1.5, 1.5))
			world.add_food(p, "bread", actor)
			actor.needs.cheer(1.5)

	func end() -> void:
		if sit:
			sit.end()
		actor.anim = "idle"


## Take photos of landmarks (tourists).
class Photo extends Activity:
	var shots := 0
	var landmark := {}
	var wait := 0.0

	func start() -> void:
		kind = "photo"
		label = "fotografiert Sehenswürdigkeiten"
		timeout = 400.0
		_next()

	func _next() -> void:
		landmark = world.landmarks[world.rng.randi() % world.landmarks.size()]
		var focus: Vector3 = landmark["pos"]
		var a := world.rng.randf() * TAU
		var p := focus + Vector3(cos(a), 0, sin(a)) * world.rng.randf_range(6.0, 10.0)
		var c := world.nav.nearest_open(Vector2(p.x, p.z))
		if c.x < 0:
			failed = true
			return
		var q := ParkMap.cell_center(c)
		walk_to(Vector3(q.x, 0, q.y))
		wait = -1.0

	func update(delta: float) -> void:
		if not walked():
			return
		if wait < 0.0:
			actor.face(landmark["pos"])
			actor.look_target = landmark["pos"]
			actor.set_item("camera")
			wait = 4.0
		wait -= delta
		actor.anim = "photo"
		if wait <= 0.0:
			actor.emote("star")
			if world.rng.randf() < 0.4:
				actor.say(["Wonderful!", "So schön hier!", "Das muss ich posten!", "Cheese!"][world.rng.randi() % 4], 2.5)
			shots += 1
			actor.look_target = Vector3.INF
			if shots >= 3:
				done = true
			else:
				_next()

	func end() -> void:
		actor.set_item("")
		actor.anim = "idle"
		actor.look_target = Vector3.INF


## Lost tourist: wander, study the map, complain.
class Lost extends Activity:
	var stops := 0
	var wait := 0.0

	func start() -> void:
		kind = "lost"
		label = "hat sich verlaufen"
		timeout = 300.0
		walk_to(world.random_lawn_point(actor.ground_pos(), 30.0))

	func update(delta: float) -> void:
		if not walked():
			return
		if wait <= 0.0:
			wait = 7.0
			actor.set_item("map")
			actor.say(["Wo bin ich nur?", "Laut Karte müsste hier ein Teich sein …", "Hmm, links oder rechts?",
				"Ist das der Central Park?"][world.rng.randi() % 4], 3.0)
		wait -= delta
		actor.anim = "look_map"
		if wait <= 0.0:
			stops += 1
			actor.set_item("")
			if stops >= 2:
				done = true
			else:
				walk_to(world.random_lawn_point(actor.ground_pos(), 35.0))

	func end() -> void:
		actor.set_item("")
		actor.anim = "idle"


## Business call while pacing up and down.
class Phone extends Activity:
	var a: Vector3
	var b: Vector3
	var leg := 0
	var talk := 0.0
	const LINES := ["Ja … nein … ja!", "Wir müssen das synergetisch denken.", "Schick mir das per Mail.",
		"Ich bin gerade im Park. Ja, im Park!", "Das Meeting ist um drei.", "Die Zahlen müssen stimmen!",
		"Können wir das offline besprechen?", "Ich hab nur kurz Mittagspause …"]

	func start() -> void:
		kind = "phone"
		label = "telefoniert geschäftlich"
		timeout = world.rng.randf_range(60.0, 120.0)
		a = world.random_path_point()
		var c := world.nav.nearest_open(Vector2(a.x + 8, a.z))
		var q := ParkMap.cell_center(c) if c.x >= 0 else Vector2(a.x, a.z)
		b = Vector3(q.x, 0, q.y)
		actor.set_item("phone")
		walk_to(a)

	func update(delta: float) -> void:
		actor.anim = "phone"
		talk -= delta
		if talk <= 0.0:
			talk = world.rng.randf_range(4.0, 8.0)
			actor.say(LINES[world.rng.randi() % LINES.size()], 3.0)
		if walked():
			leg += 1
			walk_to(b if leg % 2 == 1 else a)

	func end() -> void:
		actor.set_item("")
		actor.anim = "idle"
		done = true


## Street performance at a fixed spot until the shift ends.
class Perform extends Activity:
	var spot: Vector3
	var yaw := 0.0
	var perf_anim := "mime"
	var prop := ""
	var talk := 0.0
	var lines: Array = []

	func _init(where: Vector3, facing: float, anim_name: String, item_id := "", speech: Array = []) -> void:
		spot = where
		yaw = facing
		perf_anim = anim_name
		prop = item_id
		lines = speech

	func start() -> void:
		kind = "perform"
		label = "tritt auf"
		timeout = world.rng.randf_range(240.0, 420.0)
		walk_to(spot)

	func update(delta: float) -> void:
		if not walked():
			return
		actor.face(spot + Vector3(sin(yaw), 0, cos(yaw)))
		actor.anim = perf_anim
		if prop != "":
			actor.set_item(prop)
		talk -= delta
		if talk <= 0.0:
			talk = world.rng.randf_range(6.0, 12.0)
			if perf_anim in ["guitar", "trumpet"]:
				actor.emote("note", 2)
				Sound.play("music", actor.global_position, -8.0)
			if not lines.is_empty() and world.rng.randf() < 0.5:
				actor.say(lines[world.rng.randi() % lines.size()], 3.0)

	func end() -> void:
		actor.set_item("")
		actor.anim = "idle"


## Vendors stand behind their counter during opening hours.
class Work extends Activity:
	var shop: Shop
	var chat := 0.0

	func _init(s: Shop) -> void:
		shop = s

	func start() -> void:
		kind = "work"
		label = "arbeitet am Stand"
		timeout = 100000.0
		walk_to(shop.vendor_pos())

	func update(delta: float) -> void:
		if not walked():
			return
		if actor.distance_to(shop.vendor_pos()) > 1.0:
			actor.teleport(shop.vendor_pos())
		actor.face(shop.customer_spot())
		actor.anim = "idle"
		chat -= delta
		if chat <= 0.0:
			chat = world.rng.randf_range(20.0, 45.0)
			var near := world.actors_near(shop.customer_spot(), 8.0, func(o: Actor) -> bool: return o.is_human() and o != actor)
			if not near.is_empty():
				actor.say(shop.advert(), 3.0)
				actor.play_anim("wave", 1.5)

	func at_post() -> bool:
		return not _walking and actor.distance_to(shop.vendor_pos()) < 1.5

	func end() -> void:
		actor.anim = "idle"


## Gardener: sweep paths, pick up litter, rake leaves.
class Garden extends Activity:
	var wait := 0.0
	var target_bottle: Node3D

	func start() -> void:
		kind = "garden"
		label = "fegt die Wege" if Clock.season != Clock.Season.WINTER else "räumt Schnee"
		timeout = world.rng.randf_range(90.0, 160.0)
		actor.set_item("broom")
		target_bottle = world.nearest_bottle(actor.global_position, 40.0)
		if target_bottle:
			label = "sammelt Müll auf"
			walk_to(target_bottle.global_position)
		else:
			walk_to(world.random_path_point())

	func update(delta: float) -> void:
		if not walked():
			actor.anim = "idle"
			return
		if target_bottle:
			if is_instance_valid(target_bottle) and actor.distance_to(target_bottle.global_position) < 1.5:
				world.remove_bottle(target_bottle)
				actor.say(["Immer dieser Müll!", "Ordnung muss sein.", "Pfand gehört nicht ins Gebüsch!"][world.rng.randi() % 3], 2.5)
			target_bottle = null
			wait = 2.0
		actor.anim = "sweep"
		wait -= delta
		if wait <= 0.0:
			wait = world.rng.randf_range(8.0, 14.0)
			walk_to(world.random_path_point() if world.rng.randf() < 0.5 else actor.global_position + Vector3(world.rng.randf_range(-6, 6), 0, world.rng.randf_range(-6, 6)))

	func end() -> void:
		actor.set_item("")
		actor.anim = "idle"


## Children at the playground.
class Play extends Activity:
	var what := ""
	var sit: Sit
	var wait := 0.0

	func start() -> void:
		kind = "play"
		timeout = world.rng.randf_range(60.0, 120.0)
		var pick := world.rng.randf()
		var pg := ParkLayout.place("playground")
		if pick < 0.4:
			what = "swing"
			label = "schaukelt"
			sit = Sit.new(["swing"], timeout, "swing", Vector3(pg.x, 0, pg.y))
			sit.begin(actor)
			if sit.failed:
				what = "run"
		elif pick < 0.7:
			what = "dig"
			label = "buddelt im Sandkasten"
			walk_to(Vector3(-36 + world.rng.randf_range(-1, 1), 0, 59 + world.rng.randf_range(-1, 1)))
		else:
			what = "run"
		if what == "run":
			label = "tobt herum"
			walk_to(Vector3(pg.x + world.rng.randf_range(-8, 8), 0, pg.y + world.rng.randf_range(-6, 6)), true)

	func update(delta: float) -> void:
		match what:
			"swing":
				sit.tick(delta)
				if sit.done or sit.failed:
					done = true
			"dig":
				if walked():
					actor.anim = "dig"
			"run":
				if walked():
					wait -= delta
					actor.anim = "cheer" if wait > 1.0 else "idle"
					if wait <= 0.0:
						wait = world.rng.randf_range(1.5, 3.0)
						var pg := ParkLayout.place("playground")
						walk_to(Vector3(pg.x + world.rng.randf_range(-9, 9), 0, pg.y + world.rng.randf_range(-6, 6)), true)

	func end() -> void:
		if sit:
			sit.end()
		actor.anim = "idle"


## Picnic on a blanket with food.
class Picnic extends Activity:
	var sit: Sit

	func start() -> void:
		kind = "picnic"
		label = "macht Picknick"
		sit = Sit.new(["blanket"], world.rng.randf_range(90.0, 160.0), "idle", Vector3(ParkLayout.place("picnic").x, 0, ParkLayout.place("picnic").y))
		sit.begin(actor)
		failed = sit.failed
		timeout = 400.0

	func update(delta: float) -> void:
		sit.tick(delta)
		if sit.seated and world.rng.randf() < delta * 0.05:
			actor.play_anim("eat", 4.0)
			actor.needs.eat(8.0, 2.0)
		if sit.done or sit.failed:
			done = true

	func end() -> void:
		sit.end()


## Walk the leashed dogs around, with free play at the dog meadow.
class DogWalk extends Activity:
	var route: Array[Vector3] = []
	var idx := 0
	var free_time := 0.0
	var at_meadow := false

	func start() -> void:
		kind = "dog_walk"
		label = "geht mit den Hunden Gassi"
		timeout = 600.0
		for d in actor.def.get("dogs", []):
			var dog := world.find_actor(d)
			if dog and not dog.controlled and not dog.inside:
				actor.attach_leash(dog)
		var meadow := world.dog_meadow.get_center()
		route = [world.random_path_point(), Vector3(meadow.x - 15, 0, meadow.y), Vector3(meadow.x, 0, meadow.y),
			world.random_path_point(), world.random_path_point()]
		actor.set_item("leash")
		walk_to(route[0])

	func update(delta: float) -> void:
		actor.anim = "dog_walk"
		if free_time > 0.0:
			free_time -= delta
			actor.anim = "idle"
			if world.rng.randf() < delta * 0.1:
				actor.say(["Brav!", "Na, ihr Racker!", "Bello, aus!", "Nicht so wild!"][world.rng.randi() % 4], 2.0)
			if free_time <= 0.0:
				for d in actor.def.get("dogs", []):
					var dog := world.find_actor(d)
					if dog and not dog.controlled:
						actor.attach_leash(dog)
				idx += 1
				walk_to(route[idx])
			return
		if not walked():
			return
		idx += 1
		if idx == 3 and not at_meadow:
			# Arrived at the meadow: let them run.
			at_meadow = true
			idx = 2
			for dog in actor.leash_dogs.duplicate():
				actor.detach_leash(dog)
			free_time = world.rng.randf_range(40.0, 70.0)
			return
		if idx >= route.size():
			done = true
			return
		walk_to(route[idx])

	func end() -> void:
		actor.set_item("")
		actor.anim = "idle"
		for d in actor.def.get("dogs", []):
			var dog := world.find_actor(d)
			if dog and not dog.controlled and dog.leash_owner == null and not dog.inside:
				actor.attach_leash(dog)


## Chat with somebody nearby.
class Chat extends Activity:
	var partner: Actor
	var lines := 0
	var wait := 0.0
	const SMALLTALK := ["Schönes Wetter heute, oder?", "Haben Sie die Enten gesehen?", "Der Donut-Stand ist der beste!",
		"Früher war hier mehr Lametta.", "Kennen Sie den Pantomimen?", "Ich glaub, es gibt Regen.", "Wie geht's dem Hund?",
		"Haben Sie schon von dem Ungeheuer im Teich gehört?", "Die Tauben werden auch immer frecher.",
		"Ich jogge morgen. Ganz bestimmt.", "Unter der Steinbrücke soll nachts ein Troll wohnen!", "Was für ein Tag!"]
	const REPLIES := ["Ach was!", "Ja, wirklich!", "Hm-hm.", "Das sag ich doch immer!", "Nein, echt?", "Haha, genau!",
		"Da haben Sie recht.", "Ich weiß nicht so recht …"]

	func _init(other: Actor) -> void:
		partner = other

	func start() -> void:
		kind = "chat"
		label = "plaudert mit %s" % partner.display_name
		timeout = 60.0
		walk_to(partner.global_position + (actor.global_position - partner.global_position).normalized() * 1.3)

	func update(delta: float) -> void:
		if not is_instance_valid(partner) or partner.controlled or partner.inside:
			done = true
			return
		if not walked():
			return
		actor.face(partner.global_position)
		partner.face(actor.global_position)
		wait -= delta
		if wait <= 0.0:
			wait = 3.5
			if lines % 2 == 0:
				actor.say(SMALLTALK[world.rng.randi() % SMALLTALK.size()], 3.2)
				actor.play_anim("talk", 3.0)
			else:
				partner.say(REPLIES[world.rng.randi() % REPLIES.size()], 3.0)
				partner.play_anim("talk", 2.5)
			lines += 1
			if lines >= 5:
				done = true
				actor.needs.cheer(6.0)
				partner.needs.cheer(6.0)


## Go stand under the pavilion roof (or open the umbrella) while it rains.
class Shelter extends Activity:
	func start() -> void:
		kind = "shelter"
		label = "stellt sich unter"
		timeout = 240.0
		if world.rng.randf() < 0.5 or actor.distance_to(world.pavilion_stage) > 70.0:
			actor.set_item("umbrella")
			label = "spaziert mit Schirm"
			walk_to(world.random_path_point())
		else:
			walk_to(world.pavilion_stage + Vector3(world.rng.randf_range(-2.5, 2.5), 0, world.rng.randf_range(-2.5, 2.5)))

	func update(_delta: float) -> void:
		actor.anim = "hold" if actor.item == "umbrella" else "idle"
		if walked() and not Clock.is_raining():
			done = true

	func end() -> void:
		if actor.item == "umbrella" and not Clock.is_raining():
			actor.set_item("")
		actor.anim = "idle"


## Watch a performer and clap now and then.
class Watch extends Activity:
	var performer: Actor
	var wait := 0.0

	func _init(p: Actor) -> void:
		performer = p

	func start() -> void:
		kind = "watch"
		label = "schaut %s zu" % performer.display_name
		timeout = world.rng.randf_range(30.0, 60.0)
		var a := world.rng.randf_range(-1.0, 1.0) + performer.yaw
		var p := performer.global_position + Vector3(sin(a), 0, cos(a)) * world.rng.randf_range(3.0, 5.0)
		walk_to(p)

	func update(delta: float) -> void:
		if not walked():
			return
		actor.face(performer.global_position)
		wait -= delta
		if wait <= 0.0:
			wait = world.rng.randf_range(5.0, 10.0)
			actor.play_anim("clap", 2.0)
			if world.rng.randf() < 0.3:
				actor.say(["Bravo!", "Toll!", "Zugabe!", "Wie macht der das?"][world.rng.randi() % 4], 2.0)
		if world.rng.randf() < delta * 0.02:
			actor.needs.cheer(4.0)

	func end() -> void:
		actor.needs.cheer(8.0)


## Yoga on the great meadow.
class Yoga extends Activity:
	var spot: Vector3

	func start() -> void:
		kind = "yoga"
		label = "macht Yoga"
		timeout = world.rng.randf_range(80.0, 140.0)
		var m := ParkLayout.place("great_meadow")
		spot = Vector3(m.x + world.rng.randf_range(-8, 8), 0, m.y + world.rng.randf_range(-4, 4))
		walk_to(spot)

	func update(_delta: float) -> void:
		if not walked():
			return
		var t := fmod(elapsed, 20.0)
		actor.anim = "stretch" if t < 7.0 else ("cheer" if t < 12.0 else ("squat" if t < 16.0 else "idle"))
		actor.needs.cheer(0.02)

	func end() -> void:
		actor.anim = "idle"


## Leave the park through the nearest gate and stay away until the next visit.
class Leave extends Activity:
	var gate: Vector3

	func start() -> void:
		kind = "leave"
		label = "geht nach Hause"
		timeout = 400.0
		var best := INF
		for g in world.gates:
			var d := actor.distance_to(g)
			if d < best:
				best = d
				gate = g
		if not walk_to(gate):
			failed = false
			_go_home()

	func _go_home() -> void:
		actor.inside = true
		actor.visible = false
		for dog in actor.leash_dogs:
			dog.inside = true
			dog.visible = false
		done = true

	func update(_delta: float) -> void:
		if done:
			return
		if walked():
			actor.inside = true
			actor.visible = false
			for dog in actor.leash_dogs:
				dog.inside = true
				dog.visible = false
			done = true

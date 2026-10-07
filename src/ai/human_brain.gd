class_name HumanBrain
extends Brain
## Utility-based daily life for people: needs (hunger, fatigue, joy), personal
## likes, a visiting schedule, the weather and a role routine (vendor, performer...).

var current: Activity
var think := 0.0
var last_kind := ""
var cooldown := {}          # activity kind -> seconds until allowed again
var role := ""
var likes := {}
var hours: Array = []


func _init(a: Actor) -> void:
	super(a)
	role = a.def.get("role", "visitor")
	likes = a.def.get("likes", {})
	hours = a.def.get("hours", [[8, 20]])
	think = rng.randf_range(0.2, 2.0)


func in_hours(h := -1.0) -> bool:
	if h < 0.0:
		h = Clock.hour()
	for w: Array in hours:
		var start: float = w[0]
		var end: float = w[1]
		if end > 24.0:
			if h >= start or h < end - 24.0:
				return true
		elif h >= start and h < end:
			return true
	return false


func doing() -> String:
	if actor.inside:
		return "ist gerade nicht im Park"
	if current:
		return current.label
	return "überlegt, was als Nächstes kommt"


func suspend() -> void:
	if current:
		current.end()
		current = null
	actor.stop_moving()


func resume() -> void:
	think = 0.5


func update(delta: float) -> void:
	for k: String in cooldown.keys():
		cooldown[k] -= delta
		if cooldown[k] <= 0.0:
			cooldown.erase(k)
	if actor.inside:
		think -= delta
		if think <= 0.0:
			think = rng.randf_range(4.0, 12.0)
			if in_hours():
				_arrive()
		return
	if current:
		current.tick(delta)
		if current.done or current.failed:
			_finish()
		elif _should_interrupt():
			_finish()
	if current == null:
		think -= delta
		if think <= 0.0:
			think = rng.randf_range(0.5, 2.0)
			_choose()


func _finish() -> void:
	current.end()
	cooldown[current.kind] = 40.0 if current.failed else 20.0
	last_kind = current.kind
	current = null
	actor.anim = "idle"


func _should_interrupt() -> bool:
	if current.kind in ["leave", "work", "eat"]:
		return false
	if not in_hours() and role != "troll":
		return true
	if Clock.is_raining() and current.kind in ["picnic", "yoga", "wander", "photo"] and not cooldown.has("shelter"):
		return true
	if actor.needs.hunger > 92.0 and current.kind != "eat" and not cooldown.has("eat"):
		return true
	return false


func _start(a: Activity) -> void:
	current = a
	a.begin(actor)
	if a.failed:
		a.end()
		cooldown[a.kind] = 30.0
		current = null


func _arrive() -> void:
	var gate: Vector3 = world.gate_outside[rng.randi() % world.gate_outside.size()]
	actor.inside = false
	actor.visible = true
	actor.teleport(gate)
	for d in actor.def.get("dogs", []):
		var dog := world.find_actor(d)
		if dog and not dog.controlled:
			dog.inside = false
			dog.visible = true
			dog.teleport(gate + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)))
			actor.attach_leash(dog)
	_start(Activities.Wander.new())


func _choose() -> void:
	if not in_hours():
		_start(Activities.Leave.new())
		return
	var routine := _routine()
	var n := actor.needs
	var options := []   # [score, Callable]
	if routine:
		options.append([5.0, routine])
	if Clock.is_raining() and actor.item != "umbrella":
		options.append([3.0 * likes.get("shelter", 1.0), func() -> Activity: return Activities.Shelter.new()])
	if n.hunger > 35.0:
		options.append([pow(n.hunger / 100.0, 2.0) * 6.0 * likes.get("eat", 1.0), func() -> Activity: return Activities.Eat.new()])
	options.append([(pow(n.fatigue / 100.0, 1.5) * 4.0 + 0.3) * likes.get("sit", 1.0),
		func() -> Activity: return Activities.Sit.new(["bench"], rng.randf_range(40.0, 90.0), _sit_anim())])
	if n.fatigue > 70.0 and likes.get("sleep", 0.0) > 0.0:
		options.append([likes["sleep"] * 2.0, func() -> Activity: return Activities.Sit.new(["bench"], rng.randf_range(80.0, 160.0), "sleep")])
	options.append([0.6 * likes.get("wander", 1.0), func() -> Activity: return Activities.Wander.new()])
	if likes.get("jog", 0.0) > 0.0 and n.fatigue < 60.0:
		options.append([likes["jog"] * (1.0 - n.fatigue / 100.0) * 2.0, func() -> Activity: return Activities.Jog.new()])
	if likes.get("feed_ducks", 0.0) > 0.0:
		options.append([likes["feed_ducks"], func() -> Activity: return Activities.Feed.new("ducks")])
	if likes.get("feed_pigeons", 0.0) > 0.0:
		options.append([likes["feed_pigeons"], func() -> Activity: return Activities.Feed.new("pigeons")])
	if likes.get("photo", 0.0) > 0.0 and not Clock.is_night():
		options.append([likes["photo"], func() -> Activity: return Activities.Photo.new()])
	if likes.get("lost", 0.0) > 0.0:
		options.append([likes["lost"], func() -> Activity: return Activities.Lost.new()])
	if likes.get("phone", 0.0) > 0.0:
		options.append([likes["phone"], func() -> Activity: return Activities.Phone.new()])
	if likes.get("picnic", 0.0) > 0.0 and not Clock.is_raining() and not Clock.is_night():
		options.append([likes["picnic"], func() -> Activity: return Activities.Picnic.new()])
	if likes.get("play", 0.0) > 0.0:
		options.append([likes["play"], func() -> Activity: return Activities.Play.new()])
	if likes.get("yoga", 0.0) > 0.0 and Clock.hour() < 12.0 and not Clock.is_raining():
		options.append([likes["yoga"], func() -> Activity: return Activities.Yoga.new()])
	if likes.get("read", 0.0) > 0.0:
		options.append([likes["read"], func() -> Activity: return Activities.Sit.new(["bench"], rng.randf_range(60.0, 120.0), "read")])
	if likes.get("chess", 0.0) > 0.0:
		options.append([likes["chess"], func() -> Activity: return Activities.Sit.new(["stool"], rng.randf_range(80.0, 160.0), "chess")])
	if likes.get("dance", 0.0) > 0.0:
		options.append([likes["dance"], func() -> Activity: return _dance()])
	var partner := _chat_partner()
	if partner:
		options.append([likes.get("chat", 0.6) * 1.2, func() -> Activity: return Activities.Chat.new(partner)])
	var performer := _performer_nearby()
	if performer:
		options.append([likes.get("watch", 0.8) * 1.5, func() -> Activity: return Activities.Watch.new(performer)])
	# Pick the best with some noise, avoiding immediate repetition.
	var best_score := -1.0
	var best: Callable
	for o: Array in options:
		var score: float = o[0] * rng.randf_range(0.7, 1.3)
		var act: Callable = o[1]
		if score > best_score:
			best_score = score
			best = act
	if best.is_valid():
		var a: Activity = best.call()
		if a == null:
			return
		if a.kind != "" and cooldown.has(a.kind) and a.kind not in ["work", "perform"]:
			return
		_start(a)


func _sit_anim() -> String:
	var r := rng.randf()
	if likes.get("read", 0.0) > 0.0 and r < 0.4:
		return "read"
	if likes.get("phone", 0.0) > 0.0 and r < 0.6:
		return "phone"
	return "idle"


func _dance() -> Activity:
	var spot := world.fountain_pos + Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(5, 8))
	return Activities.Perform.new(spot, rng.randf() * TAU, "dance", "", ["Wuhuu!", "Was für ein Beat!", "Tanzt mit!"])


func _chat_partner() -> Actor:
	if likes.get("chat", 0.6) <= 0.0 or cooldown.has("chat"):
		return null
	for o in world.actors_near(actor.global_position, 12.0):
		if o == actor or not o.is_human() or o.controlled or o.seat != null:
			continue
		var b := o.brain as HumanBrain
		if b and (b.current == null or b.current.kind == "wander") and b.role not in ["vendor", "troll"]:
			return o
	return null


func _performer_nearby() -> Actor:
	if cooldown.has("watch"):
		return null
	for o in world.actors_near(actor.global_position, 30.0):
		var b := o.brain as HumanBrain
		if b and b.current and b.current.kind == "perform" and o != actor:
			return o
	return null


## Role-specific routine for the current time, or an invalid Callable.
func _routine() -> Callable:
	var work: Dictionary = actor.def.get("work", {})
	if work.is_empty():
		return Callable()
	if work.has("hours"):
		var wh: Array = work["hours"]
		var h := Clock.hour()
		if h < wh[0] or h >= wh[1]:
			return Callable()
	if Clock.is_raining() and work.get("dry", false):
		return Callable()
	match work.get("type", ""):
		"shop":
			var shop: Shop = world.shops.get(work["shop"])
			if shop:
				return func() -> Activity: return Activities.Work.new(shop)
		"perform":
			var spot := _spot(work["spot"])
			var yaw: float = spot.w
			return func() -> Activity: return Activities.Perform.new(Vector3(spot.x, spot.y, spot.z), yaw, work["anim"], work.get("item", ""), work.get("lines", []))
		"garden":
			return func() -> Activity: return Activities.Garden.new()
		"chess":
			return func() -> Activity:
				var table: Bench = world.chess_tables[0]
				return Activities.Sit.new(["stool"], rng.randf_range(200.0, 400.0), "chess", table.position)
		"dogwalk":
			return func() -> Activity: return Activities.DogWalk.new()
		"fetch":
			return func() -> Activity: return FetchPlay.new()
	return Callable()


## Named performance spots -> (x, y, z, yaw).
func _spot(id: String) -> Vector4:
	match id:
		"mime":
			var f := world.fountain_pos + Vector3(0, 0, 7.5)
			return Vector4(f.x, f.y, f.z, 0.0)
		"pavilion":
			return Vector4(world.pavilion_stage.x, world.pavilion_stage.y, world.pavilion_stage.z, world.pavilion_yaw)
		"shell":
			var t: Dictionary = world.shell_table
			var p: Vector3 = t["pos"]
			var yaw: float = t["yaw"]
			var behind := p - Vector3(sin(yaw), 0, cos(yaw)) * 0.8
			return Vector4(behind.x, 0, behind.z, yaw)
		"boule":
			var b: Vector2 = ParkLayout.AREAS["boule"]["pos"]
			return Vector4(b.x - 7.0, 0, b.y, PI / 2)
		"bridge_troll":
			for br in world.map.bridges:
				if br["name"] == "Steinbrücke":
					var c: Vector2 = br["center"]
					var d: Vector2 = br["dir"]
					var side := Vector2(-d.y, d.x)
					var p2 := c + side * 1.0 + d * (float(br["length"]) * 0.5 - 1.6)
					return Vector4(p2.x, 0, p2.y, atan2(-d.x, -d.y))
	return Vector4(0, 0, 0, 0)


## Throwing a frisbee for the dog on the great meadow.
class FetchPlay extends Activity:
	var dog: Actor
	var wait := 2.0

	func start() -> void:
		kind = "fetch"
		label = "spielt Frisbee mit dem Hund"
		timeout = world.rng.randf_range(120.0, 200.0)
		var dogs: Array = actor.def.get("dogs", [])
		if dogs.is_empty():
			failed = true
			return
		dog = world.find_actor(dogs[0])
		var m := ParkLayout.place("great_meadow")
		walk_to(Vector3(m.x - 10, 0, m.y))

	func update(delta: float) -> void:
		if not walked():
			return
		if dog == null or dog.controlled or not (dog.brain is AnimalBrain):
			done = true
			return
		actor.detach_leash(dog)
		var db := dog.brain as AnimalBrain
		wait -= delta
		if wait <= 0.0 and db.fetch_target == Vector3.INF:
			wait = world.rng.randf_range(3.0, 6.0)
			var m := ParkLayout.place("great_meadow")
			var t := Vector3(m.x + world.rng.randf_range(-4, 14), 0, m.y + world.rng.randf_range(-8, 8))
			actor.face(t)
			actor.play_anim("throw", 0.8)
			Projectile.throw_item(world, "frisbee", actor.global_position + Vector3(0, 1.2, 0), t, 1.4)
			db.fetch(t, actor)

	func end() -> void:
		if dog and not dog.controlled:
			actor.attach_leash(dog)

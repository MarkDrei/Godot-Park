class_name AnimalBrain
extends Brain
## State machines for all animals. Behaviour depends on species and needs:
## hungry animals look for food, tired ones sleep, scared ones flee.

var state := "idle"
var timer := 0.0
var target := Vector3.INF
var home := Vector3.ZERO
var fetch_target := Vector3.INF
var fetch_owner: Actor
var carrying := ""
var climb_tree := {}
var _climb_h := 0.0
var _climb_dir := 1.0
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _hop_t := 0.0
var mother: Actor
var follow_index := 0
var _bark_cd := 0.0
var _food_ref = null


func _init(a: Actor) -> void:
	super(a)
	timer = rng.randf_range(0.5, 3.0)
	var h: Array = a.def.get("home", [])
	if h.size() == 2:
		home = Vector3(h[0], 0, h[1])
	else:
		home = a.global_position
	if a.def.has("mother"):
		follow_index = a.def.get("follow_index", 1)


func doing() -> String:
	if actor.inside:
		return {"mouse": "versteckt sich im Mauseloch", "owl": "schläft tagsüber", "hedgehog": "schläft im Gebüsch",
			"fox": "ist im Bau"}.get(actor.species, "ist gerade nicht zu sehen")
	return {
		"idle": "schaut sich um", "wander": "streift umher", "follow": "läuft brav an der Leine",
		"play": "tobt herum", "sleep": "schläft", "eat": "frisst", "flee": "flüchtet!", "stalk": "pirscht sich an",
		"climb": "klettert auf einen Baum", "up": "sitzt im Baum", "swim": "schwimmt", "food": "will Futter!",
		"fetch": "holt die Frisbee", "hide": "versteckt sich", "fly": "fliegt auf", "fish": "fischt",
		"steal": "hat es auf einen Donut abgesehen", "beg": "bettelt", "hiss": "faucht", "dig": "buddelt",
	}.get(state, "lebt sein Leben")


func suspend() -> void:
	actor.stop_moving()
	_end_climb()
	state = "idle"


func resume() -> void:
	state = "idle"
	timer = 0.5


func fetch(t: Vector3, owner: Actor) -> void:
	fetch_target = t
	fetch_owner = owner
	state = "fetch"
	actor.go_to(t, true)


func update(delta: float) -> void:
	timer -= delta
	_bark_cd -= delta
	if not actor.inside:
		_self_care(delta)
	if state == "forage":
		return
	match actor.species:
		"dog": _dog(delta)
		"cat": _cat(delta)
		"mouse": _mouse(delta)
		"duck", "duckling", "goose": _duck(delta)
		"squirrel": _squirrel(delta)
		"pigeon": _pigeon(delta)
		"heron": _heron(delta)
		"owl": _owl(delta)
		"hedgehog", "fox": _night_critter(delta)


# --- Needs -----------------------------------------------------------------------------

const BUSY := ["flee", "fetch", "climb", "up", "fly", "hide", "food", "steal", "stash", "stalk", "sleep", "beg"]


## Contented animals cheer up; hungry ones forage (or get a treat from their owner).
func _self_care(delta: float) -> void:
	var n := actor.needs
	var minutes := delta * Clock.MINUTES_PER_SECOND * Clock.time_scale
	if n.hunger < 60.0 and n.fatigue < 70.0:
		n.enjoy(minutes, 9.0 if state in ["play", "swim"] else 4.0)
	if state == "forage":
		actor.anim = {"duck": "eat", "duckling": "eat", "goose": "eat", "pigeon": "peck", "dog": "eat", "heron": "fish"}.get(actor.species, "eat")
		if timer <= 0.0:
			n.eat(45.0, 6.0)
			state = "idle"
			actor.anim = "idle"
		return
	if n.hunger < 58.0 or state in BUSY or actor.custom_motion:
		return
	if actor.species in ["cat", "owl"]:
		return
	if actor.species == "dog":
		var o := actor.leash_owner
		if o and not o.controlled and rng.randf() < delta * 0.05:
			o.say("Hier, ein Leckerli!", 2.0)
			o.play_anim("feed", 1.5)
			actor.play_anim("beg", 1.5)
			n.eat(40.0, 10.0)
		elif o == null and rng.randf() < delta * 0.03:
			actor.play_anim("sniff", 2.0)
			n.eat(25.0, 3.0)
		return
	if rng.randf() < delta * 0.08:
		actor.stop_moving()
		state = "forage"
		timer = rng.randf_range(4.0, 7.0)


# --- Helpers ------------------------------------------------------------------------

func _wander(center: Vector3, radius: float, run := false) -> void:
	var p := world.nav.random_point_near(Vector2(center.x, center.z), radius, rng, actor.nav_profile)
	actor.go_to(Vector3(p.x, 0, p.y), run)


func _nearest(radius: float, filter: Callable) -> Actor:
	var best: Actor = null
	var best_d := radius
	for o in world.actors:
		if o == actor or o.inside or not o.visible:
			continue
		var d := actor.distance_to(o.global_position)
		if d < best_d and filter.call(o):
			best_d = d
			best = o
	return best


func _flee(from: Vector3, dist := 8.0) -> void:
	var away := actor.global_position - from
	away.y = 0
	if away.length() < 0.01:
		away = Vector3(1, 0, 0)
	var t := actor.global_position + away.normalized() * dist
	var c := world.nav.nearest_open(Vector2(t.x, t.z), actor.nav_profile, 6)
	if c.x >= 0:
		var q := ParkMap.cell_center(c)
		actor.go_to(Vector3(q.x, 0, q.y), true)
	state = "flee"
	timer = 2.5


func _is_night() -> bool:
	return Clock.is_night()


func _sleep_if_tired(anim := "sleep") -> bool:
	if actor.needs.fatigue > 75.0 and state != "sleep":
		actor.stop_moving()
		state = "sleep"
		timer = rng.randf_range(30.0, 60.0)
		actor.anim = anim
		return true
	if state == "sleep":
		actor.anim = anim
		if timer <= 0.0 or actor.needs.fatigue < 10.0:
			state = "idle"
			actor.anim = "idle"
		return true
	return false


func _hide(duration: float) -> void:
	actor.inside = true
	actor.visible = false
	state = "hide"
	timer = duration


func _unhide(at: Vector3) -> void:
	actor.teleport(at)
	actor.inside = false
	actor.visible = true
	state = "idle"


# --- Dogs ---------------------------------------------------------------------------

func _dog(delta: float) -> void:
	if state == "fetch":
		actor.anim = "run" if actor.is_moving() else "idle"
		if not actor.is_moving():
			if carrying == "":
				carrying = "frisbee"
				actor.set_item("frisbee")
				if fetch_owner:
					actor.go_to(fetch_owner.global_position + fetch_owner.forward() * 1.2, true)
				Projectile.clear_landed(world, fetch_target)
			else:
				carrying = ""
				actor.set_item("")
				fetch_target = Vector3.INF
				state = "idle"
				actor.play_anim("play", 1.5)
				actor.emote("heart")
		return
	if actor.leash_owner and is_instance_valid(actor.leash_owner):
		_dog_follow(delta)
		return
	if _sleep_if_tired("lie"):
		return
	var owner_id: String = actor.def.get("owner", "")
	var owner := world.find_actor(owner_id) if owner_id != "" else null
	var in_meadow := world.dog_meadow.has_point(actor.ground_pos())
	if owner and not owner.inside and actor.distance_to(owner.global_position) > 25.0 and not in_meadow:
		state = "follow"
		if timer <= 0.0:
			timer = 2.0
			actor.go_to(owner.global_position, true)
		return
	_dog_bark_check()
	if timer <= 0.0:
		var r := rng.randf()
		if in_meadow:
			if r < 0.55:
				state = "play"
				var m := world.dog_meadow
				actor.go_to(Vector3(rng.randf_range(m.position.x, m.end.x), 0, rng.randf_range(m.position.y, m.end.y)), rng.randf() < 0.7)
				timer = rng.randf_range(2.0, 5.0)
			elif r < 0.7:
				actor.play_anim("roll", 2.5)
				timer = 3.0
			elif r < 0.85:
				actor.play_anim("play", 1.8)
				timer = 2.0
			else:
				actor.play_anim("sniff", 3.0)
				timer = 3.5
		else:
			state = "wander"
			_wander(home if owner == null or owner.inside else owner.global_position, 12.0)
			timer = rng.randf_range(4.0, 9.0)
	actor.anim = "idle"


func _dog_follow(_delta: float) -> void:
	var o := actor.leash_owner
	var idx := o.leash_dogs.find(actor)
	var side := (idx % 2) * 2 - 1
	var right := Vector3(cos(o.yaw), 0, -sin(o.yaw))
	var spot := o.global_position - o.forward() * (0.8 + idx / 2 * 0.6) + right * side * (0.6 + idx * 0.25)
	var d := actor.distance_to(spot)
	state = "follow"
	_dog_bark_check()
	if d > 4.5:
		actor.go_direct(spot, true)
	elif d > 1.2:
		actor.go_direct(spot, d > 2.5 or o.running)
	elif not actor.is_moving():
		if o.velocity.length() < 0.2 and timer <= 0.0:
			timer = rng.randf_range(3.0, 7.0)
			actor.play_anim(["sniff", "sit", "idle", "sniff"][rng.randi() % 4], rng.randf_range(2.0, 4.0))
		actor.face(o.global_position + o.forward() * 3.0)
	actor.anim = "idle"


func _dog_bark_check() -> void:
	if _bark_cd > 0.0:
		return
	var prey := _nearest(9.0, func(o: Actor) -> bool: return o.species in ["squirrel", "cat"] and not o.custom_motion)
	if prey:
		_bark_cd = rng.randf_range(10.0, 20.0)
		actor.face(prey.global_position)
		actor.play_anim("bark", 1.6)
		actor.say("Wuff! Wuff!", 1.6)
		Sound.play("bark", actor.global_position)


# --- Cats -----------------------------------------------------------------------------

func _cat(delta: float) -> void:
	if state in ["climb", "up"]:
		_climb_update(delta)
		return
	var dog := _nearest(6.0, func(o: Actor) -> bool: return o.species == "dog")
	if dog and state != "flee":
		var tree := world.nearest_tree(actor.global_position, 12.0)
		if not tree.is_empty():
			_start_climb(tree, 2.2)
			actor.say("Fauch!", 1.5)
		else:
			_flee(dog.global_position, 12.0)
		return
	if state == "flee":
		if timer <= 0.0 and not actor.is_moving():
			state = "idle"
		return
	if _sleep_if_tired("sleep"):
		return
	if actor.needs.hunger > 65.0 and state != "eat":
		state = "eat"
		var bowl := world.shop_spots.get("kiosk", {}).get("pos", home) as Vector3
		actor.go_to(bowl + Vector3(2.5, 0, 0.5))
		timer = 30.0
		return
	if state == "eat":
		if not actor.is_moving():
			actor.anim = "eat"
			actor.needs.eat(delta * 3.0, 0.0)
			if actor.needs.hunger < 10.0 or timer <= 0.0:
				state = "idle"
				actor.anim = "idle"
				actor.play_anim("groom", 4.0)
		return
	if state == "stalk":
		var mouse := target_actor
		if mouse == null or mouse.inside or not mouse.visible:
			state = "idle"
			actor.anim = "idle"
			actor.speed_mult = 1.0
			return
		var d := actor.distance_to(mouse.global_position)
		actor.anim = "crouch"
		actor.speed_mult = 0.45
		if d < 2.2:
			actor.speed_mult = 2.2
			actor.play_anim("pounce", 0.6)
			actor.go_direct(mouse.global_position, true)
			(mouse.brain as AnimalBrain).scare(actor.global_position)
			state = "idle"
			timer = 3.0
			actor.anim = "idle"
			actor.speed_mult = 1.0
			if rng.randf() < 0.5:
				actor.say("Miau …", 1.5)
		elif timer <= 0.0:
			timer = 0.8
			actor.go_to(mouse.global_position)
		return
	if timer <= 0.0:
		var mouse2 := _nearest(12.0, func(o: Actor) -> bool: return o.species == "mouse")
		if mouse2 and rng.randf() < 0.7:
			target_actor = mouse2
			state = "stalk"
			timer = 0.0
			return
		var r := rng.randf()
		if r < 0.5:
			state = "wander"
			actor.speed_mult = 0.8
			_wander(home, 22.0)
			timer = rng.randf_range(6.0, 12.0)
		elif r < 0.7:
			actor.play_anim("groom", 5.0)
			timer = 6.0
		elif r < 0.85:
			actor.play_anim("sit", 6.0)
			timer = 7.0
			if rng.randf() < 0.3:
				actor.say("Miau.", 1.5)
				Sound.play("meow", actor.global_position)
		else:
			var tree := world.nearest_tree(actor.global_position, 15.0)
			if not tree.is_empty():
				_start_climb(tree, 2.4)
	actor.anim = "idle"


var target_actor: Actor


# --- Mice ----------------------------------------------------------------------------

func scare(from: Vector3) -> void:
	if state == "hide":
		return
	state = "flee"
	actor.speed_mult = 1.4
	actor.go_to(home, true)
	timer = 6.0
	if actor.controlled:
		return
	if from != Vector3.ZERO:
		actor.say("Fiep!", 1.2)


func _mouse(delta: float) -> void:
	if state == "hide":
		if timer <= 0.0:
			var out := _nocturnal_ok() and _nearest(5.0, func(o: Actor) -> bool: return o.species in ["cat", "dog"]) == null
			if out:
				_unhide(home)
				actor.speed_mult = 1.0
			else:
				timer = 8.0
		return
	if state == "flee":
		if not actor.is_moving() or actor.distance_to(home) < 0.8:
			_hide(rng.randf_range(10.0, 25.0))
		return
	var threat := _nearest(4.5, func(o: Actor) -> bool:
		return o.species in ["cat", "dog", "fox"] or (o.is_human() and o.velocity.length() > 2.5))
	if threat:
		scare(threat.global_position)
		if threat.controlled and threat.species == "cat":
			GameState.add_stat("mice_scared")
		return
	if not _nocturnal_ok() and rng.randf() < delta * 0.02:
		actor.go_to(home)
		state = "flee"
		return
	if timer <= 0.0:
		var r := rng.randf()
		if r < 0.6:
			state = "wander"
			_wander(home, 9.0, rng.randf() < 0.5)
			timer = rng.randf_range(1.5, 4.0)
		else:
			actor.play_anim("eat" if r < 0.8 else "upright", 2.5)
			actor.needs.eat(6.0, 0.0)
			timer = 3.0
	actor.anim = "idle"


func _nocturnal_ok() -> bool:
	# Mice are out at night and around the food court during the day.
	return true


# --- Ducks -----------------------------------------------------------------------------

func _duck(delta: float) -> void:
	var is_goose := actor.species == "goose"
	if actor.species == "duckling" and mother == null:
		mother = world.find_actor(actor.def.get("mother", ""))
	# Ducklings stick to their mother.
	if actor.species == "duckling" and mother and not mother.inside:
		var spot := mother.global_position - mother.forward() * (0.45 * follow_index + 0.3)
		if actor.distance_to(spot) > 0.5:
			actor.go_direct(spot, actor.distance_to(spot) > 2.0)
		actor.anim = "sleep" if mother.current_anim() == "sleep" else "idle"
		state = "follow"
		return
	# Night: sleep floating near the island.
	if _is_night() and state != "food":
		if state != "sleep":
			state = "sleep"
			var p := ParkLayout.ISLAND_CENTER + Vector2(rng.randf_range(-6, 6), rng.randf_range(4.5, 7))
			actor.go_to(Vector3(p.x, 0, p.y))
		if not actor.is_moving():
			actor.anim = "sleep"
		return
	if state == "sleep":
		state = "idle"
		actor.anim = "idle"
	# Food on the water or the shore.
	var food = world.nearest_food(actor.global_position, 22.0 if not is_goose else 30.0)
	if food != null:
		state = "food"
		if actor.distance_to(food["pos"]) > 0.6:
			if timer <= 0.0:
				timer = 0.6
				actor.go_to(food["pos"], true)
			actor.anim = "idle"
		else:
			actor.stop_moving()
			actor.anim = "eat"
			if world.consume_food(food, actor):
				actor.needs.eat(25.0, 8.0)
				if rng.randf() < 0.4:
					actor.say("Quak!" if not is_goose else "Schnatter!", 1.2)
		return
	if state == "food":
		state = "idle"
	# A player carrying lots of bread gets followed.
	var bread_carrier := _nearest(12.0, func(o: Actor) -> bool: return o.controlled and o.inventory.get("bread", 0) >= 3)
	if bread_carrier:
		state = "beg"
		if timer <= 0.0:
			timer = 1.0
			actor.go_to(bread_carrier.global_position - bread_carrier.forward() * 1.2, true)
			if rng.randf() < 0.3:
				actor.say("Quak? Quak!", 1.2)
				Sound.play("quack", actor.global_position)
		return
	if is_goose:
		var victim := _nearest(3.0, func(o: Actor) -> bool: return o.is_human())
		if victim and _bark_cd <= 0.0:
			_bark_cd = 12.0
			actor.face(victim.global_position)
			actor.play_anim("flap", 1.5)
			actor.say("Zisch!", 1.5)
	if timer <= 0.0:
		var r := rng.randf()
		if r < 0.6:
			state = "swim"
			var p := _random_water_point()
			actor.go_to(p)
			timer = rng.randf_range(6.0, 14.0)
		elif r < 0.75:
			state = "shore"
			var a := rng.randf() * TAU
			var p2 := ParkLayout.POND_CENTER + Vector2(cos(a) * (ParkLayout.POND_RADII.x + 2.5), sin(a) * (ParkLayout.POND_RADII.y + 2.5))
			actor.go_to(Vector3(p2.x, 0, p2.y))
			timer = rng.randf_range(8.0, 14.0)
		else:
			actor.play_anim(["eat", "preen", "quack", "flap"][rng.randi() % 4], 2.5)
			if rng.randf() < 0.3:
				Sound.play("quack", actor.global_position)
			timer = 3.0
	actor.anim = "eat" if state == "shore" and not actor.is_moving() else "idle"


func _random_water_point() -> Vector3:
	for i in 20:
		var a := rng.randf() * TAU
		var k := rng.randf_range(0.1, 0.85)
		var p := ParkLayout.POND_CENTER + Vector2(cos(a) * ParkLayout.POND_RADII.x * k, sin(a) * ParkLayout.POND_RADII.y * k)
		if world.map.is_water(p):
			return Vector3(p.x, 0, p.y)
	return Vector3(ParkLayout.POND_CENTER.x - 8, 0, ParkLayout.POND_CENTER.y)


# --- Squirrels ---------------------------------------------------------------------------

func _squirrel(delta: float) -> void:
	if state == "hide":
		if timer <= 0.0:
			timer = 20.0
			if not _is_night():
				_unhide(home)
		return
	if state in ["climb", "up"]:
		_climb_update(delta)
		if state == "up" and _is_night() and not actor.controlled:
			# Sleep in the drey (nest) up in the tree.
			_end_climb()
			_hide(60.0)
		return
	if _is_night() and not actor.controlled:
		var tree := world.nearest_tree(actor.global_position, 30.0)
		if not tree.is_empty():
			_start_climb(tree, tree["height"] * 0.55)
		else:
			_hide(60.0)
		return
	var threat := _nearest(7.0, func(o: Actor) -> bool: return o.species in ["dog", "cat", "fox"] or (o.is_human() and o.velocity.length() > 2.5))
	if threat:
		var tree := world.nearest_tree(actor.global_position, 14.0)
		if not tree.is_empty():
			_start_climb(tree, tree["height"] * 0.55)
			return
	if _sleep_if_tired("sleep"):
		return
	if state == "steal":
		var victim := target_actor
		if victim == null or victim.item not in ["donut", "pretzel", "hotdog"]:
			state = "idle"
			return
		if actor.distance_to(victim.global_position) < 1.0:
			var stolen := victim.item
			victim.set_item("")
			victim.say("He! Mein %s!" % {"donut": "Donut", "pretzel": "Brezel", "hotdog": "Hot Dog"}.get(stolen, "Essen"), 2.5)
			victim.emote("angry")
			victim.needs.cheer(-10.0)
			carrying = "donut"
			actor.set_item("donut")
			state = "stash"
			var stash := world.stash_tree()
			actor.go_to(Vector3(stash["pos"].x, 0, stash["pos"].y), true)
			if victim.controlled:
				GameState.toast.emit("Nussi hat dein Essen geklaut!", "warn")
		elif timer <= 0.0:
			timer = 0.5
			actor.go_to(victim.global_position, true)
		return
	if state == "stash":
		if not actor.is_moving():
			actor.set_item("")
			carrying = ""
			world.add_to_stash()
			_start_climb(world.stash_tree(), 3.0)
		return
	if timer <= 0.0:
		if actor.def.get("thief", false):
			var eater := _nearest(25.0, func(o: Actor) -> bool: return o.is_human() and o.item in ["donut", "pretzel"] and o.seat != null)
			if eater and rng.randf() < 0.6:
				target_actor = eater
				state = "steal"
				timer = 0.0
				return
		var r := rng.randf()
		if r < 0.45:
			state = "wander"
			var t := world.nearest_tree(actor.global_position, 30.0) if rng.randf() < 0.5 else world.random_tree()
			var tp: Vector2 = t["pos"] + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
			actor.go_to(Vector3(tp.x, 0, tp.y), true)
			timer = rng.randf_range(2.0, 5.0)
		elif r < 0.65:
			actor.play_anim("upright", 2.5)
			timer = 2.5
		elif r < 0.8:
			actor.play_anim("dig" if Clock.season == Clock.Season.AUTUMN else "eat", 3.0)
			actor.needs.eat(10.0, 2.0)
			timer = 3.0
		else:
			var tree := world.nearest_tree(actor.global_position, 15.0)
			if not tree.is_empty():
				_start_climb(tree, tree["height"] * 0.55)
	actor.anim = "idle"


# --- Climbing (cats, squirrels) ------------------------------------------------------------

func _start_climb(tree: Dictionary, h: float) -> void:
	climb_tree = tree
	_climb_h = h
	_climb_dir = 1.0
	var p: Vector2 = tree["pos"]
	var away := (actor.ground_pos() - p).normalized()
	if away.length() < 0.1:
		away = Vector2(1, 0)
	var foot := p + away * (float(tree["trunk"]) + 0.15)
	actor.go_to(Vector3(foot.x, 0, foot.y), true)
	state = "climb"
	timer = 0.0


func _climb_update(delta: float) -> void:
	var p: Vector2 = climb_tree["pos"]
	if state == "climb" and actor.is_moving():
		return
	if not actor.custom_motion:
		actor.custom_motion = true
		actor.face(Vector3(p.x, actor.global_position.y, p.y), true)
	var ground: float = climb_tree["ground"]
	var climb_speed := 1.6 if actor.species == "squirrel" else 1.1
	var y := actor.global_position.y + _climb_dir * climb_speed * delta
	actor.anim = "climb"
	if _climb_dir > 0.0 and y >= ground + _climb_h:
		y = ground + _climb_h
		state = "up"
		_climb_dir = 0.0
		timer = rng.randf_range(6.0, 16.0)
		if actor.controlled:
			GameState.add_stat("trees_climbed")
	elif _climb_dir == 0.0:
		actor.anim = "upright" if actor.species == "squirrel" else "sit"
		if timer <= 0.0 and not actor.controlled:
			_climb_dir = -1.0
	elif _climb_dir < 0.0 and y <= ground:
		_end_climb()
		return
	actor.global_position.y = y


func climb_down() -> void:
	if state == "up":
		_climb_dir = -1.0


func _end_climb() -> void:
	if not actor.custom_motion:
		return
	actor.custom_motion = false
	var p := actor.global_position
	actor.global_position.y = world.map.walk_height(p.x, p.z)
	state = "idle"
	actor.anim = "idle"
	timer = 1.0


func is_up_tree() -> bool:
	return state in ["climb", "up"] and actor.custom_motion


# --- Pigeons --------------------------------------------------------------------------------

func _pigeon(delta: float) -> void:
	if state == "fly":
		_hop_t += delta / 1.4
		var t := clampf(_hop_t, 0.0, 1.0)
		var pos := _hop_from.lerp(_hop_to, t)
		pos.y += sin(t * PI) * 3.5
		actor.global_position = pos
		actor.anim = "fly"
		if t >= 1.0:
			actor.custom_motion = false
			state = "idle"
			actor.anim = "idle"
		return
	if _is_night() and not actor.controlled:
		if not actor.is_moving():
			actor.anim = "sleep"
		if state != "sleep":
			state = "sleep"
			_wander(home, 3.0)
		return
	if state == "sleep":
		state = "idle"
		actor.anim = "idle"
	var threat := _nearest(3.0, func(o: Actor) -> bool: return o.species in ["dog", "cat"] or (o.is_human() and o.velocity.length() > 2.6))
	if threat:
		_fly_away(threat.global_position)
		return
	var food = world.nearest_food(actor.global_position, 20.0)
	if food != null:
		if actor.distance_to(food["pos"]) > 0.4:
			if timer <= 0.0:
				timer = 0.5
				actor.go_to(food["pos"] + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)))
		else:
			actor.anim = "peck"
			if world.consume_food(food, actor):
				actor.needs.eat(20.0, 5.0)
		return
	if timer <= 0.0:
		if rng.randf() < 0.6:
			_wander(home, 10.0)
		else:
			actor.play_anim("peck", 2.0)
			if rng.randf() < 0.2:
				actor.say("Gurr.", 1.0)
		timer = rng.randf_range(2.0, 6.0)
	actor.anim = "idle"


func _fly_away(from: Vector3) -> void:
	var away := (actor.global_position - from)
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3(1, 0, 0)
	var dest := actor.global_position + away * rng.randf_range(8.0, 14.0) + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
	var c := world.nav.nearest_open(Vector2(dest.x, dest.z), ParkMap.Nav.ANIMAL, 6)
	if c.x < 0:
		return
	var q := ParkMap.cell_center(c)
	actor.stop_moving()
	_hop_from = actor.global_position
	_hop_to = Vector3(q.x, world.map.walk_height(q.x, q.y), q.y)
	_hop_t = 0.0
	actor.custom_motion = true
	actor.face(_hop_to, true)
	state = "fly"
	Sound.play("flap", actor.global_position, -6.0)


# --- Heron -----------------------------------------------------------------------------------

func _heron(delta: float) -> void:
	if state == "fly":
		_hop_t += delta / 3.0
		var t := clampf(_hop_t, 0.0, 1.0)
		var pos := _hop_from.lerp(_hop_to, t)
		pos.y += sin(t * PI) * 8.0
		actor.global_position = pos
		actor.anim = "fly"
		if t >= 1.0:
			state = "fish"
			actor.anim = "fish"
			timer = rng.randf_range(30.0, 70.0)
		return
	if not actor.custom_motion:
		actor.custom_motion = true
		_land_at(_fishing_spot())
	var threat := _nearest(6.0, func(o: Actor) -> bool: return o.species == "dog" or (o.is_human() and o.velocity.length() > 1.8))
	if threat or timer <= 0.0:
		_hop_from = actor.global_position
		_hop_to = _fishing_spot()
		_hop_t = 0.0
		actor.face(_hop_to, true)
		state = "fly"
		Sound.play("flap", actor.global_position, -4.0)
		return
	actor.anim = "fish"
	state = "fish"


func _fishing_spot() -> Vector3:
	var line := world.map.creek if rng.randf() < 0.6 else world.map.creek_out
	for i in 20:
		var idx := rng.randi_range(4, line.size() - 5)
		var n := TerrainBuilder._normal_at(line, idx) * (1.0 if rng.randf() < 0.5 else -1.0)
		var p := line[idx] + n * (ParkLayout.CREEK_HALF_WIDTH - 0.6)
		if world.map.bridge_at(p).is_empty() and ParkMap.in_park(p, 3.0):
			return Vector3(p.x, ParkLayout.WATER_Y - 0.35, p.y)
	return Vector3(ParkLayout.POND_CENTER.x + 18, ParkLayout.WATER_Y - 0.35, ParkLayout.POND_CENTER.y)


func _land_at(p: Vector3) -> void:
	actor.global_position = p
	actor.anim = "fish"
	timer = rng.randf_range(30.0, 70.0)


# --- Night animals ----------------------------------------------------------------------------

func _owl(_delta: float) -> void:
	var awake := _is_night()
	if not awake:
		if not actor.inside:
			_hide(30.0)
		return
	if actor.inside:
		var t := world.nearest_tree(home, 40.0, ["oak", "chestnut", "maple"])
		if t.is_empty():
			return
		var p: Vector2 = t["pos"]
		actor.inside = false
		actor.visible = true
		actor.custom_motion = true
		actor.global_position = Vector3(p.x + 1.2, float(t["ground"]) + float(t["height"]) * 0.5, p.y)
		state = "up"
	if timer <= 0.0:
		timer = rng.randf_range(15.0, 30.0)
		actor.play_anim("hoot", 3.0)
		actor.say("Uhuu!", 2.0)
		Sound.play("owl", actor.global_position)
	actor.anim = "idle"


func _night_critter(_delta: float) -> void:
	if not _is_night():
		if not actor.inside and not actor.is_moving():
			_hide(20.0)
		elif not actor.inside and state != "home":
			state = "home"
			actor.go_to(home)
		return
	if actor.inside:
		_unhide(home)
	var threat := _nearest(5.0 if actor.species == "hedgehog" else 9.0, func(o: Actor) -> bool: return o.species == "dog" or (actor.species == "fox" and o.is_human()))
	if threat:
		if actor.species == "hedgehog":
			actor.stop_moving()
			actor.play_anim("lie", 4.0)
			timer = 4.0
		else:
			_flee(threat.global_position, 14.0)
		return
	if timer <= 0.0:
		if actor.species == "fox" and rng.randf() < 0.35 and not world.bins.is_empty():
			var b: Vector3 = world.bins[rng.randi() % world.bins.size()]
			actor.go_to(b + Vector3(0.8, 0, 0))
			state = "dig"
			timer = 12.0
		else:
			state = "wander"
			_wander(home, 25.0)
			timer = rng.randf_range(5.0, 10.0)
	if state == "dig" and not actor.is_moving():
		actor.anim = "dig"
	else:
		actor.anim = "sniff" if actor.species == "hedgehog" and not actor.is_moving() else "idle"

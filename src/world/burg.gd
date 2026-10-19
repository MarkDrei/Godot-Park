class_name Burg
extends Node3D
## The Ritterburg at runtime (doc/burg.md): built when the player comes close
## (World.load_area). Keeps the posts of its people and the spots of its games, lights the
## torches at dusk, and on the hour from 11 to 18 Kunibert and Adelheid joust as a show (three
## runs on Donner and Wolke) unless a game uses the lists.

var world: World
var rng := RandomNumberGenerator.new()
var time := 0.0

## Where the people of the castle work (id -> [position, yaw]; HumanBrain "burg:<id>" spots),
## where its games start (id -> position).
var posts := {}
var spots := {}
## All torch flames in one mesh (BurgBuilder), lit at dusk.
var flames: MeshInstance3D


func setup(w: World) -> void:
	world = w
	name = "Burg"
	rng.seed = 7272


## The market's stands as shops (their vendors come with the castle's people) and the talk
## options for brewing and forging (BurgTrade).
const SHOPS := {"burg_witch": "herb_witch", "burg_alchemist": "alchemist", "burg_pig": "pig", "burg_honey": "honey",
	"burg_fish": "fish", "burg_tavern": "tavern"}


func setup_gameplay() -> void:
	for id: String in SHOPS:
		var stall: String = SHOPS[id]
		var vendor: Vector3 = posts[stall][0]
		var counter: Vector3 = spots.get(stall, vendor + Vector3(0, 0, -2.0))
		world.shop_spots[id] = {"pos": counter, "vendor": vendor}
		var shop := Shop.new()
		shop.setup(world, id, world.shop_spots[id])
		add_child(shop)
		world.shops[id] = shop


## The joust show: the hour it last ran (day * 24 + hour), its time, the riders and horses.
const SHOW_HOURS := [11, 18]
const SHOW_RUN := 5.0
var show_t := -1.0
var _show_hour := -1
var _show := []                 # [[knight, horse, lane z, from x], …]


func _process(delta: float) -> void:
	time += delta
	if flames:
		flames.visible = Clock.daylight() < 0.5
	if show_t >= 0.0:
		_show_step(delta)
	elif _show_due():
		start_show()


func _show_due() -> bool:
	var h := int(Clock.hour())
	if h < SHOW_HOURS[0] or h > SHOW_HOURS[1] or Clock.hour() - h > 0.05 or _show_hour == Clock.day * 24 + h:
		return false
	return world.map.burg_open and not Gameplay.any_active()


## Starts the joust show now (also used by tests): the knights mount, the horses come out.
func start_show() -> bool:
	_show_hour = Clock.day * 24 + int(Clock.hour())
	_show.clear()
	for e: Array in [["kunibert", "donner", BurgHorseGame.LANE_N, BurgHorseGame.X1], ["adelheid", "wolke", BurgHorseGame.LANE_S, BurgHorseGame.X0]]:
		var k := world.find_actor(e[0])
		var hrs := world.find_actor(e[1])
		if k == null or hrs == null or k.controlled or k.inside or k.dormant or (hrs.brain as AnimalBrain).state == "ridden":
			_show.clear()
			return false
		_show.append([k, hrs, e[2], e[3]])
	for e: Array in _show:
		var k: Actor = e[0]
		var hrs: Actor = e[1]
		if k.brain:
			k.brain.suspend()
		k.set_item("lance")
		k.custom_motion = true
		hrs.custom_motion = true
		hrs.inside = false
		hrs.visible = true
		(hrs.brain as AnimalBrain).state = "ridden"
	show_t = 0.0
	Sound.play("music", Vector3(BurgLayout.LISTS.x, 1, BurgLayout.LISTS.y), -8.0)
	return true


func _show_step(delta: float) -> void:
	show_t += delta
	var run := int(show_t / SHOW_RUN)
	if run >= 3 or _show.is_empty():
		end_show()
		return
	var k := fmod(show_t, SHOW_RUN) / SHOW_RUN
	var dir := 1.0 if run % 2 == 0 else -1.0
	for e: Array in _show:
		var knight: Actor = e[0]
		var hrs: Actor = e[1]
		var x0: float = e[3]
		var x1 := BurgHorseGame.X0 + BurgHorseGame.X1 - x0
		var x := lerpf(x0, x1, k) if dir > 0 else lerpf(x1, x0, k)
		var going := signf(x1 - x0) * dir
		var p := Vector3(x, world.map.walk_height(x, e[2]), e[2])
		var yaw := PI / 2 if going > 0 else -PI / 2
		hrs.global_position = p
		hrs.yaw = yaw
		hrs.rotation.y = yaw
		hrs.velocity = Vector3(going * (BurgHorseGame.X1 - BurgHorseGame.X0) / SHOW_RUN, 0, 0)
		knight.global_transform = Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, BurgHorseGame.SADDLE, 0))
		knight.yaw = yaw
		knight.anim = "ride"
	var before := fmod(show_t - delta, SHOW_RUN) / SHOW_RUN
	if before < 0.5 and k >= 0.5:
		Sound.play("hit", Vector3(BurgLayout.LISTS.x, 1.5, BurgLayout.LISTS.y))


func end_show() -> void:
	for e: Array in _show:
		var knight: Actor = e[0]
		var hrs: Actor = e[1]
		if is_instance_valid(knight):
			knight.custom_motion = false
			knight.anim = "idle"
			knight.set_item("")
			knight.rotation = Vector3(0, knight.yaw, 0)
			var q := Vector2(knight.global_position.x, knight.global_position.z + (3.5 if e[2] > BurgLayout.LISTS.y else -3.5))
			knight.teleport(Vector3(q.x, world.map.walk_height(q.x, q.y), q.y))
			if knight.brain:
				knight.brain.resume()
		if is_instance_valid(hrs):
			hrs.custom_motion = false
			hrs.velocity = Vector3.ZERO
			(hrs.brain as AnimalBrain).state = "idle"
			var home: Array = hrs.def.get("home", [])
			if home.size() == 2:
				hrs.teleport(Vector3(home[0], world.map.walk_height(home[0], home[1]), home[1]))
	_show.clear()
	show_t = -1.0

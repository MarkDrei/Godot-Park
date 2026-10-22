class_name Game
extends Node3D
## Boots the park: builds the world, spawns everybody, wires camera, controls,
## UI, minigames and quests, then shows the title screen.

var world: World
var camera: CameraRig
var player: PlayerController
var dev: DevOptions
var title_mode := true
var _title_angle := 0.0


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	dev = DevOptions.parse()
	dev.apply_save()
	UI.show_loading()
	world = World.new()
	world.name = "World"
	add_child(world)
	dev.apply_seed(world)
	world.build_progress.connect(UI.loading_progress)
	await world.build()
	camera = CameraRig.new()
	add_child(camera)
	camera.setup(world)
	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	player.setup(world, camera)
	Sound.attach_world(world)
	UI.loading_progress(0.95, "Verteile die Parkbewohner …")
	await get_tree().process_frame
	_spawn(world.area("park").cast())
	Clock.day_changed.connect(func(_d: int) -> void: rest_animals_at_midnight())
	world.area_loaded.connect(func(id: String) -> void: _spawn(world.area(id).cast(), true))
	Gameplay.setup(self)
	world.seal_park()
	world.split_areas = split_areas()
	UI.attach_game(self)
	world.env.follow_target = camera
	var loaded := GameState.load_game()
	if loaded:
		for a in world.actors:
			a.load_state()
	dev.apply_world(self)
	world.env.settle()
	apply_quality()
	UI.hide_loading()
	print("BANKFREI READY in %d ms, %d actors" % [Time.get_ticks_msec() - t0, world.actors.size()])
	if dev.control != "":
		_start_with(dev.control)
	else:
		UI.show_title(loaded and GameState.controlled_actor != "", _continue, _new_game)
	dev.after_start(self)


## Midnight (also when the night is skipped): animals still in the park are rested; those at
## home rest anyway. The animal the player controls is left alone, like a controlled person.
func rest_animals_at_midnight() -> void:
	for a in world.actors:
		if not a.is_human() and not a.controlled:
			a.needs.rest_fully()


## The people and animals of an area (Area.cast): the park's at the start, the others' once
## their area is built (with what the save game knows about them).
func _spawn(defs: Array, load_saved := false) -> void:
	var spawned: Array[Actor] = []
	for def: Dictionary in defs:
		var a := Actor.new()
		world.actors_root.add_child(a)
		a.setup(def, world)
		world.register_actor(a)
		if a.is_human():
			a.brain = HumanBrain.new(a)
		else:
			a.brain = AnimalBrain.new(a)
		if load_saved:
			a.load_state()
		spawned.append(a)
	for a in spawned:
		place_by_schedule(a)


## Where an actor is at this time of day (at the start, and when its area wakes up again).
func place_by_schedule(a: Actor) -> void:
	var rng := world.rng
	if a.brain is HumanBrain:
		var b := a.brain as HumanBrain
		if not b.in_hours():
			a.teleport(world.home_of(a)[1] if a.home_region != "park" else world.gates[0])
			a.inside = true
			a.visible = false
			return
		var shop := _stand_of_working(a)
		if shop:
			a.teleport(shop.vendor_pos())   # the stand opens on time, also right after the start
		elif a.home_region in ["burg", "coast"] and b.at_work_now():
			# The castle's and the coast's people are at their posts when it wakes (long ways).
			var post := b.work_pos()
			a.teleport(post + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) if post != Vector3.INF else world.random_path_point(a))
			a.inside = false
			a.visible = not a.dormant
		else:
			a.teleport(world.random_path_point(a) + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)))
		return
	var ab := a.brain as AnimalBrain
	var owner_id: String = a.def.get("owner", "")
	if owner_id != "":
		var owner := world.find_actor(owner_id)
		if owner:
			a.teleport(owner.global_position + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)))
			a.inside = owner.inside
			a.visible = owner.visible
			if not owner.inside:
				owner.attach_leash(a)
			return
	match a.species:
		"duck", "duckling", "goose":
			a.teleport(ab.random_water_point())
		"mouse", "cat", "pigeon", "squirrel", "hedgehog", "fox", "raven", "falcon", "horse", "gull":
			a.teleport(ab.home + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)))
		"heron":
			a.teleport(Vector3(0, 0, 0))
		"owl":
			a.teleport(ab.home)
			a.inside = true
			a.visible = false
		_:
			a.teleport(world.random_lawn_point())


## Game hours before work that a vendor placed anywhere in the area could need to the stand.
const VENDOR_COMMUTE_HOURS := 2.0


## The stand of a vendor who works now or within VENDOR_COMMUTE_HOURS (null otherwise).
## Placed anywhere, such a vendor opened up to an hour late after a start at 9:00.
func _stand_of_working(a: Actor) -> Shop:
	var work: Dictionary = a.def.get("work", {})
	if work.get("type", "") != "shop":
		return null
	var hours: Array = work["hours"]
	if Clock.hour() < hours[0] - VENDOR_COMMUTE_HOURS or Clock.hour() >= hours[1]:
		return null
	return world.shops.get(work["shop"])


## A new game starts like the very first one, also when a saved game was loaded for the
## title screen: progress, clock and everybody's needs, bags and places are fresh.
func _new_game(actor_id: String) -> void:
	GameState.new_game()
	Clock.reset()
	world.env.settle()
	if player.actor and player.actor.vehicle:
		player.exit_car(true)
	for a in world.actors:
		if a.brain:
			a.brain.suspend()
		a.reset_for_new_game()
	for a in world.actors:
		if not a.dormant:
			place_by_schedule(a)
		if a.brain:
			a.brain.resume()
	world.actors_moved()
	Gameplay.gathering.refresh()
	_start_with(actor_id)
	GameState.toast.emit("Willkommen im Stadtpark! Drück J für dein Notizbuch, M für die Karte.", "info")


func _continue() -> void:
	_start_with(GameState.controlled_actor)


func _start_with(actor_id: String) -> void:
	var a := world.find_actor(actor_id)
	if a == null:
		a = world.find_actor("jens")
	title_mode = false
	camera.end_override()
	player.control(a, false)
	UI.show_hud(true)


func _process(delta: float) -> void:
	if title_mode and camera:
		_title_angle += delta * 0.04
		var center := Vector3(10, 0, 0)
		var pos := center + Vector3(cos(_title_angle) * 70.0, 32.0, sin(_title_angle) * 55.0)
		camera.set_override(Transform3D(Basis(), pos).looking_at(center + Vector3(0, -6, 0), Vector3.UP))
		if camera.target == null:
			camera.global_transform = Transform3D(Basis(), pos).looking_at(center, Vector3.UP)


## Setting "areas": "split" keeps only the player's area loaded (phones), "all" keeps every
## area once built (PCs); "auto" splits on phones and tablets.
static func split_areas() -> bool:
	var mode: String = GameState.settings.get("areas", "auto")
	if mode == "auto":
		return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	return mode == "split"


func apply_areas() -> void:
	world.set_split(split_areas())


func apply_quality() -> void:
	var q: String = GameState.settings.get("quality", "auto")
	if q == "auto":
		q = "medium" if (OS.has_feature("mobile") or OS.has_feature("web")) else "high"
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_2X if q == "high" else Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = 0.75 if q == "low" else 1.0
	world.env.set_quality(q)
	if camera:
		camera.far = 400.0 if q == "low" else 900.0
		camera.sensitivity = GameState.settings.get("camera_sensitivity", 1.0)

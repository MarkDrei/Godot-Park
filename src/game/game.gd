extends Node3D
## Boots the park: builds the world, spawns everybody, wires camera, controls,
## UI, minigames and quests, then shows the title screen.

var world: World
var camera: CameraRig
var player: PlayerController
var dev: DevOptions
var title_mode := true
var _title_angle := 0.0
var _visitor_rng := RandomNumberGenerator.new()


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
	_spawn_cast()
	Clock.day_changed.connect(func(_d: int) -> void: rest_animals_at_midnight())
	world.city_built.connect(_spawn_city_cast)
	Gameplay.setup(self)
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


func _spawn_cast() -> void:
	_visitor_rng.seed = 2024
	var defs: Array = []
	defs.append_array(Cast.PEOPLE)
	for i in 10:
		defs.append(Cast.visitor(i, _visitor_rng))
	defs.append_array(Cast.FOREST)
	defs.append_array(Cast.ANIMALS)
	for def: Dictionary in defs:
		var a := Actor.new()
		world.actors_root.add_child(a)
		a.setup(def, world)
		world.register_actor(a)
		if a.is_human():
			a.brain = HumanBrain.new(a)
		else:
			a.brain = AnimalBrain.new(a)
	for a in world.actors:
		_place_initial(a)


## The people of the Oststadt, once it is loaded: residents, passers-by and children.
func _spawn_city_cast() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var defs: Array = []
	defs.append_array(Cast.CITY)
	for i in 10:
		defs.append(Cast.city_person(i, rng))
	for i in 4:
		defs.append(Cast.city_kid(i, rng))
	var spawned: Array[Actor] = []
	for def: Dictionary in defs:
		var a := Actor.new()
		world.actors_root.add_child(a)
		a.setup(def, world)
		world.register_actor(a)
		a.brain = HumanBrain.new(a)
		a.load_state()
		spawned.append(a)
	for a in spawned:
		_place_initial(a)


func _place_initial(a: Actor) -> void:
	var rng := world.rng
	if a.brain is HumanBrain:
		var b := a.brain as HumanBrain
		if b.in_hours():
			a.teleport(world.random_path_point(a) + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)))
		else:
			a.teleport(world.home_of(a)[1] if a.home_region != "park" else world.gates[0])
			a.inside = true
			a.visible = false
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
			a.teleport(ab._random_water_point())
		"mouse", "cat", "pigeon", "squirrel", "hedgehog", "fox":
			a.teleport(ab.home + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)))
		"heron":
			a.teleport(Vector3(0, 0, 0))
		"owl":
			a.teleport(ab.home)
			a.inside = true
			a.visible = false
		_:
			a.teleport(world.random_lawn_point())


func _new_game(actor_id: String) -> void:
	GameState.new_game()
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

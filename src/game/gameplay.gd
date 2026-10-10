class_name Gameplay
extends RefCounted
## Wires minigames, jobs, quests and easter eggs into the running game.

static var minigames := {}
static var quests: Quests
static var eggs: EasterEggs
static var markers: QuestMarkers
static var game_spots := {}       # minigame id -> position of its start spot
static var gathering: Gathering
static var dwarves: DwarfQuests


static func setup(game: Node) -> void:
	var world: World = game.world
	MinigolfGame.build_course(world)
	minigames = {
		"boule": BouleGame.new(),
		"minigolf": MinigolfGame.new(),
		"shell": ShellGame.new(),
		"frisbee": FrisbeeGame.new(),
		"photo": PhotoGame.new(),
		"bottles": BottleHuntGame.new(),
		"ducks": DuckFeedingGame.new(),
		"ttt": TicTacToeGame.new(),
		"axes": AxeThrowGame.new(),
		"chopping": ChopGame.new(),
		"switch": SwitchGame.new(),
		# Oststadt (their spots come when the town is loaded: setup_city).
		"taxi": TaxiJob.new(),
		"tow": TowJob.new(),
		"parking": ParkingGame.new(),
		"fuel": FuelGame.new(),
	}
	for id: String in minigames:
		(minigames[id] as Minigame).setup(game)
	Conversations.providers.clear()
	TaskBoard.providers.clear()
	Conversations.register(_minigame_options)
	TaskBoard.register(_minigame_tasks)
	quests = Quests.new()
	quests.setup(game)
	eggs = EasterEggs.new()
	eggs.setup(game)
	markers = QuestMarkers.new()
	markers.setup(game)
	gathering = Gathering.new()
	gathering.setup(game)
	dwarves = DwarfQuests.new()
	dwarves.setup(game)
	Clock.hour_changed.connect(func(_h: int) -> void: quests.hourly())
	game_spots.clear()
	_game_spots(world)
	world.city_built.connect(func() -> void: setup_city(world))


## Start spots of the Oststadt games (called when the town is loaded).
static func setup_city(world: World) -> void:
	_spot(world, Vector3(188.0, 0, 6.0), 16.0, "taxi", "Taxi-Schicht beginnen", true)
	_spot(world, Vector3(240.0, 0, -114.0), 13.0, "tow", "Abschleppdienst starten", true)
	_spot(world, Vector3(176.0, 0, -125.0), 6.5, "fuel", "Punktlandung mit Toni", true)
	_spot(world, Vector3(305.0, 0, -117.5), 3.0, "parking", "Einparken üben mit Friedrich")


static func any_active() -> bool:
	for m: Minigame in minigames.values():
		if m.active:
			return true
	return false


static func _minigame_options(player: Actor, npc: Actor) -> Array:
	var out := []
	if any_active():
		return out
	for id: String in minigames:
		var m: Minigame = minigames[id]
		if m.host_id != npc.actor_id or not m.can_start(player):
			continue
		if m == minigames["frisbee"] and player.actor_id != "balu" and npc.brain is HumanBrain:
			var hb := npc.brain as HumanBrain
			if hb.current == null or hb.current.kind != "fetch":
				out.append({"text": "Frisbee spielen (Lukas wirft gleich wieder auf der Großen Wiese)", "action": func() -> void: m.try_start(player)})
				continue
		var label := "Spielen: %s" % m.title
		if m.cost > 0:
			label += " (%s)" % GameState.format_money(m.cost)
		out.append({"text": label, "action": func() -> void: m.try_start(player)})
	return out


## The minigame's notebook goal is reached.
static func minigame_done(id: String) -> bool:
	match id:
		"boule": return GameState.stat("boule_wins") > 0
		"minigolf": return GameState.is_unlocked("minigolf_pro")
		"shell": return GameState.stat("shell_streak") > 0
		"frisbee": return GameState.stat("frisbee_catches") >= 3
		"photo": return GameState.stat("perfect_photos") > 0
		"bottles": return GameState.stat("bottles") >= 10
		"ducks": return GameState.stat("duck_game_best") >= 8
		"ttt": return GameState.stat("ttt_wins") > 0
		"axes": return GameState.stat("axe_best") >= AxeThrowGame.GOAL
		"chopping": return GameState.stat("chop_wins") > 0
		"switch": return GameState.stat("switch_best") >= 15
		"taxi": return GameState.stat("taxi_fares") >= 4
		"tow": return GameState.stat("cars_towed") >= 3
		"parking": return GameState.stat("parking_best") >= 7
		"fuel": return GameState.stat("fuel_best") >= 95
	return false


static func _minigame_tasks() -> Array:
	var out := []
	for id: String in minigames:
		var m: Minigame = minigames[id]
		out.append({"title": "Minispiel: %s" % m.title, "desc": m.describe(), "done": minigame_done(id)})
	return out


## Interactables at the game locations (alternative to talking to the host).
static func _game_spots(world: World) -> void:
	var c := MinigolfGame.area_center()
	_spot(world, Vector3(c.x - 14.5, 0, c.y), 3.0, "minigolf", "Minigolf spielen (2,00 €)")
	_spot(world, world.giant_board + Vector3(0, 0, 3.0), 3.0, "ttt", "Tic-Tac-Toe gegen Boris")
	var t: Dictionary = world.shell_table
	_spot(world, t["pos"] + Vector3(sin(t["yaw"]), 0, cos(t["yaw"])) * 0.9, 1.8, "shell", "Hütchenspiel (2,00 €)")
	var b: Vector2 = ParkLayout.AREAS["boule"]["pos"]
	_spot(world, Vector3(b.x - 8.0, 0, b.y), 3.0, "boule", "Boule mit Monsieur Jacques")
	var pier: Vector2 = ParkLayout.PIER["to"]
	_spot(world, Vector3(pier.x, 0, pier.y + 1.5), 2.5, "ducks", "Futterchaos mit Oma Gertrud")
	_spot(world, world.bottle_machine + Vector3(1.5, 0, 0), 2.2, "bottles", "Pfandjagd starten")
	# Nordwald.
	_spot(world, Vector3(-43.0, 0, -151.0), 2.2, "axes", "Axtwerfen (1,00 €)")
	_spot(world, Vector3(-31.0, 0, -156.6), 1.6, "chopping", "Holzhacken gegen Holger")
	_spot(world, Vector3(95.4, 0, -238.0), 2.2, "switch", "Weichen stellen mit Thrain")
	# A little hut at the minigolf course.
	var hut := MeshKit.new()
	hut.box(Vector3(0, 1.1, 0), Vector3(1.8, 2.2, 1.6), Color("e8dcc0"))
	hut.lathe(PackedVector2Array([Vector2(1.5, 2.2), Vector2(0.0, 3.0)]), 4, Color("2e6fbf"), PI / 4)
	hut.box(Vector3(0.91, 1.3, 0), Vector3(0.02, 0.8, 1.0), Color("3a3a3a"))
	var hm := MeshInstance3D.new()
	hm.mesh = hut.commit()
	hm.position = Vector3(c.x - 15.5, world.map.height_at(c.x - 15.5, c.y + 2.0), c.y + 2.0)
	world.static_root.add_child(hm)
	world.map.add_obstacle_rect(Vector2(c.x - 15.5, c.y + 2.0), Vector2(1.8, 1.6), 0.0)
	var l := Label3D.new()
	l.text = "MINIGOLF\n2,00 €"
	l.font_size = 48
	l.pixel_size = 0.004
	l.position = hm.position + Vector3(0.93, 2.0, 0)
	l.rotation.y = PI / 2
	l.outline_size = 8
	world.static_root.add_child(l)


## A start spot for a minigame. from_car: used from a car (the car must suit the game).
static func _spot(world: World, pos: Vector3, r: float, game_id: String, text: String, from_car := false) -> void:
	var m: Minigame = minigames[game_id]
	var s := FunctionSpot.new()
	s.name = "MinigameSpot_" + game_id
	s.position = Vector3(pos.x, world.map.walk_height(pos.x, pos.z), pos.z)
	s.radius = r
	s.users = "human"
	s.from_car = from_car
	s.prompt_fn = func(a: Actor) -> String:
		if m.active:
			return ""
		if from_car and not m.can_start(a):
			return ""
		if not m.host_available():
			var h := m.host()
			return "%s (%s ist nicht da)" % [text, h.display_name if h else "niemand"]
		return text
	s.available_fn = func(a: Actor) -> bool: return m.host_available() and not any_active() and m.can_start(a)
	s.action_fn = func(a: Actor) -> void: m.try_start(a)
	world.add_child(s)
	game_spots[game_id] = s.position

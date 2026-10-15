class_name Gameplay
extends RefCounted
## Wires minigames, jobs, quests and easter eggs into the running game.

static var minigames := {}
static var modules: Array[QuestModule] = []   # the quest modules below (QuestMarkers asks each)
static var quests: Quests
static var eggs: EasterEggs
static var markers: QuestMarkers
static var game_spots := {}       # minigame id -> position of its start spot
static var gathering: Gathering
static var dwarves: DwarfQuests
static var stories: FairStories
static var playground: PlaygroundQuests


static func setup(game: Game) -> void:
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
		# The playground's games with the gang (doc/playground.md).
		"swing_duel": SwingGame.new(),
		"trampoline": TrampolineGame.new(),
		"sanddig": SandDigGame.new(),
		# Oststadt (their spots come when the town is loaded: setup_city).
		"taxi": TaxiJob.new(),
		"tow": TowJob.new(),
		"parking": ParkingGame.new(),
		"fuel": FuelGame.new(),
		"exam": DrivingTest.new(),
		"wash": CarWash.new(),
		"delivery": DeliveryJob.new(),
		"karts": KartRace.new(),
		"icevan": IceVanJob.new(),
		"garbage": GarbageJob.new(),
		"crane": CraneGame.new(),
		"rally": RallyGame.new(),
		# Westpark: the rides of the Kirmes (their spots come when it is loaded: setup_fair).
		"ride_ferris": FerrisRide.new(),
		"ride_carousel": CarouselRide.new(),
		"ride_chain": ChainRide.new(),
		"ride_swing": SwingRide.new(),
		"ride_ghost": GhostRide.new(),
		"ride_coaster": CoasterRide.new(),
		"bumper": BumperCars.new(),
		# Westpark: the booths (tickets instead of money).
		"booth_cans": CanThrow.new(),
		"booth_ducks": DuckFishing.new(),
		"booth_rings": RingToss.new(),
		"booth_darts": BalloonDarts.new(),
		"booth_moles": WhackAMole.new(),
		"booth_wheel": WheelOfFortune.new(),
		"booth_striker": HighStriker.new(),
		# Westpark: the machines in the arcade hall.
		"arcade_snake": SnakeMachine.new(),
		"arcade_astro": AstroMachine.new(),
		"arcade_bricks": BricksMachine.new(),
		"almond_shift": AlmondShift.new(),
	}
	for id: String in minigames:
		(minigames[id] as Minigame).setup(game)
	Conversations.providers.clear()
	TaskBoard.providers.clear()
	Conversations.register(_minigame_options)
	TaskBoard.register(_minigame_tasks)
	quests = Quests.new()
	dwarves = DwarfQuests.new()
	stories = FairStories.new()
	playground = PlaygroundQuests.new()
	modules = [quests, dwarves, stories, playground]
	for m in modules:
		m.setup(game)
	eggs = EasterEggs.new()
	eggs.setup(game)
	markers = QuestMarkers.new()
	markers.setup(game)
	gathering = Gathering.new()
	gathering.setup(game)
	Clock.hour_changed.connect(func(_h: int) -> void: quests.hourly())
	game_spots.clear()
	_game_spots(world)
	world.city_built.connect(func() -> void: setup_city(world))
	world.fair_built.connect(func() -> void: setup_fair(world))


## Start spots of the Oststadt games (called when the town is loaded).
static func setup_city(world: World) -> void:
	_spot(world, Vector3(188.0, 0, 6.0), 16.0, "taxi", "Taxi-Schicht beginnen", true)
	_spot(world, Vector3(240.0, 0, -114.0), 13.0, "tow", "Abschleppdienst starten", true)
	_spot(world, Vector3(176.0, 0, -125.0), 6.5, "fuel", "Punktlandung mit Toni", true)
	_spot(world, Vector3(305.0, 0, -117.5), 3.0, "parking", "Einparken üben mit Friedrich")
	_spot(world, Vector3(308.0, 0, -117.5), 3.0, "exam", "Fahrprüfung bei Friedrich")
	_spot(world, Vector3(CarWash.ENTRY.x, 0, CarWash.ENTRY.y - 2.0), 4.5, "wash", "Waschstraße (3,00 €)", true)
	_spot(world, Vector3(190.0, 0, -66.0), 6.0, "delivery", "Lieferungen abholen", true)
	_spot(world, Vector3(240.0, 0, -171.0), 3.5, "karts", "Kartrennen (2,00 €)")
	_spot(world, Vector3(298.0, 0, 55.25), 8.0, "icevan", "Eiswagen-Tour starten", true)
	_spot(world, Vector3(368.0, 0, -206.0), 8.0, "garbage", "Müllabfuhr starten", true)
	_spot(world, Vector3(322.0, 0, -192.0), 3.5, "crane", "Schrottkran bedienen")
	_spot(world, Vector3(318.0, 0, 77.0), 7.0, "rally", "Oldtimer-Rallye mit Opa Egon", true)


## Start spots of the Kirmes's rides (called when the Westpark is loaded).
static func setup_fair(world: World) -> void:
	var s: Dictionary = world.fair.spots
	for r: Array in [["ride_ferris", "ferris_wheel", "Riesenrad fahren"], ["ride_carousel", "carousel", "Karussell fahren"],
			["ride_chain", "chain_swing", "Kettenkarussell fahren"], ["ride_swing", "swing_boat", "Schiffschaukel fahren"],
			["ride_ghost", "ghost_train", "Geisterbahn fahren"], ["ride_coaster", "coaster", "Achterbahn fahren"],
			["bumper", "bumper_cars", "Autoscooter fahren"]]:
		var m: Minigame = minigames[r[0]]
		_spot(world, s[r[1]], 2.6, r[0], "%s (%s)" % [r[2], GameState.format_money(m.cost)])
	for id: String in ["cans", "ducks", "rings", "darts", "moles", "wheel"]:
		var m: BoothGame = minigames["booth_" + id]
		_spot(world, world.fair.booths[id]["pos"], 1.8, "booth_" + id, "%s (%s)" % [m.title, GameState.format_money(m.cost)])
	var hs: BoothGame = minigames["booth_striker"]
	_spot(world, s["high_striker"], 1.8, "booth_striker", "%s (%s)" % [hs.title, GameState.format_money(hs.cost)])
	_fair_counters(world)
	# The three machines at the back of the arcade hall.
	var hall := FairLayout.place("arcade")
	var k := 0
	for id: String in ["arcade_snake", "arcade_astro", "arcade_bricks"]:
		var m: ArcadeGame = minigames[id]
		var x := hall.x - 3.0 + k * 3.0
		m.cabinet = Vector3(x, world.map.walk_height(x, hall.y - 5.7), hall.y - 5.7)
		_spot(world, m.cabinet, 1.2, id, "%s spielen (%s)" % [m.title, GameState.format_money(m.cost)])
		k += 1


## Los-Lothar's lottery tickets and the prize counter.
static func _fair_counters(world: World) -> void:
	var lots := FunctionSpot.new()
	lots.name = "FairLots"
	lots.position = world.fair.booths["lots"]["pos"]
	lots.radius = 1.8
	lots.users = "human"
	var lothar := func() -> Actor: return world.find_actor("lothar")
	var at_post := func() -> bool:
		var l: Actor = lothar.call()
		return l != null and not l.inside and not l.controlled and l.distance_to(world.fair.posts["lots"][0]) < 1.5
	lots.prompt_fn = func(_a: Actor) -> String:
		return "Los kaufen (%s)" % GameState.format_money(FairTrade.LOT_PRICE) if at_post.call() else "Los kaufen (Los-Lothar ist nicht da)"
	lots.available_fn = func(_a: Actor) -> bool: return at_post.call() and not any_active()
	lots.action_fn = func(a: Actor) -> void: FairTrade.buy_lot(a)
	world.fair.add_child(lots)
	var prizes := FunctionSpot.new()
	prizes.name = "FairPrizes"
	prizes.position = world.fair.booths["prizes"]["pos"]
	prizes.radius = 2.0
	prizes.users = "human"
	var sascha_there := func() -> bool:
		var s: Actor = world.find_actor("sascha")
		return s != null and not s.inside and not s.controlled and s.distance_to(world.fair.posts["prizes"][0]) < 1.5
	prizes.prompt_fn = func(_a: Actor) -> String:
		return "Gewinnausgabe (%d Tickets)" % GameState.tickets if sascha_there.call() else "Gewinnausgabe (Sascha ist nicht da)"
	prizes.available_fn = func(_a: Actor) -> bool: return sascha_there.call() and not any_active()
	prizes.action_fn = func(a: Actor) -> void: FairTrade.open_prizes(a)
	world.fair.add_child(prizes)


static func any_active() -> bool:
	for m: Minigame in minigames.values():
		if m.active:
			return true
	return false


static func _minigame_options(player: Actor, npc: Actor) -> Array:
	var out := []
	if any_active():
		return out
	for m: Minigame in minigames.values():
		if m.host_id == npc.actor_id and m.can_start(player):
			out.append({"text": m.talk_option(player, npc), "action": func() -> void: m.try_start(player)})
	return out


static func _minigame_tasks() -> Array:
	var out := []
	for id: String in minigames:
		var m: Minigame = minigames[id]
		out.append({"title": "%s: %s" % ["Fahrgeschäft" if m is Ride else "Minispiel", m.title], "desc": m.describe(), "done": m.goal_done()})
	out.append_array(FairPass.tasks())
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
	# Playground.
	var sw: Vector2 = Playground.SWINGS[SwingGame.SWING_SET] + Vector2(0, -2.7)
	_spot(world, Vector3(sw.x, 0, sw.y), 1.2, "swing_duel", "Schaukel-Duell mit Finja")
	var tr := Playground.TRAMPOLINE + Vector2(2.4, 0)
	_spot(world, Vector3(tr.x, 0, tr.y), 1.2, "trampoline", "Trampolin mit Robin")
	var sb := Playground.SANDBOX + Vector2(0, Playground.SANDBOX_SIZE.y * 0.5 + 0.9)
	_spot(world, Vector3(sb.x, 0, sb.y), 1.4, "sanddig", "Schatzsuche mit Mika")
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
			return "%s (%s)" % [text, m.unavailable_text()]
		return text
	s.available_fn = func(a: Actor) -> bool: return m.host_available() and not any_active() and m.can_start(a)
	s.action_fn = func(a: Actor) -> void: m.try_start(a)
	world.add_child(s)
	game_spots[game_id] = s.position

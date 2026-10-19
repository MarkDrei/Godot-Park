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
		"cinema": Cinema.new(),
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
		# Ritterburg: the tournament and the market's games (their spots come when it is loaded).
		"burg_joust": BurgJoust.new(),
		"burg_rings": BurgRings.new(),
		"burg_archery": BurgArchery.new(),
		"burg_tug": BurgTug.new(),
		"burg_bet": BurgBet.new(),
		"burg_dice": BurgDice.new(),
		"burg_crystal": BurgCrystal.new(),
		"burg_tower": BurgTower.new(),
	}
	for id: String in minigames:
		(minigames[id] as Minigame).setup(game)
	Conversations.providers.clear()
	TaskBoard.providers.clear()
	Conversations.register(_minigame_options)
	BurgTrade.setup()
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
	BurgPassage.setup(world)
	world.area_loaded.connect(func(id: String) -> void:
		if id == "city":
			setup_city(world)
		elif id == "fair":
			setup_fair(world)
		elif id == "burg":
			setup_burg(world))


## Start spots of the Oststadt games (called when the town is loaded).
static func setup_city(world: World) -> void:
	for id: String in CityLayout.GAME_SPOTS:
		var s: Array = CityLayout.GAME_SPOTS[id]
		var p: Vector2 = CityLayout.vehicle_pos(s[0]) if s[0] is String else s[0]
		_spot(world, Vector3(p.x, 0, p.y), s[1], id, s[2], s[3])


## Start spots of the Ritterburg's games (called when the Burg is loaded; phase 3, doc/burg.md).
static func setup_burg(world: World) -> void:
	BurgPassage.setup_burg(world)
	var dice: Vector3 = world.burg.spots["dice"]
	var mg := BurgLayout.place("magician") + Vector2(0, 2.2).rotated(-PI * 0.25)
	for g: Array in [["burg_joust", Vector2(-338, -106), 2.5, "Tjost gegen Kunibert"], ["burg_rings", Vector2(-332, -128), 2.5, "Ringstechen"],
			["burg_archery", Vector2(-152, -102), 2.5, "Bogenschießen"], ["burg_tug", Vector2(-196, -136), 3.0, "Tauziehen gegen Kunibert"],
			["burg_bet", Vector2(-224, -95.5), 2.5, "Auf den Schwertkampf wetten"], ["burg_dice", Vector2(dice.x, dice.z), 2.0, "Würfeln mit Fritz"],
			["burg_crystal", mg, 2.2, "In die Kristallkugel schauen"], ["burg_tower", Vector2(-241, -239.6), 2.0, "Auf den Aussichtsturm"]]:
		_spot(world, Vector3(g[1].x, 0, g[1].y), g[2], g[0], g[3])


## Start spots of the Kirmes's rides (called when the Westpark is loaded).
static func setup_fair(world: World) -> void:
	HerbSpots.place_fair(world, world.area("fair").root)
	var s: Dictionary = world.fair.spots
	for r: Array in [["ride_ferris", "ferris_wheel", "Riesenrad fahren"], ["ride_carousel", "carousel", "Karussell fahren"],
			["ride_chain", "chain_swing", "Kettenkarussell fahren"], ["ride_swing", "swing_boat", "Schiffschaukel fahren"],
			["ride_ghost", "ghost_train", "Geisterbahn fahren"], ["ride_coaster", "coaster", "Achterbahn fahren"],
			["bumper", "bumper_cars", "Autoscooter fahren"]]:
		_spot(world, s[r[1]], 2.6, r[0], r[2])
	for id: String in ["cans", "ducks", "rings", "darts", "moles", "wheel"]:
		_spot(world, world.fair.booths[id]["pos"], 1.8, "booth_" + id, (minigames["booth_" + id] as Minigame).title)
	_spot(world, s["high_striker"], 1.8, "booth_striker", (minigames["booth_striker"] as Minigame).title)
	_fair_counters(world)
	# The three machines at the back of the arcade hall.
	var hall := FairLayout.place("arcade")
	var k := 0
	for id: String in ["arcade_snake", "arcade_astro", "arcade_bricks"]:
		var m: ArcadeGame = minigames[id]
		var x := hall.x - 3.0 + k * 3.0
		m.cabinet = Vector3(x, world.map.walk_height(x, hall.y - 5.7), hall.y - 5.7)
		_spot(world, m.cabinet, 1.2, id, "%s spielen" % m.title)
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
		if m.host_id == npc.actor_id:
			out.append_array(m.host_options(player, npc))
	return out


## The player got into a car: a driving job ordered at its host starts (DriveJob.order_for).
static func vehicle_entered(a: Actor, _car: Car) -> void:
	if any_active():
		return
	for m: Minigame in minigames.values():
		if m is DriveJob and (m as DriveJob).order_for == a and m.can_start(a):
			m.try_start(a)
			return


static func _minigame_tasks() -> Array:
	var out := []
	for id: String in minigames:
		var m: Minigame = minigames[id]
		out.append({"title": "%s: %s" % ["Fahrgeschäft" if m is Ride else "Minispiel", m.title], "desc": m.describe(), "done": m.goal_done(),
			"area": area_of_game(id)})
	out.append_array(FairPass.tasks())
	return out


## The notebook's area of a minigame: "park", "forest", "city", "fair" or "burg".
static func area_of_game(id: String) -> String:
	if id in ["axes", "chopping", "switch"]:
		return "forest"
	if CityLayout.GAME_SPOTS.has(id) or id == "cinema":
		return "city"
	if id.begins_with("burg_"):
		return "burg"
	if id.begins_with("ride_") or id.begins_with("booth_") or id.begins_with("arcade_") or id in ["bumper", "almond_shift"]:
		return "fair"
	return "park"


## Interactables at the game locations (alternative to talking to the host).
static func _game_spots(world: World) -> void:
	var c := MinigolfGame.area_center()
	_spot(world, Vector3(c.x - 14.5, 0, c.y), 3.0, "minigolf", "Minigolf spielen")
	_spot(world, world.giant_board + Vector3(0, 0, 3.0), 3.0, "ttt", "Tic-Tac-Toe gegen Boris")
	var t: Dictionary = world.shell_table
	_spot(world, t["pos"] + Vector3(sin(t["yaw"]), 0, cos(t["yaw"])) * 0.9, 1.8, "shell", "Hütchenspiel")
	var b: Vector2 = ParkLayout.AREAS["boule"]["pos"]
	_spot(world, Vector3(b.x - 8.0, 0, b.y), 3.0, "boule", "Boule mit Monsieur Jacques")
	var pier: Vector2 = ParkLayout.PIER["to"]
	_spot(world, Vector3(pier.x, 0, pier.y + 1.5), 2.5, "ducks", "Futterchaos mit Oma Gertrud")
	_spot(world, world.bottle_machine + Vector3(1.5, 0, 0), 2.2, "bottles", "Pfandjagd starten")
	for id: String in ParkLayout.GAME_SPOTS:
		var s: Array = ParkLayout.GAME_SPOTS[id]
		_spot(world, Vector3(s[0].x, 0, s[0].y), s[1], id, s[2])
	# Playground.
	var sw: Vector2 = Playground.SWINGS[SwingGame.SWING_SET] + Vector2(0, -2.7)
	_spot(world, Vector3(sw.x, 0, sw.y), 1.2, "swing_duel", "Schaukel-Duell mit Finja")
	var tr := Playground.TRAMPOLINE + Vector2(2.4, 0)
	_spot(world, Vector3(tr.x, 0, tr.y), 1.2, "trampoline", "Trampolin mit Robin")
	var sb := Playground.SANDBOX + Vector2(0, Playground.SANDBOX_SIZE.y * 0.5 + 0.9)
	_spot(world, Vector3(sb.x, 0, sb.y), 1.4, "sanddig", "Schatzsuche mit Mika")


## A start spot for a minigame (the prompt gets the price). from_car: used from a car (the car
## must suit the game).
static func _spot(world: World, pos: Vector3, r: float, game_id: String, prompt: String, from_car := false) -> void:
	var m: Minigame = minigames[game_id]
	var text := "%s (%s)" % [prompt, GameState.format_money(m.cost)] if m.cost > 0 else prompt
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
		var why := m.blocked_text(a)
		return "%s (%s)" % [text, why] if why != "" else text
	s.available_fn = func(a: Actor) -> bool: return m.blocked_text(a) == "" and not any_active() and m.can_start(a)
	s.action_fn = func(a: Actor) -> void: m.try_start(a)
	if m is DriveJob and from_car:
		# A driving job goes with its vehicle: it starts wherever the player sits in one.
		s.background = true
		s.anchor_fn = func() -> Vector3:
			var c := (m as DriveJob).player_car()
			return c.global_position if c else s.global_position
	world.add_child(s)
	game_spots[game_id] = s.position
	m.start_pos = s.position

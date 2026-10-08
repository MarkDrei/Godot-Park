class_name DevOptions
extends RefCounted
## Startup options for testing and screenshots. Read from the command line
## (after "--") or, on the web, from the URL query (?time=14&season=1&cam=...).
##   time=H  season=0..3  weather=0..5  control=<actor id>  cam=x,y,z,tx,ty,tz
##   quality=low|medium|high  autotest=1 (prints a status line, used by tests)
##   seed=N (reproducible randomness)  save=<name> (own, fresh save file for test runs)
##   scenario=<file>[:<test>] (runs tests/scenarios/<file>.gd, see doc/test-scenarios.md)

var time := -1.0
var season := -1
var weather := -1
var control := ""
var cam := PackedFloat32Array()
var quality := ""
var autotest := false
var freeze_time := false
var smoke := false
var minigame := ""
var ui := ""
var lineup := ""
var stats := false
var speed := 1.0
var sit := false
var press := ""
var touch := false
var rng_seed := -1
var save := ""
var scenario := ""


static func parse() -> DevOptions:
	var d := DevOptions.new()
	var pairs := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.substr(2).split("=", true, 1)
			pairs[kv[0]] = kv[1]
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if q is String and q.length() > 1:
			for part in (q as String).substr(1).split("&"):
				var kv := part.split("=", true, 1)
				if kv.size() == 2:
					pairs[kv[0]] = kv[1].uri_decode()
	d.time = float(pairs.get("time", "-1"))
	d.season = int(pairs.get("season", "-1"))
	d.weather = int(pairs.get("weather", "-1"))
	d.control = pairs.get("control", "")
	d.quality = pairs.get("quality", "")
	d.autotest = pairs.get("autotest", "0") == "1"
	d.freeze_time = pairs.get("freeze", "0") == "1"
	d.smoke = pairs.get("smoke", "0") == "1"
	d.minigame = pairs.get("minigame", "")
	d.ui = pairs.get("ui", "")
	d.lineup = pairs.get("lineup", "")
	d.stats = pairs.get("stats", "0") == "1"
	d.speed = float(pairs.get("speed", "1"))
	d.sit = pairs.get("sit", "0") == "1"
	d.press = pairs.get("press", "")
	d.touch = pairs.get("touch", "0") == "1"
	d.rng_seed = int(pairs.get("seed", "-1"))
	d.scenario = pairs.get("scenario", "")
	d.save = pairs.get("save", "scenario_" + d.scenario.replace(":", "_") if d.scenario != "" else "")
	if pairs.has("cam"):
		for v in (pairs["cam"] as String).split(","):
			d.cam.append(float(v))
	return d


## Before anything is loaded: separate save file for test runs (deleted, so every run starts fresh).
func apply_save() -> void:
	if save != "":
		GameState.save_path = "user://save_%s.json" % save
		GameState.delete_save()


## Fixed seeds for the global RNG and the RNGs created before the options were read.
func apply_seed(world: World) -> void:
	if rng_seed < 0:
		return
	seed(rng_seed)
	Clock._rng.seed = rng_seed + 1
	world.rng.seed = rng_seed + 2


func apply_world(game: Node) -> void:
	if season >= 0:
		Clock.season_locked = true
		Clock.day = season * Clock.DAYS_PER_SEASON + 1
		Clock.set_season(season)
	if time >= 0.0:
		Clock.set_time(time)
	if weather >= 0:
		Clock.set_weather(weather, 100000.0)
	if freeze_time:
		Clock.running = false
	if quality != "":
		GameState.settings["quality"] = quality


func after_start(game: Node) -> void:
	if cam.size() == 6:
		var pos := Vector3(cam[0], cam[1], cam[2])
		var tgt := Vector3(cam[3], cam[4], cam[5])
		game.title_mode = false
		UI.hide_title()
		game.camera.set_override(Transform3D(Basis(), pos).looking_at(tgt, Vector3.UP))
		game.camera._override_blend = 1.0
		if game.camera.target == null:
			game.camera.target = game.world.actors[0]
	if minigame != "" and Gameplay.minigames.has(minigame):
		var m: Minigame = Gameplay.minigames[minigame]
		var h := m.host()
		if h:
			h.inside = false
			h.visible = true
		await game.get_tree().create_timer(1.0).timeout
		m.start(game.player.actor)
	if touch:
		Controls.set_touch_mode(true)
	if sit and game.player.actor:
		# Tired player on the nearest bench (shows fatigue recovering in the HUD).
		var a: Actor = game.player.actor
		a.needs.fatigue = 90.0
		var seat := game.world.find_free_seat(a.global_position, a, 200.0) as Seat
		if seat:
			a.teleport(seat.approach_point())
			a.sit_on(seat)
	if press != "":
		_press_loop(game, press)
	if lineup != "":
		_lineup(game, lineup.replace(" ", ",").replace("+", ",").split(","))
	if ui == "map":
		UI.open_map()
	elif ui == "tasks":
		UI.open_tasks()
	if speed != 1.0:
		Engine.time_scale = speed
	if scenario != "" and ResourceLoader.exists("res://tests/scenario.gd"):
		var runner: Node = load("res://tests/scenario.gd").new()
		game.add_child(runner)
		runner.call("run_file", game, scenario)
	if smoke and ResourceLoader.exists("res://tests/smoke_test.gd"):
		var t: Node = load("res://tests/smoke_test.gd").new()
		game.add_child(t)
		t.call("run", game)
	if stats:
		_stats_loop(game)
		_invariants_loop(game)
	if autotest:
		await game.get_tree().create_timer(3.0).timeout
		print("AUTOTEST READY actors=%d fps=%d draw_calls=%d objects=%d primitives=%d" % [game.world.actors.size(),
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


## press=<action>@<seconds>[@<repeat seconds>]: simulated input for screenshots,
## e.g. press=interact@6@2 keeps throwing in boule.
func _press_loop(game: Node, spec: String) -> void:
	var parts := spec.split("@")
	await game.get_tree().create_timer(float(parts[1]) if parts.size() > 1 else 3.0).timeout
	while true:
		for down: bool in [true, false]:
			var ev := InputEventAction.new()
			ev.action = parts[0]
			ev.pressed = down
			Input.parse_input_event(ev)
			await game.get_tree().process_frame
		if parts.size() < 3:
			return
		await game.get_tree().create_timer(float(parts[2])).timeout


## Lines up the given actors on the food court for close-up screenshots.
func _lineup(game: Node, ids: PackedStringArray) -> void:
	var world: World = game.world
	var base := Vector3(6, 0, 47)
	var spacing := 1.1
	var i := 0
	for id in ids:
		var a := world.find_actor(id)
		if a == null:
			continue
		a.brain = null
		a.inside = false
		a.visible = true
		a.leash_dogs.clear()
		a.leash_owner = null
		var x := (i - (ids.size() - 1) * 0.5) * spacing
		a.teleport(base + Vector3(x, 0, 0))
		a.face(base + Vector3(x, 0, 5), true)
		a.anim = "idle"
		i += 1
	var y := world.map.walk_height(base.x, base.z)
	game.title_mode = false
	UI.hide_title()
	var width := ids.size() * spacing
	game.camera.set_override(Transform3D(Basis(), base + Vector3(0, y + 1.3, maxf(3.0, width * 0.85))).looking_at(base + Vector3(0, y + 0.8, 0), Vector3.UP))
	game.camera._override_blend = 1.0
	if game.camera.target == null:
		game.camera.target = world.actors[0]


## Prints what everybody is doing every few game hours (used by the long simulation test).
func _stats_loop(game: Node) -> void:
	var world: World = game.world
	var stuck := {"n": 0}
	var who := {}
	for a in world.actors:
		var actor := a
		a.path_failed.connect(func() -> void:
			stuck["n"] += 1
			var key := actor.actor_id
			if actor.brain is HumanBrain and (actor.brain as HumanBrain).current:
				key += "/" + (actor.brain as HumanBrain).current.kind
			elif actor.brain is AnimalBrain:
				key += "/" + (actor.brain as AnimalBrain).state
			who[key] = who.get(key, 0) + 1)
	var last_hour := -1
	while true:
		await game.get_tree().create_timer(5.0).timeout
		var h := int(Clock.hour())
		if h == last_hour or h % 3 != 0:
			continue
		last_hour = h
		var kinds := {}
		var in_park := 0
		var sad := 0
		var hungry := 0
		for a in world.actors:
			if a.inside:
				continue
			in_park += 1
			if a.needs.is_sad():
				sad += 1
			if a.needs.hunger > 85.0:
				hungry += 1
			var k := "?"
			if a.brain is HumanBrain:
				var b := a.brain as HumanBrain
				k = b.current.kind if b.current else "think"
			elif a.brain is AnimalBrain:
				k = a.species + ":" + (a.brain as AnimalBrain).state
			kinds[k] = kinds.get(k, 0) + 1
		var top := kinds.keys()
		top.sort_custom(func(x, y) -> bool: return kinds[x] > kinds[y])
		var parts := []
		for k in top.slice(0, 14):
			parts.append("%s=%d" % [k, kinds[k]])
		var worst := who.keys()
		worst.sort_custom(func(x, y) -> bool: return who[x] > who[y])
		var wl := []
		for k in worst.slice(0, 8):
			wl.append("%s=%d" % [k, who[k]])
		print("TEST STUCK " + ", ".join(wl))
		print("TEST STATS day %d %s in_park=%d sad=%d starving=%d stuck_total=%d | %s" % [Clock.day, Clock.time_string(),
			in_park, sad, hungry, stuck["n"], ", ".join(parts)])


## Rules that must hold at any time; checked during the simulation (stats=1).
## Prints "TEST INVARIANT <rule>: <details>" once per rule and actor; test.sh fails on it.
func _invariants_loop(game: Node) -> void:
	var world: World = game.world
	var seen := {}
	var report := func(rule: String, who: String, details: String) -> void:
		if not seen.has(rule + who):
			seen[rule + who] = true
			print("TEST INVARIANT %s: %s %s (day %d %s)" % [rule, who, details, Clock.day, Clock.time_string()])
	while true:
		await game.get_tree().create_timer(2.0).timeout
		if GameState.money < 0:
			report.call("money_negative", "", str(GameState.money))
		var occupants := {}
		for a in world.actors:
			var p := a.global_position
			if not p.is_finite():
				report.call("position_nan", a.actor_id, str(p))
				continue
			var n := a.needs
			for v: float in [n.hunger, n.fatigue, n.joy]:
				if v < 0.0 or v > 100.0 or is_nan(v):
					report.call("need_out_of_range", a.actor_id, "%.1f/%.1f/%.1f" % [n.hunger, n.fatigue, n.joy])
			if a.inside:
				continue
			if not ParkMap.in_park(Vector2(p.x, p.z), -20.0):
				report.call("outside_park", a.actor_id, "(%.0f, %.0f)" % [p.x, p.z])
			if a.is_human() and world.map.is_water(Vector2(p.x, p.z)) and p.y < ParkLayout.WATER_Y + 0.05:
				report.call("human_in_water", a.actor_id, "(%.1f, %.1f)" % [p.x, p.z])
			if a.seat:
				if a.seat.occupant != a:
					report.call("seat_mismatch", a.actor_id, "seat %s" % a.seat.owner_id)
				if occupants.has(a.seat):
					report.call("seat_shared", a.actor_id, "with %s" % occupants[a.seat])
				occupants[a.seat] = a.actor_id

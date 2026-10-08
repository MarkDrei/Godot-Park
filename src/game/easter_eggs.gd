class_name EasterEggs
extends Node
## Hidden things: garden gnomes, the wishing fountain, the duck statue and its
## quack code, Nessie in the pond at night and a UFO over the great meadow.

var game: Node
var world: World
var nessie: Node3D
var ufo: Node3D
var _nessie_t := -1.0
var _nessie_next := 120.0
var _typed := ""
var duck_hats := false
var _statue_taps: Array[float] = []
var gnome_spots := {}          # gnome id -> position

const GNOMES := ["Gustl", "Bertram", "Fridolin", "Kasimir", "Ottokar", "Waldemar", "Rumpel"]


func setup(g: Node) -> void:
	game = g
	world = g.world
	name = "EasterEggs"
	world.add_child(self)
	_place_gnomes()
	_spot(world.fountain_pos, 5.6, "any", func(a: Actor) -> String:
		return "Münze in den Brunnen werfen (0,20 €)" if a.is_human() else "Ins Wasser schauen", _wish)
	_spot(world.statue_pos, 2.6, "any", func(_a: Actor) -> String: return "Die Bronze-Ente streicheln", _pet_statue)
	# No prompt without bottles, so the "Pfandjagd starten" spot next to it gets the focus.
	var machine := _spot(world.bottle_machine, 1.8, "human", func(a: Actor) -> String:
		return "Pfandflaschen einwerfen (%d)" % a.inventory.get("empty_bottle", 0) if a.has_item("empty_bottle") else "",
		func(a: Actor) -> void: world.return_bottles(a)) as FunctionSpot
	machine.available_fn = func(a: Actor) -> bool: return a.has_item("empty_bottle")
	for b in world.info_boards:
		_spot(b, 2.0, "any", func(_a: Actor) -> String: return "Parkplan ansehen", func(_a: Actor) -> void: UI.open_map())
	_build_nessie()
	_build_ufo()


func _spot(pos: Vector3, r: float, users: String, prompt: Callable, action: Callable) -> Interactable:
	var s := FunctionSpot.new()
	s.position = pos
	s.radius = r
	s.users = users
	s.prompt_fn = prompt
	s.action_fn = action
	world.add_child(s)
	return s


# --- Gnomes --------------------------------------------------------------------------

func _gnome_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.append(world.grotto_pos + Vector3(0.9, 0, -1.3))
	var isl := ParkLayout.ISLAND_CENTER + Vector2(1.8, -1.2)
	out.append(Vector3(isl.x, 0, isl.y))
	for b in world.map.bridges:
		if b["name"] == "Steinbrücke":
			var a: Vector2 = b["a"]
			var d: Vector2 = b["dir"]
			var side := Vector2(-d.y, d.x) * (float(b["width"]) * 0.5 + 0.9)
			var p := a + d * 1.2 + side
			out.append(Vector3(p.x, 0, p.y))
	var kiosk := ParkLayout.place("kiosk")
	var back := (kiosk - ParkLayout.place("food_court")).normalized() * 2.4
	out.append(Vector3(kiosk.x + back.x + 1.2, 0, kiosk.y + back.y))
	var hill := ParkLayout.place("sled_hill")
	out.append(Vector3(hill.x - 2.2, 0, hill.y - 2.6))
	out.append(Vector3(57.0, 0, 61.0))
	out.append(Vector3(118.0, 0, -76.0))
	return out


func _place_gnomes() -> void:
	var positions := _gnome_positions()
	for i in positions.size():
		var p := positions[i]
		var c := world.nav.nearest_open(Vector2(p.x, p.z), ParkMap.Nav.ANIMAL, 3)
		if c.x >= 0 and Vector2(p.x, p.z).distance_to(ParkMap.cell_center(c)) > 1.5:
			var q := ParkMap.cell_center(c)
			p = Vector3(q.x, 0, q.y)
		p.y = world.map.walk_height(p.x, p.z)
		var mi := MeshInstance3D.new()
		mi.mesh = PropModels.gnome(i)
		mi.position = p
		mi.rotation.y = randf() * TAU
		world.add_child(mi)
		var id := "gnome_%d" % i
		var name: String = GNOMES[i]
		var found := GameState.has_in_set("gnomes", id)
		gnome_spots[id] = p
		_spot(p, 1.8, "any", func(_a: Actor) -> String:
			return "Gartenzwerg „%s“" % name if GameState.has_in_set("gnomes", id) else "Was ist das da?",
			func(a: Actor) -> void: _find_gnome(a, id, name, mi))
		if found:
			mi.scale = Vector3.ONE


func _find_gnome(a: Actor, id: String, name: String, mi: MeshInstance3D) -> void:
	var tw := create_tween()
	tw.tween_property(mi, "position:y", mi.position.y + 0.35, 0.15)
	tw.tween_property(mi, "position:y", mi.position.y, 0.2).set_trans(Tween.TRANS_BOUNCE)
	if GameState.add_to_set("gnomes", id):
		var n := GameState.stat("gnomes")
		Sound.play("success")
		GameState.toast.emit("Gartenzwerg „%s“ gefunden! (%d/7)" % [name, n], "money")
		a.emote("star")
	else:
		GameState.toast.emit("„Hoho! Mich hast du schon gefunden.“ – %s" % name, "info")


# --- Wishing fountain -------------------------------------------------------------------

func _wish(a: Actor) -> void:
	if not a.is_human():
		a.emote("happy")
		GameState.toast.emit("Im Wasser glitzern Münzen. Viele Münzen.", "info")
		return
	if not GameState.spend(20):
		return
	a.face(world.fountain_pos)
	a.play_anim("throw", 0.8)
	var target := world.fountain_pos + Vector3(randf_range(-1.5, 1.5), 0.5, randf_range(-1.5, 1.5))
	Projectile.throw_item(world, "coin", a.global_position + Vector3(0, 1.4, 0), target, 0.8, 1.6, 0.5)
	await get_tree().create_timer(1.0).timeout
	Sound.play("splash", target, -6.0)
	GameState.add_stat("wishes")
	var r := randf()
	if r < 0.22 and not Clock.is_night():
		Clock.set_weather(Clock.Weather.SUNNY)
		GameState.toast.emit("Dein Wunsch nach Sonnenschein wurde erhört!", "info")
	elif r < 0.44:
		_confetti(world.fountain_pos + Vector3(0, 3, 0))
		a.needs.cheer(20.0)
		GameState.toast.emit("Konfetti! Einfach so. Du fühlst dich großartig.", "info")
	elif r < 0.62:
		GameState.add_money(200, "Glück im Brunnen")
	elif r < 0.8:
		for p in world.actors:
			if p.species == "pigeon" and p.brain is AnimalBrain:
				p.go_to(world.fountain_pos + Vector3(randf_range(-6, 6), 0, randf_range(4, 7)))
		GameState.toast.emit("Alle Tauben des Parks kommen angetrippelt …", "info")
	else:
		GameState.toast.emit("Nichts passiert. Oder doch? Irgendwo quakt eine Ente.", "info")
		Sound.play("quack", a.global_position)


func _confetti(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 140
	p.lifetime = 2.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0, -4, 0)
	p.angular_velocity_min = -300
	p.angular_velocity_max = 300
	var m := BoxMesh.new()
	m.size = Vector3(0.08, 0.01, 0.05)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("ff4f6d"), Color("ffd34d"), Color("5ac8fa"), Color("7ed957")])
	g.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	p.color_initial_ramp = g
	p.position = pos
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(4.0).timeout.connect(p.queue_free)


# --- Duck statue & quack code --------------------------------------------------------------

func _pet_statue(a: Actor) -> void:
	a.play_anim("wave", 1.0)
	Sound.play("quack", world.statue_pos, -4.0)
	var now := Time.get_ticks_msec() / 1000.0
	_statue_taps.append(now)
	while not _statue_taps.is_empty() and now - _statue_taps[0] > 10.0:
		_statue_taps.pop_front()
	if _statue_taps.size() >= 5:
		_statue_taps.clear()
		toggle_duck_hats()
	else:
		GameState.toast.emit(["Die Bronze-Ente glänzt an der Stelle, die alle streicheln.", "Quak?", "Die Ente scheint zu lächeln.",
			"Auf der Plakette steht: „Der unbekannten Ente“."][randi() % 4], "info")


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var ch := String.chr(k.unicode).to_lower() if k.unicode > 0 else ""
	if ch == "":
		return
	_typed = (_typed + ch).right(4)
	if _typed == "quak":
		_typed = ""
		toggle_duck_hats()


func toggle_duck_hats() -> void:
	duck_hats = not duck_hats
	GameState.add_stat("quack")
	for a in world.actors:
		if a.is_human():
			var look: Dictionary = a.def["look"]
			if duck_hats:
				look["hat_before"] = look.get("hat", "")
				look["hat"] = "duck"
			else:
				look["hat"] = look.get("hat_before", "")
			a.rebuild_rig()
	Sound.play("quack")
	GameState.toast.emit("QUAK! Alle tragen jetzt Enten auf dem Kopf." if duck_hats else "Die Enten fliegen davon.", "info")


# --- Nessie --------------------------------------------------------------------------------

func _build_nessie() -> void:
	nessie = Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = PropModels.nessie()
	nessie.add_child(mi)
	nessie.visible = false
	world.add_child(nessie)


func _build_ufo() -> void:
	ufo = Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = PropModels.ufo()
	ufo.add_child(mi)
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.8
	cm.bottom_radius = 4.0
	cm.height = 24.0
	cm.cap_top = false
	cm.cap_bottom = false
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 1.0, 0.8, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.material = mat
	beam.mesh = cm
	beam.position.y = -12.0
	ufo.add_child(beam)
	ufo.visible = false
	world.add_child(ufo)


func _visible_to_player(p: Vector3, max_dist: float) -> bool:
	var pc: PlayerController = game.player
	if pc == null or pc.actor == null:
		return false
	if pc.actor.distance_to(p) > max_dist:
		return false
	var cam: Camera3D = game.camera
	if cam.is_position_behind(p):
		return false
	var sp := cam.unproject_position(p)
	var s := get_viewport().get_visible_rect().size
	return sp.x > 0 and sp.y > 0 and sp.x < s.x and sp.y < s.y


func _process(delta: float) -> void:
	var h := Clock.hour()
	# Nessie: surfaces now and then at night (or in fog).
	var nessie_time := (h >= 23.0 or h < 4.5) or Clock.weather == Clock.Weather.FOG
	if _nessie_t < 0.0:
		_nessie_next -= delta
		if _nessie_next <= 0.0 and nessie_time:
			_nessie_t = 0.0
			var a := randf() * TAU
			var c := ParkLayout.POND_CENTER + Vector2(cos(a) * 9.0, sin(a) * 5.0)
			nessie.position = Vector3(c.x, ParkLayout.WATER_Y - 2.6, c.y)
			nessie.rotation.y = randf() * TAU
			nessie.visible = true
	else:
		_nessie_t += delta
		var rise := smoothstep(0.0, 4.0, _nessie_t) * (1.0 - smoothstep(22.0, 26.0, _nessie_t))
		nessie.position.y = ParkLayout.WATER_Y - 2.6 + rise * 2.5
		nessie.position += Vector3(sin(nessie.rotation.y), 0, cos(nessie.rotation.y)) * delta * 0.6
		if rise > 0.6 and _visible_to_player(nessie.position + Vector3(0, 2, 0), 70.0) and not GameState.is_unlocked("nessie"):
			GameState.add_stat("nessie")
			GameState.toast.emit("Was war das?! Ein Ungeheuer im Ententeich!", "warn")
		if _nessie_t > 26.0:
			_nessie_t = -1.0
			_nessie_next = randf_range(120.0, 260.0)
			nessie.visible = false
	# UFO over the great meadow between 0:30-0:50 and 3:00-3:40.
	var ufo_time := (h >= 0.5 and h < 0.85) or (h >= 3.0 and h < 3.66)
	ufo.visible = ufo_time
	if ufo_time:
		var m := ParkLayout.place("great_meadow")
		var tt := Time.get_ticks_msec() / 1000.0
		ufo.position = Vector3(m.x + sin(tt * 0.3) * 6.0, 26.0 + sin(tt * 1.3) * 0.5, m.y + cos(tt * 0.23) * 4.0)
		ufo.rotation.y += delta * 1.5
		if _visible_to_player(ufo.position, 120.0) and not GameState.is_unlocked("ufo"):
			GameState.add_stat("ufo")
			GameState.toast.emit("Da oben! Ein UFO über der Großen Wiese!", "warn")

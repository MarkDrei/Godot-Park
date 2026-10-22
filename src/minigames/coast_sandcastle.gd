class_name CoastSandcastle
extends Minigame
## Sandburg bauen with Opa Fietje (doc/moewenbucht.md): a bucket of wet sand swings to and fro
## above the castle. When it is right above (the ring on the castle turns green, "JETZT!", the
## reaction included) "Stülpen!" (Aktion) turns it over: a new storey. Beside it the sand
## crumbles and the top storey falls off; far beside it nothing happens. The tide comes in (the
## bar); when it is there, the storeys count. The bucket swings faster with every storey.

const DURATION := 45.0
const SWING := 1.5               # metres either side of the castle
const HIT := 0.42                # metres from the middle that make a storey
const PERFECT := 0.1
const NEAR := 0.9                # closer than this but not a hit: the top crumbles
const LAYER := 0.32              # height of a storey
const REACT := 0.15

var castle := Vector3.ZERO
var t := 0.0
var phase := 0.0
var offset := 0.0
var storeys := 0
var perfect := 0
var state := "swing"            # swing, drop, done
var drop_t := 0.0
var bucket: Node3D
var ring: MeshInstance3D
var layers: Array[MeshInstance3D] = []
var tide: MeshInstance3D
var _gold: StandardMaterial3D
var _green: StandardMaterial3D
var _cue_t := 0.0
var pace := 1.0                 # < 1 slows the bucket (tests)


func _init() -> void:
	title = "Sandburg bauen"
	host_id = "fietje"
	cost = 0
	cue_x = 0.22   # beside the castle: the bucket swings in the middle
	cue_y = 0.42


func describe() -> String:
	return "Mit Opa Fietje eine Sandburg bauen: Eimer genau über der Burg stülpen, Stockwerk um Stockwerk, bevor die Flut kommt."


func goal_done() -> bool:
	return GameState.stat("sandcastle_best") >= 8


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.coast != null


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Eine Sandburg bauen"


func begin() -> void:
	var c := CoastLayout.place("sandcastles") + Vector2(3.0, 3.5)
	castle = Vector3(c.x, world.map.height_at(c.x, c.y), c.y)
	actor.teleport(castle + Vector3(0, 0, -1.6))
	actor.face(castle, true)
	_gold = _glow(Color("f2c230"))
	_green = _glow(Color("4ee05a"))
	storeys = 0
	perfect = 0
	t = 0.0
	phase = 0.0
	layers.clear()
	_add_layer(0)   # the base
	bucket = Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = CoastModels.bucket(0)
	mi.rotation.x = PI   # upside down, full of sand
	mi.scale = Vector3(2.2, 2.2, 2.2)
	mi.position.y = 0.5
	bucket.add_child(mi)
	world.add_child(bucket)
	ring = MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.torus(Vector3.ZERO, 0.42, 0.05, 20, 3, Color.WHITE)
	ring.mesh = kit.commit()
	ring.material_override = _gold
	world.add_child(ring)
	tide = MeshInstance3D.new()
	var tk := MeshKit.new()
	tk.use("surf")
	tk.quad_uv(Vector3(-4, 0, 0), Vector3(4, 0, 0), Vector3(4, 0, 3), Vector3(-4, 0, 3), Color.WHITE,
		Vector2(0, 1), Vector2(8, 1), Vector2(8, 0), Vector2(0, 0))
	tide.mesh = tk.commit()
	tide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(tide)
	_view()
	host_say("Nasser Sand hält! Genau drauf stülpen, mien Jung.", 3.0)
	set_info("Ist der Eimer genau über der Burg, leuchtet der Ring GRÜN: drück „Stülpen!“ (Aktion) – ein Stockwerk mehr. Daneben bröckelt das oberste ab. Bevor die Flut kommt (Balken)!")
	add_button("Stülpen!", func() -> void: drop(), 220)
	state = "swing"
	_update_score()


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.8
	return m


func _view() -> void:
	look(castle + Vector3(3.2, 2.6, -3.4), castle + Vector3(0, 0.9, 0))


func _update_score() -> void:
	set_score("Stockwerke: %d" % storeys)


func top_y() -> float:
	return castle.y + 0.25 + storeys * LAYER


func _add_layer(i: int) -> void:
	var mi := MeshInstance3D.new()
	var kit := MeshKit.new()
	var sand := Color("d9c08a").darkened((i % 2) * 0.06)
	var r := maxf(0.75 - i * 0.04, 0.35)
	if i == 0:
		kit.cylinder(Vector3.ZERO, 0.25, 0.95, 0.85, 12, sand)
	else:
		kit.cylinder(Vector3.ZERO, LAYER, r, r * 0.92, 10, sand)
		for k in 6:
			var a := TAU * k / 6.0 + i
			kit.box(Vector3(cos(a) * r * 0.8, LAYER + 0.04, sin(a) * r * 0.8), Vector3(0.12, 0.08, 0.12), sand.lightened(0.05))
	mi.mesh = kit.commit()
	mi.position = castle + Vector3(0, 0.0 if i == 0 else 0.25 + (i - 1) * LAYER, 0)
	world.add_child(mi)
	layers.append(mi)


## Where the bucket is (metres beside the castle) at swing phase `ph`.
func offset_at(ph: float) -> float:
	return SWING * sin(ph)


func speed() -> float:
	return (1.5 + storeys * 0.1) * pace


## A drop now would make a storey, and one a moment later (the reaction) still would.
func in_reach() -> bool:
	return state == "swing" and absf(offset_at(phase)) <= HIT and absf(offset_at(phase + speed() * REACT)) <= HIT


func _process(delta: float) -> void:
	if not active:
		return
	_cue_t -= delta
	t += delta
	show_power(clampf(t / DURATION, 0.0, 1.0))
	var tide_z := lerpf(castle.z + 9.0, castle.z + 0.9, clampf(t / DURATION, 0.0, 1.0))
	tide.position = Vector3(castle.x, world.map.height_at(castle.x, tide_z) + 0.06, tide_z)
	match state:
		"swing":
			phase += speed() * delta
			offset = offset_at(phase)
			bucket.position = Vector3(castle.x + offset, top_y() + 1.1, castle.z)
			ring.position = Vector3(castle.x, top_y() + 0.03, castle.z)
			var near := in_reach()
			ring.material_override = _green if near else _gold
			if _cue_t <= 0.0:
				set_cue("JETZT!" if near else "", Color("4ee05a"))
			if t >= DURATION:
				_finish()
		"drop":
			drop_t += delta
			var k := clampf(drop_t / 0.25, 0.0, 1.0)
			bucket.position.y = lerpf(top_y() + 1.1, top_y() + 0.1, k)
			if k >= 1.0:
				_land()


## "Stülpen!": the bucket goes down where it is.
func drop() -> void:
	if state != "swing" or not active:
		return
	state = "drop"
	drop_t = 0.0
	set_cue("")


func _land() -> void:
	var d := absf(offset)
	if d <= HIT:
		_add_layer(storeys + 1)
		storeys += 1
		if d <= PERFECT:
			perfect += 1
		Sound.play("pickup", castle)
		_flash("Perfekt!" if d <= PERFECT else "+1 Stockwerk!", Color("4ee05a"))
		host_say(["Schön, schön!", "Noch einen Turm!", "So wird das was!"][storeys % 3], 1.6)
	elif d <= NEAR:
		Sound.play("click", castle)
		if storeys > 0:
			var top: MeshInstance3D = layers.pop_back()
			top.queue_free()
			storeys -= 1
		_flash("Daneben – es bröckelt!", UiTheme.RED)
	else:
		_flash("Zu weit daneben", UiTheme.GOLD)
	_update_score()
	state = "swing"
	if t >= DURATION:
		_finish()


func _flash(text: String, color: Color) -> void:
	set_cue(text, color)
	_cue_t = 0.9


func _finish() -> void:
	if state == "done":
		return
	state = "done"
	set_cue("Die Flut ist da!", UiTheme.GOLD)
	GameState.set_stat_max("sandcastle_best", storeys)
	var won := storeys >= 6
	end_after(1.5, {"won": won, "money": 0, "joy": 12.0 + storeys * 1.5,
		"text": "%d Stockwerke, dann kam die Flut.\n\nOpa Fietje: „%s“" % [storeys, "Donnerwetter! So hoch hab ich das seit achtundsiebzig nicht gesehen!" if storeys >= 8
			else ("Eine stattliche Burg!" if won else "Nächstes Mal wird sie höher.")]})


func cleanup() -> void:
	set_cue("")
	for n: Node in [bucket, ring, tide]:
		if is_instance_valid(n):
			n.queue_free()
	for l in layers:
		if is_instance_valid(l):
			l.queue_free()
	layers.clear()


func game_input(event: InputEvent) -> void:
	if primary_pressed(event):
		drop()

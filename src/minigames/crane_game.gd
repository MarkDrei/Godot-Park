class_name CraneGame
extends Minigame
## The scrapyard crane with Schrott-Siggi: move the magnet (keys or the buttons), grab a wreck
## and stack it on the press platform. A wreck that lands too far off the stack tumbles down.
## Ninety seconds; every wreck on the stack counts.

const TIME := 90.0
const STACK := Vector2(317.0, -191.0)
const PILE := Rect2(320, -215, 13, 10)
const AREA := Rect2(312, -218, 24, 32)
const HOVER := 4.2
const SPEED := 5.0
const ALIGN := 0.9                 # metres a wreck may be off the stack and still stay

var rng := RandomNumberGenerator.new()
var magnet: MeshInstance3D
var rope: MeshInstance3D
var pad: MeshInstance3D
var wrecks: Array[Dictionary] = []   # {node, pos (Vector2), y, stacked}
var held := {}
var height := 0                      # wrecks on the stack
var pos := Vector2(324, -198)
var y := HOVER
var time := 0.0
var state := "move"                  # move, down, up
var dir := Vector2.ZERO              # from the hold buttons


func _init() -> void:
	title = "Schrottkran"
	host_id = "siggi"
	rng.randomize()


func describe() -> String:
	return "Am Kran auf Schrott-Siggis Schrottplatz: Autowracks mit dem Magneten greifen und auf der Presse stapeln – 90 Sekunden."


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and a.vehicle == null


func begin() -> void:
	time = 0.0
	height = 0
	held = {}
	state = "move"
	pos = Vector2(324, -198)
	y = HOVER
	dir = Vector2.ZERO
	magnet = MeshInstance3D.new()
	magnet.mesh = CityModels.magnet()
	world.add_child(magnet)
	rope = MeshInstance3D.new()
	rope.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("2a2a2a")
	rope.material_override = mat
	world.add_child(rope)
	pad = MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.box(Vector3(0, 0.1, 0), Vector3(4.6, 0.2, 2.4), Color("8a8f96"))
	kit.use("glow")
	kit.box(Vector3(0, 0.21, 0), Vector3(1.8, 0.02, 1.8), Color("ffd84a"))
	pad.mesh = kit.commit()
	pad.position = Vector3(STACK.x, 0.0, STACK.y)
	world.add_child(pad)
	var cols := [Color("8a3b2b"), Color("2a4a8a"), Color("5a6a4a"), Color("7a7a7e"), Color("a87a3a"), Color("6a2a5a")]
	wrecks.clear()
	for i in 8:
		var p := PILE.position + Vector2((i % 4) * 3.2 + 1.5, (i / 4) * 5.0 + 2.5)
		var mi := MeshInstance3D.new()
		mi.mesh = CityModels.wreck(cols[i % cols.size()], i + 10)
		mi.position = Vector3(p.x, 0.02, p.y)
		mi.rotation.y = PI / 2 + rng.randf_range(-0.2, 0.2)
		world.add_child(mi)
		wrecks.append({"node": mi, "pos": p, "y": 0.02, "stacked": false})
	look(Vector3(306.0, 15.0, -176.0), Vector3(324.0, 0.5, -203.0))
	host_say("Greifen, heben, stapeln. Und nichts kaputt machen – also, mehr als schon ist.", 3.5)
	for b: Array in [["Links", Vector2(-1, 0)], ["Vor", Vector2(0, -1)], ["Zurück", Vector2(0, 1)], ["Rechts", Vector2(1, 0)]]:
		var d: Vector2 = b[1]
		var btn := add_button(b[0], func() -> void: pass, 110)
		btn.button_down.connect(func() -> void: dir += d)
		btn.button_up.connect(func() -> void: dir -= d)
	add_button("Greifen", func() -> void: grab(), 150)
	set_info("Bewegen: W/A/S/D oder die Knöpfe · Greifen und Loslassen: Aktion oder „Greifen“.")


func _process(delta: float) -> void:
	if not active:
		return
	time += delta
	var move := dir
	if game.player:
		move += Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	match state:
		"move":
			pos += move.limit_length(1.0) * SPEED * delta
			pos.x = clampf(pos.x, AREA.position.x, AREA.end.x)
			pos.y = clampf(pos.y, AREA.position.y, AREA.end.y)
			y = move_toward(y, HOVER, delta * 3.0)
		"down":
			var target := _grab_height()
			y = move_toward(y, target, delta * 6.0)
			if absf(y - target) < 0.05:
				_pick()
				state = "up"
		"up":
			y = move_toward(y, HOVER, delta * 5.0)
			if absf(y - HOVER) < 0.05:
				state = "move"
	magnet.position = Vector3(pos.x, y, pos.y)
	if not held.is_empty():
		var n: MeshInstance3D = held["node"]
		n.position = Vector3(pos.x, y - 1.15, pos.y)
	_draw_rope()
	set_score("Stapel %d · %d s" % [height, maxi(0, int(TIME - time))])
	if time >= TIME and state != "done":
		_finish()


func _draw_rope() -> void:
	var im := rope.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(Vector3(pos.x, 12.6, pos.y))
	im.surface_add_vertex(Vector3(pos.x, y + 0.3, pos.y))
	im.surface_end()


## The free wreck under the magnet (not on the stack), or {}.
func wreck_below() -> Dictionary:
	var best := {}
	var best_d := 1.8
	for w: Dictionary in wrecks:
		if w["stacked"] or w == held:
			continue
		var d := (w["pos"] as Vector2).distance_to(pos)
		if d < best_d:
			best_d = d
			best = w
	return best


func _grab_height() -> float:
	var w := wreck_below()
	return float(w["y"]) + 1.15 if not w.is_empty() else 1.2


## Action: lower and grab, or let go.
func grab() -> void:
	if not active or state != "move":
		return
	if held.is_empty():
		state = "down"
		Sound.play("click", magnet.global_position)
	else:
		_drop()


func _pick() -> void:
	var w := wreck_below()
	if w.is_empty():
		host_say("Da ist nichts!", 1.5)
		return
	held = w
	Sound.play("hit", magnet.global_position)


func _drop() -> void:
	var w := held
	held = {}
	var off := pos.distance_to(STACK)
	if off < 3.0:
		if off <= ALIGN:
			w["stacked"] = true
			w["pos"] = pos
			w["y"] = 0.22 + height * 0.92
			height += 1
			Sound.play("hit", magnet.global_position)
			host_say(["Sitzt!", "Saubere Arbeit!", "Noch einer!"][height % 3], 1.5)
		else:
			# Too far off: it tumbles down beside the stack.
			w["pos"] = STACK + (pos - STACK).normalized() * 3.2
			w["y"] = 0.02
			host_say("Daneben! Der ist runtergefallen.", 1.8)
			Sound.play("fail", magnet.global_position, -6.0)
	else:
		w["pos"] = pos
		w["y"] = 0.02
	var n: MeshInstance3D = w["node"]
	n.position = Vector3((w["pos"] as Vector2).x, w["y"], (w["pos"] as Vector2).y)


func _finish() -> void:
	state = "done"
	GameState.set_stat_max("crane_best", height)
	end_after(0.8, {"won": height >= 5, "money": height * 100, "joy": 10.0 + height * 2.0,
		"text": "%d Wracks gestapelt! %s" % [height, "Siggi: „Du kannst bei mir anfangen!“" if height >= 5 else "Siggi: „Na, das Stapeln üben wir noch.“"]})


func game_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_SPACE):
		grab()


func cleanup() -> void:
	for w: Dictionary in wrecks:
		if is_instance_valid(w["node"]):
			(w["node"] as Node).queue_free()
	wrecks.clear()
	held = {}
	for n: Node in [magnet, rope, pad]:
		if is_instance_valid(n):
			n.queue_free()
	magnet = null
	rope = null
	pad = null
	dir = Vector2.ZERO

class_name PhotoGame
extends Minigame
## Take a holiday photo of Peggy in front of a landmark. Frame her and the
## landmark, and press the shutter while she smiles. Three shots, best counts.

var tourist: Actor
var landmark := {}
var eye := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var fov := 55.0
var smile := false
var smile_t := 0.0
var shots := 0
var best := 0
var t := 0.0
var frame: Control
var smile_label: Label
var photo_rect: TextureRect
var _busy := false


func _init() -> void:
	title = "Foto für Peggy"
	host_id = "peggy"


func describe() -> String:
	return "Touristin Peggy möchte ein Urlaubsfoto vor einer Sehenswürdigkeit. Sie mit aufs Bild – und warte, bis sie lächelt!"


func begin() -> void:
	tourist = host()
	shots = 0
	best = 0
	_busy = false
	var options := []
	for l in world.landmarks:
		if l["id"] in ["pavilion", "fountain", "statue", "donut", "pier"] or (l["id"] as String).begins_with("bridge_Stein"):
			options.append(l)
	landmark = options[randi() % options.size()]
	var focus: Vector3 = landmark["pos"]
	# Peggy stands a few metres in front of the landmark, the player further out.
	var dir := Vector3(1, 0, 0)
	for i in 16:
		var a := TAU * i / 16.0 + randf() * 0.2
		var d := Vector3(cos(a), 0, sin(a))
		var pp := focus + d * 5.5
		var cp := focus + d * 11.0
		if not world.map.is_solid(Vector2(pp.x, pp.z)) and not world.map.is_solid(Vector2(cp.x, cp.z)):
			dir = d
			break
	var peggy_pos := focus + dir * 5.5
	tourist.teleport(peggy_pos)
	tourist.face(peggy_pos + dir, true)
	tourist.set_item("")
	actor.teleport(focus + dir * 11.0)
	actor.face(peggy_pos, true)
	eye = actor.global_position + Vector3(0, actor.rig.height - 0.12, 0)
	var to := (focus + Vector3(0, -0.5, 0)) - eye
	yaw = atan2(to.x, to.z) + randf_range(-0.25, 0.25)
	pitch = 0.0
	fov = 60.0
	actor.set_item("camera")
	actor.anim = "photo"
	actor.rig.visible = false
	tourist.say("Mach ein Foto von mir vor dem Ort „%s“!" % landmark["name"], 4.0)
	_build_frame()
	set_info("Zielen: WASD/Pfeile oder Ziehen · Zoom: Mausrad oder +/- · Aktion/Klick: auslösen")
	add_button("-", func() -> void: fov = clampf(fov + 6.0, 25.0, 75.0), 80)
	add_button("Auslösen!", func() -> void: _shoot(), 200)
	add_button("+", func() -> void: fov = clampf(fov - 6.0, 25.0, 75.0), 80)
	_update()


func _build_frame() -> void:
	frame = Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func() -> void:
		var s := frame.size
		var m := Vector2(s.x * 0.08, s.y * 0.1)
		var col := Color(1, 1, 1, 0.85)
		var l := 40.0
		for c: Vector2 in [m, Vector2(s.x - m.x, m.y), Vector2(m.x, s.y - m.y), s - m]:
			var sx := 1.0 if c.x < s.x * 0.5 else -1.0
			var sy := 1.0 if c.y < s.y * 0.5 else -1.0
			frame.draw_line(c, c + Vector2(l * sx, 0), col, 3.0)
			frame.draw_line(c, c + Vector2(0, l * sy), col, 3.0)
		frame.draw_circle(s * 0.5, 4.0, col)
		frame.draw_arc(s * 0.5, 18.0, 0, TAU, 24, col, 1.5))
	hud.add_child(frame)
	hud.move_child(frame, 0)
	smile_label = UiTheme.label("", 30, UiTheme.GOLD)
	smile_label.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	smile_label.position = Vector2(40, 60)
	hud.add_child(smile_label)


func _update() -> void:
	set_score("Foto %d/3  ·  Bestes Foto: %d Punkte" % [mini(shots + 1, 3), best])


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	var turn := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	yaw -= turn.x * delta * 0.8
	pitch = clampf(pitch - turn.y * delta * 0.6, -0.6, 0.6)
	var basis := Basis(Vector3.UP, yaw + PI) * Basis(Vector3.RIGHT, pitch)
	game.camera.set_override(Transform3D(basis, eye))
	game.camera._override_blend = 1.0
	game.camera.fov = lerpf(game.camera.fov, fov, clampf(delta * 8.0, 0.0, 1.0))
	actor.yaw = yaw
	actor.rotation.y = yaw
	# Peggy's smile comes and goes.
	smile_t -= delta
	if smile_t <= 0.0:
		smile = not smile
		smile_t = randf_range(1.0, 1.6) if smile else randf_range(1.5, 3.5)
		if smile:
			tourist.say("Cheese!", 1.0)
			tourist.play_anim("cheer", smile_t)
		else:
			tourist.play_anim(["idle", "wave", "talk"][randi() % 3], smile_t)
	(tourist.rig as HumanRig).set_mood(90.0 if smile else 35.0)
	smile_label.text = "Peggy lächelt!" if smile else ""


func _in_frame(p: Vector3, margin := 0.08) -> bool:
	var cam: Camera3D = game.camera
	if cam.is_position_behind(p):
		return false
	var sp := cam.unproject_position(p)
	var s := get_viewport().get_visible_rect().size
	return sp.x > s.x * margin and sp.x < s.x * (1.0 - margin) and sp.y > s.y * margin and sp.y < s.y * (1.0 - margin)


func _shoot() -> void:
	if _busy or shots >= 3:
		return
	_busy = true
	var cam: Camera3D = game.camera
	var head := tourist.global_position + Vector3(0, tourist.rig.height, 0)
	var feet := tourist.global_position + Vector3(0, 0.1, 0)
	var score := 0
	var notes: Array[String] = []
	if _in_frame(head) and _in_frame(feet):
		score += 40
		var h := absf(cam.unproject_position(feet).y - cam.unproject_position(head).y) / get_viewport().get_visible_rect().size.y
		if h > 0.22 and h < 0.85:
			score += 20
		else:
			notes.append("Peggy ist zu %s." % ("klein" if h <= 0.22 else "groß"))
	elif _in_frame(head) or _in_frame(feet):
		score += 15
		notes.append("Peggy ist abgeschnitten!")
	else:
		notes.append("Peggy ist gar nicht drauf!")
	if _in_frame(landmark["pos"], 0.04):
		score += 30
	else:
		notes.append("Der Ort „%s“ fehlt." % landmark["name"])
	if smile:
		score += 10
	else:
		score = maxi(0, score - 20)
		notes.append("Peggy hat nicht gelächelt.")
	shots += 1
	best = maxi(best, score)
	Sound.play("click")
	# Flash and polaroid.
	var img: Image
	if DisplayServer.get_name() == "headless":
		# No rendering in headless test runs (frame_post_draw never comes): blank polaroid.
		img = Image.create(64, 36, false, Image.FORMAT_RGB8)
	else:
		await RenderingServer.frame_post_draw
		img = get_viewport().get_texture().get_image()
	_show_photo(img, score, notes)
	_update()
	var s := session
	await get_tree().create_timer(2.6).timeout
	if not still_running(s):
		return
	if photo_rect:
		photo_rect.get_parent().queue_free()
		photo_rect = null
	_busy = false
	if shots >= 3 or score >= 90:
		_finish()


func _show_photo(img: Image, score: int, notes: Array[String]) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel(Color("f6f2e8"), 6))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.rotation = deg_to_rad(randf_range(-4, 4))
	var v := VBoxContainer.new()
	p.add_child(v)
	img.resize(384, 216)
	photo_rect = TextureRect.new()
	photo_rect.texture = ImageTexture.create_from_image(img)
	photo_rect.custom_minimum_size = Vector2(384, 216)
	v.add_child(photo_rect)
	var verdict := "Perfekt!" if score >= 90 else ("Schön!" if score >= 60 else ("Geht so." if score >= 30 else "Hm …"))
	var l := UiTheme.label("%s  %d Punkte" % [verdict, score], 20, Color("1f3a2e"))
	v.add_child(l)
	if not notes.is_empty():
		var n := UiTheme.label(" ".join(notes), 15, Color("6a3a20"))
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.custom_minimum_size = Vector2(384, 0)
		v.add_child(n)
	hud.add_child(p)
	await get_tree().process_frame
	if is_instance_valid(p):
		p.position = (hud.size - p.size) * 0.5


func _finish() -> void:
	var text := "Peggy schaut sich die Fotos an. Bestes Foto: %d Punkte." % best
	var money := 100
	if best >= 90:
		GameState.add_stat("perfect_photos")
		text += "\n„Oh my God, das ist PERFEKT! Das kommt an meinen Kühlschrank!“"
		money = 300
	elif best >= 60:
		text += "\n„Wonderful, danke schön!“"
		money = 200
	else:
		text += "\n„Naja … danke trotzdem.“"
	end({"won": best >= 60, "money": money, "joy": 20.0, "text": text})


func game_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_shoot()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			fov = clampf(fov - 3.0, 25.0, 75.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			fov = clampf(fov + 3.0, 25.0, 75.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not UI.point_blocked(mb.position) and not Controls.touch_mode:
			_shoot()
	elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_RIGHT):
		yaw -= (event as InputEventMouseMotion).relative.x * 0.004
		pitch = clampf(pitch - (event as InputEventMouseMotion).relative.y * 0.004, -0.6, 0.6)
	elif event is InputEventScreenDrag:
		yaw -= (event as InputEventScreenDrag).relative.x * 0.005
		pitch = clampf(pitch - (event as InputEventScreenDrag).relative.y * 0.005, -0.6, 0.6)
	elif event is InputEventKey and event.pressed:
		if (event as InputEventKey).keycode in [KEY_PLUS, KEY_KP_ADD, KEY_EQUAL]:
			fov = clampf(fov - 6.0, 25.0, 75.0)
		elif (event as InputEventKey).keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			fov = clampf(fov + 6.0, 25.0, 75.0)


func cleanup() -> void:
	actor.rig.visible = true
	actor.set_item("")
	actor.anim = "idle"
	game.camera.fov = 62.0
	if tourist:
		tourist.look_target = Vector3.INF

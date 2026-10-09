class_name ChopGame
extends Minigame
## Wood chopping duel against Holzfäller Holger: 30 seconds at the chopping block. A marker
## swings over a bar; Action while it is in the green zone splits the log. A miss costs
## a moment. Whoever splits more logs wins; you keep some of the firewood.

const DURATION := 30.0
const ZONE := Vector2(0.38, 0.62)    # green part of the bar (0..1)
const HOLGER_EVERY := 2.0            # seconds per log for Holger

var block := Vector3.ZERO
var holger_block := Vector3.ZERO
var time_left := DURATION
var splits := 0
var holger_splits := 0
var marker := 0.0
var t := 0.0
var lockout := 0.0
var _holger_t := 0.0
var state := "play"
var bar: Control
var props: Array[Node3D] = []
var log_node: MeshInstance3D
var holger_log: MeshInstance3D


func _init() -> void:
	title = "Holzhacken gegen Holger"
	host_id = "holger"


func describe() -> String:
	return "30 Sekunden Holzhacken im Holzfällerlager: Spalte mehr Scheite als Holger!"


func begin() -> void:
	var b := Vector2(-31, -158)
	block = Vector3(b.x, world.map.height_at(b.x, b.y), b.y)
	holger_block = block + Vector3(3.2, 0, 0)
	holger_block.y = world.map.height_at(holger_block.x, holger_block.z)
	actor.teleport(block + Vector3(0, 0, 1.1))
	actor.face(block, true)
	actor.set_item("axe")
	var hb := MeshInstance3D.new()
	hb.mesh = ForestModels.chopping_block()
	hb.position = holger_block
	add_child(hb)
	props.append(hb)
	log_node = _log_at(block)
	holger_log = _log_at(holger_block)
	var h := host()
	if h:
		h.teleport(holger_block + Vector3(0, 0, 1.1))
		h.face(holger_block, true)
		h.set_item("axe")
		host_say("Wer mehr Scheite schafft, gewinnt. Los!", 3.0)
	look(block + Vector3(1.6, 2.4, 4.6), block + Vector3(1.6, 0.6, 0))
	time_left = DURATION
	splits = 0
	holger_splits = 0
	_holger_t = HOLGER_EVERY
	state = "play"
	lockout = 0.0
	_build_bar()
	set_info("Drück Aktion, Leertaste oder „Hacken!“, wenn der Strich im grünen Feld ist.")
	add_button("Hacken!", func() -> void: chop(), 220)
	_update_score()


func _log_at(p: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.cylinder(Vector3.ZERO, 0.5, 0.2, 0.2, 8, ForestModels.LOG, true, ForestModels.LOG_END)
	mi.mesh = kit.commit()
	mi.position = p + Vector3(0, 0.55, 0)
	add_child(mi)
	props.append(mi)
	return mi


func _build_bar() -> void:
	bar = Control.new()
	bar.custom_minimum_size = Vector2(420, 34)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var w := bar.size.x
		var h := bar.size.y
		bar.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.45))
		bar.draw_rect(Rect2(w * ZONE.x, 0, w * (ZONE.y - ZONE.x), h), Color(UiTheme.GREEN, 0.85))
		bar.draw_rect(Rect2(w * marker - 3, -4, 6, h + 8), UiTheme.CREAM))
	_power.get_parent().add_child(bar)


func _update_score() -> void:
	set_score("Du: %d  ·  Holger: %d  ·  noch %d s" % [splits, holger_splits, int(ceil(time_left))])


func _process(delta: float) -> void:
	if not active or state != "play":
		return
	t += delta
	time_left -= delta
	lockout = maxf(0.0, lockout - delta)
	marker = pingpong(t, 0.9 + splits * 0.02)
	if bar:
		bar.queue_redraw()
	_holger_t -= delta
	if _holger_t <= 0.0:
		_holger_t = HOLGER_EVERY * randf_range(0.85, 1.15)
		holger_splits += 1
		var h := host()
		if h:
			h.play_anim("chop", 0.6)
		_split_fx(holger_log)
	if time_left <= 0.0:
		_finish()
	_update_score()


func in_zone() -> bool:
	return marker >= ZONE.x and marker <= ZONE.y


func chop() -> void:
	if not active or state != "play" or lockout > 0.0:
		return
	actor.play_anim("chop", 0.6)
	if in_zone():
		splits += 1
		Sound.play("hit", block)
		_split_fx(log_node)
	else:
		lockout = 0.6
		Sound.play("click", block)
		set_info("Daneben! Kurz durchatmen …")
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if active:
				set_info("Drück Aktion, Leertaste oder „Hacken!“, wenn der Strich im grünen Feld ist."))
	_update_score()


## The log jumps apart for a moment, then a new one stands on the block.
func _split_fx(n: MeshInstance3D) -> void:
	if not is_instance_valid(n):
		return
	var base := n.position
	n.scale = Vector3(1.6, 0.4, 1.6)
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.scale = Vector3.ONE
			n.position = base)


func _finish() -> void:
	state = "done"
	GameState.set_stat_max("chop_best", splits)
	var won := splits > holger_splits
	if won:
		GameState.add_stat("chop_wins")
	var logs := splits / 4
	if logs > 0:
		actor.add_item("log", logs)
	host_say("Respekt!" if won else "Ha! Der Wald gehört mir!", 2.5)
	end_after(1.6, {"won": won, "money": 300 if won else 0, "joy": 22.0 if won else 10.0,
		"text": "Du: %d Scheite, Holger: %d. %s%s" % [splits, holger_splits, "Gewonnen – 3 € Siegprämie!" if won else "Holger war schneller.",
			" Du darfst %d Holzscheite mitnehmen." % logs if logs > 0 else ""]})


func game_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_SPACE):
		chop()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if not UI.point_blocked((event as InputEventMouseButton).position):
			chop()


func cleanup() -> void:
	for n in props:
		if is_instance_valid(n):
			n.queue_free()
	props.clear()
	if is_instance_valid(bar):
		bar.queue_free()
	if actor:
		actor.set_item("")
	var h := host()
	if h:
		h.set_item("")

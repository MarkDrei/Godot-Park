class_name TouchControls
extends Control
## Virtual joystick (left) and action buttons (right) for phones and tablets.

var game: Node
var _stick_index := -1
var _stick_center := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _base: Control
var _knob: Control
var _run_button: Button
var _run := false
const RADIUS := 80.0
## Width the round buttons take at the right edge (margin included); other UI keeps out.
const WIDTH := 300.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build(g: Node) -> void:
	game = g
	_base = _circle(Vector2(RADIUS * 2.2, RADIUS * 2.2), Color(1, 1, 1, 0.12))
	_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_base.position = Vector2(40, -RADIUS * 2.2 - 40)
	add_child(_base)
	_knob = _circle(Vector2(RADIUS * 0.9, RADIUS * 0.9), Color(UiTheme.CREAM, 0.55))
	_base.add_child(_knob)
	_center_knob()
	# Zoom buttons (right edge, middle); pinching with two fingers works too.
	var zoom := VBoxContainer.new()
	zoom.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	zoom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	zoom.grow_vertical = Control.GROW_DIRECTION_BOTH
	zoom.position = Vector2(-30, -60)
	zoom.add_theme_constant_override("separation", 10)
	add_child(zoom)
	for z: Array in [["+", 0.8], ["-", 1.25]]:
		var b := _round(z[0], func() -> void: game.player.camera.zoom_by(z[1]))
		b.custom_minimum_size = Vector2(64, 64)
		b.add_theme_font_size_override("font_size", 28)
		zoom.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grid.grow_vertical = Control.GROW_DIRECTION_BEGIN
	grid.position = Vector2(-30, -30)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	add_child(grid)
	grid.add_child(_round("Spezial", func() -> void: game.player.special()))
	grid.add_child(_round("Wechseln", func() -> void: UI.open_switch_menu()))
	_run_button = _round("Rennen", func() -> void:
		_run = not _run
		game.player.touch_run = _run
		_run_button.modulate = Color(1, 0.8, 0.5) if _run else Color.WHITE)
	grid.add_child(_run_button)
	var act := _round("Aktion", func() -> void: game.player.interact())
	act.custom_minimum_size = Vector2(130, 130)
	act.add_theme_font_size_override("font_size", 24)
	grid.add_child(act)


func _circle(sz: Vector2, col: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = sz
	p.size = sz
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(int(sz.x))
	s.border_color = Color(1, 1, 1, 0.3)
	s.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _round(text: String, cb: Callable) -> Button:
	var b := UiTheme.button_node(text, cb, 18)
	b.custom_minimum_size = Vector2(110, 110)
	b.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed"]:
		# From UiTheme directly: the button is not in the tree yet, so the theme lookup
		# would return Godot's dark default style.
		var s := UiTheme.button(state).duplicate() as StyleBoxFlat
		s.set_corner_radius_all(60)
		s.bg_color.a = 0.82
		b.add_theme_stylebox_override(state, s)
	return b


## Hidden while a dialog or screen is open: they do nothing then and would cover it.
func _process(_delta: float) -> void:
	var free := not UI.blocks_game_input()
	if _base.visible == free:
		return
	for c in get_children():
		(c as Control).visible = free
	if not free and _stick_index >= 0:
		_stick_index = -1
		_stick_vec = Vector2.ZERO
		game.player.touch_move = Vector2.ZERO
		_center_knob()


func _center_knob() -> void:
	_knob.position = (_base.size - _knob.size) * 0.5 + _stick_vec * RADIUS


func _input(event: InputEvent) -> void:
	if not visible or game == null or game.player == null:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var base_rect := Rect2(_base.global_position - Vector2(60, 60), _base.size + Vector2(120, 120))
		if st.pressed and _stick_index < 0 and base_rect.has_point(st.position) and not UI.blocks_game_input():
			_stick_index = st.index
			_stick_center = _base.global_position + _base.size * 0.5
			_update_stick(st.position)
			get_viewport().set_input_as_handled()
		elif not st.pressed and st.index == _stick_index:
			_stick_index = -1
			_stick_vec = Vector2.ZERO
			game.player.touch_move = Vector2.ZERO
			_center_knob()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _stick_index:
			_update_stick(sd.position)
			get_viewport().set_input_as_handled()


func _update_stick(p: Vector2) -> void:
	var v := (p - _stick_center) / RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	_stick_vec = v
	game.player.touch_move = v
	_center_knob()

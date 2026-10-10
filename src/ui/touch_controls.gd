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
var _grid: GridContainer          # walking buttons
var _drive_grid: GridContainer    # driving buttons (Gas, Bremse, Hupe, Aussteigen)
var _gas: Button
var _brake: Button
var _pedals := {}                 # finger index -> "gas" / "brake"
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
	_grid = grid
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
	# While driving: pedals (held; several fingers at once, see _input) and horn / get out.
	_drive_grid = GridContainer.new()
	_drive_grid.columns = 2
	_drive_grid.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_drive_grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_drive_grid.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_drive_grid.position = Vector2(-30, -30)
	_drive_grid.add_theme_constant_override("h_separation", 14)
	_drive_grid.add_theme_constant_override("v_separation", 14)
	_drive_grid.visible = false
	add_child(_drive_grid)
	_drive_grid.add_child(_round("Hupe", func() -> void: game.player.special()))
	_drive_grid.add_child(_round("Aussteigen", func() -> void: game.player.interact()))
	_brake = _round("Bremse", func() -> void: pass)
	_drive_grid.add_child(_brake)
	_gas = _round("Gas", func() -> void: pass)
	_gas.custom_minimum_size = Vector2(130, 130)
	_gas.add_theme_font_size_override("font_size", 26)
	_drive_grid.add_child(_gas)
	for pedal: Array in [[_gas, "gas"], [_brake, "brake"]]:
		var b: Button = pedal[0]
		var which: String = pedal[1]
		b.button_down.connect(func() -> void: _set_pedal(which, true))
		b.button_up.connect(func() -> void: _set_pedal(which, false))


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


func _set_pedal(which: String, down: bool) -> void:
	if game == null or game.player == null:
		return
	if which == "gas":
		game.player.touch_gas = down
	else:
		game.player.touch_brake = down


## Hidden while a dialog or screen is open: they do nothing then and would cover it.
func _process(_delta: float) -> void:
	var driving: bool = game != null and game.player != null and game.player.actor != null and game.player.actor.vehicle != null
	if _drive_grid.visible != (driving and _base.visible):
		_drive_grid.visible = driving and _base.visible
		_grid.visible = not driving and _base.visible
		if not driving:
			_pedals.clear()
			_set_pedal("gas", false)
			_set_pedal("brake", false)
	var free := not UI.blocks_game_input()
	if _base.visible == free:
		return
	for c in get_children():
		(c as Control).visible = free
	_drive_grid.visible = free and driving
	_grid.visible = free and not driving
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
		# Pedals: held while the finger stays (steering with another finger at the same time).
		if _drive_grid.visible:
			if st.pressed:
				for pedal: Array in [[_gas, "gas"], [_brake, "brake"]]:
					if (pedal[0] as Button).get_global_rect().has_point(st.position):
						_pedals[st.index] = pedal[1]
						_set_pedal(pedal[1], true)
						get_viewport().set_input_as_handled()
						return
			elif _pedals.has(st.index):
				_set_pedal(_pedals[st.index], false)
				_pedals.erase(st.index)
				get_viewport().set_input_as_handled()
				return
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

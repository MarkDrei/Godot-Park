extends CanvasLayer
## UI coordinator (autoload "UI"): HUD, dialogs, toasts, menus, title and loading
## screens, touch controls and the minigame layer.

signal toast_shown(text: String)    # every toast, also UI-only ones (used by tests)

var game: Node
var theme: Theme
var root: Control
var hud: Hud
var touch: TouchControls
var minigame_root: Control
var map_screen: MapScreen
var bag_screen: BagScreen
var craft_screen: CraftScreen
var tasks_screen: TasksScreen

var _dialog: PanelContainer
var _dialog_cb: Callable
var _dialog_buttons: Array[Button] = []
var _toasts: VBoxContainer
var _achievement: PanelContainer
var _loading: Control
var _loading_bar: ProgressBar
var _loading_text: Label
var _title: Control
var _pause: Control
var _switch: Control
var _modal := ""
var _marker: MeshInstance3D


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.make()
	root = Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	minigame_root = Control.new()
	minigame_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	minigame_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minigame_root)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)
	root.resized.connect(_on_resized)
	GameState.toast.connect(toast)
	GameState.achievement_unlocked.connect(_on_achievement)
	Controls.touch_mode_changed.connect(func(on: bool) -> void:
		_place_toasts()
		if touch:
			touch.visible = on and hud != null and hud.visible)


# --- Game hookup -------------------------------------------------------------------

func attach_game(g: Node) -> void:
	game = g
	hud = Hud.new()
	hud.visible = false
	root.add_child(hud)
	root.move_child(hud, 0)
	hud.build(g)
	touch = TouchControls.new()
	touch.visible = false
	root.add_child(touch)
	root.move_child(touch, 1)
	touch.build(g)
	g.player.prompt_changed.connect(func(t: String) -> void: hud.set_prompt(t))


func show_hud(on: bool) -> void:
	if hud:
		hud.visible = on
	if touch:
		touch.visible = on and Controls.touch_mode
	_place_toasts()


## True while a menu/dialog is open, so the game ignores movement input.
func blocks_game_input() -> bool:
	return _modal != ""


## True if a screen position lies over an interactive UI element.
func point_blocked(p: Vector2) -> bool:
	return _hit(root, p)


func _hit(c: Control, p: Vector2) -> bool:
	if not c.visible:
		return false
	if c is BaseButton and c.get_global_rect().has_point(p):
		return true
	if c is PanelContainer and c.mouse_filter == Control.MOUSE_FILTER_STOP and c.get_global_rect().has_point(p):
		return true
	for ch in c.get_children():
		if ch is Control and _hit(ch, p):
			return true
	return false


# --- Toasts and achievements ----------------------------------------------------

## Window size changed (phone rotated, browser resized): re-centre what was placed by hand.
func _on_resized() -> void:
	if _dialog:
		_dialog.position = Vector2((root.size.x - _dialog.size.x) * 0.5, root.size.y - _dialog.size.y - 24)
	if _switch:
		_switch.position = (root.size - _switch.size) * 0.5
	_place_toasts()


## Narrower in touch mode: there they sit left of the round buttons, next to the player.
func _toast_width() -> float:
	return 240.0 if Controls.touch_mode else 300.0


## Toasts hang at the right edge below the menu buttons (in touch mode left of the
## round buttons) and never reach into an open dialog or below the screen: the
## oldest go first when space runs out.
func _place_toasts() -> void:
	var right := -14.0 - (TouchControls.WIDTH if Controls.touch_mode else 0.0)
	var top := 76.0  # below a minigame's "Beenden" button
	if hud and hud.visible:
		top = hud.menu_buttons.get_global_rect().end.y + 10.0
	# Below a running minigame's top panel (it is wide in some games).
	if minigame_root:
		for mh in minigame_root.get_children():
			for c in mh.get_children():
				if c is PanelContainer and (c as Control).visible:
					top = maxf(top, (c as Control).get_global_rect().end.y + 10.0)
	var bottom := root.size.y - 14.0
	if _dialog:
		bottom = minf(bottom, _dialog.position.y - 10.0)
	for p in _toasts.get_children():
		(p.get_child(0) as Control).custom_minimum_size.x = _toast_width()
	_toasts.reset_size()
	# remove_child first: queue_free alone keeps the child until the frame ends, so a
	# loop on the child count never ended (game froze and ate all memory).
	while _toasts.get_child_count() > 1 and (_toasts.get_child_count() > 4 or top + _toasts.size.y > bottom):
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
		_toasts.reset_size()
	_toasts.offset_top = top
	_toasts.offset_bottom = top + _toasts.size.y
	_toasts.offset_left = right - _toasts.size.x
	_toasts.offset_right = right


func toast(text: String, kind := "info") -> void:
	toast_shown.emit(text)
	var p := PanelContainer.new()
	var col: Color = {"info": UiTheme.BG, "warn": Color(0.45, 0.18, 0.12, 0.92), "money": Color(0.35, 0.3, 0.08, 0.92)}.get(kind, UiTheme.BG)
	p.add_theme_stylebox_override("panel", UiTheme.panel(col, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.label(text, 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(_toast_width(), 0)
	p.add_child(l)
	_toasts.add_child(p)
	_place_toasts()
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _on_achievement(id: String) -> void:
	var def := Achievements.get_def(id)
	Sound.play("achievement")
	if _achievement:
		_achievement.queue_free()
	_achievement = PanelContainer.new()
	_achievement.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.32, 0.25, 0.06, 0.95), 14))
	_achievement.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_achievement.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_achievement.position.y = 20
	_achievement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_achievement.add_child(v)
	var t := UiTheme.label("Erfolg freigeschaltet!", 16, UiTheme.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var n := UiTheme.label(def.get("title", id), 28, Color.WHITE)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var d := UiTheme.label(def.get("desc", ""), 16)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	if def.get("reward", 0) > 0:
		var r := UiTheme.label("+ " + GameState.format_money(def["reward"]), 18, UiTheme.GOLD)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(r)
	root.add_child(_achievement)
	await get_tree().process_frame
	if is_instance_valid(_achievement):
		_achievement.position.x = (root.size.x - _achievement.size.x) * 0.5
		_achievement.position.y = _free_top()
		var tw := create_tween()
		var node := _achievement
		tw.tween_interval(4.5)
		tw.tween_property(node, "modulate:a", 0.0, 0.8)
		tw.tween_callback(node.queue_free)


## The first free y at the top centre: below a minigame's title panel, if one is shown.
func _free_top() -> float:
	var y := 20.0
	for h in minigame_root.get_children():
		for c in h.get_children():
			if c is PanelContainer and (c as Control).visible and (c as Control).position.y < 100.0:
				y = maxf(y, (c as Control).get_global_rect().end.y + 10.0)
	return y


# --- Dialog ------------------------------------------------------------------------

## Shows a dialog; options are [{text, id}]; callback(id) ("" when dismissed).
func dialog(title: String, text: String, options: Array, callback := Callable()) -> void:
	close_dialog("")
	_dialog_cb = callback
	_modal = "dialog"
	_dialog = PanelContainer.new()
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dialog.custom_minimum_size = Vector2(620, 0)
	_dialog.position.y = -24
	var v := VBoxContainer.new()
	_dialog.add_child(v)
	v.add_child(UiTheme.label(title, 24, UiTheme.ACCENT))
	var body := UiTheme.label(text, 19)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(580, 0)
	v.add_child(body)
	var grid := GridContainer.new()
	# Short answers side by side, so the dialog stays low and the player stays visible.
	var short := options.all(func(o: Dictionary) -> bool: return str(o["text"]).length() <= 22)
	grid.columns = mini(options.size(), 3) if short else (2 if options.size() > 3 else 1)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	_dialog_buttons.clear()
	var i := 0
	for o: Dictionary in options:
		i += 1
		var id: String = o.get("id", "")
		var label: String = o["text"]
		if not Controls.touch_mode and i <= 9:
			label = "%d  %s" % [i, label]
		var b := UiTheme.button_node(label, func() -> void: close_dialog(id), 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(b)
		_dialog_buttons.append(b)
	root.add_child(_dialog)
	await get_tree().process_frame
	if is_instance_valid(_dialog):
		_dialog.position.x = (root.size.x - _dialog.size.x) * 0.5
		_dialog.position.y = root.size.y - _dialog.size.y - 24
		_place_toasts()
		if not _dialog_buttons.is_empty() and not Controls.touch_mode:
			_dialog_buttons[0].grab_focus()


func close_dialog(choice: String) -> void:
	if _dialog == null:
		return
	_dialog.queue_free()
	_dialog = null
	_dialog_buttons.clear()
	_place_toasts()
	if _modal == "dialog":
		_modal = ""
	var cb := _dialog_cb
	_dialog_cb = Callable()
	if cb.is_valid():
		cb.call(choice)


func is_dialog_open() -> bool:
	return _dialog != null


func _unhandled_input(event: InputEvent) -> void:
	if _dialog and event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9:
			var i := k - KEY_1
			if i < _dialog_buttons.size():
				_dialog_buttons[i].pressed.emit()
				get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			close_dialog("")
			get_viewport().set_input_as_handled()
	elif _modal == "bag" and event.is_action_pressed("bag"):
		close_screens()
		get_viewport().set_input_as_handled()
	elif _modal in ["map", "tasks", "switch", "bag", "craft"] and event.is_action_pressed("pause"):
		close_screens()
		get_viewport().set_input_as_handled()
	elif _modal == "map" and event.is_action_pressed("map"):
		close_screens()
		get_viewport().set_input_as_handled()
	elif _modal == "tasks" and event.is_action_pressed("tasks"):
		close_screens()
		get_viewport().set_input_as_handled()
	elif _modal == "pause" and event.is_action_pressed("pause"):
		close_pause()
		get_viewport().set_input_as_handled()


# --- Screens -----------------------------------------------------------------------

func open_map() -> void:
	if _modal != "" or game == null:
		return
	if map_screen == null:
		map_screen = MapScreen.new()
		root.add_child(map_screen)
		map_screen.build(game)
	map_screen.visible = true
	_modal = "map"


## The controlled character's bag; with_chest shows the storage chest next to it.
func open_bag(with_chest := false) -> void:
	if _modal != "" or game == null or game.player.actor == null:
		return
	if bag_screen == null:
		bag_screen = BagScreen.new()
		root.add_child(bag_screen)
		bag_screen.build(game)
	bag_screen.open(game.player.actor, with_chest)
	bag_screen.visible = true
	_modal = "bag"


## Workbench or campfire (station "workbench" | "campfire").
func open_craft(station: String) -> void:
	if _modal != "" or game == null or game.player.actor == null:
		return
	if craft_screen == null:
		craft_screen = CraftScreen.new()
		root.add_child(craft_screen)
		craft_screen.build(game)
	craft_screen.open(game.player.actor, station)
	craft_screen.visible = true
	_modal = "craft"


func open_tasks() -> void:
	if _modal != "" or game == null:
		return
	if tasks_screen == null:
		tasks_screen = TasksScreen.new()
		root.add_child(tasks_screen)
		tasks_screen.build(game)
	tasks_screen.refresh()
	tasks_screen.visible = true
	_modal = "tasks"


func close_screens() -> void:
	if map_screen:
		map_screen.visible = false
	if tasks_screen:
		tasks_screen.visible = false
	if bag_screen:
		bag_screen.visible = false
	if craft_screen:
		craft_screen.visible = false
	if _switch:
		_switch.queue_free()
		_switch = null
		hud.visible = true
	if _modal in ["map", "tasks", "switch", "bag", "craft"]:
		_modal = ""


func open_switch_menu() -> void:
	if _modal != "" or game == null or game.player.actor == null:
		return
	var candidates: Array[Actor] = game.player.switch_candidates()
	if candidates.is_empty():
		toast("Niemand in der Nähe, zu dem du wechseln kannst.", "info")
		return
	_modal = "switch"
	hud.visible = false  # up to eight rows: the menu would cover the HUD panels
	_switch = PanelContainer.new()
	_switch.mouse_filter = Control.MOUSE_FILTER_STOP
	_switch.set_anchors_preset(Control.PRESET_CENTER)
	var v := VBoxContainer.new()
	_switch.add_child(v)
	v.add_child(UiTheme.label("Zu wem möchtest du wechseln?", 24, UiTheme.ACCENT))
	var i := 0
	for a in candidates.slice(0, 8):
		i += 1
		var label := "%s  –  %s (%d m)" % [a.display_name, a.description, int(a.distance_to(game.player.actor.global_position))]
		var actor: Actor = a
		var b := UiTheme.button_node(label, func() -> void:
			close_screens()
			game.player.control(actor), 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
	v.add_child(UiTheme.button_node("Abbrechen", func() -> void: close_screens(), 17))
	root.add_child(_switch)
	await get_tree().process_frame
	if is_instance_valid(_switch):
		_switch.position = (root.size - _switch.size) * 0.5
		if not Controls.touch_mode:
			(v.get_child(1) as Button).grab_focus()


# --- Pause, settings, help -----------------------------------------------------------

func open_pause() -> void:
	if _modal != "" or game == null:
		return
	_modal = "pause"
	get_tree().paused = true
	_pause = _menu_panel("Pause", [
		["Weiterspielen", func() -> void: close_pause()],
		["Einstellungen", func() -> void: _settings()],
		["Steuerung & Hilfe", func() -> void: _help()],
		["Spiel speichern", func() -> void:
			GameState.save_game()
			toast("Gespeichert!", "info")],
		["Neues Spiel", func() -> void: _confirm_new_game()],
	])
	root.add_child(_pause)


func close_pause() -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
	get_tree().paused = false
	if _modal == "pause":
		_modal = ""


func _menu_panel(title: String, entries: Array) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(420, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var t := UiTheme.label(title, 32, UiTheme.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for e: Array in entries:
		v.add_child(UiTheme.button_node(e[0], e[1], 22))
	(v.get_child(1) as Button).call_deferred("grab_focus")
	return shade


func _replace_pause(panel: Control) -> void:
	if _pause:
		_pause.queue_free()
	_pause = panel
	root.add_child(_pause)


func _back_to_pause() -> void:
	if _title and _title.visible:
		if _pause:
			_pause.queue_free()
			_pause = null
		_modal = "title"
		return
	if _pause:
		_pause.queue_free()
		_pause = null
	_modal = ""
	open_pause()


func _settings() -> void:
	var shade := _menu_panel("Einstellungen", [["Zurück", func() -> void:
		GameState.save_settings()
		_back_to_pause()]])
	var v := shade.get_child(0).get_child(0).get_child(0) as VBoxContainer
	var q := HBoxContainer.new()
	q.add_child(UiTheme.label("Grafik", 20))
	for opt: Array in [["auto", "Auto"], ["low", "Niedrig"], ["medium", "Mittel"], ["high", "Hoch"]]:
		var key: String = opt[0]
		var b := UiTheme.button_node(opt[1], func() -> void:
			GameState.settings["quality"] = key
			game.apply_quality()
			toast("Grafik: %s" % opt[1], "info"), 17)
		q.add_child(b)
	v.add_child(q)
	v.add_child(_slider("Lautstärke", "volume", func(val: float) -> void: Sound.set_volume(val)))
	v.add_child(_slider("Musik & Ambiente", "music", func(val: float) -> void: Sound.set_ambient_volume(val)))
	v.add_child(_slider("Kamera-Empfindlichkeit", "camera_sensitivity", func(val: float) -> void:
		if game and game.camera:
			game.camera.sensitivity = val, 0.3, 2.5))
	var fps := CheckButton.new()
	fps.text = "FPS anzeigen"
	fps.button_pressed = GameState.settings.get("show_fps", false)
	fps.toggled.connect(func(on: bool) -> void: GameState.settings["show_fps"] = on)
	v.add_child(fps)
	v.move_child(v.get_child(1), v.get_child_count() - 1)
	_replace_pause(shade)


func _slider(text: String, key: String, cb: Callable, lo := 0.0, hi := 1.0) -> Control:
	var h := HBoxContainer.new()
	var l := UiTheme.label(text, 18)
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = GameState.settings.get(key, 1.0)
	s.custom_minimum_size = Vector2(180, 30)
	s.value_changed.connect(func(val: float) -> void:
		GameState.settings[key] = val
		cb.call(val))
	h.add_child(s)
	return h


func _help() -> void:
	var text := """[b]Ziel:[/b] Lebe im Stadtpark! Spiele Menschen und Tiere, erfülle Aufgaben, spiele Minispiele, verdiene Geld und schalte Erfolge frei. Halte deine Figur bei Laune: Essen gegen Hunger, Bänke gegen Müdigkeit, Minispiele für Freude.

[b]Tastatur & Maus[/b]
WASD / Pfeiltasten – laufen    Shift – rennen
E – Aktion (hinsetzen, kaufen, ansprechen …)
Q oder Tab – Figur wechseln (nur Figuren in deiner Nähe)
F – Spezialaktion (bellen, quaken, klettern, winken …)
R – tanzen    M – Karte    J – Notizbuch    Esc – Menü
Maus ziehen – Kamera drehen    Mausrad – zoomen
Linksklick auf den Boden – dorthin laufen

[b]Touch[/b]
Linker Joystick – laufen, Wischen – Kamera drehen,
Tippen – hinlaufen oder Figur ansprechen, Knöpfe rechts für Aktionen.

[b]Gamepad[/b]
Linker Stick – laufen, rechter Stick – Kamera, A – Aktion, Y – wechseln, X – Spezial."""
	var shade := _menu_panel("Steuerung & Hilfe", [["Zurück", func() -> void: _back_to_pause()]])
	var v := shade.get_child(0).get_child(0).get_child(0) as VBoxContainer
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = text
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(640, 0)
	rt.add_theme_font_size_override("normal_font_size", 17)
	rt.add_theme_font_size_override("bold_font_size", 18)
	v.add_child(rt)
	v.move_child(rt, 1)
	_replace_pause(shade)


func _confirm_new_game() -> void:
	dialog("Neues Spiel", "Wirklich neu anfangen? Dein Fortschritt geht verloren.", [
		{"text": "Ja, neu anfangen", "id": "yes"}, {"text": "Nein", "id": ""}], func(c: String) -> void:
		if c == "yes":
			GameState.delete_save()
			GameState.new_game()
			close_pause()
			get_tree().reload_current_scene()
		else:
			_modal = "pause")


# --- Loading and title ------------------------------------------------------------------

func show_loading() -> void:
	_loading = ColorRect.new()
	(_loading as ColorRect).color = Color("1f3a2e")
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_loading)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)
	var t := UiTheme.label("Bank frei!", 72, UiTheme.CREAM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UiTheme.label("Ein Tag im Stadtpark", 24, UiTheme.ACCENT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(420, 20)
	_loading_bar.show_percentage = false
	v.add_child(_loading_bar)
	_loading_text = UiTheme.label("", 18)
	_loading_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_loading_text)


func loading_progress(f: float, text: String) -> void:
	if _loading_bar:
		_loading_bar.value = f * 100.0
		_loading_text.text = text


func hide_loading() -> void:
	if _loading:
		var tw := create_tween()
		var node := _loading
		tw.tween_property(node, "modulate:a", 0.0, 0.6)
		tw.tween_callback(node.queue_free)
		_loading = null


## Title screen over the live park. `starters` = actor ids offered for a new game.
func show_title(has_save: bool, on_continue: Callable, on_new: Callable) -> void:
	_modal = "title"
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_title)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.1, 0.08, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(70, -200)
	v.add_theme_constant_override("separation", 12)
	_title.add_child(v)
	var t := UiTheme.label("Bank frei!", 84, UiTheme.CREAM)
	t.add_theme_constant_override("outline_size", 14)
	t.add_theme_color_override("font_outline_color", Color("1f3a2e"))
	v.add_child(t)
	var sub := UiTheme.label("Ein Tag im Stadtpark – mit Enten, Opas und Donuts.", 22, UiTheme.ACCENT)
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", Color("1f3a2e"))
	v.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	v.add_child(spacer)
	if has_save:
		v.add_child(UiTheme.button_node("Weiterspielen", func() -> void:
			hide_title()
			on_continue.call(), 24))
	v.add_child(UiTheme.button_node("Neues Spiel", func() -> void: _choose_starter(on_new), 24))
	v.add_child(UiTheme.button_node("Einstellungen", func() -> void:
		_pause = null
		_settings(), 20))
	v.add_child(UiTheme.button_node("Steuerung & Hilfe", func() -> void:
		_pause = null
		_help(), 20))
	if OS.has_feature("web") and not OS.has_feature("web_ios"):
		v.add_child(UiTheme.button_node("Android-App herunterladen", func() -> void: open_download_page(), 20))
	for c in v.get_children():
		if c is Button:
			(c as Button).custom_minimum_size = Vector2(320, 0)
			(c as Button).call_deferred("grab_focus")
			break


## Opens the APK download page next to the web build (web only).
func open_download_page() -> void:
	var origin = JavaScriptBridge.eval("window.location.origin + window.location.pathname.replace(/[^/]*$/, '')", true)
	OS.shell_open(str(origin) + "download")


func hide_title() -> void:
	if _title:
		_title.queue_free()
		_title = null
	if _modal == "title":
		_modal = ""


func _choose_starter(on_new: Callable) -> void:
	var starters := ["jens", "herbert", "peggy", "lena", "bello", "minka", "nussi", "erwin"]
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.1, 0.08, 0.75)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var p := PanelContainer.new()
	center.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UiTheme.label("Mit wem möchtest du starten?", 30, UiTheme.ACCENT))
	v.add_child(UiTheme.label("Später kannst du jederzeit zu Figuren in deiner Nähe wechseln.", 17))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var first := true
	for id: String in starters:
		var a: Actor = game.world.find_actor(id)
		if a == null:
			continue
		var b := UiTheme.button_node("%s\n%s" % [a.display_name, a.description], func() -> void:
			hide_title()
			on_new.call(id), 17)
		b.custom_minimum_size = Vector2(420, 70)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(b)
		if first:
			b.call_deferred("grab_focus")
			first = false


# --- Minigame helpers -------------------------------------------------------------------

func set_modal(name: String) -> void:
	_modal = name


func clear_modal(name: String) -> void:
	if _modal == name:
		_modal = ""


# --- World marker --------------------------------------------------------------------------

func show_marker(p: Vector3) -> void:
	if game == null:
		return
	if _marker == null or not is_instance_valid(_marker):
		_marker = MeshInstance3D.new()
		var kit := MeshKit.new()
		kit.use("unshaded")
		kit.torus(Vector3.ZERO, 0.45, 0.06, 20, 4, UiTheme.ACCENT)
		_marker.mesh = kit.commit()
		_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.world.add_child(_marker)
	_marker.global_position = p + Vector3(0, 0.08, 0)
	_marker.visible = true
	_marker.scale = Vector3.ONE * 1.6
	var tw := create_tween()
	tw.tween_property(_marker, "scale", Vector3.ONE, 0.3)
	tw.tween_interval(1.5)
	tw.tween_callback(func() -> void: _marker.visible = false)

class_name Hud
extends Control
## In-game overlay: character + needs, clock/weather/money, prompt, inventory, buttons.

var game: Node
var name_label: Label
var doing_label: Label
var bars := {}
var clock_label: Label
var info_label: Label
var money_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var inventory_label: Label
var fps_label: Label
var _t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build(g: Node) -> void:
	game = g
	# Character panel (top left).
	var left := PanelContainer.new()
	left.position = Vector2(14, 14)
	left.custom_minimum_size = Vector2(300, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	left.add_child(lv)
	name_label = UiTheme.label("", 24, UiTheme.CREAM)
	lv.add_child(name_label)
	doing_label = UiTheme.label("", 15, Color(UiTheme.CREAM, 0.8))
	doing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	doing_label.custom_minimum_size = Vector2(268, 0)
	lv.add_child(doing_label)
	for key: Array in [["joy", "Freude", UiTheme.GREEN], ["hunger", "Hunger", UiTheme.ACCENT], ["fatigue", "Müdigkeit", UiTheme.BLUE]]:
		var row := HBoxContainer.new()
		var l := UiTheme.label(key[1], 16)
		l.custom_minimum_size = Vector2(92, 0)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(170, 16)
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = key[2]
		fill.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		lv.add_child(row)
		bars[key[0]] = bar
	inventory_label = UiTheme.label("", 15, Color(UiTheme.CREAM, 0.85))
	lv.add_child(inventory_label)
	# Clock panel (top right).
	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-14, 14)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 2)
	right.add_child(rv)
	clock_label = UiTheme.label("", 30)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(clock_label)
	info_label = UiTheme.label("", 16)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(info_label)
	money_label = UiTheme.label("", 22, UiTheme.GOLD)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(money_label)
	# Menu buttons under the clock.
	var buttons := HBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	buttons.position = Vector2(-14, 150)
	buttons.add_theme_constant_override("separation", 6)
	add_child(buttons)
	for b in [["Karte", func() -> void: UI.open_map()], ["Aufgaben", func() -> void: UI.open_tasks()],
			["Wechseln", func() -> void: UI.open_switch_menu()], ["Menü", func() -> void: UI.open_pause()]]:
		var btn := UiTheme.button_node(b[0], b[1], 16)
		btn.focus_mode = Control.FOCUS_NONE
		buttons.add_child(btn)
	# Interaction prompt (bottom centre).
	prompt_panel = PanelContainer.new()
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_panel.position.y = -110
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.visible = false
	add_child(prompt_panel)
	prompt_label = UiTheme.label("", 22)
	prompt_panel.add_child(prompt_label)
	fps_label = UiTheme.label("", 14)
	fps_label.position = Vector2(14, 690)
	fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	fps_label.position = Vector2(14, -26)
	add_child(fps_label)
	GameState.money_changed.connect(func(_c: int) -> void: _refresh_static())
	_refresh_static()


func set_prompt(text: String) -> void:
	prompt_panel.visible = text != ""
	if text == "":
		return
	var key := "Aktion" if Controls.touch_mode else "[E]"
	prompt_label.text = "%s  %s" % [key, text]
	prompt_panel.reset_size()
	prompt_panel.position.x = (size.x - prompt_panel.size.x) * 0.5


func _refresh_static() -> void:
	money_label.text = GameState.format_money(GameState.money)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.2
	clock_label.text = Clock.time_string()
	info_label.text = "Tag %d · %s · %s" % [Clock.day + 1, Clock.season_name(), Clock.weather_name()]
	fps_label.visible = GameState.settings.get("show_fps", false)
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	var pc: PlayerController = game.player if game else null
	if pc == null or pc.actor == null:
		return
	var a := pc.actor
	name_label.text = a.display_name
	doing_label.text = a.description
	(bars["joy"] as ProgressBar).value = a.needs.joy
	(bars["hunger"] as ProgressBar).value = a.needs.hunger
	(bars["fatigue"] as ProgressBar).value = a.needs.fatigue
	var inv := []
	var names := {"bread": "Entenbrot", "empty_bottle": "Pfandflaschen", "invisible_key": "Unsichtbarer Schlüssel", "nut": "Nüsse"}
	for k: String in a.inventory:
		inv.append("%s ×%d" % [names.get(k, k), a.inventory[k]])
	inventory_label.text = " · ".join(inv)
	inventory_label.visible = not inv.is_empty()

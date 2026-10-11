class_name Hud
extends Control
## In-game overlay: character + needs, clock/weather/money, prompt, inventory, buttons.

var game: Node
var left_panel: PanelContainer   # character and needs (top left)
var right_panel: PanelContainer  # clock, weather, money (top right)
var menu_buttons: HBoxContainer  # under the clock
var name_label: Label
var doing_label: Label
var bars := {}
var trends := {}             # need -> Control drawing animated arrows
var fills := {}              # need -> [StyleBoxFlat, base colour]
var _rates := {}             # need -> smoothed change per second
var _last := {}              # need -> value at the previous sample
var _trend_actor: Actor
var _anim_t := 0.0
const TREND_MIN := 0.25      # need points per second before a trend is shown
var clock_label: Label
var info_label: Label
var money_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var inventory_label: Label
var bag_button: Button
var fps_label: Label
var _perf := {"start": 0, "frames": 0, "proc": 0.0, "phys": 0.0, "pframes": 0, "ticks": 0}
var _t := 0.0
var _prompt := ""
var _talk_prompt := ""


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
	left_panel = left
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
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
		var trend := Control.new()
		trend.custom_minimum_size = Vector2(40, 18)
		trend.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trend.draw.connect(_draw_trend.bind(key[0], trend))
		row.add_child(trend)
		lv.add_child(row)
		bars[key[0]] = bar
		trends[key[0]] = trend
		fills[key[0]] = [fill, key[2]]
	# Bag button with a one-line summary of what the character carries.
	var inv_row := HBoxContainer.new()
	inv_row.add_theme_constant_override("separation", 8)
	lv.add_child(inv_row)
	bag_button = UiTheme.button_node("Rucksack", func() -> void: UI.open_bag(), 15)
	bag_button.focus_mode = Control.FOCUS_NONE
	bag_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state: String in ["normal", "hover", "pressed"]:
		var sb := UiTheme.button(state)
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		bag_button.add_theme_stylebox_override(state, sb)
	inv_row.add_child(bag_button)
	inventory_label = UiTheme.label("", 14, Color(UiTheme.CREAM, 0.85))
	inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_label.custom_minimum_size = Vector2(170, 0)
	inventory_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_row.add_child(inventory_label)
	# Clock panel (top right).
	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-14, 14)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	right_panel = right
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
	menu_buttons = buttons
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
	Controls.touch_mode_changed.connect(func(_on: bool) -> void: _show_prompt())  # "[E]" vs "Aktion"
	_refresh_static()


## What "Aktion" does (things) and what "Ansprechen" does (the person in front), side by side.
func set_prompt(text: String) -> void:
	_prompt = text
	_show_prompt()


func set_talk_prompt(text: String) -> void:
	_talk_prompt = text
	_show_prompt()


func _show_prompt() -> void:
	prompt_panel.visible = _prompt_shown()
	if not _has_prompt():
		return
	var parts := []
	if _prompt != "":
		parts.append("%s  %s" % ["Aktion" if Controls.touch_mode else "[E]", _prompt])
	if _talk_prompt != "":
		# On touch the button is called "Ansprechen" already.
		parts.append(_talk_prompt if Controls.touch_mode else "[T]  " + _talk_prompt)
	prompt_label.text = "   ·   ".join(parts)
	prompt_panel.reset_size()
	prompt_panel.position.x = (size.x - prompt_panel.size.x) * 0.5


func _has_prompt() -> bool:
	return _prompt != "" or _talk_prompt != ""


## Hidden under a dialog or screen; on touch also while driving (the buttons are named).
func _prompt_shown() -> bool:
	var driving: bool = game != null and game.player != null and game.player.actor != null and game.player.actor.vehicle != null
	return _has_prompt() and not UI.blocks_game_input() and not (Controls.touch_mode and driving)


func _refresh_static() -> void:
	money_label.text = GameState.format_money(GameState.money)


func _process(delta: float) -> void:
	_animate_trends(delta)
	if fps_label.visible:
		_sample_perf()
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.2
	# Hidden while a dialog or screen is open (it would sit under the dialog).
	prompt_panel.visible = _prompt_shown()
	clock_label.text = Clock.time_string()
	info_label.text = "Tag %d · %s · %s" % [Clock.day + 1, Clock.season_name(), Clock.weather_name()]
	fps_label.visible = GameState.settings.get("show_fps", false)
	var pc: PlayerController = game.player if game else null
	if pc == null or pc.actor == null:
		return
	var a := pc.actor
	name_label.text = a.display_name
	doing_label.text = a.description
	if a.vehicle:
		doing_label.text = "Am Steuer: %s · %d km/h" % [CarSpecs.name_of(a.vehicle.kind), CarSpecs.kmh(a.vehicle.speed)]
	(bars["joy"] as ProgressBar).value = a.needs.joy
	(bars["hunger"] as ProgressBar).value = a.needs.hunger
	(bars["fatigue"] as ProgressBar).value = a.needs.fatigue
	_sample_trends(a, 0.2)
	var inv := []
	for k: String in Items.sorted_ids(a.inventory):
		inv.append("%s ×%d" % [Items.name_of(k), int(a.inventory[k])])
	# Long lists are cut: the bag screen shows everything.
	var text := " · ".join(inv.slice(0, 3))
	if inv.size() > 3:
		text += " …"
	inventory_label.text = text if not inv.is_empty() else "leer"


## Tracks how fast each need changes so the bars can show it (e.g. fatigue
## dropping while sitting on a bench).
func _sample_trends(a: Actor, dt: float) -> void:
	var values := {"joy": a.needs.joy, "hunger": a.needs.hunger, "fatigue": a.needs.fatigue}
	if a != _trend_actor:
		_trend_actor = a
		_last = values
		_rates.clear()
		return
	for k: String in values:
		var rate: float = (values[k] - _last[k]) / dt
		# Instant changes (eating) show briefly, steady ones (sitting) stay.
		_rates[k] = lerpf(_rates.get(k, 0.0), rate, 0.5)
		_last[k] = values[k]


func _animate_trends(delta: float) -> void:
	_anim_t += delta
	for k: String in trends:
		var rate: float = _rates.get(k, 0.0)
		var fill: StyleBoxFlat = fills[k][0]
		var base: Color = fills[k][1]
		(trends[k] as Control).queue_redraw()
		if absf(rate) < TREND_MIN:
			fill.bg_color = base
			continue
		fill.bg_color = base.lerp(Color.WHITE, 0.25 + 0.25 * sin(_anim_t * 8.0))


## One to three moving chevrons pointing up or down; green when the change is
## good (lower hunger / fatigue, higher joy), red otherwise.
func _draw_trend(k: String, c: Control) -> void:
	var rate: float = _rates.get(k, 0.0)
	if absf(rate) < TREND_MIN:
		return
	var up := rate > 0.0
	var good := up == (k == "joy")
	var col := UiTheme.GREEN if good else Color("e0574a")
	var n := 1 + int(_anim_t * 4.0) % 3
	var h := c.size.y
	for i in n:
		var x := 3.0 + i * 12.0
		var tip := 1.0 if up else h - 1.0
		var base := h - 3.0 if up else 3.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, base), Vector2(x + 10.0, base), Vector2(x + 5.0, tip)]), col)


## Performance overlay (Einstellungen → Leistung anzeigen), averaged over half a second: frame
## time, script time per frame (process) and per physics step, what the GPU had to draw, and
## how many actors updated per physics step (the rest is far away, Actor.lod_step).
func _sample_perf() -> void:
	var p := _perf
	if p["frames"] == 0:
		p["start"] = Time.get_ticks_usec()
	p["frames"] += 1
	p["proc"] += Performance.get_monitor(Performance.TIME_PROCESS)
	p["phys"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var secs := (Time.get_ticks_usec() - int(p["start"])) / 1000000.0
	if secs < 0.5:
		return
	var n := float(p["frames"])
	var steps := maxi(1, Engine.get_physics_frames() - int(p["pframes"]))
	var active := float(Actor.ticks - int(p["ticks"])) / steps
	var total: int = game.world.actors.filter(func(a: Actor) -> bool: return not a.dormant).size() if game and game.world else 0
	fps_label.text = "%d FPS · %.1f ms · Skript %.1f · Physik %.1f · %d Draws · %dk Dreiecke · %d/%d Figuren aktiv" % [
		Engine.get_frames_per_second(), secs / n * 1000.0, p["proc"] / n * 1000.0, p["phys"] / n * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		roundi(active), total]
	_perf = {"start": 0, "frames": 0, "proc": 0.0, "phys": 0.0, "pframes": Engine.get_physics_frames(), "ticks": Actor.ticks}

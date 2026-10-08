class_name Minigame
extends Node3D
## Base class for minigames: start/end flow, rewards, camera takeover and a
## small HUD (title, instructions, score, power bar, touch buttons).

signal finished(result: Dictionary)

var game: Node
var world: World
var actor: Actor
var title := "Minispiel"
var host_id := ""            # NPC who offers the game ("" = none)
var cost := 0                # entry fee in cents
var active := false
var free_roam := false        # player keeps walking around (no camera takeover)
var hud: Control
var _score_label: Label
var _info_label: Label
var _power: ProgressBar
var _buttons: HBoxContainer
var _quit_confirm := false
var session := 0              # counts starts; delayed callbacks check it (see end_after)


func setup(g: Node) -> void:
	game = g
	world = g.world
	world.add_child(self)


## Override: description for the task board / dialogs.
func describe() -> String:
	return ""


func host() -> Actor:
	return world.find_actor(host_id) if host_id != "" else null


## Host present and not controlled by the player?
func host_available() -> bool:
	if host_id == "":
		return true
	var h := host()
	return h != null and not h.inside and h.visible and not h.controlled


func can_start(a: Actor) -> bool:
	return a.is_human() and not active


func try_start(a: Actor) -> void:
	if active:
		return
	if cost > 0 and not GameState.spend(cost):
		return
	start(a)


func start(a: Actor) -> void:
	actor = a
	active = true
	session += 1
	if a.seat:
		a.stand_up()
	a.stop_moving()
	if not free_roam:
		game.player.input_enabled = false
		UI.set_modal("minigame")
		UI.show_hud(false)
	_build_hud()
	var h := host()
	if h and h.brain:
		h.brain.suspend()
	begin()


## Ends the game after a short pause (to show the outcome), unless it was quit or
## restarted meanwhile: a stale timer must not end the next game.
func end_after(secs: float, result: Dictionary) -> void:
	var s := session
	await get_tree().create_timer(secs).timeout
	if active and session == s:
		end(result)


## True while the game started in session `s` is still running.
func still_running(s: int) -> bool:
	return active and session == s


## Override: game-specific setup.
func begin() -> void:
	pass


## Ends the game. result: {"won": bool, "money": cents, "joy": float, "text": String}
func end(result: Dictionary) -> void:
	if not active:
		return
	active = false
	cleanup()
	if hud:
		hud.queue_free()
		hud = null
	if not free_roam:
		game.camera.end_override()
		game.player.input_enabled = true
		UI.clear_modal("minigame")
		UI.show_hud(true)
	var h := host()
	if h and h.brain:
		h.brain.resume()
	var money: int = result.get("money", 0)
	var joy: float = result.get("joy", 15.0)
	actor.needs.cheer(joy)
	actor.emote("happy" if result.get("won", false) else "note")
	if money > 0:
		GameState.add_money(money, title)
	if result.has("text"):
		UI.dialog(title, result["text"], [{"text": "Super!", "id": ""}])
	Sound.play("success" if result.get("won", false) else "click")
	finished.emit(result)


## Override: remove game objects.
func cleanup() -> void:
	pass


func quit() -> void:
	end({"won": false, "joy": 3.0, "text": "Spiel abgebrochen."})


# --- HUD ------------------------------------------------------------------------------

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = UI.theme
	UI.minigame_root.add_child(hud)
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.position.y = 14 if not free_roam else 200
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	top.add_child(v)
	var t := UiTheme.label(title, 26, UiTheme.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_score_label = UiTheme.label("", 20)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_score_label)
	_info_label = UiTheme.label("", 16, Color(UiTheme.CREAM, 0.85))
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(560, 0)
	v.add_child(_info_label)
	_power = ProgressBar.new()
	_power.custom_minimum_size = Vector2(360, 18)
	_power.show_percentage = false
	_power.visible = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.ACCENT
	fill.set_corner_radius_all(6)
	_power.add_theme_stylebox_override("fill", fill)
	v.add_child(_power)
	_buttons = HBoxContainer.new()
	_buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_buttons.position.y = -24
	_buttons.add_theme_constant_override("separation", 14)
	hud.add_child(_buttons)
	var quit_btn := UiTheme.button_node("Beenden", func() -> void: quit(), 16)
	quit_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quit_btn.position = Vector2(-120, 16)
	quit_btn.focus_mode = Control.FOCUS_NONE
	hud.add_child(quit_btn)
	await get_tree().process_frame
	if is_instance_valid(top):
		top.position.x = (hud.size.x - top.size.x) * 0.5


func set_score(text: String) -> void:
	if _score_label:
		_score_label.text = text


func set_info(text: String) -> void:
	if _info_label:
		_info_label.text = text


func show_power(value: float) -> void:
	if _power:
		_power.visible = value >= 0.0
		_power.value = value * 100.0


## Adds a big touch/mouse button; returns it.
func add_button(text: String, cb: Callable, width := 150) -> Button:
	var b := UiTheme.button_node(text, cb, 22)
	b.custom_minimum_size = Vector2(width, 70)
	b.focus_mode = Control.FOCUS_NONE
	_buttons.add_child(b)
	_center_buttons.call_deferred()
	return b


func clear_buttons() -> void:
	if _buttons:
		for c in _buttons.get_children():
			c.queue_free()


func _center_buttons() -> void:
	if _buttons and hud:
		_buttons.reset_size()
		_buttons.position.x = (hud.size.x - _buttons.size.x) * 0.5


## Camera looking from `from` to `at`.
func look(from: Vector3, at: Vector3) -> void:
	game.camera.set_override(Transform3D(Basis(), from).looking_at(at, Vector3.UP))


func _unhandled_input(event: InputEvent) -> void:
	if not active or free_roam:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		quit()
		return
	game_input(event)


## Override for keyboard/mouse input during the game.
func game_input(_event: InputEvent) -> void:
	pass


# --- Shared helpers ---------------------------------------------------------------

## Oscillating 0..1 value for power bars.
static func pingpong(t: float, speed := 1.0) -> float:
	var x := fmod(t * speed, 2.0)
	return x if x <= 1.0 else 2.0 - x

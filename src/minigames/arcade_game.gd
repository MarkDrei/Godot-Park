class_name ArcadeGame
extends Minigame
## A machine in the arcade hall of the Kirmes (doc/kirmes.md): a little 2D game on the
## cabinet's screen, a high-score table with the fair people's scores to beat, tickets by the
## score. Subclasses play the game in step(), draw it in draw_screen() (a 240 × 180 grid of
## "pixels" scaled to the screen) and set `score` and `over`.

const SCREEN := Vector2(240, 180)
## The best scores of the fair people per machine (the player has to beat the first).
const TABLE := {
	"snake": [["Sascha", 420], ["Aylin", 310], ["Lothar", 190], ["Zora", 120], ["Max", 60]],
	"astro": [["Sascha", 1800], ["Geister-Gustav", 1250], ["Dieter", 900], ["Rita", 500], ["Erna", 200]],
	"bricks": [["Sascha", 2600], ["Claudette", 1900], ["Moritz", 1100], ["Karl", 700], ["Bernd", 300]],
}

var machine := ""            # snake | astro | bricks (stat "arcade_<id>")
var cabinet := Vector3.ZERO  # where the player stands, in front of the screen
var score := 0
var over := false
var keys := {"left": false, "right": false, "up": false, "down": false, "fire": false}
var _touch := {"left": false, "right": false, "up": false, "down": false, "fire": false}
var _panel: Control
var _screen: Control
var _table: Label
var _step := 0.0
## The old code (up up down down left right left right) shows a bonus picture: an easter egg.
const RETRO := ["up", "up", "down", "down", "left", "right", "left", "right"]
var _code: Array[String] = []
var bonus := 0.0


func _init() -> void:
	cost = 50


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.fair != null


func host_available() -> bool:
	return Fair.open_now(world)


func unavailable_text() -> String:
	return "geschlossen"


## Best score of the player on this machine.
func best() -> int:
	return GameState.stat("arcade_" + machine)


## The table with the player's best in it: [[name, score, is_player], ...] best first.
func table() -> Array:
	var out := []
	for e: Array in TABLE[machine]:
		out.append([e[0], e[1], false])
	if best() > 0:
		out.append(["Du", best(), true])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return out.slice(0, 6)


func first_place() -> bool:
	return best() > TABLE[machine][0][1]


func begin() -> void:
	score = 0
	over = false
	for k: String in keys:
		keys[k] = false
		_touch[k] = false
	actor.teleport(cabinet)
	actor.face(cabinet + Vector3(0, 0, -2), true)
	look(cabinet + Vector3(0.6, 1.9, 1.6), cabinet + Vector3(0, 1.4, -1.3))
	_build_screen()
	reset_game()
	for b: Array in controls():
		var btn := add_button(b[0], func() -> void: pass, 110)
		var key: String = b[1]
		btn.button_down.connect(func() -> void:
			_touch[key] = true
			code_key(key))
		btn.button_up.connect(func() -> void: _touch[key] = false)
	_code.clear()
	bonus = 0.0
	set_info(help_text())


func _build_screen() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("12121a")
	sb.border_color = Color("3a3a50")
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_panel.add_child(h)
	_screen = Control.new()
	_screen.custom_minimum_size = SCREEN * 2.0
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.draw.connect(func() -> void: _draw())
	h.add_child(_screen)
	_table = UiTheme.label("", 16, Color("9fe8ff"))
	_table.custom_minimum_size = Vector2(170, 0)
	h.add_child(_table)
	_update_table()
	_place_panel.call_deferred()


func _place_panel() -> void:
	if not is_instance_valid(_panel):
		return
	var vp := hud.size
	# Fit between the title panel and the buttons on every screen.
	var avail := Vector2(vp.x - 40.0, vp.y - 300.0)
	var k := clampf(minf(avail.x / (SCREEN.x * 2.0 + 200.0), avail.y / (SCREEN.y * 2.0 + 20.0)), 0.5, 1.4)
	_panel.scale = Vector2(k, k)
	_panel.reset_size()
	_panel.position = Vector2((vp.x - _panel.size.x * k) * 0.5, 190.0)


func _update_table() -> void:
	var lines := ["HIGHSCORE", ""]
	var i := 1
	for e: Array in table():
		lines.append("%d. %s%s %d" % [i, "> " if e[2] else "", e[0], e[1]])
		i += 1
	_table.text = "\n".join(lines)


func _process(delta: float) -> void:
	if not active:
		return
	for k: String in keys:
		keys[k] = _touch[k]
	keys["left"] = keys["left"] or Input.is_action_pressed("move_left")
	keys["right"] = keys["right"] or Input.is_action_pressed("move_right")
	keys["up"] = keys["up"] or Input.is_action_pressed("move_forward")
	keys["down"] = keys["down"] or Input.is_action_pressed("move_back")
	keys["fire"] = keys["fire"] or Input.is_action_pressed("interact") or Input.is_key_pressed(KEY_SPACE)
	bonus = maxf(0.0, bonus - delta)
	if not over:
		_step += delta
		while _step >= 1.0 / 60.0:
			_step -= 1.0 / 60.0
			step(1.0 / 60.0)
			if over:
				_game_over()
				break
	set_score("Punkte: %d" % score)
	if is_instance_valid(_screen):
		_screen.queue_redraw()


## A direction pressed: part of the retro code?
func code_key(k: String) -> void:
	if not k in ["up", "down", "left", "right"]:
		return
	_code.append(k)
	if _code.size() > RETRO.size():
		_code.pop_front()
	if _code == RETRO:
		bonus = 6.0
		_code.clear()
		GameState.set_stat("retro_code", 1)
		Sound.play("achievement", null, -4.0)


func game_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		var k: String = {KEY_W: "up", KEY_UP: "up", KEY_S: "down", KEY_DOWN: "down", KEY_A: "left", KEY_LEFT: "left",
			KEY_D: "right", KEY_RIGHT: "right"}.get((event as InputEventKey).keycode, "")
		code_key(k)


func _draw() -> void:
	var c := _screen
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN * 2.0), Color("05050a"))
	draw_screen(c, 2.0)
	if bonus > 0.0:
		_draw_bonus(c, 2.0)
	if over:
		var f := c.get_theme_default_font()
		c.draw_string(f, Vector2(0, SCREEN.y - 10.0), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x * 2.0, 40, Color("ff4f6a"))


## A filled block on the screen grid (x, y, w, h in screen pixels).
static func block(c: Control, s: float, x: float, y: float, w: float, h: float, col: Color) -> void:
	c.draw_rect(Rect2(x * s, y * s, w * s, h * s), col)


## The bonus picture: the park's bronze duck with a crown, in big pixels.
func _draw_bonus(c: Control, s: float) -> void:
	block(c, s, 40, 20, 160, 140, Color("1a1430"))
	var pix := ["....yyy.y.y.....", "....yyyyyyy.....", ".....bbbb.......", "....bbbbbb......", "....bbkbbbbo....",
		"....bbbbbboo....", ".....bbbb.......", "..bbbbbbbbb.....", ".bbbbbbbbbbbb...", ".bbbbbbbbbbbb...",
		"..bbbbbbbbbb....", "...bbbbbbbb.....", "...ssssssss.....", "..ssssssssss...."]
	var cols := {"y": Color("ffd84a"), "b": Color("8a6a3a"), "k": Color("1a1a1a"), "o": Color("e67e22"), "s": Color("a8a196")}
	for row in pix.size():
		var line: String = pix[row]
		for col in line.length():
			var ch := line[col]
			if cols.has(ch):
				block(c, s, 56 + col * 8, 32 + row * 8, 8, 8, cols[ch])
	var f := c.get_theme_default_font()
	c.draw_string(f, Vector2(40 * s, 158 * s), "QUAK! GEHEIMCODE", HORIZONTAL_ALIGNMENT_CENTER, 160 * s, 22, Color("ffd84a"))


func _game_over() -> void:
	var was_first := first_place()
	GameState.set_stat_max("arcade_" + machine, score)
	_update_table()
	var tickets := score_tickets()
	var text := "%d Punkte." % score
	if first_place() and not was_first:
		text += " Platz 1 der Highscore-Liste! Sascha staunt."
	elif best() == score and score > 0:
		text += " Neuer persönlicher Rekord!"
	FairPass.stamp("arcade")
	var firsts := 0
	for m: String in TABLE:
		if GameState.stat("arcade_" + m) > TABLE[m][0][1]:
			firsts += 1
	GameState.set_stat_max("arcade_firsts", firsts)
	if tickets > 0:
		GameState.add_tickets(tickets, title)
		text += "\n\nDu gewinnst %d Ticket%s." % [tickets, "" if tickets == 1 else "s"]
	end_after(2.0, {"won": first_place(), "joy": 10.0 + tickets, "text": text})


func cleanup() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()


# --- Override --------------------------------------------------------------------------

func reset_game() -> void:
	pass


func step(_dt: float) -> void:
	pass


func draw_screen(_c: Control, _s: float) -> void:
	pass


## [label, key] of the touch buttons.
func controls() -> Array:
	return [["Links", "left"], ["Rechts", "right"]]


func help_text() -> String:
	return ""


func score_tickets() -> int:
	return score / 100


func goal_done() -> bool:
	return first_place()

class_name CoastTelescope
extends Minigame
## The coin telescope on the pier head (doc/moewenbucht.md): 20 cents for half a minute of
## looking through it. The view is narrow and round; "Links" and "Rechts" (or the stick, A/D)
## turn it, "Hoch"/"Runter" tilt it; the seals on the sandbank, the lighthouse, the cutter.

const DURATION := 30.0
const FOV := 13.0
const TURN := 0.5               # radians per second

var t := 0.0
var yaw := PI                   # looking south, out to sea
var pitch := -0.04
var turn := 0.0                 # held buttons: -1, 0, 1
var tilt := 0.0
var eye := Vector3.ZERO
var mask: Control
var _fov := 62.0


func _init() -> void:
	title = "Münzfernrohr"
	host_id = ""
	host_needed = false
	cost = 20


func describe() -> String:
	return "Das Münzfernrohr auf dem Brückenkopf der Seebrücke: eine halbe Minute ganz nah heran. 0,20 €."


func goal_done() -> bool:
	return GameState.stat("telescope") > 0


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.coast != null


func begin() -> void:
	var s: Vector3 = world.coast.spots.get("telescope", actor.global_position)
	var to_bank := (CoastLayout.SANDBANK - Vector2(s.x, s.z)).normalized()
	eye = s + Vector3(to_bank.x * 0.75, 1.45, to_bank.y * 0.75)
	# First towards the sandbank and its seals.
	var bank := CoastLayout.SANDBANK
	yaw = atan2(bank.x - eye.x, bank.y - eye.z)
	pitch = -0.03
	actor.visible = false
	t = 0.0
	_fov = game.camera.fov
	game.camera.fov = FOV
	mask = Vignette.new()
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(mask)
	hud.move_child(mask, 0)
	set_info("Dreh das Fernrohr mit „Links“ und „Rechts“ (oder A/D), neige es mit „Hoch“ und „Runter“. Vor dir liegen die Robben auf der Sandbank.")
	for b: Array in [["Links", -1.0, 0.0], ["Hoch", 0.0, 1.0], ["Runter", 0.0, -1.0], ["Rechts", 1.0, 0.0]]:
		var btn := add_button(b[0], func() -> void: pass, 110)
		var dx: float = b[1]
		var dy: float = b[2]
		btn.button_down.connect(func() -> void:
			turn = dx if dx != 0.0 else turn
			tilt = dy if dy != 0.0 else tilt)
		btn.button_up.connect(func() -> void:
			turn = 0.0 if dx != 0.0 else turn
			tilt = 0.0 if dy != 0.0 else tilt)
	add_button("Fertig", func() -> void: _done(), 140)
	GameState.add_stat("telescope")


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	var stick := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var dx := turn if turn != 0.0 else stick.x
	var dy := tilt if tilt != 0.0 else stick.y
	yaw -= dx * TURN * delta
	pitch = clampf(pitch + dy * TURN * 0.6 * delta, -0.25, 0.2)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	look(eye, eye + dir * 100.0)
	set_score("Noch %d s" % ceili(maxf(DURATION - t, 0.0)))
	if t >= DURATION:
		_done()


func _done() -> void:
	if active:
		end({"won": true, "joy": 12.0, "text": "Klack – die Klappe fällt zu. Ganz nah dran war das!"})


func cleanup() -> void:
	actor.visible = true
	game.camera.fov = _fov
	if is_instance_valid(mask):
		mask.queue_free()
	mask = null


## The round view of the telescope: black outside a circle.
class Vignette extends Control:
	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.46
		var pts := PackedVector2Array()
		for k in 49:
			var a := TAU * k / 48.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		# Four dark quads round the circle (as polygons between the circle and the edges).
		var big := maxf(size.x, size.y)
		for q in 4:
			var poly := PackedVector2Array()
			for k in 13:
				var a := TAU * (q * 12 + k) / 48.0
				poly.append(c + Vector2(cos(a), sin(a)) * r)
			for k in range(12, -1, -1):
				var a := TAU * (q * 12 + k) / 48.0
				poly.append(c + Vector2(cos(a), sin(a)) * big)
			draw_colored_polygon(poly, Color(0.02, 0.03, 0.05))
		draw_polyline(pts, Color(0.1, 0.1, 0.12), 6.0)

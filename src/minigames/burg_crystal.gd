class_name BurgCrystal
extends Minigame
## Meister Morwen's crystal ball (doc/burg.md): the ball lights up in a row of colours; repeat it
## with the colour buttons. Each round the row grows by one; a mistake ends the game. 0,50 € per
## round from the fourth on. "Gedächtnis eines Zauberers": a row of eight.

const COLORS := {"Rot": Color("ff4a3a"), "Blau": Color("3a8aff"), "Grün": Color("4ae05a"), "Gelb": Color("ffd23a")}
const START := 3
const ON := 0.6
const OFF := 0.25

var row: Array[String] = []
var typed := 0
var state := "show"             # show, input, done
var t := 0.0
var shown := 0
var ball: MeshInstance3D
var ball_pos := Vector3.ZERO
var best := 0


func _init() -> void:
	title = "Die Kristallkugel"
	host_id = "morwen"
	cost = 100


func describe() -> String:
	return "Merk dir die Lichter in Meister Morwens Kristallkugel. Einsatz 1 €."


func goal_done() -> bool:
	return GameState.stat("crystal_best") >= 8


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.burg != null


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "In die Kristallkugel schauen (%s)" % GameState.format_money(cost)


func begin() -> void:
	var mg := BurgLayout.place("magician")
	ball_pos = Vector3(mg.x, world.map.walk_height(mg.x, mg.y) + 1.05, mg.y) + Vector3(0, 0, 0.3).rotated(Vector3.UP, PI * 0.25)
	ball = MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.use("glow")
	kit.sphere(Vector3.ZERO, Vector3(0.24, 0.24, 0.24), Color.WHITE, 4, 9)
	ball.mesh = kit.commit()
	add_child(ball)
	ball.global_position = ball_pos
	ball.visible = false
	var front := ball_pos + Vector3(0, 0, 2.0).rotated(Vector3.UP, PI * 0.25)
	actor.teleport(Vector3(front.x, world.map.walk_height(front.x, front.z), front.z))
	actor.face(ball_pos, true)
	var h := host()
	if h:
		# Morwen on his chair behind the ball.
		var chair := Vector3(mg.x, world.map.walk_height(mg.x, mg.y), mg.y) + Vector3(0, 0, -0.75).rotated(Vector3.UP, PI * 0.25)
		h.teleport(chair)
		h.face(ball_pos, true)
	look(ball_pos + Vector3(1.1, 0.7, 1.4).rotated(Vector3.UP, PI * 0.25), ball_pos + Vector3(0, -0.1, 0))
	row.clear()
	for i in START:
		row.append(COLORS.keys()[rng.randi() % 4])
	best = 0
	host_say("Schau in die Kugel … und merk dir, was du siehst.", 3.0)
	set_info("Die Kugel leuchtet in einer Reihe von Farben. Tippe sie danach in derselben Reihe.")
	for c: String in COLORS:
		var b := add_button(c, func() -> void: press_color(c), 120)
		b.modulate = COLORS[c].lightened(0.3)
	_start_show()


func _start_show() -> void:
	state = "show"
	t = -0.6
	shown = 0
	typed = 0
	set_score("Reihe: %d Farben" % row.size())


func _process(delta: float) -> void:
	if not active or state != "show":
		return
	t += delta
	if t < 0.0:
		return
	var i := int(t / (ON + OFF))
	var phase := fmod(t, ON + OFF)
	if i >= row.size():
		ball.visible = false
		state = "input"
		set_info("Jetzt du: %d Farben." % row.size())
		return
	ball.visible = phase < ON
	if ball.visible:
		ball.material_override = _mat(COLORS[row[i]])


static var _mats := {}


static func _mat(c: Color) -> Material:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.6
		_mats[key] = m
	return _mats[key]


func press_color(c: String) -> void:
	if state != "input":
		return
	ball.visible = true
	ball.material_override = _mat(COLORS[c])
	var s := session
	get_tree().create_timer(0.25, false).timeout.connect(func() -> void:
		if still_running(s) and state == "input":
			ball.visible = false)
	if row[typed] != c:
		state = "done"
		Sound.play("fail", ball_pos)
		_finish()
		return
	typed += 1
	Sound.play("click", ball_pos)
	if typed >= row.size():
		best = row.size()
		Sound.play("coin", ball_pos)
		host_say(["Gut gesehen.", "Die Kugel ist zufrieden.", "Bemerkenswert …"][rng.randi() % 3], 1.8)
		row.append(COLORS.keys()[rng.randi() % 4])
		_start_show()


func _finish() -> void:
	GameState.set_stat_max("crystal_best", best)
	var rounds := maxi(0, best - START)
	var per := 100 if BurgStories.staff() >= 7 else 50   # the staff shines again: Morwen pays double
	end_after(1.2, {"won": best >= 6, "money": rounds * per, "joy": 10.0 + best,
		"text": "Du hast dir eine Reihe von %d Farben gemerkt. %s" % [best,
			"Morwen hebt eine Augenbraue: „Ein Gedächtnis wie ein Zauberer.“" if best >= 8 else "Morwen murmelt: „Die Kugel vergisst nichts. Du schon.“"]})


func cleanup() -> void:
	if ball:
		ball.queue_free()
		ball = null

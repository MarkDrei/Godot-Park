class_name CoastGulls
extends Minigame
## Möwenalarm at Uwe's fish stand (doc/moewenbucht.md): three fish rolls lie on the counter and
## the gulls want them. A gull that dives at a roll shows a red ring with "!" over it; the
## button below that roll ("Links", "Mitte", "Rechts", or the keys A, S, D) shoos it away before
## it gets there. A press where no gull comes costs nothing. 45 seconds; the gulls come faster;
## the rolls left at the end count.

const DURATION := 45.0
const SIDES := ["Links", "Mitte", "Rechts"]

var counter := Vector3.ZERO
var rolls: Array[MeshInstance3D] = []
var alive := [true, true, true]
var warnings: Array[Node3D] = []
var gulls: Array[Dictionary] = []      # {node, roll, t, dur, from, state}
var t := 0.0
var next_gull := 1.5
var shooed := 0
var _cue_t := 0.0
var done := false
var pace := 1.0                        # < 1 slows the gulls (tests)


func _init() -> void:
	title = "Möwenalarm"
	host_id = "uwe"
	cost = 0


func describe() -> String:
	return "Pass bei Fischbrötchen-Uwe auf die Brötchen auf: Kommt eine Möwe (roter Ring), drück den Knopf darunter."


func goal_done() -> bool:
	return GameState.stat("gulls_all_rolls") > 0


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.coast != null


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Auf die Fischbrötchen aufpassen"


func roll_pos(i: int) -> Vector3:
	return counter + Vector3((i - 1) * 1.15, 0, 0)


func begin() -> void:
	var st := CoastLayout.place("fish_stand")
	counter = Vector3(st.x, world.map.height_at(st.x, st.y) + 1.2, st.y + 1.4)
	# Beside the stand, out of the camera's way to the rolls.
	actor.teleport(Vector3(st.x - 2.6, 0, st.y + 2.4))
	actor.face(counter, true)
	alive = [true, true, true]
	done = false
	t = 0.0
	next_gull = 1.5
	shooed = 0
	rolls.clear()
	warnings.clear()
	for i in 3:
		var r := MeshInstance3D.new()
		r.mesh = CoastModels.fish_roll()
		r.position = roll_pos(i)
		world.add_child(r)
		rolls.append(r)
		var w := Node3D.new()
		var ring := MeshInstance3D.new()
		var kit := MeshKit.new()
		kit.use("glow")
		kit.torus(Vector3.ZERO, 0.36, 0.05, 18, 3, Color("ff3b30"))
		ring.mesh = kit.commit()
		w.add_child(ring)
		var mark := Label3D.new()
		mark.text = "!"
		mark.font_size = 140
		mark.pixel_size = 0.006
		mark.outline_size = 22
		mark.modulate = Color("ff3b30")
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.no_depth_test = true
		mark.position = Vector3(0, 0.55, 0)
		w.add_child(mark)
		w.position = roll_pos(i) + Vector3(0, 0.12, 0)
		w.visible = false
		world.add_child(w)
		warnings.append(w)
	look(counter + Vector3(0.0, 1.2, 5.6), counter + Vector3(0, 1.0, 0))
	host_say("Pass auf meine Brötchen auf! Die Möwen sind frech!", 3.0)
	set_info("Stürzt sich eine Möwe auf ein Brötchen, leuchtet darüber ein ROTER Ring mit „!“: drück den Knopf darunter (Links, Mitte, Rechts – oder A, S, D) und sie fliegt weg. 45 Sekunden!")
	for i in 3:
		var side := i
		add_button(SIDES[i], func() -> void: shoo(side), 170)
	_update_score()


func _update_score() -> void:
	set_score("Brötchen: %d von 3  ·  Verscheucht: %d  ·  noch %d s" % [alive.count(true), shooed, ceili(maxf(DURATION - t, 0.0))])


func _process(delta: float) -> void:
	if not active or done:
		return
	_cue_t -= delta
	if _cue_t <= 0.0:
		set_cue("")
	t += delta
	show_power(clampf(t / DURATION, 0.0, 1.0))
	if t < DURATION:
		next_gull -= delta
		if next_gull <= 0.0:
			_spawn()
			next_gull = lerpf(3.0, 1.4, t / DURATION) / pace
	for g: Dictionary in gulls.duplicate():
		_move(g, delta)
	for i in 3:
		warnings[i].visible = alive[i] and gulls.any(func(g: Dictionary) -> bool: return g["roll"] == i and g["state"] == "dive")
		if warnings[i].visible:
			warnings[i].rotation.y += delta * 3.0
	_update_score()
	if (t >= DURATION and gulls.is_empty()) or alive.count(true) == 0:
		_finish()


## A gull dives at a roll that is left (not one another gull is already after, if possible).
func _spawn() -> void:
	var free := []
	for i in 3:
		if alive[i] and not gulls.any(func(g: Dictionary) -> bool: return g["roll"] == i):
			free.append(i)
	if free.is_empty():
		return
	var roll: int = free[rng.randi() % free.size()]
	var node := MeshInstance3D.new()
	node.mesh = CoastModels.gull_mesh()
	world.add_child(node)
	# From the sky beside the stand (seen below the panel), not from straight above.
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var from := counter + Vector3(side * rng.randf_range(3.5, 5.5), rng.randf_range(3.0, 4.2), rng.randf_range(-3.0, 0.5))
	node.position = from
	var dur := lerpf(2.6, 1.6, t / DURATION) / pace
	gulls.append({"node": node, "roll": roll, "t": 0.0, "dur": dur, "from": from, "state": "dive"})
	Sound.play("gull", from, -4.0)


func _move(g: Dictionary, delta: float) -> void:
	var node: MeshInstance3D = g["node"]
	g["t"] += delta
	if g["state"] == "dive":
		var k: float = clampf(g["t"] / g["dur"], 0.0, 1.0)
		var to := roll_pos(g["roll"]) + Vector3(0, 0.2, 0)
		var p: Vector3 = (g["from"] as Vector3).lerp(to, k * k * (3.0 - 2.0 * k))
		node.look_at_from_position(p, to + Vector3(0, -0.5, 0) if p.distance_to(to) > 0.3 else to + Vector3(0, 0, 1))
		node.position = p
		if k >= 1.0:
			_steal(g)
	else:
		node.position += Vector3(0, 4.0, -3.0) * delta
		if g["t"] > 1.6:
			node.queue_free()
			gulls.erase(g)


## The button below roll i: shoos a gull diving at it; nothing when none comes.
func shoo(i: int) -> void:
	if not active:
		return
	actor.play_anim("wave", 0.5)
	var g: Dictionary = {}
	for o: Dictionary in gulls:
		if o["roll"] == i and o["state"] == "dive":
			g = o
	if g.is_empty():
		return
	g["state"] = "away"
	g["t"] = 0.0
	shooed += 1
	Sound.play("flap", (g["node"] as Node3D).position)
	_flash("Husch!", Color("4ee05a"))


func _steal(g: Dictionary) -> void:
	var i: int = g["roll"]
	alive[i] = false
	rolls[i].visible = false
	g["state"] = "away"
	g["t"] = 0.0
	Sound.play("gull", roll_pos(i))
	_flash("Geklaut! (%s)" % SIDES[i], UiTheme.RED)
	host_say(["Ey! Mein Brötchen!", "Diese Diebe!", "Schon wieder eins weg!"][rng.randi() % 3], 1.6)


func _flash(text: String, color: Color) -> void:
	set_cue(text, color)
	_cue_t = 0.8


func _finish() -> void:
	if not active or done:
		return
	done = true
	var left: int = alive.count(true)
	if left == 3:
		GameState.add_stat("gulls_all_rolls")
	var money: int = [0, 0, 100, 300][left]
	end_after(1.0, {"won": left >= 2, "money": money, "joy": 8.0 + left * 4.0,
		"text": "%d von 3 Brötchen gerettet, %d Möwen verscheucht.\n\nUwe: „%s“" % [left, shooed,
			["Alle weg! Die Möwen feiern heute.", "Eins ist übrig. Immerhin.", "Zwei gerettet, gut aufgepasst!", "Alle drei! Du bist der beste Möwenschreck der Küste!"][left]]})


func cleanup() -> void:
	set_cue("")
	for g: Dictionary in gulls:
		if is_instance_valid(g["node"]):
			(g["node"] as Node).queue_free()
	gulls.clear()
	for n in rolls + warnings:
		if is_instance_valid(n):
			n.queue_free()
	rolls.clear()
	warnings.clear()


func game_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		match k.keycode:
			KEY_A: shoo(0)
			KEY_S: shoo(1)
			KEY_D: shoo(2)

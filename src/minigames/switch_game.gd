class_name SwitchGame
extends Minigame
## Switchman at the dwarves' mine with Zwerg Thrain: carts roll out of the mountain to a
## switch. Ore and gems go right to the smelter, rock goes left to the dump. Action (or
## the button) flips the switch. Three wrong carts end the shift.

const MISTAKES := 3
const MAX_CARTS := 40
## Track from the mine portal to the switch, and the two branches after it.
const IN := [Vector2(74, -251.0), Vector2(73, -243)]
const LEFT := [Vector2(73, -243), Vector2(68, -236)]                       # dump (rock)
const RIGHT := [Vector2(73, -243), Vector2(84, -246), Vector2(94, -247)]   # smelter (ore, gems)

var switch_right := true
var carts: Array[Dictionary] = []    # {node, kind, d (metres along), branch ("" until the switch)}
var spawn_in := 1.0
var spawned := 0
var correct := 0
var mistakes := 0
var speed := 2.6
var state := "play"
var arrow: MeshInstance3D
var labels: Array[Node3D] = []
var junction := Vector3.ZERO


func _init() -> void:
	title = "Stellwerk mit Thrain"
	host_id = "thrain"


func describe() -> String:
	return "Stell die Weiche: Erz und Edelsteine zur Schmelze (rechts), Geröll auf die Halde (links). Thrain wartet am Stellwerk."


func _h(p: Vector2) -> Vector3:
	return Vector3(p.x, world.map.height_at(p.x, p.y) + 0.1, p.y)


func begin() -> void:
	junction = _h(IN[1])
	var tower := Vector2(98, -240)
	actor.teleport(_h(tower + Vector2(-2.6, 1.5)))
	actor.face(junction, true)
	var h := host()
	if h:
		h.teleport(_h(tower + Vector2(-2.6, 3.2)))
		h.face(junction)
		host_say("Erz nach rechts, Geröll nach links. Glück auf!", 3.5)
	look(junction + Vector3(4.0, 11.0, 11.0), junction + Vector3(4.0, 0, -2.0))
	for n in get_tree().get_nodes_in_group("decor_carts"):
		(n as Node3D).visible = false
	arrow = MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.use("glow")
	kit.box(Vector3(0, 0, 0.6), Vector3(0.18, 0.05, 1.2), Color("ffd84a"))
	kit.cylinder(Vector3(0, -0.03, 1.2), 0.06, 0.32, 0.0, 3, Color("ffd84a"))
	arrow.mesh = kit.commit()
	add_child(arrow)
	_label("SCHMELZE", RIGHT[2] + Vector2(0, -1.5))
	_label("HALDE", LEFT[1] + Vector2(-1.5, 0))
	switch_right = true
	carts.clear()
	spawn_in = 1.0
	spawned = 0
	correct = 0
	mistakes = 0
	speed = 2.6
	state = "play"
	_show_switch()
	set_info("Aktion, Leertaste oder „Weiche!“ stellt um. Rostbraunes Erz und Edelsteine nach rechts, graues Geröll nach links.")
	add_button("Weiche!", func() -> void: flip(), 220)
	_update_score()


func _label(text: String, p: Vector2) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 12
	l.position = _h(p) + Vector3(0, 1.6, 0)
	add_child(l)
	labels.append(l)


func _show_switch() -> void:
	var target: Vector2 = RIGHT[1] if switch_right else LEFT[1]
	var d := target - IN[1]
	arrow.global_position = junction + Vector3(0, 0.5, 0)
	arrow.rotation = Vector3(0, atan2(d.x, d.y), 0)


func flip() -> void:
	if not active or state != "play":
		return
	switch_right = not switch_right
	_show_switch()
	Sound.play("click", junction)


func _update_score() -> void:
	set_score("Richtig: %d  ·  Fehler: %d / %d  ·  Weiche: %s" % [correct, mistakes, MISTAKES, "rechts" if switch_right else "links"])


func _process(delta: float) -> void:
	if not active or state != "play":
		return
	spawn_in -= delta
	if spawn_in <= 0.0 and spawned < MAX_CARTS:
		_spawn()
		spawn_in = maxf(1.5, 3.4 - spawned * 0.08)
		speed = minf(5.0, 2.6 + spawned * 0.06)
	for c: Dictionary in carts.duplicate():
		c["d"] += speed * delta
		var path := _path(c)
		var pos := _along(path, c["d"])
		var node: Node3D = c["node"]
		node.global_position = _h(pos)
		var ahead := _along(path, c["d"] + 0.5)
		node.rotation.y = atan2(ahead.x - pos.x, ahead.y - pos.y)
		if c["branch"] == "" and c["d"] >= _length(IN):
			c["branch"] = "right" if switch_right else "left"
			_judge(c)
		if c["d"] >= _length(path):
			node.queue_free()
			carts.erase(c)
	if (mistakes >= MISTAKES or (spawned >= MAX_CARTS and carts.is_empty())) and state == "play":
		_finish()


func _path(c: Dictionary) -> Array:
	var p: Array = IN.duplicate()
	var branch: String = c["branch"]
	if branch == "":
		branch = "right" if switch_right else "left"
	p.append_array((RIGHT if branch == "right" else LEFT).slice(1))
	return p


static func _length(pts: Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += (pts[i] as Vector2).distance_to(pts[i - 1])
	return l


static func _along(pts: Array, d: float) -> Vector2:
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var l := a.distance_to(b)
		if d <= l:
			return a.lerp(b, d / l)
		d -= l
	return pts[pts.size() - 1]


func _spawn() -> void:
	var r := randf()
	var kind := "gems" if r < 0.1 else ("ore" if r < 0.55 else "rock")
	var mi := MeshInstance3D.new()
	mi.mesh = ForestModels.mine_cart(kind)
	add_child(mi)
	carts.append({"node": mi, "kind": kind, "d": 0.0, "branch": ""})
	spawned += 1


## The cart that comes next to the switch (for tests and the hint).
func next_cart() -> Dictionary:
	var best := {}
	for c: Dictionary in carts:
		if c["branch"] == "" and (best.is_empty() or c["d"] > best["d"]):
			best = c
	return best


static func wants_right(kind: String) -> bool:
	return kind != "rock"


func _judge(c: Dictionary) -> void:
	var ok: bool = (c["branch"] == "right") == wants_right(c["kind"])
	if ok:
		correct += 2 if c["kind"] == "gems" else 1
		Sound.play("coin", junction, -6.0)
		if c["kind"] == "gems":
			host_say("Edelsteine! Prima!", 1.5)
	else:
		mistakes += 1
		Sound.play("fail", junction, -4.0)
		host_say(["Falsche Weiche!", "Das Erz landet auf der Halde!", "Geröll in der Schmelze?!"][mistakes % 3], 2.0)
	_update_score()


func _finish() -> void:
	state = "done"
	GameState.set_stat_max("switch_best", correct)
	var won := correct >= 15
	end_after(1.5, {"won": won, "money": correct * 15, "joy": 20.0 if won else 10.0,
		"text": "%d Loren richtig verteilt! %s" % [correct, "Thrain nickt anerkennend." if won else "Thrain: „Das üben wir noch.“"]})


func game_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_SPACE):
		flip()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if not UI.point_blocked((event as InputEventMouseButton).position):
			flip()


func cleanup() -> void:
	for c: Dictionary in carts:
		if is_instance_valid(c["node"]):
			(c["node"] as Node3D).queue_free()
	carts.clear()
	for l in labels:
		l.queue_free()
	labels.clear()
	if is_instance_valid(arrow):
		arrow.queue_free()
	for n in get_tree().get_nodes_in_group("decor_carts"):
		(n as Node3D).visible = true

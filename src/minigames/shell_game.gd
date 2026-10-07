class_name ShellGame
extends Minigame
## Hütchenspiel with Hütchen-Harry: follow the cup with the nut. 2 € stake, win 4 €.

var cups: Array[MeshInstance3D] = []
var slots: Array[int] = [0, 1, 2]     # cup index at slot position
var nut_cup := 0
var nut_node: MeshInstance3D
var table_pos := Vector3.ZERO
var table_yaw := 0.0
var state := "show"
var t := 0.0
var swaps_left := 0
var swap_a := -1
var swap_b := -1
var swap_t := 0.0
var swap_dur := 0.5
var round_no := 0
var picked := -1


func _init() -> void:
	title = "Hütchenspiel"
	host_id = "harry"
	cost = 200


func describe() -> String:
	return "Finde die Nuss unter dem richtigen Becher. Einsatz 2 €, Gewinn 4 €. Hütchen-Harry steht am Südtor."


func _slot_pos(slot: int) -> Vector3:
	var right := Vector3(cos(table_yaw), 0, -sin(table_yaw))
	return table_pos + right * (1 - slot) * 0.3


func begin() -> void:
	table_pos = world.shell_table["pos"]
	table_yaw = world.shell_table["yaw"]
	var fwd := Vector3(sin(table_yaw), 0, cos(table_yaw))
	var right := Vector3(cos(table_yaw), 0, -sin(table_yaw))
	actor.teleport(table_pos + fwd * 0.9 - right * 0.6)
	actor.face(table_pos, true)
	var h := host()
	if h:
		h.teleport(table_pos - fwd * 0.75)
		h.face(table_pos, true)
		h.say("Pass gut auf! Wo ist die Nuss?", 3.0)
	look(table_pos + fwd * 1.5 + right * 0.25 + Vector3(0, 0.95, 0), table_pos)
	for i in 3:
		var c := MeshInstance3D.new()
		c.mesh = PropModels.cup()
		add_child(c)
		cups.append(c)
	nut_node = MeshInstance3D.new()
	nut_node.mesh = PropModels.item("nut")
	add_child(nut_node)
	round_no = 0
	_new_round()
	add_button("Links", func() -> void: _pick(0), 140)
	add_button("Mitte", func() -> void: _pick(1), 140)
	add_button("Rechts", func() -> void: _pick(2), 140)


func _new_round() -> void:
	round_no += 1
	slots = [0, 1, 2]
	nut_cup = randi() % 3
	for i in 3:
		cups[i].global_position = _slot_pos(i)
	state = "show"
	t = 0.0
	picked = -1
	swaps_left = 5 + round_no * 2
	swap_dur = maxf(0.18, 0.5 - round_no * 0.07)
	set_info("Die Nuss liegt unter einem Becher … gleich wird gemischt!")
	set_score("Runde %d  ·  Serie: %d" % [round_no, GameState.stat("shell_streak_now")])


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	match state:
		"show":
			# Lift the cup with the nut so the player sees it.
			var lift := sin(clampf(t / 1.6, 0.0, 1.0) * PI) * 0.25
			for i in 3:
				var slot := slots.find(i)
				cups[i].global_position = _slot_pos(slot) + Vector3(0, lift if i == nut_cup else 0.0, 0)
			nut_node.global_position = _slot_pos(slots.find(nut_cup)) + Vector3(0, 0.03, 0)
			nut_node.visible = true
			if t > 1.8:
				state = "shuffle"
				nut_node.visible = false
				_next_swap()
		"shuffle":
			swap_t += delta / swap_dur
			var k := clampf(swap_t, 0.0, 1.0)
			var ca := slots[swap_a]
			var cb := slots[swap_b]
			var pa := _slot_pos(swap_a)
			var pb := _slot_pos(swap_b)
			var fwd := Vector3(sin(table_yaw), 0, cos(table_yaw))
			cups[ca].global_position = pa.lerp(pb, k) + fwd * sin(k * PI) * 0.12
			cups[cb].global_position = pb.lerp(pa, k) - fwd * sin(k * PI) * 0.12
			if k >= 1.0:
				slots[swap_a] = cb
				slots[swap_b] = ca
				swaps_left -= 1
				if swaps_left <= 0:
					state = "pick"
					set_info("Wo ist die Nuss? Wähle einen Becher (1/2/3 oder Knöpfe).")
				else:
					_next_swap()
		"reveal":
			var lift2 := sin(clampf(t / 1.2, 0.0, 1.0) * PI * 0.5) * 0.25
			for slot in 3:
				cups[slots[slot]].global_position = _slot_pos(slot) + Vector3(0, lift2 if slot == picked or slots[slot] == nut_cup else 0.0, 0)
			nut_node.global_position = _slot_pos(slots.find(nut_cup)) + Vector3(0, 0.03, 0)
			nut_node.visible = true


func _next_swap() -> void:
	swap_a = randi() % 3
	swap_b = (swap_a + 1 + randi() % 2) % 3
	swap_t = 0.0
	Sound.play("click", table_pos, -10.0)


func _pick(slot: int) -> void:
	if state != "pick":
		return
	picked = slot
	state = "reveal"
	t = 0.0
	var won := slots[slot] == nut_cup
	var h := host()
	if won:
		GameState.set_stat("shell_streak_now", GameState.stat("shell_streak_now") + 1)
		GameState.set_stat_max("shell_streak", GameState.stat("shell_streak_now"))
		if h:
			h.say(["Was?! Glück gehabt!", "Na gut, na gut …", "Du hast Adleraugen!"][randi() % 3], 2.5)
		await get_tree().create_timer(1.8).timeout
		end({"won": true, "money": 400, "joy": 25.0, "text": "Richtig! Die Nuss war unter dem Becher. Du gewinnst 4 €!"})
	else:
		GameState.set_stat("shell_streak_now", 0)
		if h:
			h.say(["Haha! Nächstes Mal!", "Zu langsam, Freundchen!", "Die Hand ist schneller als das Auge!"][randi() % 3], 2.5)
			h.play_anim("cheer", 1.5)
		await get_tree().create_timer(1.8).timeout
		end({"won": false, "joy": 8.0, "text": "Leider daneben – die Nuss war woanders. Harry grinst."})


func game_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_1: _pick(0)
			KEY_2: _pick(1)
			KEY_3: _pick(2)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var pos := (event as InputEventMouseButton).position
		if UI.point_blocked(pos):
			return
		var best := -1
		var best_d := 80.0
		for slot in 3:
			var sp: Vector2 = game.camera.unproject_position(_slot_pos(slot) + Vector3(0, 0.1, 0))
			var d: float = sp.distance_to(pos)
			if d < best_d:
				best_d = d
				best = slot
		if best >= 0:
			_pick(best)


func cleanup() -> void:
	for c in cups:
		c.queue_free()
	cups.clear()
	if nut_node:
		nut_node.queue_free()
		nut_node = null

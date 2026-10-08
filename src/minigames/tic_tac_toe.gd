class_name TicTacToeGame
extends Minigame
## Giant tic-tac-toe against Boris (who claims chess is too tiring today).
## Boris plays minimax but gets distracted now and then.

var board: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]   # 0 empty, 1 player (X), 2 Boris (O)
var marks: Array[MeshInstance3D] = []
var center := Vector3.ZERO
var turn := 1
var _wait := 0.0
var _over := false

const LINES := [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]


func _init() -> void:
	title = "Riesen-Tic-Tac-Toe gegen Boris"
	host_id = "boris"


func describe() -> String:
	return "Boris ist heute zu müde für Schach. Schlag ihn im Tic-Tac-Toe auf dem Riesenbrett in der Schachecke!"


func cell_pos(i: int) -> Vector3:
	return center + Vector3((i % 3 - 1) * 1.4, 0, (i / 3 - 1) * 1.4)


func begin() -> void:
	center = world.giant_board
	board = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	_over = false
	actor.teleport(center + Vector3(0, 0, 3.2))
	actor.face(center, true)
	var h := host()
	if h:
		h.teleport(center + Vector3(2.8, 0, 0.5))
		h.face(center)
		h.say("Tic-Tac-Toe? Na gut. Du fängst an.", 3.0)
	look(center + Vector3(0, 6.5, 4.2), center)
	turn = 1
	set_info("Wähle ein Feld: Klick/Tippen oder Ziffern 1–9 (wie auf dem Ziffernblock: 1 = vorne links).")
	set_score("Du: Kreuz  ·  Boris: Kreis")


func _place(i: int, who: int) -> void:
	board[i] = who
	var m := MeshInstance3D.new()
	m.mesh = PropModels.giant_mark(who == 1)
	add_child(m)
	m.global_position = cell_pos(i) + Vector3(0, 0.6, 0)
	var tw := create_tween()
	tw.tween_property(m, "global_position", cell_pos(i), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	marks.append(m)
	Sound.play("hit", cell_pos(i), -4.0)


static func winner(b: Array) -> int:
	for l: Array in LINES:
		if b[l[0]] != 0 and b[l[0]] == b[l[1]] and b[l[1]] == b[l[2]]:
			return b[l[0]]
	if not b.has(0):
		return 3
	return 0


static func minimax(b: Array, who: int) -> Array:
	var w := winner(b)
	if w == 2:
		return [10, -1]
	if w == 1:
		return [-10, -1]
	if w == 3:
		return [0, -1]
	var best := [-100 if who == 2 else 100, -1]
	for i in 9:
		if b[i] != 0:
			continue
		b[i] = who
		var r: Array = minimax(b, 3 - who)
		b[i] = 0
		var score: int = r[0]
		if who == 2 and score > best[0] or who == 1 and score < best[0]:
			best = [score, i]
	return best


func _player_move(i: int) -> void:
	if _over or turn != 1 or i < 0 or i > 8 or board[i] != 0:
		return
	_place(i, 1)
	if _check():
		return
	turn = 2
	_wait = 1.0


func _boris_move() -> void:
	var free: Array[int] = []
	for i in 9:
		if board[i] == 0:
			free.append(i)
	var choice: int
	if randf() < 0.28:
		choice = free[randi() % free.size()]
		var h := host()
		if h:
			h.say(["Hmm, war das klug?", "Ich bin heute nicht in Form.", "Ups."][randi() % 3], 2.0)
	else:
		choice = minimax(board.duplicate(), 2)[1]
	_place(choice, 2)
	if not _check():
		turn = 1


func _check() -> bool:
	var w := winner(board)
	if w == 0:
		return false
	_over = true
	_end_game(w)
	return true


func _end_game(w: int) -> void:
	var h := host()
	var s := session
	await get_tree().create_timer(1.3).timeout
	if not still_running(s):
		return
	match w:
		1:
			GameState.add_stat("ttt_wins")
			if h:
				h.say("Unmöglich! Revanche!", 3.0)
			end({"won": true, "money": 400, "joy": 30.0, "text": "Drei in einer Reihe – du hast Boris geschlagen!"})
		2:
			if h:
				h.say("Seit 1983 ungeschlagen!", 3.0)
				h.play_anim("cheer", 2.0)
			end({"won": false, "joy": 12.0, "text": "Boris gewinnt. Er wirkt sehr zufrieden mit sich."})
		3:
			if h:
				h.say("Remis. Respekt.", 3.0)
			end({"won": false, "money": 100, "joy": 20.0, "text": "Unentschieden! Boris nickt anerkennend."})


func _process(delta: float) -> void:
	if not active or _over:
		return
	if turn == 2:
		_wait -= delta
		if _wait <= 0.0:
			_boris_move()


func game_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k := (event as InputEventKey).keycode
		var map := {KEY_1: 6, KEY_2: 7, KEY_3: 8, KEY_4: 3, KEY_5: 4, KEY_6: 5, KEY_7: 0, KEY_8: 1, KEY_9: 2,
			KEY_KP_1: 6, KEY_KP_2: 7, KEY_KP_3: 8, KEY_KP_4: 3, KEY_KP_5: 4, KEY_KP_6: 5, KEY_KP_7: 0, KEY_KP_8: 1, KEY_KP_9: 2}
		if map.has(k):
			_player_move(map[k])
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var pos := (event as InputEventMouseButton).position
		if UI.point_blocked(pos):
			return
		var p: Vector3 = game.camera.ground_point(pos)
		if p == Vector3.INF:
			return
		var best := -1
		var best_d := 0.8
		for i in 9:
			var d := Vector2(p.x - cell_pos(i).x, p.z - cell_pos(i).z).length()
			if d < best_d:
				best_d = d
				best = i
		_player_move(best)


func cleanup() -> void:
	for m in marks:
		m.queue_free()
	marks.clear()

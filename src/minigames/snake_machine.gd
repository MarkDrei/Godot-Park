class_name SnakeMachine
extends ArcadeGame
## Schlangenfraß: steer the snake to the cherries; it grows with every one and gets faster.
## Walls and its own tail end the game.

const GRID := Vector2i(24, 18)
const CELL := 10.0
var body: Array[Vector2i] = []
var dir := Vector2i(1, 0)
var _next := Vector2i(1, 0)
var food := Vector2i.ZERO
var _move := 0.0
var _speed := 7.0             # cells per second


func _init() -> void:
	super()
	title = "Schlangenfraß"
	machine = "snake"


func describe() -> String:
	return "Automat in der Spielhalle: Lenk die Schlange zu den Kirschen. 50 Cent, Tickets nach Punkten."


func reset_game() -> void:
	body = [Vector2i(8, 9), Vector2i(7, 9), Vector2i(6, 9)]
	dir = Vector2i(1, 0)
	_next = dir
	_speed = 7.0
	_move = 0.0
	_place_food()


func _place_food() -> void:
	for i in 200:
		var f := Vector2i(rng.randi_range(0, GRID.x - 1), rng.randi_range(0, GRID.y - 1))
		if not f in body:
			food = f
			return


func steer(d: Vector2i) -> void:
	if d != -dir:
		_next = d


func step(dt: float) -> void:
	if keys["left"]:
		steer(Vector2i(-1, 0))
	elif keys["right"]:
		steer(Vector2i(1, 0))
	elif keys["up"]:
		steer(Vector2i(0, -1))
	elif keys["down"]:
		steer(Vector2i(0, 1))
	_move += dt * _speed
	if _move < 1.0:
		return
	_move -= 1.0
	dir = _next
	var head := body[0] + dir
	if head.x < 0 or head.y < 0 or head.x >= GRID.x or head.y >= GRID.y or head in body.slice(0, body.size() - 1):
		over = true
		Sound.play("fail", null, -6.0)
		return
	body.push_front(head)
	if head == food:
		score += 10
		_speed = minf(_speed + 0.35, 16.0)
		Sound.play("pickup", null, -8.0)
		_place_food()
	else:
		body.pop_back()


func draw_screen(c: Control, s: float) -> void:
	block(c, s, 0, 0, SCREEN.x, SCREEN.y, Color("0c1a0c"))
	block(c, s, food.x * CELL + 2, food.y * CELL + 2, CELL - 4, CELL - 4, Color("ff3a4a"))
	block(c, s, food.x * CELL + 5, food.y * CELL, 2, 3, Color("4fd84f"))
	for i in body.size():
		var b := body[i]
		block(c, s, b.x * CELL + 1, b.y * CELL + 1, CELL - 2, CELL - 2, Color("9cff6a") if i == 0 else Color("4fd84f").darkened(float(i % 3) * 0.08))


func controls() -> Array:
	return [["Links", "left"], ["Hoch", "up"], ["Runter", "down"], ["Rechts", "right"]]


func help_text() -> String:
	return "Lenken: W/A/S/D oder die Knöpfe. Nicht in die Wand, nicht in den Schwanz!"


func score_tickets() -> int:
	return score / 30

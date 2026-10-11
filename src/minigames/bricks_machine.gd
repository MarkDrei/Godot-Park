class_name BricksMachine
extends ArcadeGame
## Ziegelbrecher: keep the ball in play with the paddle and break all the bricks. Three balls;
## a cleared wall brings a new, faster one.

const COLS := 10
const ROWS := 5
var paddle_x := 120.0
var ball := Vector2.ZERO
var vel := Vector2.ZERO
var bricks: Array[bool] = []
var balls := 3
var level := 1
var _stuck := true             # the ball waits on the paddle


func _init() -> void:
	super()
	title = "Ziegelbrecher"
	machine = "bricks"


func describe() -> String:
	return "Automat in der Spielhalle: Halt den Ball im Spiel und brich alle Ziegel. 50 Cent, Tickets nach Punkten."


func reset_game() -> void:
	balls = 3
	level = 1
	_new_wall()


func _new_wall() -> void:
	bricks.clear()
	for i in COLS * ROWS:
		bricks.append(true)
	_serve()


func _serve() -> void:
	paddle_x = SCREEN.x * 0.5
	_stuck = true
	ball = Vector2(paddle_x, SCREEN.y - 18.0)
	vel = Vector2.ZERO


func step(dt: float) -> void:
	if keys["left"]:
		paddle_x -= 150.0 * dt
	if keys["right"]:
		paddle_x += 150.0 * dt
	paddle_x = clampf(paddle_x, 16.0, SCREEN.x - 16.0)
	if _stuck:
		ball = Vector2(paddle_x, SCREEN.y - 18.0)
		if keys["fire"] or keys["up"]:
			_stuck = false
			var sp := 110.0 + level * 15.0
			vel = Vector2(sp * 0.45 * (1.0 if rng.randf() < 0.5 else -1.0), -sp)
		return
	ball += vel * dt
	if ball.x < 3.0 or ball.x > SCREEN.x - 3.0:
		vel.x = -vel.x
		ball.x = clampf(ball.x, 3.0, SCREEN.x - 3.0)
	if ball.y < 3.0:
		vel.y = absf(vel.y)
	# Paddle: where it hits sets the angle.
	if vel.y > 0.0 and ball.y > SCREEN.y - 16.0 and ball.y < SCREEN.y - 10.0 and absf(ball.x - paddle_x) < 17.0:
		var k := (ball.x - paddle_x) / 17.0
		var sp := vel.length()
		vel = Vector2(k * sp * 0.8, -sqrt(maxf(sp * sp - (k * sp * 0.8) * (k * sp * 0.8), 100.0)))
		Sound.play("click", null, -12.0)
	if ball.y > SCREEN.y:
		balls -= 1
		Sound.play("fail", null, -8.0)
		if balls <= 0:
			over = true
			return
		_serve()
		return
	var bw := SCREEN.x / COLS
	for i in bricks.size():
		if not bricks[i]:
			continue
		var r := Rect2((i % COLS) * bw + 1.0, 20.0 + (i / COLS) * 9.0, bw - 2.0, 7.0)
		if r.grow(2.0).has_point(ball):
			bricks[i] = false
			score += 10 * (ROWS - i / COLS)
			Sound.play("hit", null, -12.0)
			if absf(ball.y - r.get_center().y) > 3.0:
				vel.y = -vel.y
			else:
				vel.x = -vel.x
			break
	if not bricks.has(true):
		level += 1
		score += 200
		_new_wall()


func draw_screen(c: Control, s: float) -> void:
	block(c, s, 0, 0, SCREEN.x, SCREEN.y, Color("0a0a18"))
	var bw := SCREEN.x / COLS
	var cols := [Color("ff4f6a"), Color("ff9a30"), Color("fff04f"), Color("4fd84f"), Color("4ff3ff")]
	for i in bricks.size():
		if bricks[i]:
			block(c, s, (i % COLS) * bw + 1.0, 20.0 + (i / COLS) * 9.0, bw - 2.0, 7.0, cols[i / COLS])
	block(c, s, paddle_x - 16.0, SCREEN.y - 12.0, 32, 4, Color("e8e8f0"))
	block(c, s, ball.x - 2.0, ball.y - 2.0, 4, 4, Color("ffffff"))
	for i in balls:
		block(c, s, 4.0 + i * 8.0, 6.0, 5, 5, Color("e8e8f0"))


func controls() -> Array:
	return [["Links", "left"], ["Los", "fire"], ["Rechts", "right"]]


func help_text() -> String:
	return "Schläger: A/D oder die Knöpfe · Ball los: Leertaste oder „Los“."


func score_tickets() -> int:
	return score / 200

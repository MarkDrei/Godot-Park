class_name AstroMachine
extends ArcadeGame
## Astro-Abwehr: meteors fall on the town; move the cannon and shoot them. Big ones break in
## two. Three lives; a meteor on the ground or on the cannon costs one.

var ship_x := 120.0
var shots: Array[Vector2] = []
var rocks: Array[Dictionary] = []    # {pos, vel, r}
var lives := 3
var _cool := 0.0
var _spawn := 1.0
var _time := 0.0


func _init() -> void:
	super()
	title = "Astro-Abwehr"
	machine = "astro"


func describe() -> String:
	return "Automat in der Spielhalle: Schieß die Meteore ab, bevor sie landen. 50 Cent, Tickets nach Punkten."


func reset_game() -> void:
	ship_x = SCREEN.x * 0.5
	shots.clear()
	rocks.clear()
	lives = 3
	_cool = 0.0
	_spawn = 1.0
	_time = 0.0


func step(dt: float) -> void:
	_time += dt
	if keys["left"]:
		ship_x -= 120.0 * dt
	if keys["right"]:
		ship_x += 120.0 * dt
	ship_x = clampf(ship_x, 8.0, SCREEN.x - 8.0)
	_cool -= dt
	if keys["fire"] and _cool <= 0.0:
		_cool = 0.28
		shots.append(Vector2(ship_x, SCREEN.y - 20.0))
		Sound.play("click", null, -14.0)
	for i in range(shots.size() - 1, -1, -1):
		shots[i].y -= 220.0 * dt
		if shots[i].y < -4.0:
			shots.remove_at(i)
	_spawn -= dt
	if _spawn <= 0.0:
		_spawn = maxf(0.45, 1.4 - _time * 0.012)
		var big := rng.randf() < 0.35
		rocks.append({"pos": Vector2(rng.randf_range(10.0, SCREEN.x - 10.0), -10.0),
			"vel": Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(22.0, 34.0) + _time * 0.4), "r": 9.0 if big else 5.0})
	for i in range(rocks.size() - 1, -1, -1):
		var rk: Dictionary = rocks[i]
		rk["pos"] += rk["vel"] * dt
		var p: Vector2 = rk["pos"]
		if p.x < 4.0 or p.x > SCREEN.x - 4.0:
			rk["vel"].x = -rk["vel"].x
		var hit := -1
		for j in shots.size():
			if shots[j].distance_to(p) < rk["r"] + 2.0:
				hit = j
		if hit >= 0:
			shots.remove_at(hit)
			rocks.remove_at(i)
			score += 50 if rk["r"] > 6.0 else 30
			Sound.play("hit", null, -10.0)
			if rk["r"] > 6.0:
				for s: float in [-1.0, 1.0]:
					rocks.append({"pos": p, "vel": Vector2(s * 28.0, rk["vel"].y * 0.8), "r": 5.0})
			continue
		var at_ship := absf(p.x - ship_x) < 9.0 and p.y > SCREEN.y - 26.0
		if p.y > SCREEN.y - 12.0 or at_ship:
			rocks.remove_at(i)
			lives -= 1
			Sound.play("bump", null, -4.0)
			if lives <= 0:
				over = true
				return


func draw_screen(c: Control, s: float) -> void:
	block(c, s, 0, 0, SCREEN.x, SCREEN.y, Color("070716"))
	for i in 30:
		var sx := fmod(i * 73.0, SCREEN.x)
		var sy := fmod(i * 41.0 + _time * 6.0 * (1 + i % 3), SCREEN.y - 20.0)
		block(c, s, sx, sy, 1, 1, Color("c8c8ff"))
	# The town on the ground.
	for i in 12:
		var hh := 6.0 + float((i * 7) % 5) * 2.0
		block(c, s, i * 20.0 + 2.0, SCREEN.y - 6.0 - hh, 16, hh, Color("2c3e66"))
	block(c, s, 0, SCREEN.y - 6.0, SCREEN.x, 6, Color("3a5a2a"))
	block(c, s, ship_x - 7.0, SCREEN.y - 16.0, 14, 6, Color("4ff3ff"))
	block(c, s, ship_x - 2.0, SCREEN.y - 22.0, 4, 6, Color("4ff3ff"))
	for sh in shots:
		block(c, s, sh.x - 1.0, sh.y - 3.0, 2, 6, Color("fff04f"))
	for rk: Dictionary in rocks:
		var p: Vector2 = rk["pos"]
		var r: float = rk["r"]
		block(c, s, p.x - r, p.y - r * 0.7, r * 2.0, r * 1.4, Color("b07850"))
		block(c, s, p.x - r * 0.7, p.y - r, r * 1.4, r * 2.0, Color("b07850"))
		block(c, s, p.x - r * 0.4, p.y - r * 0.4, r * 0.5, r * 0.5, Color("805038"))
	for i in lives:
		block(c, s, 4.0 + i * 10.0, 4.0, 7, 4, Color("4ff3ff"))


func controls() -> Array:
	return [["Links", "left"], ["Feuer", "fire"], ["Rechts", "right"]]


func help_text() -> String:
	return "Bewegen: A/D oder die Knöpfe · Schießen: Leertaste oder „Feuer“."


func score_tickets() -> int:
	return score / 150

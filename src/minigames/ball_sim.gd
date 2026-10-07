class_name BallSim
extends RefCounted
## Tiny 2D rolling-ball physics (boule, minigolf): friction, wall segments,
## moving segments and elastic ball-ball collisions. Coordinates are (x, z).

class Ball:
	var p := Vector2.ZERO
	var v := Vector2.ZERO
	var r := 0.04
	var friction := 1.0         # deceleration in m/s²
	var active := true
	var node: Node3D
	var id := ""


var balls: Array[Ball] = []
var walls: Array = []           # [Vector2 a, Vector2 b]
var movers: Array = []          # [Callable() -> [a, b]] for moving obstacles
var restitution := 0.75
var ball_restitution := 0.9


func add_ball(p: Vector2, r: float, friction: float, id := "") -> Ball:
	var b := Ball.new()
	b.p = p
	b.r = r
	b.friction = friction
	b.id = id
	balls.append(b)
	return b


func add_wall(a: Vector2, b: Vector2) -> void:
	walls.append([a, b])


func add_box_walls(center: Vector2, size: Vector2) -> void:
	var h := size * 0.5
	var c := [center + Vector2(-h.x, -h.y), center + Vector2(h.x, -h.y), center + Vector2(h.x, h.y), center + Vector2(-h.x, h.y)]
	for i in 4:
		add_wall(c[i], c[(i + 1) % 4])


func step(dt: float) -> void:
	var sub := 6
	var h := dt / sub
	for s in sub:
		for b in balls:
			if not b.active:
				continue
			var speed := b.v.length()
			if speed > 0.0:
				var ns := maxf(0.0, speed - b.friction * h)
				b.v = b.v * (ns / speed)
				b.p += b.v * h
			_collide_walls(b, walls)
			for m: Callable in movers:
				_collide_walls(b, [m.call()])
		for i in balls.size():
			for j in range(i + 1, balls.size()):
				_collide_balls(balls[i], balls[j])


func _collide_walls(b: Ball, segs: Array) -> void:
	for w: Array in segs:
		var a: Vector2 = w[0]
		var c: Vector2 = w[1]
		var q := Geometry2D.get_closest_point_to_segment(b.p, a, c)
		var d := b.p - q
		var dist := d.length()
		if dist < b.r and dist > 0.00001:
			var n := d / dist
			b.p = q + n * b.r
			var vn := b.v.dot(n)
			if vn < 0.0:
				b.v -= (1.0 + restitution) * vn * n


func _collide_balls(a: Ball, b: Ball) -> void:
	if not a.active or not b.active:
		return
	var d := b.p - a.p
	var dist := d.length()
	var min_d := a.r + b.r
	if dist >= min_d or dist < 0.00001:
		return
	var n := d / dist
	var overlap := min_d - dist
	a.p -= n * overlap * 0.5
	b.p += n * overlap * 0.5
	var rel := (a.v - b.v).dot(n)
	if rel > 0.0:
		var imp := rel * (1.0 + ball_restitution) * 0.5
		a.v -= n * imp
		b.v += n * imp


func resting(threshold := 0.03) -> bool:
	for b in balls:
		if b.active and b.v.length() > threshold:
			return false
	return true

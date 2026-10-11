class_name BumperCars
extends Ride
## Autoscooter: a minute in a bumper car. Bump the other cars from the side or behind for a
## point each; walls and other cars bounce you back. Keys W/A/S/D or arrows, the stick, or the
## touch buttons.

const ROUND := 60.0
const ACCEL := 5.0
const MAX_SPEED := 5.0
const TURN := 2.4
const HIT_SPEED := 1.4       # closing speed (m/s) that counts as a bump

var score := 0
var _pos := Vector2.ZERO
var _yaw := 0.0
var _speed := 0.0
var _cooldown := {}          # scooter index -> seconds until it counts again
var _touch := {"gas": false, "brake": false, "left": false, "right": false}


func _init() -> void:
	title = "Autoscooter"
	host_id = "aylin"
	cost = 250
	ride_id = "bumper"
	duration = ROUND
	joy = 20.0


func describe() -> String:
	return "Eine Minute Autoscooter: Ramm die anderen Wagen von der Seite oder von hinten – jeder Treffer zählt. 2,50 € bei Aylin im Westpark."


func ride_begin() -> void:
	var f := fair()
	f.player_scooter = 0
	var r := f.scooter_rect
	_pos = r.get_center() + Vector2(r.size.x * 0.3, 0)
	_yaw = -PI / 2
	_speed = 0.0
	score = 0
	_cooldown.clear()
	for k: String in _touch:
		_touch[k] = false
	set_score("Treffer: 0")
	host_say("Rammen erlaubt! Nur nicht von vorn.")
	for b: Array in [["Links", "left"], ["Bremse", "brake"], ["Gas", "gas"], ["Rechts", "right"]]:
		var btn := add_button(b[0], func() -> void: pass, 130)
		var key: String = b[1]
		btn.button_down.connect(func() -> void: _touch[key] = true)
		btn.button_up.connect(func() -> void: _touch[key] = false)


func ride_end() -> void:
	fair().player_scooter = -1
	GameState.set_stat_max("bumper_best", score)


func ride_update(delta: float) -> void:
	var f := fair()
	var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var steer := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	throttle += (1.0 if _touch["gas"] else 0.0) - (1.0 if _touch["brake"] else 0.0)
	steer += (1.0 if _touch["right"] else 0.0) - (1.0 if _touch["left"] else 0.0)
	_speed = clampf(_speed + clampf(throttle, -1.0, 1.0) * ACCEL * delta, -MAX_SPEED * 0.5, MAX_SPEED)
	_speed *= 1.0 - 0.9 * delta
	# Yaw grows to the left (arc42 §8.1), so steering right turns it down.
	_yaw -= clampf(steer, -1.0, 1.0) * TURN * delta * clampf(absf(_speed) / 1.5, 0.3, 1.0) * signf(_speed if _speed != 0.0 else 1.0)
	var dir := Vector2(sin(_yaw), cos(_yaw))
	var q := _pos + dir * _speed * delta
	var rink := f.scooter_rect.grow(-0.9)
	if not rink.has_point(q):
		_speed *= -0.45
		q = Vector2(clampf(q.x, rink.position.x, rink.end.x), clampf(q.y, rink.position.y, rink.end.y))
		Sound.play("bump", Vector3(q.x, 0, q.y), -6.0)
	for k: int in _cooldown.keys():
		_cooldown[k] -= delta
		if _cooldown[k] <= 0.0:
			_cooldown.erase(k)
	for i in f.scooters.size():
		if i == f.player_scooter:
			continue
		var other := f.scooters[i]
		var op := Vector2(other.position.x, other.position.z)
		var d := q - op
		var dist := d.length()
		if dist >= 2.0 or dist < 0.001:
			continue
		var n := d / dist
		# Their front: a hit on the nose doesn't count.
		var ofwd := Vector2(sin(other.rotation.y), cos(other.rotation.y))
		var closing := -(dir * _speed).dot(n)
		if closing > HIT_SPEED and not _cooldown.has(i) and ofwd.dot(n) < 0.5:
			score += 1
			_cooldown[i] = 1.2
			set_score("Treffer: %d" % score)
			Sound.play("bump", other.position, 0.0)
			f._scooter_targets[i] = op - n * 6.0
		elif closing > HIT_SPEED:
			Sound.play("bump", other.position, -8.0)
		q = op + n * 2.0
		_speed *= -0.3
		other.position += Vector3(-n.x, 0, -n.y) * 0.4
	_pos = q
	var sc := f.scooters[0]
	sc.position = Vector3(_pos.x, sc.position.y, _pos.y)
	sc.rotation.y = _yaw


func mount() -> Transform3D:
	return fair().scooters[0].global_transform.translated_local(Vector3(0, 0.3, -0.35))


func camera_pose() -> Array:
	var p := fair().scooters[0].global_position
	var dir := Vector3(sin(_yaw), 0, cos(_yaw))
	return [p - dir * 5.5 + Vector3(0, 4.0, 0), p + dir * 2.0]


func game_input(event: InputEvent) -> void:
	pass   # steering is read from the actions every frame


func finish() -> void:
	if _finishing:
		return
	_finishing = true
	var text := "Zeit um! %d Treffer." % score
	if score >= 8:
		text += " Aylin klatscht: „Du bist ein Naturtalent!“"
	end({"won": score >= 5, "joy": joy + score * 2.0, "text": text})


func info_text() -> String:
	return ("Gas und Lenken mit den Knöpfen unten." if Controls.touch_mode else "Gas: W · Lenken: A/D.") + " Ramm die anderen von der Seite oder von hinten!"


func end_text() -> String:
	return ""

class_name BumperCars
extends Ride
## Autoscooter: a minute in a bumper car. It is a Car (kind "scooter") driven like the cars of
## the Oststadt: the same controls (W/S gas and brake, A/D steer; on touch the stick and the
## pedals), the same driving and the driving camera, only in the rink. Bump the other cars
## from the side or behind for a point each.

const ROUND := 60.0
const HIT_SPEED := 1.4       # closing speed (m/s) that counts as a bump

var score := 0
var car: Car                 # the player's scooter while the round lasts
var _cooldown := {}          # scooter index -> seconds until it counts again
var _last_v := Vector2.ZERO  # the car's velocity a frame ago (a bump already turned it round)


func _init() -> void:
	title = "Autoscooter"
	host_id = "aylin"
	cost = 250
	ride_id = "bumper"
	duration = ROUND
	joy = 20.0
	rides_along = false
	free_roam = true          # the player drives: normal HUD, touch stick and pedals


func describe() -> String:
	return "Eine Minute Autoscooter: Ramm die anderen Wagen von der Seite oder von hinten – jeder Treffer zählt. 2,50 € bei Aylin im Westpark."


func goal_done() -> bool:
	return GameState.stat("bumper_best") >= 5


func ride_begin() -> void:
	var f := fair()
	f.player_scooter = 0
	var sc := f.scooters[0]
	sc.visible = false
	var r := f.scooter_rect
	car = Car.new()
	world.add_child(car)
	car.base_y = sc.position.y
	car.setup(world, "scooter", FairModels.COLORS[0], r.get_center() + Vector2(r.size.x * 0.3, 0), -PI / 2)
	car.arena = r.grow(-0.2)
	for i in f.scooters.size():
		if i != 0:
			car.arena_cars.append(f.scooters[i])
	game.player.enter_car(car)
	car.locked = true
	car.exit_hint = "Erst die Runde zu Ende fahren – oder „Beenden“."
	score = 0
	_last_v = Vector2.ZERO
	_cooldown.clear()
	set_score("Treffer: 0")
	host_say("Rammen erlaubt! Nur nicht von vorn.")


func ride_end() -> void:
	var f := fair()
	if is_instance_valid(car):
		if actor and actor.vehicle == car:
			game.player.exit_car(true)
		var sc := f.scooters[0]
		sc.position = Vector3(car.pos2().x, sc.position.y, car.pos2().y)
		sc.rotation.y = car.yaw
		sc.visible = true
		car.queue_free()
	car = null
	f.player_scooter = -1
	GameState.set_stat_max("bumper_best", score)


## Contacts with the other scooters: a bump from the side or behind counts, the other car is
## pushed away and turns off.
func ride_update(delta: float) -> void:
	if not is_instance_valid(car):
		return
	var f := fair()
	for k: int in _cooldown.keys():
		_cooldown[k] -= delta
		if _cooldown[k] <= 0.0:
			_cooldown.erase(k)
	var p := car.pos2()
	var v := car.forward2() * car.speed
	var before := _last_v
	_last_v = v
	# The hidden scooter of the Fair stands in for the car: the others keep away from it.
	var mine := f.scooters[f.player_scooter]
	mine.position = Vector3(p.x, mine.position.y, p.y)
	mine.rotation.y = car.yaw
	for i in f.scooters.size():
		if i == f.player_scooter:
			continue
		var other := f.scooters[i]
		var op := Vector2(other.position.x, other.position.z)
		var d := p - op
		var dist := d.length()
		if dist >= 2.3 or dist < 0.001:
			continue
		var n := d / dist
		var closing := maxf(-v.dot(n), -before.dot(n))
		if closing < 0.3:
			continue
		var ofwd := Vector2(sin(other.rotation.y), cos(other.rotation.y))
		# Their front: a hit on the nose doesn't count.
		if closing > HIT_SPEED and not _cooldown.has(i) and ofwd.dot(n) < 0.5:
			score += 1
			set_score("Treffer: %d" % score)
			Sound.play("bump", other.position, 0.0)
			game.camera.shake(0.15)
		elif closing > HIT_SPEED and not _cooldown.has(i):
			Sound.play("bump", other.position, -8.0)
		_cooldown[i] = 1.0
		f._scooter_targets[i] = op - n * 6.0
		var push := op - n * minf(0.6, closing * 0.25)
		if f.scooter_rect.grow(-1.2).has_point(push):
			other.position = Vector3(push.x, other.position.y, push.y)


func finish() -> void:
	if _finishing:
		return
	_finishing = true
	var text := "Zeit um! %d Treffer." % score
	if score >= 8:
		text += " Aylin klatscht: „Du bist ein Naturtalent!“"
	end({"won": score >= 5, "joy": joy + score * 2.0, "text": text})


func info_text() -> String:
	return ("Fahren wie mit dem Auto: Stick und Pedale." if Controls.touch_mode else "Fahren wie mit dem Auto: W/S Gas und Bremse, A/D lenken.") \
		+ " Ramm die anderen von der Seite oder von hinten!"


func end_text() -> String:
	return ""

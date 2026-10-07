class_name FrisbeeGame
extends Minigame
## Frisbee with Labrador Balu on the great meadow: five throws, Balu tries to catch.
## Playing as Balu instead, Lukas throws and you have to catch.

var dog: Actor
var thrower: Actor
var as_dog := false
var throws := 0
var catches := 0
var aim := 0.0
var t := 0.0
var state := "aim"
var disc: Projectile
var land := Vector3.ZERO
var flight := 0.0
var flight_t := 0.0
var wind := Vector3.ZERO
var meadow: Vector2
var _wait := 0.0


func _init() -> void:
	title = "Frisbee mit Balu"
	host_id = "lukas"


func describe() -> String:
	return "Wirf die Frisbee für Labrador Balu – fängt er sie? Lukas ist nachmittags auf der Großen Wiese."


func can_start(a: Actor) -> bool:
	return not active and (a.is_human() or a.actor_id == "balu")


func begin() -> void:
	meadow = ParkLayout.place("great_meadow")
	as_dog = actor.actor_id == "balu"
	dog = world.find_actor("balu")
	thrower = host() if as_dog else actor
	if dog == null or thrower == null:
		end({"won": false, "text": "Balu ist gerade nicht da."})
		return
	var start := Vector3(meadow.x - 12, 0, meadow.y)
	for a: Actor in [dog, thrower]:
		a.inside = false
		a.visible = true
	thrower.teleport(start)
	thrower.face(Vector3(meadow.x + 10, 0, meadow.y), true)
	for d in thrower.leash_dogs.duplicate():
		thrower.detach_leash(d)
	var lukas := world.find_actor("lukas")
	if lukas and lukas.leash_dogs.has(dog):
		lukas.detach_leash(dog)
	dog.teleport(start + Vector3(1.5, 0, 1.0))
	if dog.brain:
		dog.brain.suspend()
	var w := 0.6 if Clock.weather in [Clock.Weather.CLOUDY, Clock.Weather.RAIN] else (1.8 if Clock.weather == Clock.Weather.STORM else 0.25)
	wind = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * w
	throws = 0
	catches = 0
	state = "aim"
	if as_dog:
		set_info("Lukas wirft – lauf mit Balu dorthin, wo die Frisbee landet! (Steuerung wie immer)")
		game.player.input_enabled = true
		UI.clear_modal("minigame")
		_wait = 1.5
		state = "ai_wait"
	else:
		set_info("Links/Rechts: Richtung · Aktion/Klick: werfen. Wind: %s" % ("stark" if w > 1.0 else ("mittel" if w > 0.5 else "schwach")))
		add_button("<", func() -> void: aim -= 5.0, 90)
		add_button("Werfen!", func() -> void: _throw(pingpong(t, 0.7)), 200)
		add_button(">", func() -> void: aim += 5.0, 90)
	_update()


func _update() -> void:
	set_score("Wurf %d/5  ·  Gefangen: %d" % [mini(throws + 1, 5), catches])


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	var start := thrower.global_position
	match state:
		"aim":
			if Input.is_action_pressed("move_left"):
				aim -= delta * 30.0
			if Input.is_action_pressed("move_right"):
				aim += delta * 30.0
			aim = clampf(aim, -40.0, 40.0)
			thrower.yaw = PI / 2 - deg_to_rad(aim)
			thrower.rotation.y = thrower.yaw
			show_power(pingpong(t, 0.7))
			var dir := Vector3(cos(deg_to_rad(aim)), 0, sin(deg_to_rad(aim)))
			look(start - dir * 4.5 + Vector3(0, 2.6, 0), start + dir * 10.0)
		"ai_wait":
			_wait -= delta
			if _wait <= 0.0:
				aim = randf_range(-30.0, 30.0)
				thrower.yaw = PI / 2 - deg_to_rad(aim)
				thrower.rotation.y = thrower.yaw
				_throw(randf_range(0.35, 0.95))
		"flying":
			flight_t += delta
			if not as_dog:
				var mid := (start + land) * 0.5
				look(start + Vector3(-6, 7, 0), mid)
			if flight_t >= flight:
				_landed()
		"result":
			_wait -= delta
			if _wait <= 0.0:
				if throws >= 5:
					_finish()
				else:
					state = "ai_wait" if as_dog else "aim"
					_wait = 1.5
					dog.go_to(thrower.global_position + Vector3(1.5, 0, 1.0), true)
					_update()


func _throw(power: float) -> void:
	if state not in ["aim", "ai_wait"]:
		return
	var dir := Vector3(cos(deg_to_rad(aim)), 0, sin(deg_to_rad(aim)))
	var dist := 6.0 + power * 18.0
	flight = 1.0 + power * 1.6
	land = thrower.global_position + dir * dist + wind * flight
	land.x = clampf(land.x, meadow.x - 24, meadow.x + 24)
	land.z = clampf(land.z, meadow.y - 13, meadow.y + 13)
	flight_t = 0.0
	thrower.play_anim("throw", 0.8)
	disc = Projectile.throw_item(world, "frisbee", thrower.global_position + Vector3(0, 1.3, 0), land, flight, 1.8, 3.0)
	state = "flying"
	throws += 1
	show_power(-1.0)
	Sound.play("whistle", thrower.global_position, -10.0)
	if not as_dog:
		# Balu reads the throw and sprints towards it.
		var guess := land + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		dog.go_to(guess, true)
		dog.speed_mult = 1.0


func _landed() -> void:
	var d := dog.distance_to(land)
	var caught := d < 1.4
	if caught:
		catches += 1
		dog.set_item("frisbee")
		dog.play_anim("beg", 1.5)
		dog.emote("heart")
		Sound.play("bark", dog.global_position)
		set_info("Gefangen! Super, Balu!")
		if disc:
			disc.queue_free()
	else:
		set_info("Daneben! Balu war %.1f m zu weit weg." % d)
		dog.play_anim("sit", 1.5)
	GameState.set_stat_max("frisbee_catches", catches)
	state = "result"
	_wait = 2.0
	_update()


func _finish() -> void:
	dog.set_item("")
	dog.speed_mult = 1.0
	var text := "Balu hat %d von 5 Würfen gefangen!" % catches
	if as_dog:
		text = "Du hast als Balu %d von 5 Frisbees gefangen!" % catches
	end({"won": catches >= 3, "money": catches * 50, "joy": 20.0 + catches * 4.0, "text": text})


func game_input(event: InputEvent) -> void:
	if as_dog:
		return
	if event.is_action_pressed("interact") or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not UI.point_blocked((event as InputEventMouseButton).position)):
		_throw(pingpong(t, 0.7))


func cleanup() -> void:
	if dog:
		dog.set_item("")
		if dog.brain and not dog.controlled:
			dog.brain.resume()
	if disc and is_instance_valid(disc):
		disc.queue_free()

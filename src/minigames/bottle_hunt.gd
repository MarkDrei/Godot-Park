class_name BottleHuntGame
extends Minigame
## Pfandjagd: collect as many deposit bottles as possible in 150 seconds and
## bring them to the bottle machine at the kiosk.

const DURATION := 150.0
const COUNT := 14

var time_left := DURATION
var spawned: Array[Node3D] = []
var start_returned := 0


func _init() -> void:
	title = "Pfandjagd"
	host_id = "kemal"
	free_roam = true


func describe() -> String:
	return "Sammle in 2½ Minuten so viele Pfandflaschen wie möglich und bring sie zum Automaten am Kiosk. Frag Kiosk-Kemal."


func begin() -> void:
	time_left = DURATION
	start_returned = GameState.stat("bottles")
	var center := Vector2(world.bottle_machine.x, world.bottle_machine.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()  # follows the global seed (dev option seed=N)
	spawned.clear()
	for i in COUNT:
		var p := world.nav.random_point_near(center, 48.0, rng)
		var b := world.spawn_bottle(Vector3(p.x, 0, p.y))
		if b:
			spawned.append(b)
	var h := host()
	if h:
		h.say("Los geht's! Die Uhr läuft!", 3.0)
	set_info("Flaschen aufheben (Aktion) und am Pfandautomaten neben dem Kiosk abgeben. Beenden mit dem Knopf oben rechts.")


func _process(delta: float) -> void:
	if not active:
		return
	time_left -= delta
	var carried: int = actor.inventory.get("empty_bottle", 0)
	var returned := GameState.stat("bottles") - start_returned
	set_score("Zeit: %d s  ·  Dabei: %d  ·  Abgegeben: %d" % [maxi(0, int(time_left)), carried, returned])
	if time_left <= 0.0:
		_finish()


func _finish() -> void:
	var returned := GameState.stat("bottles") - start_returned
	var bonus := 100 if returned >= 10 else 0
	end({"won": returned >= 6, "money": bonus, "joy": 15.0 + returned,
		"text": "Zeit um! Du hast %d Flasche%s abgegeben.%s" % [returned, "" if returned == 1 else "n",
			"\nKemal legt einen Euro Bonus drauf!" if bonus > 0 else ""]})


func quit() -> void:
	_finish()


func cleanup() -> void:
	for b in spawned:
		if is_instance_valid(b):
			world.remove_bottle(b)
	spawned.clear()

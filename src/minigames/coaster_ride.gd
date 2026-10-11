class_name CoasterRide
extends Ride
## Achterbahn: in the front car up the lift hill, down the drop, over the camel back and
## round the turn, once, back into the station.

var _laps := 0
var _drop_said := false


func _init() -> void:
	title = "Achterbahn"
	cost = 350
	ride_id = "coaster"
	duration = 90.0     # the ride ends when the train is back in the station
	joy = 40.0


func describe() -> String:
	return "Einmal die Achterbahn im Westpark: vorne sitzen, Arme hoch! 3,50 € am Automaten."


func ride_begin() -> void:
	fair().coaster_board(2.0)
	_laps = fair().coaster_laps
	_drop_said = false


func ride_update(_delta: float) -> void:
	var car := fair().coaster_cars[0]
	var dir := car.global_transform.basis.z
	if not _drop_said and dir.y < -0.3:
		_drop_said = true
		set_info("Festhalten! Es geht steil bergab!")
		Sound.play("whistle", null, -6.0)
	if fair().coaster_laps > _laps:
		finish()


func rider_anim() -> String:
	return "cheer" if fair().coaster_cars[0].global_transform.basis.z.y < -0.2 else "sit"


func mount() -> Transform3D:
	return fair().coaster_cars[0].global_transform.translated_local(Vector3(0, 0.2, 0.35))


func camera_pose() -> Array:
	var xf := fair().coaster_cars[0].global_transform
	return [xf * Vector3(0, 2.0, -3.4), xf * Vector3(0, 0.9, 6.0)]


func info_text() -> String:
	return "Klack, klack, klack … es geht den Lifthügel hinauf."


func end_text() -> String:
	return "Zurück im Bahnhof. Die Haare stehen noch zu Berge!"

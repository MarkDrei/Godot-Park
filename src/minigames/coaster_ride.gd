class_name CoasterRide
extends Ride
## Achterbahn: in the front car up the lift hill, down the drop, over the camel back and
## round the turn, once, back into the station.

var _laps := 0
var _drop_said := false
var _eye := Vector3.ZERO      # smoothed camera
var _at := Vector3.ZERO


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
	_eye = Vector3.ZERO


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


## Behind and above the front car, looking ahead along the track; eased a little, so the
## camera glides through the curves.
func camera_pose() -> Array:
	var xf := fair().coaster_cars[0].global_transform
	var eye := xf * Vector3(0, 2.0, -3.4)
	var at := xf * Vector3(0, 0.9, 6.0)
	if _eye == Vector3.ZERO:
		_eye = eye
		_at = at
	var k := 1.0 - exp(-get_process_delta_time() * 10.0)
	_eye = _eye.lerp(eye, k)
	_at = _at.lerp(at, k)
	return [_eye, _at]


## The bar follows the train round the track.
func progress() -> float:
	return fair().coaster_progress() if fair().coaster_laps == _laps else 1.0


func info_text() -> String:
	return "Klack, klack, klack … es geht den Lifthügel hinauf."


func end_text() -> String:
	return "Zurück im Bahnhof. Die Haare stehen noch zu Berge!"

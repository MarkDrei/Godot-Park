class_name SwingRide
extends Ride
## Schiffschaukel: the swing boat swings higher and higher, then calms down.

const BOAT := 0


func _init() -> void:
	title = "Schiffschaukel"
	cost = 200
	ride_id = "swing"
	duration = 25.0
	joy = 28.0


func describe() -> String:
	return "Schaukeln, bis der Magen kribbelt. 2 € am Automaten im Westpark."


func ride_begin() -> void:
	fair().ride_boat = BOAT


func ride_update(_delta: float) -> void:
	fair().ride_boat_amp = 0.15 + 0.95 * smoothstep(0.0, 9.0, t) * (1.0 - smoothstep(17.0, duration, t) * 0.8)


func ride_end() -> void:
	fair().ride_boat = -1


func mount() -> Transform3D:
	var boat := fair().boats[BOAT]
	return boat.global_transform.translated_local(Vector3(0, -(FairModels.SWING_BAR - 1.2) - 0.5, -1.0))


func camera_pose() -> Array:
	var bar := fair().boats[BOAT].global_position
	return [bar + Vector3(10.0, -2.5, 1.5), mount().origin + Vector3(0, 0.8, 0)]


func info_text() -> String:
	return "Höher, immer höher!"


func end_text() -> String:
	return "Puh! Die Schiffschaukel steht wieder still."

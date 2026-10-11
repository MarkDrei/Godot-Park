class_name CarouselRide
extends Ride
## Karussell: round and round on a carousel horse that bobs up and down.

var horse := 0


func _init() -> void:
	title = "Karussell"
	cost = 150
	ride_id = "carousel"
	duration = 28.0
	joy = 22.0


func describe() -> String:
	return "Eine Runde auf dem Pferdekarussell im Westpark. 1,50 € am Automaten."


func _horse() -> Node3D:
	return fair().horses[horse]


func mount() -> Transform3D:
	var h := _horse()
	return h.global_transform.translated_local(Vector3(0, 0.82, -0.05))


func camera_pose() -> Array:
	var c := fair().carousel.global_position
	var p := _horse().global_position
	var out := Vector3(p.x - c.x, 0, p.z - c.z).normalized()
	return [c + out * 11.0 + Vector3(0, 3.0, 0), p + Vector3(0, 1.2, 0)]


func info_text() -> String:
	return "Hoch und runter, rundherum!"


func end_text() -> String:
	return "Das Karussell hält an. Dir ist kein bisschen schwindelig. Fast."

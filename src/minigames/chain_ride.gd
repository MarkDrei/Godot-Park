class_name ChainRide
extends Ride
## Kettenkarussell: the chain swing spins up, the seats fly out, it slows down again.

var seat := 0


func _init() -> void:
	title = "Kettenkarussell"
	cost = 200
	ride_id = "chain"
	duration = Fair.chain_ride_time() + 1.0
	joy = 30.0


func describe() -> String:
	return "Im Kettenkarussell durch die Luft fliegen. 2 € am Automaten im Westpark."


func ride_begin() -> void:
	fair().start_chain_cycle()


func _seat() -> Node3D:
	return fair().chain_seats[seat]


func mount() -> Transform3D:
	return _seat().global_transform.translated_local(Vector3(0, -FairModels.CHAIN_LEN - 0.46, 0.05))


func camera_pose() -> Array:
	var xf := mount()
	var fwd := xf.basis.z.normalized()
	var p := xf.origin + Vector3(0, 0.9, 0)
	var out := Vector3(p.x - fair().chain_crown.global_position.x, 0, p.z - fair().chain_crown.global_position.z).normalized()
	return [p - fwd * 3.2 + out * 1.6 + Vector3(0, 1.3, 0), p + fwd * 4.0]


func info_text() -> String:
	return "Gleich geht's los … und hui!"


func end_text() -> String:
	return "Die Füße wieder auf dem Boden. Das war wie Fliegen!"

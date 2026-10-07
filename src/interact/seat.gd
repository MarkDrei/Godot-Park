class_name Seat
extends RefCounted
## One place to sit (bench seat, picnic table, chess stool, swing...).

var position: Vector3          # where the hips go (world)
var yaw := 0.0                 # facing direction (radians, 0 = +Z)
var occupant: Actor = null
var reserved_by: Actor = null
var owner_id := ""             # bench / table id
var kind := "bench"            # bench, table, stool, swing, blanket
var height := 0.45             # seat height above the ground


func is_free_for(actor: Actor) -> bool:
	return occupant == null and (reserved_by == null or reserved_by == actor or not is_instance_valid(reserved_by))


func forward() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


## Where to stand before sitting down.
func approach_point() -> Vector3:
	if kind in ["stool", "table"]:
		return position - forward() * 0.6
	return position + forward() * 0.65

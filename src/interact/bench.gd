class_name Bench
extends Interactable
## A park bench with up to three seats. Sitting on every bench unlocks "Bankdrücker".

var bench_id := ""
var seats: Array[Seat] = []
var plaque := ""


func setup(id: String, ground_pos: Vector3, yaw: float, seat_count := 3, seat_height := 0.45,
		kind := "bench", spacing := 0.6) -> void:
	bench_id = id
	position = ground_pos
	rotation.y = yaw
	radius = 1.9
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	for i in seat_count:
		var s := Seat.new()
		var off := (i - (seat_count - 1) * 0.5) * spacing
		s.position = ground_pos + right * off + Vector3(0, seat_height, 0) - fwd * 0.05
		s.yaw = yaw
		s.owner_id = id
		s.kind = kind
		s.height = seat_height
		seats.append(s)


func free_seat(actor: Actor) -> Seat:
	for s in seats:
		if s.is_free_for(actor):
			return s
	return null


func get_prompt(actor: Actor) -> String:
	if actor.seat != null:
		if actor.anim == "sleep":
			return "Aufwachen"
		if actor.is_human() and actor.is_player():
			return "Aufstehen  ·  %s Nickerchen" % ("Spezial:" if Controls.touch_mode else "[F]")
		return "Aufstehen"
	if free_seat(actor) == null:
		return "Bank besetzt"
	return "Hinsetzen" if plaque == "" else "Hinsetzen (Plakette lesen)"


func can_interact(actor: Actor) -> bool:
	return actor.seat != null or free_seat(actor) != null


func interact(actor: Actor) -> void:
	if actor.seat != null:
		actor.stand_up()
		return
	var best: Seat = null
	var best_d := INF
	for s in seats:
		if s.is_free_for(actor):
			var d := s.position.distance_to(actor.global_position)
			if d < best_d:
				best_d = d
				best = s
	if best:
		actor.sit_on(best)
		if plaque != "" and actor.is_player():
			GameState.toast.emit("Plakette: „%s“" % plaque, "info")

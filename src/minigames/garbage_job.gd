class_name GarbageJob
extends DriveJob
## Garbage collection: with the garbage truck from the depot, empty eight wheelie bins at the
## kerbs of a round. Stop beside a bin; the arm lifts it. Five minutes for the round.

const BINS := 8
const TIME := 300.0

var rng := RandomNumberGenerator.new()
var bins: Array[Dictionary] = []     # {pos (kerb side, on the sidewalk), node, done}
var current := 0
var time := 0.0
var lifting := 0.0


func _init() -> void:
	super()
	title = "Müllabfuhr"
	host_id = ""
	vehicle_kind = "garbage"
	rng.randomize()


func describe() -> String:
	return "Mit dem Müllwagen vom Betriebshof (Ostring) acht Mülltonnen am Straßenrand leeren. Neben der Tonne anhalten."


func begin() -> void:
	start_driving()
	time = 0.0
	current = 0
	lifting = 0.0
	_place_bins()
	_show_bin()
	set_info("Fahr zur Tonne (Lichtsäule) und halte direkt daneben an.")


## Eight bins along the sidewalks, the next one never far from the last.
func _place_bins() -> void:
	_clear_bins()
	var bays := CityLayout.parking_bays()
	var last := car().pos2()
	for i in BINS:
		var best := {}
		for attempt in 60:
			var bay: Dictionary = bays[rng.randi() % bays.size()]
			var p: Vector2 = bay["pos"]
			var d := p.distance_to(last)
			if d < 40.0 or d > 110.0 or bins.any(func(b: Dictionary) -> bool: return (b["curb"] as Vector2).distance_to(p) < 30.0):
				continue
			best = bay
			break
		if best.is_empty():
			best = bays[rng.randi() % bays.size()]
		var curb: Vector2 = best["pos"]
		var yaw: float = best["yaw"]
		# The bin stands on the sidewalk beside the parking strip.
		var f := Vector2(sin(yaw), cos(yaw))
		var side := Car.right_of(f)   # parked cars face the lane direction: the kerb is on their right
		var walk := curb + side * (CityLayout.ROAD_HALF - CityLayout.PARK_OFFSET + 0.6)
		if world.map.ground_at(walk) != ParkMap.Ground.SIDEWALK:
			walk = curb - side * (CityLayout.ROAD_HALF - CityLayout.PARK_OFFSET + 0.6)
		var mi := MeshInstance3D.new()
		mi.mesh = CityModels.wheelie_bin(Color("3a6a3a") if i % 2 == 0 else Color("5a5a5e"))
		mi.position = Vector3(walk.x, ParkMap.CURB_Y, walk.y)
		world.add_child(mi)
		bins.append({"pos": walk, "curb": curb, "node": mi, "done": false})
		last = curb


func _show_bin() -> void:
	if current < bins.size():
		show_target(bins[current]["curb"], "Tonne %d" % (current + 1), Color(0.6, 1.0, 0.4))


func job_tick(delta: float) -> void:
	time += delta
	set_score("Tonne %d/%d · %d s · %s" % [mini(current + 1, BINS), BINS, maxi(0, int(TIME - time)), way_text()])
	if lifting > 0.0:
		lifting -= delta
		var node: MeshInstance3D = bins[current]["node"]
		var k := 1.0 - absf(lifting - 0.75) / 0.75
		node.position.y = ParkMap.CURB_Y + k * 1.6
		node.rotation.x = k * 2.2
		if lifting <= 0.0:
			node.position.y = ParkMap.CURB_Y
			node.rotation.x = 0.0
			bins[current]["done"] = true
			current += 1
			GameState.add_stat("bins_emptied")
			if current >= BINS:
				var bonus := 400 if time < TIME else 0
				end({"won": true, "money": BINS * 100 + bonus, "joy": 18.0,
					"text": "Alle %d Tonnen geleert%s!" % [BINS, " – in Rekordzeit" if bonus > 0 else ""]})
				return
			_show_bin()
		return
	if arrived(4.5) and car().pos2().distance_to(bins[current]["pos"]) < 6.0:
		lifting = 1.5
		Sound.play("hit", car().global_position)
	if time >= TIME:
		end({"won": false, "money": current * 100, "joy": 6.0, "text": "Zeit um: %d von %d Tonnen geleert." % [current, BINS]})


func _clear_bins() -> void:
	for b: Dictionary in bins:
		if is_instance_valid(b["node"]):
			(b["node"] as Node).queue_free()
	bins.clear()


func cleanup() -> void:
	super()
	_clear_bins()

class_name Traffic
extends Node
## Traffic of the Oststadt (doc/oststadt.md): a lane graph over the street grid (right-hand
## traffic), traffic lights at the main crossings and AI cars that follow the lanes, turn at
## random, wait at red lights and for a free crossing, keep their distance and brake for
## people (the car's own safety brake). A stuck car out of sight starts somewhere else.

const COUNT := 14
const STOP := 9.5              # stop line: distance from the crossing centre
const CRUISE := 9.0            # m/s (about 32 km/h)
const TURN_SPEED := 4.5
const CYCLE := [["z", 11.0], ["z_yellow", 2.0], ["red", 1.5], ["x", 11.0], ["x_yellow", 2.0], ["red", 1.5]]

var world: World
var lanes: Array[Dictionary] = []       # {id, dir, a (start), b (stop line), from, to, axis}
var crossings: Array[Dictionary] = []   # {pos, lights, holder (Car), phase, t, heads}
var agents: Array = []                  # Agent
var rng := RandomNumberGenerator.new()
var _respawn := 0.0
var red_runs := 0                       # the player drove into a crossing at red


func setup(w: World) -> void:
	world = w
	name = "Traffic"
	rng.seed = 7272
	_build_graph()


func _build_graph() -> void:
	for c: Dictionary in CityLayout.crossings():
		crossings.append({"pos": c["pos"], "lights": c["lights"], "holder": null, "phase": 0, "t": 0.0, "heads": []})
	var index := {}
	for i in crossings.size():
		index[crossings[i]["pos"]] = i
	for i in crossings.size():
		var p: Vector2 = crossings[i]["pos"]
		for arm: Vector2 in CityLayout.crossings()[i]["arms"]:
			# The next crossing along this arm.
			var best := -1
			var best_d := INF
			for j in crossings.size():
				var q: Vector2 = crossings[j]["pos"]
				var d := q - p
				if j == i or d.normalized().dot(arm) < 0.999:
					continue
				if d.length() < best_d:
					best_d = d.length()
					best = j
			if best < 0:
				continue
			var r := Car.right_of(arm) * CityLayout.LANE_OFFSET
			var q2: Vector2 = crossings[best]["pos"]
			lanes.append({"id": lanes.size(), "dir": arm, "a": p + arm * STOP + r, "b": q2 - arm * STOP + r,
				"from": i, "to": best, "axis": "x" if arm.x != 0.0 else "z"})


## Lanes leaving crossing c (no U-turn unless there is no other way).
func next_lanes(lane: Dictionary) -> Array:
	var out := []
	for l: Dictionary in lanes:
		if l["from"] == lane["to"] and (l["dir"] as Vector2).dot(lane["dir"]) > -0.5:
			out.append(l)
	if out.is_empty():
		for l: Dictionary in lanes:
			if l["from"] == lane["to"]:
				out.append(l)
	return out


## Points from the stop line of `lane` to the start of `next` through the crossing.
static func turn_path(lane: Dictionary, next: Dictionary) -> PackedVector2Array:
	var e: Vector2 = lane["b"]
	var s: Vector2 = next["a"]
	var d1: Vector2 = lane["dir"]
	var d2: Vector2 = next["dir"]
	var pts := PackedVector2Array()
	if d1.dot(d2) > 0.9:
		for k in 5:
			pts.append(e.lerp(s, k / 4.0))
		return pts
	# Corner: where the two lane lines meet (a U-turn bends around the crossing centre).
	var c: Vector2
	if absf(d1.dot(d2)) < 0.1:
		c = Vector2(e.x, s.y) if d1.x == 0.0 else Vector2(s.x, e.y)
	else:
		c = (e + s) * 0.5 + d1 * CityLayout.ROAD_HALF
	for k in 9:
		var t := k / 8.0
		pts.append(e.lerp(c, t).lerp(c.lerp(s, t), t))
	return pts


# --- Traffic lights -----------------------------------------------------------------

func _process(delta: float) -> void:
	for c: Dictionary in crossings:
		if not c["lights"]:
			continue
		c["t"] += delta
		var step: Array = CYCLE[c["phase"]]
		if c["t"] >= step[1]:
			c["t"] = 0.0
			c["phase"] = (c["phase"] + 1) % CYCLE.size()
			_show_lights(c)
	_check_player()
	_respawn -= delta
	if _respawn <= 0.0:
		_respawn = 4.0
		_keep_count()


## "green", "yellow" or "red" for cars travelling along `axis` at crossing c.
static func light(c: Dictionary, axis: String) -> String:
	if not c["lights"]:
		return "green"
	var state: String = CYCLE[c["phase"]][0]
	if state == axis:
		return "green"
	if state == axis + "_yellow":
		return "yellow"
	return "red"


func crossing_at(p: Vector2) -> Dictionary:
	for c: Dictionary in crossings:
		var q: Vector2 = c["pos"]
		if absf(p.x - q.x) <= CityLayout.ROAD_HALF and absf(p.y - q.y) <= CityLayout.ROAD_HALF:
			return c
	return {}


## Light heads: one per arm, facing the cars that come in on it. The lit lamp moves.
func build_lights(parent: Node3D) -> void:
	var mats := {"red": _lamp_mat(Color("ff3020")), "yellow": _lamp_mat(Color("ffc020")), "green": _lamp_mat(Color("30e060"))}
	for i in crossings.size():
		var c: Dictionary = crossings[i]
		if not c["lights"]:
			continue
		var p: Vector2 = c["pos"]
		for arm: Vector2 in CityLayout.crossings()[i]["arms"]:
			# Cars come in against `arm`; their light stands on their right, before the crossing.
			var incoming := -arm
			var post := p + arm * (CityLayout.ROAD_HALF + 1.2) + Car.right_of(incoming) * (CityLayout.ROAD_HALF + 0.9)
			var yaw := atan2(-incoming.x, -incoming.y)    # the head faces the incoming cars
			var head := MeshInstance3D.new()
			head.mesh = CityModels.traffic_light()
			head.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(post.x, ParkMap.CURB_Y, post.y))
			parent.add_child(head)
			world.map.add_obstacle_circle(post, 0.15, 3)
			var lamp := MeshInstance3D.new()
			lamp.mesh = CityModels.lamp_disc()
			head.add_child(lamp)
			c["heads"].append({"axis": "x" if arm.x != 0.0 else "z", "lamp": lamp, "mats": mats})
		_show_lights(c)


static func _lamp_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m


func _show_lights(c: Dictionary) -> void:
	for h: Dictionary in c["heads"]:
		var state := light(c, h["axis"])
		var lamp: MeshInstance3D = h["lamp"]
		lamp.material_override = h["mats"][state]
		lamp.position = Vector3(0, {"red": 3.35, "yellow": 3.05, "green": 2.75}[state], 0.16)


# --- AI cars ---------------------------------------------------------------------------

func spawn_all() -> void:
	for i in COUNT:
		_spawn_one()


## A new AI car on a random lane, away from other cars (and out of the player's sight
## after the start).
func _spawn_one(hidden := false) -> Car:
	for attempt in 30:
		var lane: Dictionary = lanes[rng.randi() % lanes.size()]
		var t := rng.randf_range(0.15, 0.7)
		var p: Vector2 = (lane["a"] as Vector2).lerp(lane["b"], t)
		var ok := true
		for c: Car in world.city.cars:
			if c.pos2().distance_to(p) < (12.0 if c.ai else 4.5):
				ok = false
				break
		if ok and hidden and _seen(p):
			ok = false
		if not ok:
			continue
		var dir: Vector2 = lane["dir"]
		var kind: String = CarSpecs.ORDINARY[rng.randi() % CarSpecs.ORDINARY.size()]
		var car := world.city.spawn_car(kind, CarSpecs.COLORS[rng.randi() % CarSpecs.COLORS.size()], p, atan2(dir.x, dir.y))
		var agent := Agent.new(self, car, lane)
		car.ai = agent
		car.activate()
		agents.append(agent)
		return car
	return null


## Near the camera and in front of it.
func _seen(p: Vector2) -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return false
	var q := Vector3(p.x, 1.0, p.y)
	return q.distance_to(cam.global_position) < 70.0 and not cam.is_position_behind(q)


## Agents whose car the player took, or that got stuck out of sight, are replaced.
func _keep_count() -> void:
	for a: Agent in agents.duplicate():
		if a.car == null or not is_instance_valid(a.car) or a.car.ai != a:
			release(a)
			agents.erase(a)
		elif a.stuck > 14.0 and not _seen(a.car.pos2()):
			release(a)
			agents.erase(a)
			world.city.remove_car(a.car)
	if agents.size() < COUNT:
		_spawn_one(true)


func release(a: Agent) -> void:
	for c: Dictionary in crossings:
		if c["holder"] == a:
			c["holder"] = null


func agent_of(car: Car) -> Agent:
	for a: Agent in agents:
		if a.car == car:
			return a
	return null


## The player drives into a crossing at red: the others honk, the policewoman comments.
var _player_cross := {}


func _check_player() -> void:
	var pc: PlayerController = UI.game.player if UI.game else null
	if pc == null or pc.actor == null or pc.actor.vehicle == null:
		_player_cross = {}
		return
	var car: Car = pc.actor.vehicle
	var c := crossing_at(car.pos2())
	if c.is_empty() or c == _player_cross:
		_player_cross = c
		return
	_player_cross = c
	var f := car.forward2()
	var axis := "x" if absf(f.x) > absf(f.y) else "z"
	if absf(car.speed) > 2.0 and light(c, axis) == "red":
		red_runs += 1
		GameState.add_stat("red_lights")
		for a: Agent in agents:
			if a.car.pos2().distance_to(car.pos2()) < 30.0:
				a.car.honk()
				break
		var petra := world.find_actor("petra")
		if petra and not petra.inside and petra.distance_to(car.global_position) < 35.0:
			petra.face(car.global_position)
			petra.say(["Hey! Das war rot!", "Rote Ampel! Ich hab's gesehen!", "Das gibt … ach, diesmal nur eine Verwarnung!"][red_runs % 3], 3.0)


## One AI car: follows lane → turn → lane …
class Agent extends RefCounted:
	var traffic: Traffic
	var car: Car
	var lane: Dictionary
	var next: Dictionary = {}
	var path := PackedVector2Array()   # current way: rest of the lane, then the turn
	var state := "lane"                # lane (towards the stop line), cross (in the crossing)
	var stuck := 0.0
	var honk_wait := 0.0

	func _init(t: Traffic, c: Car, l: Dictionary) -> void:
		traffic = t
		car = c
		lane = l
		_plan()

	## Picks the next lane and lays the way: along the lane, through the crossing, into the next.
	func _plan() -> void:
		var options := traffic.next_lanes(lane)
		next = options[traffic.rng.randi() % options.size()]
		path = PackedVector2Array([lane["b"]])
		path.append_array(Traffic.turn_path(lane, next))
		path.append(next["a"] + (next["dir"] as Vector2) * 6.0)
		state = "lane"

	func crossing() -> Dictionary:
		return traffic.crossings[lane["to"]]

	func drive(c: Car, delta: float) -> void:
		var p := c.pos2()
		var f := c.forward2()
		# Progress: drop passed points.
		while path.size() > 1 and (path[0] - p).dot(f) < 1.0 and p.distance_to(path[0]) < 6.0:
			path.remove_at(0)
		var to_stop := (lane["b"] as Vector2 - p).dot(lane["dir"])
		if state == "lane" and to_stop < 0.5:
			state = "cross"
		var cr := crossing()
		if state == "cross":
			# Out of the crossing and on the next lane: that is the new lane.
			if (p - (next["a"] as Vector2)).dot(next["dir"]) > 0.0:
				if cr["holder"] == self:
					cr["holder"] = null
				lane = next
				_plan()
				cr = crossing()
		# Pure pursuit to a point ahead.
		var look := clampf(absf(c.speed) * 0.7 + 3.5, 3.5, 8.0)
		var target := _ahead(p, look)
		var to := target - p
		var cross := f.x * to.y - f.y * to.x
		var alpha := atan2(cross, f.dot(to))
		var wb: float = c.spec["wheelbase"]
		var want := atan(2.0 * wb * sin(alpha) / maxf(look, 0.1))
		var max_eff: float = float(c.spec["steer"]) / (1.0 + absf(c.speed) / 11.0)
		var steer := clampf(want / maxf(max_eff, 0.05), -1.0, 1.0)
		# Speed: cruise, slower in turns, stop at the line and behind cars.
		var v := CRUISE
		if state == "cross" or (to_stop < 12.0 and (next["dir"] as Vector2).dot(lane["dir"]) < 0.9):
			v = TURN_SPEED
		var brake: float = c.spec["brake"] * 0.55
		if state == "lane" and not _may_enter(cr):
			v = minf(v, sqrt(2.0 * brake * maxf(0.0, to_stop - 0.8)))
		var gap := _gap_to_cars(c)
		if gap < INF:
			v = minf(v, sqrt(2.0 * brake * maxf(0.0, gap - 2.2)))
		var throttle := clampf((v - c.speed) * 0.8, -1.0, 1.0)
		if v < 0.2 and c.speed < 0.5:
			throttle = -0.05 if c.speed > 0.05 else 0.0
		c.set_input(throttle, steer)
		# Waiting: honk now and then at a car in the way; count towards a respawn.
		if c.speed < 0.3 and (gap < 6.0 or c.auto_braked):
			stuck += delta
			honk_wait += delta
			if honk_wait > 5.0:
				honk_wait = 0.0
				if traffic.rng.randf() < 0.4:
					c.honk()
		elif c.speed > 1.0:
			stuck = 0.0
			honk_wait = 0.0

	## Point `dist` metres ahead on the way.
	func _ahead(p: Vector2, dist: float) -> Vector2:
		var prev := p
		var left := dist
		for q in path:
			var l := prev.distance_to(q)
			if l >= left:
				return prev.lerp(q, left / l)
			left -= l
			prev = q
		return path[path.size() - 1] if not path.is_empty() else p + car.forward2() * dist

	## Green (or yellow when too close to stop) and the crossing free: reserve it.
	func _may_enter(cr: Dictionary) -> bool:
		if cr["holder"] == self:
			return true
		var to_stop := (lane["b"] as Vector2 - car.pos2()).dot(lane["dir"])
		if to_stop > 14.0:
			return true      # far away: no decision yet
		var l := Traffic.light(cr, lane["axis"])
		if l == "red" or (l == "yellow" and to_stop > 4.0):
			return false
		if cr["holder"] != null and is_instance_valid((cr["holder"] as Agent).car):
			return false
		# Only the first car in the queue reserves (a car behind it would block the crossing).
		if _gap_to_cars(car) < to_stop:
			return false
		# Nobody else (the player too) standing in the crossing, room on the next lane.
		var q: Vector2 = cr["pos"]
		for other: Car in traffic.world.city.cars:
			if other == car:
				continue
			var o := other.pos2()
			if absf(o.x - q.x) < CityLayout.ROAD_HALF + 1.0 and absf(o.y - q.y) < CityLayout.ROAD_HALF + 1.0:
				return false
			if o.distance_to(next["a"]) < 6.0 and other.forward2().dot(next["dir"]) > 0.5:
				return false   # no room on the next lane
		cr["holder"] = self
		return true

	## Distance along the way to the nearest car on it (bumper to bumper), or INF. The way
	## bends through crossings, so cars in the other lane of a turn don't count.
	func _gap_to_cars(c: Car) -> float:
		var p := c.pos2()
		var near: Array[Car] = []
		for other: Car in traffic.world.city.cars:
			if other != c and other.pos2().distance_squared_to(p) < 900.0:
				near.append(other)
		if near.is_empty():
			return INF
		var half := c.length() * 0.5
		var d := half
		while d <= 24.0:
			var q := _ahead(p, d)
			for other in near:
				if other.contains(q, c.width() * 0.5 - 0.2):
					return maxf(0.0, d - half - _depth_into(other, q))
			d += 1.0
		return INF

	## How far q lies inside the other car's footprint along our way (≈ its half length).
	func _depth_into(other: Car, q: Vector2) -> float:
		return 0.0 if other.contains(q, -0.5) else 0.5

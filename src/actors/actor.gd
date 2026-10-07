class_name Actor
extends Node3D
## A person or animal in the park. Movement is kinematic on the ParkMap
## (no physics engine): grid-checked steps, terrain/bridge height, soft avoidance.
## Either a Brain (NPC) or the PlayerController drives it.

signal arrived
signal path_failed

const HUMAN_SPECIES := ["human", "troll"]

var actor_id := ""
var display_name := ""
var description := ""
var species := "human"
var def := {}
var world: World
var rig: Rig
var needs := Needs.new()
var brain: Brain
var controlled := false
var playable := true

# Motion parameters.
var walk_speed := 1.3
var run_speed := 3.2
var swim_speed := 0.8
var turn_rate := 9.0
var nav_profile := ParkMap.Nav.HUMAN
var can_swim := false
var radius := 0.35
var avoid := true

# Motion state.
var velocity := Vector3.ZERO
var yaw := 0.0
var path := PackedVector3Array()
var path_i := 0
var running := false
var move_input := Vector3.ZERO
var custom_motion := false
var swimming := false
var seat: Seat = null
var inside := false
var speed_mult := 1.0
var lod_distance := 0.0

# Presentation state.
var anim := "idle"
var _override := ""
var _override_time := 0.0
var look_target := Vector3.INF
var item := ""
var inventory := {}
var leash_owner: Actor = null
var leash_dogs: Array[Actor] = []
var _leash_mesh: MeshInstance3D
var _consume := ""
var _consume_time := 0.0
var _stuck_time := 0.0
var _last_pos := Vector3.ZERO
var _y_vel := 0.0


func setup(definition: Dictionary, w: World) -> void:
	def = definition
	world = w
	actor_id = def["id"]
	display_name = def["name"]
	description = def.get("desc", "")
	species = def.get("species", "human")
	playable = def.get("playable", true)
	name = actor_id
	walk_speed = def.get("walk", walk_speed)
	run_speed = def.get("run", run_speed)
	radius = def.get("radius", radius)
	can_swim = def.get("swims", false)
	nav_profile = ParkMap.Nav.HUMAN if is_human() else ParkMap.Nav.ANIMAL
	var rates: Dictionary = def.get("rates", {})
	needs.hunger_rate *= rates.get("hunger", 1.0)
	needs.fatigue_rate *= rates.get("fatigue", 1.0)
	needs.joy_decay *= rates.get("joy", 1.0)
	needs.hunger = randf_range(5.0, 35.0)
	needs.fatigue = randf_range(5.0, 30.0)
	needs.joy = randf_range(55.0, 85.0)
	rig = _make_rig()
	add_child(rig)
	add_to_group("actors")
	add_to_group("persistent")


func _make_rig() -> Rig:
	match species:
		"human", "troll":
			var r := HumanRig.new()
			r.build(def.get("look", {}))
			return r
		"duck", "duckling", "goose", "pigeon", "heron", "owl":
			var b := BirdRig.new()
			b.build(def.get("preset", "drake"))
			return b
		_:
			var q := QuadrupedRig.new()
			q.build(def.get("preset", "labrador"), def.get("look", {}))
			return q


func is_human() -> bool:
	return species in HUMAN_SPECIES


func is_player() -> bool:
	return controlled


func is_bird() -> bool:
	return species in ["duck", "duckling", "goose", "pigeon", "heron", "owl"]


func ground_pos() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func forward() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


# --- Commands ----------------------------------------------------------------------

## Plans a path to `target`; returns false when unreachable.
func go_to(target: Vector3, run := false) -> bool:
	if seat:
		stand_up()
	running = run
	var nav := ParkMap.Nav.WATER if swimming and _target_is_water(target) else nav_profile
	path = world.nav.find_path(global_position, target, nav)
	path_i = 0
	_stuck_time = 0.0
	if path.is_empty():
		return false
	# Skip the first waypoint when we're already past it.
	if path.size() > 1 and global_position.distance_to(path[0]) < 1.0:
		path_i = 1
	return true


## Straight-line move without pathfinding (short hops, swimming in open water).
func go_direct(target: Vector3, run := false) -> void:
	if seat:
		stand_up()
	running = run
	path = PackedVector3Array([target])
	path_i = 0
	_stuck_time = 0.0


func _target_is_water(t: Vector3) -> bool:
	return world.map.is_water(Vector2(t.x, t.z))


func stop_moving() -> void:
	path = PackedVector3Array()
	path_i = 0
	move_input = Vector3.ZERO


func is_moving() -> bool:
	return path_i < path.size()


func distance_to(p: Vector3) -> float:
	return Vector2(global_position.x - p.x, global_position.z - p.z).length()


func face(point: Vector3, instant := false) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	var target := atan2(d.x, d.z)
	if instant:
		yaw = target
		rotation.y = yaw
	else:
		_face_target = target


var _face_target := NAN


func teleport(p: Vector3) -> void:
	global_position = Vector3(p.x, world.map.walk_height(p.x, p.z), p.z)
	_last_pos = global_position
	velocity = Vector3.ZERO
	stop_moving()


func sit_on(s: Seat) -> void:
	if s == null or not s.is_free_for(self):
		return
	stop_moving()
	if seat:
		seat.occupant = null
	seat = s
	s.occupant = self
	s.reserved_by = null
	global_position = Vector3(s.position.x, s.position.y - s.height, s.position.z)
	yaw = s.yaw
	rotation.y = yaw
	velocity = Vector3.ZERO
	if controlled and s.owner_id.begins_with("bench_"):
		GameState.add_to_set("benches", s.owner_id)


func stand_up() -> void:
	if seat == null:
		return
	var s := seat
	seat.occupant = null
	seat = null
	var p := s.approach_point()
	if world.map.is_solid(Vector2(p.x, p.z), nav_profile):
		var c := world.nav.nearest_open(Vector2(p.x, p.z), nav_profile)
		if c.x >= 0:
			var q := ParkMap.cell_center(c)
			p = Vector3(q.x, 0, q.y)
	global_position = Vector3(p.x, world.map.walk_height(p.x, p.z), p.z)
	if anim in ["sit", "sleep", "read", "chess", "swing", "blanket"]:
		anim = "idle"


## One-shot animation for `duration` seconds (overrides the activity animation).
func play_anim(name: String, duration := 2.0) -> void:
	_override = name
	_override_time = duration


## Eat or drink something over a few seconds, then apply its effect.
func consume(food: String) -> void:
	_consume = food
	_consume_time = 4.0
	set_item(Food.item_for(food))
	play_anim("eat" if food != "water" and food != "coffee" else "drink", 4.0)


func current_anim() -> String:
	return _override if _override_time > 0.0 else anim


func set_item(id: String) -> void:
	item = id
	if rig:
		var xf := Transform3D.IDENTITY
		match id:
			"umbrella":
				xf = Transform3D(Basis(), Vector3(0, 0.95, 0))
			"newspaper", "map":
				xf = Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0.05, 0.05, 0.12))
			"leash":
				xf = Transform3D(Basis(), Vector3(0, -0.02, 0))
			"guitar":
				xf = Transform3D(Basis(Vector3.BACK, 1.2), Vector3(0.1, -0.1, 0.18))
			"broom":
				xf = Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, 0, 0.05))
			"balloon":
				xf = Transform3D(Basis(), Vector3(0, -0.05, 0))
		rig.set_item(id, xf)


func say(text: String, duration := 3.5) -> void:
	if rig:
		rig.say(text, duration)


func emote(icon: String, count := 1) -> void:
	if rig:
		rig.emote(icon, count)


func add_item(id: String, count := 1) -> void:
	inventory[id] = inventory.get(id, 0) + count


func take_item(id: String, count := 1) -> bool:
	if inventory.get(id, 0) < count:
		return false
	inventory[id] -= count
	if inventory[id] <= 0:
		inventory.erase(id)
	return true


func has_item(id: String) -> bool:
	return inventory.get(id, 0) > 0


# --- Simulation ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null:
		return
	var game_minutes := delta * Clock.MINUTES_PER_SECOND * Clock.time_scale
	needs.update(game_minutes, _need_state())
	if brain and not controlled:
		brain.update(delta)
	if inside:
		return
	if seat == null and not custom_motion:
		_move(delta)
	elif seat:
		velocity = Vector3.ZERO
	if not is_nan(_face_target) and velocity.length() < 0.2:
		yaw = lerp_angle(yaw, _face_target, clampf(delta * turn_rate, 0.0, 1.0))
		rotation.y = yaw
		if absf(angle_difference(yaw, _face_target)) < 0.02:
			_face_target = NAN
	_override_time = maxf(0.0, _override_time - delta)
	if _consume_time > 0.0:
		_consume_time -= delta
		if _consume_time <= 0.0:
			var expected := Food.item_for(_consume)
			if expected == "" or item == expected:
				Food.apply(self, _consume)
				if controlled:
					emote("happy")
			set_item("")
			_consume = ""
	_animate(delta)
	if not leash_dogs.is_empty():
		_update_leashes()


func _need_state() -> String:
	var a := current_anim()
	if a == "sleep":
		return "sleep"
	if seat != null or a in ["sit", "lie", "read", "chess", "blanket"]:
		return "sit"
	if swimming:
		return "swim"
	if velocity.length() > walk_speed * 1.5:
		return "run"
	return "walk"


func current_speed() -> float:
	var base := run_speed if running else walk_speed
	if swimming:
		base = swim_speed * (1.6 if running else 1.0)
	return base * needs.speed_factor() * speed_mult


func _move(delta: float) -> void:
	var desired := Vector3.ZERO
	var speed := current_speed()
	if controlled and move_input.length() > 0.05:
		desired = move_input.limit_length(1.0) * speed
		path = PackedVector3Array()
	elif path_i < path.size():
		var wp := path[path_i]
		var to := Vector3(wp.x - global_position.x, 0, wp.z - global_position.z)
		var dist := to.length()
		var last := path_i == path.size() - 1
		var reach := 0.25 if last else 0.7
		if dist < reach:
			path_i += 1
			if path_i >= path.size():
				path = PackedVector3Array()
				path_i = 0
				arrived.emit()
		else:
			var slow := clampf(dist / 1.2, 0.35, 1.0) if last else 1.0
			desired = to / dist * speed * slow
	if avoid and desired.length() > 0.05 and lod_distance < 45.0:
		desired += _separation() * speed * 0.6
	var accel := 10.0 if desired.length() > velocity.length() else 12.0
	velocity = velocity.lerp(desired, clampf(delta * accel, 0.0, 1.0))
	var step := velocity * delta
	if step.length() > 0.0001:
		var p := global_position
		var nxt := Vector2(p.x + step.x, p.z + step.z)
		if _blocked(nxt):
			# Slide along the obstacle.
			var nx := Vector2(p.x + step.x, p.z)
			var nz := Vector2(p.x, p.z + step.z)
			if not _blocked(nx):
				nxt = nx
			elif not _blocked(nz):
				nxt = nz
			else:
				nxt = Vector2(p.x, p.z)
				velocity = Vector3.ZERO
		global_position.x = nxt.x
		global_position.z = nxt.y
		if velocity.length() > 0.15:
			var target_yaw := atan2(velocity.x, velocity.z)
			yaw = lerp_angle(yaw, target_yaw, clampf(delta * turn_rate, 0.0, 1.0))
			rotation.y = yaw
			_face_target = NAN
	_update_height(delta)
	# Stuck detection for path following.
	if not controlled and path_i < path.size():
		if global_position.distance_to(_last_pos) < speed * delta * 0.2:
			_stuck_time += delta
			if _stuck_time > 2.5:
				_stuck_time = 0.0
				stop_moving()
				path_failed.emit()
		else:
			_stuck_time = 0.0
	_last_pos = global_position


func _blocked(p: Vector2) -> bool:
	if can_swim:
		if not ParkMap.in_park(p, 0.6):
			return true
		var c := ParkMap.to_cell(p)
		var water := world.map.ground[c.y * ParkMap.W + c.x] == ParkMap.Ground.WATER
		if water:
			return false
		return world.map.is_solid(p, nav_profile)
	return world.map.is_solid(p, nav_profile)


func _update_height(delta: float) -> void:
	var p := global_position
	var gy := world.map.walk_height(p.x, p.z)
	swimming = false
	if can_swim and world.map.is_water(Vector2(p.x, p.z)) and world.map.bridge_at(Vector2(p.x, p.z)).is_empty() \
			and not world.map.is_on_stones(Vector2(p.x, p.z)):
		var ice := world.ice
		gy = ParkLayout.WATER_Y + (0.02 if ice > 0.5 else 0.0)
		swimming = ice <= 0.5
	global_position.y = lerpf(p.y, gy, clampf(delta * 14.0, 0.0, 1.0))


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in world.actors:
		if other == self or other.inside or not other.visible or other.seat != null:
			continue
		if other.lod_distance > 45.0:
			continue
		var d := Vector3(global_position.x - other.global_position.x, 0, global_position.z - other.global_position.z)
		var min_d := radius + other.radius + 0.25
		var l := d.length()
		if l < min_d and l > 0.001:
			push += d / l * (1.0 - l / min_d)
	return push


func _animate(delta: float) -> void:
	if rig == null:
		return
	var a := current_anim()
	var st := {
		"anim": a,
		"speed": Vector2(velocity.x, velocity.z).length(),
		"sad": needs.is_sad(),
		"tired": needs.fatigue > 75.0,
		"happy": needs.joy > 40.0,
		"swimming": swimming,
		"seat_height": seat.height if seat else 0.47,
	}
	if seat and a == "idle":
		st["anim"] = "sit" if seat.kind != "blanket" else "blanket"
		if seat.kind == "swing":
			st["anim"] = "swing"
	if look_target != Vector3.INF:
		var d := look_target - global_position
		st["look_yaw"] = angle_difference(yaw, atan2(d.x, d.z))
	if rig is HumanRig:
		(rig as HumanRig).set_mood(needs.joy)
	rig.animate(delta, st)


# --- Leashes ------------------------------------------------------------------------

func attach_leash(dog: Actor) -> void:
	if dog in leash_dogs:
		return
	leash_dogs.append(dog)
	dog.leash_owner = self


func detach_leash(dog: Actor) -> void:
	leash_dogs.erase(dog)
	if dog.leash_owner == self:
		dog.leash_owner = null
	if leash_dogs.is_empty() and _leash_mesh:
		_leash_mesh.queue_free()
		_leash_mesh = null


func _update_leashes() -> void:
	if _leash_mesh == null:
		_leash_mesh = MeshInstance3D.new()
		_leash_mesh.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("c0392b")
		_leash_mesh.material_override = mat
		_leash_mesh.top_level = true
		_leash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_leash_mesh)
	var im := _leash_mesh.mesh as ImmediateMesh
	im.clear_surfaces()
	if inside or lod_distance > 60.0:
		return
	var hand := global_position + forward() * 0.25 + Vector3(0, 0.85, 0) + Vector3(cos(yaw), 0, -sin(yaw)) * -0.25
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for dog in leash_dogs:
		if not is_instance_valid(dog) or dog.inside:
			continue
		var collar := dog.global_position + Vector3(0, (dog.rig.height * 0.55), 0) + dog.forward() * 0.2
		var mid := (hand + collar) * 0.5 - Vector3(0, 0.25, 0)
		im.surface_add_vertex(hand)
		im.surface_add_vertex(mid)
		im.surface_add_vertex(mid)
		im.surface_add_vertex(collar)
	im.surface_end()


# --- Persistence -----------------------------------------------------------------------

func save_state() -> void:
	GameState.actors[actor_id] = {"needs": needs.to_dict(), "pos": [global_position.x, global_position.z], "inv": inventory}


func load_state() -> void:
	var d: Dictionary = GameState.actors.get(actor_id, {})
	if d.is_empty():
		return
	needs.from_dict(d.get("needs", {}))
	inventory = d.get("inv", {})

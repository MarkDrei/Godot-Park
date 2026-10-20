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
var home_region := "park"      # "park", "forest" (the Nordwald, in the park's area), "city" or "fair" (World.allowed)
var playable := true
var vehicle: Car = null        # the car this actor drives (the player only)

## The character the player controls moves this much faster than NPCs, so the
## park is quick to cross.
const PLAYER_SPEED := 2.0

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
var dormant := false              # its area sleeps (World.enter_area): hidden, not processed
var speed_mult := 1.0
var lod_distance := 0.0           # metres to the camera's focus (World.focus)
var listen_to: Actor = null       # the player talking to this person: stands still, faces them
var _listen_time := 0.0
var _lod_slot := randi() % 8      # spreads the reduced ticks over the frames
var _lod_delta := 0.0
static var ticks := 0             # actor updates so far (the performance overlay counts them per frame)

# Presentation state.
var anim := "idle"
var _override := ""
var last_said := ""                 # last speech bubble text (read by tests)
var _override_time := 0.0
var look_target := Vector3.INF
var item := ""
## The bag: GameState.inventory, the player's, while controlled (PlayerController.control);
## NPCs carry things only for a while (bread for the ducks), it is not saved.
var inventory := {}
var leash_owner: Actor = null
var leash_dogs: Array[Actor] = []
var borrowed := false                # dog on a walk with the player: its owner leaves it alone
var _leash_mesh: MeshInstance3D
var _sad_timer := 5.0
var _repathed := false   # a stuck walk was planned again once
var _consume := ""
var _consume_time := 0.0
var _stuck_time := 0.0
var _last_pos := Vector3.ZERO
var _y_vel := 0.0
var _dodge := Vector3.ZERO     # quick step aside from a car (dodge)
var _dodge_time := 0.0
var _dodge_cooldown := 0.0


func setup(definition: Dictionary, w: World) -> void:
	def = definition.duplicate(true)
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
	home_region = "park"
	for r: String in ["forest", "city", "fair", "burg"]:
		if def.get(r, false):
			home_region = r
	nav_profile = ParkMap.Nav.HUMAN if is_human() else ParkMap.Nav.ANIMAL
	avoid = is_human() or species == "dog"
	var rates: Dictionary = def.get("rates", {})
	needs.hunger_rate *= rates.get("hunger", 1.0)
	needs.fatigue_rate *= rates.get("fatigue", 1.0)
	needs.joy_decay *= rates.get("joy", 1.0)
	_fresh_needs()
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
		"duck", "duckling", "goose", "pigeon", "heron", "owl", "raven", "falcon":
			var b := BirdRig.new()
			b.build(def.get("preset", "drake"))
			return b
		_:
			var q := QuadrupedRig.new()
			q.build(def.get("preset", "labrador"), def.get("look", {}))
			return q


## Rebuilds the visual rig from the (possibly changed) definition.
func rebuild_rig() -> void:
	var held := item
	if rig:
		rig.queue_free()
	rig = _make_rig()
	add_child(rig)
	item = ""
	if held != "":
		set_item(held)


func is_human() -> bool:
	return species in HUMAN_SPECIES


func is_player() -> bool:
	return controlled


func is_bird() -> bool:
	return species in ["duck", "duckling", "goose", "pigeon", "heron", "owl", "raven", "falcon"]


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
	_repathed = false
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
	_repathed = true  # no pathfinding here: a block is final


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
	# Off the playground's moving seats and scripted motions, or they would pull us back.
	if world.playground:
		world.playground.stop(self)
	if seat and seat.kind in Playground.SEATS:
		seat.occupant = null
		seat = null
		anim = "idle"
	rotation = Vector3(0, yaw, 0)
	global_position = Vector3(p.x, world.map.walk_height(p.x, p.z), p.z)
	_last_pos = global_position
	velocity = Vector3.ZERO
	stop_moving()
	world.actors_moved()


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
	if controlled and s.oasis != "":
		GameState.add_to_set("oases", s.oasis)


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
	rotation = Vector3(0, yaw, 0)   # upright again (a swing or a seesaw tilts its rider)
	if anim in ["sit", "sleep", "read", "chess", "swing", "blanket", "slide", "ride"]:
		anim = "idle"


## One-shot animation for `duration` seconds (overrides the activity animation).
func play_anim(name: String, duration := 2.0) -> void:
	_override = name
	_override_time = duration


## Eat or drink something over a few seconds, then apply its effect.
## Eats or drinks `food` over 4 s; its effect comes at the end. Starting another one while
## still eating finishes the first one at once, so nothing eaten gets lost.
func consume(food: String) -> void:
	if _consume != "":
		_finish_consume()
	_consume = food
	_consume_time = 4.0
	set_item(Food.item_for(food))
	play_anim("eat" if food != "water" and food != "coffee" else "drink", 4.0)


func is_consuming() -> bool:
	return _consume != ""


## Applies the food being eaten (if it is still in hand) and empties the hand.
func _finish_consume() -> void:
	var expected := Food.item_for(_consume)
	if expected == "" or item == expected:
		Food.apply(self, _consume)
		if controlled:
			emote("happy")
	set_item("")
	_consume = ""
	_consume_time = 0.0


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


## Floating name above the head (shown for characters near the player).
func set_name_tag(on: bool) -> void:
	if on and _name_tag == null:
		_name_tag = Label3D.new()
		_name_tag.text = display_name
		_name_tag.font_size = 28
		_name_tag.pixel_size = 0.003
		_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_tag.outline_size = 8
		_name_tag.modulate = Color(1, 0.96, 0.85, 0.9)
		_name_tag.no_depth_test = false
		add_child(_name_tag)
	if _name_tag:
		_name_tag.visible = on
		_name_tag.position = Vector3(0, rig.height + 0.12, 0)


var _name_tag: Label3D


## A speech bubble with the line's voice. Out of hearing (Voice.HEAR from the camera) neither
## shows: a bubble you can't hear looked like a missing voice.
func say(text: String, duration := 3.5) -> void:
	last_said = text
	if rig and Voice.in_hearing(self):
		rig.say(text, duration)
		Voice.say(self, voice(), text)


## Whose clips this actor speaks: its own, or a crowd voice (Cast "voice", VoiceLines.crowd).
func voice() -> String:
	return def.get("voice", actor_id)


func emote(icon: String, count := 1) -> void:
	if rig:
		rig.emote(icon, count)


## Puts `count` pieces into the bag; returns `count`. Nothing gets lost: what does not fit
## (Items.BAG_SLOTS slots, more with the dwarf bag) makes the bag overfull, and the player
## can't walk until it is emptied (PlayerController.held_by_bag). So results (a haul, a
## find, a reward) always go in; what the player chooses to take (buying, picking up,
## crafting, starting work) asks `room_for` first and is refused when the bag is full.
func add_item(id: String, count := 1) -> int:
	if count <= 0:
		return 0
	var fits := room(id) >= count
	inventory[id] = int(inventory.get(id, 0)) + count
	if not fits and controlled:
		GameState.toast.emit(overfull_text(), "warn")
	return count


## How many pieces of `id` still fit: room left in the last, partly filled stack plus whole
## free slots.
func room(id: String) -> int:
	var have := int(inventory.get(id, 0))
	var stack := Items.stack_size(id)
	return maxi(0, (bag_slots() - Items.slots_used(inventory)) * stack + Items.slots_for(id, have) * stack - have)


## There is room for `count` of `id`; if not, the player hears so (`hint`: what to do then).
func room_for(id: String, count := 1, hint := "") -> bool:
	if can_add(id, count):
		return true
	if controlled:
		bag_full(id, hint)
	return false


func bag_full(id: String, hint := "") -> void:
	GameState.toast.emit(("Der Rucksack ist voll! %s passt nicht mehr hinein. %s" % [Items.name_of(id), hint]).strip_edges(), "warn")


func can_add(id: String, count := 1) -> bool:
	return room(id) >= count


## More slots used than the bag has (after a switch, or a haul of several things at once).
func overfull() -> bool:
	return Items.slots_used(inventory) > bag_slots()


func overfull_text() -> String:
	return "Der Rucksack ist übervoll (%d / %d Plätze)! Iss, verkauf oder wirf etwas weg, sonst kommst du nicht vom Fleck." \
		% [Items.slots_used(inventory), bag_slots()]


func bag_slots() -> int:
	return Items.bag_slots(inventory)


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

## Every how many physics frames this actor updates: far from the camera less often, with the
## time of the skipped frames added up (walking, needs and plans stay the same, only coarser).
func lod_step() -> int:
	if controlled or lod_distance < 50.0:
		return 1
	if lod_distance < 100.0:
		return 2
	if lod_distance < 160.0:
		return 4
	return 8


func _physics_process(delta: float) -> void:
	if world == null:
		return
	lod_distance = Vector2(global_position.x - world.focus.x, global_position.z - world.focus.z).length()
	_lod_delta += delta
	# Never more than 0.15 s at once (fast forward): a longer step could skip over a wall.
	var step := mini(lod_step(), maxi(1, int(0.15 / maxf(delta, 0.001))))
	if step > 1 and (Engine.get_physics_frames() + _lod_slot) % step != 0:
		return
	delta = _lod_delta
	_lod_delta = 0.0
	ticks += 1
	var game_minutes := delta * Clock.MINUTES_PER_SECOND * Clock.time_scale
	if inside:
		needs.rest_fully()
	else:
		var fair := World.area_of(global_position) == "fair"
		var state := _need_state()
		if state in ["walk", "run"] and controlled and Potions.active("speed"):
			state = "light"   # the Lauftrank: walking and running don't tire
		needs.update(game_minutes, state, Seat.OASIS_REST if seat and seat.oasis != "" else 1.0, fair)
		if needs.is_sad() and lod_distance < 40.0:
			_sad_timer -= delta
			if _sad_timer <= 0.0:
				_sad_timer = randf_range(6.0, 12.0)
				emote("sad")
	if brain and not controlled:
		brain.update(delta)
	elif controlled and brain is AnimalBrain:
		(brain as AnimalBrain).player_tick(delta)
	if inside:
		return
	if seat == null and not custom_motion:
		if not controlled and _listening(delta):
			_stand_and_listen(delta)
		else:
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
			_finish_consume()
	_animate(delta)
	if not leash_dogs.is_empty():
		_update_leashes()


func _need_state() -> String:
	if vehicle:
		# Driving tires like walking; a car held still for a while is a seat (doc/oststadt.md).
		return "sit" if vehicle.resting() else "walk"
	var a := current_anim()
	if a == "sleep":
		return "sleep"
	if seat != null or a in ["sit", "lie", "read", "chess", "blanket"]:
		return "sit"
	if swimming:
		return "swim"
	if velocity.length() > walk_speed * _speed_boost() * 1.5:
		return "run"
	return "walk"


## People walk slower right next to the player (World.focus): half speed at 1 m, full from 3 m.
const NEAR_SLOW := 3.0


func current_speed() -> float:
	var base := run_speed if running else walk_speed
	if swimming:
		base = swim_speed * (1.6 if running else 1.0)
	if not controlled and is_human() and lod_distance < NEAR_SLOW:
		base *= lerpf(0.5, 1.0, clampf((lod_distance - 1.0) / (NEAR_SLOW - 1.0), 0.0, 1.0))
	# Hunger and fatigue slow down only the player: NPCs keep their pace, or the hungry ones
	# took hours to the next stand.
	var tired := needs.speed_factor() if controlled else 1.0
	return base * tired * speed_mult * _speed_boost() * _brisk()


## NPCs on a long way walk briskly: their own pace up to BRISK_FROM m before the goal (straight
## line), BRISK times as fast from BRISK_FULL m. A walk across the park took hours of game time.
const BRISK_FROM := 40.0
const BRISK_FULL := 120.0
const BRISK := 1.4


func _brisk() -> float:
	if controlled or running or swimming or path_i >= path.size() or not is_human():
		return 1.0
	var d := distance_to(path[path.size() - 1])
	return lerpf(1.0, BRISK, clampf((d - BRISK_FROM) / (BRISK_FULL - BRISK_FROM), 0.0, 1.0))


## The player talks to this actor (Conversations.talk): it stops where it is and faces them
## while a dialog is open and a moment after, then goes on with its way.
func listen(to: Actor) -> void:
	if controlled:
		return
	listen_to = to
	_listen_time = 1.5


func is_listening() -> bool:
	return listen_to != null


func _listening(delta: float) -> bool:
	if listen_to == null:
		return false
	if not is_instance_valid(listen_to) or listen_to.global_position.distance_to(global_position) > 5.0:
		listen_to = null
		return false
	if UI.is_dialog_open():
		_listen_time = 1.5
	else:
		_listen_time -= delta
		if _listen_time <= 0.0:
			listen_to = null
			return false
	return true


func _stand_and_listen(delta: float) -> void:
	velocity = velocity.lerp(Vector3.ZERO, clampf(delta * 12.0, 0.0, 1.0))
	face(listen_to.global_position)
	_last_pos = global_position
	_stuck_time = 0.0


func _speed_boost() -> float:
	return PLAYER_SPEED * Potions.speed_factor(self) if controlled else 1.0


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
	if _dodge_time > 0.0:
		_dodge_time -= delta
		desired = _dodge
	var accel := 10.0 if desired.length() > velocity.length() else 12.0
	velocity = velocity.lerp(desired, clampf(delta * accel, 0.0, 1.0))
	var step := velocity * delta
	if step.length() > 0.0001:
		var p := global_position
		var nxt := Vector2(p.x + step.x, p.z + step.z)
		# Standing inside an obstacle (arriving through a gate, teleported): walk out freely.
		var escaping := _blocked(Vector2(p.x, p.z))
		if not escaping and _blocked(nxt):
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
				if OS.has_environment("PARK_DEBUG_STUCK"):
					var wp := path[path_i]
					var p2 := ground_pos()
					print("STUCKDBG %s pos=(%.1f,%.1f) wp=(%.1f,%.1f) i=%d/%d vel=%.2f solid_here=%s solid_wp=%s sep=%s seat=%s" % [actor_id, p2.x, p2.y, wp.x, wp.z, path_i, path.size(),
						velocity.length(), world.map.is_solid(p2, nav_profile), world.map.is_solid(Vector2(wp.x, wp.z), nav_profile), _separation(), seat != null])
				# Pushed off the line (by others, around a corner) and now walking into an
				# obstacle: plan once more from here before giving up.
				if not _repathed and path.size() > 0:
					var goal := path[path.size() - 1]
					var keep_run := running
					go_to(goal, keep_run)
					_repathed = true
					if not path.is_empty():
						_last_pos = global_position
						return
				stop_moving()
				path_failed.emit()
		else:
			_stuck_time = 0.0
	_last_pos = global_position


func _blocked(p: Vector2) -> bool:
	# Cars are solid for walkers (nobody walks into or through a car).
	if p.x > ParkLayout.CITY_EDGE and world.city and world.city.car_at(p, radius * 0.8):
		return true
	if can_swim:
		if not ParkMap.in_world(p, 0.6):
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
	for other in world.actors_near(global_position, radius + 1.5):
		if other == self or other.seat != null or other.vehicle != null:
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
	# Nobody sees the pose of someone off screen (the smoothing catches up when they show);
	# speech bubbles and emotes still run out.
	if not controlled and lod_distance > 10.0:
		var cam := get_viewport().get_camera_3d()
		if cam and not cam.is_position_in_frustum(global_position + Vector3(0, 0.9, 0)):
			rig.update_overlays(delta)
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
	st["anim"] = pose_anim()
	if look_target != Vector3.INF:
		var d := look_target - global_position
		st["look_yaw"] = angle_difference(yaw, atan2(d.x, d.z))
	if rig is HumanRig:
		(rig as HumanRig).set_mood(needs.joy)
	rig.animate(delta, st)


## The animation the rig shows: the current one, or how this seat is sat on.
func pose_anim() -> String:
	var a := current_anim()
	if seat == null or a != "idle":
		return a
	if seat.kind == "blanket":
		return "blanket"
	if seat.kind in Playground.SEATS:
		return Playground.SEATS[seat.kind]["pose"]
	return "sit"


## A car comes: jump aside (to `side` of its heading), with a word now and then.
func dodge(car_dir: Vector3, side: float) -> void:
	if _dodge_cooldown > Clock.now() or seat != null or inside:
		return
	_dodge_cooldown = Clock.now() + 1.2
	var lateral := Vector3(-car_dir.z, 0, car_dir.x) * side
	_dodge = lateral.normalized() * 4.5
	_dodge_time = 0.45
	if is_human() and randf() < 0.5:
		say(["Huch!", "Hoppla!", "Pass doch auf!", "Uiii!", "Langsam!"][randi() % 5], 1.6)
	elif not is_human():
		play_anim("flap" if is_bird() else "idle", 0.5)


# --- Leashes ------------------------------------------------------------------------

## Falls asleep with its area (gets up, lets go of leashes, hidden, not processed) or wakes
## up (World places it by the time of day).
func set_dormant(on: bool) -> void:
	dormant = on
	if on:
		if seat:
			stand_up()
		if brain:
			brain.suspend()
		for d in leash_dogs.duplicate():
			detach_leash(d)
		if leash_owner:
			leash_owner.detach_leash(self)
		borrowed = false
	stop_moving()
	velocity = Vector3.ZERO
	inside = on
	visible = not on
	process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


func attach_leash(dog: Actor) -> void:
	if dog in leash_dogs:
		return
	if dog.leash_owner and dog.leash_owner != self:
		dog.leash_owner.detach_leash(dog)
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
	var dogs := leash_dogs.filter(func(d: Actor) -> bool: return is_instance_valid(d) and not d.inside)
	if dogs.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for dog: Actor in dogs:
		var collar := dog.global_position + Vector3(0, (dog.rig.height * 0.55), 0) + dog.forward() * 0.2
		var mid := (hand + collar) * 0.5 - Vector3(0, 0.25, 0)
		im.surface_add_vertex(hand)
		im.surface_add_vertex(mid)
		im.surface_add_vertex(mid)
		im.surface_add_vertex(collar)
	im.surface_end()


# --- Persistence -----------------------------------------------------------------------

func save_state() -> void:
	GameState.actors[actor_id] = {"needs": needs.to_dict(), "pos": [global_position.x, global_position.z]}


func _fresh_needs() -> void:
	needs.hunger = randf_range(5.0, 35.0)
	needs.fatigue = randf_range(5.0, 30.0)
	needs.joy = randf_range(55.0, 85.0)


## As at the very first start (a new game): fresh needs, an empty bag, nothing in the hands,
## off benches and leashes. Where to stand is up to Game.place_by_schedule.
func reset_for_new_game() -> void:
	if seat:
		stand_up()
	for d in leash_dogs.duplicate():
		detach_leash(d)
	stop_moving()
	inventory.clear()
	set_item("")
	_fresh_needs()


func load_state() -> void:
	var d: Dictionary = GameState.actors.get(actor_id, {})
	if d.is_empty():
		return
	needs.from_dict(d.get("needs", {}))

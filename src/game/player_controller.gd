class_name PlayerController
extends Node
## Drives the controlled actor from keyboard, gamepad, touch joystick or
## tap-to-walk; finds interaction targets and handles character switching.

signal actor_changed(actor: Actor)
signal prompt_changed(text: String)

const SWITCH_RANGE := 25.0

var world: World
var camera: CameraRig
var actor: Actor
var touch_move := Vector2.ZERO        # from the virtual joystick (-1..1)
var touch_run := false
var touch_gas := false                # touch buttons while driving
var touch_brake := false
var input_enabled := true
var focus: Object = null              # current interaction target (Interactable or Actor)
var _prompt := ""
var _focus_timer := 0.0
var _snore_timer := 0.0
var _nap_time := 0.0
var _sleeping_through := false
var _touches := {}                    # finger index -> position (fingers on the 3D view)
var _pinch_dist := 0.0
## A nap after dark sleeps through to this hour.
const WAKE_HOUR := 6.0
var _drag_start := Vector2.ZERO
var _dragging := false
var _pressed_on_view := false          # the mouse press reached the 3D view (not the UI)
var _drag_index := -1
var _midnight_checked := -1
var _hint_timer := 30.0


func setup(w: World, cam: CameraRig) -> void:
	world = w
	camera = cam


func control(a: Actor, smooth := true) -> void:
	if a == actor:
		return
	var old := actor
	if old and old.vehicle:
		exit_car(true)
	if old:
		old.controlled = false
		old.move_input = Vector3.ZERO
		old.running = false
		if old.brain:
			old.brain.resume()
	actor = a
	a.controlled = true
	if a.inside:
		a.inside = false
		a.visible = true
	if a.brain:
		a.brain.suspend()
	camera.follow(a, smooth and old != null)
	world.env.follow_target = camera
	GameState.controlled_actor = a.actor_id
	GameState.add_to_set("characters", a.actor_id)
	actor_changed.emit(a)


## Characters the player may switch to: visible and in range.
func switch_candidates() -> Array[Actor]:
	var out: Array[Actor] = []
	for a in world.actors:
		if a == actor or not a.playable or a.inside or not a.visible:
			continue
		if a.distance_to(actor.global_position) > SWITCH_RANGE:
			continue
		var screen_ok := not camera.is_position_behind(a.global_position + Vector3(0, 0.3, 0))
		if screen_ok or a.distance_to(actor.global_position) < 6.0:
			out.append(a)
	out.sort_custom(func(x: Actor, y: Actor) -> bool: return x.distance_to(actor.global_position) < y.distance_to(actor.global_position))
	return out


func _process(delta: float) -> void:
	if actor == null:
		return
	if actor.vehicle:
		_drive_input()
		_focus_timer -= delta
		if _focus_timer <= 0.0:
			_focus_timer = 0.15
			_update_focus()
			_update_name_tags()
		_checks(delta)
		return
	Sound.engine(-1.0)
	var dir := Vector2.ZERO
	if input_enabled and not UI.blocks_game_input():
		dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if touch_move.length() > 0.05:
			dir = touch_move
	var f := Vector3(-sin(camera.yaw), 0, -cos(camera.yaw))
	var r := Vector3(cos(camera.yaw), 0, -sin(camera.yaw))
	var move := (r * dir.x - f * dir.y)
	if move.length() > 0.05:
		if actor.seat:
			actor.stand_up()
		_climb_down_if_up()
		actor.stop_moving()
	actor.move_input = move
	var want_run := Input.is_action_pressed("run") or touch_run or touch_move.length() > 0.92
	if actor.is_moving() and move.length() < 0.05:
		pass
	else:
		actor.running = want_run
	_focus_timer -= delta
	if _focus_timer <= 0.0:
		_focus_timer = 0.15
		_update_focus()
		_update_name_tags()
	_checks(delta)


func _climb_down_if_up() -> void:
	if actor.brain is AnimalBrain and (actor.brain as AnimalBrain).is_up_tree():
		(actor.brain as AnimalBrain).climb_down()
		(actor.brain as AnimalBrain).player_tick(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if actor == null or not input_enabled or UI.blocks_game_input():
		return
	if event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("switch"):
		if actor.vehicle:
			if not exit_car():
				return
		UI.open_switch_menu()
	elif event.is_action_pressed("special"):
		special()
	elif event.is_action_pressed("emote"):
		emote()
	# Screens: mark the key as handled, otherwise UI._unhandled_input sees the same
	# key press and closes the screen right away.
	elif event.is_action_pressed("map"):
		UI.open_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tasks"):
		UI.open_tasks()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("bag"):
		UI.open_bag()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		UI.open_pause()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			camera.zoom_by(0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			camera.zoom_by(1.1)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if mb.pressed:
				_drag_start = mb.position
				_dragging = false
				_pressed_on_view = true
			elif _pressed_on_view and not _dragging and mb.button_index == MOUSE_BUTTON_LEFT and not Controls.touch_mode:
				# Only when the press was on the view too: clicking the map closes it on
				# press, and the release must not walk to the 3D point under the cursor.
				_tap(mb.position)
			if not mb.pressed:
				_pressed_on_view = false
	elif event is InputEventMouseMotion and not Controls.touch_mode:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
			if mm.position.distance_to(_drag_start) > 6.0:
				_dragging = true
			if _dragging:
				camera.orbit(mm.relative.x, mm.relative.y)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		# Touches on buttons belong to the buttons, not to the 3D view (otherwise
		# pressing "Spezial" on a bench would count as a tap and stand you up).
		if st.pressed and UI.point_blocked(st.position):
			return
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_pinch_dist = _pinch_distance()
		if _touches.size() >= 2:
			_dragging = true
		if st.pressed:
			if _drag_index < 0:
				_drag_index = st.index
				_drag_start = st.position
				_dragging = false
		elif st.index == _drag_index:
			if not _dragging:
				_tap(st.position)
			_drag_index = -1
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _touches.has(sd.index):
			_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			# Two fingers: pinch to zoom.
			var d := _pinch_distance()
			if _pinch_dist > 10.0 and d > 10.0:
				camera.zoom_by(_pinch_dist / d)
			_pinch_dist = d
		elif sd.index == _drag_index:
			if sd.position.distance_to(_drag_start) > 12.0:
				_dragging = true
			if _dragging:
				camera.orbit(sd.relative.x * 1.4, sd.relative.y * 1.4)
	elif event is InputEventMagnifyGesture:
		camera.zoom_by(1.0 / (event as InputEventMagnifyGesture).factor)


func _pinch_distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])


## Tap/click: on a character -> talk/switch; on the ground -> walk there.
func _tap(screen: Vector2) -> void:
	if actor.vehicle:
		return
	var picked := _pick_actor(screen)
	if picked and picked != actor:
		if picked.distance_to(actor.global_position) < 3.0:
			focus = picked
			interact()
		else:
			actor.go_to(picked.global_position, false)
		return
	var p := camera.ground_point(screen)
	if p != Vector3.INF and p.distance_to(actor.global_position) < 80.0:
		if actor.seat:
			actor.stand_up()
		_climb_down_if_up()
		if not actor.go_to(p, actor.distance_to(p) > 20.0):
			actor.rig.emote_text("?")
		else:
			UI.show_marker(p)


func _pick_actor(screen: Vector2) -> Actor:
	var best: Actor = null
	var best_d := 60.0
	for a in world.actors:
		if a.inside or not a.visible or a.distance_to(actor.global_position) > 40.0:
			continue
		var top := a.global_position + Vector3(0, a.rig.height * 0.6, 0)
		if camera.is_position_behind(top):
			continue
		var sp := camera.unproject_position(top)
		var d := sp.distance_to(screen)
		if d < best_d:
			best_d = d
			best = a
	return best


var _tagged: Array[Actor] = []


func _update_name_tags() -> void:
	var near := world.actors_near(actor.global_position, 9.0)
	for a in _tagged:
		if is_instance_valid(a) and not near.has(a):
			a.set_name_tag(false)
	_tagged.clear()
	var cam := camera.global_position
	for a in near:
		if a != actor and not a.inside:
			# Too close to the camera the tag would fill the screen.
			var far_enough := a.global_position.distance_to(cam) > 3.5
			a.set_name_tag(far_enough)
			_tagged.append(a)


func _update_focus() -> void:
	var best: Object = null
	var best_score := INF
	var pos := actor.global_position
	var driving := actor.vehicle != null
	for n in get_tree().get_nodes_in_group("interactables"):
		var it := n as Interactable
		if not it.is_visible_in_tree() or it.from_car != driving:
			continue
		var d := it.anchor().distance_to(pos)
		if d > it.radius:
			continue
		if not it.can_interact(actor) and it.get_prompt(actor) == "":
			continue
		var to := (it.anchor() - pos)
		to.y = 0
		var facing := actor.forward().dot(to.normalized()) if to.length() > 0.1 else 1.0
		var score := d - facing * 0.8
		if score < best_score:
			best_score = score
			best = it
	for a in world.actors:
		if driving:
			break
		if a == actor or a.inside or not a.visible or a.vehicle:
			continue
		var d := a.distance_to(pos)
		if d > 2.4:
			continue
		var to := a.global_position - pos
		to.y = 0
		var facing := actor.forward().dot(to.normalized()) if to.length() > 0.1 else 1.0
		var score := d - facing * 0.8 + 0.3
		if score < best_score:
			best_score = score
			best = a
	focus = best
	var text := ""
	if driving and best == null:
		text = "Aussteigen" if actor.vehicle.is_standing() else ""
	if best is Interactable:
		text = (best as Interactable).get_prompt(actor)
	elif best is Actor:
		text = "Ansprechen: %s" % (best as Actor).display_name if actor.is_human() and (best as Actor).is_human() \
			else "%s begrüßen" % (best as Actor).display_name
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


func interact() -> void:
	if _sleeping_through:
		return
	if actor.vehicle:
		if focus is Interactable and (focus as Interactable).can_interact(actor):
			(focus as Interactable).interact(actor)
		else:
			exit_car()
		return
	if is_napping():
		wake_up()
		return
	if actor.seat and not (focus is Bench):
		actor.stand_up()
		return
	if focus is Interactable:
		var it := focus as Interactable
		if it.can_interact(actor):
			it.interact(actor)
	elif focus is Actor:
		Conversations.talk(actor, focus as Actor, self)


## Species special action (F).
func special() -> void:
	if _sleeping_through:
		return
	if actor.vehicle:
		actor.vehicle.honk()
		return
	if actor.is_human() and actor.seat != null:
		if is_napping():
			wake_up()
		else:
			nap()
		return
	match actor.species:
		"dog":
			actor.play_anim("bark", 1.5)
			actor.say("Wuff!", 1.2)
			Sound.play("bark", actor.global_position)
			_scare_nearby(6.0)
		"cat":
			actor.say("Miau!", 1.2)
			Sound.play("meow", actor.global_position)
			var mouse := _nearest_species("mouse", 4.0)
			if mouse:
				actor.play_anim("pounce", 0.7)
				(mouse.brain as AnimalBrain).scare(actor.global_position)
				GameState.add_stat("mice_scared")
			else:
				actor.play_anim("groom", 2.0)
		"duck", "duckling", "goose":
			actor.play_anim("quack", 1.2)
			actor.say("Quak!" if actor.species != "goose" else "Schnatter!", 1.2)
			Sound.play("quack", actor.global_position)
		"squirrel":
			var b := actor.brain as AnimalBrain
			if b.is_up_tree():
				b.climb_down()
			else:
				var t := world.nearest_tree(actor.global_position, 3.5)
				if t.is_empty():
					GameState.toast.emit("Kein Baum in der Nähe zum Klettern.", "info")
				else:
					b._start_climb(t, t["height"] * 0.55)
		"mouse":
			actor.play_anim("upright", 1.5)
			actor.say("Piep!", 1.0)
		"pigeon":
			actor.play_anim("flap", 1.0)
			actor.say("Gurr!", 1.0)
		"hedgehog":
			actor.play_anim("lie", 2.0)
		"fox":
			actor.play_anim("sniff", 2.0)
		_:
			actor.play_anim("wave", 2.0)
			var near := world.actors_near(actor.global_position, 8.0, func(o: Actor) -> bool: return o != actor and o.is_human())
			if not near.is_empty():
				var o: Actor = near[0]
				o.face(actor.global_position)
				o.play_anim("wave", 1.5)
				o.say(["Hallo!", "Moin!", "Servus!", "Grüß Gott!", "Hi!"][randi() % 5], 2.0)


func emote() -> void:
	if actor.is_human():
		actor.play_anim("dance", 4.0)
		if Clock.is_raining():
			GameState.add_stat("rain_dance")
	else:
		actor.play_anim("roll" if actor.species == "dog" else "idle", 2.0)
	actor.emote("note" if actor.is_human() else "heart")
	actor.needs.cheer(3.0)


func _scare_nearby(r: float) -> void:
	for o in world.actors_near(actor.global_position, r):
		if o.brain is AnimalBrain and o.species in ["squirrel", "cat", "pigeon", "mouse"]:
			var b := o.brain as AnimalBrain
			if o.species == "pigeon":
				b._fly_away(actor.global_position)
			elif o.species == "mouse":
				b.scare(actor.global_position)
			else:
				b._flee(actor.global_position, 10.0)


func _nearest_species(sp: String, r: float) -> Actor:
	for o in world.actors_near(actor.global_position, r):
		if o.species == sp:
			return o
	return null


# --- Driving ----------------------------------------------------------------------

## Within a few metres of the Osttor or the forest gate east (loads the town).
static func near_city_gate(p: Vector2) -> bool:
	if p.x < ParkLayout.CITY_EDGE - 9.0:
		return false
	for id: String in ["gate_e", "gate_forest_e"]:
		if p.distance_to(ParkLayout.place(id)) < 8.0:
			return true
	return p.x > ParkLayout.CITY_EDGE - 1.0

## Gets into a standing car (Car.can_enter): the actor sits inside, the camera moves out.
func enter_car(car: Car) -> void:
	if actor == null or not car.can_enter(actor):
		return
	if actor.seat:
		actor.stand_up()
	actor.stop_moving()
	actor.vehicle = car
	actor.custom_motion = true
	actor.set_name_tag(false)
	car.driver = actor
	car.ai = null
	car.activate()
	var open: bool = car.spec["open"]
	actor.rig.visible = open
	actor.anim = "sit" if open else "idle"
	car._carry_driver()
	camera.drive(car)
	GameState.add_to_set("cars_driven", car.kind)
	Sound.play("click")
	if GameState.stat("cars_driven") <= 1 and GameState.stats.get("drive_hint", 0) == 0:
		GameState.set_stat("drive_hint", 1)
		GameState.toast.emit("Gas: %s · Lenken: %s · Aussteigen: %s · Hupe: %s" % (["Gas-Knopf", "Joystick", "„Aktion“", "„Hupe“"]
			if Controls.touch_mode else ["W", "A/D", "E", "F"]), "info")


## Gets out next to the driver's door (or wherever there is room). Only when the car is
## (almost) standing, unless `force`. Returns true when the actor is out.
func exit_car(force := false) -> bool:
	var car := actor.vehicle if actor else null
	if car == null:
		return true
	if not force and not car.is_standing():
		GameState.toast.emit("Erst anhalten!", "warn")
		return false
	car.speed = 0.0
	car.set_input(0.0, 0.0)
	car.driver = null
	actor.vehicle = null
	actor.custom_motion = false
	actor.rig.visible = true
	actor.anim = "idle"
	actor.velocity = Vector3.ZERO
	var spot := exit_spot(car)
	actor.teleport(Vector3(spot.x, 0, spot.y))
	actor.face(actor.global_position + Vector3(car.forward2().x, 0, car.forward2().y), true)
	camera.drive(null)
	Sound.engine(-1.0)
	return true


## Where the driver steps out: left of the car (driver's side), else right, front or back.
func exit_spot(car: Car) -> Vector2:
	var f := car.forward2()
	var r := Car.right_of(f)
	var p := car.pos2()
	var w := car.width() * 0.5 + 0.7
	var l := car.length() * 0.5 + 0.8
	for off: Vector2 in [-r * w, r * w, -r * w + f * 1.0, -r * w - f * 1.0, f * l, -f * l, -r * (w + 1.2), r * (w + 1.2)]:
		var q := p + off
		if not world.map.is_solid(q) and world.city and world.city.car_at(q, 0.3) == null:
			return q
	var c := world.nav.nearest_open(p - r * w)
	return ParkMap.cell_center(c) if c.x >= 0 else p - r * w


## Keyboard, gamepad and touch into the car: forward/back = gas/brake, left/right = steer.
func _drive_input() -> void:
	var car := actor.vehicle
	var dir := Vector2.ZERO
	var throttle := 0.0
	if input_enabled and not UI.blocks_game_input():
		dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if touch_move.length() > 0.05:
			dir = touch_move
		throttle = -dir.y
		if Input.get_action_strength("accelerate") > 0.1:
			throttle = Input.get_action_strength("accelerate")
		if Input.is_action_pressed("brake") or touch_brake:
			throttle = -1.0
		elif touch_gas:
			throttle = 1.0
	actor.move_input = Vector3.ZERO
	car.set_input(throttle, dir.x)
	var top: float = car.spec["max"]
	Sound.engine(clampf(absf(car.speed) / top, 0.0, 1.0))


## Nap on the current seat: fatigue drops faster than when just sitting
## (Needs.SLEEP_RECOVERY). Action, Special or walking away wakes you up.
func nap() -> void:
	actor.anim = "sleep"
	_snore_timer = 0.0
	_nap_time = 0.0
	if _is_dark():
		GameState.toast.emit("Gute Nacht! Du schläfst bis zum Sonnenaufgang …", "info")
	else:
		GameState.toast.emit("Nickerchen … Die Müdigkeit sinkt schneller. %s weckt dich." % ("„Aktion“" if Controls.touch_mode else "[E]"), "info")


func _is_dark() -> bool:
	return Clock.daylight() < 0.25


## Night on the bench: fade out, skip to sunrise, wake up rested.
func _sleep_through_night() -> void:
	_sleeping_through = true
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.root.add_child(shade)
	var tw := shade.create_tween()
	tw.tween_property(shade, "color:a", 1.0, 1.2)
	await tw.finished
	var minutes := fposmod(WAKE_HOUR * 60.0 - Clock.minutes, Clock.MINUTES_PER_DAY)
	_send_home_for_the_night()
	Clock.advance(minutes)
	var hours := minutes / 60.0
	actor.needs.fatigue = 0.0
	actor.needs.hunger = clampf(actor.needs.hunger + hours * 3.0, 0.0, 85.0)
	await get_tree().create_timer(0.8).timeout
	if is_napping():
		wake_up(true)
		actor.say("Guten Morgen!", 2.5)
	GameState.add_stat("nights_on_bench")
	tw = shade.create_tween()
	tw.tween_property(shade, "color:a", 0.0, 1.5)
	await tw.finished
	shade.queue_free()
	_sleeping_through = false


## A bed at the Waldschänke: through the night to sunrise, or a three-hour nap by day.
func sleep_in_bed(night: bool) -> void:
	if actor.seat:
		actor.stand_up()
	_sleeping_through = true
	GameState.toast.emit("Gute Nacht im Gästezimmer …" if night else "Ein Mittagsschlaf im Gästezimmer …", "info")
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.root.add_child(shade)
	var tw := shade.create_tween()
	tw.tween_property(shade, "color:a", 1.0, 1.0)
	await tw.finished
	var minutes := fposmod(WAKE_HOUR * 60.0 - Clock.minutes, Clock.MINUTES_PER_DAY) if night else 180.0
	if night:
		_send_home_for_the_night()
	Clock.advance(minutes)
	actor.needs.fatigue = 0.0
	actor.needs.hunger = clampf(actor.needs.hunger + minutes / 60.0 * 2.5, 0.0, 85.0)
	actor.needs.cheer(8.0)
	GameState.add_stat("inn_nights" if night else "inn_naps")
	await get_tree().create_timer(0.6).timeout
	actor.say("Herrlich geschlafen!", 2.5)
	tw = shade.create_tween()
	tw.tween_property(shade, "color:a", 0.0, 1.2)
	await tw.finished
	shade.queue_free()
	_sleeping_through = false


## Before the night is skipped: whoever is on the way home is home (otherwise they stood
## somewhere in the park or forest at sunrise and started work from there, hours late).
func _send_home_for_the_night() -> void:
	for a in world.actors:
		if a.controlled or a.inside or not (a.brain is HumanBrain):
			continue
		var b := a.brain as HumanBrain
		if (b.current and b.current.kind == "leave") or not b.in_hours(Clock.hour()):
			b.suspend()
			a.inside = true
			a.visible = false
			for dog in a.leash_dogs:
				dog.inside = true
				dog.visible = false


func wake_up(rested := false) -> void:
	actor.anim = "idle"
	actor.say("Ausgeschlafen!" if rested else "Hm? Bin wach!", 2.0)
	actor.needs.cheer(4.0 if rested else 0.0)


func is_napping() -> bool:
	return actor != null and actor.seat != null and actor.anim == "sleep"


func _checks(delta: float) -> void:
	# The Oststadt is built when the player comes up to one of its gates (doc/oststadt.md).
	if not world.city_loaded() and not world.city_loading and near_city_gate(actor.ground_pos()):
		world.load_city()
	if is_napping():
		_nap_time += delta
		if _is_dark() and _nap_time > 2.5 and not _sleeping_through:
			_sleep_through_night()
		_snore_timer -= delta
		if _snore_timer <= 0.0:
			_snore_timer = 5.0
			actor.say("Zzz …", 2.5)
		if actor.needs.fatigue <= 1.0 and not _sleeping_through:
			wake_up(true)
	# Night owl achievement and gentle hints.
	var h := int(Clock.hour())
	if h == 0 and _midnight_checked != Clock.day:
		_midnight_checked = Clock.day
		GameState.add_stat("midnight")
	_hint_timer -= delta
	if _hint_timer <= 0.0:
		_hint_timer = 45.0
		var n := actor.needs
		if actor.is_human() and n.hunger > 70.0:
			GameState.toast.emit("%s hat Hunger – ab zum Imbiss!" % actor.display_name, "info")
			actor.emote("hungry")
		elif n.fatigue > 75.0:
			GameState.toast.emit("%s ist müde – such dir eine Bank." % actor.display_name if actor.is_human()
				else "%s ist müde und braucht eine Pause." % actor.display_name, "info")
		elif n.joy < 25.0:
			GameState.toast.emit("%s ist traurig. Ein Minispiel macht fröhlich!" % actor.display_name, "info")
			actor.emote("sad")

class_name DriveJob
extends Minigame
## Base for the driving jobs of the Oststadt (taxi, tow truck, delivery, ice cream van,
## garbage …): the player keeps driving (free roam), a light pillar marks the target, an arrow
## over the car points along the streets (RouteArrow) and the panel shows the way. Subclasses
## call show_target() and arrived() and count bumps.
## The job goes with its vehicle (the start spot goes along with it, Gameplay._spot), wherever its
## host is; the host only speaks over the radio (radio). A job whose host gives the order
## (needs_order: Bodo's orders, Egon's oldtimer) is taken from the host first and starts when
## the player gets into the vehicle (Gameplay.vehicle_entered).

const ARRIVE := 6.0           # metres from the target point that count as "there"

var vehicle_kind := ""        # the job needs a car of this kind ("" = any car)
var target := Vector2.INF
var target_name := ""
var bumps := 0
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var arrow: RouteArrow
var guide := true             # show the arrow (off where the target is in sight, e.g. parking)
var _t := 0.0
var _car: Car
var needs_order := false      # the host gives the order: talk to them first
var order_for: Actor          # who took the order (until the job ends)
var order_option := ""        # the host's offer ("Lieferaufträge übernehmen")
var order_line := ""          # what the host says when handing out the order
var order_hint := ""          # toast: where the vehicle is
var bump_lines: Array = []    # the host over the radio after a hard bump
var radio_name := "Zentrale"  # who is on the radio when the job has no host
var on_radio := true          # false: the host is there in person (Friedrich sits beside you)
var _bump_quiet := 0.0
var _radio: Array[Dictionary] = []   # lines waiting for the panel: {text, secs}
var _radio_time := 0.0


func _init() -> void:
	free_roam = true
	host_needed = false


func can_start(a: Actor) -> bool:
	return not active and a.vehicle != null and (vehicle_kind == "" or a.vehicle.kind == vehicle_kind)


func car() -> Car:
	return actor.vehicle if actor else null


## The car the player sits in, if it is this job's kind (the start spot goes along with it).
func player_car() -> Car:
	var a: Actor = game.player.actor if game and game.player else null
	if a == null or a.vehicle == null or (vehicle_kind != "" and a.vehicle.kind != vehicle_kind):
		return null
	return a.vehicle


func blocked_text(a: Actor) -> String:
	if needs_order and order_for != a:
		var h := host()
		return "erst den Auftrag bei %s holen" % (h.display_name if h else "niemand")
	return ""


## On foot at the host: take the order (needs_order).
func host_options(player: Actor, npc: Actor) -> Array:
	if not needs_order:
		return super(player, npc)
	if active or order_for == player or player.vehicle != null or not player.is_human():
		return []
	return [{"text": order_option, "action": func() -> void: take_order(player)}]


func take_order(player: Actor) -> void:
	order_for = player
	var h := host()
	if h and order_line != "":
		h.face(player.global_position)
		h.say(order_line, 4.5)
	if order_hint != "":
		GameState.toast.emit(order_hint, "info")
	Sound.play("click")


## The host speaks over the radio: the line goes into the panel (after the one before it) and
## is spoken as loud as a dialog, wherever the host is.
func radio(text: String) -> void:
	var h := host()
	if h:
		h.last_said = text
	panel_line("Funk · %s" % (h.display_name if h else radio_name), text)
	Voice.radio(host_id, text)


## A line in the panel, "who: „text“" (a passenger in the car, the radio).
func panel_line(who: String, text: String) -> void:
	_radio.append({"text": "%s: „%s“" % [who, text], "secs": clampf(text.length() * 0.08, 2.5, 6.0)})
	if _radio_time <= 0.0:
		_next_line()


func _next_line() -> void:
	if not is_instance_valid(_line_label):
		_radio.clear()
		return
	if _radio.is_empty():
		_radio_time = 0.0
		_line_label.visible = false
		return
	var l: Dictionary = _radio.pop_front()
	_line_label.text = l["text"]
	_line_label.visible = true
	_radio_time = l["secs"]


## The host is somewhere else in town: what they say comes over the radio.
func host_say(text: String, duration := 3.0) -> void:
	if on_radio:
		radio(text)
	else:
		super(text, duration)


## A random line of `lines` (fixed lines: they have voice clips).
func pick(lines: Array) -> String:
	return lines[rng.randi() % lines.size()]


## The host's last words for the result dialog (spoken: Minigame.end speaks quoted words).
func quote(text: String) -> String:
	var h := host()
	return "\n\n%s: „%s“" % [h.display_name, text] if h and text != "" else ""


## Called by begin() of subclasses.
func start_driving() -> void:
	bumps = 0
	_car = actor.vehicle
	if _car and not _car.bumped.is_connected(_on_bump):
		_car.bumped.connect(_on_bump)


func _on_bump(hard: float) -> void:
	if active and hard > 3.0:
		bumps += 1
		if _bump_quiet <= 0.0:
			_bump_quiet = 12.0
			bumped_hard()


## Override: what is said after a hard bump (default: the host over the radio).
func bumped_hard() -> void:
	if not bump_lines.is_empty():
		radio(pick(bump_lines))


## The light pillar (and the panel line) for a target point.
func show_target(p: Vector2, name := "", color := Color(1.0, 0.82, 0.3)) -> void:
	target = p
	target_name = name
	if _beam == null:
		_beam = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.6
		cyl.bottom_radius = 1.6
		cyl.height = 40.0
		cyl.cap_top = false
		cyl.cap_bottom = false
		_beam.mesh = cyl
		_beam_mat = ShaderMaterial.new()
		_beam_mat.shader = preload("res://src/shaders/beam.gdshader")
		_beam.material_override = _beam_mat
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(_beam)
	_beam.visible = true
	_beam.position = Vector3(p.x, 20.0, p.y)
	if name != "":
		set_info("Ziel: %s (Lichtsäule)" % name)
	_beam_mat.set_shader_parameter("color", color)
	if guide:
		if arrow == null:
			arrow = RouteArrow.new()
			world.add_child(arrow)
		arrow.show_for(car(), p, color)


func hide_target() -> void:
	target = Vector2.INF
	if _beam:
		_beam.visible = false
	if arrow:
		arrow.clear()


## The player's car stands at the target.
func arrived(radius := ARRIVE) -> bool:
	var c := car()
	return c != null and target != Vector2.INF and c.is_standing() and c.pos2().distance_to(target) < radius


## The way to the target for the panel ("320 m, in 40 m rechts"): along the streets, with the
## arrow's next turn; the target's name is in the info line.
func way_text() -> String:
	if target == Vector2.INF or actor == null:
		return ""
	if arrow and arrow.visible and not arrow.info.is_empty():
		return "%d m, %s" % [int(arrow.info["left"]), arrow.hint()]
	return "%d m" % int(actor.ground_pos().distance_to(target))


func _process(delta: float) -> void:
	_t += delta
	if _beam_mat:
		_beam_mat.set_shader_parameter("t", _t)
	if not active:
		return
	_bump_quiet -= delta
	if _radio_time > 0.0:
		_radio_time -= delta
		if _radio_time <= 0.0:
			_next_line()
	# Getting out of the job's car ends the job.
	if actor.vehicle == null or (_car and actor.vehicle != _car):
		job_left()
		return
	job_tick(delta)


## Override: per-frame job logic while driving.
func job_tick(_delta: float) -> void:
	pass


## Override: the player left the car.
func job_left() -> void:
	end({"won": false, "joy": 3.0, "text": "Schicht beendet – du bist ausgestiegen." + quote(left_line())})


## Override: the host's words when the player gets out during the job.
func left_line() -> String:
	return ""


func cleanup() -> void:
	order_for = null
	_radio.clear()
	_radio_time = 0.0
	hide_target()
	if _car and _car.bumped.is_connected(_on_bump):
		_car.bumped.disconnect(_on_bump)


## A house between min_dist and max_dist from p (taxi and delivery destinations).
func house_away_from(p: Vector2, min_dist: float, rng: RandomNumberGenerator, max_dist := INF) -> Dictionary:
	var houses := CityLayout.houses()
	for i in 80:
		var h: Dictionary = houses[rng.randi() % houses.size()]
		var d := (h["curb"] as Vector2).distance_to(p)
		if d >= min_dist and d <= max_dist:
			return h
	return houses[0]

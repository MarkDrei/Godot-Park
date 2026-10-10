class_name DriveJob
extends Minigame
## Base for the driving jobs of the Oststadt (taxi, tow truck, delivery, ice cream van,
## garbage …): the player keeps driving (free roam), a light pillar marks the target and the
## panel shows the way. Subclasses call show_target() and arrived() and count bumps.

const ARRIVE := 6.0           # metres from the target point that count as "there"

var vehicle_kind := ""        # the job needs a car of this kind ("" = any car)
var target := Vector2.INF
var target_name := ""
var bumps := 0
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _t := 0.0
var _car: Car


func _init() -> void:
	free_roam = true


func can_start(a: Actor) -> bool:
	return not active and a.vehicle != null and (vehicle_kind == "" or a.vehicle.kind == vehicle_kind)


func car() -> Car:
	return actor.vehicle if actor else null


## Called by begin() of subclasses.
func start_driving() -> void:
	bumps = 0
	_car = actor.vehicle
	if _car and not _car.bumped.is_connected(_on_bump):
		_car.bumped.connect(_on_bump)


func _on_bump(hard: float) -> void:
	if active and hard > 3.0:
		bumps += 1


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


func hide_target() -> void:
	target = Vector2.INF
	if _beam:
		_beam.visible = false


## The player's car stands at the target.
func arrived(radius := ARRIVE) -> bool:
	var c := car()
	return c != null and target != Vector2.INF and c.is_standing() and c.pos2().distance_to(target) < radius


## Distance to the target for the panel ("140 m"); the target's name is in the info line.
func way_text() -> String:
	if target == Vector2.INF or actor == null:
		return ""
	return "%d m" % int(actor.ground_pos().distance_to(target))


func _process(delta: float) -> void:
	_t += delta
	if _beam_mat:
		_beam_mat.set_shader_parameter("t", _t)
	if not active:
		return
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
	end({"won": false, "joy": 3.0, "text": "Schicht beendet – du bist ausgestiegen."})


func cleanup() -> void:
	hide_target()
	if _car and _car.bumped.is_connected(_on_bump):
		_car.bumped.disconnect(_on_bump)


## A house far enough from p (taxi and delivery destinations).
func house_away_from(p: Vector2, min_dist: float, rng: RandomNumberGenerator) -> Dictionary:
	var houses := CityLayout.houses()
	for i in 40:
		var h: Dictionary = houses[rng.randi() % houses.size()]
		if (h["curb"] as Vector2).distance_to(p) >= min_dist:
			return h
	return houses[0]

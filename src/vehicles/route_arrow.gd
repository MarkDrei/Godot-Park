class_name RouteArrow
extends Node3D
## The navigation arrow of the driving jobs (DriveJob): floats over the player's car and
## points along the way through the streets (CityRoute) to the target, round the next corner
## shortly before a crossing where the way turns. Glows like the target's light pillar.

const HEIGHT := 1.4            # metres over the car's roof
const TILT := 0.32             # the tip is lifted towards the chase camera (radians)
const SIZE := 1.25
const REROUTE := 0.4           # seconds between route updates

var car: Car
var target := Vector2.INF
var route := PackedVector2Array()
var info := {}                 # CityRoute.guide(): aim, turn, in
var _mat: ShaderMaterial
var _mesh: MeshInstance3D
var _t := 0.0
var _next := 0.0
var _yaw := 0.0


func _init() -> void:
	name = "RouteArrow"
	_mesh = MeshInstance3D.new()
	_mesh.mesh = arrow_mesh()
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/shaders/route_arrow.gdshader")
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false


## A flat arrow pointing to +Z, 2.7 m long: a light top on a slightly larger dark plate, so
## it stands out against sky and asphalt.
static func arrow_mesh() -> Mesh:
	return NatureModels.cached("route_arrow", func() -> Mesh:
		var kit := MeshKit.new()
		var shape := PackedVector2Array([Vector2(0, 1.3), Vector2(1.0, 0.1), Vector2(0.42, 0.1), Vector2(0.42, -1.1),
			Vector2(-0.42, -1.1), Vector2(-0.42, 0.1), Vector2(-1.0, 0.1)])
		var big := PackedVector2Array()
		for q in shape:
			big.append(q * 1.12 + Vector2(0, -0.02))
		kit.prism(shape, 0.0, 0.16, Color(0.3, 0.3, 0.3), Color.WHITE, false)
		kit.prism(big, -0.08, 0.04, Color(0.12, 0.12, 0.12), Color(0.12, 0.12, 0.12), true)
		return kit.commit())


func show_for(c: Car, t: Vector2, color: Color) -> void:
	car = c
	target = t
	_mat.set_shader_parameter("color", color)
	_next = 0.0
	if car:
		_yaw = car.yaw
	visible = car != null


func clear() -> void:
	target = Vector2.INF
	car = null
	route = PackedVector2Array()
	info = {}
	visible = false


func _process(delta: float) -> void:
	if car == null or not is_instance_valid(car) or target == Vector2.INF:
		visible = false
		return
	_t += delta
	_next -= delta
	var p := car.pos2()
	var fwd := car.forward2() * (1.0 if car.speed >= -0.5 else -1.0)
	if _next <= 0.0 or route.is_empty():
		_next = REROUTE
		route = CityRoute.route(p, fwd, target)
	info = CityRoute.guide(p, fwd, route)
	var aim: Vector2 = info["aim"]
	var to := aim - p
	var want := atan2(to.x, to.y) if to.length() > 0.5 else _yaw
	_yaw = lerp_angle(_yaw, want, minf(1.0, delta * 6.0))
	var top := float(car.spec.get("height", 1.5))
	global_position = Vector3(p.x, car.base_y + top + HEIGHT + sin(_t * 3.0) * 0.12, p.y)
	rotation = Vector3(-TILT, _yaw, 0.0)
	scale = Vector3.ONE * SIZE
	_mat.set_shader_parameter("t", _t)
	visible = true


## Short German hint for the job panel: "in 40 m rechts", "wenden", "gleich da".
func hint() -> String:
	if info.is_empty():
		return ""
	var dist := int(round(float(info["in"]) / 10.0) * 10.0)
	match info["turn"]:
		"left":
			return "links abbiegen" if dist <= 15 else "in %d m links" % dist
		"right":
			return "rechts abbiegen" if dist <= 15 else "in %d m rechts" % dist
		"back":
			return "bitte wenden"
		"there":
			return "gleich da"
	return "geradeaus"

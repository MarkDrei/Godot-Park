class_name CameraRig
extends Camera3D
## Third-person orbit camera with terrain avoidance, smooth target switching
## and an override mode for minigames.

var target: Actor
var world: World
var yaw := PI
var pitch := -0.32
var distance := 5.5
var zoom := 1.0
var height := 1.5
var manual_timer := 0.0
var sensitivity := 1.0

var _focus := Vector3.ZERO
var _transition := 0.0
var _transition_from := Vector3.ZERO
var _override := false
var _override_xf := Transform3D()
var _override_blend := 0.0
var _shake := 0.0


func setup(w: World) -> void:
	world = w
	fov = 62.0
	near = 0.08
	far = 900.0
	current = true


func follow(a: Actor, smooth := true) -> void:
	if smooth and target:
		_transition_from = _focus
		_transition = 1.0
	target = a
	var size := a.rig.height
	height = clampf(size * 0.85, 0.3, 1.6)
	distance = clampf(size * 3.4, 2.4, 6.0)
	pitch = -0.32 if size > 1.2 else -0.42
	if not smooth:
		yaw = a.yaw + PI
		_focus = a.global_position + Vector3(0, height, 0)


func orbit(dx: float, dy: float) -> void:
	yaw -= dx * 0.005 * sensitivity
	pitch = clampf(pitch - dy * 0.004 * sensitivity, -1.25, 0.35)
	manual_timer = 2.5


func zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, 0.45, 3.5)


func shake(amount := 0.3) -> void:
	_shake = amount


## Camera transform override (minigames, cut-scenes). Pass null-ish via end_override.
func set_override(xf: Transform3D) -> void:
	_override = true
	_override_xf = xf


func end_override() -> void:
	_override = false


func _process(delta: float) -> void:
	if target == null or world == null:
		return
	var desired_focus := target.global_position + Vector3(0, height, 0)
	if _transition > 0.0:
		_transition = maxf(0.0, _transition - delta / 1.2)
		var k := 1.0 - _transition
		k = k * k * (3.0 - 2.0 * k)
		_focus = _transition_from.lerp(desired_focus, k)
	else:
		_focus = _focus.lerp(desired_focus, clampf(delta * 10.0, 0.0, 1.0))
	# Drift behind the character while walking, unless the player steers the camera.
	manual_timer -= delta
	var turn := Input.get_axis("cam_left", "cam_right")
	if absf(turn) > 0.1:
		yaw -= turn * delta * 2.2
		manual_timer = 2.5
	if manual_timer <= 0.0 and target.velocity.length() > 0.6:
		yaw = lerp_angle(yaw, target.yaw + PI, clampf(delta * 0.8, 0.0, 1.0))
	var d := distance * zoom
	var offset := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * d
	var pos := _focus + offset
	# Keep above ground (and bridges).
	var steps := 6
	for i in range(1, steps + 1):
		var p := _focus.lerp(pos, float(i) / steps)
		var gy := world.map.walk_height(p.x, p.z) + 0.35
		if p.y < gy:
			pos.y += gy - p.y
	var xf := Transform3D(Basis(), pos).looking_at(_focus, Vector3.UP)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		xf.origin += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.1
	_override_blend = move_toward(_override_blend, 1.0 if _override else 0.0, delta * 1.6)
	if _override_blend > 0.0:
		var k2 := _override_blend * _override_blend * (3.0 - 2.0 * _override_blend)
		xf = xf.interpolate_with(_override_xf, k2)
	global_transform = xf


## Ground point under a screen position (ray-marched against the height field).
func ground_point(screen: Vector2) -> Vector3:
	var o := project_ray_origin(screen)
	var dir := project_ray_normal(screen)
	var t := 0.0
	for i in 400:
		var p := o + dir * t
		var gy := world.map.walk_height(p.x, p.z)
		if p.y <= gy:
			return Vector3(p.x, gy, p.z)
		t += 0.25 if t < 30.0 else 0.6
		if t > 160.0:
			break
	return Vector3.INF

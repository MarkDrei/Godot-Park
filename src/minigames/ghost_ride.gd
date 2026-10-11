class_name GhostRide
extends Ride
## Geisterbahn: the car rolls in through the left door, past five funny frights in the dark,
## and out of the right door. The inside only exists during the ride.

const SPEED := 2.3
## The track in the building's own coordinates (x along the front, +z towards the doors).
const TRACK := [Vector2(-5.5, 11.0), Vector2(-5.5, 7.0), Vector2(-5.5, 4.0), Vector2(-9.0, 2.0), Vector2(-10.0, -2.5),
	Vector2(-7.0, -5.5), Vector2(-2.0, -3.5), Vector2(2.5, -5.5), Vector2(7.5, -4.5), Vector2(10.0, -0.5),
	Vector2(7.5, 3.0), Vector2(5.5, 4.0), Vector2(5.5, 7.0), Vector2(5.5, 11.0)]
## The frights: where on the track (0..1), where they stand, what the panel says.
const FRIGHTS := [
	[0.17, Vector2(-11.0, 0.5), "ghost", "Huuuh! Ein Gespenst! … Es winkt freundlich und wünscht gute Fahrt."],
	[0.38, Vector2(-7.5, -6.6), "skeleton", "Ein Skelett spielt Xylophon – auf seinen eigenen Rippen."],
	[0.52, Vector2(0.0, -4.5), "spider", "Eine Riesenspinne seilt sich ab. „Schönen Tag noch!“"],
	[0.66, Vector2(4.0, -6.6), "pumpkin", "Ein Kürbis kichert. Und kichert. Und kichert."],
	[0.8, Vector2(11.0, -1.0), "vampire", "Graf Zahnlos lächelt dich an. Ganz ohne Zähne."],
]

var _inside: Node3D
var _props: Array[Node3D] = []
var _popped := []
var _length := 0.0
var _flash: OmniLight3D
var _rabbit: Node3D           # Hoppel in the dark (FairStories, the magician's quest)


func _init() -> void:
	title = "Geisterbahn"
	host_id = "geistgustav"
	cost = 250
	ride_id = "ghost"
	joy = 32.0
	duration = 40.0


func describe() -> String:
	return "Eine Fahrt durch die lustige Geisterbahn – nur für Mutige. 2,50 € bei Geister-Gustav im Westpark."


func _world(q: Vector2) -> Vector3:
	var b := fair().ghost_base
	return Vector3(b.x + q.x, b.y, b.z + q.y)


func ride_begin() -> void:
	fair().ride_ghost = true
	fair().ghost_car.visible = true
	_length = 0.0
	for i in TRACK.size() - 1:
		_length += (TRACK[i] as Vector2).distance_to(TRACK[i + 1])
	duration = _length / SPEED + 1.5
	_popped = []
	_build_inside()
	host_say("Gute Fahrt! Und keine Angst … hoffentlich.")


func ride_end() -> void:
	fair().ride_ghost = false
	_rabbit = null
	if is_instance_valid(_inside):
		_inside.queue_free()
	_props.clear()


## Point and direction at `s` metres along the track.
func _pose(s: float) -> Array:
	s = clampf(s, 0.0, _length)
	for i in TRACK.size() - 1:
		var a: Vector2 = TRACK[i]
		var b: Vector2 = TRACK[i + 1]
		var l := a.distance_to(b)
		if s <= l or i == TRACK.size() - 2:
			var q := a.lerp(b, clampf(s / maxf(l, 0.001), 0.0, 1.0))
			var d := (b - a).normalized()
			return [_world(q), Vector3(d.x, 0, d.y)]
		s -= l
	return [_world(TRACK[0]), Vector3.FORWARD]


func ride_update(delta: float) -> void:
	var s := clampf((t - 0.5) * SPEED, 0.0, _length)
	var pose: Array = _pose(s)
	var car := fair().ghost_car
	car.global_transform = Transform3D(Basis.looking_at(-(pose[1] as Vector3), Vector3.UP), (pose[0] as Vector3) + Vector3(0, 0.1, 0))
	var k := s / _length
	for i in FRIGHTS.size():
		var fr: Array = FRIGHTS[i]
		if i in _popped or k < fr[0]:
			continue
		_popped.append(i)
		set_info(fr[3])
		Sound.play("owl" if fr[2] in ["ghost", "vampire"] else "flap", null, -6.0)
		if _flash:
			_flash.global_position = _world(fr[1]) + Vector3(0, 2.0, 1.5)
			_flash.light_energy = 3.0
	if k > 0.9 and _rabbit == null and FairStories.step() == 2 and Gameplay.stories:
		set_info(Gameplay.stories.in_ghost_train())
		_rabbit = Node3D.new()
		var rm := MeshInstance3D.new()
		rm.mesh = FairModels.rabbit()
		_rabbit.add_child(rm)
		_rabbit.position = _world(Vector2(8.5, 5.0))
		_rabbit.scale = Vector3.ONE * 1.6
		_inside.add_child(_rabbit)
	if _rabbit:
		_rabbit.position.x += delta * 1.2
	# The frights jump out and settle; the flash fades.
	for i in _props.size():
		var target := 1.0 if i in _popped else 0.05
		var n := _props[i]
		n.scale = n.scale.lerp(Vector3.ONE * target, clampf(delta * 8.0, 0.0, 1.0))
		if FRIGHTS[i][2] == "spider" and i in _popped:
			n.position.y = lerpf(n.position.y, fair().ghost_base.y + 1.2, clampf(delta * 3.0, 0.0, 1.0))
		if FRIGHTS[i][2] == "skeleton":
			n.rotation.y = sin(t * 6.0) * 0.3
	if _flash:
		_flash.light_energy = move_toward(_flash.light_energy, 0.6, delta * 3.0)


func mount() -> Transform3D:
	return fair().ghost_car.global_transform.translated_local(Vector3(0, 0.32, -0.3))


func camera_pose() -> Array:
	var xf := fair().ghost_car.global_transform
	return [xf * Vector3(0, 1.75, -1.7), xf * Vector3(0, 1.1, 4.0)]


## A dark hall inside the building (walls facing inwards), the rails and the frights.
func _build_inside() -> void:
	_inside = Node3D.new()
	_inside.name = "GhostInside"
	add_child(_inside)
	var b := fair().ghost_base
	var kit := MeshKit.new()
	kit.use("unshaded")
	var lo := Vector3(b.x - 12.7, b.y + 0.02, b.z - 6.8)
	var hi := Vector3(b.x + 12.7, b.y + 6.8, b.z + 6.8)
	var wall := Color("2e1d42")
	var floor_col := Color("16101c")
	# Floor, ceiling and walls, all seen from inside.
	kit.quad(Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), floor_col)
	kit.quad(Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), wall.darkened(0.4))
	kit.quad(Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), wall)
	kit.quad(Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z), wall)
	kit.quad(Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, lo.y, hi.z), wall)
	kit.quad(Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), wall)
	# Stripes, glowing slime, staring eyes and lanterns on the walls, stars on the ceiling.
	for i in 30:
		var x := lo.x + 0.5 + i * 0.83
		kit.quad(Vector3(x, lo.y + 0.4 + (i % 3) * 0.2, lo.z + 0.02), Vector3(x + 0.5, lo.y + 0.4 + ((i + 1) % 3) * 0.2, lo.z + 0.02),
			Vector3(x + 0.5, lo.y + 1.0, lo.z + 0.02), Vector3(x, lo.y + 1.0, lo.z + 0.02), Color("3fa82a"))
		kit.quad(Vector3(x, lo.y + 1.0, lo.z + 0.015), Vector3(x + 0.25, lo.y + 1.0, lo.z + 0.015), Vector3(x + 0.25, hi.y, lo.z + 0.015), Vector3(x, hi.y, lo.z + 0.015), Color("3a2654"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 14:
		var side_z := lo.z + 0.03 if i % 2 == 0 else hi.z - 0.03
		var ex := lo.x + 1.5 + i * 1.7
		var ey := lo.y + rng.randf_range(2.2, 4.5)
		var n := 1.0 if i % 2 == 0 else -1.0
		for dx: float in [-0.18, 0.18]:
			_eye(kit, Vector3(ex + dx, ey, side_z), n)
	for i in 60:
		var sp := Vector3(rng.randf_range(lo.x, hi.x), hi.y - 0.03, rng.randf_range(lo.z, hi.z))
		kit.quad(sp + Vector3(-0.04, 0, -0.04), sp + Vector3(0.04, 0, -0.04), sp + Vector3(0.04, 0, 0.04), sp + Vector3(-0.04, 0, 0.04), Color("fff6c0"))
	for i in range(2, TRACK.size() - 2, 2):
		var lp := _world(TRACK[i]) + (Vector3(1.8, 0, 0) if TRACK[i].x < 0.0 else Vector3(-1.8, 0, 0))
		kit.box(lp + Vector3(0, 1.6, 0.0), Vector3(0.18, 0.26, 0.18), Color("ff9a30"))
		kit.box(lp + Vector3(0, 0.8, 0.0), Vector3(0.05, 1.6, 0.05), Color("3a3040"))
	# Cobwebs in the corners.
	for c: Vector3 in [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z)]:
		var dx := 1.4 if c.x < b.x else -1.4
		var dz := 1.4 if c.z < b.z else -1.4
		kit.tri(c + Vector3(0, -0.02, 0), c + Vector3(dx, -0.02, 0), c + Vector3(0, -1.2, 0), Color(0.85, 0.85, 0.9))
		kit.tri(c + Vector3(0, -0.02, 0), c + Vector3(0, -1.2, 0), c + Vector3(dx, -0.02, 0), Color(0.85, 0.85, 0.9))
		kit.tri(c + Vector3(0, -0.02, 0), c + Vector3(0, -0.02, dz), c + Vector3(0, -1.2, 0), Color(0.85, 0.85, 0.9))
		kit.tri(c + Vector3(0, -0.02, 0), c + Vector3(0, -1.2, 0), c + Vector3(0, -0.02, dz), Color(0.85, 0.85, 0.9))
	for i in TRACK.size() - 1:
		var a := _world(TRACK[i])
		var c := _world(TRACK[i + 1])
		var d := (c - a).normalized()
		var side := Vector3(-d.z, 0, d.x) * 0.55
		for k: float in [1.0, -1.0]:
			var r0 := a + side * k + Vector3(0, 0.04, 0)
			var r1 := c + side * k + Vector3(0, 0.04, 0)
			var r2 := c + side * k * 0.85 + Vector3(0, 0.04, 0)
			var r3 := a + side * k * 0.85 + Vector3(0, 0.04, 0)
			kit.quad(r0, r1, r2, r3, Color("8a8a9a"))
			kit.quad(r0, r3, r2, r1, Color("8a8a9a"))
	var shell := MeshInstance3D.new()
	shell.mesh = kit.commit()
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_inside.add_child(shell)
	_props.clear()
	for fr: Array in FRIGHTS:
		var n := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = _fright_mesh(fr[2])
		n.add_child(mi)
		var p := _world(fr[1])
		n.position = p + (Vector3(0, 4.5, 0) if fr[2] == "spider" else Vector3.ZERO)
		n.rotation.y = atan2(b.x - p.x, (b.z + 2.0) - p.z)
		n.scale = Vector3.ONE * 0.05
		_inside.add_child(n)
		_props.append(n)
	_flash = OmniLight3D.new()
	_flash.light_color = Color("c8a0ff")
	_flash.omni_range = 9.0
	_flash.light_energy = 0.6
	_flash.position = b + Vector3(0, 4.0, 0)
	_inside.add_child(_flash)


## A staring eye painted on a wall (n: +1 on the back wall, -1 on the front wall).
static func _eye(kit: MeshKit, c: Vector3, n: float) -> void:
	for k in 8:
		var a0 := TAU * k / 8
		var a1 := TAU * (k + 1) / 8
		var p0 := c + Vector3(cos(a0) * 0.13, sin(a0) * 0.09, 0)
		var p1 := c + Vector3(cos(a1) * 0.13, sin(a1) * 0.09, 0)
		if n > 0:
			kit.tri(c, p0, p1, Color("f4f2ff"))
		else:
			kit.tri(c, p1, p0, Color("f4f2ff"))
	var q := c + Vector3(0, 0, 0.005 * n)
	if n > 0:
		kit.quad(q + Vector3(-0.04, -0.04, 0), q + Vector3(0.04, -0.04, 0), q + Vector3(0.04, 0.04, 0), q + Vector3(-0.04, 0.04, 0), Color("101010"))
	else:
		kit.quad(q + Vector3(-0.04, -0.04, 0), q + Vector3(-0.04, 0.04, 0), q + Vector3(0.04, 0.04, 0), q + Vector3(0.04, -0.04, 0), Color("101010"))


static func _fright_mesh(kind: String) -> Mesh:
	var kit := MeshKit.new()
	kit.use("unshaded")
	var white := Color("f4f2ff")
	var dark := Color("161018")
	match kind:
		"ghost":
			kit.sphere(Vector3(0, 2.0, 0), Vector3(0.7, 0.8, 0.6), white, 4, 8)
			kit.cylinder(Vector3(0, 0.4, 0), 1.6, 0.9, 0.65, 8, white)
			kit.sphere(Vector3(-0.25, 2.15, 0.52), Vector3(0.12, 0.16, 0.06), dark, 2, 5)
			kit.sphere(Vector3(0.25, 2.15, 0.52), Vector3(0.12, 0.16, 0.06), dark, 2, 5)
			kit.rod(Vector3(0.6, 1.6, 0), Vector3(1.2, 2.3, 0.2), 0.15, 0.1, 5, white)
		"skeleton":
			kit.sphere(Vector3(0, 1.75, 0), Vector3(0.18, 0.22, 0.2), white, 3, 6)
			kit.beam(Vector3(0, 1.0, 0), Vector3(0, 1.55, 0), Vector2(0.06, 0.06), white)
			for k in 4:
				kit.beam(Vector3(-0.22, 1.45 - k * 0.12, 0.02), Vector3(0.22, 1.45 - k * 0.12, 0.02), Vector2(0.03, 0.03), white)
			for s: float in [-1.0, 1.0]:
				kit.beam(Vector3(s * 0.2, 1.5, 0), Vector3(s * 0.45, 1.1, 0.25), Vector2(0.04, 0.04), white)
				kit.beam(Vector3(s * 0.1, 1.0, 0), Vector3(s * 0.15, 0.0, 0), Vector2(0.05, 0.05), white)
			kit.box(Vector3(0, 0.9, 0.4), Vector3(0.9, 0.08, 0.3), Color("e2c050"))
		"spider":
			kit.sphere(Vector3(0, 0, 0), Vector3(0.6, 0.45, 0.7), dark.lightened(0.1), 4, 8)
			kit.sphere(Vector3(-0.2, 0.15, 0.6), Vector3(0.1, 0.1, 0.06), Color("ff5050"), 2, 5)
			kit.sphere(Vector3(0.2, 0.15, 0.6), Vector3(0.1, 0.1, 0.06), Color("ff5050"), 2, 5)
			for s: float in [-1.0, 1.0]:
				for k in 4:
					var z := -0.4 + k * 0.27
					kit.beam(Vector3(s * 0.45, 0, z), Vector3(s * 1.1, 0.35, z * 1.4), Vector2(0.05, 0.05), dark.lightened(0.2))
					kit.beam(Vector3(s * 1.1, 0.35, z * 1.4), Vector3(s * 1.4, -0.4, z * 1.6), Vector2(0.05, 0.05), dark.lightened(0.2))
			kit.beam(Vector3(0, 0.4, 0), Vector3(0, 6.0, 0), Vector2(0.02, 0.02), white)
		"pumpkin":
			kit.sphere(Vector3(0, 0.55, 0), Vector3(0.75, 0.55, 0.75), Color("ff8a1a"), 4, 10)
			kit.cylinder(Vector3(0, 1.05, 0), 0.25, 0.08, 0.06, 5, Color("3f7a3a"))
			kit.tri(Vector3(-0.35, 0.75, 0.72), Vector3(-0.15, 0.75, 0.74), Vector3(-0.25, 0.92, 0.72), Color("fff060"))
			kit.tri(Vector3(0.15, 0.75, 0.74), Vector3(0.35, 0.75, 0.72), Vector3(0.25, 0.92, 0.72), Color("fff060"))
			kit.quad(Vector3(-0.35, 0.45, 0.72), Vector3(0.35, 0.45, 0.72), Vector3(0.25, 0.3, 0.73), Vector3(-0.25, 0.3, 0.73), Color("fff060"))
		"vampire":
			kit.cylinder(Vector3(0, 0, 0), 1.4, 0.55, 0.3, 8, dark)
			kit.lathe(PackedVector2Array([Vector2(0.9, 0.0), Vector2(0.4, 1.5)]), 8, Color("8e1f2b"))
			kit.sphere(Vector3(0, 1.75, 0), Vector3(0.22, 0.26, 0.22), Color("d8e8d0"), 3, 6)
			kit.box(Vector3(0, 2.02, 0), Vector3(0.4, 0.1, 0.4), dark)
			kit.box(Vector3(0, 1.62, 0.2), Vector3(0.14, 0.03, 0.03), Color("8e1f2b"))
	return kit.commit()


func info_text() -> String:
	return "Es wird dunkel …"


func end_text() -> String:
	return "Wieder draußen! Das war ja gar nicht so gruselig. Oder doch?"

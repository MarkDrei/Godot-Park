class_name CityModels
extends RefCounted
## Procedural models of the Oststadt (doc/oststadt.md): cars of every kind, low houses and
## the buildings and props of the lots. Origins sit on the ground; front faces +Z.

const GLASS := Color("2b3a48")
const TYRE := Color("1e1e1e")
const HUB := Color("b8bcc0")
const CHROME := Color("d8dcdf")
const BUMPER := Color("2a2a2e")
const ASPHALT := Color("4a4a4e")
const WHITE := Color("f1eee6")
const SIGN_YELLOW := Color("f2c230")


static func cached(key: String, builder: Callable) -> Mesh:
	return NatureModels.cached("city_" + key, builder)


# --- Cars ---------------------------------------------------------------------------

## Extrudes a side profile (points (z, y), counter-clockwise) across the width (x).
static func _side(kit: MeshKit, profile: PackedVector2Array, width: float, col: Color) -> void:
	kit.push(Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), Vector3.ZERO))
	kit.prism(profile, -width * 0.5, width * 0.5, col, Color(0, 0, 0, 0), true)
	kit.pop()


static func _wheels(kit: MeshKit, wheelbase: float, width: float, r: float, rear_offset := 0.0, extra_axle := false) -> void:
	var zs := [wheelbase * 0.5 - rear_offset, -wheelbase * 0.5 - rear_offset]
	if extra_axle:
		zs.append(-wheelbase * 0.5 - rear_offset - r * 2.3)
	for z: float in zs:
		for s: float in [-1.0, 1.0]:
			var x := s * (width * 0.5 - 0.12)
			kit.push(Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(x, r, z)))
			kit.cylinder(Vector3(0, -0.13, 0), 0.26, r, r, 10, TYRE)
			kit.cylinder(Vector3(0, -0.14, 0), 0.28, r * 0.5, r * 0.5, 8, HUB)
			kit.pop()


static func _lights(kit: MeshKit, length: float, width: float, y: float, front := Color("fff3c0"), rear := Color("ff4030")) -> void:
	kit.use("glow")
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(s * (width * 0.5 - 0.3), y, length * 0.5 + 0.01), Vector3(0.36, 0.14, 0.03), front)
		kit.box(Vector3(s * (width * 0.5 - 0.25), y + 0.05, -length * 0.5 - 0.01), Vector3(0.3, 0.16, 0.03), rear)
	kit.use("solid")


static func _bumpers(kit: MeshKit, length: float, width: float, y := 0.38) -> void:
	kit.box(Vector3(0, y, length * 0.5 + 0.02), Vector3(width + 0.04, 0.16, 0.12), BUMPER)
	kit.box(Vector3(0, y, -length * 0.5 - 0.02), Vector3(width + 0.04, 0.16, 0.12), BUMPER)


## A passenger car: body up to the belt line, glass cabin, painted roof.
## hood: front overhang to the windscreen; tail: roof end from the rear; roof_h: roof height.
static func _sedan(kit: MeshKit, length: float, width: float, col: Color, hood: float, tail: float, roof_h: float, belt := 0.95) -> void:
	var hl := length * 0.5
	var body := PackedVector2Array([Vector2(-hl, 0.32), Vector2(hl, 0.32), Vector2(hl, 0.72), Vector2(hl - 0.25, belt - 0.08),
		Vector2(-hl + 0.08, belt), Vector2(-hl, belt - 0.1)])
	_side(kit, body, width, col)
	var ws := hl - hood                    # windscreen base (z)
	var ws_top := ws - (roof_h - belt) * 0.9
	var back := -hl + tail
	var cabin := PackedVector2Array([Vector2(-hl + 0.12, belt), Vector2(ws, belt - 0.04), Vector2(ws_top, roof_h),
		Vector2(back + 0.25, roof_h), Vector2(back, belt + (roof_h - belt) * 0.15)])
	if tail < 0.2:
		cabin = PackedVector2Array([Vector2(-hl + 0.06, belt), Vector2(ws, belt - 0.04), Vector2(ws_top, roof_h),
			Vector2(-hl + 0.12, roof_h), Vector2(-hl + 0.04, belt + 0.1)])
	_side(kit, cabin, width - 0.16, GLASS)
	# Painted roof and pillars over the glass.
	var roof_back := (back + 0.25) if tail >= 0.2 else (-hl + 0.12)
	kit.box(Vector3(0, roof_h + 0.03, (ws_top + roof_back) * 0.5), Vector3(width - 0.12, 0.07, ws_top - roof_back + 0.06), col)
	for s: float in [-1.0, 1.0]:
		var x := s * (width * 0.5 - 0.07)
		kit.beam(Vector3(x, belt - 0.04, ws), Vector3(x, roof_h, ws_top), Vector2(0.08, 0.08), col)
		kit.beam(Vector3(x, belt, (ws + roof_back) * 0.5), Vector3(x, roof_h, (ws_top + roof_back) * 0.5), Vector2(0.07, 0.07), col)
	# Side mirrors and door line.
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(s * (width * 0.5 + 0.08), belt + 0.06, ws - 0.1), Vector3(0.14, 0.1, 0.16), col.darkened(0.2))
		kit.box(Vector3(s * (width * 0.5 + 0.005), 0.66, (ws + roof_back) * 0.5), Vector3(0.01, 0.4, 0.02), col.darkened(0.35))


static func car(kind: String, col: Color) -> Mesh:
	return cached("car_%s_%s" % [kind, col.to_html()], func() -> Mesh:
		var sp := CarSpecs.spec(kind)
		var L: float = sp["length"]
		var W: float = sp["width"]
		var wb: float = sp["wheelbase"]
		var kit := MeshKit.new()
		kit.use("nosnow")
		kit.use("solid")
		match kind:
			"small", "learner":
				_sedan(kit, L, W, col, 1.05, 0.0, 1.5)
				_wheels(kit, wb, W, 0.31)
				_bumpers(kit, L, W)
				_lights(kit, L, W, 0.7)
				if kind == "learner":
					kit.box(Vector3(0, 1.68, -0.1), Vector3(0.9, 0.3, 0.22), WHITE)
					kit.box(Vector3(0, 1.68, -0.1), Vector3(0.94, 0.12, 0.24), Color("2e86de"))
			"kombi", "taxi":
				_sedan(kit, L, W, col, 1.15, 0.0, 1.5)
				_wheels(kit, wb, W, 0.32)
				_bumpers(kit, L, W)
				_lights(kit, L, W, 0.7)
				kit.beam(Vector3(-0.55, 1.56, -1.6), Vector3(-0.55, 1.56, 0.3), Vector2(0.04, 0.04), CHROME)
				kit.beam(Vector3(0.55, 1.56, -1.6), Vector3(0.55, 1.56, 0.3), Vector2(0.04, 0.04), CHROME)
				if kind == "taxi":
					kit.use("glow")
					kit.box(Vector3(0, 1.68, -0.3), Vector3(0.7, 0.22, 0.3), Color("ffe680"))
					kit.use("solid")
					kit.box(Vector3(0, 1.56, -0.3), Vector3(0.76, 0.04, 0.34), BUMPER)
			"van", "delivery":
				var hl := L * 0.5
				var h: float = sp["height"]
				var body := PackedVector2Array([Vector2(-hl, 0.35), Vector2(hl, 0.35), Vector2(hl, 0.95), Vector2(hl - 0.5, 1.15),
					Vector2(hl - 1.1, h), Vector2(-hl, h)])
				_side(kit, body, W, col)
				var glass := PackedVector2Array([Vector2(hl - 0.48, 1.18), Vector2(hl - 1.06, h - 0.12), Vector2(hl - 1.5, h - 0.12), Vector2(hl - 1.5, 1.18)])
				_side(kit, glass, W + 0.02, GLASS)
				_wheels(kit, wb, W, 0.34)
				_bumpers(kit, L, W, 0.42)
				_lights(kit, L, W, 0.8)
				if kind == "delivery":
					for s: float in [-1.0, 1.0]:
						kit.box(Vector3(s * (W * 0.5 + 0.01), 1.35, -0.6), Vector3(0.02, 0.7, 2.2), SIGN_YELLOW)
						kit.box(Vector3(s * (W * 0.5 + 0.02), 1.35, -0.6), Vector3(0.02, 0.4, 0.4), Color("6b3e26"))
					kit.cylinder(Vector3(0, h, -0.6), 0.12, 0.35, 0.35, 10, Color("d9a35c"))
					kit.cylinder(Vector3(0, h + 0.12, -0.6), 0.08, 0.36, 0.36, 10, Color("6b3e26"))
					kit.sphere(Vector3(0, h + 0.26, -0.6), Vector3(0.36, 0.14, 0.36), Color("e0a050"), 2, 10)
			"tow":
				var hl := L * 0.5
				# Cab in front, flat bed with the crane boom behind.
				var cab := PackedVector2Array([Vector2(hl - 2.2, 0.45), Vector2(hl, 0.45), Vector2(hl, 1.2), Vector2(hl - 0.5, 1.4),
					Vector2(hl - 0.8, 2.5), Vector2(hl - 2.2, 2.5)])
				_side(kit, cab, W, col)
				_side(kit, PackedVector2Array([Vector2(hl - 0.48, 1.45), Vector2(hl - 0.78, 2.38), Vector2(hl - 1.6, 2.38), Vector2(hl - 1.6, 1.45)]), W + 0.02, GLASS)
				kit.box(Vector3(0, 0.75, -0.9), Vector3(W, 0.4, L - 2.0), Color("3a3a3e"))
				kit.box(Vector3(0, 1.0, -0.9), Vector3(W, 0.1, L - 2.2), Color("8a8f96"))
				kit.beam(Vector3(0, 1.0, -L * 0.5 + 0.4), Vector3(0, 2.4, -L * 0.5 + 1.6), Vector2(0.22, 0.22), SIGN_YELLOW)
				kit.beam(Vector3(0, 2.4, -L * 0.5 + 1.6), Vector3(0, 2.0, -L * 0.5 - 0.2), Vector2(0.18, 0.18), SIGN_YELLOW)
				kit.beam(Vector3(0, 2.0, -L * 0.5 - 0.2), Vector3(0, 0.7, -L * 0.5 - 0.3), Vector2(0.03, 0.03), Color("2a2a2a"))
				kit.box(Vector3(0, 0.6, -L * 0.5 - 0.3), Vector3(0.6, 0.12, 0.12), Color("2a2a2a"))
				kit.use("glow")
				kit.box(Vector3(0, 2.6, hl - 1.5), Vector3(1.0, 0.16, 0.25), Color("ffa020"))
				kit.use("solid")
				_wheels(kit, wb, W, 0.42, 0.5)
				_lights(kit, L, W, 0.85)
			"icecream":
				var hl := L * 0.5
				var h: float = sp["height"]
				var body := PackedVector2Array([Vector2(-hl, 0.35), Vector2(hl, 0.35), Vector2(hl, 0.95), Vector2(hl - 0.5, 1.2),
					Vector2(hl - 1.0, h), Vector2(-hl, h)])
				_side(kit, body, W, col)
				_side(kit, PackedVector2Array([Vector2(hl - 0.48, 1.22), Vector2(hl - 0.96, h - 0.12), Vector2(hl - 1.4, h - 0.12), Vector2(hl - 1.4, 1.22)]), W + 0.02, GLASS)
				# Serving hatch on the right (kerb) side, stripes and the cone on the roof.
				kit.box(Vector3(-W * 0.5 - 0.01, 1.45, -0.7), Vector3(0.03, 0.75, 1.8), Color("3a2a20"))
				kit.box(Vector3(-W * 0.5 - 0.25, 1.05, -0.7), Vector3(0.5, 0.06, 1.8), WHITE)
				for s: float in [-1.0, 1.0]:
					kit.box(Vector3(s * (W * 0.5 + 0.005), 0.8, -0.3), Vector3(0.02, 0.18, L - 0.8), Color("f28db2"))
				kit.cylinder(Vector3(0, h, -0.6), 0.9, 0.05, 0.38, 8, Color("e0b070"))
				kit.sphere(Vector3(0, h + 1.05, -0.6), Vector3(0.45, 0.4, 0.45), Color("f7c6d9"), 3, 8)
				kit.sphere(Vector3(0.05, h + 1.4, -0.58), Vector3(0.3, 0.26, 0.3), Color("9be0c0"), 3, 8)
				_wheels(kit, wb, W, 0.34)
				_bumpers(kit, L, W, 0.42)
				_lights(kit, L, W, 0.8)
			"garbage":
				var hl := L * 0.5
				var cab := PackedVector2Array([Vector2(hl - 2.0, 0.5), Vector2(hl, 0.5), Vector2(hl, 1.4), Vector2(hl - 0.3, 2.6),
					Vector2(hl - 2.0, 2.7)])
				_side(kit, cab, W, col)
				_side(kit, PackedVector2Array([Vector2(hl - 0.25, 1.5), Vector2(hl - 0.42, 2.45), Vector2(hl - 1.3, 2.5), Vector2(hl - 1.3, 1.5)]), W + 0.02, GLASS)
				var box := PackedVector2Array([Vector2(-hl, 0.6), Vector2(hl - 2.1, 0.6), Vector2(hl - 2.1, 3.0), Vector2(-hl + 0.6, 3.0), Vector2(-hl, 2.4)])
				_side(kit, box, W - 0.05, col.darkened(0.1))
				for s: float in [-1.0, 1.0]:
					kit.box(Vector3(s * (W * 0.5 - 0.01), 1.4, -1.0), Vector3(0.02, 0.25, L - 3.5), WHITE)
				kit.box(Vector3(0, 1.2, -hl - 0.25), Vector3(W - 0.3, 1.2, 0.5), Color("3a3a3e"))
				kit.use("glow")
				kit.box(Vector3(0, 2.75, hl - 1.2), Vector3(0.9, 0.14, 0.22), Color("ffa020"))
				kit.use("solid")
				_wheels(kit, wb, W, 0.48, 0.6, true)
				_lights(kit, L, W, 0.9)
			"oldtimer":
				var hl := L * 0.5
				# Long bonnet, open two-seater, round fenders and chrome.
				var body := PackedVector2Array([Vector2(-hl + 0.2, 0.42), Vector2(hl - 0.2, 0.42), Vector2(hl, 0.62), Vector2(hl - 0.1, 0.9),
					Vector2(-0.2, 0.95), Vector2(-0.4, 1.1), Vector2(-hl + 0.4, 1.0), Vector2(-hl, 0.75)])
				_side(kit, body, W - 0.3, col)
				for z: float in [wb * 0.5, -wb * 0.5]:
					for s: float in [-1.0, 1.0]:
						kit.sphere(Vector3(s * (W * 0.5 - 0.2), 0.62, z), Vector3(0.24, 0.3, 0.62), col.darkened(0.08), 3, 8)
				for s: float in [-1.0, 1.0]:
					kit.box(Vector3(s * (W * 0.5 - 0.2), 0.42, 0.0), Vector3(0.3, 0.05, wb - 1.1), BUMPER)
					kit.cylinder(Vector3(s * 0.5, 0.75, hl - 0.15), 0.05, 0.14, 0.14, 8, CHROME)
				kit.box(Vector3(0, 0.75, hl - 0.05), Vector3(0.6, 0.45, 0.06), CHROME)
				kit.box(Vector3(0, 1.15, -0.05), Vector3(W - 0.4, 0.32, 0.04), Color(GLASS, 1.0).lightened(0.3))
				kit.box(Vector3(0, 0.62, -0.75), Vector3(W - 0.5, 0.06, 0.9), Color("6b3e26"))   # seat
				kit.box(Vector3(0, 0.85, -1.15), Vector3(W - 0.5, 0.5, 0.12), Color("6b3e26"))
				kit.cylinder(Vector3(-0.35, 0.95, -0.1), 0.05, 0.18, 0.18, 10, Color("2a2a2a"))  # steering wheel
				_wheels(kit, wb, W - 0.1, 0.36)
				_lights(kit, L, W - 0.6, 0.75)
			"kart":
				kit.box(Vector3(0, 0.12, 0), Vector3(W - 0.3, 0.06, L - 0.2), Color("2a2a2e"))
				kit.box(Vector3(0, 0.22, L * 0.5 - 0.15), Vector3(W - 0.4, 0.16, 0.3), col)
				kit.box(Vector3(0, 0.2, -L * 0.5 + 0.12), Vector3(W, 0.12, 0.18), col)
				for s: float in [-1.0, 1.0]:
					kit.box(Vector3(s * (W * 0.5 - 0.22), 0.22, 0.0), Vector3(0.18, 0.14, 0.9), col)
				kit.box(Vector3(0, 0.3, -0.25), Vector3(0.45, 0.06, 0.5), Color("1a1a1a"))
				kit.box(Vector3(0, 0.5, -0.5), Vector3(0.45, 0.4, 0.06), Color("1a1a1a"))
				kit.beam(Vector3(0, 0.22, 0.35), Vector3(0, 0.45, 0.15), Vector2(0.04, 0.04), Color("2a2a2a"))
				kit.cylinder(Vector3(0, 0.45, 0.12), 0.03, 0.14, 0.14, 8, Color("2a2a2a"))
				_wheels(kit, L * 0.62, W, 0.17)
		return kit.commit())


## A crushed wreck for the scrapyard (stacks and the crane).
static func wreck(col: Color, v: int) -> Mesh:
	return cached("wreck_%s_%d" % [col.to_html(), v], func() -> Mesh:
		var kit := MeshKit.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = v
		kit.box(Vector3(0, 0.35, 0), Vector3(1.75, 0.7, 4.0), col.darkened(0.25), col.darkened(0.1))
		kit.box(Vector3(0, 0.78, -0.2), Vector3(1.5, 0.2, 2.0), col.darkened(0.35))
		for i in 3:
			kit.box(Vector3(rng.randf_range(-0.6, 0.6), 0.71, rng.randf_range(-1.6, 1.6)), Vector3(0.4, 0.04, 0.5), Color("8a5a34"))
		return kit.commit())


# --- Houses -------------------------------------------------------------------------

## Appends a low house (CityLayout.houses() entry) with door, windows and roof to kit.
static func house_into(kit: MeshKit, h: Dictionary) -> void:
	var r: Rect2 = h["rect"]
	var front: Vector2 = h["front"]
	var c := r.get_center()
	# Local frame: front of the house faces +Z.
	var yaw := atan2(front.x, front.y)
	var w := r.size.x if front.y != 0.0 else r.size.y
	var d := r.size.y if front.y != 0.0 else r.size.x
	var floors: int = h["floors"]
	var wall_h := floors * 3.0
	var col: Color = h["color"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(h["id"])
	kit.push(Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, 0.0, c.y)))
	kit.use("solid")
	kit.box(Vector3(0, wall_h * 0.5 + 0.05, 0), Vector3(w, wall_h, d), col)
	kit.box(Vector3(0, 0.3, 0), Vector3(w + 0.1, 0.6, d + 0.1), col.darkened(0.3))   # plinth
	if h["roof"] == "gable":
		_gable_roof(kit, w, d, wall_h + 0.05, 2.2, h["roof_color"], col)
	else:
		kit.box(Vector3(0, wall_h + 0.25, 0), Vector3(w + 0.2, 0.4, d + 0.2), col.darkened(0.15))
		kit.box(Vector3(0, wall_h + 0.08, 0), Vector3(w - 0.2, 0.06, d - 0.2), Color("6a6a6e"))
	# Door with a little canopy and step.
	var door_x := rng.randf_range(-w * 0.25, w * 0.25)
	kit.box(Vector3(door_x, 1.1, d * 0.5 + 0.03), Vector3(1.1, 2.1, 0.06), [Color("6b3e26"), Color("2e5e44"), Color("8a3b2b"), Color("2c3e50")][rng.randi() % 4])
	kit.box(Vector3(door_x, 2.35, d * 0.5 + 0.35), Vector3(1.6, 0.08, 0.7), col.darkened(0.35))
	kit.box(Vector3(door_x, 0.08, d * 0.5 + 0.4), Vector3(1.4, 0.16, 0.8), Color("a8a196"))
	# Windows: front and back on every floor, sides on the upper floors; some lit at night.
	var cols := maxi(2, int(w / 2.4))
	for f in floors:
		var y := 1.55 + f * 3.0
		for i in cols:
			var x := -w * 0.5 + (i + 0.5) * w / cols
			if f == 0 and absf(x - door_x) < 1.2:
				continue
			_window(kit, Vector3(x, y, d * 0.5), 0.0, rng)
			_window(kit, Vector3(x, y, -d * 0.5), PI, rng)
		if f > 0 or rng.randf() < 0.5:
			for s: float in [-1.0, 1.0]:
				_window(kit, Vector3(s * w * 0.5, y, 0.0), s * PI / 2, rng)
	kit.pop()


static func _window(kit: MeshKit, p: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	kit.push(Transform3D(Basis(Vector3.UP, yaw), p))
	kit.box(Vector3(0, 0, 0.02), Vector3(1.2, 1.45, 0.05), WHITE)
	if rng.randf() < 0.35:
		kit.use("glow")
		kit.box(Vector3(0, 0, 0.05), Vector3(1.0, 1.25, 0.02), Color("ffd98a"))
		kit.use("solid")
	else:
		kit.box(Vector3(0, 0, 0.05), Vector3(1.0, 1.25, 0.02), Color("5a7085"))
	kit.box(Vector3(0, -0.75, 0.1), Vector3(1.3, 0.06, 0.18), WHITE)
	kit.pop()


## Gable roof over a w × d box, ridge along x, with gable walls in the wall colour.
static func _gable_roof(kit: MeshKit, w: float, d: float, y0: float, rise: float, col: Color, wall: Color) -> void:
	var x := w * 0.5 + 0.3
	var z := d * 0.5 + 0.35
	var top := y0 + rise
	kit.quad(Vector3(-x, y0 - 0.15, z), Vector3(x, y0 - 0.15, z), Vector3(x, top, 0), Vector3(-x, top, 0), col)
	kit.quad(Vector3(x, y0 - 0.15, -z), Vector3(-x, y0 - 0.15, -z), Vector3(-x, top, 0), Vector3(x, top, 0), col)
	kit.quad(Vector3(-x, y0 - 0.25, z), Vector3(-x, top - 0.1, 0), Vector3(x, top - 0.1, 0), Vector3(x, y0 - 0.25, z), col.darkened(0.3))
	kit.quad(Vector3(x, y0 - 0.25, -z), Vector3(x, top - 0.1, 0), Vector3(-x, top - 0.1, 0), Vector3(-x, y0 - 0.25, -z), col.darkened(0.3))
	for s: float in [1.0, -1.0]:
		var gx := w * 0.5 * s
		var p0 := Vector3(gx, y0, d * 0.5)
		var p1 := Vector3(gx, y0, -d * 0.5)
		var p2 := Vector3(gx, top - 0.05, 0)
		if s > 0:
			kit.tri(p0, p1, p2, wall)
		else:
			kit.tri(p1, p0, p2, wall)


## A lot building (CityLayout.BUILDINGS entry) into kit.
static func building_into(kit: MeshKit, b: Dictionary) -> void:
	var r: Rect2 = b["rect"]
	var c := r.get_center()
	var h: float = b["h"]
	var col: Color = b["color"]
	kit.push(Transform3D(Basis(), Vector3(c.x, 0.0, c.y)))
	kit.use("solid")
	match b.get("roof", "flat"):
		"spire":
			kit.box(Vector3(0, h * 0.5 * 0.7, 0), Vector3(r.size.x, h * 0.7, r.size.y), col)
			kit.lathe(PackedVector2Array([Vector2(r.size.x * 0.75, h * 0.7), Vector2(0.0, h * 1.25)]), 4, Color("4a5a50"), PI / 4)
			kit.use("glow")
			kit.cylinder(Vector3(0, h * 0.55, r.size.y * 0.5 + 0.02), 0.04, 0.9, 0.9, 12, Color("f4f0e0"))
			kit.use("solid")
		"gable":
			var along_x := r.size.x >= r.size.y
			var w := r.size.x if along_x else r.size.y
			var d := r.size.y if along_x else r.size.x
			kit.push(Transform3D(Basis(Vector3.UP, 0.0 if along_x else PI / 2), Vector3.ZERO))
			kit.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), col)
			_gable_roof(kit, w, d, h, minf(3.2, d * 0.4), Color("7a4a3a"), col)
			kit.pop()
		_:
			if b.get("open_z", false):
				for s: float in [-1.0, 1.0]:
					kit.box(Vector3(s * (r.size.x * 0.5 - 0.3), h * 0.5, 0), Vector3(0.6, h, r.size.y), col)
				kit.box(Vector3(0, h - 0.3, 0), Vector3(r.size.x, 0.6, r.size.y), col.darkened(0.1))
			else:
				kit.box(Vector3(0, h * 0.5, 0), Vector3(r.size.x, h, r.size.y), col)
				kit.box(Vector3(0, h + 0.2, 0), Vector3(r.size.x + 0.2, 0.4, r.size.y + 0.2), col.darkened(0.2))
				# A band of windows (lit at night) and a darker plinth all round.
				kit.box(Vector3(0, 0.3, 0), Vector3(r.size.x + 0.06, 0.6, r.size.y + 0.06), col.darkened(0.35))
				var band: Color = b.get("band", Color("f4f0e0"))
				kit.box(Vector3(0, h - 0.55, 0), Vector3(r.size.x + 0.04, 0.5, r.size.y + 0.04), band)
				kit.use("glow")
				for side in 4:
					var w := r.size.x if side % 2 == 0 else r.size.y
					var n := int(w / 3.0)
					for i in n:
						var u := -w * 0.5 + (i + 0.5) * w / n
						var y := minf(1.7, h * 0.45)
						var sz := Vector3(1.6, minf(1.1, h * 0.3), 0.04)
						var col2 := Color("8fb0c8") if i % 3 != 1 else Color("ffd98a")
						match side:
							0: kit.box(Vector3(u, y, r.size.y * 0.5 + 0.03), sz, col2)
							1: kit.box(Vector3(r.size.x * 0.5 + 0.03, y, u), Vector3(0.04, sz.y, sz.x), col2)
							2: kit.box(Vector3(u, y, -r.size.y * 0.5 - 0.03), sz, col2)
							3: kit.box(Vector3(-r.size.x * 0.5 - 0.03, y, u), Vector3(0.04, sz.y, sz.x), col2)
				kit.use("solid")
	kit.pop()


# --- Street furniture ---------------------------------------------------------------

static func street_lamp() -> Mesh:
	return cached("street_lamp", func() -> Mesh:
		var kit := MeshKit.new()
		var iron := Color("4a5058")
		kit.cylinder(Vector3.ZERO, 0.3, 0.16, 0.12, 8, iron)
		kit.cylinder(Vector3(0, 0.3, 0), 4.7, 0.07, 0.05, 6, iron)
		kit.beam(Vector3(0, 4.9, 0), Vector3(0, 5.0, 1.2), Vector2(0.06, 0.06), iron)
		kit.box(Vector3(0, 4.95, 1.3), Vector3(0.36, 0.12, 0.6), iron)
		kit.use("glow")
		kit.box(Vector3(0, 4.87, 1.3), Vector3(0.3, 0.04, 0.5), Color("fff0c0"))
		return kit.commit())


## Street name sign on a pole; labels are added by the builder.
static func sign_pole() -> Mesh:
	return cached("sign_pole", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 2.9, 0.05, 0.05, 6, Color("8a8f96"))
		kit.box(Vector3(0, 2.6, 0), Vector3(1.5, 0.26, 0.04), Color("f4f4f4"))
		kit.box(Vector3(0, 2.6, 0), Vector3(1.42, 0.2, 0.05), Color("2a4a8a"))
		kit.box(Vector3(0, 2.25, 0), Vector3(0.04, 0.26, 1.5), Color("f4f4f4"))
		kit.box(Vector3(0, 2.25, 0), Vector3(0.05, 0.2, 1.42), Color("2a4a8a"))
		return kit.commit())


## Traffic light: pole and head facing +Z with three dark lamps (the lit one is lamp_disc).
static func traffic_light() -> Mesh:
	return cached("traffic_light", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 3.7, 0.07, 0.06, 6, Color("3a3e44"))
		kit.box(Vector3(0, 3.05, 0), Vector3(0.36, 1.0, 0.26), Color("2a2a2e"))
		kit.box(Vector3(0, 3.05, -0.02), Vector3(0.44, 1.1, 0.04), Color("f4f4f4"))
		for y: float in [3.35, 3.05, 2.75]:
			kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, y, 0.135)))
			kit.cylinder(Vector3.ZERO, 0.01, 0.11, 0.11, 10, Color("3a3a36"))
			kit.pop()
			kit.box(Vector3(0, y + 0.12, 0.2), Vector3(0.26, 0.03, 0.14), Color("2a2a2e"))
		return kit.commit())


## The lit lamp of a traffic light (material set by Traffic).
static func lamp_disc() -> Mesh:
	return cached("lamp_disc", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("unshaded")
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
		kit.cylinder(Vector3.ZERO, 0.02, 0.105, 0.105, 10, Color.WHITE)
		kit.pop()
		return kit.commit())


## Sales counter with an awning (2 m wide, customer side +Z).
static func counter() -> Mesh:
	return cached("counter", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.5, 0), Vector3(2.0, 1.0, 0.5), Color("e8e2d0"))
		kit.box(Vector3(0, 1.03, 0.05), Vector3(2.1, 0.06, 0.65), Color("8a6a4a"))
		for x: float in [-0.95, 0.95]:
			kit.beam(Vector3(x, 1.0, -0.2), Vector3(x, 2.4, -0.2), Vector2(0.06, 0.06), Color("8a8f96"))
		kit.box(Vector3(0, 2.45, 0.2), Vector3(2.3, 0.08, 1.1), Color("c0392b"))
		return kit.commit())


static func planter() -> Mesh:
	return cached("planter", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.3, 0), Vector3(1.2, 0.6, 1.2), Color("a8a196"))
		kit.use("foliage")
		kit.sphere(Vector3(0, 0.85, 0), Vector3(0.6, 0.45, 0.6), Color("4f8a3a"), 3, 6, 0.15, 3)
		return kit.commit())


static func bollard() -> Mesh:
	return cached("bollard", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.9, 0.09, 0.08, 8, Color("5a5a5e"))
		kit.cylinder(Vector3(0, 0.7, 0), 0.08, 0.095, 0.095, 8, WHITE)
		return kit.commit())


static func traffic_cone() -> Mesh:
	return cached("traffic_cone", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.02, 0), Vector3(0.4, 0.04, 0.4), Color("e8602e"))
		kit.cylinder(Vector3(0, 0.04, 0), 0.6, 0.15, 0.03, 8, Color("f07030"))
		kit.cylinder(Vector3(0, 0.3, 0), 0.1, 0.095, 0.08, 8, WHITE)
		return kit.commit())


static func tyre_stack(n: int) -> Mesh:
	return cached("tyre_stack_%d" % n, func() -> Mesh:
		var kit := MeshKit.new()
		for i in n:
			kit.torus(Vector3(0, 0.12 + i * 0.24, 0), 0.32, 0.12, 10, 5, TYRE)
		return kit.commit())


static func wheelie_bin(col: Color) -> Mesh:
	return cached("wheelie_bin_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.5, 0), Vector3(0.6, 0.95, 0.7), col)
		kit.box(Vector3(0, 1.0, -0.02), Vector3(0.64, 0.06, 0.76), col.darkened(0.25))
		for s: float in [-1.0, 1.0]:
			kit.push(Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(s * 0.28, 0.1, -0.3)))
			kit.cylinder(Vector3(0, -0.04, 0), 0.08, 0.1, 0.1, 6, TYRE)
			kit.pop()
		return kit.commit())


# --- Lot props ----------------------------------------------------------------------

## Cinema screen, 20 m wide, front +Z, on two lattice posts.
static func cinema_screen() -> Mesh:
	return cached("cinema_screen", func() -> Mesh:
		var kit := MeshKit.new()
		var steel := Color("6a6e74")
		for s: float in [-1.0, 1.0]:
			for k: float in [-0.6, 0.6]:
				kit.beam(Vector3(s * 8.0 + k, 0, -0.8), Vector3(s * 8.0 + k, 12.0, -0.3), Vector2(0.18, 0.18), steel)
			for i in 6:
				kit.beam(Vector3(s * 8.0 - 0.6, i * 2.0, -0.7), Vector3(s * 8.0 + 0.6, i * 2.0 + 2.0, -0.4), Vector2(0.08, 0.08), steel)
		kit.box(Vector3(0, 7.6, -0.25), Vector3(20.6, 9.4, 0.3), Color("2a2a2e"))
		kit.box(Vector3(0, 2.6, -0.2), Vector3(20.6, 0.5, 0.4), Color("c0392b"))
		return kit.commit())


static func speaker_post() -> Mesh:
	return cached("speaker_post", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 1.2, 0.05, 0.05, 6, Color("5a5a5e"))
		kit.box(Vector3(0, 1.25, 0), Vector3(0.3, 0.25, 0.14), Color("8a8f96"))
		kit.box(Vector3(0, 1.25, 0.075), Vector3(0.22, 0.16, 0.02), Color("2a2a2e"))
		return kit.commit())


## Drive-in order post with menu board (front +Z faces the car).
static func order_post() -> Mesh:
	return cached("order_post", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 0.3), Color("3a3a3e"))
		kit.box(Vector3(0, 1.0, 0.16), Vector3(0.3, 0.2, 0.02), Color("8a8f96"))
		kit.box(Vector3(0, 1.4, -0.4), Vector3(0.12, 2.8, 0.12), Color("3a3a3e"))
		kit.box(Vector3(0, 2.1, -0.32), Vector3(2.2, 1.3, 0.12), Color("d8402e"))
		kit.use("glow")
		kit.box(Vector3(0, 2.1, -0.25), Vector3(2.0, 1.1, 0.02), Color("fff3d0"))
		kit.use("solid")
		for i in 4:
			kit.box(Vector3(-0.6, 2.5 - i * 0.26, -0.23), Vector3(0.5, 0.14, 0.02), [Color("d9a35c"), Color("f2c230"), Color("e0e0e0"), Color("c0392b")][i])
		return kit.commit())


## Big burger sign on a pole for the drive-in (6 m).
static func burger_sign() -> Mesh:
	return cached("burger_sign", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 5.0, 0.16, 0.14, 8, Color("5a5a5e"))
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 5.8, 0)))
		kit.cylinder(Vector3(0, -0.25, 0), 0.22, 1.1, 1.1, 14, Color("d9a35c"))
		kit.cylinder(Vector3(0, -0.03, 0), 0.12, 1.15, 1.15, 14, Color("6b3e26"))
		kit.cylinder(Vector3(0, 0.09, 0), 0.06, 1.2, 1.2, 14, Color("4caf50"))
		kit.cylinder(Vector3(0, 0.15, 0), 0.06, 1.15, 1.15, 14, Color("f2c230"))
		kit.cylinder(Vector3(0, 0.21, 0), 0.22, 1.1, 0.8, 14, Color("e0a050"))
		kit.pop()
		return kit.commit())


## Petrol station canopy (12 × 8 m) with two pump islands.
static func petrol_canopy() -> Mesh:
	return cached("petrol_canopy", func() -> Mesh:
		var kit := MeshKit.new()
		for x: float in [-4.5, 4.5]:
			for z: float in [-2.5, 2.5]:
				kit.box(Vector3(x, 2.4, z), Vector3(0.3, 4.8, 0.3), WHITE)
		kit.box(Vector3(0, 5.0, 0), Vector3(14.0, 0.5, 9.0), WHITE)
		kit.box(Vector3(0, 5.0, 0), Vector3(14.1, 0.3, 9.1), Color("c0392b"))
		kit.use("glow")
		kit.box(Vector3(0, 4.72, 0), Vector3(12.0, 0.04, 7.0), Color("fff8e0"))
		kit.use("solid")
		return kit.commit())


static func petrol_pump() -> Mesh:
	return cached("petrol_pump", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.1, 0), Vector3(1.2, 0.2, 2.4), Color("a8a196"))
		kit.box(Vector3(0, 0.95, 0), Vector3(0.6, 1.5, 0.9), WHITE)
		kit.box(Vector3(0, 1.6, 0), Vector3(0.62, 0.3, 0.92), Color("c0392b"))
		kit.use("glow")
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(s * 0.31, 1.15, 0), Vector3(0.02, 0.3, 0.5), Color("9fe0a0"))
		kit.use("solid")
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(s * 0.33, 0.8, 0.3), Vector3(0.06, 0.25, 0.1), Color("2a2a2a"))
		return kit.commit())


## Price pylon of the petrol station (5 m).
static func pylon() -> Mesh:
	return cached("pylon", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 2.5, 0), Vector3(1.6, 5.0, 0.4), Color("c0392b"))
		kit.use("glow")
		for i in 3:
			kit.box(Vector3(0, 3.8 - i * 0.8, 0.21), Vector3(1.2, 0.5, 0.02), Color("f4f4f4"))
		return kit.commit())


## Car wash brushes (blue rollers) inside the tunnel.
static func wash_brushes() -> Mesh:
	return cached("wash_brushes", func() -> Mesh:
		var kit := MeshKit.new()
		for s: float in [-1.0, 1.0]:
			kit.cylinder(Vector3(s * 2.3, 0.1, 0), 3.4, 0.55, 0.55, 10, Color("2e86de"))
		kit.push(Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0, 3.0, 2.0)))
		kit.cylinder(Vector3(0, -2.6, 0), 5.2, 0.45, 0.45, 10, Color("e84393"))
		kit.pop()
		kit.box(Vector3(0, 3.9, 0), Vector3(5.6, 0.3, 0.3), Color("8a8f96"))
		return kit.commit())


## Scrapyard crane: tower, jib and cab (13 m); the magnet hangs from a separate node.
static func crane() -> Mesh:
	return cached("crane", func() -> Mesh:
		var kit := MeshKit.new()
		var y := SIGN_YELLOW
		kit.box(Vector3(0, 0.4, 0), Vector3(3.0, 0.8, 3.0), Color("5a5a5e"))
		for s: Vector2 in [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(0.6, 0.6), Vector2(-0.6, 0.6)]:
			kit.beam(Vector3(s.x, 0.8, s.y), Vector3(s.x, 12.0, s.y), Vector2(0.16, 0.16), y)
		for i in 6:
			kit.beam(Vector3(-0.6, 1.0 + i * 1.8, -0.6), Vector3(0.6, 2.8 + i * 1.8, -0.6), Vector2(0.08, 0.08), y)
			kit.beam(Vector3(0.6, 1.0 + i * 1.8, 0.6), Vector3(-0.6, 2.8 + i * 1.8, 0.6), Vector2(0.08, 0.08), y)
		kit.box(Vector3(0, 12.4, 0), Vector3(1.8, 0.8, 1.8), y)
		kit.box(Vector3(0, 12.9, 4.5), Vector3(0.7, 0.6, 13.0), y)
		kit.box(Vector3(0, 12.9, -3.2), Vector3(1.2, 1.0, 2.0), Color("5a5a5e"))
		kit.box(Vector3(1.2, 11.2, 0.0), Vector3(1.4, 1.6, 1.6), Color("e8e2d0"))
		kit.box(Vector3(1.91, 11.4, 0.0), Vector3(0.02, 0.8, 1.2), GLASS)
		return kit.commit())


static func magnet() -> Mesh:
	return cached("magnet", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3(0, -0.4, 0), 0.4, 0.8, 0.8, 12, Color("3a3a3e"))
		kit.box(Vector3(0, 0.15, 0), Vector3(0.4, 0.3, 0.4), Color("3a3a3e"))
		return kit.commit())


## Tyre wall element along the kart track (2 m).
static func tyre_wall() -> Mesh:
	return cached("tyre_wall", func() -> Mesh:
		var kit := MeshKit.new()
		for i in 4:
			for k in 2:
				kit.torus(Vector3(-0.75 + i * 0.5, 0.12 + k * 0.22, 0), 0.24, 0.1, 8, 4, TYRE if (i + k) % 2 == 0 else Color("c0392b"))
		return kit.commit())


## Start gantry over the kart track (width along x).
static func start_gantry(width: float) -> Mesh:
	return cached("start_gantry_%d" % int(width), func() -> Mesh:
		var kit := MeshKit.new()
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(s * width * 0.5, 1.8, 0), Vector3(0.25, 3.6, 0.25), Color("e8e2d0"))
		kit.box(Vector3(0, 3.7, 0), Vector3(width + 0.3, 0.6, 0.3), Color("2a2a2e"))
		for i in 8:
			kit.box(Vector3(-width * 0.5 + 0.5 + i * (width - 1.0) / 7.0, 3.7, 0.16), Vector3(0.4, 0.4, 0.02), WHITE if i % 2 == 0 else Color("1a1a1a"))
		return kit.commit())


## Ticket booth (cinema, kart track).
static func booth(col: Color) -> Mesh:
	return cached("booth_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 1.3, 0), Vector3(2.6, 2.6, 2.6), col)
		kit.box(Vector3(0, 2.75, 0), Vector3(3.0, 0.3, 3.0), col.darkened(0.3))
		kit.box(Vector3(0, 1.5, 1.31), Vector3(1.6, 0.9, 0.02), GLASS)
		kit.box(Vector3(0, 1.05, 1.45), Vector3(1.8, 0.06, 0.3), WHITE)
		return kit.commit())


## Garage door (6 × 4 m) in front of a hall wall.
static func garage_door() -> Mesh:
	return cached("garage_door", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 2.0, 0), Vector3(5.6, 4.0, 0.08), Color("8a8f96"))
		for i in 6:
			kit.box(Vector3(0, 0.4 + i * 0.66, 0.05), Vector3(5.6, 0.04, 0.02), Color("6a6e74"))
		return kit.commit())


## Market fountain.
static func market_fountain() -> Mesh:
	return cached("market_fountain", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.6, 3.2, 3.2, 16, Color("a8a196"))
		kit.use("water")
		kit.cylinder(Vector3(0, 0.45, 0), 0.05, 2.9, 2.9, 16, Color("3d8aa0"))
		kit.use("solid")
		kit.cylinder(Vector3(0, 0.5, 0), 1.6, 0.35, 0.3, 8, Color("a8a196"))
		kit.cylinder(Vector3(0, 2.1, 0), 0.25, 1.0, 0.6, 10, Color("a8a196"))
		kit.sphere(Vector3(0, 2.6, 0), Vector3(0.35, 0.35, 0.35), Color("c4bdb1"), 3, 8)
		return kit.commit())


## A movie: one frame of the shader screen is set by the cinema; this is the screen quad.
static func screen_quad() -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(19.6, 8.8)
	return q

class_name CarModels
extends RefCounted
## The cars of the Oststadt (doc/oststadt.md). Bodies are lofted from cross-sections along
## the car (stations): every ring has the same points from the underside over the sill, the
## side, the shoulder and the side glass to the roof, so windows, pillars and roof fall on the
## bands between them. One "car" surface (car.gdshader) holds paint, lamps, glass, chrome and
## rubber, told apart by the vertex alpha: one draw call per car. Front faces +Z, origin on the
## ground.

const PAINT := 1.0
const LAMP := 0.83
const GLASS := 0.66
const CHROME := 0.33
const MATTE := 0.0

const GLASS_COL := Color("1f2c38")
const TYRE := Color("1c1c1e")
const TRIM := Color("2c2d30")
const UNDER := Color("161618")
const RIM := Color("c9cdd2")
const PLATE := Color("f2f2ec")
const EU_BLUE := Color("2a4fa8")
const HEAD := Color("fff4cc")
const TAIL := Color("ff3424")
const BLINK := Color("ffa020")
const WHITE := Color("f1eee6")
const YELLOW := Color("f2c230")

## Looks of the bands of a ring (underside, sill, side, shoulder, side glass, roof edge, top)
## per interval tag: u underside, t trim, p paint, g glass.
const BANDS := {
	"body": "utppppp",     # bonnet, boot, cargo box
	"glass": "utppgpp",    # side windows under the roof
	"pillar": "utppppp",   # a door pillar
	"screen": "utppgpg",   # windscreen (the side glass reaches into it)
	"rear": "utppppg",     # rear window over the C pillar
}


## While true, parts skip their small details: the far version of a car (Car shows it beyond
## Car.NEAR metres), a quarter of the triangles.
static var simple := false


static func car(kind: String, col: Color, far := false) -> Mesh:
	return CityModels.cached("car_%s_%s%s" % [kind, col.to_html(), "_far" if far else ""], func() -> Mesh:
		simple = far
		var sp := CarSpecs.spec(kind)
		var kit := MeshKit.new()
		kit.use("car", PAINT)
		match kind:
			"small", "learner":
				_hatch(kit, sp, col)
				if kind == "learner":
					_roof_sign(kit, Vector3(0, 1.52, -0.2), "FAHRSCHULE")
			"kombi", "taxi":
				_estate(kit, sp, col)
				if kind == "taxi":
					_taxi_sign(kit, Vector3(0, 1.52, -0.25))
				else:
					_roof_rails(kit, sp)
			"van", "delivery", "icecream":
				_van(kit, sp, col, kind)
			"tow":
				_tow(kit, sp, col)
			"garbage":
				_garbage(kit, sp, col)
			"oldtimer":
				_oldtimer(kit, sp, col)
			"kart":
				_kart(kit, sp, col)
		simple = false
		return kit.commit())


# --- Loft -----------------------------------------------------------------------------

## A station: z, bottom y0, half width w at the belt, belt height, top height, half width tw
## at the top and gt, the top of the side glass (a little under the top by default).
static func st(z: float, y0: float, w: float, belt: float, top: float, tw: float, gt := -1.0) -> Dictionary:
	return {"z": z, "y0": y0, "w": w, "belt": belt, "top": top, "tw": tw, "gt": top - 0.06 if gt < 0.0 else gt}


## Right half of a station's ring, from the underside centre up to the roof centre.
static func _ring(s: Dictionary) -> PackedVector2Array:
	var w: float = s["w"]
	var tw: float = s["tw"]
	var y0: float = s["y0"]
	var belt: float = s["belt"]
	var top: float = s["top"]
	var gt: float = maxf(s["gt"], belt + 0.04)
	return PackedVector2Array([Vector2(0, y0), Vector2(w - 0.08, y0), Vector2(w, y0 + 0.12), Vector2(w, belt),
		Vector2(lerpf(w, tw, 0.3), belt + 0.04), Vector2(tw, gt), Vector2(maxf(tw - 0.12, tw * 0.85), top), Vector2(0, top + 0.015)])


## The body between the stations; tags[i] names the interval from station i to i + 1.
## Both ends are closed with flat caps in the paint.
static func loft(kit: MeshKit, stations: Array, tags: Array, col: Color) -> void:
	for i in stations.size() - 1:
		var a: Dictionary = stations[i]
		var b: Dictionary = stations[i + 1]
		var ra := _ring(a)
		var rb := _ring(b)
		var looks: String = BANDS[tags[i]]
		var mid_y := (float(a["y0"]) + float(a["top"]) + float(b["y0"]) + float(b["top"])) * 0.25
		for j in 7:
			for side: float in [1.0, -1.0]:
				var q := [Vector3(ra[j].x * side, ra[j].y, a["z"]), Vector3(ra[j + 1].x * side, ra[j + 1].y, a["z"]),
					Vector3(rb[j + 1].x * side, rb[j + 1].y, b["z"]), Vector3(rb[j].x * side, rb[j].y, b["z"])]
				var c: Vector3 = (q[0] + q[1] + q[2] + q[3]) * 0.25
				_face(kit, q, looks[j], col, c - Vector3(0, mid_y, c.z))
	for k: int in [0, stations.size() - 1]:
		var s: Dictionary = stations[k]
		var r := _ring(s)
		var z: float = s["z"]
		var out := Vector3(0, 0, -1.0 if k == 0 else 1.0)
		var centre := Vector3(0, (float(s["y0"]) + float(s["top"])) * 0.5, z)
		for j in 7:
			for side: float in [1.0, -1.0]:
				_face(kit, [centre, Vector3(r[j].x * side, r[j].y, z), Vector3(r[j + 1].x * side, r[j + 1].y, z)], "p", col, out)


## A quad or triangle in a look, turned so that it faces `out`.
static func _face(kit: MeshKit, q: Array, look: String, col: Color, out: Vector3) -> void:
	var n: Vector3
	if q.size() == 4:
		n = (q[2] - q[0]).cross(q[3] - q[1])
	else:
		n = (q[1] - q[0]).cross(q[2] - q[0])
	if n.dot(out) < 0.0:
		q.reverse()
	match look:
		"u":
			kit.use("car", MATTE)
			col = UNDER
		"t":
			kit.use("car", MATTE)
			col = TRIM
		"g":
			kit.use("car", GLASS)
			col = GLASS_COL
		_:
			kit.use("car", PAINT)
	if q.size() == 4:
		kit.quad(q[0], q[1], q[2], q[3], col)
	else:
		kit.tri(q[0], q[1], q[2], col)
	kit.use("car", PAINT)


# --- Parts ----------------------------------------------------------------------------

## A wheel at (x, r, z) on the side `side` (+1 right): tyre, rim with five spokes and a hub,
## and the dark wheel arch on the body side at x_body. Kept cheap: a car has four of them.
static func wheel(kit: MeshKit, x: float, z: float, r: float, side: float, x_body := NAN, width := 0.24, whitewall := false) -> void:
	kit.push(Transform3D(Basis(Vector3.BACK, -side * PI / 2), Vector3(x, r, z)))
	kit.use("car", MATTE)
	kit.cylinder(Vector3(0, -width * 0.5, 0), width, r, r, 6 if simple else 10, TYRE)
	var face := width * 0.5 + 0.004
	if simple:
		kit.use("car", CHROME)
		kit.disc(Vector3(0, face, 0), r * 0.62, 6, RIM)
		kit.pop()
		kit.use("car", PAINT)
		if not is_nan(x_body):
			arch(kit, x_body * side, z, r, side)
		return
	if whitewall:
		kit.disc(Vector3(0, face, 0), r * 0.84, 10, WHITE)
		face += 0.003
	kit.use("car", CHROME)
	kit.disc(Vector3(0, face, 0), r * 0.64, 10, RIM)
	kit.use("car", MATTE)
	for i in 5:
		var a0 := TAU * (i + 0.18) / 5.0
		var a1 := TAU * (i + 0.82) / 5.0
		var p0 := Vector3(cos(a0) * r * 0.22, face + 0.002, sin(a0) * r * 0.22)
		var p1 := Vector3(cos(a0) * r * 0.52, face + 0.002, sin(a0) * r * 0.52)
		var p2 := Vector3(cos(a1) * r * 0.52, face + 0.002, sin(a1) * r * 0.52)
		var p3 := Vector3(cos(a1) * r * 0.22, face + 0.002, sin(a1) * r * 0.22)
		_face(kit, [p0, p1, p2, p3], "u", Color.BLACK, Vector3.UP)
	kit.use("car", CHROME)
	kit.disc(Vector3(0, face + 0.004, 0), r * 0.15, 6, Color("8a8e94"))
	kit.pop()
	kit.use("car", PAINT)
	if not is_nan(x_body):
		arch(kit, x_body * side, z, r, side)


## The dark wheel well as a half disc on the body side (x), over a wheel of radius r at z.
static func arch(kit: MeshKit, x: float, z: float, r: float, side: float) -> void:
	var c := Vector3(x + side * 0.004, r, z)
	var rr := r + 0.07
	var n := 8
	for i in n:
		var a0 := PI * i / n
		var a1 := PI * (i + 1) / n
		_face(kit, [c, c + Vector3(0, sin(a0), cos(a0)) * rr, c + Vector3(0, sin(a1), cos(a1)) * rr], "u", Color.BLACK, Vector3(side, 0, 0))


## Head- and tail-lights, bumpers, grille and number plates at the front (zf) and back (zb).
## w: half width there, y: height of the lights, y0: bottom of the body.
static func ends(kit: MeshKit, zf: float, zb: float, wf: float, wb: float, yf: float, yb: float, y0: float, grille := true) -> void:
	kit.use("car", MATTE)
	kit.box(Vector3(0, y0 + 0.08, zf + 0.02), Vector3(wf * 2.0 + 0.06, 0.18, 0.12), TRIM)
	kit.box(Vector3(0, y0 + 0.08, zb - 0.02), Vector3(wb * 2.0 + 0.06, 0.18, 0.12), TRIM)
	if grille and not simple:
		kit.box(Vector3(0, yf - 0.02, zf + 0.008), Vector3(wf * 0.8, 0.14, 0.03), Color("1e1f22"))
		kit.use("car", CHROME)
		kit.box(Vector3(0, yf + 0.06, zf + 0.012), Vector3(wf * 0.82, 0.025, 0.03), RIM)
		kit.use("car", MATTE)
	# Number plates: white with the blue band on the left.
	for e: Array in ([] if simple else [[zf + 0.085, 1.0], [zb - 0.085, -1.0]]):
		var z: float = e[0]
		kit.box(Vector3(0, y0 + 0.2, z), Vector3(0.52, 0.12, 0.012), PLATE)
		kit.box(Vector3(e[1] * 0.235, y0 + 0.2, z + e[1] * 0.004), Vector3(0.05, 0.12, 0.012), EU_BLUE)
		kit.box(Vector3(0.03 * e[1], y0 + 0.2, z + e[1] * 0.004), Vector3(0.34, 0.03, 0.012), Color("303030"))
	kit.use("car", LAMP)
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(s * (wf - 0.2), yf, zf), Vector3(0.34, 0.12, 0.05), HEAD)
		kit.box(Vector3(s * (wb - 0.17), yb, zb), Vector3(0.3, 0.14, 0.05), TAIL)
		if not simple:
			kit.box(Vector3(s * (wf - 0.06), yf - 0.01, zf - 0.02), Vector3(0.08, 0.08, 0.05), BLINK)
			kit.box(Vector3(s * (wb - 0.17), yb - 0.1, zb), Vector3(0.3, 0.05, 0.05), BLINK)
	kit.use("car", PAINT)


## Door gaps (dark lines) and handles on both sides at x = w, from y0 to belt.
static func doors(kit: MeshKit, w: float, gaps: Array, y0: float, belt: float, handles: Array) -> void:
	if simple:
		return
	kit.use("car", MATTE)
	for z: float in gaps:
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(s * (w + 0.002), (y0 + belt) * 0.5 + 0.04, z), Vector3(0.006, belt - y0 - 0.12, 0.018), Color("1a1a1c"))
	kit.use("car", CHROME)
	for z: float in handles:
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(s * (w + 0.01), belt - 0.1, z), Vector3(0.025, 0.035, 0.16), RIM)
	kit.use("car", PAINT)


## Wing mirrors at the windscreen base.
static func mirrors(kit: MeshKit, w: float, y: float, z: float, col: Color) -> void:
	if simple:
		return
	for s: float in [-1.0, 1.0]:
		kit.use("car", PAINT)
		kit.beam(Vector3(s * (w - 0.05), y - 0.04, z), Vector3(s * (w + 0.1), y, z - 0.04), Vector2(0.04, 0.04), col)
		kit.box(Vector3(s * (w + 0.13), y + 0.02, z - 0.06), Vector3(0.12, 0.11, 0.16), col)
		kit.use("car", GLASS)
		kit.box(Vector3(s * (w + 0.13), y + 0.02, z - 0.145), Vector3(0.1, 0.09, 0.01), Color("8a9aa8"))
	kit.use("car", PAINT)


static func _roof_rails(kit: MeshKit, sp: Dictionary) -> void:
	if simple:
		return
	var hl: float = sp["length"] * 0.5
	kit.use("car", CHROME)
	for s: float in [-1.0, 1.0]:
		kit.beam(Vector3(s * 0.62, 1.53, -hl + 0.45), Vector3(s * 0.62, 1.53, 0.55), Vector2(0.04, 0.04), Color("9aa0a6"))
		for z: float in [-hl + 0.5, 0.5]:
			kit.box(Vector3(s * 0.62, 1.515, z), Vector3(0.05, 0.04, 0.08), Color("4a4e54"))
	kit.use("car", PAINT)


static func _taxi_sign(kit: MeshKit, p: Vector3) -> void:
	kit.use("car", MATTE)
	kit.box(p + Vector3(0, 0.02, 0), Vector3(0.62, 0.04, 0.26), TRIM)
	kit.use("car", LAMP)
	kit.box(p + Vector3(0, 0.13, 0), Vector3(0.56, 0.18, 0.2), Color("ffe680"))
	kit.use("car", MATTE)
	for s: float in [-1.0, 1.0]:
		kit.box(p + Vector3(0, 0.13, s * 0.101), Vector3(0.4, 0.07, 0.005), Color("2a2a2a"))
	kit.use("car", PAINT)


static func _roof_sign(kit: MeshKit, p: Vector3, _text: String) -> void:
	kit.use("car", PAINT)
	kit.box(p + Vector3(0, 0.16, 0), Vector3(0.9, 0.3, 0.2), WHITE)
	kit.box(p + Vector3(0, 0.16, 0), Vector3(0.94, 0.11, 0.21), Color("2e86de"))
	kit.use("car", MATTE)
	kit.box(p + Vector3(0, 0.0, 0), Vector3(0.7, 0.04, 0.16), TRIM)
	kit.use("car", PAINT)


# --- Kinds ----------------------------------------------------------------------------

## Small car and the learner: a hatchback with a steep tailgate and two doors.
static func _hatch(kit: MeshKit, sp: Dictionary, col: Color) -> void:
	var hl: float = sp["length"] * 0.5
	var w: float = sp["width"] * 0.5 - 0.015
	var wb: float = sp["wheelbase"]
	loft(kit, [
		st(-hl, 0.36, w - 0.06, 0.84, 0.94, w - 0.16),
		st(-hl + 0.09, 0.28, w, 0.9, 1.02, w - 0.1),
		st(-hl + 0.33, 0.28, w + 0.01, 0.93, 1.46, w - 0.17),
		st(-0.55, 0.28, w + 0.01, 0.94, 1.5, w - 0.17),
		st(-0.45, 0.28, w + 0.01, 0.94, 1.5, w - 0.17),
		st(0.5, 0.28, w + 0.01, 0.94, 1.49, w - 0.17),
		st(1.0, 0.28, w + 0.01, 0.9, 1.0, w - 0.07),
		st(hl - 0.15, 0.28, w, 0.84, 0.92, w - 0.08),
		st(hl, 0.36, w - 0.06, 0.74, 0.8, w - 0.16),
	], ["body", "rear", "glass", "pillar", "glass", "screen", "body", "body"], col)
	_wheels4(kit, wb, w, 0.31, 0.0)
	ends(kit, hl, -hl, w - 0.06, w - 0.06, 0.66, 0.78, 0.28)
	doors(kit, w + 0.01, [-0.5, 0.86], 0.28, 0.94, [-0.38])
	mirrors(kit, w, 0.98, 0.95, col)


## Kombi and taxi: a long roof, an upright tailgate and four doors.
static func _estate(kit: MeshKit, sp: Dictionary, col: Color) -> void:
	var hl: float = sp["length"] * 0.5
	var w: float = sp["width"] * 0.5 - 0.015
	var wb: float = sp["wheelbase"]
	loft(kit, [
		st(-hl, 0.36, w - 0.06, 0.86, 0.96, w - 0.16),
		st(-hl + 0.08, 0.28, w, 0.92, 1.06, w - 0.1),
		st(-hl + 0.22, 0.28, w + 0.01, 0.95, 1.46, w - 0.17),
		st(-1.2, 0.28, w + 0.01, 0.96, 1.5, w - 0.17),
		st(-1.1, 0.28, w + 0.01, 0.96, 1.5, w - 0.17),
		st(-0.25, 0.28, w + 0.01, 0.96, 1.5, w - 0.17),
		st(-0.15, 0.28, w + 0.01, 0.96, 1.5, w - 0.17),
		st(0.7, 0.28, w + 0.01, 0.96, 1.48, w - 0.17),
		st(1.25, 0.28, w + 0.01, 0.92, 1.02, w - 0.07),
		st(hl - 0.15, 0.28, w, 0.84, 0.92, w - 0.1),
		st(hl, 0.36, w - 0.06, 0.74, 0.8, w - 0.18),
	], ["body", "rear", "glass", "pillar", "glass", "pillar", "glass", "screen", "body", "body"], col)
	_wheels4(kit, wb, w, 0.32, 0.0)
	ends(kit, hl, -hl, w - 0.06, w - 0.06, 0.66, 0.82, 0.28)
	doors(kit, w + 0.01, [-1.15, -0.2, 1.1], 0.28, 0.96, [-1.0, -0.05])
	mirrors(kit, w, 1.0, 1.2, col)


## Van, burger van and ice cream van: a box with a short bonnet; windows only in the cab.
static func _van(kit: MeshKit, sp: Dictionary, col: Color, kind: String) -> void:
	var hl: float = sp["length"] * 0.5
	var w: float = sp["width"] * 0.5 - 0.015
	var wb: float = sp["wheelbase"]
	var h: float = sp["height"]
	var cab := hl - 1.95            # B pillar behind the cab doors
	loft(kit, [
		st(-hl, 0.4, w - 0.04, 1.2, h - 0.08, w - 0.07, h - 0.4),
		st(-hl + 0.08, 0.32, w, 1.2, h, w - 0.03, h - 0.3),
		st(cab - 0.1, 0.32, w, 1.2, h, w - 0.03, h - 0.3),
		st(cab, 0.32, w, 1.2, h, w - 0.03, h - 0.3),
		st(hl - 1.3, 0.32, w, 1.15, h - 0.02, w - 0.04, h - 0.32),
		st(hl - 0.65, 0.32, w - 0.01, 1.08, 1.3, w - 0.07, 1.24),
		st(hl - 0.15, 0.32, w - 0.02, 0.98, 1.1, w - 0.09),
		st(hl, 0.4, w - 0.08, 0.9, 1.0, w - 0.14),
	], ["body", "body", "pillar", "glass", "screen", "body", "body"], col)
	_wheels4(kit, wb, w, 0.34, 0.0)
	ends(kit, hl, -hl, w - 0.08, w - 0.04, 0.82, 0.95, 0.32)
	doors(kit, w, [cab + 0.02, hl - 0.68], 0.32, 1.2, [cab + 0.15])
	mirrors(kit, w, 1.3, hl - 0.75, col)
	# Rear doors with their windows.
	kit.use("car", MATTE)
	kit.box(Vector3(0, (h + 0.4) * 0.5, -hl - 0.003), Vector3(0.012, h - 0.6, 0.01), Color("1a1a1c"))
	kit.use("car", GLASS)
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(s * w * 0.48, h - 0.55, -hl - 0.004), Vector3(w * 0.7, 0.45, 0.01), GLASS_COL)
	kit.use("car", PAINT)
	match kind:
		"delivery":
			for s: float in [-1.0, 1.0]:
				kit.box(Vector3(s * (w + 0.006), 1.35, -0.6), Vector3(0.01, 0.7, 2.2), YELLOW)
				kit.box(Vector3(s * (w + 0.012), 1.35, -0.6), Vector3(0.01, 0.5, 0.5), Color("6b3e26"))
				kit.box(Vector3(s * (w + 0.014), 1.42, -0.6), Vector3(0.01, 0.12, 0.56), Color("4fa040"))
				kit.box(Vector3(s * (w + 0.016), 1.52, -0.6), Vector3(0.01, 0.1, 0.52), Color("e0a050"))
			kit.cylinder(Vector3(0, h, -0.6), 0.12, 0.35, 0.35, 12, Color("d9a35c"))
			kit.cylinder(Vector3(0, h + 0.12, -0.6), 0.08, 0.37, 0.37, 12, Color("6b3e26"))
			kit.cylinder(Vector3(0, h + 0.2, -0.6), 0.03, 0.39, 0.39, 12, Color("4fa040"))
			kit.sphere(Vector3(0, h + 0.24, -0.6), Vector3(0.36, 0.16, 0.36), Color("e0a050"), 3, 12)
		"icecream":
			# Serving hatch on the kerb side (-x), its awning, pink stripes, the cone on the roof.
			kit.use("car", MATTE)
			kit.box(Vector3(-w - 0.006, 1.5, -0.7), Vector3(0.012, 0.8, 1.9), Color("3a2a20"))
			kit.use("car", PAINT)
			kit.box(Vector3(-w - 0.25, 1.06, -0.7), Vector3(0.5, 0.06, 1.9), WHITE)
			for i in 6:
				kit.box(Vector3(-w - 0.28, 2.0, -1.55 + i * 0.34), Vector3(0.56, 0.04, 0.17), Color("f28db2") if i % 2 == 0 else WHITE)
			for s: float in [-1.0, 1.0]:
				kit.box(Vector3(s * (w + 0.006), 0.8, -0.3), Vector3(0.01, 0.18, sp["length"] - 1.0), Color("f28db2"))
				kit.box(Vector3(s * (w + 0.006), 0.62, -0.3), Vector3(0.01, 0.06, sp["length"] - 1.0), Color("9be0c0"))
			kit.cylinder(Vector3(0, h, -0.6), 0.9, 0.05, 0.38, 10, Color("e0b070"))
			kit.sphere(Vector3(0, h + 1.05, -0.6), Vector3(0.45, 0.4, 0.45), Color("f7c6d9"), 4, 10)
			kit.sphere(Vector3(0.05, h + 1.4, -0.58), Vector3(0.3, 0.26, 0.3), Color("9be0c0"), 4, 10)
			kit.sphere(Vector3(0.08, h + 1.66, -0.56), Vector3(0.05, 0.05, 0.05), Color("d0352b"), 2, 6)


## A truck cab from z0 to the front (hl): short bonnet, big windscreen.
static func _cab(kit: MeshKit, z0: float, hl: float, w: float, h: float, y0: float, col: Color) -> void:
	loft(kit, [
		st(z0, y0, w, 1.4, h, w - 0.05, h - 0.3),
		st(z0 + 0.12, y0, w, 1.4, h, w - 0.05, h - 0.3),
		st(hl - 1.0, y0, w, 1.38, h, w - 0.05, h - 0.3),
		st(hl - 0.45, y0, w, 1.3, 1.55, w - 0.08, 1.5),
		st(hl - 0.1, y0, w - 0.01, 1.22, 1.36, w - 0.1),
		st(hl, y0 + 0.08, w - 0.06, 1.16, 1.26, w - 0.14),
	], ["pillar", "glass", "screen", "body", "body"], col)
	mirrors(kit, w, 1.55, hl - 0.55, col)
	doors(kit, w, [z0 + 0.14, hl - 0.5], y0, 1.4, [z0 + 0.3])


static func _tow(kit: MeshKit, sp: Dictionary, col: Color) -> void:
	var hl: float = sp["length"] * 0.5
	var L: float = sp["length"]
	var w: float = sp["width"] * 0.5 - 0.015
	_cab(kit, hl - 2.2, hl, w, 2.5, 0.45, col)
	kit.use("car", MATTE)
	kit.box(Vector3(0, 0.75, -0.9), Vector3(w * 2.0, 0.4, L - 2.0), Color("3a3a3e"))
	kit.use("car", CHROME)
	kit.box(Vector3(0, 1.0, -0.9), Vector3(w * 2.0, 0.1, L - 2.2), Color("8a8f96"))
	for i in 9:
		kit.box(Vector3(0, 1.06, -L * 0.5 + 0.5 + i * 0.5), Vector3(w * 2.0 - 0.1, 0.02, 0.05), Color("6a6e74"))
	kit.use("car", PAINT)
	kit.beam(Vector3(0, 1.0, -L * 0.5 + 0.4), Vector3(0, 2.4, -L * 0.5 + 1.6), Vector2(0.22, 0.22), YELLOW)
	kit.beam(Vector3(0, 2.4, -L * 0.5 + 1.6), Vector3(0, 2.0, -L * 0.5 - 0.2), Vector2(0.18, 0.18), YELLOW)
	kit.use("car", MATTE)
	kit.beam(Vector3(0, 2.0, -L * 0.5 - 0.2), Vector3(0, 0.7, -L * 0.5 - 0.3), Vector2(0.03, 0.03), Color("2a2a2a"))
	kit.box(Vector3(0, 0.6, -L * 0.5 - 0.3), Vector3(0.6, 0.12, 0.12), Color("2a2a2a"))
	# Black and yellow warning stripes on the bed's end.
	for i in 6:
		kit.use("car", PAINT)
		kit.box(Vector3(-w + 0.18 + i * (w * 2.0 - 0.36) / 5.0, 0.75, -L * 0.5 + 0.09), Vector3(0.18, 0.36, 0.02), YELLOW if i % 2 == 0 else Color("1a1a1a"))
	kit.use("car", LAMP)
	kit.box(Vector3(0, 2.6, hl - 1.5), Vector3(1.0, 0.16, 0.25), Color("ffa020"))
	kit.use("car", PAINT)
	var r := 0.42
	for z: float in [sp["wheelbase"] * 0.5 - 0.5, -sp["wheelbase"] * 0.5 - 0.5]:
		for s: float in [-1.0, 1.0]:
			wheel(kit, s * (w - 0.1), z, r, s, w if z > 0.0 else NAN, 0.3)
	ends(kit, hl, -hl, w - 0.06, w - 0.1, 0.95, 0.6, 0.45, true)


static func _garbage(kit: MeshKit, sp: Dictionary, col: Color) -> void:
	var hl: float = sp["length"] * 0.5
	var w: float = sp["width"] * 0.5 - 0.015
	_cab(kit, hl - 2.0, hl, w, 2.7, 0.5, col)
	loft(kit, [
		st(-hl, 0.6, w - 0.05, 2.2, 2.4, w - 0.12),
		st(-hl + 0.6, 0.6, w - 0.04, 2.9, 3.0, w - 0.1),
		st(hl - 2.1, 0.6, w - 0.04, 2.9, 3.0, w - 0.1),
	], ["body", "body"], col.darkened(0.08))
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(s * (w - 0.03), 1.4, -1.0), Vector3(0.02, 0.25, sp["length"] - 3.5), WHITE)
		for i in 4:
			kit.use("car", MATTE)
			kit.box(Vector3(s * (w - 0.03), 1.75 + i * 0.25, -1.0), Vector3(0.025, 0.03, sp["length"] - 3.6), col.darkened(0.3))
			kit.use("car", PAINT)
	kit.use("car", MATTE)
	kit.box(Vector3(0, 1.3, -hl - 0.25), Vector3(w * 2.0 - 0.3, 1.3, 0.5), Color("3a3a3e"))
	kit.box(Vector3(0, 0.95, -hl - 0.55), Vector3(w * 2.0 - 0.6, 0.06, 0.4), Color("5a5e64"))
	kit.use("car", LAMP)
	kit.box(Vector3(0, 2.85, hl - 1.2), Vector3(0.9, 0.14, 0.22), Color("ffa020"))
	kit.use("car", PAINT)
	var r := 0.48
	var zs := [sp["wheelbase"] * 0.5 - 0.6, -sp["wheelbase"] * 0.5 - 0.6, -sp["wheelbase"] * 0.5 - 0.6 - r * 2.3]
	for z: float in zs:
		for s: float in [-1.0, 1.0]:
			wheel(kit, s * (w - 0.12), z, r, s, w - 0.04 if z < 0.0 else w, 0.32)
	ends(kit, hl, -hl - 0.5, w - 0.06, w - 0.2, 1.0, 0.75, 0.5, true)


## Opa Egon's roadster: long bonnet with a chrome grille, round wings, whitewall tyres, an
## open cockpit with leather seats and a small windscreen.
static func _oldtimer(kit: MeshKit, sp: Dictionary, col: Color) -> void:
	var hl: float = sp["length"] * 0.5
	var W: float = sp["width"]
	var wb: float = sp["wheelbase"]
	var w := W * 0.5 - 0.2
	loft(kit, [
		st(-hl, 0.5, w - 0.12, 0.85, 0.9, w - 0.2),
		st(-hl + 0.3, 0.42, w, 0.98, 1.02, w - 0.08),
		st(-0.5, 0.42, w, 0.96, 1.0, w - 0.08),
		st(0.0, 0.42, w - 0.02, 0.9, 0.95, w - 0.1),
		st(hl - 0.3, 0.42, w - 0.08, 0.84, 0.9, w - 0.16),
		st(hl, 0.48, w - 0.16, 0.74, 0.8, w - 0.24),
	], ["body", "body", "body", "body", "body"], col)
	# Cockpit: dark well with leather seats and the steering wheel.
	kit.use("car", MATTE)
	kit.box(Vector3(0, 1.0, -0.85), Vector3(w * 2.0 - 0.2, 0.06, 1.1), Color("2a2220"))
	kit.box(Vector3(0, 1.0, -1.05), Vector3(w * 2.0 - 0.3, 0.16, 0.5), Color("6b3e26"))
	kit.box(Vector3(0, 1.25, -1.32), Vector3(w * 2.0 - 0.3, 0.45, 0.14), Color("6b3e26"))
	kit.push(Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(-0.32, 1.2, -0.25)))
	kit.torus(Vector3.ZERO, 0.17, 0.02, 12, 4, Color("2a2a2a"))
	kit.pop()
	# Windscreen in a chrome frame.
	kit.use("car", GLASS)
	kit.box(Vector3(0, 1.22, -0.05), Vector3(w * 2.0 - 0.1, 0.36, 0.03), Color("6f8090"))
	kit.use("car", CHROME)
	kit.box(Vector3(0, 1.41, -0.05), Vector3(w * 2.0 - 0.06, 0.03, 0.05), RIM)
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(s * (w - 0.03), 1.22, -0.05), Vector3(0.03, 0.4, 0.05), RIM)
	# Grille, round lamps, bumpers.
	kit.box(Vector3(0, 0.68, hl + 0.01), Vector3(0.5, 0.36, 0.04), RIM)
	kit.use("car", MATTE)
	for i in 7:
		kit.box(Vector3(-0.18 + i * 0.06, 0.68, hl + 0.035), Vector3(0.02, 0.3, 0.01), Color("2a2a2a"))
	kit.use("car", CHROME)
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(0, 0.45, s * (hl + 0.12)), Vector3(W - 0.1, 0.08, 0.06), RIM)
		kit.cylinder(Vector3(s * 0.5, 0.86, hl - 0.18), 0.04, 0.03, 0.03, 6, RIM)
	for s: float in [-1.0, 1.0]:
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(s * 0.5, 0.95, hl - 0.12)))
		kit.cylinder(Vector3.ZERO, 0.1, 0.13, 0.12, 10, RIM)
		kit.pop()
	kit.use("car", LAMP)
	for s: float in [-1.0, 1.0]:
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(s * 0.5, 0.95, hl - 0.015)))
		kit.cylinder(Vector3.ZERO, 0.01, 0.1, 0.1, 10, HEAD)
		kit.pop()
		kit.box(Vector3(s * (w - 0.1), 0.85, -hl - 0.01), Vector3(0.12, 0.1, 0.03), TAIL)
	# Wings over the wheels and running boards between them.
	kit.use("car", PAINT)
	for z: float in [wb * 0.5, -wb * 0.5]:
		for s: float in [-1.0, 1.0]:
			kit.sphere(Vector3(s * (W * 0.5 - 0.2), 0.6, z), Vector3(0.26, 0.3, 0.62), col.darkened(0.06), 4, 10)
	kit.use("car", MATTE)
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(s * (W * 0.5 - 0.2), 0.42, 0.0), Vector3(0.3, 0.05, wb - 1.1), Color("2a2a2a"))
	kit.use("car", PAINT)
	for z: float in [wb * 0.5, -wb * 0.5]:
		for s: float in [-1.0, 1.0]:
			wheel(kit, s * (W * 0.5 - 0.17), z, 0.36, s, NAN, 0.2, true)


static func _kart(kit: MeshKit, sp: Dictionary, col: Color) -> void:
	var L: float = sp["length"]
	var W: float = sp["width"]
	kit.use("car", CHROME)
	kit.box(Vector3(0, 0.12, 0), Vector3(W - 0.3, 0.05, L - 0.2), Color("7a7e84"))
	kit.use("car", PAINT)
	kit.box(Vector3(0, 0.22, L * 0.5 - 0.15), Vector3(W - 0.4, 0.16, 0.3), col)
	kit.box(Vector3(0, 0.2, -L * 0.5 + 0.12), Vector3(W, 0.12, 0.18), col)
	kit.box(Vector3(0, 0.3, 0.42), Vector3(0.5, 0.1, 0.36), col)
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(s * (W * 0.5 - 0.22), 0.22, 0.0), Vector3(0.18, 0.14, 0.9), col)
		kit.box(Vector3(s * (W * 0.5 - 0.22), 0.3, 0.0), Vector3(0.19, 0.03, 0.9), WHITE)
	kit.use("car", MATTE)
	kit.box(Vector3(0, 0.3, -0.25), Vector3(0.45, 0.06, 0.5), Color("1a1a1a"))
	kit.box(Vector3(0, 0.5, -0.5), Vector3(0.45, 0.4, 0.06), Color("1a1a1a"))
	kit.box(Vector3(0, 0.36, 0.62), Vector3(0.24, 0.16, 0.02), PLATE)
	kit.beam(Vector3(0, 0.22, 0.35), Vector3(0, 0.45, 0.15), Vector2(0.04, 0.04), Color("2a2a2a"))
	kit.push(Transform3D(Basis(Vector3.RIGHT, -1.1), Vector3(0, 0.46, 0.12)))
	kit.torus(Vector3.ZERO, 0.13, 0.018, 10, 4, Color("2a2a2a"))
	kit.pop()
	kit.use("car", PAINT)
	var wb := L * 0.62
	for z: float in [wb * 0.5, -wb * 0.5]:
		for s: float in [-1.0, 1.0]:
			wheel(kit, s * (W * 0.5 - 0.12), z, 0.17, s, NAN, 0.2 if z > 0.0 else 0.26)


static func _wheels4(kit: MeshKit, wb: float, w: float, r: float, rear_offset: float) -> void:
	for z: float in [wb * 0.5 - rear_offset, -wb * 0.5 - rear_offset]:
		for s: float in [-1.0, 1.0]:
			wheel(kit, s * (w - 0.1), z, r, s, w + 0.01)

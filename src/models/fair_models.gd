class_name FairModels
extends RefCounted
## Procedural models of the Kirmes (doc/kirmes.md): rides (static frames and the parts that
## move), booths, food stands, halls, string lights. Origins sit on the ground; "front" faces
## +Z unless stated otherwise. Bulbs use the "glow" surface, so they shine at night.

const RED := Color("e8442e")
const YELLOW := Color("f2c230")
const BLUE := Color("2e86de")
const PINK := Color("f28db2")
const GREEN := Color("27ae60")
const PURPLE := Color("8e44ad")
const ORANGE := Color("e67e22")
const TEAL := Color("1abc9c")
const WHITE := Color("f1eee6")
const GOLD := Color("e2c050")
const STEEL := Color("c8ccd0")
const DARK := Color("2a2a30")
const BULB := Color("ffe9a8")
## Surface flags (MeshKit.use): lacquer drawn with METAL is gold or steel, bulbs with STEADY don't
## chase. One surface each instead of three keeps the draw calls down.
const METAL := 0.0
const STEADY := 0.0
const COLORS := [RED, YELLOW, BLUE, PINK, GREEN, PURPLE, ORANGE, TEAL]
## Booths that sell food (a price board instead of the emblem).
const FOOD := ["candy", "almonds", "sausage", "crepes"]
## Stalls: the counter's top and the middle of the sign's field; its face is SIGN_FACE in front
## of the stall's front (d / 2).
const COUNTER_TOP := 1.06
const SIGN_Y := 3.45
const SIGN_FACE := 0.1

## Ferris wheel: hub height and wheel radius (the gondolas hang from the rim).
const WHEEL_HUB := 13.6
const WHEEL_R := 11.0
const WHEEL_GONDOLAS := 16
## Chain swing: crown height and chain length.
const CHAIN_TOP := 7.4
const CHAIN_LEN := 3.4
const CHAIN_R := 3.2
const CHAIN_SEATS := 16
## Swing boat: height of the bar.
const SWING_BAR := 6.4


static func cached(key: String, builder: Callable) -> Mesh:
	return NatureModels.cached("fair_" + key, builder)


# --- Ferris wheel ------------------------------------------------------------------

## The standing part: two A-frames left and right of the wheel (the wheel turns in the x-y
## plane at z = 0), the axle, the boarding platform with steps and the ticket booth.
static func ferris_frame() -> Mesh:
	return cached("ferris_frame", func() -> Mesh:
		var kit := MeshKit.new()
		var hub := Vector3(0, WHEEL_HUB, 0)
		for s: float in [-1.0, 1.0]:
			var top := hub + Vector3(0, 0, s * 2.2)
			kit.use("lacquer")
			for lx: float in [-6.5, 6.5]:
				kit.rod(Vector3(lx, 0.3, s * 3.4), top, 0.28, 0.2, 8, WHITE)
			kit.beam(Vector3(-4.2, 4.5, s * 3.0), Vector3(4.2, 4.5, s * 3.0), Vector2(0.18, 0.18), WHITE)
			kit.beam(Vector3(-2.3, 9.0, s * 2.6), Vector3(2.3, 9.0, s * 2.6), Vector2(0.16, 0.16), WHITE)
			# Cross braces between the legs.
			var leg := func(lx: float, h: float) -> Vector3:
				return Vector3(lx, 0.3, s * 3.4).lerp(top, (h - 0.3) / (WHEEL_HUB - 0.3))
			for hs: Array in [[0.6, 4.5], [4.5, 9.0]]:
				kit.beam(leg.call(-6.5, hs[0]), leg.call(6.5, hs[1]), Vector2(0.1, 0.1), WHITE)
				kit.beam(leg.call(6.5, hs[0]), leg.call(-6.5, hs[1]), Vector2(0.1, 0.1), WHITE)
			kit.use("lacquer", METAL)
			for lx: float in [-6.5, 6.5]:
				kit.cylinder(Vector3(lx, 0.3, s * 3.4), 0.25, 0.42, 0.34, 8, STEEL)
			kit.use("solid")
			kit.box(Vector3(0, 0.15, s * 3.4), Vector3(14.0, 0.3, 0.9), Color("8a847a"))
		kit.use("lacquer", METAL)
		kit.rod(hub + Vector3(0, 0, -2.4), hub + Vector3(0, 0, 2.4), 0.35, 0.35, 10, STEEL)
		# Boarding platform under the lowest gondola, steps to the front.
		kit.use("boards")
		kit.box(Vector3(0, 0.45, 0), Vector3(5.0, 0.9, 3.2), Color("8e1f2b"))
		kit.use("boards")
		kit.box(Vector3(0, 0.88, 0), Vector3(5.1, 0.06, 3.3), Color("a07c56"))
		for st in 3:
			kit.box(Vector3(0, 0.15 + st * 0.3, 2.0 + (2 - st) * 0.35), Vector3(3.0, 0.3, 0.35), Color("a07c56"))
		kit.use("lacquer", METAL)
		kit.box(Vector3(0, 0.8, 1.66), Vector3(5.1, 0.05, 0.02), GOLD)
		kit.use("lacquer")
		for x: float in [-2.4, 2.4]:
			kit.beam(Vector3(x, 0.9, -1.5), Vector3(x, 1.9, -1.5), Vector2(0.06, 0.06), RED)
			kit.beam(Vector3(x, 1.9, -1.5), Vector3(x, 1.9, 1.5), Vector2(0.06, 0.06), RED)
			kit.beam(Vector3(x, 0.9, 1.5), Vector3(x, 1.9, 1.5), Vector2(0.06, 0.06), RED)
			kit.beam(Vector3(x, 1.35, -1.5), Vector3(x, 1.35, 1.5), Vector2(0.04, 0.04), RED)
		# Ticket booth beside the steps: a little kiosk with a pointed roof and bulbs.
		kit.use("boards")
		kit.box(Vector3(4.3, 1.2, 2.2), Vector3(1.8, 2.4, 1.6), RED)
		kit.use("lacquer")
		kit.box(Vector3(4.3, 2.47, 2.2), Vector3(2.1, 0.14, 1.9), YELLOW)
		kit.lathe(PackedVector2Array([Vector2(1.45, 2.54), Vector2(0.0, 3.4)]), 4, RED, PI / 4)
		kit.use("lacquer", METAL)
		kit.sphere(Vector3(4.3, 3.45, 2.2), Vector3(0.12, 0.12, 0.12), GOLD, 2, 6)
		_frame(kit, Vector3(4.3, 1.45, 3.01), Vector2(1.3, 0.9), 0.05)
		kit.use("glow")
		kit.box(Vector3(4.3, 1.45, 3.01), Vector3(1.2, 0.8, 0.02), Color("bfe0ff"))
		kit.use("boards")
		kit.box(Vector3(4.3, 1.0, 3.12), Vector3(1.3, 0.05, 0.25), Color("c09060"))
		kit.use("bulbs")
		for k in 6:
			kit.sphere(Vector3(3.5 + k * 0.32, 2.37, 3.16), Vector3(0.05, 0.05, 0.05), BULB, 2, 5)
		return kit.commit())


## The turning wheel, origin at the hub: two rims with bulbs, spokes, the cross bars the
## gondolas hang from.
static func ferris_wheel() -> Mesh:
	return cached("ferris_wheel", func() -> Mesh:
		var kit := MeshKit.new()
		var n := 32
		for s: float in [-1.0, 1.0]:
			var z := s * 1.0
			for i in n:
				var a0 := TAU * i / n
				var a1 := TAU * (i + 1) / n
				var p0 := Vector3(cos(a0), sin(a0), 0) * WHEEL_R + Vector3(0, 0, z)
				var p1 := Vector3(cos(a1), sin(a1), 0) * WHEEL_R + Vector3(0, 0, z)
				kit.use("lacquer")
				kit.beam(p0, p1, Vector2(0.22, 0.22), WHITE)
				var q0 := Vector3(cos(a0), sin(a0), 0) * (WHEEL_R - 1.6) + Vector3(0, 0, z)
				var q1 := Vector3(cos(a1), sin(a1), 0) * (WHEEL_R - 1.6) + Vector3(0, 0, z)
				kit.beam(q0, q1, Vector2(0.12, 0.12), [RED, YELLOW, BLUE, GREEN][(i / 2) % 4])
				if i % 2 == 0:
					kit.use("lacquer", METAL)
					kit.beam(Vector3(0, 0, z * 1.6), p0, Vector2(0.1, 0.1), STEEL)
					kit.use("lacquer")
					kit.beam(q0, p1, Vector2(0.08, 0.08), WHITE)
		kit.use("lacquer", METAL)
		for i in WHEEL_GONDOLAS:
			var a := TAU * i / WHEEL_GONDOLAS
			var p := Vector3(cos(a), sin(a), 0) * WHEEL_R
			kit.beam(p + Vector3(0, 0, -1.1), p + Vector3(0, 0, 1.1), Vector2(0.14, 0.14), STEEL)
		# Hub: a red drum with a gold star on both faces.
		kit.use("lacquer")
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
		kit.cylinder(Vector3(0, -1.7, 0), 3.4, 1.0, 1.0, 14, RED)
		kit.pop()
		kit.use("lacquer", METAL)
		for s: float in [-1.0, 1.0]:
			kit.push(Transform3D(Basis(Vector3.UP, 0.0 if s > 0 else PI), Vector3(0, 0, s * 1.71)))
			_star(kit, Vector3.ZERO, 0.85, 0.36, GOLD)
			kit.pop()
		kit.use("bulbs")
		for s: float in [-1.0, 1.0]:
			for i in 48:
				var a := TAU * (i + 0.5) / 48
				kit.box(Vector3(cos(a), sin(a), 0) * (WHEEL_R + 0.18) + Vector3(0, 0, s * 1.0), Vector3(0.16, 0.16, 0.16),
					BULB if i % 3 else Color("ff8fb0"))
		return kit.commit())


## A gondola hanging from its pivot (origin), open at the front and back so you see who rides.
static func gondola(col: Color) -> Mesh:
	return cached("gondola_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("lacquer")   # one surface: there are many of these
		kit.beam(Vector3(0, 0, -0.5), Vector3(0, -0.9, -0.5), Vector2(0.06, 0.06), STEEL)
		kit.beam(Vector3(0, 0, 0.5), Vector3(0, -0.9, 0.5), Vector2(0.06, 0.06), STEEL)
		kit.box(Vector3(0, -2.25, 0), Vector3(1.7, 0.12, 1.5), col.darkened(0.2))
		kit.box(Vector3(0, -1.95, -0.7), Vector3(1.7, 0.5, 0.08), col)
		kit.box(Vector3(0, -1.95, 0.7), Vector3(1.7, 0.5, 0.08), col)
		for x: float in [-0.82, 0.82]:
			kit.box(Vector3(x, -1.75, 0), Vector3(0.08, 0.9, 1.5), col)
			kit.beam(Vector3(x, -1.3, -0.7), Vector3(x, -0.9, -0.7), Vector2(0.05, 0.05), STEEL)
			kit.beam(Vector3(x, -1.3, 0.7), Vector3(x, -0.9, 0.7), Vector2(0.05, 0.05), STEEL)
		kit.box(Vector3(0, -2.05, 0), Vector3(1.2, 0.3, 0.5), WHITE)
		kit.lathe(PackedVector2Array([Vector2(1.25, -0.95), Vector2(0.0, -0.5)]), 4, col.lightened(0.25), PI / 4)
		for z: float in [-0.75, 0.75]:
			kit.box(Vector3(0, -1.69, z), Vector3(1.74, 0.04, 0.02), GOLD)
		kit.sphere(Vector3(0, -0.45, 0), Vector3(0.08, 0.08, 0.08), GOLD, 2, 5)
		return kit.commit())


# --- Carousel ------------------------------------------------------------------------

static func carousel_base() -> Mesh:
	return cached("carousel_base", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("lacquer")
		kit.cylinder(Vector3.ZERO, 0.35, 6.3, 6.3, 24, Color("8e1f2b"), true, Color("c9b9a6"))
		kit.use("lacquer", METAL)
		kit.cylinder(Vector3(0, 0.29, 0), 0.04, 6.32, 6.32, 24, GOLD, false)
		kit.use("boards")
		for st in 2:
			kit.box(Vector3(0, 0.08 + st * 0.12, 6.5 + (1 - st) * 0.3), Vector3(2.4, 0.16, 0.3), Color("a07c56"))
		return kit.commit())


## The turning part: floor, mirrored centre column, poles and the striped roof with bulbs.
static func carousel_top() -> Mesh:
	return cached("carousel_top", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("boards")
		kit.cylinder(Vector3(0, 0.35, 0), 0.12, 5.9, 5.9, 24, Color("8a5a34"), true, Color("b98a57"))
		# Centre column: gold with mirror panels in gold frames, a painted band above.
		kit.use("lacquer", METAL)
		kit.cylinder(Vector3(0, 0.47, 0), 3.2, 1.3, 1.3, 12, GOLD)
		kit.use("glow")
		for i in 12:
			var a := TAU * (i + 0.5) / 12
			kit.box(Vector3(cos(a) * 1.3, 2.0, sin(a) * 1.3), Vector3(0.3, 1.5, 0.3), Color("cfe8ff"))
		kit.use("lacquer")
		kit.cylinder(Vector3(0, 3.0, 0), 0.6, 1.36, 1.36, 12, RED, false)
		var segs := 16
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var col: Color = RED if i % 2 == 0 else WHITE
			var c0 := Vector3(cos(a0), 0, sin(a0))
			var c1 := Vector3(cos(a1), 0, sin(a1))
			kit.use("canvas")
			kit.tri(c0 * 6.3 + Vector3(0, 3.7, 0), c1 * 6.3 + Vector3(0, 3.7, 0), Vector3(0, 5.6, 0), col)
			kit.tri(c0 * 6.3 + Vector3(0, 3.69, 0), Vector3(0, 5.59, 0), c1 * 6.3 + Vector3(0, 3.69, 0), col.darkened(0.35))
			# Rounding board: painted panels with a mirror each, gold edges.
			var mid := (c0 + c1).normalized()
			kit.use("lacquer")
			var pc: Color = [BLUE, GREEN, PURPLE, TEAL][i % 4]
			kit.quad(c0 * 6.32 + Vector3(0, 3.15, 0), c0 * 6.32 + Vector3(0, 3.72, 0), c1 * 6.32 + Vector3(0, 3.72, 0), c1 * 6.32 + Vector3(0, 3.15, 0), pc)
			kit.quad(c0 * 6.3 + Vector3(0, 3.15, 0), c1 * 6.3 + Vector3(0, 3.15, 0), c1 * 6.3 + Vector3(0, 3.72, 0), c0 * 6.3 + Vector3(0, 3.72, 0), pc.darkened(0.4))
			kit.use("glow")
			kit.push(Transform3D(Basis(Vector3.UP, PI / 2 - (a0 + a1) * 0.5), mid * 6.36 + Vector3(0, 3.43, 0)))
			kit.sphere(Vector3.ZERO, Vector3(0.28, 0.18, 0.02), Color("cfe8ff"), 2, 8)
			kit.pop()
			kit.use("lacquer", METAL)
			kit.beam(c0 * 6.36 + Vector3(0, 3.72, 0), c1 * 6.36 + Vector3(0, 3.72, 0), Vector2(0.06, 0.06), GOLD)
			kit.beam(c0 * 6.36 + Vector3(0, 3.15, 0), c1 * 6.36 + Vector3(0, 3.15, 0), Vector2(0.05, 0.05), GOLD)
			# Scalloped valance under the board.
			kit.use("canvas")
			kit.tri(c0 * 6.3 + Vector3(0, 3.15, 0), mid * 6.3 + Vector3(0, 2.75, 0), c1 * 6.3 + Vector3(0, 3.15, 0), YELLOW)
			kit.tri(c0 * 6.3 + Vector3(0, 3.15, 0), c1 * 6.3 + Vector3(0, 3.15, 0), mid * 6.3 + Vector3(0, 2.75, 0), YELLOW.darkened(0.2))
		kit.use("lacquer", METAL)
		kit.cylinder(Vector3(0, 5.6, 0), 0.8, 0.12, 0.05, 6, GOLD)
		kit.sphere(Vector3(0, 6.5, 0), Vector3(0.25, 0.25, 0.25), GOLD, 3, 6)
		kit.use("canvas")
		kit.tri_c(Vector3(0, 6.95, 0), Vector3(0, 6.65, 0), Vector3(0.6, 6.8, 0), RED, RED, Color(RED, 0.0))
		kit.tri_c(Vector3(0, 6.95, 0), Vector3(0.6, 6.8, 0), Vector3(0, 6.65, 0), RED, Color(RED, 0.0), RED)
		kit.use("lacquer", METAL)
		kit.rod(Vector3(0, 6.5, 0), Vector3(0, 7.0, 0), 0.02, 0.02, 4, STEEL)
		kit.use("bulbs")
		for i in 48:
			var a := TAU * (i + 0.5) / 48
			kit.sphere(Vector3(cos(a) * 6.42, 3.72, sin(a) * 6.42), Vector3(0.07, 0.07, 0.07), BULB if i % 4 else Color("ff9ab0"), 2, 5)
		for i in 32:
			var a := TAU * (i + 0.5) / 32
			kit.sphere(Vector3(cos(a) * 6.42, 3.15, sin(a) * 6.42), Vector3(0.06, 0.06, 0.06), BULB, 2, 5)
		for i in 16:
			var a := TAU * (i + 0.5) / 16
			var c := Vector3(cos(a), 0, sin(a))
			kit.sphere(c.lerp(Vector3.ZERO, 0.5) * 6.3 + Vector3(0, 4.65, 0) + Vector3(0, 0.03, 0), Vector3(0.06, 0.06, 0.06), BULB, 2, 5)
		return kit.commit())


## A carousel horse on its brass pole (origin on the floor; the horse bobs along the pole).
static func carousel_horse(col: Color) -> Mesh:
	return cached("horse_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("lacquer")   # one surface: there are many of these
		var mane := col.darkened(0.45)
		kit.sphere(Vector3(0, 1.0, 0), Vector3(0.24, 0.26, 0.62), col, 3, 6)
		kit.rod(Vector3(0, 1.15, 0.45), Vector3(0, 1.55, 0.62), 0.11, 0.09, 5, col)
		kit.sphere(Vector3(0, 1.62, 0.72), Vector3(0.12, 0.13, 0.24), col, 3, 5)
		kit.box(Vector3(0, 1.45, 0.42), Vector3(0.06, 0.4, 0.22), mane)
		for z: float in [-0.38, 0.38]:
			for x: float in [-0.13, 0.13]:
				kit.rod(Vector3(x, 0.9, z), Vector3(x, 0.45, z + 0.12 * signf(z)), 0.05, 0.04, 4, col)
		kit.rod(Vector3(0, 1.0, -0.6), Vector3(0, 0.6, -0.8), 0.06, 0.02, 4, mane)
		kit.box(Vector3(0, 1.24, -0.05), Vector3(0.36, 0.06, 0.4), RED)
		kit.box(Vector3(0, 1.08, -0.05), Vector3(0.5, 0.3, 0.36), RED.darkened(0.15))
		kit.cylinder(Vector3(0, 0.0, 0), 3.2, 0.035, 0.035, 6, GOLD, false)
		kit.box(Vector3(0, 1.28, -0.05), Vector3(0.38, 0.02, 0.42), GOLD)
		kit.rod(Vector3(0, 1.62, 0.72), Vector3(0, 1.4, 0.3), 0.012, 0.012, 4, GOLD)
		for x: float in [-0.27, 0.27]:
			kit.rod(Vector3(x, 1.15, 0.0), Vector3(x, 0.85, 0.1), 0.01, 0.01, 4, GOLD)
			kit.box(Vector3(x, 0.83, 0.1), Vector3(0.05, 0.03, 0.1), GOLD)
		return kit.commit())


# --- Chain swing ----------------------------------------------------------------------

static func chain_tower() -> Mesh:
	return cached("chain_tower", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("lacquer")
		kit.cylinder(Vector3.ZERO, 0.3, 2.6, 2.6, 16, Color("8e1f2b"), true, Color("c9b9a6"))
		kit.cylinder(Vector3(0, 0.3, 0), CHAIN_TOP - 0.3, 0.55, 0.4, 12, BLUE)
		for i in 6:
			var a := TAU * i / 6
			kit.box(Vector3(cos(a) * 0.5, 2.5 + (i % 3) * 1.4, sin(a) * 0.5), Vector3(0.2, 0.9, 0.2), YELLOW)
		kit.use("lacquer", METAL)
		kit.cylinder(Vector3(0, 0.26, 0), 0.04, 2.62, 2.62, 16, GOLD, false)
		for y: float in [1.2, 6.6]:
			kit.cylinder(Vector3(0, y, 0), 0.12, 0.6 - y * 0.02, 0.6 - y * 0.02, 12, GOLD)
		kit.use("bulbs")
		for i in 14:
			var a := TAU * i / 7.0
			kit.sphere(Vector3(cos(a) * 0.55, 1.5 + i * 0.36, sin(a) * 0.55), Vector3(0.06, 0.06, 0.06), BULB, 2, 5)
		return kit.commit())


## The turning crown at the top (origin at the crown's centre), with bulbs and a little roof.
static func chain_crown() -> Mesh:
	return cached("chain_crown", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("lacquer")
		kit.cylinder(Vector3(0, -0.3, 0), 0.6, CHAIN_R + 0.2, CHAIN_R + 0.2, 16, WHITE, true, BLUE)
		kit.use("canvas")
		for i in 16:
			var a0 := TAU * i / 16
			var a1 := TAU * (i + 1) / 16
			var c: Color = BLUE if i % 2 == 0 else YELLOW
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			kit.quad(d0 * (CHAIN_R + 0.6) + Vector3(0, 0.3, 0), d0 * 0.4 + Vector3(0, 1.7, 0), d1 * 0.4 + Vector3(0, 1.7, 0),
				d1 * (CHAIN_R + 0.6) + Vector3(0, 0.3, 0), c)
		kit.use("lacquer", METAL)
		kit.cylinder(Vector3(0, 1.7, 0), 0.25, 0.4, 0.15, 8, GOLD)
		kit.sphere(Vector3(0, 2.1, 0), Vector3(0.2, 0.2, 0.2), GOLD, 3, 6)
		kit.use("lacquer")
		for i in 16:
			var a := TAU * (i + 0.5) / 16
			kit.quad(Vector3(cos(a - 0.2), 0, sin(a - 0.2)) * (CHAIN_R + 0.62) + Vector3(0, 0.3, 0),
				Vector3(cos(a + 0.2), 0, sin(a + 0.2)) * (CHAIN_R + 0.62) + Vector3(0, 0.3, 0),
				Vector3(cos(a + 0.2), 0, sin(a + 0.2)) * (CHAIN_R + 0.62) + Vector3(0, -0.1, 0),
				Vector3(cos(a - 0.2), 0, sin(a - 0.2)) * (CHAIN_R + 0.62) + Vector3(0, -0.1, 0), YELLOW if i % 2 else RED)
		kit.use("bulbs")
		for i in 24:
			var a := TAU * i / 24
			kit.sphere(Vector3(cos(a), 0, sin(a)) * (CHAIN_R + 0.25) + Vector3(0, -0.34, 0), Vector3(0.07, 0.07, 0.07), BULB, 2, 5)
		for i in 32:
			var a := TAU * (i + 0.5) / 32
			kit.sphere(Vector3(cos(a), 0, sin(a)) * (CHAIN_R + 0.66) + Vector3(0, 0.33, 0), Vector3(0.06, 0.06, 0.06),
				BULB if i % 2 else Color("ff9ab0"), 2, 5)
		return kit.commit())


## A seat on its chains (origin at the hook; the seat hangs CHAIN_LEN below).
static func chain_seat(col: Color) -> Mesh:
	return cached("chain_seat_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("lacquer")   # one surface: there are many of these
		for x: float in [-0.22, 0.22]:
			kit.beam(Vector3(0, 0, 0), Vector3(x, -CHAIN_LEN, 0), Vector2(0.03, 0.03), STEEL)
		kit.box(Vector3(0, -CHAIN_LEN - 0.05, 0.05), Vector3(0.5, 0.08, 0.45), col)
		kit.box(Vector3(0, -CHAIN_LEN + 0.25, -0.17), Vector3(0.5, 0.55, 0.06), col)
		kit.beam(Vector3(-0.25, -CHAIN_LEN + 0.25, 0.25), Vector3(0.25, -CHAIN_LEN + 0.25, 0.25), Vector2(0.03, 0.03), STEEL)
		return kit.commit())


# --- Swing boat -------------------------------------------------------------------------

## Two A-frames carrying the bar (along x at SWING_BAR) for two swing boats.
static func swing_frame() -> Mesh:
	return cached("swing_frame", func() -> Mesh:
		var kit := MeshKit.new()
		for x: float in [-4.6, 4.6]:
			kit.use("lacquer")
			for z: float in [-2.8, 2.8]:
				kit.rod(Vector3(x, 0, z), Vector3(x, SWING_BAR, 0), 0.14, 0.12, 8, RED)
			kit.beam(Vector3(x, 2.0, -2.0), Vector3(x, 2.0, 2.0), Vector2(0.1, 0.1), RED)
			kit.beam(Vector3(x, 4.2, -0.95), Vector3(x, 4.2, 0.95), Vector2(0.08, 0.08), RED)
			# A painted diamond with a star over each A-frame, facing out.
			var out := signf(x)
			kit.push(Transform3D(Basis(Vector3.UP, out * PI / 2), Vector3(x + out * 0.18, SWING_BAR + 0.6, 0)))
			kit.use("lacquer")
			kit.quad(Vector3(0, -0.5, 0), Vector3(0.7, 0, 0), Vector3(0, 0.5, 0), Vector3(-0.7, 0, 0), YELLOW)
			kit.quad(Vector3(0, -0.5, -0.02), Vector3(-0.7, 0, -0.02), Vector3(0, 0.5, -0.02), Vector3(0.7, 0, -0.02), YELLOW.darkened(0.3))
			_star(kit, Vector3(0, 0, 0.01), 0.3, 0.13, RED)
			kit.pop()
		kit.use("lacquer", METAL)
		kit.rod(Vector3(-4.8, SWING_BAR, 0), Vector3(4.8, SWING_BAR, 0), 0.16, 0.16, 10, STEEL)
		kit.use("boards")
		kit.box(Vector3(0, 0.12, 0), Vector3(10.0, 0.24, 3.0), Color("a07c56"))
		kit.use("bulbs")
		for i in 25:
			kit.sphere(Vector3(-4.8 + i * 0.4, SWING_BAR + 0.22, 0), Vector3(0.06, 0.06, 0.06), BULB if i % 3 else Color("ff9ab0"), 2, 5)
		return kit.commit())


## A swing boat hanging from the bar (origin on the bar; it swings about x).
static func swing_boat(col: Color) -> Mesh:
	return cached("swing_boat_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		var arm := SWING_BAR - 1.2
		kit.use("lacquer", METAL)
		for x: float in [-0.95, 0.95]:
			for z: float in [-1.0, 1.0]:
				kit.beam(Vector3(x, 0, 0), Vector3(x, -arm, z), Vector2(0.07, 0.07), STEEL)
		kit.use("lacquer")
		var hull := PackedVector2Array()
		for i in 13:
			var t := float(i) / 12.0
			var z := lerpf(-1.8, 1.8, t)
			hull.append(Vector2(z, -arm - 0.2 + 0.55 * pow(absf(z) / 1.8, 2.0) * 1.0))
		for i in 12:
			var a := hull[i]
			var b := hull[i + 1]
			for x: float in [-0.95, 0.95]:
				kit.quad(Vector3(x, a.y - 0.45, a.x), Vector3(x, a.y + 0.45, a.x), Vector3(x, b.y + 0.45, b.x), Vector3(x, b.y - 0.45, b.x), col)
			kit.quad(Vector3(-0.95, a.y - 0.45, a.x), Vector3(-0.95, b.y - 0.45, b.x), Vector3(0.95, b.y - 0.45, b.x), Vector3(0.95, a.y - 0.45, a.x), col.darkened(0.3))
		kit.use("boards")
		kit.box(Vector3(0, -arm - 0.35, 0), Vector3(1.8, 0.08, 2.6), Color("8a5a34"))
		for z: float in [-1.0, 1.0]:
			kit.box(Vector3(0, -arm - 0.1, z), Vector3(1.8, 0.1, 0.4), Color("b98a57"))
		kit.use("lacquer", METAL)
		for x: float in [-0.97, 0.97]:
			for k in 12:
				var a := hull[k]
				var b := hull[k + 1]
				kit.beam(Vector3(x, a.y + 0.45, a.x), Vector3(x, b.y + 0.45, b.x), Vector2(0.06, 0.06), GOLD)
			kit.push(Transform3D(Basis(Vector3.UP, signf(x) * PI / 2), Vector3(x * 1.005, -arm - 0.05, 0)))
			_star(kit, Vector3.ZERO, 0.28, 0.12, YELLOW)
			kit.pop()
		return kit.commit())


# --- Roller coaster -----------------------------------------------------------------------

## Rails, sleepers and posts along the closed track (points with height), the station.
static func coaster_track(track: PackedVector3Array) -> Mesh:
	var kit := MeshKit.new()
	var n := track.size()
	for i in n:
		var a := track[i]
		var b := track[(i + 1) % n]
		var t := (b - a).normalized()
		var side := Vector3(-t.z, 0, t.x).normalized() * 0.55
		kit.use("lacquer", METAL)
		kit.beam(a + side, b + side, Vector2(0.14, 0.14), STEEL)
		kit.beam(a - side, b - side, Vector2(0.14, 0.14), STEEL)
		kit.use("lacquer")
		kit.beam(a - Vector3(0, 0.35, 0), b - Vector3(0, 0.35, 0), Vector2(0.24, 0.24), RED)
		if i % 2 == 0:
			kit.beam(a + side * 1.05 - Vector3(0, 0.12, 0), a - side * 1.05 - Vector3(0, 0.12, 0), Vector2(0.12, 0.08), RED.darkened(0.3))
			kit.beam(a + side - Vector3(0, 0.1, 0), a - Vector3(0, 0.33, 0), Vector2(0.06, 0.06), RED.darkened(0.3))
			kit.beam(a - side - Vector3(0, 0.1, 0), a - Vector3(0, 0.33, 0), Vector2(0.06, 0.06), RED.darkened(0.3))
		var ground_y := track[0].y - 1.4
		if i % 4 == 0 and a.y > ground_y + 1.0:
			var foot := Vector3(a.x, ground_y, a.z)
			kit.use("lacquer")
			kit.beam(foot + side * 1.3, a - Vector3(0, 0.3, 0) + side * 0.5, Vector2(0.18, 0.18), WHITE)
			kit.beam(foot - side * 1.3, a - Vector3(0, 0.3, 0) - side * 0.5, Vector2(0.18, 0.18), WHITE)
			kit.use("solid")
			for sd: float in [-1.0, 1.0]:
				kit.box(foot + side * 1.3 * sd + Vector3(0, 0.1, 0), Vector3(0.5, 0.2, 0.5), Color("8a847a"))
			kit.use("lacquer")
			if a.y > ground_y + 4.0:
				var mid := (a.y + ground_y) * 0.5
				kit.beam(Vector3(a.x, mid, a.z) + side * 0.9, Vector3(a.x, mid, a.z) - side * 0.9, Vector2(0.1, 0.1), WHITE)
				kit.beam(foot + side * 1.2 + Vector3(0, 0.4, 0), Vector3(a.x, mid, a.z) - side * 0.9, Vector2(0.07, 0.07), WHITE)
				kit.beam(foot - side * 1.2 + Vector3(0, 0.4, 0), Vector3(a.x, mid, a.z) + side * 0.9, Vector2(0.07, 0.07), WHITE)
	return kit.commit()


static func coaster_station() -> Mesh:
	return cached("coaster_station", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("boards")
		kit.box(Vector3(0, 0.45, 0), Vector3(10.0, 0.9, 3.0), Color("2c3e66"))
		kit.use("boards")
		kit.box(Vector3(0, 0.88, 0), Vector3(10.1, 0.06, 3.1), Color("a07c56"))
		for st in 3:
			kit.box(Vector3(0, 0.15 + st * 0.3, 1.8 + (2 - st) * 0.35), Vector3(3.0, 0.3, 0.35), Color("a07c56"))
		kit.use("lacquer")
		for x: float in [-4.6, -1.55, 1.55, 4.6]:
			for z: float in [-1.6, 1.6]:
				kit.beam(Vector3(x, 0.9, z), Vector3(x, 3.6, z), Vector2(0.14, 0.14), WHITE)
		kit.box(Vector3(0, 3.7, 0), Vector3(10.6, 0.2, 3.8), YELLOW)
		for x: float in [-4.6, 4.6]:
			kit.beam(Vector3(x, 1.85, -1.5), Vector3(x, 1.85, 1.5), Vector2(0.05, 0.05), RED)
		# A striped tent roof.
		kit.use("canvas")
		var corners := [Vector3(-5.6, 3.8, -2.1), Vector3(5.6, 3.8, -2.1), Vector3(5.6, 3.8, 2.1), Vector3(-5.6, 3.8, 2.1)]
		for k in 4:
			var a: Vector3 = corners[k]
			var b: Vector3 = corners[(k + 1) % 4]
			var n := 6 if k % 2 == 0 else 2
			for j in n:
				var p0 := a.lerp(b, float(j) / n)
				var p1 := a.lerp(b, float(j + 1) / n)
				var apex := Vector3(0, 5.1, 0)
				kit.tri(p1, p0, apex, RED if j % 2 == 0 else WHITE)
				kit.tri(p0, p1, apex - Vector3(0, 0.02, 0), (RED if j % 2 == 0 else WHITE).darkened(0.35))
		kit.use("lacquer", METAL)
		kit.sphere(Vector3(0, 5.2, 0), Vector3(0.18, 0.18, 0.18), GOLD, 2, 6)
		kit.use("bulbs")
		for i in 28:
			kit.sphere(Vector3(-5.4 + i * 0.4, 3.62, 1.95), Vector3(0.06, 0.06, 0.06), BULB if i % 3 else Color("ff9ab0"), 2, 5)
		return kit.commit())


## One car of the coaster train (front +Z).
static func coaster_car(col: Color, front := false) -> Mesh:
	return cached("coaster_car_%s_%s" % [col.to_html(), front], func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("lacquer")   # one surface: there are many of these
		kit.box(Vector3(0, 0.35, 0), Vector3(1.3, 0.5, 1.7), col)
		kit.box(Vector3(0, 0.45, 0), Vector3(1.32, 0.04, 1.72), GOLD)
		kit.box(Vector3(0, 0.62, -0.4), Vector3(1.2, 0.06, 0.6), DARK)
		kit.box(Vector3(0, 0.62, 0.35), Vector3(1.2, 0.06, 0.6), DARK)
		kit.box(Vector3(0, 0.75, -0.72), Vector3(1.2, 0.3, 0.08), col.darkened(0.2))
		kit.box(Vector3(0, 0.75, 0.05), Vector3(1.2, 0.3, 0.08), col.darkened(0.2))
		if front:
			kit.box(Vector3(0, 0.6, 0.95), Vector3(1.2, 0.6, 0.2), col.lightened(0.2))
			kit.sphere(Vector3(0.3, 0.75, 1.06), Vector3(0.09, 0.09, 0.04), WHITE, 2, 5)
			kit.sphere(Vector3(-0.3, 0.75, 1.06), Vector3(0.09, 0.09, 0.04), WHITE, 2, 5)
		for x: float in [-0.6, 0.6]:
			for z: float in [-0.6, 0.6]:
				kit.sphere(Vector3(x, 0.12, z), Vector3(0.1, 0.12, 0.12), DARK, 2, 5)
		return kit.commit())


# --- Halls -----------------------------------------------------------------------------

## The ghost train: a dark house with a painted front, two doors (in, out) and a funny ghost
## and bat on the roof. Footprint 26 × 14, front +Z.
static func ghost_train() -> Mesh:
	return cached("ghost_train", func() -> Mesh:
		var kit := MeshKit.new()
		var wall := Color("4a3560")
		kit.use("boards")
		kit.box(Vector3(0, 3.5, 0), Vector3(26.0, 7.0, 14.0), wall, Color("2a1f36"))
		# Crooked towers at the corners.
		for x: float in [-12.0, 12.0]:
			kit.use("boards")
			kit.box(Vector3(x, 4.5, 6.0), Vector3(3.0, 9.0, 3.0), wall.darkened(0.15))
			kit.use("lacquer")
			kit.push(Transform3D(Basis(Vector3.BACK, 0.12 * signf(x)), Vector3(x, 9.0, 6.0)))
			kit.lathe(PackedVector2Array([Vector2(2.4, 0.0), Vector2(0.0, 3.0)]), 4, Color("5a2a6a"), PI / 4)
			kit.pop()
			kit.use("glow")
			for y: float in [5.5, 7.5]:
				kit.box(Vector3(x, y, 7.52), Vector3(0.9, 1.1, 0.04), Color("ffcf5a"))
			kit.use("solid")
			for y: float in [5.5, 7.5]:
				kit.box(Vector3(x, y, 7.55), Vector3(0.08, 1.1, 0.03), Color("1a1424"))
				kit.box(Vector3(x, y, 7.55), Vector3(0.9, 0.08, 0.03), Color("1a1424"))
		kit.use("solid")
		# Battlements along the front and a crooked sign board.
		kit.use("boards")
		for k in 9:
			kit.box(Vector3(-9.6 + k * 2.4, 7.3, 6.8), Vector3(1.2, 0.6 + (k % 3) * 0.12, 0.4), wall.darkened(0.1))
		kit.use("lacquer")
		kit.push(Transform3D(Basis(Vector3.BACK, 0.03), Vector3(0, 5.75, 7.12)))
		kit.box(Vector3.ZERO, Vector3(9.0, 1.5, 0.12), Color("231a33"))
		_frame(kit, Vector3(0, 0, 0.07), Vector2(9.0, 1.5), 0.08)
		kit.pop()
		kit.use("solid")
		# Painted front: moon, green slime, eyes.
		kit.box(Vector3(0, 5.6, 7.02), Vector3(20.0, 2.2, 0.06), Color("1f1830"))
		kit.disc(Vector3(-8.0, 5.6, 7.06), 0.0, 3, WHITE)
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(-8.0, 5.7, 7.07)))
		kit.disc(Vector3.ZERO, 0.9, 12, Color("f4eecb"))
		kit.pop()
		for i in 9:
			kit.box(Vector3(-9.0 + i * 2.2, 4.3 - (i % 2) * 0.25, 7.04), Vector3(1.6, 0.4 + (i % 3) * 0.2, 0.05), Color("7bd34a"))
		for x: float in [-5.5, 5.5]:
			# Doors with a frame, the rails run in.
			kit.box(Vector3(x, 1.5, 7.03), Vector3(3.4, 3.0, 0.06), Color("120c18"))
			kit.box(Vector3(x, 3.15, 7.05), Vector3(3.8, 0.3, 0.1), Color("7bd34a"))
			for rx: float in [-0.55, 0.55]:
				kit.beam(Vector3(x + rx, 0.05, 7.0), Vector3(x + rx, 0.05, 11.5), Vector2(0.08, 0.08), STEEL)
		kit.use("lacquer", METAL)
		kit.box(Vector3(0, 0.05, 9.2), Vector3(14.6, 0.1, 0.8), STEEL)
		kit.use("boards")
		kit.box(Vector3(0, 0.3, 11.0), Vector3(8.6, 0.6, 2.0), Color("5a4a6a"))
		# Gravestones and a pumpkin in front.
		kit.use("solid")
		for k in 4:
			var gx := -11.5 + k * 1.1 if k < 2 else 9.5 + (k - 2) * 1.1
			kit.box(Vector3(gx, 0.4, 9.0 + (k % 2) * 0.6), Vector3(0.6, 0.8, 0.18), Color("8a8a96"))
			kit.cylinder(Vector3(gx, 0.8, 9.0 + (k % 2) * 0.6 - 0.09), 0.18, 0.3, 0.3, 8, Color("8a8a96"), true, Color("8a8a96"), 0.0)
		kit.use("lacquer")
		kit.sphere(Vector3(8.2, 0.35, 10.2), Vector3(0.45, 0.35, 0.45), ORANGE, 3, 8)
		kit.use("glow")
		for x: float in [-0.15, 0.15]:
			kit.tri(Vector3(8.2 + x - 0.08, 0.42, 10.63), Vector3(8.2 + x + 0.08, 0.42, 10.63), Vector3(8.2 + x, 0.55, 10.63), Color("ffcf5a"))
		kit.box(Vector3(8.2, 0.25, 10.6), Vector3(0.3, 0.06, 0.04), Color("ffcf5a"))
		kit.use("lacquer")
		# A friendly ghost waving from the roof.
		kit.sphere(Vector3(0, 9.0, 3.0), Vector3(1.5, 1.8, 1.3), WHITE, 4, 8)
		kit.cylinder(Vector3(0, 7.0, 3.0), 2.0, 1.6, 1.4, 8, WHITE)
		kit.sphere(Vector3(-0.5, 9.4, 4.15), Vector3(0.22, 0.3, 0.1), DARK, 2, 5)
		kit.sphere(Vector3(0.5, 9.4, 4.15), Vector3(0.22, 0.3, 0.1), DARK, 2, 5)
		kit.sphere(Vector3(0, 8.7, 4.2), Vector3(0.3, 0.2, 0.1), DARK, 2, 5)
		kit.rod(Vector3(1.4, 8.6, 3.0), Vector3(2.6, 9.8, 3.4), 0.3, 0.2, 5, WHITE)
		# A bat on the left tower.
		kit.sphere(Vector3(-12.0, 12.4, 6.0), Vector3(0.3, 0.3, 0.3), DARK, 2, 5)
		kit.tri(Vector3(-12.0, 12.4, 6.0), Vector3(-13.4, 12.9, 6.0), Vector3(-12.6, 12.1, 6.0), DARK)
		kit.tri(Vector3(-12.0, 12.4, 6.0), Vector3(-11.4, 12.1, 6.0), Vector3(-10.6, 12.9, 6.0), DARK)
		kit.use("bulbs")
		for i in 40:
			kit.sphere(Vector3(-11.7 + i * 0.6, 6.9, 7.1), Vector3(0.08, 0.08, 0.06), [Color("b06aff"), Color("7bd34a"), Color("ff7a3a")][i % 3], 2, 5)
		for x: float in [-5.5, 5.5]:
			for k in 9:
				kit.sphere(Vector3(x - 1.9 + k * 0.475, 3.35, 7.1), Vector3(0.06, 0.06, 0.05), Color("7bd34a") if k % 2 else Color("b06aff"), 2, 5)
		return kit.commit())


## A ghost-train car (front +Z), with a bat face at the front.
static func ghost_car(col: Color) -> Mesh:
	return cached("ghost_car_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("lacquer")   # one surface: there are many of these
		kit.box(Vector3(0, 0.4, 0), Vector3(1.2, 0.6, 1.6), col)
		kit.box(Vector3(0, 0.75, -0.3), Vector3(1.1, 0.08, 0.7), DARK)
		kit.box(Vector3(0, 0.95, -0.7), Vector3(1.1, 0.5, 0.1), col.darkened(0.25))
		kit.box(Vector3(0, 0.85, 0.75), Vector3(1.0, 0.6, 0.12), DARK)
		kit.sphere(Vector3(-0.25, 0.95, 0.83), Vector3(0.1, 0.1, 0.04), Color("ffde3a"), 2, 5)
		kit.sphere(Vector3(0.25, 0.95, 0.83), Vector3(0.1, 0.1, 0.04), Color("ffde3a"), 2, 5)
		return kit.commit())


## The bumper-car hall: a raised floor with a rubber border, posts and a flat roof whose
## ceiling grid the cars' poles touch. Footprint 28 × 18, open on all sides.
static func bumper_hall() -> Mesh:
	return cached("bumper_hall", func() -> Mesh:
		var kit := MeshKit.new()
		var w := 28.0
		var d := 18.0
		kit.use("lacquer", METAL)
		kit.box(Vector3(0, 0.15, 0), Vector3(w, 0.3, d), Color("5a5a62"), Color("8a8a96"))
		kit.use("solid")
		kit.box(Vector3(0, 0.42, d * 0.5 - 0.2), Vector3(w, 0.25, 0.4), Color("222226"))
		kit.box(Vector3(0, 0.42, -d * 0.5 + 0.2), Vector3(w, 0.25, 0.4), Color("222226"))
		kit.box(Vector3(w * 0.5 - 0.2, 0.42, 0), Vector3(0.4, 0.25, d), Color("222226"))
		kit.box(Vector3(-w * 0.5 + 0.2, 0.42, 0), Vector3(0.4, 0.25, d), Color("222226"))
		kit.use("lacquer")
		for x: float in [-w * 0.5 + 0.4, -w / 6.0, w / 6.0, w * 0.5 - 0.4]:
			for z: float in [-d * 0.5 + 0.4, d * 0.5 - 0.4]:
				kit.beam(Vector3(x, 0.3, z), Vector3(x, 4.6, z), Vector2(0.25, 0.25), YELLOW)
				kit.box(Vector3(x, 4.45, z), Vector3(0.34, 0.12, 0.34), RED)
		kit.use("boards")
		kit.box(Vector3(0, 4.8, 0), Vector3(w + 1.0, 0.4, d + 1.0), Color("3a3a42"))
		kit.use("lacquer")
		# Fascia with stripes around the roof.
		for i in 12:
			var x := -w * 0.5 + (i + 0.5) * w / 12.0
			for z: float in [d * 0.5 + 0.52, -d * 0.5 - 0.52]:
				kit.box(Vector3(x, 5.4, z), Vector3(w / 12.0, 1.0, 0.06), RED if i % 2 == 0 else WHITE)
		for i in 8:
			var z := -d * 0.5 + (i + 0.5) * d / 8.0
			for x: float in [w * 0.5 + 0.52, -w * 0.5 - 0.52]:
				kit.box(Vector3(x, 5.4, z), Vector3(0.06, 1.0, d / 8.0), RED if i % 2 == 0 else WHITE)
		kit.use("lacquer", METAL)
		kit.box(Vector3(0, 4.92, d * 0.5 + 0.56), Vector3(w + 1.0, 0.06, 0.03), GOLD)
		kit.box(Vector3(0, 4.92, -d * 0.5 - 0.56), Vector3(w + 1.0, 0.06, 0.03), GOLD)
		kit.use("solid")
		kit.box(Vector3(0, 4.58, 0), Vector3(w - 0.6, 0.04, d - 0.6), Color("2a2a30"))
		kit.use("lacquer", METAL)
		for i in 14:
			kit.box(Vector3(-w * 0.5 + 1.0 + i * 2.0, 4.55, 0), Vector3(0.04, 0.03, d - 1.0), STEEL)
		# A sign board on the front with a lightning bolt.
		kit.use("lacquer")
		kit.box(Vector3(0, 6.45, d * 0.5 + 0.3), Vector3(10.0, 1.3, 0.2), Color("1f2a44"))
		_frame(kit, Vector3(0, 6.45, d * 0.5 + 0.41), Vector2(10.0, 1.3), 0.07)
		kit.use("lacquer")
		for s: float in [-1.0, 1.0]:
			var c := Vector3(s * 4.3, 6.45, d * 0.5 + 0.42)
			kit.tri(c + Vector3(0.1, 0.5, 0), c + Vector3(-0.25, -0.05, 0), c + Vector3(0.05, -0.05, 0), YELLOW)
			kit.tri(c + Vector3(-0.05, 0.05, 0), c + Vector3(-0.1, -0.5, 0), c + Vector3(0.25, 0.05, 0), YELLOW)
		kit.use("bulbs")
		for i in 56:
			var x := -w * 0.5 + 0.5 + i * (w - 1.0) / 55.0
			kit.sphere(Vector3(x, 5.95, d * 0.5 + 0.58), Vector3(0.08, 0.08, 0.08), BULB if i % 4 else Color("ff9ab0"), 2, 5)
			kit.sphere(Vector3(x, 5.95, -d * 0.5 - 0.58), Vector3(0.08, 0.08, 0.08), BULB if i % 4 else Color("ff9ab0"), 2, 5)
		for i in 26:
			kit.sphere(Vector3(-4.9 + i * 0.392, 7.13, d * 0.5 + 0.42), Vector3(0.06, 0.06, 0.05), [Color("4ff3ff"), BULB][i % 2], 2, 5)
			kit.sphere(Vector3(-4.9 + i * 0.392, 5.77, d * 0.5 + 0.42), Vector3(0.06, 0.06, 0.05), [BULB, Color("4ff3ff")][i % 2], 2, 5)
		return kit.commit())


## A bumper car with its pole (front +Z).
static func scooter(col: Color) -> Mesh:
	return cached("scooter_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("lacquer")   # one surface: there are many of these
		kit.cylinder(Vector3(0, 0.05, 0), 0.25, 1.05, 1.05, 16, Color("1e1e22"))
		kit.box(Vector3(0, 0.45, 0), Vector3(1.4, 0.4, 2.0), col)
		kit.box(Vector3(0, 0.7, 0.55), Vector3(1.3, 0.25, 0.7), col.lightened(0.15))
		kit.box(Vector3(0, 0.75, -0.35), Vector3(1.0, 0.1, 0.6), DARK)
		kit.box(Vector3(0, 1.0, -0.7), Vector3(1.0, 0.5, 0.12), col.darkened(0.2))
		kit.rod(Vector3(0, 0.9, 0.25), Vector3(0, 1.05, 0.0), 0.04, 0.04, 4, DARK)
		kit.cylinder(Vector3(0, 1.05, 0.0), 0.04, 0.2, 0.2, 8, DARK)
		kit.box(Vector3(0, 0.66, 0), Vector3(1.42, 0.04, 2.02), GOLD)
		kit.cylinder(Vector3(0, 1.0, -0.85), 3.25, 0.03, 0.03, 4, STEEL, false)
		for x: float in [-0.4, 0.4]:
			kit.sphere(Vector3(x, 0.55, 1.01), Vector3(0.09, 0.07, 0.03), Color("fff2b0"), 2, 6)
		return kit.commit())


## The arcade hall: three walls and a roof, open to the front (+Z) with a neon sign, rows of
## cabinets inside. Footprint 24 × 16.
static func arcade_hall() -> Mesh:
	return cached("arcade_hall", func() -> Mesh:
		var kit := MeshKit.new()
		var w := 24.0
		var d := 16.0
		var wall := Color("4a3a7a")
		kit.use("solid")
		kit.box(Vector3(0, 0.08, 0), Vector3(w, 0.16, d), Color("3a3048"), Color("4a3a5a"))
		# A checkered floor.
		for i in 12:
			for j in 8:
				if (i + j) % 2 == 0:
					kit.box(Vector3(-w * 0.5 + 1.0 + i * 2.0, 0.165, -d * 0.5 + 1.0 + j * 2.0), Vector3(2.0, 0.01, 2.0), Color("5a4a70"))
		kit.use("boards")
		kit.box(Vector3(0, 2.6, -d * 0.5 + 0.2), Vector3(w, 5.2, 0.4), wall)
		kit.box(Vector3(-w * 0.5 + 0.2, 2.6, 0), Vector3(0.4, 5.2, d), wall)
		kit.box(Vector3(w * 0.5 - 0.2, 2.6, 0), Vector3(0.4, 5.2, d), wall)
		kit.box(Vector3(0, 5.4, 0), Vector3(w + 0.6, 0.4, d + 0.6), Color("1f2a44"))
		kit.use("lacquer")
		for x: float in [-w * 0.5 + 0.2, -w / 6.0, w / 6.0, w * 0.5 - 0.2]:
			kit.beam(Vector3(x, 0.16, d * 0.5 - 0.3), Vector3(x, 5.2, d * 0.5 - 0.3), Vector2(0.4, 0.4), Color("1f2a44"))
			kit.box(Vector3(x, 0.4, d * 0.5 - 0.3), Vector3(0.5, 0.5, 0.5), Color("ff4fd8").darkened(0.4))
		# Light panels under the roof and posters on the walls inside.
		kit.use("bulbs", STEADY)
		for i in 4:
			for j in 3:
				kit.box(Vector3(-7.5 + i * 5.0, 5.17, -5.0 + j * 4.5), Vector3(3.2, 0.04, 0.5), Color("e8f4ff"))
		kit.use("lacquer")
		for k in 6:
			var side := -1.0 if k < 3 else 1.0
			var col: Color = [Color("ff4fd8"), Color("4ff3ff"), Color("fff04f")][k % 3]
			kit.push(Transform3D(Basis(Vector3.UP, -side * PI / 2), Vector3(side * (w * 0.5 - 0.41), 3.2, -4.0 + (k % 3) * 4.0)))
			kit.use("lacquer")
			kit.box(Vector3.ZERO, Vector3(1.0, 1.4, 0.02), col.darkened(0.25))
			_frame(kit, Vector3(0, 0, 0.015), Vector2(1.0, 1.4), 0.04)
			kit.use("lacquer")
			_star(kit, Vector3(0, 0.1, 0.03), 0.32, 0.14, WHITE)
			kit.box(Vector3(0, -0.45, 0.03), Vector3(0.7, 0.08, 0.01), WHITE)
			kit.pop()
		# Neon stripes along the side walls outside.
		kit.use("glow")
		for sx: float in [-1.0, 1.0]:
			for k in 3:
				kit.box(Vector3(sx * (w * 0.5 + 0.01), 1.6 + k * 1.2, 0), Vector3(0.03, 0.08, d - 1.0), [Color("ff4fd8"), Color("4ff3ff"), Color("fff04f")][k])
		kit.use("lacquer")
		kit.box(Vector3(0, 6.3, d * 0.5 + 0.1), Vector3(14.0, 1.6, 0.3), Color("2a1a44"))
		_frame(kit, Vector3(0, 6.3, d * 0.5 + 0.26), Vector2(14.0, 1.6), 0.08)
		kit.use("lacquer")
		for s: float in [-1.0, 1.0]:
			_star(kit, Vector3(s * 5.6, 6.3, d * 0.5 + 0.27), 0.5, 0.22, Color("fff04f"))
		# Cabinets along the back and in a row in the middle.
		var cols := [RED, BLUE, GREEN, PURPLE, ORANGE, TEAL]
		for i in 7:
			var x := -9.0 + i * 3.0
			_cabinet(kit, Vector3(x, 0.16, -d * 0.5 + 1.0), 0.0, cols[i % cols.size()])
		for i in 4:
			var x := -6.0 + i * 4.0
			_cabinet(kit, Vector3(x, 0.16, 0.0), PI, cols[(i + 3) % cols.size()])
		kit.use("bulbs")
		for i in 47:
			kit.sphere(Vector3(-6.9 + i * 0.3, 7.15, d * 0.5 + 0.28), Vector3(0.06, 0.06, 0.05), [Color("ff4fd8"), Color("4ff3ff"), Color("fff04f")][i % 3], 2, 5)
			kit.sphere(Vector3(-6.9 + i * 0.3, 5.45, d * 0.5 + 0.28), Vector3(0.06, 0.06, 0.05), [Color("4ff3ff"), Color("fff04f"), Color("ff4fd8")][i % 3], 2, 5)
		for k in 5:
			for sx: float in [-1.0, 1.0]:
				kit.sphere(Vector3(sx * 7.0, 5.55 + k * 0.38, d * 0.5 + 0.28), Vector3(0.06, 0.06, 0.05), Color("ff4fd8"), 2, 5)
		return kit.commit())


static func _cabinet(kit: MeshKit, p: Vector3, yaw: float, col: Color) -> void:
	kit.push(Transform3D(Basis(Vector3.UP, yaw), p))
	kit.use("lacquer")
	kit.box(Vector3(0, 0.9, 0), Vector3(0.9, 1.8, 0.8), col.darkened(0.3))
	kit.box(Vector3(0, 1.0, 0.5), Vector3(0.9, 0.12, 0.35), DARK)
	kit.box(Vector3(0, 1.95, 0.05), Vector3(0.95, 0.3, 0.85), col)
	for x: float in [-0.46, 0.46]:
		kit.box(Vector3(x, 0.9, 0.0), Vector3(0.02, 1.7, 0.7), col.lightened(0.2))
	kit.use("solid")
	kit.box(Vector3(-0.2, 1.07, 0.55), Vector3(0.03, 0.08, 0.03), DARK)
	kit.sphere(Vector3(-0.2, 1.13, 0.55), Vector3(0.05, 0.05, 0.05), RED, 2, 5)
	for k in 2:
		kit.cylinder(Vector3(0.1 + k * 0.15, 1.06, 0.55), 0.02, 0.04, 0.04, 6, [YELLOW, BLUE][k])
	kit.use("glow")
	kit.box(Vector3(0, 1.45, 0.41), Vector3(0.65, 0.5, 0.02), Color("9fe8ff"))
	kit.box(Vector3(0, 1.95, 0.48), Vector3(0.8, 0.2, 0.02), col.lightened(0.3))
	kit.use("solid")
	kit.pop()


# --- Booths and food stands ---------------------------------------------------------------

## A booth (5 m wide, front +Z): a painted wooden stall (`_stall`) and a big topper on the roof
## that shows from afar what the booth is about. The sign text is added separately.
static func booth(kind: String, col: Color) -> Mesh:
	return cached("booth_%s_%s" % [kind, col.to_html()], func() -> Mesh:
		var kit := MeshKit.new()
		_stall(kit, 5.0, 3.0, col, kind in FOOD)
		_topper(kit, kind, Vector3(0, 4.05, -0.45), col)
		return kit.commit())


## A Kirmes stall `w` wide and `d` deep, origin on the ground in its middle, front +Z: plank
## floor, board walls, a counter with framed panels and a plank top (its top at COUNTER_TOP),
## barber-pole posts, a curved striped awning with a scalloped valance that flutters, the sign
## board (field at SIGN_Y, its face at d/2 + SIGN_FACE) with a crest, gold frames and bulbs,
## pennants on the back corners and a painted emblem (or, for food, a price board) outside on
## both side walls.
static func _stall(kit: MeshKit, w: float, d: float, col: Color, food: bool) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var accent: Color = YELLOW if col != YELLOW else RED
	var cream := Color("f6ead0")
	kit.use("boards")
	kit.box(Vector3(0, 0.06, 0), Vector3(w, 0.12, d), Color("8a6a4a"))
	kit.box(Vector3(0, COUNTER_TOP - 0.03, hd - 0.07), Vector3(w + 0.1, 0.06, 0.5), Color("c09060"))
	kit.use("boards")
	kit.box(Vector3(0, 1.45, -hd + 0.06), Vector3(w, 2.9, 0.12), col.darkened(0.12))
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(s * (hw - 0.06), 1.45, 0), Vector3(0.12, 2.9, d), col.darkened(0.22))
	kit.box(Vector3(0, 0.56, hd - 0.11), Vector3(w - 0.24, 0.92, 0.22), col)
	kit.box(Vector3(0, 2.95, 0), Vector3(w + 0.2, 0.1, d + 0.2), col.darkened(0.4))
	# Counter front: framed panels with a diamond each.
	var panels := 3 if w > 4.5 else 2
	var pw := (w - 0.6) / panels
	for k in panels:
		var x := -hw + 0.3 + (k + 0.5) * pw
		kit.use("lacquer")
		kit.box(Vector3(x, 0.58, hd + 0.01), Vector3(pw - 0.22, 0.5, 0.02), col.lightened(0.35))
		_frame(kit, Vector3(x, 0.58, hd + 0.025), Vector2(pw - 0.18, 0.54), 0.035)
		kit.use("lacquer")
		var dz := hd + 0.03
		kit.quad(Vector3(x, 0.44, dz), Vector3(x + 0.16, 0.58, dz), Vector3(x, 0.72, dz), Vector3(x - 0.16, 0.58, dz), accent)
	kit.use("lacquer", METAL)
	kit.box(Vector3(0, COUNTER_TOP - 0.05, hd + 0.18), Vector3(w + 0.1, 0.03, 0.02), GOLD)
	# Inside: a framed panel on the back wall and a light tube under the roof.
	kit.use("lacquer")
	kit.box(Vector3(0, 1.85, -hd + 0.13), Vector3(w - 0.7, 1.4, 0.02), col.lightened(0.55))
	_frame(kit, Vector3(0, 1.85, -hd + 0.15), Vector2(w - 0.66, 1.44), 0.04)
	kit.use("bulbs", STEADY)
	kit.box(Vector3(0, 2.86, 0.3), Vector3(w - 1.2, 0.05, 0.07), Color("fff4d8"))
	# Barber-pole posts at the front corners.
	kit.use("lacquer")
	for s: float in [-1.0, 1.0]:
		var base := Vector3(s * (hw - 0.09), 0.12, hd - 0.08)
		for k in 10:
			kit.cylinder(base + Vector3(0, k * 0.278, 0), 0.278, 0.085, 0.085, 8, WHITE if k % 2 == 0 else col, false)
	# Outside on the side walls: an emblem or the price board.
	for s: float in [-1.0, 1.0]:
		kit.push(Transform3D(Basis(Vector3.UP, s * PI / 2), Vector3(s * (hw + 0.005), 0, -0.1)))
		kit.use("lacquer")
		kit.box(Vector3(0, 1.6, 0.01), Vector3(d - 0.8, 1.5, 0.02), cream)
		_frame(kit, Vector3(0, 1.6, 0.025), Vector2(d - 0.76, 1.54), 0.04)
		if food:
			kit.use("lacquer")
			kit.box(Vector3(0, 1.6, 0.03), Vector3(d - 1.2, 1.1, 0.02), Color("23302a"))
			for k in 4:
				kit.box(Vector3(-0.25, 1.92 - k * 0.22, 0.045), Vector3(0.7 - (k % 2) * 0.2, 0.04, 0.01), WHITE)
				kit.box(Vector3(0.55, 1.92 - k * 0.22, 0.045), Vector3(0.22, 0.04, 0.01), YELLOW)
		else:
			kit.use("lacquer")
			_star(kit, Vector3(0, 1.6, 0.04), 0.55, 0.24, accent)
			_star(kit, Vector3(0, 1.6, 0.045), 0.3, 0.13, col)
		kit.pop()
	_awning(kit, w, hd, col)
	_sign_board(kit, w, hd, col, accent)
	# Pennants on poles at the back corners.
	for s: float in [-1.0, 1.0]:
		var p := Vector3(s * (hw - 0.1), 3.0, -hd + 0.1)
		kit.use("lacquer", METAL)
		kit.rod(p, p + Vector3(0, 1.4, 0), 0.03, 0.025, 5, STEEL)
		kit.use("lacquer", METAL)
		kit.sphere(p + Vector3(0, 1.44, 0), Vector3(0.06, 0.06, 0.06), GOLD, 2, 5)
		kit.use("canvas")
		var fixed := Color(accent, 1.0)
		var free := Color(accent, 0.0)
		var a := p + Vector3(0, 1.35, 0)
		var b := p + Vector3(0, 0.95, 0)
		var tip := p + Vector3(s * 0.75, 1.15, 0)
		if s > 0:
			kit.tri_c(a, b, tip, fixed, fixed, free)
			kit.tri_c(a, tip, b, fixed, free, fixed)
		else:
			kit.tri_c(a, tip, b, fixed, free, fixed)
			kit.tri_c(a, b, tip, fixed, fixed, free)


## The striped awning over the counter: curved, white and `col`, a scalloped valance at the
## front; the free edge flutters (canvas alpha).
static func _awning(kit: MeshKit, w: float, hd: float, col: Color) -> void:
	var hw := w * 0.5
	var prof := [Vector2(hd, 2.84), Vector2(hd + 0.35, 2.74), Vector2(hd + 0.7, 2.58), Vector2(hd + 1.05, 2.36)]
	var alpha := [1.0, 0.85, 0.7, 0.55]
	var stripes := int(round(w / 0.5))
	var sw := w / stripes
	kit.use("canvas")
	for i in stripes:
		var x0 := -hw + i * sw
		var x1 := x0 + sw
		var c: Color = WHITE if i % 2 == 0 else col
		var under := c.darkened(0.25)
		for j in 3:
			var a: Vector2 = prof[j]
			var b: Vector2 = prof[j + 1]
			var ca := Color(c, alpha[j])
			var cb := Color(c, alpha[j + 1])
			kit.quad_c(Vector3(x0, a.y, a.x), Vector3(x0, b.y, b.x), Vector3(x1, b.y, b.x), Vector3(x1, a.y, a.x), ca, cb, cb, ca)
			var ua := Color(under, alpha[j])
			var ub := Color(under, alpha[j + 1])
			kit.quad_c(Vector3(x0, a.y - 0.01, a.x), Vector3(x1, a.y - 0.01, a.x), Vector3(x1, b.y - 0.01, b.x), Vector3(x0, b.y - 0.01, b.x),
				ua, ua, ub, ub)
		# Scallop: a half disc hanging from the front edge.
		var front: Vector2 = prof[3]
		var mid := Vector3((x0 + x1) * 0.5, front.y, front.x)
		var n := 6
		for k in n:
			var t0 := PI * k / n
			var t1 := PI * (k + 1) / n
			var p0 := mid + Vector3(cos(t0) * sw * 0.5, -sin(t0) * 0.22, 0)
			var p1 := mid + Vector3(cos(t1) * sw * 0.5, -sin(t1) * 0.22, 0)
			var cm := Color(c, alpha[3])
			var c0 := Color(c, alpha[3] * (1.0 - sin(t0)))
			var c1 := Color(c, alpha[3] * (1.0 - sin(t1)))
			kit.tri_c(mid, p1, p0, cm, c1, c0)
			kit.tri_c(mid + Vector3(0, 0, -0.005), p0 + Vector3(0, 0, -0.005), p1 + Vector3(0, 0, -0.005),
				Color(under, cm.a), Color(under, c0.a), Color(under, c1.a))
	# Struts from the posts and a row of bulbs under the front edge.
	var front: Vector2 = prof[3]
	kit.use("lacquer", METAL)
	for s: float in [-1.0, 1.0]:
		kit.rod(Vector3(s * (hw - 0.09), 2.84, hd - 0.08), Vector3(s * (hw - 0.09), front.y - 0.03, front.x - 0.08), 0.022, 0.022, 5, STEEL)
	kit.rod(Vector3(-hw + 0.09, front.y - 0.04, front.x - 0.08), Vector3(hw - 0.09, front.y - 0.04, front.x - 0.08), 0.02, 0.02, 5, STEEL)
	kit.use("bulbs")
	for i in stripes:
		var x := -hw + (i + 0.5) * sw
		kit.sphere(Vector3(x, front.y - 0.12, front.x - 0.08), Vector3(0.055, 0.07, 0.055), [BULB, Color("ffb0c0"), BULB, Color("b0e0ff")][i % 4], 2, 5)


## The sign board above the awning: a dark lacquered board with an arched crest, a light field
## (the label goes in front of it), gold frames, scrolls at the ends and bulbs all round.
static func _sign_board(kit: MeshKit, w: float, hd: float, col: Color, accent: Color) -> void:
	var board := col.darkened(0.45)
	var z := hd + 0.02
	kit.use("lacquer")
	kit.box(Vector3(0, SIGN_Y, z), Vector3(w + 0.3, 1.0, 0.1), board)
	# Crest: half an ellipse on top, front and back, with a smaller field and a star.
	var top := SIGN_Y + 0.5
	var rx := minf(1.2, w * 0.26)
	var n := 12
	for k in n:
		var t0 := PI * k / n
		var t1 := PI * (k + 1) / n
		var p0 := Vector3(cos(t0) * rx, top + sin(t0) * 0.45, 0)
		var p1 := Vector3(cos(t1) * rx, top + sin(t1) * 0.45, 0)
		var c := Vector3(0, top, 0)
		kit.use("lacquer")
		kit.tri(c + Vector3(0, 0, z + 0.05), p0 + Vector3(0, 0, z + 0.05), p1 + Vector3(0, 0, z + 0.05), board)
		kit.tri(c + Vector3(0, 0, z - 0.05), p1 + Vector3(0, 0, z - 0.05), p0 + Vector3(0, 0, z - 0.05), board)
		kit.quad(p0 + Vector3(0, 0, z + 0.05), p0 + Vector3(0, 0, z - 0.05), p1 + Vector3(0, 0, z - 0.05), p1 + Vector3(0, 0, z + 0.05), board)
		var q0 := Vector3(cos(t0) * (rx - 0.18), top + sin(t0) * 0.32, z + 0.06)
		var q1 := Vector3(cos(t1) * (rx - 0.18), top + sin(t1) * 0.32, z + 0.06)
		kit.tri(Vector3(0, top, z + 0.06), q0, q1, accent)
		kit.use("lacquer", METAL)
		kit.beam(p0 + Vector3(0, 0, z + 0.06), p1 + Vector3(0, 0, z + 0.06), Vector2(0.04, 0.03), GOLD)
	kit.use("lacquer", METAL)
	_star(kit, Vector3(0, top + 0.17, z + 0.07), 0.14, 0.06, GOLD)
	# Field and frame.
	kit.use("lacquer")
	kit.box(Vector3(0, SIGN_Y, z + 0.06), Vector3(w - 0.2, 0.7, 0.02), accent.lightened(0.15))
	_frame(kit, Vector3(0, SIGN_Y, z + 0.075), Vector2(w - 0.16, 0.74), 0.045)
	for s: float in [-1.0, 1.0]:
		kit.sphere(Vector3(s * (w * 0.5 + 0.18), SIGN_Y, z), Vector3(0.13, 0.13, 0.08), GOLD, 3, 6)
	kit.use("bulbs")
	var count := int(w / 0.34)
	for i in count + 1:
		var x := -w * 0.5 + i * w / count
		kit.sphere(Vector3(x, SIGN_Y - 0.44, z + 0.07), Vector3(0.045, 0.045, 0.04), BULB, 2, 5)
		if absf(x) > rx + 0.05:
			kit.sphere(Vector3(x, SIGN_Y + 0.44, z + 0.07), Vector3(0.045, 0.045, 0.04), BULB, 2, 5)
	for k in 9:
		var t := PI * (k + 0.5) / 9
		kit.sphere(Vector3(cos(t) * (rx - 0.09), top + sin(t) * 0.38, z + 0.08), Vector3(0.04, 0.04, 0.035), Color("ffc0d0") if k % 2 else BULB, 2, 5)


## A thin gold frame (border width `t`) round a rectangle of `size` facing +Z at `center`.
static func _frame(kit: MeshKit, center: Vector3, size: Vector2, t: float) -> void:
	kit.use("lacquer", METAL)
	var h := size * 0.5
	kit.box(center + Vector3(0, h.y - t * 0.5, 0), Vector3(size.x, t, 0.02), GOLD)
	kit.box(center + Vector3(0, -h.y + t * 0.5, 0), Vector3(size.x, t, 0.02), GOLD)
	kit.box(center + Vector3(h.x - t * 0.5, 0, 0), Vector3(t, size.y - 2.0 * t, 0.02), GOLD)
	kit.box(center + Vector3(-h.x + t * 0.5, 0, 0), Vector3(t, size.y - 2.0 * t, 0.02), GOLD)


## A five-pointed star in the x-y plane facing +Z (in the active surface).
static func _star(kit: MeshKit, center: Vector3, r_out: float, r_in: float, col: Color) -> void:
	for k in 10:
		var a0 := PI / 2 + TAU * k / 10
		var a1 := PI / 2 + TAU * (k + 1) / 10
		var r0 := r_out if k % 2 == 0 else r_in
		var r1 := r_out if k % 2 == 1 else r_in
		kit.tri(center, center + Vector3(cos(a0) * r0, sin(a0) * r0, 0), center + Vector3(cos(a1) * r1, sin(a1) * r1, 0), col)


## The big thing on a booth's roof that tells from afar what it is about: a plinth at `b`, held
## above the sign's crest by two struts from the roof (at 3.0).
static func _topper(kit: MeshKit, kind: String, b: Vector3, col: Color) -> void:
	kit.use("lacquer", METAL)
	for s: float in [-1.0, 1.0]:
		kit.beam(Vector3(s * 0.28, 3.0, b.z), b + Vector3(s * 0.22, 0, 0), Vector2(0.06, 0.06), STEEL)
	kit.beam(Vector3(-0.27, 3.5, b.z), Vector3(0.27, 3.5, b.z), Vector2(0.04, 0.04), STEEL)
	kit.use("lacquer")
	kit.box(b + Vector3(0, 0.06, 0), Vector3(0.8, 0.12, 0.6), col.darkened(0.4))
	var y := b + Vector3(0, 0.12, 0)
	match kind:
		"cans":
			for k in 3:
				var p: Vector3 = y + [Vector3(-0.22, 0, 0), Vector3(0.22, 0, 0), Vector3(0, 0.46, 0)][k]
				kit.use("lacquer")
				kit.cylinder(p, 0.44, 0.2, 0.2, 10, [RED, BLUE, RED][k])
				kit.use("lacquer", METAL)
				kit.cylinder(p + Vector3(0, 0.15, 0), 0.14, 0.205, 0.205, 10, STEEL, false)
				kit.cylinder(p + Vector3(0, 0.42, 0), 0.02, 0.19, 0.19, 10, STEEL)
		"ducks":
			kit.sphere(y + Vector3(0, 0.38, 0), Vector3(0.42, 0.34, 0.55), YELLOW, 4, 9)
			kit.sphere(y + Vector3(0, 0.88, 0.3), Vector3(0.26, 0.26, 0.26), YELLOW, 4, 8)
			kit.sphere(y + Vector3(0, 0.55, -0.48), Vector3(0.16, 0.2, 0.12), YELLOW, 3, 6)
			kit.box(y + Vector3(0, 0.84, 0.58), Vector3(0.2, 0.07, 0.16), ORANGE)
			for s: float in [-1.0, 1.0]:
				kit.sphere(y + Vector3(s * 0.12, 0.96, 0.52), Vector3(0.05, 0.06, 0.03), DARK, 2, 5)
				kit.sphere(y + Vector3(s * 0.4, 0.42, -0.05), Vector3(0.06, 0.18, 0.3), YELLOW.darkened(0.1), 3, 6)
		"rings":
			kit.cylinder(y, 0.5, 0.2, 0.2, 10, Color("4cc47a"))
			kit.cylinder(y + Vector3(0, 0.5, 0), 0.16, 0.2, 0.07, 10, Color("4cc47a"))
			kit.cylinder(y + Vector3(0, 0.66, 0), 0.32, 0.07, 0.07, 8, Color("4cc47a"))
			kit.cylinder(y + Vector3(0, 0.98, 0), 0.05, 0.085, 0.085, 8, WHITE)
			kit.push(Transform3D(Basis(Vector3.RIGHT, 0.35), y + Vector3(0, 0.62, 0)))
			kit.torus(Vector3.ZERO, 0.3, 0.06, 14, 5, RED)
			kit.pop()
		"darts":
			var balloons := [[Vector3(-0.32, 1.15, 0.0), RED], [Vector3(0.3, 1.3, 0.05), BLUE], [Vector3(0.0, 1.62, -0.05), YELLOW],
				[Vector3(0.05, 1.05, 0.15), PINK]]
			for bl: Array in balloons:
				kit.use("lacquer")
				kit.beam(y, y + (bl[0] as Vector3) - Vector3(0, 0.3, 0), Vector2(0.012, 0.012), WHITE)
				kit.use("lacquer")
				kit.sphere(y + bl[0], Vector3(0.24, 0.3, 0.24), bl[1], 4, 8)
				kit.cylinder(y + (bl[0] as Vector3) - Vector3(0, 0.34, 0), 0.06, 0.02, 0.05, 5, bl[1])
		"moles":
			kit.use("lacquer")
			kit.sphere(y + Vector3(0, 0.05, 0), Vector3(0.5, 0.25, 0.38), Color("7a5232"), 3, 8)
			kit.use("lacquer")
			kit.sphere(y + Vector3(0, 0.55, 0.05), Vector3(0.3, 0.42, 0.28), Color("9b6a44"), 4, 8)
			kit.sphere(y + Vector3(0, 0.6, 0.3), Vector3(0.11, 0.09, 0.1), PINK, 3, 6)
			for s: float in [-1.0, 1.0]:
				kit.sphere(y + Vector3(s * 0.12, 0.76, 0.25), Vector3(0.05, 0.06, 0.03), DARK, 2, 5)
				kit.sphere(y + Vector3(s * 0.22, 0.4, 0.25), Vector3(0.1, 0.06, 0.08), PINK, 2, 5)
			kit.push(Transform3D(Basis(Vector3.BACK, -0.5), y + Vector3(0.45, 0.3, 0.1)))
			kit.rod(Vector3.ZERO, Vector3(0, 0.75, 0), 0.03, 0.03, 5, Color("b98a57"))
			kit.box(Vector3(0, 0.8, 0), Vector3(0.36, 0.18, 0.18), RED)
			kit.pop()
		"wheel":
			kit.use("lacquer", METAL)
			for s: float in [-1.0, 1.0]:
				kit.beam(y + Vector3(s * 0.3, 0, 0), y + Vector3(0, 0.75, -0.06), Vector2(0.05, 0.05), STEEL)
			kit.use("lacquer")
			var c := y + Vector3(0, 0.75, 0)
			for k in 12:
				var a0 := TAU * k / 12
				var a1 := TAU * (k + 1) / 12
				kit.tri(c, c + Vector3(cos(a0), sin(a0), 0) * 0.62, c + Vector3(cos(a1), sin(a1), 0) * 0.62, COLORS[k % COLORS.size()])
				kit.tri(c - Vector3(0, 0, 0.02), c + Vector3(cos(a1), sin(a1), -0.02) * 0.62, c + Vector3(cos(a0), sin(a0), -0.02) * 0.62, WHITE)
			kit.use("lacquer", METAL)
			kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), c))
			kit.torus(Vector3.ZERO, 0.64, 0.035, 20, 4, GOLD)
			kit.cylinder(Vector3(0, -0.06, 0), 0.08, 0.09, 0.09, 8, GOLD)
			kit.pop()
		"lots":
			for k in 2:
				kit.push(Transform3D(Basis(Vector3.BACK, [-0.25, 0.2][k]), y + Vector3([-0.12, 0.15][k], 0.55, [0.0, -0.08][k])))
				kit.box(Vector3.ZERO, Vector3(1.0, 0.5, 0.05), [YELLOW, PINK][k])
				kit.box(Vector3(-0.3, 0, 0.03), Vector3(0.05, 0.5, 0.02), RED)
				_star(kit, Vector3(0.12, 0, 0.035), 0.16, 0.07, RED)
				kit.pop()
		"candy":
			kit.use("lacquer")
			kit.rod(y, y + Vector3(0, 0.75, 0), 0.035, 0.03, 5, WHITE)
			kit.use("canvas")
			kit.sphere(y + Vector3(0, 1.05, 0), Vector3(0.45, 0.4, 0.45), Color("ffb3d6"), 4, 9, 0.12, 5)
			kit.sphere(y + Vector3(0.12, 1.3, 0.05), Vector3(0.28, 0.25, 0.28), Color("ffc8e2"), 3, 7, 0.12, 9)
		"almonds":
			kit.use("canvas")
			kit.cylinder(y + Vector3(0, 0.05, 0), 0.75, 0.04, 0.34, 10, Color("efe2c4"), true, Color("8a5a2a"))
			kit.cylinder(y + Vector3(0, 0.35, 0), 0.12, 0.18, 0.23, 10, RED, false)
			kit.use("lacquer")
			for k in 7:
				var a := TAU * k / 7
				kit.sphere(y + Vector3(cos(a) * 0.17, 0.85 + (k % 2) * 0.05, sin(a) * 0.17), Vector3(0.09, 0.06, 0.12), Color("8a5a2a"), 2, 6)
			kit.sphere(y + Vector3(0, 0.92, 0), Vector3(0.1, 0.07, 0.13), Color("9a6a3a"), 2, 6)
		"sausage":
			kit.use("canvas")
			kit.sphere(y + Vector3(0, 0.35, 0), Vector3(0.62, 0.2, 0.26), Color("e0b070"), 3, 8)
			kit.use("lacquer")
			kit.rod(y + Vector3(-0.72, 0.5, 0), y + Vector3(0.72, 0.5, 0), 0.13, 0.13, 8, Color("a0522d"))
			for s: float in [-1.0, 1.0]:
				kit.sphere(y + Vector3(s * 0.72, 0.5, 0), Vector3(0.13, 0.13, 0.13), Color("a0522d"), 3, 6)
			kit.use("lacquer")
			for k in 6:
				kit.beam(y + Vector3(-0.55 + k * 0.2, 0.63, -0.05 + (k % 2) * 0.1), y + Vector3(-0.45 + k * 0.2, 0.63, 0.05 - (k % 2) * 0.1),
					Vector2(0.035, 0.03), YELLOW)
		"crepes":
			kit.push(Transform3D(Basis(Vector3.BACK, 0.3), y + Vector3(0, 0.1, 0)))
			kit.use("canvas")
			kit.cylinder(Vector3.ZERO, 0.8, 0.03, 0.36, 10, Color("e8c48a"), true, Color("5a3020"))
			kit.use("lacquer")
			kit.sphere(Vector3(0, 0.82, 0), Vector3(0.3, 0.1, 0.3), Color("5a3020"), 2, 8)
			kit.sphere(Vector3(0.1, 0.92, 0.05), Vector3(0.08, 0.1, 0.08), RED, 2, 6)
			kit.sphere(Vector3(-0.12, 0.9, -0.05), Vector3(0.08, 0.1, 0.08), RED, 2, 6)
			kit.pop()
		_:
			kit.use("lacquer", METAL)
			_star(kit, y + Vector3(0, 0.55, 0.05), 0.45, 0.2, GOLD)


## What lies in a booth (cans, ducks, bottles, balloons, moles, the wheel, lottery drums, food):
## its own mesh, so a booth game can hide it while it puts out its own things.
static func booth_deco(kind: String) -> Mesh:
	return cached("booth_deco_%s" % kind, func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("lacquer")
		match kind:
			"cans":
				kit.box(Vector3(0, 1.2, -0.9), Vector3(3.0, 0.08, 0.6), Color("b98a57"))
				for row in 3:
					for k in 3 - row:
						kit.cylinder(Vector3(-0.3 * (2 - row) + k * 0.6 - 0.0, 1.24 + row * 0.33, -0.9), 0.32, 0.13, 0.13, 8, [RED, STEEL, BLUE][(row + k) % 3])
				for k in 4:
					kit.sphere(Vector3(-1.6 + k * 0.25, 1.15, 1.3), Vector3(0.09, 0.09, 0.09), WHITE, 2, 5)
			"ducks":
				kit.box(Vector3(0, 0.75, -0.2), Vector3(3.8, 0.7, 1.8), Color("2e6fbf"))
				kit.use("water")
				kit.box(Vector3(0, 1.11, -0.2), Vector3(3.6, 0.02, 1.6), Color("3d8aa0"))
				kit.use("lacquer")
				for k in 8:
					var p := Vector3(-1.5 + (k % 4) * 1.0, 1.18, -0.7 + (k / 4) * 0.9)
					kit.sphere(p, Vector3(0.14, 0.11, 0.17), YELLOW, 2, 5)
					kit.sphere(p + Vector3(0, 0.13, 0.08), Vector3(0.08, 0.08, 0.08), YELLOW, 2, 5)
					kit.box(p + Vector3(0, 0.12, 0.17), Vector3(0.06, 0.03, 0.06), ORANGE)
				for k in 3:
					kit.beam(Vector3(1.8 + k * 0.1, 1.0, 1.1), Vector3(1.6 + k * 0.1, 2.2, 0.4), Vector2(0.03, 0.03), Color("b98a57"))
			"rings":
				# The same table and bottles RingToss puts out.
				_ring_table(kit)
				for k in 15:
					var row := k / 5
					_bottle(kit, Vector3(-1.4 + (k % 5) * 0.7, RingToss.TABLE_Y + row * 0.1, -0.2 - row * 0.45),
						RingToss.GLASS[(k + row) % RingToss.GLASS.size()])
				kit.use("lacquer")
				for k in 5:
					kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(-1.9 + k * 0.08, 1.25, 1.3)))
					kit.torus(Vector3.ZERO, 0.14, 0.025, 10, 3, [RED, YELLOW, BLUE][k % 3])
					kit.pop()
			"darts":
				for k in 24:
					var p := Vector3(-1.9 + (k % 8) * 0.55, 1.0 + (k / 8) * 0.55, -1.32)
					kit.sphere(p, Vector3(0.2, 0.24, 0.12), COLORS[k % COLORS.size()], 3, 6)
				for k in 3:
					kit.beam(Vector3(1.6 + k * 0.12, 1.08, 1.35), Vector3(1.6 + k * 0.12, 1.08, 1.6), Vector2(0.02, 0.02), RED)
			"moles":
				# The board of WhackAMole: two rows of three, the back row on a step.
				kit.box(Vector3(0, 0.62, 0.95), Vector3(2.6, 1.0, 0.6), Color("d9a441"), Color("8cc152"))
				kit.box(Vector3(0, 0.69, 0.35), Vector3(2.6, 1.14, 0.6), Color("d9a441"), Color("7fb347"))
				for k in 6:
					var back := k < 3
					var p := Vector3(-0.75 + (k % 3) * 0.75 + (0.2 if back else -0.2), 1.26 if back else 1.12, 0.35 if back else 0.95)
					kit.cylinder(p, 0.015, 0.2, 0.2, 10, DARK)
					if k == 1 or k == 3:
						kit.sphere(p + Vector3(0, 0.06, 0), Vector3(0.17, 0.16, 0.17), Color("a8754a"), 3, 6)
						kit.sphere(p + Vector3(0, 0.12, 0.17), Vector3(0.05, 0.04, 0.04), PINK, 2, 4)
				kit.rod(Vector3(1.9, 1.06, 1.2), Vector3(1.9, 1.06, 0.6), 0.03, 0.03, 4, Color("b98a57"))
				kit.cylinder(Vector3(1.75, 1.06, 0.5), 0.3, 0.12, 0.12, 8, RED)
			"wheel":
				kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1.8, -1.35)))
				for k in 12:
					var a0 := TAU * k / 12
					var a1 := TAU * (k + 1) / 12
					kit.tri(Vector3.ZERO, Vector3(cos(a1), 0, sin(a1)) * 1.0, Vector3(cos(a0), 0, sin(a0)) * 1.0, COLORS[k % COLORS.size()])
				kit.cylinder(Vector3(0, -0.04, 0), 0.08, 0.15, 0.15, 8, GOLD)
				kit.pop()
				kit.tri(Vector3(0, 2.75, -1.3), Vector3(-0.12, 2.95, -1.3), Vector3(0.12, 2.95, -1.3), RED)
			"lots":
				for k in 3:
					var p := Vector3(-1.2 + k * 1.2, 1.06, -0.4)
					kit.cylinder(p, 0.5, 0.35, 0.3, 8, [RED, YELLOW, BLUE][k])
					for t in 6:
						kit.box(p + Vector3(-0.15 + (t % 3) * 0.15, 0.55, -0.08 + (t / 3) * 0.16), Vector3(0.1, 0.05, 0.12), [WHITE, PINK, YELLOW][t % 3])
			# Food.
			"candy":
				kit.cylinder(Vector3(-1.0, 1.06, -0.2), 0.5, 0.45, 0.55, 10, STEEL)
				kit.sphere(Vector3(-1.0, 1.75, -0.2), Vector3(0.5, 0.35, 0.5), Color("ffc0dd"), 3, 7)
				for k in 5:
					var p := Vector3(0.2 + k * 0.4, 1.06, -0.9)
					kit.beam(p, p + Vector3(0, 0.6, 0), Vector2(0.02, 0.02), WHITE)
					kit.sphere(p + Vector3(0, 0.8, 0), Vector3(0.2, 0.24, 0.2), [Color("ffc0dd"), Color("bfe0ff"), Color("ffc0dd")][k % 3], 3, 6)
			"almonds":
				kit.cylinder(Vector3(-0.8, 1.06, -0.4), 0.45, 0.55, 0.35, 10, Color("b87333"))
				kit.sphere(Vector3(-0.8, 1.5, -0.4), Vector3(0.35, 0.12, 0.35), Color("8a5a2a"), 2, 7)
				for k in 6:
					kit.cylinder(Vector3(0.4 + (k % 3) * 0.45, 1.06, -0.8 + (k / 3) * 0.5), 0.35, 0.03, 0.14, 6, WHITE)
			"sausage":
				kit.box(Vector3(0, 1.1, -0.5), Vector3(2.6, 0.12, 1.0), DARK)
				for k in 7:
					kit.push(Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(-1.0 + k * 0.33, 1.2, -0.5)))
					kit.cylinder(Vector3(0, -0.35, 0), 0.7, 0.05, 0.05, 6, Color("a0522d"))
					kit.pop()
				for k in 3:
					kit.cylinder(Vector3(1.6, 1.06, -0.9 + k * 0.4), 0.2, 0.08, 0.08, 6, [Color("f2c230"), RED, Color("d8c8a8")][k])
			"crepes":
				for k in 2:
					kit.cylinder(Vector3(-0.7 + k * 1.4, 1.06, -0.5), 0.12, 0.45, 0.45, 12, DARK)
					kit.cylinder(Vector3(-0.7 + k * 1.4, 1.18, -0.5), 0.02, 0.4, 0.4, 12, Color("e8c48a"))
				kit.cylinder(Vector3(1.9, 1.06, -0.9), 0.3, 0.12, 0.12, 8, Color("6b3e26"))
		return kit.commit())


## Ringwurf's table: three rows, each a step higher towards the back (booth coordinates).
static func ring_table() -> Mesh:
	return cached("ring_table", func() -> Mesh:
		var kit := MeshKit.new()
		_ring_table(kit)
		return kit.commit())


static func _ring_table(kit: MeshKit) -> void:
	for row in 3:
		var top := RingToss.TABLE_Y + row * 0.1
		kit.use("boards")
		kit.box(Vector3(0, (top + 0.12) * 0.5, -0.2 - row * 0.45), Vector3(3.6, top - 0.12, 0.45), Color("b98a57"))
		kit.use("canvas")
		kit.box(Vector3(0, top - 0.005, -0.2 - row * 0.45), Vector3(3.62, 0.012, 0.46), Color("e8d8b0"))


## A glass bottle (origin at its foot) for Ringwurf.
static func bottle(col: Color) -> Mesh:
	return cached("bottle_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		_bottle(kit, Vector3.ZERO, col)
		return kit.commit())


static func _bottle(kit: MeshKit, p: Vector3, col: Color) -> void:
	kit.use("lacquer")
	kit.cylinder(p, 0.24, 0.075, 0.075, 8, col)
	kit.cylinder(p + Vector3(0, 0.24, 0), 0.07, 0.075, 0.03, 8, col)
	kit.cylinder(p + Vector3(0, 0.31, 0), 0.17, 0.025, 0.025, 6, col)
	kit.cylinder(p + Vector3(0, 0.08, 0), 0.1, 0.077, 0.077, 8, Color("f1eee6"), false)
	kit.cylinder(p + Vector3(0, 0.48, 0), 0.02, 0.032, 0.032, 6, GOLD)


## The high striker: a 6 m pole with a scale and a bell, the pad and the mallet.
static func high_striker() -> Mesh:
	return cached("high_striker", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("boards")
		kit.box(Vector3(0, 0.15, 0.6), Vector3(1.6, 0.3, 1.6), Color("8a5a34"))
		kit.use("lacquer")
		kit.cylinder(Vector3(0, 0.3, 0.9), 0.15, 0.3, 0.3, 12, RED)
		kit.box(Vector3(0, 3.2, 0), Vector3(0.4, 6.4, 0.25), WHITE)
		for k in 10:
			kit.box(Vector3(0, 0.8 + k * 0.55, 0.14), Vector3(0.36, 0.5, 0.03), COLORS[k % COLORS.size()])
		kit.box(Vector3(0.12, 0.6, 0.18), Vector3(0.2, 0.2, 0.1), RED)
		# Top board with a star and two side struts.
		kit.box(Vector3(0, 6.2, 0.0), Vector3(0.9, 0.5, 0.15), RED)
		_star(kit, Vector3(0, 6.2, 0.08), 0.2, 0.09, YELLOW)
		for s: float in [-1.0, 1.0]:
			kit.beam(Vector3(s * 0.7, 0.3, 0.0), Vector3(s * 0.2, 3.0, 0.0), Vector2(0.06, 0.06), WHITE)
		kit.use("lacquer", METAL)
		kit.beam(Vector3(0.12, 0.3, 0.15), Vector3(0.12, 6.0, 0.15), Vector2(0.03, 0.03), STEEL)
		kit.cylinder(Vector3(0, 0.3, 0.9), 0.17, 0.12, 0.12, 8, STEEL)
		kit.use("lacquer", METAL)
		kit.sphere(Vector3(0, 6.75, 0.0), Vector3(0.35, 0.3, 0.35), GOLD, 3, 10)
		kit.cylinder(Vector3(0, 6.45, 0.0), 0.05, 0.12, 0.12, 6, GOLD)
		kit.use("boards")
		kit.rod(Vector3(0.9, 0.3, 1.0), Vector3(0.9, 1.3, 1.1), 0.04, 0.04, 5, Color("b98a57"))
		kit.box(Vector3(0.9, 1.35, 1.1), Vector3(0.5, 0.25, 0.25), Color("6e4a2c"))
		kit.use("bulbs")
		for k in 16:
			kit.sphere(Vector3(-0.26, 0.9 + k * 0.34, 0.0), Vector3(0.05, 0.05, 0.05), BULB, 2, 5)
			kit.sphere(Vector3(0.26, 0.9 + k * 0.34, 0.0), Vector3(0.05, 0.05, 0.05), BULB, 2, 5)
		return kit.commit())


## The magician's little stage with a red curtain and stars (front +Z).
static func magic_stage() -> Mesh:
	return cached("magic_stage", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("boards")
		kit.box(Vector3(0, 0.4, 0), Vector3(7.0, 0.8, 4.0), Color("6e4a2c"))
		kit.use("boards")
		kit.box(Vector3(0, 0.79, 0), Vector3(7.05, 0.04, 4.05), Color("9a6a3e"))
		for st in 2:
			kit.box(Vector3(2.6, 0.13 + st * 0.27, 2.2 + (1 - st) * 0.3), Vector3(1.2, 0.27, 0.3), Color("9a6a3e"))
		kit.use("canvas")
		kit.box(Vector3(0, 2.6, -1.9), Vector3(7.0, 3.6, 0.15), Color("8e1f2b"))
		# Velvet back curtain in folds.
		for k in 22:
			kit.box(Vector3(-3.15 + k * 0.3, 2.6, -1.8 + (k % 2) * 0.05), Vector3(0.18, 3.6, 0.08), Color("a3243a") if k % 2 else Color("7e1a2b"))
		kit.use("lacquer")
		for x: float in [-3.4, 3.4]:
			kit.box(Vector3(x, 2.6, -0.2), Vector3(0.3, 3.6, 3.6), Color("2a1f3a"))
		kit.box(Vector3(0, 4.55, -0.2), Vector3(7.2, 0.5, 3.8), Color("2a1f3a"))
		kit.use("canvas")
		for x: float in [-2.6, 2.6]:
			for k in 5:
				kit.box(Vector3(x + (k - 2) * 0.16 * signf(x), 2.6, -1.0 + k * 0.05), Vector3(0.14, 3.4, 0.4), Color("b02a38"))
		# Scalloped pelmet.
		for k in 14:
			var x0 := -3.5 + k * 0.5
			kit.tri(Vector3(x0, 4.32, 1.68), Vector3(x0 + 0.25, 4.05, 1.68), Vector3(x0 + 0.5, 4.32, 1.68), Color("b02a38"))
		kit.use("lacquer")
		kit.box(Vector3(0, 4.55, 1.72), Vector3(7.2, 0.5, 0.06), Color("1a1430"))
		_frame(kit, Vector3(0, 4.55, 1.76), Vector2(7.2, 0.5), 0.05)
		kit.use("lacquer", METAL)
		for x: float in [-3.4, 3.4]:
			kit.box(Vector3(x, 2.6, 1.61), Vector3(0.34, 3.6, 0.02), GOLD)
			kit.sphere(Vector3(x, 1.9, 1.62), Vector3(0.09, 0.09, 0.04), GOLD, 2, 5)
		kit.use("glow")
		for x: float in [-3.25, -2.75, 2.75, 3.25]:
			kit.sphere(Vector3(x, 4.55, 1.8), Vector3(0.12, 0.12, 0.04), GOLD, 2, 5)
		for k in 7:
			kit.box(Vector3(-3.0 + k * 1.0, 0.82, 1.95), Vector3(0.12, 0.06, 0.06), BULB)
		kit.use("bulbs")
		for x: float in [-3.4, 3.4]:
			for k in 10:
				kit.sphere(Vector3(x, 1.0 + k * 0.33, 1.64), Vector3(0.05, 0.05, 0.04), BULB, 2, 5)
		return kit.commit())


## The fortune teller's round tent with stars; the flap is open towards +Z.
static func fortune_tent() -> Mesh:
	return cached("fortune_tent", func() -> Mesh:
		var kit := MeshKit.new()
		var col := Color("5b2a7a")
		var n := 12
		for i in n:
			var a0 := TAU * i / n + PI / 2 + TAU / n * 0.5
			var a1 := TAU * (i + 1) / n + PI / 2 + TAU / n * 0.5
			if i == 0 or i == n - 1:
				continue   # the open flap (front)
			var d0 := Vector3(cos(a0), 0, sin(a0)) * 3.0
			var d1 := Vector3(cos(a1), 0, sin(a1)) * 3.0
			var c: Color = col if i % 2 == 0 else col.lightened(0.15)
			kit.use("canvas")
			kit.quad(d0, d0 + Vector3(0, 2.2, 0), d1 + Vector3(0, 2.2, 0), d1, c)
			kit.quad(d1, d1 + Vector3(0, 2.2, 0), d0 + Vector3(0, 2.2, 0), d0, c.darkened(0.4))
		kit.lathe(PackedVector2Array([Vector2(3.3, 2.1), Vector2(0.0, 4.2)]), n, col.darkened(0.1), PI / 2 + TAU / n * 0.5)
		kit.lathe(PackedVector2Array([Vector2(0.0, 4.19), Vector2(3.29, 2.09)]), n, col.darkened(0.5), PI / 2 + TAU / n * 0.5)
		# Gold scallops round the roof's edge.
		for i in n:
			var a0 := TAU * i / n + PI / 2 + TAU / n * 0.5
			var a1 := TAU * (i + 1) / n + PI / 2 + TAU / n * 0.5
			var am := (a0 + a1) * 0.5
			var e0 := Vector3(cos(a0), 0, sin(a0)) * 3.3 + Vector3(0, 2.1, 0)
			var e1 := Vector3(cos(a1), 0, sin(a1)) * 3.3 + Vector3(0, 2.1, 0)
			var em := Vector3(cos(am), 0, sin(am)) * 3.3 + Vector3(0, 1.8, 0)
			kit.tri(e1, em, e0, GOLD.darkened(0.1))
			kit.tri(e0, em, e1, GOLD.darkened(0.4))
		kit.use("lacquer", METAL)
		kit.cylinder(Vector3(0, 4.1, 0), 0.6, 0.05, 0.03, 5, GOLD)
		kit.sphere(Vector3(0, 4.8, 0), Vector3(0.15, 0.15, 0.15), GOLD, 2, 5)
		kit.use("solid")
		# Table with a crystal ball, stools.
		kit.cylinder(Vector3(0, 0, -0.4), 0.75, 0.1, 0.1, 6, DARK)
		kit.cylinder(Vector3(0, 0.75, -0.4), 0.05, 0.7, 0.7, 12, Color("8e1f2b"))
		kit.use("glow")
		kit.sphere(Vector3(0, 1.0, -0.4), Vector3(0.2, 0.2, 0.2), Color("b8e0ff"), 3, 7)
		for i in 10:
			var a := TAU * i / 10
			kit.box(Vector3(cos(a) * 3.05, 1.6 + sin(i * 1.7) * 0.4, sin(a) * 3.05), Vector3(0.12, 0.12, 0.04), GOLD)
		return kit.commit())


## The prize counter: a stall (4 m wide, 2.4 deep, front +Z) with shelves full of tools, gems
## and jars and a gold star on the roof.
static func prize_counter() -> Mesh:
	return cached("prize_counter", func() -> Mesh:
		var kit := MeshKit.new()
		_stall(kit, 4.0, 2.4, Color("2e86de"), false)
		_topper(kit, "prizes", Vector3(0, 4.05, -0.3), Color("2e86de"))
		kit.use("boards")
		for y: float in [1.1, 1.7, 2.3]:
			kit.box(Vector3(0, y, -0.85), Vector3(3.4, 0.06, 0.4), Color("b98a57"))
		for k in 6:
			var x := -1.35 + k * 0.54
			kit.use("lacquer")
			kit.box(Vector3(x, 1.28, -0.85), Vector3(0.3, 0.3, 0.3), [Color("d9a35c"), STEEL, Color("6e4a2c")][k % 3])
			kit.use("lacquer")
			kit.sphere(Vector3(x, 1.85, -0.85), Vector3(0.14, 0.14, 0.14), [Color("7fd8ff"), Color("ff7fa8"), GREEN][k % 3], 2, 6)
			kit.cylinder(Vector3(x, 2.33, -0.85), 0.3, 0.1, 0.1, 8, Color("f2b630"))
			kit.cylinder(Vector3(x, 2.63, -0.85), 0.04, 0.105, 0.105, 8, WHITE)
		return kit.commit())


# --- Street furniture ---------------------------------------------------------------------

## A tall pole for string lights.
static func light_pole() -> Mesh:
	return cached("light_pole", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("lacquer")
		kit.cylinder(Vector3.ZERO, 0.3, 0.16, 0.12, 8, DARK)
		kit.cylinder(Vector3(0, 0.3, 0), 4.2, 0.06, 0.05, 8, DARK)
		kit.use("lacquer", METAL)
		kit.cylinder(Vector3(0, 0.3, 0), 0.05, 0.1, 0.08, 8, GOLD)
		kit.cylinder(Vector3(0, 4.35, 0), 0.08, 0.07, 0.09, 8, GOLD)
		kit.sphere(Vector3(0, 4.55, 0), Vector3(0.09, 0.09, 0.09), GOLD, 2, 6)
		return kit.commit())


## Bulbs hanging between poles: `spans` are pairs of points (top of the poles).
static func light_strings(spans: Array) -> Mesh:
	var kit := MeshKit.new()
	for span: Array in spans:
		var a: Vector3 = span[0]
		var b: Vector3 = span[1]
		var n := maxi(4, int(a.distance_to(b) / 0.7))
		var prev := a
		for i in range(1, n + 1):
			var t := float(i) / n
			var p := a.lerp(b, t) - Vector3(0, sin(PI * t) * 0.6, 0)
			kit.use("solid")
			kit.beam(prev, p, Vector2(0.015, 0.015), DARK)
			if i < n and i % 2 == 0:
				kit.use("bulbs")
				kit.sphere(p - Vector3(0, 0.08, 0), Vector3(0.07, 0.09, 0.07), [BULB, Color("ff9a9a"), Color("9affb0"), Color("9ad0ff")][(i / 2) % 4], 2, 5)
			elif i < n:
				# Bunting between the bulbs; the tips flutter.
				var along := (b - a).normalized() * 0.22
				var col: Color = COLORS[(i / 2 + span.size()) % COLORS.size()]
				var tip := Color(col, 0.0)
				kit.use("canvas")
				kit.tri_c(p - along, p + along, p - Vector3(0, 0.42, 0), col, col, tip)
				kit.tri_c(p + along, p - along, p - Vector3(0, 0.42, 0), col.darkened(0.2), col.darkened(0.2), Color(col.darkened(0.2), 0.0))
			prev = p
	return kit.commit()


## A rose arbour: a wooden pergola with roses climbing over it (origin under its middle).
static func rose_arbour() -> Mesh:
	return cached("rose_arbour", func() -> Mesh:
		var kit := MeshKit.new()
		var wood := Color("f1eee6")
		for x: float in [-1.5, 1.5]:
			for z: float in [-1.0, 1.0]:
				kit.beam(Vector3(x, 0, z), Vector3(x, 2.6, z), Vector2(0.12, 0.12), wood)
		for k in 7:
			var z := -1.2 + k * 0.4
			kit.beam(Vector3(-1.8, 2.65, z), Vector3(1.8, 2.65, z), Vector2(0.08, 0.1), wood)
		kit.beam(Vector3(-1.5, 2.55, -1.1), Vector3(-1.5, 2.55, 1.1), Vector2(0.1, 0.12), wood)
		kit.beam(Vector3(1.5, 2.55, -1.1), Vector3(1.5, 2.55, 1.1), Vector2(0.1, 0.12), wood)
		kit.use("foliage")
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for k in 26:
			var p := Vector3(rng.randf_range(-1.8, 1.8), 2.75 + rng.randf_range(-0.1, 0.15), rng.randf_range(-1.2, 1.2))
			if k < 10:
				var side := -1.5 if k % 2 == 0 else 1.5
				p = Vector3(side, rng.randf_range(0.4, 2.4), rng.randf_range(-1.0, 1.0))
			kit.sphere(p, Vector3(0.35, 0.28, 0.35), Color("3f7a3a"), 2, 5, 0.2, k)
		kit.use("solid")
		for k in 30:
			var p := Vector3(rng.randf_range(-1.9, 1.9), 2.8 + rng.randf_range(0.0, 0.2), rng.randf_range(-1.3, 1.3))
			if k < 12:
				var side := -1.62 if k % 2 == 0 else 1.62
				p = Vector3(side, rng.randf_range(0.5, 2.4), rng.randf_range(-1.0, 1.0))
			kit.sphere(p, Vector3(0.09, 0.08, 0.09), [Color("e84a6f"), Color("f7a8c8"), Color("f1eee6")][k % 3], 2, 4)
		return kit.commit())


## A signpost "Kirmes" with arrows (origin at the post).
static func fair_sign() -> Mesh:
	return cached("fair_sign", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 2.6, 0.08, 0.07, 6, PropModels.WOOD_DARK)
		kit.use("lacquer")
		kit.box(Vector3(0, 2.2, 0.0), Vector3(1.9, 0.5, 0.08), RED)
		kit.box(Vector3(0, 2.2, 0.0), Vector3(1.7, 0.36, 0.1), YELLOW)
		kit.tri(Vector3(-0.95, 2.45, 0.06), Vector3(-1.35, 2.2, 0.06), Vector3(-0.95, 1.95, 0.06), RED)
		kit.tri(Vector3(-0.95, 2.45, -0.06), Vector3(-0.95, 1.95, -0.06), Vector3(-1.35, 2.2, -0.06), RED)
		return kit.commit())


# --- Figures and secrets (FairStories) -----------------------------------------------------

## Gisbert, the fair ghost: a friendly sheet with eyes and little arms (origin at the floor).
static func ghost() -> Mesh:
	return cached("ghost", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("glow")
		var white := Color("e8f0ff")
		kit.sphere(Vector3(0, 1.55, 0), Vector3(0.42, 0.48, 0.38), white, 4, 8)
		kit.cylinder(Vector3(0, 0.3, 0), 1.25, 0.5, 0.4, 8, white, false)
		for i in 8:
			var a := TAU * i / 8
			kit.sphere(Vector3(cos(a) * 0.46, 0.3, sin(a) * 0.46), Vector3(0.12, 0.14, 0.12), white, 2, 5)
		kit.use("solid")
		kit.sphere(Vector3(-0.15, 1.62, 0.33), Vector3(0.07, 0.1, 0.04), DARK, 2, 5)
		kit.sphere(Vector3(0.15, 1.62, 0.33), Vector3(0.07, 0.1, 0.04), DARK, 2, 5)
		kit.sphere(Vector3(0, 1.42, 0.35), Vector3(0.08, 0.05, 0.03), DARK, 2, 5)
		kit.use("glow")
		kit.rod(Vector3(0.38, 1.2, 0), Vector3(0.65, 1.45, 0.15), 0.09, 0.06, 5, white)
		kit.rod(Vector3(-0.38, 1.2, 0), Vector3(-0.6, 0.95, 0.1), 0.09, 0.06, 5, white)
		return kit.commit())


## Hoppel, the magician's white rabbit (sitting, origin at the floor).
static func rabbit() -> Mesh:
	return cached("rabbit", func() -> Mesh:
		var kit := MeshKit.new()
		var white := Color("f4f2ee")
		kit.sphere(Vector3(0, 0.16, -0.04), Vector3(0.15, 0.15, 0.19), white, 3, 7)
		kit.sphere(Vector3(0, 0.3, 0.1), Vector3(0.1, 0.1, 0.1), white, 3, 6)
		for x: float in [-0.04, 0.04]:
			kit.rod(Vector3(x, 0.36, 0.08), Vector3(x * 2.0, 0.55, 0.04), 0.03, 0.02, 4, white)
		kit.sphere(Vector3(0, 0.3, 0.2), Vector3(0.02, 0.02, 0.02), PINK, 2, 4)
		kit.sphere(Vector3(-0.04, 0.33, 0.18), Vector3(0.015, 0.015, 0.01), DARK, 2, 4)
		kit.sphere(Vector3(0.04, 0.33, 0.18), Vector3(0.015, 0.015, 0.01), DARK, 2, 4)
		kit.sphere(Vector3(0, 0.14, -0.22), Vector3(0.05, 0.05, 0.05), white, 2, 4)
		return kit.commit())


## A brown teddy bear (sitting, origin at the floor).
static func teddy() -> Mesh:
	return cached("teddy", func() -> Mesh:
		var kit := MeshKit.new()
		var brown := Color("a0703a")
		kit.sphere(Vector3(0, 0.14, 0), Vector3(0.12, 0.14, 0.1), brown, 3, 7)
		kit.sphere(Vector3(0, 0.33, 0), Vector3(0.09, 0.09, 0.09), brown, 3, 7)
		for x: float in [-0.07, 0.07]:
			kit.sphere(Vector3(x, 0.41, 0), Vector3(0.035, 0.035, 0.025), brown.darkened(0.2), 2, 5)
			kit.sphere(Vector3(x * 1.3, 0.08, 0.08), Vector3(0.045, 0.04, 0.06), brown, 2, 5)
			kit.sphere(Vector3(x * 1.7, 0.18, 0.02), Vector3(0.035, 0.07, 0.035), brown, 2, 5)
		kit.sphere(Vector3(0, 0.31, 0.08), Vector3(0.035, 0.03, 0.03), Color("d9b48a"), 2, 5)
		kit.box(Vector3(0, 0.24, 0.07), Vector3(0.1, 0.03, 0.02), RED)
		return kit.commit())


## The golden rubber duck (origin at the floor).
static func golden_duck() -> Mesh:
	return cached("golden_duck", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("glow")
		var gold := Color("f0c040")
		kit.sphere(Vector3(0, 0.07, 0), Vector3(0.11, 0.08, 0.14), gold, 3, 6)
		kit.sphere(Vector3(0, 0.17, 0.07), Vector3(0.065, 0.065, 0.065), gold, 3, 6)
		kit.use("solid")
		kit.box(Vector3(0, 0.16, 0.14), Vector3(0.05, 0.02, 0.05), ORANGE)
		return kit.commit())


## A trail of carrot pieces (origin at the floor).
static func carrot() -> Mesh:
	return cached("carrot", func() -> Mesh:
		var kit := MeshKit.new()
		kit.push(Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0, 0.03, 0)))
		kit.cylinder(Vector3(0, -0.06, 0), 0.12, 0.025, 0.0, 5, ORANGE)
		kit.pop()
		kit.box(Vector3(-0.07, 0.04, 0), Vector3(0.03, 0.02, 0.03), GREEN)
		return kit.commit())


## A little bird of the flock (wings out, origin in the middle).
static func flock_bird() -> Mesh:
	return cached("flock_bird", func() -> Mesh:
		var kit := MeshKit.new()
		var grey := Color("6a6a74")
		kit.sphere(Vector3.ZERO, Vector3(0.08, 0.07, 0.14), grey, 2, 5)
		kit.tri(Vector3(0, 0.02, 0.04), Vector3(0.32, 0.06, -0.04), Vector3(0, 0.02, -0.08), grey.lightened(0.1))
		kit.tri(Vector3(0, 0.02, 0.04), Vector3(0, 0.02, -0.08), Vector3(0.32, 0.06, -0.04), grey)
		kit.tri(Vector3(0, 0.02, 0.04), Vector3(0, 0.02, -0.08), Vector3(-0.32, 0.06, -0.04), grey.lightened(0.1))
		kit.tri(Vector3(0, 0.02, 0.04), Vector3(-0.32, 0.06, -0.04), Vector3(0, 0.02, -0.08), grey)
		return kit.commit())

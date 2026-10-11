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
const COLORS := [RED, YELLOW, BLUE, PINK, GREEN, PURPLE, ORANGE, TEAL]

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
			for lx: float in [-6.5, 6.5]:
				kit.rod(Vector3(lx, 0, s * 3.4), top, 0.28, 0.2, 6, WHITE)
			kit.beam(Vector3(-4.2, 4.5, s * 3.0), Vector3(4.2, 4.5, s * 3.0), Vector2(0.18, 0.18), WHITE)
			kit.beam(Vector3(-2.3, 9.0, s * 2.6), Vector3(2.3, 9.0, s * 2.6), Vector2(0.16, 0.16), WHITE)
			kit.box(Vector3(0, 0.15, s * 3.4), Vector3(14.0, 0.3, 0.9), Color("8a847a"))
		kit.rod(hub + Vector3(0, 0, -2.4), hub + Vector3(0, 0, 2.4), 0.35, 0.35, 8, STEEL)
		# Boarding platform under the lowest gondola, steps to the front.
		kit.box(Vector3(0, 0.45, 0), Vector3(5.0, 0.9, 3.2), Color("b0a090"), Color("c9b9a6"))
		for st in 3:
			kit.box(Vector3(0, 0.15 + st * 0.3, 2.0 + (2 - st) * 0.35), Vector3(3.0, 0.3, 0.35), Color("c9b9a6"))
		for x: float in [-2.4, 2.4]:
			kit.beam(Vector3(x, 0.9, -1.5), Vector3(x, 1.9, -1.5), Vector2(0.06, 0.06), RED)
			kit.beam(Vector3(x, 1.9, -1.5), Vector3(x, 1.9, 1.5), Vector2(0.06, 0.06), RED)
		# Ticket booth beside the steps.
		kit.box(Vector3(4.3, 1.2, 2.2), Vector3(1.8, 2.4, 1.6), RED)
		kit.box(Vector3(4.3, 2.5, 2.2), Vector3(2.1, 0.2, 1.9), YELLOW)
		kit.box(Vector3(4.3, 1.4, 3.01), Vector3(1.2, 0.8, 0.04), Color("bfe0ff"))
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
				kit.beam(p0, p1, Vector2(0.22, 0.22), WHITE)
				var q0 := Vector3(cos(a0), sin(a0), 0) * (WHEEL_R - 1.6) + Vector3(0, 0, z)
				var q1 := Vector3(cos(a1), sin(a1), 0) * (WHEEL_R - 1.6) + Vector3(0, 0, z)
				kit.beam(q0, q1, Vector2(0.12, 0.12), [RED, YELLOW, BLUE, GREEN][(i / 2) % 4])
				if i % 2 == 0:
					kit.beam(Vector3(0, 0, z * 1.6), p0, Vector2(0.12, 0.12), WHITE)
					kit.beam(q0, p1, Vector2(0.08, 0.08), WHITE)
		for i in WHEEL_GONDOLAS:
			var a := TAU * i / WHEEL_GONDOLAS
			var p := Vector3(cos(a), sin(a), 0) * WHEEL_R
			kit.beam(p + Vector3(0, 0, -1.1), p + Vector3(0, 0, 1.1), Vector2(0.14, 0.14), STEEL)
		kit.cylinder(Vector3(0, 0, -1.6), 3.2, 0.9, 0.9, 10, RED)
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
		kit.cylinder(Vector3(0, -1.7, 0), 3.4, 0.7, 0.7, 10, GOLD)
		kit.pop()
		kit.use("glow")
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
		return kit.commit())


# --- Carousel ------------------------------------------------------------------------

static func carousel_base() -> Mesh:
	return cached("carousel_base", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.35, 6.3, 6.3, 20, Color("b0a090"), true, Color("c9b9a6"))
		for st in 2:
			kit.box(Vector3(0, 0.08 + st * 0.12, 6.5 + (1 - st) * 0.3), Vector3(2.4, 0.16, 0.3), Color("c9b9a6"))
		return kit.commit())


## The turning part: floor, mirrored centre column, poles and the striped roof with bulbs.
static func carousel_top() -> Mesh:
	return cached("carousel_top", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3(0, 0.35, 0), 0.12, 5.9, 5.9, 20, Color("8a5a34"), true, Color("b98a57"))
		kit.cylinder(Vector3(0, 0.47, 0), 3.2, 1.3, 1.3, 12, GOLD)
		kit.use("glow")
		for i in 12:
			var a := TAU * i / 12
			kit.box(Vector3(cos(a) * 1.32, 2.0, sin(a) * 1.32), Vector3(0.3, 1.8, 0.3) * Vector3(1, 1, 1), Color("cfe8ff"))
		kit.use("solid")
		var segs := 16
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var col: Color = RED if i % 2 == 0 else WHITE
			var c0 := Vector3(cos(a0), 0, sin(a0))
			var c1 := Vector3(cos(a1), 0, sin(a1))
			kit.quad(c0 * 6.3 + Vector3(0, 3.7, 0), Vector3(0, 5.6, 0), Vector3(0, 5.6, 0), c1 * 6.3 + Vector3(0, 3.7, 0), col)
			kit.tri(c0 * 6.3 + Vector3(0, 3.7, 0), c1 * 6.3 + Vector3(0, 3.7, 0), Vector3(0, 5.6, 0), col)
			kit.tri(c0 * 6.3 + Vector3(0, 3.69, 0), Vector3(0, 5.59, 0), c1 * 6.3 + Vector3(0, 3.69, 0), col.darkened(0.35))
			# Scalloped valance.
			var mid := (c0 + c1).normalized()
			kit.tri(c0 * 6.3 + Vector3(0, 3.7, 0), mid * 6.3 + Vector3(0, 3.1, 0), c1 * 6.3 + Vector3(0, 3.7, 0), YELLOW)
			kit.tri(c0 * 6.3 + Vector3(0, 3.7, 0), c1 * 6.3 + Vector3(0, 3.7, 0), mid * 6.3 + Vector3(0, 3.1, 0), YELLOW.darkened(0.2))
		kit.cylinder(Vector3(0, 5.6, 0), 0.8, 0.12, 0.05, 6, GOLD)
		kit.sphere(Vector3(0, 6.5, 0), Vector3(0.25, 0.25, 0.25), GOLD, 3, 6)
		kit.use("glow")
		for i in 32:
			var a := TAU * (i + 0.5) / 32
			kit.box(Vector3(cos(a) * 6.32, 3.68, sin(a) * 6.32), Vector3(0.14, 0.14, 0.14), BULB)
		return kit.commit())


## A carousel horse on its brass pole (origin on the floor; the horse bobs along the pole).
static func carousel_horse(col: Color) -> Mesh:
	return cached("horse_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
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
		kit.cylinder(Vector3(0, 0.0, 0), 3.2, 0.035, 0.035, 5, GOLD, false)
		return kit.commit())


# --- Chain swing ----------------------------------------------------------------------

static func chain_tower() -> Mesh:
	return cached("chain_tower", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.3, 2.6, 2.6, 12, Color("b0a090"), true, Color("c9b9a6"))
		kit.cylinder(Vector3(0, 0.3, 0), CHAIN_TOP - 0.3, 0.55, 0.4, 10, BLUE)
		for i in 6:
			var a := TAU * i / 6
			kit.box(Vector3(cos(a) * 0.5, 2.5 + (i % 3) * 1.4, sin(a) * 0.5), Vector3(0.2, 0.9, 0.2), YELLOW)
		return kit.commit())


## The turning crown at the top (origin at the crown's centre), with bulbs and a little roof.
static func chain_crown() -> Mesh:
	return cached("chain_crown", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3(0, -0.3, 0), 0.6, CHAIN_R + 0.2, CHAIN_R + 0.2, 16, WHITE, true, BLUE)
		kit.lathe(PackedVector2Array([Vector2(CHAIN_R + 0.6, 0.3), Vector2(0.4, 1.7), Vector2(0.0, 1.9)]), 16, BLUE, 0.0,
			[BLUE, BLUE.lightened(0.2)])
		for i in 16:
			var a := TAU * (i + 0.5) / 16
			kit.quad(Vector3(cos(a - 0.2), 0, sin(a - 0.2)) * (CHAIN_R + 0.62) + Vector3(0, 0.3, 0),
				Vector3(cos(a + 0.2), 0, sin(a + 0.2)) * (CHAIN_R + 0.62) + Vector3(0, 0.3, 0),
				Vector3(cos(a + 0.2), 0, sin(a + 0.2)) * (CHAIN_R + 0.62) + Vector3(0, -0.1, 0),
				Vector3(cos(a - 0.2), 0, sin(a - 0.2)) * (CHAIN_R + 0.62) + Vector3(0, -0.1, 0), YELLOW if i % 2 else RED)
		kit.use("glow")
		for i in 24:
			var a := TAU * i / 24
			kit.box(Vector3(cos(a), 0, sin(a)) * (CHAIN_R + 0.25) + Vector3(0, -0.32, 0), Vector3(0.14, 0.14, 0.14), BULB)
		return kit.commit())


## A seat on its chains (origin at the hook; the seat hangs CHAIN_LEN below).
static func chain_seat(col: Color) -> Mesh:
	return cached("chain_seat_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
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
			for z: float in [-2.8, 2.8]:
				kit.rod(Vector3(x, 0, z), Vector3(x, SWING_BAR, 0), 0.14, 0.12, 6, RED)
			kit.beam(Vector3(x, 2.0, -2.0), Vector3(x, 2.0, 2.0), Vector2(0.1, 0.1), RED)
		kit.rod(Vector3(-4.8, SWING_BAR, 0), Vector3(4.8, SWING_BAR, 0), 0.16, 0.16, 8, STEEL)
		kit.box(Vector3(0, 0.12, 0), Vector3(10.0, 0.24, 3.0), Color("b0a090"))
		kit.use("glow")
		for i in 13:
			kit.box(Vector3(-4.8 + i * 0.8, SWING_BAR + 0.25, 0), Vector3(0.14, 0.14, 0.14), BULB)
		return kit.commit())


## A swing boat hanging from the bar (origin on the bar; it swings about x).
static func swing_boat(col: Color) -> Mesh:
	return cached("swing_boat_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		var arm := SWING_BAR - 1.2
		for x: float in [-0.95, 0.95]:
			for z: float in [-1.0, 1.0]:
				kit.beam(Vector3(x, 0, 0), Vector3(x, -arm, z), Vector2(0.07, 0.07), STEEL)
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
		kit.box(Vector3(0, -arm - 0.35, 0), Vector3(1.8, 0.08, 2.6), Color("8a5a34"))
		for z: float in [-1.0, 1.0]:
			kit.box(Vector3(0, -arm - 0.1, z), Vector3(1.8, 0.1, 0.4), Color("b98a57"))
		kit.box(Vector3(0.97, -arm + 0.0, 0), Vector3(0.04, 0.3, 2.6), YELLOW)
		kit.box(Vector3(-0.97, -arm + 0.0, 0), Vector3(0.04, 0.3, 2.6), YELLOW)
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
		kit.beam(a + side, b + side, Vector2(0.16, 0.16), RED)
		kit.beam(a - side, b - side, Vector2(0.16, 0.16), RED)
		kit.beam(a - Vector3(0, 0.35, 0), b - Vector3(0, 0.35, 0), Vector2(0.22, 0.22), RED.darkened(0.25))
		if i % 2 == 0:
			kit.beam(a + side * 1.15 - Vector3(0, 0.1, 0), a - side * 1.15 - Vector3(0, 0.1, 0), Vector2(0.14, 0.08), Color("6e4a2c"))
		var ground_y := track[0].y - 1.4
		if i % 4 == 0 and a.y > ground_y + 1.0:
			var foot := Vector3(a.x, ground_y, a.z)
			kit.beam(foot + side * 1.3, a - Vector3(0, 0.3, 0) + side * 0.5, Vector2(0.18, 0.18), WHITE)
			kit.beam(foot - side * 1.3, a - Vector3(0, 0.3, 0) - side * 0.5, Vector2(0.18, 0.18), WHITE)
			if a.y > ground_y + 4.0:
				var mid := (a.y + ground_y) * 0.5
				kit.beam(Vector3(a.x, mid, a.z) + side * 0.9, Vector3(a.x, mid, a.z) - side * 0.9, Vector2(0.1, 0.1), WHITE)
	return kit.commit()


static func coaster_station() -> Mesh:
	return cached("coaster_station", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.45, 0), Vector3(10.0, 0.9, 3.0), Color("b0a090"), Color("c9b9a6"))
		for x: float in [-4.6, 4.6]:
			for z: float in [-1.6, 1.6]:
				kit.beam(Vector3(x, 0.9, z), Vector3(x, 3.6, z), Vector2(0.14, 0.14), WHITE)
		kit.box(Vector3(0, 3.7, 0), Vector3(10.6, 0.2, 3.8), YELLOW)
		kit.lathe(PackedVector2Array([Vector2(6.0, 3.8), Vector2(0.0, 5.0)]), 4, RED, PI / 4)
		for st in 3:
			kit.box(Vector3(0, 0.15 + st * 0.3, 1.8 + (2 - st) * 0.35), Vector3(3.0, 0.3, 0.35), Color("c9b9a6"))
		return kit.commit())


## One car of the coaster train (front +Z).
static func coaster_car(col: Color, front := false) -> Mesh:
	return cached("coaster_car_%s_%s" % [col.to_html(), front], func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.35, 0), Vector3(1.3, 0.5, 1.7), col)
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
		var wall := Color("3b2a4a")
		kit.box(Vector3(0, 3.5, 0), Vector3(26.0, 7.0, 14.0), wall, Color("2a1f36"))
		# Crooked towers at the corners.
		for x: float in [-12.0, 12.0]:
			kit.box(Vector3(x, 4.5, 6.0), Vector3(3.0, 9.0, 3.0), wall.darkened(0.15))
			kit.lathe(PackedVector2Array([Vector2(2.4, 9.0), Vector2(0.0, 12.0)]), 4, Color("5a2a6a"), PI / 4)
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
		kit.box(Vector3(0, 0.05, 9.2), Vector3(14.6, 0.1, 0.8), STEEL)
		kit.box(Vector3(0, 0.3, 11.0), Vector3(8.6, 0.6, 2.0), Color("5a4a6a"))
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
		kit.use("glow")
		for i in 20:
			kit.box(Vector3(-11.5 + i * 1.2, 6.9, 7.08), Vector3(0.18, 0.18, 0.08), [Color("b06aff"), Color("7bd34a"), Color("ff7a3a")][i % 3])
		return kit.commit())


## A ghost-train car (front +Z), with a bat face at the front.
static func ghost_car(col: Color) -> Mesh:
	return cached("ghost_car_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
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
		kit.box(Vector3(0, 0.15, 0), Vector3(w, 0.3, d), Color("5a5a62"), Color("6e6e78"))
		kit.box(Vector3(0, 0.42, d * 0.5 - 0.2), Vector3(w, 0.25, 0.4), Color("222226"))
		kit.box(Vector3(0, 0.42, -d * 0.5 + 0.2), Vector3(w, 0.25, 0.4), Color("222226"))
		kit.box(Vector3(w * 0.5 - 0.2, 0.42, 0), Vector3(0.4, 0.25, d), Color("222226"))
		kit.box(Vector3(-w * 0.5 + 0.2, 0.42, 0), Vector3(0.4, 0.25, d), Color("222226"))
		for x: float in [-w * 0.5 + 0.4, -w / 6.0, w / 6.0, w * 0.5 - 0.4]:
			for z: float in [-d * 0.5 + 0.4, d * 0.5 - 0.4]:
				kit.beam(Vector3(x, 0.3, z), Vector3(x, 4.6, z), Vector2(0.25, 0.25), YELLOW)
		kit.box(Vector3(0, 4.8, 0), Vector3(w + 1.0, 0.4, d + 1.0), Color("3a3a42"))
		# Fascia with stripes around the roof.
		for i in 12:
			var x := -w * 0.5 + (i + 0.5) * w / 12.0
			for z: float in [d * 0.5 + 0.52, -d * 0.5 - 0.52]:
				kit.box(Vector3(x, 5.4, z), Vector3(w / 12.0, 1.0, 0.06), RED if i % 2 == 0 else WHITE)
		for i in 8:
			var z := -d * 0.5 + (i + 0.5) * d / 8.0
			for x: float in [w * 0.5 + 0.52, -w * 0.5 - 0.52]:
				kit.box(Vector3(x, 5.4, z), Vector3(0.06, 1.0, d / 8.0), RED if i % 2 == 0 else WHITE)
		kit.box(Vector3(0, 4.58, 0), Vector3(w - 0.6, 0.04, d - 0.6), Color("2a2a30"))
		for i in 14:
			kit.box(Vector3(-w * 0.5 + 1.0 + i * 2.0, 4.55, 0), Vector3(0.04, 0.03, d - 1.0), STEEL)
		kit.use("glow")
		for i in 28:
			var x := -w * 0.5 + 0.5 + i * (w - 1.0) / 27.0
			kit.box(Vector3(x, 5.95, d * 0.5 + 0.55), Vector3(0.16, 0.16, 0.16), BULB)
			kit.box(Vector3(x, 5.95, -d * 0.5 - 0.55), Vector3(0.16, 0.16, 0.16), BULB)
		return kit.commit())


## A bumper car with its pole (front +Z).
static func scooter(col: Color) -> Mesh:
	return cached("scooter_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3(0, 0.05, 0), 0.25, 1.05, 1.05, 12, Color("1e1e22"))
		kit.box(Vector3(0, 0.45, 0), Vector3(1.4, 0.4, 2.0), col)
		kit.box(Vector3(0, 0.7, 0.55), Vector3(1.3, 0.25, 0.7), col.lightened(0.15))
		kit.box(Vector3(0, 0.75, -0.35), Vector3(1.0, 0.1, 0.6), DARK)
		kit.box(Vector3(0, 1.0, -0.7), Vector3(1.0, 0.5, 0.12), col.darkened(0.2))
		kit.rod(Vector3(0, 0.9, 0.25), Vector3(0, 1.05, 0.0), 0.04, 0.04, 4, DARK)
		kit.cylinder(Vector3(0, 1.05, 0.0), 0.04, 0.2, 0.2, 8, DARK)
		kit.cylinder(Vector3(0, 1.0, -0.85), 3.25, 0.03, 0.03, 4, STEEL, false)
		return kit.commit())


## The arcade hall: three walls and a roof, open to the front (+Z) with a neon sign, rows of
## cabinets inside. Footprint 24 × 16.
static func arcade_hall() -> Mesh:
	return cached("arcade_hall", func() -> Mesh:
		var kit := MeshKit.new()
		var w := 24.0
		var d := 16.0
		var wall := Color("2c3e66")
		kit.box(Vector3(0, 0.08, 0), Vector3(w, 0.16, d), Color("3a3048"), Color("4a3a5a"))
		kit.box(Vector3(0, 2.6, -d * 0.5 + 0.2), Vector3(w, 5.2, 0.4), wall)
		kit.box(Vector3(-w * 0.5 + 0.2, 2.6, 0), Vector3(0.4, 5.2, d), wall)
		kit.box(Vector3(w * 0.5 - 0.2, 2.6, 0), Vector3(0.4, 5.2, d), wall)
		kit.box(Vector3(0, 5.4, 0), Vector3(w + 0.6, 0.4, d + 0.6), Color("1f2a44"))
		for x: float in [-w / 6.0, w / 6.0]:
			kit.beam(Vector3(x, 0.16, d * 0.5 - 0.3), Vector3(x, 5.2, d * 0.5 - 0.3), Vector2(0.3, 0.3), Color("1f2a44"))
		kit.box(Vector3(0, 6.3, d * 0.5 + 0.1), Vector3(14.0, 1.6, 0.3), Color("1a1a24"))
		# Cabinets along the back and in a row in the middle.
		var cols := [RED, BLUE, GREEN, PURPLE, ORANGE, TEAL]
		for i in 7:
			var x := -9.0 + i * 3.0
			_cabinet(kit, Vector3(x, 0.16, -d * 0.5 + 1.0), 0.0, cols[i % cols.size()])
		for i in 4:
			var x := -6.0 + i * 4.0
			_cabinet(kit, Vector3(x, 0.16, 0.0), PI, cols[(i + 3) % cols.size()])
		kit.use("glow")
		for i in 24:
			kit.box(Vector3(-6.8 + i * 0.6, 7.15, d * 0.5 + 0.28), Vector3(0.12, 0.12, 0.08), [Color("ff4fd8"), Color("4ff3ff"), Color("fff04f")][i % 3])
			kit.box(Vector3(-6.8 + i * 0.6, 5.45, d * 0.5 + 0.28), Vector3(0.12, 0.12, 0.08), [Color("4ff3ff"), Color("fff04f"), Color("ff4fd8")][i % 3])
		return kit.commit())


static func _cabinet(kit: MeshKit, p: Vector3, yaw: float, col: Color) -> void:
	kit.push(Transform3D(Basis(Vector3.UP, yaw), p))
	kit.use("solid")
	kit.box(Vector3(0, 0.9, 0), Vector3(0.9, 1.8, 0.8), col.darkened(0.3))
	kit.box(Vector3(0, 1.0, 0.5), Vector3(0.9, 0.12, 0.35), DARK)
	kit.box(Vector3(0, 1.95, 0.05), Vector3(0.95, 0.3, 0.85), col)
	kit.use("glow")
	kit.box(Vector3(0, 1.45, 0.41), Vector3(0.65, 0.5, 0.02), Color("9fe8ff"))
	kit.box(Vector3(0, 1.95, 0.48), Vector3(0.8, 0.2, 0.02), col.lightened(0.3))
	kit.use("solid")
	kit.pop()


# --- Booths and food stands ---------------------------------------------------------------

## A booth (5 m wide, front +Z): counter, back and side walls, a striped awning and the sign
## board (text added separately); `kind` adds what the booth is about.
static func booth(kind: String, col: Color) -> Mesh:
	return cached("booth_%s_%s" % [kind, col.to_html()], func() -> Mesh:
		var kit := MeshKit.new()
		var w := 5.0
		kit.box(Vector3(0, 0.06, 0), Vector3(w, 0.12, 3.0), Color("8a7a6a"))
		kit.box(Vector3(0, 1.4, -1.45), Vector3(w, 2.8, 0.1), col.darkened(0.15))
		for x: float in [-w * 0.5 + 0.05, w * 0.5 - 0.05]:
			kit.box(Vector3(x, 1.4, 0), Vector3(0.1, 2.8, 3.0), col.darkened(0.25))
		kit.box(Vector3(0, 0.5, 1.4), Vector3(w, 1.0, 0.2), col)
		kit.box(Vector3(0, 1.03, 1.45), Vector3(w + 0.1, 0.06, 0.45), Color("b98a57"))
		kit.box(Vector3(0, 2.85, 0), Vector3(w + 0.2, 0.1, 3.2), col.darkened(0.3))
		# Striped awning over the counter.
		for i in 10:
			var x0 := -w * 0.5 + i * w / 10.0
			var x1 := x0 + w / 10.0
			var c: Color = WHITE if i % 2 == 0 else col
			kit.quad(Vector3(x0, 2.8, 1.5), Vector3(x0, 2.35, 2.5), Vector3(x1, 2.35, 2.5), Vector3(x1, 2.8, 1.5), c)
			kit.quad(Vector3(x0, 2.79, 1.5), Vector3(x1, 2.79, 1.5), Vector3(x1, 2.34, 2.5), Vector3(x0, 2.34, 2.5), c.darkened(0.3))
			kit.tri(Vector3(x0, 2.35, 2.5), Vector3((x0 + x1) * 0.5, 2.15, 2.5), Vector3(x1, 2.35, 2.5), c)
			kit.tri(Vector3(x0, 2.35, 2.49), Vector3(x1, 2.35, 2.49), Vector3((x0 + x1) * 0.5, 2.15, 2.49), c.darkened(0.3))
		kit.box(Vector3(0, 3.3, 1.45), Vector3(w + 0.2, 0.9, 0.12), YELLOW if col != YELLOW else RED)
		return kit.commit())


## What lies in a booth (cans, ducks, bottles, balloons, moles, the wheel, lottery drums, food):
## its own mesh, so a booth game can hide it while it puts out its own things.
static func booth_deco(kind: String) -> Mesh:
	return cached("booth_deco_%s" % kind, func() -> Mesh:
		var kit := MeshKit.new()
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
				kit.use("solid")
				for k in 8:
					var p := Vector3(-1.5 + (k % 4) * 1.0, 1.18, -0.7 + (k / 4) * 0.9)
					kit.sphere(p, Vector3(0.14, 0.11, 0.17), YELLOW, 2, 5)
					kit.sphere(p + Vector3(0, 0.13, 0.08), Vector3(0.08, 0.08, 0.08), YELLOW, 2, 5)
					kit.box(p + Vector3(0, 0.12, 0.17), Vector3(0.06, 0.03, 0.06), ORANGE)
				for k in 3:
					kit.beam(Vector3(1.8 + k * 0.1, 1.0, 1.1), Vector3(1.6 + k * 0.1, 2.2, 0.4), Vector2(0.03, 0.03), Color("b98a57"))
			"rings":
				kit.box(Vector3(0, 0.8, -0.5), Vector3(3.4, 0.08, 1.6), Color("b98a57"))
				for k in 15:
					var p := Vector3(-1.4 + (k % 5) * 0.7, 0.84, -1.0 + (k / 5) * 0.5)
					kit.cylinder(p, 0.32, 0.07, 0.05, 6, Color("2f7d4a"))
					kit.cylinder(p + Vector3(0, 0.32, 0), 0.16, 0.025, 0.025, 4, Color("2f7d4a"))
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
				kit.box(Vector3(0, 0.95, -0.2), Vector3(3.0, 0.2, 1.8), Color("6b8a3a"))
				for k in 9:
					var p := Vector3(-1.0 + (k % 3) * 1.0, 1.06, -0.8 + (k / 3) * 0.6)
					kit.cylinder(p, 0.02, 0.2, 0.2, 8, DARK)
					if k % 3 == 1:
						kit.sphere(p + Vector3(0, 0.08, 0), Vector3(0.16, 0.18, 0.16), Color("7a5a3a"), 3, 6)
						kit.sphere(p + Vector3(0, 0.12, 0.15), Vector3(0.05, 0.04, 0.04), PINK, 2, 4)
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


## The high striker: a 6 m pole with a scale and a bell, the pad and the mallet.
static func high_striker() -> Mesh:
	return cached("high_striker", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.15, 0.6), Vector3(1.6, 0.3, 1.6), Color("8a5a34"))
		kit.cylinder(Vector3(0, 0.3, 0.9), 0.15, 0.3, 0.3, 10, RED)
		kit.box(Vector3(0, 3.2, 0), Vector3(0.4, 6.4, 0.25), WHITE)
		for k in 10:
			kit.box(Vector3(0, 0.8 + k * 0.55, 0.14), Vector3(0.36, 0.5, 0.03), COLORS[k % COLORS.size()])
		kit.beam(Vector3(0.12, 0.3, 0.15), Vector3(0.12, 6.2, 0.15), Vector2(0.03, 0.03), STEEL)
		kit.sphere(Vector3(0, 6.7, 0.0), Vector3(0.35, 0.3, 0.35), GOLD, 3, 8)
		kit.box(Vector3(0.12, 0.6, 0.18), Vector3(0.2, 0.2, 0.1), RED)
		kit.rod(Vector3(0.9, 0.3, 1.0), Vector3(0.9, 1.3, 1.1), 0.04, 0.04, 4, Color("b98a57"))
		kit.box(Vector3(0.9, 1.35, 1.1), Vector3(0.5, 0.25, 0.25), Color("6e4a2c"))
		kit.use("glow")
		for k in 8:
			kit.box(Vector3(-0.26, 1.0 + k * 0.7, 0.0), Vector3(0.1, 0.1, 0.1), BULB)
		return kit.commit())


## The magician's little stage with a red curtain and stars (front +Z).
static func magic_stage() -> Mesh:
	return cached("magic_stage", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.4, 0), Vector3(7.0, 0.8, 4.0), Color("6e4a2c"), Color("9a6a3e"))
		for st in 2:
			kit.box(Vector3(2.6, 0.13 + st * 0.27, 2.2 + (1 - st) * 0.3), Vector3(1.2, 0.27, 0.3), Color("9a6a3e"))
		kit.box(Vector3(0, 2.6, -1.9), Vector3(7.0, 3.6, 0.15), Color("8e1f2b"))
		for x: float in [-3.4, 3.4]:
			kit.box(Vector3(x, 2.6, -0.2), Vector3(0.3, 3.6, 3.6), Color("2a1f3a"))
		kit.box(Vector3(0, 4.55, -0.2), Vector3(7.2, 0.5, 3.8), Color("2a1f3a"))
		for x: float in [-2.6, 2.6]:
			for k in 5:
				kit.box(Vector3(x + (k - 2) * 0.16 * signf(x), 2.6, -1.0 + k * 0.05), Vector3(0.14, 3.4, 0.4), Color("b02a38"))
		kit.box(Vector3(0, 4.55, 1.72), Vector3(7.2, 0.5, 0.06), Color("1a1430"))
		kit.use("glow")
		for k in 7:
			var x := -3.0 + k * 1.0
			kit.sphere(Vector3(x, 4.55, 1.78), Vector3(0.12, 0.12, 0.04), GOLD, 2, 5)
			kit.box(Vector3(x, 0.82, 1.95), Vector3(0.12, 0.06, 0.06), BULB)
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
			kit.quad(d0, d0 + Vector3(0, 2.2, 0), d1 + Vector3(0, 2.2, 0), d1, c)
			kit.quad(d1, d1 + Vector3(0, 2.2, 0), d0 + Vector3(0, 2.2, 0), d0, c.darkened(0.4))
		kit.lathe(PackedVector2Array([Vector2(3.3, 2.1), Vector2(0.0, 4.2)]), n, col.darkened(0.1), PI / 2 + TAU / n * 0.5)
		kit.lathe(PackedVector2Array([Vector2(0.0, 4.19), Vector2(3.29, 2.09)]), n, col.darkened(0.5), PI / 2 + TAU / n * 0.5)
		kit.cylinder(Vector3(0, 4.1, 0), 0.6, 0.05, 0.03, 5, GOLD)
		kit.sphere(Vector3(0, 4.8, 0), Vector3(0.15, 0.15, 0.15), GOLD, 2, 5)
		# Table with a crystal ball, stools.
		kit.cylinder(Vector3(0, 0, -0.4), 0.75, 0.1, 0.1, 6, DARK)
		kit.cylinder(Vector3(0, 0.75, -0.4), 0.05, 0.7, 0.7, 12, Color("8e1f2b"))
		kit.use("glow")
		kit.sphere(Vector3(0, 1.0, -0.4), Vector3(0.2, 0.2, 0.2), Color("b8e0ff"), 3, 7)
		for i in 10:
			var a := TAU * i / 10
			kit.box(Vector3(cos(a) * 3.05, 1.6 + sin(i * 1.7) * 0.4, sin(a) * 3.05), Vector3(0.12, 0.12, 0.04), GOLD)
		return kit.commit())


## The prize counter: a kiosk with shelves full of tools, gems and jars (front +Z).
static func prize_counter() -> Mesh:
	return cached("prize_counter", func() -> Mesh:
		var kit := MeshKit.new()
		var col := Color("2e86de")
		kit.box(Vector3(0, 1.3, -1.2), Vector3(4.0, 2.6, 0.1), col.darkened(0.2))
		for x: float in [-1.95, 1.95]:
			kit.box(Vector3(x, 1.3, 0), Vector3(0.1, 2.6, 2.5), col.darkened(0.3))
		kit.box(Vector3(0, 0.5, 1.15), Vector3(4.0, 1.0, 0.2), col)
		kit.box(Vector3(0, 2.7, 0), Vector3(4.4, 0.2, 2.9), YELLOW)
		kit.box(Vector3(0, 3.2, 1.25), Vector3(4.4, 0.8, 0.12), RED)
		for y: float in [1.1, 1.7, 2.3]:
			kit.box(Vector3(0, y, -0.95), Vector3(3.6, 0.06, 0.4), Color("b98a57"))
		for k in 6:
			kit.box(Vector3(-1.4 + k * 0.55, 1.28, -0.95), Vector3(0.3, 0.3, 0.3), [Color("d9a35c"), STEEL, Color("6e4a2c")][k % 3])
			kit.sphere(Vector3(-1.4 + k * 0.55, 1.85, -0.95), Vector3(0.14, 0.14, 0.14), [Color("7fd8ff"), Color("ff7fa8"), GREEN][k % 3], 2, 5)
			kit.cylinder(Vector3(-1.4 + k * 0.55, 2.33, -0.95), 0.3, 0.1, 0.1, 6, Color("f2b630"))
		return kit.commit())


# --- Street furniture ---------------------------------------------------------------------

## A tall pole for string lights.
static func light_pole() -> Mesh:
	return cached("light_pole", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.3, 0.16, 0.12, 6, DARK)
		kit.cylinder(Vector3(0, 0.3, 0), 4.2, 0.06, 0.05, 6, DARK)
		kit.sphere(Vector3(0, 4.55, 0), Vector3(0.09, 0.09, 0.09), GOLD, 2, 5)
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
				kit.use("glow")
				kit.sphere(p - Vector3(0, 0.08, 0), Vector3(0.07, 0.09, 0.07), [BULB, Color("ff9a9a"), Color("9affb0"), Color("9ad0ff")][(i / 2) % 4], 2, 4)
			elif i < n:
				# Bunting between the bulbs.
				var along := (b - a).normalized() * 0.22
				var col: Color = COLORS[(i / 2 + span.size()) % COLORS.size()]
				kit.use("solid")
				kit.tri(p - along, p + along, p - Vector3(0, 0.42, 0), col)
				kit.tri(p + along, p - along, p - Vector3(0, 0.42, 0), col.darkened(0.2))
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

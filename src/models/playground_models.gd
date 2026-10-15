class_name PlaygroundModels
extends RefCounted
## The big playground in the city park: play tower with slide, nest swing, seesaw, carousel,
## spring animals, trampoline, balance beam, climbing net, sandbox things, fence and sign, and
## the troll's treasure chest. Origins sit on the ground unless stated; front faces +Z. Parts
## that move (nest, seesaw beam, carousel deck, spring animal) are separate meshes whose origin
## is the point they move about; the constants tell the logic where seats and ends are.

const RED := Color("d8463a")
const YELLOW := Color("f2c230")
const BLUE := Color("3a7fd8")
const GREEN := Color("3aa86b")
const ORANGE := Color("f28a2a")
const STEEL := Color("8e959a")
const ROPE := Color("c9b48a")
const RUBBER := Color("2b2b2e")
const SAND := Color("ead7a0")
const SAND_DARK := Color("cdb67a")
const BARK := Color("6b4a2c")
const CUT := Color("d9b98a")
const COLOURS := [RED, YELLOW, BLUE, GREEN]

## Play tower with slide (slide_tower): platform top, ladder and slide ends.
const TOWER_TOP := 1.5
const LADDER_FOOT := Vector3(-1.6, 0, 0)
const LADDER_TOP := Vector3(-0.65, 1.5, 0)
const SLIDE_TOP := Vector3(0.75, 1.5, 0)
const SLIDE_BOTTOM := Vector3(3.9, 0.35, 0)
const SLIDE_EXIT := Vector3(4.9, 0, 0)
## Nest swing: beam height above the ground, nest below the pivot.
const NEST_PIVOT := 2.6
const NEST_DROP := 2.05
## Seesaw: pivot height, seats at ±SEESAW_SEAT_X along the beam.
const SEESAW_PIVOT_Y := 0.5
const SEESAW_SEAT_X := 1.5
## Carousel (merry-go-round): deck radius and deck top.
const CAROUSEL_R := 1.5
const CAROUSEL_DECK := 0.25
## Spring animal: coil top above the ground, seat above the coil top.
const SPRING_TOP := 0.45
const SPRING_SEAT := 0.25
## In-ground trampoline radius.
const TRAMPOLINE_R := 1.5
## Balance beam top.
const BEAM_TOP := 0.35
## Climbing net: the knot platform on the mast.
const CLIMB_TOP := 2.6


static func cached(key: String, builder: Callable) -> Mesh:
	return PropModels.cached("pg_" + key, builder)


## A thin rope or bar between two points.
static func _rope(kit: MeshKit, a: Vector3, b: Vector3, col: Color, thick := 0.035) -> void:
	kit.beam(a, b, Vector2(thick, thick), col)


## A flat disc facing +Z (painted things on boards), centred at c.
static func _disc_z(kit: MeshKit, c: Vector3, r: float, segments: int, col: Color) -> void:
	kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), c))
	kit.disc(Vector3.ZERO, r, segments, col)
	kit.pop()


# --- Play tower and slide -------------------------------------------------------------

static func slide_tower() -> Mesh:
	return cached("slide_tower", func() -> Mesh:
		var kit := MeshKit.new()
		var wood := PropModels.WOOD
		var wood_light := PropModels.WOOD_LIGHT
		# Four posts up to the roof (high enough for a grown-up on the platform), the platform and
		# braces under it.
		for x: float in [-0.75, 0.75]:
			for z: float in [-0.75, 0.75]:
				kit.box(Vector3(x, 1.7, z), Vector3(0.12, 3.4, 0.12), wood)
		kit.box(Vector3(0, TOWER_TOP - 0.04, 0), Vector3(1.66, 0.08, 1.66), wood_light, wood_light.lightened(0.1))
		for i in 6:
			kit.box(Vector3(-0.68 + i * 0.27, TOWER_TOP + 0.002, 0), Vector3(0.02, 0.004, 1.6), wood)
		for z: float in [-0.75, 0.75]:
			kit.beam(Vector3(-0.75, 0.2, z), Vector3(0.75, TOWER_TOP - 0.1, z), Vector2(0.06, 0.06), wood)
		# Pyramid roof with a little flag.
		kit.lathe(PackedVector2Array([Vector2(1.25, 3.4), Vector2(0.0, 4.05)]), 4, RED, PI / 4)
		kit.box(Vector3(0, 3.37, 0), Vector3(1.8, 0.06, 1.8), RED.darkened(0.25))
		kit.beam(Vector3(0, 4.0, 0), Vector3(0, 4.45, 0), Vector2(0.025, 0.025), STEEL)
		kit.tri(Vector3(0, 4.45, 0), Vector3(0, 4.28, 0), Vector3(0.3, 4.37, 0), YELLOW)
		kit.tri(Vector3(0, 4.45, 0), Vector3(0.3, 4.37, 0), Vector3(0, 4.28, 0), YELLOW)
		# Railings on the ±Z sides.
		for z: float in [-0.78, 0.78]:
			kit.box(Vector3(0, 2.25, z), Vector3(1.6, 0.06, 0.06), wood_light)
			kit.box(Vector3(0, 1.85, z), Vector3(1.6, 0.05, 0.05), wood_light)
			for i in 5:
				kit.box(Vector3(-0.56 + i * 0.28, 1.88, z), Vector3(0.05, 0.75, 0.04), YELLOW if i % 2 == 0 else BLUE)
		# Ladder on −X with handles above the platform.
		var foot := LADDER_FOOT
		var top := Vector3(-0.8, TOWER_TOP, 0)
		for z: float in [-0.3, 0.3]:
			kit.beam(foot + Vector3(0, 0, z), top + Vector3(0, 0.02, z), Vector2(0.07, 0.07), YELLOW)
			kit.beam(top + Vector3(0, 0, z), top + Vector3(0.05, 0.7, z), Vector2(0.05, 0.05), YELLOW)
		for i in 5:
			var t := (i + 0.6) / 5.6
			var p := foot.lerp(top, t)
			kit.beam(p + Vector3(0, 0, -0.3), p + Vector3(0, 0, 0.3), Vector2(0.06, 0.04), wood)
		# Slide chute on +X: bed, raised sides and a flat run-out, legs at the bottom.
		var s0 := SLIDE_TOP
		var s1 := SLIDE_BOTTOM
		var s2 := Vector3(4.4, 0.3, 0)
		kit.beam(s0 + Vector3(-0.05, -0.03, 0), s1, Vector2(0.62, 0.05), BLUE)
		kit.beam(s1, s2, Vector2(0.62, 0.05), BLUE)
		for z: float in [-0.32, 0.32]:
			kit.beam(s0 + Vector3(0, 0.12, z), s1 + Vector3(0, 0.12, z), Vector2(0.04, 0.18), BLUE.darkened(0.25))
			kit.beam(s1 + Vector3(0, 0.12, z), s2 + Vector3(0, 0.1, z), Vector2(0.04, 0.16), BLUE.darkened(0.25))
			kit.beam(Vector3(4.2, 0, z * 0.8), Vector3(4.2, 0.28, z * 0.8), Vector2(0.06, 0.06), STEEL)
			kit.beam(Vector3(2.3, 0, z * 0.8), Vector3(2.3, 0.88, z * 0.8), Vector2(0.06, 0.06), STEEL)
		# Grab bars at the top of the slide.
		for z: float in [-0.34, 0.34]:
			kit.beam(Vector3(0.75, TOWER_TOP, z), Vector3(0.95, 2.05, z), Vector2(0.04, 0.04), RED)
		# Steering wheel on the +Z railing and a telescope on the −Z railing.
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 2.05, 0.84)))
		kit.torus(Vector3.ZERO, 0.2, 0.03, 12, 4, RED)
		for k in 3:
			var a := TAU * k / 3.0
			kit.beam(Vector3.ZERO, Vector3(cos(a), 0, sin(a)) * 0.2, Vector2(0.025, 0.025), RED)
		kit.cylinder(Vector3(0, -0.03, 0), 0.06, 0.05, 0.05, 6, YELLOW)
		kit.pop()
		kit.rod(Vector3(0.3, 2.3, -0.82), Vector3(0.55, 2.45, -1.15), 0.05, 0.07, 6, GREEN)
		# Climbing holds under the platform on the +Z side.
		kit.box(Vector3(0, 0.75, 0.8), Vector3(1.4, 1.4, 0.05), wood_light)
		for i in 7:
			var hp := Vector3(-0.5 + (i % 3) * 0.5 + (0.25 if i % 2 == 1 else 0.0), 0.25 + i * 0.18, 0.84)
			kit.sphere(hp, Vector3(0.07, 0.05, 0.04), COLOURS[i % 4], 2, 5)
		return kit.commit())


# --- Nest swing -------------------------------------------------------------------------

static func nest_swing_frame() -> Mesh:
	return cached("nest_swing_frame", func() -> Mesh:
		var kit := MeshKit.new()
		for x: float in [-1.7, 1.7]:
			for z: float in [-1.0, 1.0]:
				kit.beam(Vector3(x, 0, z), Vector3(x, NEST_PIVOT, 0), Vector2(0.12, 0.12), GREEN)
				kit.box(Vector3(x, 0.03, z * 0.97), Vector3(0.25, 0.06, 0.25), PropModels.STONE)
			kit.beam(Vector3(x, 0.9, -0.66), Vector3(x, 0.9, 0.66), Vector2(0.07, 0.07), GREEN.darkened(0.2))
		kit.box(Vector3(0, NEST_PIVOT, 0), Vector3(3.7, 0.16, 0.16), GREEN.darkened(0.15))
		for x: float in [-0.35, 0.35]:
			kit.box(Vector3(x, NEST_PIVOT - 0.1, 0), Vector3(0.08, 0.06, 0.2), STEEL)
		return kit.commit())


static func nest_seat() -> Mesh:
	return cached("nest_seat", func() -> Mesh:
		var kit := MeshKit.new()
		var y := -NEST_DROP
		# Four chains from two hooks to the ring.
		for k in 4:
			var a := PI / 4 + k * PI / 2
			var ring := Vector3(cos(a) * 0.5, y + 0.08, sin(a) * 0.5)
			var hook := Vector3(0.35 if cos(a) > 0.0 else -0.35, -0.13, 0)
			_rope(kit, hook, ring, STEEL, 0.025)
		kit.torus(Vector3(0, y, 0), 0.55, 0.09, 16, 6, RED)
		kit.disc(Vector3(0, y - 0.02, 0), 0.5, 16, RUBBER)
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, y - 0.03, 0)))
		kit.disc(Vector3.ZERO, 0.5, 16, RUBBER)
		kit.pop()
		# Woven net on the disc.
		for i in 5:
			var o := -0.4 + i * 0.2
			var h := sqrt(maxf(0.0, 0.25 - o * o))
			kit.box(Vector3(o, y - 0.005, 0), Vector3(0.02, 0.012, h * 2.0), ROPE)
			kit.box(Vector3(0, y - 0.005, o), Vector3(h * 2.0, 0.012, 0.02), ROPE)
		return kit.commit())


# --- Seesaw -----------------------------------------------------------------------------

static func seesaw_stand() -> Mesh:
	return cached("seesaw_stand", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.03, 0), Vector3(0.6, 0.06, 0.7), PropModels.STONE)
		for z: float in [-0.2, 0.2]:
			kit.box(Vector3(0, 0.27, z), Vector3(0.32, 0.48, 0.05), BLUE)
		kit.rod(Vector3(0, SEESAW_PIVOT_Y, -0.26), Vector3(0, SEESAW_PIVOT_Y, 0.26), 0.04, 0.04, 6, STEEL)
		# Old tyres half in the ground under the beam ends.
		for x: float in [-1.55, 1.55]:
			kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(x, -0.12, 0)))
			kit.torus(Vector3.ZERO, 0.22, 0.08, 12, 5, RUBBER)
			kit.pop()
		return kit.commit())


static func seesaw_beam() -> Mesh:
	return cached("seesaw_beam", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0, 0), Vector3(3.6, 0.08, 0.26), YELLOW)
		kit.rod(Vector3(0, 0, -0.16), Vector3(0, 0, 0.16), 0.07, 0.07, 8, RED)
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(s * SEESAW_SEAT_X, 0.06, 0), Vector3(0.46, 0.04, 0.32), RED, RED.lightened(0.15))
			# Handle: two posts and a cross bar in front of the seat.
			var hx := s * 1.15
			for z: float in [-0.12, 0.12]:
				kit.beam(Vector3(hx, 0.04, z), Vector3(hx, 0.35, z), Vector2(0.04, 0.04), BLUE)
			kit.beam(Vector3(hx, 0.35, -0.16), Vector3(hx, 0.35, 0.16), Vector2(0.045, 0.045), BLUE)
			kit.box(Vector3(s * 1.78, 0, 0), Vector3(0.06, 0.1, 0.28), RUBBER)
		return kit.commit())


# --- Carousel ---------------------------------------------------------------------------

static func carousel_base() -> Mesh:
	return cached("carousel_base", func() -> Mesh:
		var kit := MeshKit.new()
		kit.disc(Vector3(0, 0.012, 0), CAROUSEL_R + 0.3, 24, Color("5a6a5e"))
		kit.cylinder(Vector3.ZERO, 0.12, 0.32, 0.28, 10, PropModels.STONE_DARK)
		return kit.commit())


static func carousel_top() -> Mesh:
	return cached("carousel_top", func() -> Mesh:
		var kit := MeshKit.new()
		# Deck in eight coloured wedges and a rim.
		var n := 8
		for k in n:
			var poly := PackedVector2Array([Vector2.ZERO])
			for i in 4:
				var a := TAU * (k + i / 3.0) / n
				poly.append(Vector2(cos(a), sin(a)) * CAROUSEL_R)
			kit.prism(poly, 0.13, CAROUSEL_DECK, COLOURS[k % 4].darkened(0.15), COLOURS[k % 4])
		kit.torus(Vector3(0, CAROUSEL_DECK - 0.04, 0), CAROUSEL_R, 0.045, 24, 4, STEEL)
		# Centre post with a cap.
		kit.cylinder(Vector3(0, CAROUSEL_DECK, 0), 0.75, 0.08, 0.07, 8, STEEL)
		kit.sphere(Vector3(0, 1.03, 0), Vector3(0.14, 0.1, 0.14), RED, 3, 8)
		# Bent handle bars from the post to the rim, between the sitting places.
		for k in 4:
			var a := k * PI / 2
			var d := Vector3(cos(a), 0, sin(a))
			var p0 := d * 0.08 + Vector3(0, 0.95, 0)
			var p1 := d * 0.95 + Vector3(0, 0.85, 0)
			var p2 := d * 1.38 + Vector3(0, CAROUSEL_DECK, 0)
			kit.rod(p0, p1, 0.03, 0.03, 6, YELLOW, false)
			kit.rod(p1, p2, 0.03, 0.03, 6, YELLOW, false)
			kit.sphere(p1, Vector3(0.035, 0.035, 0.035), YELLOW, 2, 5)
			# Sitting pad between the bars.
			var b := PI / 4 + k * PI / 2
			var sp := Vector3(cos(b), 0, sin(b)) * 1.0
			kit.push(Transform3D(Basis(Vector3.UP, -b), sp + Vector3(0, CAROUSEL_DECK + 0.015, 0)))
			kit.box(Vector3.ZERO, Vector3(0.4, 0.03, 0.34), Color("f1eee6"))
			kit.pop()
		return kit.commit())


# --- Spring animals ---------------------------------------------------------------------

static func spring_base() -> Mesh:
	return cached("spring_base", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.05, 0.3, 0.28, 10, PropModels.STONE_DARK)
		for i in 6:
			kit.torus(Vector3(0, 0.1 + i * 0.058, 0), 0.12, 0.022, 10, 4, Color("c0c4c8"))
		kit.cylinder(Vector3(0, 0.05, 0), 0.04, 0.15, 0.14, 8, STEEL)
		kit.cylinder(Vector3(0, SPRING_TOP - 0.04, 0), 0.04, 0.14, 0.15, 8, STEEL)
		return kit.commit())


static func spring_animal(kind: String) -> Mesh:
	return cached("spring_animal_" + kind, func() -> Mesh:
		var kit := MeshKit.new()
		var y := SPRING_SEAT
		if kind == "horse":
			var brown := Color("8a5a34")
			var white := Color("f4f0e6")
			kit.sphere(Vector3(0, 0.05, -0.02), Vector3(0.22, 0.18, 0.46), brown, 4, 8)
			# Legs folded forward and back (a rocking horse look).
			for x: float in [-0.12, 0.12]:
				kit.beam(Vector3(x, 0.0, 0.25), Vector3(x, -0.1, 0.45), Vector2(0.08, 0.08), brown)
				kit.beam(Vector3(x, 0.0, -0.28), Vector3(x, -0.1, -0.48), Vector2(0.08, 0.08), brown)
			# Neck, head, blaze, ears, eyes, mane and tail.
			kit.beam(Vector3(0, 0.1, 0.32), Vector3(0, 0.42, 0.46), Vector2(0.17, 0.15), brown)
			kit.sphere(Vector3(0, 0.46, 0.58), Vector3(0.11, 0.12, 0.2), brown, 3, 7)
			kit.box(Vector3(0, 0.47, 0.765), Vector3(0.06, 0.12, 0.02), white)
			for x: float in [-0.06, 0.06]:
				kit.beam(Vector3(x, 0.56, 0.5), Vector3(x * 1.4, 0.66, 0.48), Vector2(0.04, 0.03), brown.darkened(0.2))
				kit.sphere(Vector3(x * 1.55, 0.5, 0.66), Vector3(0.022, 0.022, 0.022), RUBBER, 2, 4)
			for i in 5:
				kit.box(Vector3(0, 0.2 + i * 0.075, 0.27 + i * 0.045), Vector3(0.05, 0.1, 0.07), white)
			kit.beam(Vector3(0, 0.12, -0.45), Vector3(0, -0.12, -0.6), Vector2(0.07, 0.05), white)
			# Saddle.
			kit.box(Vector3(0, y - 0.025, -0.05), Vector3(0.3, 0.05, 0.3), RED, RED.lightened(0.1))
		else:
			kit.sphere(Vector3(0, 0.05, -0.02), Vector3(0.25, 0.18, 0.42), YELLOW, 4, 8)
			kit.sphere(Vector3(0, 0.42, 0.36), Vector3(0.17, 0.17, 0.17), YELLOW, 3, 8)
			kit.beam(Vector3(0, 0.12, 0.25), Vector3(0, 0.3, 0.33), Vector2(0.18, 0.14), YELLOW)
			kit.box(Vector3(0, 0.39, 0.55), Vector3(0.14, 0.05, 0.16), ORANGE)
			for x: float in [-0.08, 0.08]:
				kit.sphere(Vector3(x, 0.47, 0.5), Vector3(0.025, 0.025, 0.025), RUBBER, 2, 4)
				kit.sphere(Vector3(x * 3.0, 0.08, -0.05), Vector3(0.05, 0.1, 0.24), YELLOW.darkened(0.12), 3, 6)
			kit.beam(Vector3(0, 0.08, -0.38), Vector3(0, 0.25, -0.52), Vector2(0.14, 0.06), YELLOW)
			kit.box(Vector3(0, y - 0.025, -0.08), Vector3(0.3, 0.05, 0.3), BLUE, BLUE.lightened(0.1))
		# Handle bar in front.
		kit.beam(Vector3(-0.2, 0.45, 0.28), Vector3(0.2, 0.45, 0.28), Vector2(0.04, 0.04), RED)
		for x: float in [-0.22, 0.22]:
			kit.rod(Vector3(x, 0.45, 0.28), Vector3(x * 1.25, 0.45, 0.28), 0.03, 0.03, 6, RUBBER)
		return kit.commit())


# --- Trampoline, balance beam, climbing net ---------------------------------------------------

static func trampoline() -> Mesh:
	return cached("trampoline", func() -> Mesh:
		var kit := MeshKit.new()
		kit.disc(Vector3(0, 0.015, 0), TRAMPOLINE_R + 0.3, 24, Color("3e8a4a"))
		kit.torus(Vector3(0, 0.06, 0), TRAMPOLINE_R - 0.12, 0.12, 24, 5, BLUE)
		kit.disc(Vector3(0, 0.04, 0), TRAMPOLINE_R - 0.2, 24, RUBBER)
		kit.torus(Vector3(0, 0.042, 0), 0.6, 0.012, 20, 3, Color("f1eee6"))
		kit.box(Vector3(0, 0.045, 0), Vector3(0.3, 0.004, 0.04), Color("f1eee6"))
		kit.box(Vector3(0, 0.045, 0), Vector3(0.04, 0.004, 0.3), Color("f1eee6"))
		return kit.commit())


static func balance_beam(length: float) -> Mesh:
	return cached("balance_beam_%.1f" % length, func() -> Mesh:
		var kit := MeshKit.new()
		var r := 0.11
		var y := BEAM_TOP - r
		for x: float in [-length * 0.5 + 0.15, 0.0, length * 0.5 - 0.15]:
			kit.cylinder(Vector3(x, 0, 0), y, 0.09, 0.08, 7, BARK.darkened(0.15))
		kit.rod(Vector3(-length * 0.5, y, 0), Vector3(length * 0.5, y, 0), r, r, 8, PropModels.WOOD)
		# Light cut ends.
		for s: float in [-1.0, 1.0]:
			kit.push(Transform3D(Basis(Vector3.FORWARD, s * PI / 2), Vector3(s * (length * 0.5 + 0.002), y, 0)))
			kit.disc(Vector3.ZERO, r * 0.95, 8, CUT)
			kit.pop()
		return kit.commit())


static func stump(h: float) -> Mesh:
	return cached("stump_%.2f" % h, func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, h, 0.24, 0.21, 9, BARK, true, CUT)
		kit.disc(Vector3(0, h + 0.003, 0), 0.08, 8, CUT.darkened(0.12))
		return kit.commit())


static func climbing_net() -> Mesh:
	return cached("climbing_net", func() -> Mesh:
		var kit := MeshKit.new()
		var apex := Vector3(0, CLIMB_TOP - 0.1, 0)
		var corners := [Vector3(-1.6, 0.12, -1.6), Vector3(1.6, 0.12, -1.6), Vector3(1.6, 0.12, 1.6), Vector3(-1.6, 0.12, 1.6)]
		# Mast with the standing knot, cap and flag.
		kit.cylinder(Vector3.ZERO, CLIMB_TOP + 0.4, 0.08, 0.07, 8, STEEL)
		kit.cylinder(Vector3(0, CLIMB_TOP - 0.06, 0), 0.06, 0.32, 0.32, 10, RED)
		kit.sphere(Vector3(0, CLIMB_TOP + 0.43, 0), Vector3(0.1, 0.1, 0.1), YELLOW, 3, 6)
		kit.tri(Vector3(0, CLIMB_TOP + 0.38, 0), Vector3(0, CLIMB_TOP + 0.2, 0), Vector3(0.35, CLIMB_TOP + 0.29, 0), BLUE)
		kit.tri(Vector3(0, CLIMB_TOP + 0.38, 0), Vector3(0.35, CLIMB_TOP + 0.29, 0), Vector3(0, CLIMB_TOP + 0.2, 0), BLUE)
		for c: Vector3 in corners:
			kit.box(Vector3(c.x, 0.1, c.z), Vector3(0.25, 0.2, 0.25), PropModels.STONE)
			_rope(kit, apex, c, RED, 0.05)
		# Rope net on the four faces: ropes from the apex down, rings across.
		for k in 4:
			var a: Vector3 = corners[k]
			var b: Vector3 = corners[(k + 1) % 4]
			_rope(kit, a, b, BLUE, 0.05)
			for i in range(1, 5):
				_rope(kit, apex, a.lerp(b, i / 5.0), RED)
			for i in range(1, 6):
				var t := i / 6.0
				_rope(kit, apex.lerp(a, t), apex.lerp(b, t), BLUE)
		return kit.commit())


# --- Sandbox things -------------------------------------------------------------------------

static func sandbox_big(size: Vector2) -> Mesh:
	return cached("sandbox_%.1fx%.1f" % [size.x, size.y], func() -> Mesh:
		var kit := MeshKit.new()
		var wood := PropModels.WOOD
		var top := PropModels.WOOD_LIGHT
		var hx := size.x * 0.5
		var hz := size.y * 0.5
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(0, 0.15, s * (hz - 0.15)), Vector3(size.x, 0.3, 0.3), wood, top)
			kit.box(Vector3(s * (hx - 0.15), 0.15, 0), Vector3(0.3, 0.3, size.y - 0.6), wood, top)
		kit.box(Vector3(0, 0.06, 0), Vector3(size.x - 0.6, 0.12, size.y - 0.6), SAND_DARK, SAND)
		# A few mounds and dug holes.
		var spots := [Vector2(-0.3, -0.25), Vector2(0.28, 0.2), Vector2(-0.15, 0.3), Vector2(0.32, -0.3)]
		for i in spots.size():
			var sp: Vector2 = spots[i]
			var p := Vector3(sp.x * (size.x - 1.0), 0.12, sp.y * (size.y - 1.0))
			if i % 2 == 0:
				kit.sphere(p, Vector3(0.45, 0.14, 0.38), SAND, 3, 7)
			else:
				kit.disc(p + Vector3(0, 0.003, 0), 0.3, 9, SAND_DARK.darkened(0.1))
		return kit.commit())


static func bucket(col: Color) -> Mesh:
	return cached("bucket_" + col.to_html(false), func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.22, 0.09, 0.12, 9, col, true, col.darkened(0.4))
		kit.torus(Vector3(0, 0.22, 0), 0.12, 0.012, 9, 3, col.lightened(0.2))
		var prev := Vector3(-0.12, 0.22, 0)
		for i in range(1, 6):
			var a := PI * i / 5.0
			var q := Vector3(-cos(a) * 0.12, 0.22 + sin(a) * 0.1, 0)
			kit.beam(prev, q, Vector2(0.012, 0.012), STEEL)
			prev = q
		return kit.commit())


static func spade(col: Color) -> Mesh:
	return cached("spade_" + col.to_html(false), func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(-0.08, 0.015, 0), Vector3(0.34, 0.025, 0.03), col)
		kit.box(Vector3(-0.27, 0.02, 0), Vector3(0.05, 0.035, 0.1), col)
		kit.box(Vector3(0.16, 0.012, 0), Vector3(0.16, 0.02, 0.13), col.lightened(0.1))
		return kit.commit())


static func sand_castle() -> Mesh:
	return cached("sand_castle", func() -> Mesh:
		var kit := MeshKit.new()
		var sand := SAND.darkened(0.06)
		kit.box(Vector3(0, 0.07, 0), Vector3(0.6, 0.14, 0.45), sand)
		kit.cylinder(Vector3(0, 0.14, 0), 0.22, 0.13, 0.11, 8, sand)
		for k in 4:
			var a := TAU * k / 4.0 + PI / 4
			kit.box(Vector3(cos(a) * 0.1, 0.39, sin(a) * 0.1), Vector3(0.05, 0.05, 0.05), sand)
		for c: Vector3 in [Vector3(-0.3, 0, -0.22), Vector3(0.3, 0, -0.22), Vector3(-0.3, 0, 0.22), Vector3(0.3, 0, 0.22)]:
			kit.cylinder(c, 0.18, 0.08, 0.06, 7, sand)
			kit.cylinder(c + Vector3(0, 0.18, 0), 0.06, 0.06, 0.0, 7, sand.darkened(0.05))
		kit.beam(Vector3(0, 0.36, 0), Vector3(0, 0.6, 0), Vector2(0.012, 0.012), PropModels.WOOD_DARK)
		kit.tri(Vector3(0, 0.6, 0), Vector3(0, 0.5, 0), Vector3(0.14, 0.55, 0), RED)
		kit.tri(Vector3(0, 0.6, 0), Vector3(0.14, 0.55, 0), Vector3(0, 0.5, 0), RED)
		return kit.commit())


static func toy_digger() -> Mesh:
	return cached("toy_digger", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.08, 0.28, 0.25, 10, PropModels.STONE_DARK)
		kit.cylinder(Vector3(0, 0.08, 0), 0.38, 0.06, 0.06, 8, STEEL)
		# Turntable seat with a backrest and two levers.
		kit.box(Vector3(0, 0.5, -0.1), Vector3(0.42, 0.08, 0.5), YELLOW)
		kit.box(Vector3(0, 0.56, -0.12), Vector3(0.3, 0.05, 0.3), RUBBER)
		kit.box(Vector3(0, 0.75, -0.3), Vector3(0.32, 0.36, 0.05), YELLOW)
		for x: float in [-0.1, 0.1]:
			kit.beam(Vector3(x, 0.54, 0.12), Vector3(x, 0.78, 0.2), Vector2(0.025, 0.025), RUBBER)
			kit.sphere(Vector3(x, 0.8, 0.21), Vector3(0.035, 0.035, 0.035), RED, 2, 5)
		# Arm and scoop.
		kit.beam(Vector3(0, 0.55, 0.15), Vector3(0, 0.88, 0.6), Vector2(0.09, 0.09), YELLOW)
		kit.beam(Vector3(0, 0.88, 0.6), Vector3(0, 0.3, 0.98), Vector2(0.08, 0.08), YELLOW)
		kit.push(Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, 0.22, 1.03)))
		kit.box(Vector3.ZERO, Vector3(0.3, 0.16, 0.18), STEEL)
		kit.pop()
		return kit.commit())


static func water_pump() -> Mesh:
	return cached("water_pump", func() -> Mesh:
		var kit := MeshKit.new()
		var iron := Color("2f6b45")
		kit.box(Vector3(0, 0.1, -0.1), Vector3(0.4, 0.2, 0.4), PropModels.STONE)
		kit.cylinder(Vector3(0, 0.2, -0.1), 0.85, 0.1, 0.085, 8, iron)
		kit.sphere(Vector3(0, 1.08, -0.1), Vector3(0.1, 0.08, 0.1), iron.lightened(0.1), 3, 6)
		kit.beam(Vector3(0, 0.82, -0.04), Vector3(0, 0.74, 0.22), Vector2(0.06, 0.06), iron)
		kit.beam(Vector3(0, 1.0, -0.15), Vector3(0, 1.25, -0.55), Vector2(0.04, 0.04), iron.darkened(0.2))
		kit.sphere(Vector3(0, 1.26, -0.57), Vector3(0.04, 0.04, 0.04), RUBBER, 2, 5)
		# Trough in front.
		kit.box(Vector3(0, 0.14, 0.42), Vector3(0.9, 0.28, 0.5), PropModels.STONE_DARK, PropModels.STONE_LIGHT)
		kit.box(Vector3(0, 0.282, 0.42), Vector3(0.74, 0.004, 0.34), Color("5f9ec4"))
		return kit.commit())


# --- Fence, sign, chest ---------------------------------------------------------------------

static func play_fence(length: float) -> Mesh:
	return cached("play_fence_%.1f" % length, func() -> Mesh:
		var kit := MeshKit.new()
		var posts := maxi(1, int(round(length / 2.0)))
		for i in posts + 1:
			var x := length * i / posts
			kit.box(Vector3(x, 0.47, 0), Vector3(0.1, 0.94, 0.1), PropModels.WOOD_DARK)
			kit.cylinder(Vector3(x, 0.94, 0), 0.08, 0.07, 0.0, 6, RED)
		for y: float in [0.25, 0.65]:
			kit.box(Vector3(length * 0.5, y, -0.06), Vector3(length, 0.07, 0.03), PropModels.WOOD)
		var n := int(length / 0.18)
		for i in n:
			var x := (i + 0.5) * length / n
			var col: Color = COLOURS[i % 4]
			kit.box(Vector3(x, 0.38, -0.085), Vector3(0.1, 0.72, 0.025), col)
			kit.tri(Vector3(x - 0.05, 0.74, -0.072), Vector3(x + 0.05, 0.74, -0.072), Vector3(x, 0.85, -0.072), col)
			kit.tri(Vector3(x + 0.05, 0.74, -0.098), Vector3(x - 0.05, 0.74, -0.098), Vector3(x, 0.85, -0.098), col)
		return kit.commit())


static func sign_board() -> Mesh:
	return cached("sign_board", func() -> Mesh:
		var kit := MeshKit.new()
		for x: float in [-1.1, 1.1]:
			kit.box(Vector3(x, 1.08, 0), Vector3(0.1, 2.16, 0.1), PropModels.WOOD_DARK)
		kit.box(Vector3(0, 1.75, 0), Vector3(2.4, 0.6, 0.08), PropModels.WOOD_LIGHT)
		kit.box(Vector3(0, 2.12, 0), Vector3(2.6, 0.06, 0.24), RED)
		# A sun on the left end, a flower on the right one.
		_disc_z(kit, Vector3(-0.98, 1.75, 0.043), 0.12, 10, YELLOW)
		for k in 8:
			var a := TAU * k / 8.0
			var d := Vector3(cos(a), sin(a), 0)
			kit.tri(Vector3(-0.98, 1.75, 0.044) + d * 0.2 + Vector3(-d.y, d.x, 0) * 0.04,
				Vector3(-0.98, 1.75, 0.044) + d * 0.2 - Vector3(-d.y, d.x, 0) * 0.04,
				Vector3(-0.98, 1.75, 0.044) + d * 0.27, ORANGE)
		for k in 5:
			var a := TAU * k / 5.0
			_disc_z(kit, Vector3(0.98 + cos(a) * 0.09, 1.75 + sin(a) * 0.09, 0.043), 0.07, 8, RED)
		_disc_z(kit, Vector3(0.98, 1.75, 0.045), 0.06, 8, YELLOW)
		return kit.commit())


static func treasure_chest(open: bool) -> Mesh:
	return cached("treasure_chest_%s" % ("open" if open else "shut"), func() -> Mesh:
		var kit := MeshKit.new()
		var wood := Color("5e3d22")
		var iron := Color("3a3a3e")
		var gold := Color("e8b830")
		kit.box(Vector3(0, 0.16, 0), Vector3(0.8, 0.32, 0.5), wood)
		for x: float in [-0.28, 0.28]:
			kit.box(Vector3(x, 0.16, 0), Vector3(0.06, 0.33, 0.52), iron)
		# Side handles.
		for s: float in [-1.0, 1.0]:
			kit.push(Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(s * 0.41, 0.2, 0)))
			kit.torus(Vector3.ZERO, 0.06, 0.012, 8, 3, iron)
			kit.pop()
		if open:
			kit.box(Vector3(0, 0.3, 0), Vector3(0.7, 0.04, 0.42), gold)
			for i in 9:
				var p := Vector3(-0.28 + (i % 5) * 0.14, 0.33 + (i / 5) * 0.03, -0.1 + (i % 3) * 0.1)
				kit.cylinder(p, 0.02, 0.05, 0.05, 8, gold.lightened(0.1))
			kit.sphere(Vector3(0.12, 0.36, 0.05), Vector3(0.05, 0.05, 0.05), Color("d8304a"), 2, 6)
			# Lid tilted back about the hinge.
			kit.push(Transform3D(Basis(Vector3.RIGHT, -1.9), Vector3(0, 0.32, -0.25)))
			kit.box(Vector3(0, 0.04, 0.25), Vector3(0.82, 0.08, 0.5), wood)
			for x: float in [-0.28, 0.28]:
				kit.box(Vector3(x, 0.04, 0.25), Vector3(0.06, 0.09, 0.52), iron)
			kit.pop()
		else:
			kit.rod(Vector3(-0.4, 0.32, 0), Vector3(0.4, 0.32, 0), 0.25, 0.25, 10, wood)
			for x: float in [-0.28, 0.28]:
				kit.rod(Vector3(x - 0.03, 0.32, 0), Vector3(x + 0.03, 0.32, 0), 0.26, 0.26, 10, iron)
			kit.box(Vector3(0, 0.3, 0.26), Vector3(0.14, 0.16, 0.04), iron)
			kit.box(Vector3(0, 0.28, 0.285), Vector3(0.03, 0.06, 0.01), Color("111111"))
		return kit.commit())

class_name PropModels
extends RefCounted
## Procedural park furniture and buildings. Origins sit on the ground; "front"
## faces +Z unless stated otherwise.

const IRON := Color("2f3b33")
const WOOD := Color("9a6a3e")
const WOOD_LIGHT := Color("b98a57")
const WOOD_DARK := Color("6e4a2c")
const STONE := Color("a8a196")
const STONE_DARK := Color("8a847a")
const STONE_LIGHT := Color("c4bdb1")
const WHITE := Color("f1eee6")
const PARK_GREEN := Color("2e5e44")
const GLASS_WARM := Color("ffd98a")


static func cached(key: String, builder: Callable) -> Mesh:
	return NatureModels.cached("prop_" + key, builder)


# --- Seating ---------------------------------------------------------------

## Park bench, 1.8 m long; seats face +Z. style: 0 classic iron, 1 wooden, 2 stone.
static func bench(style: int) -> Mesh:
	return cached("bench_%d" % style, func() -> Mesh:
		var kit := MeshKit.new()
		var slat: Color = [WOOD, Color("8a5a34"), Color("5f7f4f")][style % 3]
		var frame: Color = [IRON, WOOD_DARK, STONE][style % 3]
		for side: float in [-0.82, 0.82]:
			if style == 2:
				kit.box(Vector3(side, 0.21, 0.0), Vector3(0.22, 0.42, 0.46), STONE, STONE_LIGHT)
			else:
				kit.beam(Vector3(side, 0, 0.18), Vector3(side, 0.42, 0.12), Vector2(0.07, 0.07), frame)
				kit.beam(Vector3(side, 0, -0.2), Vector3(side, 0.85, -0.3), Vector2(0.07, 0.07), frame)
				kit.beam(Vector3(side, 0.42, 0.2), Vector3(side, 0.42, -0.24), Vector2(0.06, 0.06), frame)
				# Armrest.
				kit.beam(Vector3(side, 0.62, 0.18), Vector3(side, 0.62, -0.26), Vector2(0.06, 0.05), frame)
				kit.beam(Vector3(side, 0.42, 0.16), Vector3(side, 0.62, 0.18), Vector2(0.05, 0.05), frame)
		for i in 4:
			var z := 0.17 - i * 0.12
			kit.box(Vector3(0, 0.45, z), Vector3(1.8, 0.04, 0.1), slat)
		if style != 2:
			for i in 3:
				var y := 0.58 + i * 0.11
				kit.push(Transform3D(Basis(Vector3.RIGHT, -0.22), Vector3(0, y, -0.26 - i * 0.02)))
				kit.box(Vector3.ZERO, Vector3(1.8, 0.09, 0.035), slat)
				kit.pop()
		return kit.commit())


## Picnic table with attached benches along x; seats face the table (±Z).
static func picnic_table() -> Mesh:
	return cached("picnic_table", func() -> Mesh:
		var kit := MeshKit.new()
		for i in 5:
			kit.box(Vector3(0, 0.74, -0.32 + i * 0.16), Vector3(1.9, 0.04, 0.14), WOOD_LIGHT)
		for side: float in [-1.0, 1.0]:
			kit.box(Vector3(0, 0.44, side * 0.72), Vector3(1.9, 0.04, 0.28), WOOD_LIGHT)
			for x: float in [-0.75, 0.75]:
				kit.beam(Vector3(x, 0, side * 0.85), Vector3(x, 0.74, side * 0.05), Vector2(0.08, 0.06), WOOD)
		return kit.commit())


# --- Lighting and furniture --------------------------------------------------

static func lamp() -> Mesh:
	return cached("lamp", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.35, 0.18, 0.12, 8, IRON)
		kit.cylinder(Vector3(0, 0.35, 0), 2.9, 0.06, 0.05, 6, IRON)
		kit.torus(Vector3(0, 1.4, 0), 0.07, 0.025, 8, 4, IRON)
		kit.cylinder(Vector3(0, 3.2, 0), 0.08, 0.16, 0.2, 6, IRON)
		kit.use("glow")
		kit.cylinder(Vector3(0, 3.28, 0), 0.42, 0.18, 0.25, 6, GLASS_WARM)
		kit.use("solid")
		kit.cylinder(Vector3(0, 3.7, 0), 0.22, 0.3, 0.05, 6, IRON)
		kit.sphere(Vector3(0, 3.95, 0), Vector3(0.05, 0.05, 0.05), IRON, 2, 4)
		return kit.commit())


static func bin() -> Mesh:
	return cached("bin", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.8, 0.24, 0.27, 9, PARK_GREEN)
		kit.torus(Vector3(0, 0.8, 0), 0.27, 0.03, 9, 4, IRON)
		kit.cylinder(Vector3(0, 0.82, 0), 0.06, 0.29, 0.22, 9, PARK_GREEN.darkened(0.2))
		return kit.commit())


static func signpost() -> Mesh:
	return cached("signpost", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 2.6, 0.06, 0.05, 6, WOOD_DARK)
		kit.cylinder(Vector3(0, 2.6, 0), 0.15, 0.09, 0.0, 6, WOOD_DARK)
		return kit.commit())


## Arrow board for signposts, 1.3 m long, pointing +X.
static func sign_arrow() -> Mesh:
	return cached("sign_arrow", func() -> Mesh:
		var kit := MeshKit.new()
		kit.prism(PackedVector2Array([Vector2(0, -0.04), Vector2(1.1, -0.04), Vector2(1.3, 0.0),
			Vector2(1.1, 0.04), Vector2(0, 0.04)]), -0.13, 0.13, Color("f3ead2"))
		return kit.commit())


static func info_board() -> Mesh:
	return cached("info_board", func() -> Mesh:
		var kit := MeshKit.new()
		for x: float in [-0.9, 0.9]:
			kit.box(Vector3(x, 1.0, 0), Vector3(0.1, 2.0, 0.1), WOOD_DARK)
		kit.box(Vector3(0, 1.35, -0.03), Vector3(1.9, 1.2, 0.05), WOOD)
		kit.push(Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 2.05, 0)))
		kit.box(Vector3.ZERO, Vector3(2.1, 0.06, 0.5), Color("7a3b2c"))
		kit.pop()
		return kit.commit())


static func bike_rack() -> Mesh:
	return cached("bike_rack", func() -> Mesh:
		var kit := MeshKit.new()
		for i in 4:
			var x := -1.2 + i * 0.8
			kit.beam(Vector3(x, 0, -0.3), Vector3(x, 0.7, -0.3), Vector2(0.04, 0.04), IRON)
			kit.beam(Vector3(x, 0, 0.3), Vector3(x, 0.7, 0.3), Vector2(0.04, 0.04), IRON)
			kit.beam(Vector3(x, 0.7, -0.32), Vector3(x, 0.7, 0.32), Vector2(0.04, 0.04), IRON)
		return kit.commit())


static func bicycle(color: Color) -> Mesh:
	return cached("bicycle_%s" % color.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		for z: float in [-0.5, 0.5]:
			kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.34, z)))
			kit.torus(Vector3.ZERO, 0.32, 0.025, 12, 3, Color("222222"))
			kit.pop()
		kit.beam(Vector3(0, 0.34, -0.5), Vector3(0, 0.75, -0.1), Vector2(0.04, 0.04), color)
		kit.beam(Vector3(0, 0.34, 0.5), Vector3(0, 0.82, 0.38), Vector2(0.04, 0.04), color)
		kit.beam(Vector3(0, 0.75, -0.12), Vector3(0, 0.8, 0.38), Vector2(0.04, 0.04), color)
		kit.beam(Vector3(0, 0.34, -0.1), Vector3(0, 0.75, -0.12), Vector2(0.04, 0.04), color)
		kit.box(Vector3(0, 0.82, -0.14), Vector3(0.12, 0.04, 0.22), Color("222222"))
		kit.beam(Vector3(-0.25, 0.95, 0.38), Vector3(0.25, 0.95, 0.38), Vector2(0.03, 0.03), Color("333333"))
		return kit.commit())


# --- Landmarks -----------------------------------------------------------------

static func pavilion() -> Mesh:
	return cached("pavilion", func() -> Mesh:
		var kit := MeshKit.new()
		var r := 5.2
		var base := PackedVector2Array()
		for i in 8:
			var a := TAU * i / 8.0 + TAU / 16.0
			base.append(Vector2(cos(a), sin(a)) * (r + 0.4))
		kit.prism(base, -0.4, 0.6, STONE, STONE_LIGHT)
		var floor_poly := PackedVector2Array()
		for i in 8:
			var a := TAU * i / 8.0 + TAU / 16.0
			floor_poly.append(Vector2(cos(a), sin(a)) * r)
		kit.prism(floor_poly, 0.6, 0.66, WOOD_LIGHT)
		# Steps at the front (+Z).
		for s in 3:
			kit.box(Vector3(0, 0.1 + s * 0.2, r + 1.15 - s * 0.35), Vector3(2.6, 0.2, 0.35), STONE_LIGHT)
		for i in 8:
			var a := TAU * i / 8.0 + TAU / 16.0
			var p := Vector3(cos(a) * (r - 0.25), 0.66, sin(a) * (r - 0.25))
			kit.cylinder(p, 0.15, 0.2, 0.18, 6, WHITE)
			kit.cylinder(p + Vector3(0, 0.15, 0), 3.0, 0.12, 0.1, 6, WHITE)
			kit.cylinder(p + Vector3(0, 3.15, 0), 0.15, 0.13, 0.2, 6, WHITE)
			# Railing between columns, leaving the front open.
			var a2 := TAU * (i + 1) / 8.0 + TAU / 16.0
			var q := Vector3(cos(a2) * (r - 0.25), 0.66, sin(a2) * (r - 0.25))
			var mid := (a + a2) * 0.5
			if absf(angle_difference(mid, PI / 2)) > 0.3:
				kit.beam(p + Vector3(0, 0.9, 0), q + Vector3(0, 0.9, 0), Vector2(0.08, 0.08), WHITE)
				for k in 5:
					var t := (k + 1) / 6.0
					var b := p.lerp(q, t)
					kit.beam(b, b + Vector3(0, 0.9, 0), Vector2(0.04, 0.04), WHITE)
			kit.beam(p + Vector3(0, 3.3, 0), q + Vector3(0, 3.3, 0), Vector2(0.18, 0.2), WHITE)
		# Roof: two-stage copper roof with spire.
		var roof := Color("5fa08a")
		kit.lathe(PackedVector2Array([Vector2(r + 0.9, 3.35), Vector2(r * 0.55, 4.8), Vector2(1.0, 5.5), Vector2(0.0, 6.4)]),
			8, roof, TAU / 16.0, [roof, roof.darkened(0.08), roof.darkened(0.14)])
		kit.lathe(PackedVector2Array([Vector2(0.0, 3.3), Vector2(r + 0.9, 3.35)]), 8, WHITE, TAU / 16.0)
		kit.cylinder(Vector3(0, 6.3, 0), 0.9, 0.06, 0.03, 5, Color("c9a640"))
		kit.sphere(Vector3(0, 7.25, 0), Vector3(0.14, 0.14, 0.14), Color("e2c050"), 3, 6)
		# Music stands.
		for x: float in [-1.2, 0.0, 1.2]:
			kit.cylinder(Vector3(x, 0.66, -1.5), 1.0, 0.02, 0.02, 4, IRON)
			kit.push(Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(x, 1.7, -1.5)))
			kit.box(Vector3.ZERO, Vector3(0.45, 0.32, 0.02), IRON)
			kit.pop()
		return kit.commit())


static func fountain() -> Mesh:
	return cached("fountain", func() -> Mesh:
		var kit := MeshKit.new()
		kit.lathe(PackedVector2Array([Vector2(3.6, 0.0), Vector2(3.7, 0.55), Vector2(3.95, 0.62),
			Vector2(3.95, 0.72), Vector2(3.3, 0.72), Vector2(3.3, 0.1), Vector2(0.0, 0.1)]), 16, STONE, 0.0,
			[STONE, STONE_LIGHT, STONE_LIGHT, STONE_LIGHT, STONE_DARK, STONE_DARK])
		kit.lathe(PackedVector2Array([Vector2(0.7, 0.1), Vector2(0.5, 1.2), Vector2(0.35, 1.5),
			Vector2(1.6, 1.7), Vector2(1.7, 1.95), Vector2(0.4, 1.95), Vector2(0.25, 2.6),
			Vector2(0.9, 2.75), Vector2(0.95, 2.95), Vector2(0.2, 2.95), Vector2(0.12, 3.4), Vector2(0.0, 3.55)]),
			12, STONE_LIGHT)
		kit.use("water")
		kit.disc(Vector3(0, 0.55, 0), 3.32, 16, Color("3d8aa0"))
		kit.disc(Vector3(0, 1.88, 0), 1.6, 12, Color("3d8aa0"))
		kit.disc(Vector3(0, 2.9, 0), 0.9, 10, Color("3d8aa0"))
		return kit.commit())


static func duck_statue() -> Mesh:
	return cached("duck_statue", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.6), STONE, STONE_LIGHT)
		kit.box(Vector3(0, 1.25, 0), Vector3(1.8, 0.1, 1.8), STONE_LIGHT)
		kit.box(Vector3(0, 0.62, 0.81), Vector3(1.0, 0.4, 0.02), Color("b08d3c"))
		var bronze := Color("8a6a3a")
		var patina := Color("6f9a82")
		kit.sphere(Vector3(0, 2.0, 0), Vector3(0.75, 0.55, 1.0), bronze, 4, 8, 0.05, 3, patina)
		kit.sphere(Vector3(0, 2.75, 0.65), Vector3(0.38, 0.4, 0.38), bronze, 4, 8)
		kit.push(Transform3D(Basis(), Vector3(0, 2.7, 1.0)))
		kit.box(Vector3(0, 0, 0.12), Vector3(0.3, 0.1, 0.3), Color("b08d3c"))
		kit.pop()
		kit.sphere(Vector3(0, 2.2, -0.95), Vector3(0.3, 0.25, 0.3), bronze, 3, 6)
		for x: float in [-0.2, 0.2]:
			kit.sphere(Vector3(x, 2.85, 0.95), Vector3(0.05, 0.05, 0.05), Color("2a2a2a"), 2, 4)
		# A bronze bow tie, for dignity.
		kit.box(Vector3(0, 2.4, 0.95), Vector3(0.36, 0.14, 0.08), Color("4f4130"))
		return kit.commit())


# --- Bridges -----------------------------------------------------------------

## Bridge mesh along local +X from 0 to `length`; deck height follows h0 → h1 + arch.
static func bridge(length: float, width: float, arch: float, h0: float, h1: float, style: String) -> Mesh:
	var kit := MeshKit.new()
	var n := 14
	var hw := width * 0.5
	var stone := style == "stone"
	var deck_col := STONE_LIGHT if stone else WOOD_LIGHT
	var side_col := STONE if stone else WOOD
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var x0 := t0 * length
		var x1 := t1 * length
		var y0 := lerpf(h0, h1, t0) + arch * sin(PI * t0) + ParkMap.deck_lift(t0, length)
		var y1 := lerpf(h0, h1, t1) + arch * sin(PI * t1) + ParkMap.deck_lift(t1, length)
		if stone:
			var under0 := lerpf(h0, h1, t0) - 0.6 + (arch + 0.55) * sin(PI * t0)
			var under1 := lerpf(h0, h1, t1) - 0.6 + (arch + 0.55) * sin(PI * t1)
			kit.use("cobbles")
			kit.quad(Vector3(x0, y0, -hw), Vector3(x0, y0, hw), Vector3(x1, y1, hw), Vector3(x1, y1, -hw), deck_col)
			kit.use("masonry")
			kit.quad(Vector3(x0, under0, -hw), Vector3(x1, under1, -hw), Vector3(x1, under1, hw), Vector3(x0, under0, hw), STONE_DARK)
			for side: float in [-1.0, 1.0]:
				var z := side * (hw + 0.25)
				var top0 := y0 + 0.75
				var top1 := y1 + 0.75
				var a := Vector3(x0, under0 - 0.05, z)
				var b := Vector3(x1, under1 - 0.05, z)
				var c := Vector3(x1, top1, z)
				var d := Vector3(x0, top0, z)
				if side > 0:
					kit.quad(a, b, c, d, side_col)
				else:
					kit.quad(a, d, c, b, side_col)
				# Inner parapet face and cap.
				var zi := side * hw
				if side > 0:
					kit.quad(Vector3(x0, y0, zi), Vector3(x0, top0, zi), Vector3(x1, top1, zi), Vector3(x1, y1, zi), side_col)
				else:
					kit.quad(Vector3(x0, y0, zi), Vector3(x1, y1, zi), Vector3(x1, top1, zi), Vector3(x0, top0, zi), side_col)
				if side > 0:
					kit.quad(Vector3(x0, top0, zi), Vector3(x0, top0 + 0.02, z), Vector3(x1, top1 + 0.02, z), Vector3(x1, top1, zi), STONE_LIGHT)
				else:
					kit.quad(Vector3(x0, top0, zi), Vector3(x1, top1, zi), Vector3(x1, top1 + 0.02, z), Vector3(x0, top0 + 0.02, z), STONE_LIGHT)
				# Close the parapet at both ends of the bridge.
				for end: Array in ([[x0, y0, under0, -1.0]] if i == 0 else []) + ([[x1, y1, under1, 1.0]] if i == n - 1 else []):
					var ex: float = end[0]
					var lo: float = end[2] - 0.05
					var hi: float = end[1] + 0.77
					var zo := Vector3(ex, 0, z)
					var zn := Vector3(ex, 0, zi)
					var q := [zn + Vector3(0, lo, 0), zo + Vector3(0, lo, 0), zo + Vector3(0, hi, 0), zn + Vector3(0, hi, 0)]
					if (end[3] as float) * side < 0.0:
						kit.quad(q[0], q[1], q[2], q[3], side_col)
					else:
						kit.quad(q[0], q[3], q[2], q[1], side_col)
		else:
			# Wooden planks with gaps.
			kit.use("planks")
			var xm := (x0 + x1) * 0.5
			kit.push(Transform3D(Basis(Vector3.BACK, atan2(y1 - y0, x1 - x0)), Vector3(xm, (y0 + y1) * 0.5 - 0.03, 0)))
			kit.box(Vector3.ZERO, Vector3((x1 - x0) * 0.86, 0.07, width), deck_col.darkened(0.05 * (i % 2)))
			kit.pop()
	kit.use("solid")
	if not stone:
		for side: float in [-1.0, 1.0]:
			var z := side * (hw - 0.05)
			for b: float in [-0.3, 0.3]:
				kit.beam(Vector3(0, h0 - 0.1, b * width), Vector3(length, h1 - 0.1, b * width), Vector2(0.14, 0.2), WOOD_DARK)
			var posts := 5
			var prev := Vector3.ZERO
			for k in posts + 1:
				var t := float(k) / posts
				var y := lerpf(h0, h1, t) + arch * sin(PI * t) + ParkMap.deck_lift(t, length)
				var p := Vector3(t * length, y, z)
				kit.beam(p, p + Vector3(0, 0.95, 0), Vector2(0.09, 0.09), WOOD_DARK)
				if k > 0:
					kit.beam(prev + Vector3(0, 0.95, 0), p + Vector3(0, 0.95, 0), Vector2(0.08, 0.08), WOOD)
					kit.beam(prev + Vector3(0, 0.5, 0), p + Vector3(0, 0.5, 0), Vector2(0.05, 0.05), WOOD)
				prev = p
		# Supports into the creek bed.
		for t: float in [0.33, 0.66]:
			var y := lerpf(h0, h1, t) + arch * sin(PI * t)
			for side: float in [-1.0, 1.0]:
				kit.beam(Vector3(t * length, ParkMap.BED_Y, side * hw * 0.7), Vector3(t * length, y, side * hw * 0.7), Vector2(0.16, 0.16), WOOD_DARK)
	return kit.commit()


static func pier(length: float, width: float, height: float) -> Mesh:
	var kit := MeshKit.new()
	var n := int(length / 0.35)
	for i in n:
		var z := (i + 0.5) * length / n
		kit.box(Vector3(0, height, z), Vector3(width, 0.06, length / n * 0.85), WOOD_LIGHT.darkened(0.06 * (i % 3)))
	for z: float in [0.4, length * 0.5, length - 0.3]:
		for x: float in [-width * 0.45, width * 0.45]:
			kit.cylinder(Vector3(x, ParkMap.BED_Y, z), height - ParkMap.BED_Y + 0.25, 0.1, 0.1, 6, WOOD_DARK)
	kit.beam(Vector3(-width * 0.5, height - 0.08, 0), Vector3(-width * 0.5, height - 0.08, length), Vector2(0.08, 0.12), WOOD_DARK)
	kit.beam(Vector3(width * 0.5, height - 0.08, 0), Vector3(width * 0.5, height - 0.08, length), Vector2(0.08, 0.12), WOOD_DARK)
	return kit.commit()


static func stepping_stone() -> Mesh:
	return cached("stepping_stone", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3(0, -0.7, 0), 0.9, 0.62, 0.52, 7, STONE_DARK, true, STONE)
		return kit.commit())


static func rowboat() -> Mesh:
	return cached("rowboat", func() -> Mesh:
		var kit := MeshKit.new()
		var hull := Color("c8553d")
		var prof := [Vector2(0.0, 1.4), Vector2(0.5, 1.0), Vector2(0.6, 0.0), Vector2(0.5, -1.0), Vector2(0.0, -1.3)]
		for i in prof.size() - 1:
			var a: Vector2 = prof[i]
			var b: Vector2 = prof[i + 1]
			for side: float in [-1.0, 1.0]:
				var p0 := Vector3(a.x * side, 0.35, a.y)
				var p1 := Vector3(b.x * side, 0.35, b.y)
				var q0 := Vector3(a.x * side * 0.6, 0.0, a.y * 0.92)
				var q1 := Vector3(b.x * side * 0.6, 0.0, b.y * 0.92)
				if side > 0:
					kit.quad(q0, q1, p1, p0, hull)
				else:
					kit.quad(q0, p0, p1, q1, hull)
				kit.beam(p0, p1, Vector2(0.06, 0.06), WHITE)
		kit.box(Vector3(0, 0.05, 0), Vector3(0.7, 0.04, 2.2), WOOD)
		kit.box(Vector3(0, 0.25, 0.2), Vector3(1.0, 0.05, 0.3), WOOD_LIGHT)
		kit.beam(Vector3(-0.5, 0.32, 0.0), Vector3(-1.2, 0.0, -0.4), Vector2(0.04, 0.04), WOOD_LIGHT)
		kit.beam(Vector3(0.5, 0.32, 0.0), Vector3(1.2, 0.0, -0.4), Vector2(0.04, 0.04), WOOD_LIGHT)
		return kit.commit())


# --- Food stands ---------------------------------------------------------------

static func _stripes(kit: MeshKit, w: float, d: float, y: float, slope: float, c1: Color, c2: Color, count: int) -> void:
	for i in count:
		var x0 := -w * 0.5 + w * i / count
		var x1 := -w * 0.5 + w * (i + 1) / count
		var col := c1 if i % 2 == 0 else c2
		kit.quad(Vector3(x0, y, 0), Vector3(x0, y - slope, d), Vector3(x1, y - slope, d), Vector3(x1, y, 0), col)
		kit.quad(Vector3(x0, y - 0.01, 0), Vector3(x1, y - 0.01, 0), Vector3(x1, y - slope - 0.01, d), Vector3(x0, y - slope - 0.01, d), col.darkened(0.3))
		kit.box(Vector3((x0 + x1) * 0.5, y - slope - 0.1, d), Vector3(x1 - x0, 0.2, 0.02), col)


static func donut_stand() -> Mesh:
	return cached("donut_stand", func() -> Mesh:
		var kit := MeshKit.new()
		var pink := Color("f28db2")
		# Hollow booth with an open window: the vendor stands inside, visible from the front.
		kit.box(Vector3(0, 1.2, -0.95), Vector3(2.8, 2.4, 0.1), WHITE)
		for x: float in [-1.35, 1.35]:
			kit.box(Vector3(x, 1.2, 0), Vector3(0.1, 2.4, 2.0), WHITE)
		kit.box(Vector3(0, 0.5, 0.95), Vector3(2.8, 1.0, 0.1), WHITE)
		kit.box(Vector3(0, 2.25, 0.95), Vector3(2.8, 0.3, 0.1), WHITE)
		kit.box(Vector3(0, 0.02, 0), Vector3(2.6, 0.04, 1.8), Color("8a7a6a"))
		kit.box(Vector3(0, 0.5, 1.05), Vector3(2.8, 1.0, 0.1), pink)
		kit.box(Vector3(0, 1.02, 1.15), Vector3(2.9, 0.06, 0.4), WOOD_LIGHT)
		kit.box(Vector3(0, 2.45, 0), Vector3(3.0, 0.1, 2.2), pink.darkened(0.2))
		kit.translate(Vector3(0, 2.4, 1.0))
		_stripes(kit, 3.0, 0.9, 0.0, 0.35, pink, WHITE, 8)
		kit.pop()
		# Donuts on the counter.
		for i in 5:
			kit.push(Transform3D(Basis(), Vector3(-1.0 + i * 0.5, 1.1, 1.2)))
			kit.torus(Vector3.ZERO, 0.1, 0.05, 8, 4, [pink, Color("6b3e26"), Color("f5e6c8")][i % 3])
			kit.pop()
		return kit.commit())


## Giant rotating donut sign (origin = donut centre).
static func giant_donut() -> Mesh:
	return cached("giant_donut", func() -> Mesh:
		var kit := MeshKit.new()
		var pink := Color("f28db2")
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
		kit.torus(Vector3.ZERO, 0.7, 0.35, 16, 8, Color("d9a35c"))
		kit.pop()
		for side: float in [1.0, -1.0]:
			kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.09 * side)))
			kit.torus(Vector3.ZERO, 0.7, 0.29, 16, 5, pink)
			kit.pop()
		var sprinkles := [Color("ffffff"), Color("5ac8fa"), Color("ffd60a"), Color("34c759")]
		for side: float in [1.0, -1.0]:
			for i in 18:
				var a := TAU * i / 18.0
				var r := 0.7 + 0.15 * sin(i * 2.3)
				kit.box(Vector3(cos(a) * r, sin(a) * r, 0.39 * side), Vector3(0.1, 0.03, 0.03), sprinkles[i % 4])
		kit.cylinder(Vector3(0, -1.2, 0), 0.5, 0.04, 0.04, 5, Color("cccccc"))
		return kit.commit())


## Street food cart with umbrella; the sign and colours depend on the stand
## ("hotdog_stand", "icecream_cart", "fries_stand").
static func food_cart(kind: String) -> Mesh:
	return cached("cart_" + kind, func() -> Mesh:
		var kit := MeshKit.new()
		var red := Color("d8402e")
		var yellow := Color("f4c542")
		var c1: Color = {"hotdog_stand": red, "icecream_cart": Color("f7a8c8"), "fries_stand": Color("e8402e")}[kind]
		var c2: Color = {"hotdog_stand": yellow, "icecream_cart": Color("8fd3e8"), "fries_stand": WHITE}[kind]
		var body: Color = {"hotdog_stand": Color("d9dde0"), "icecream_cart": Color("f4f0e6"), "fries_stand": Color("f4d35e")}[kind]
		kit.box(Vector3(0, 0.95, 0), Vector3(2.2, 0.9, 1.1), body, body.darkened(0.1))
		kit.box(Vector3(0, 0.75, 0.56), Vector3(2.2, 0.3, 0.02), c1)
		for x: float in [-0.8, 0.8]:
			kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(x, 0.32, 0.6)))
			kit.torus(Vector3.ZERO, 0.24, 0.07, 10, 4, Color("222222"))
			kit.pop()
		kit.box(Vector3(-1.2, 0.3, 0.0), Vector3(0.1, 0.6, 0.1), Color("777777"))
		kit.cylinder(Vector3(0, 1.4, 0), 1.7, 0.04, 0.04, 5, Color("cccccc"))
		# Umbrella.
		var n := 10
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var col := c1 if i % 2 == 0 else c2
			var top := Vector3(0, 3.35, 0)
			kit.tri(top, Vector3(cos(a1) * 1.6, 2.85, sin(a1) * 1.6), Vector3(cos(a0) * 1.6, 2.85, sin(a0) * 1.6), col)
			kit.tri(top - Vector3(0, 0.02, 0), Vector3(cos(a0) * 1.6, 2.83, sin(a0) * 1.6), Vector3(cos(a1) * 1.6, 2.83, sin(a1) * 1.6), col.darkened(0.3))
		# Sign on top of the cart.
		match kind:
			"hotdog_stand":
				kit.rod(Vector3(-0.5, 1.75, 0), Vector3(0.5, 1.75, 0), 0.16, 0.16, 8, Color("e0b070"))
				kit.rod(Vector3(-0.6, 1.8, 0), Vector3(0.6, 1.8, 0), 0.09, 0.09, 6, Color("a8432e"))
				for i in 5:
					kit.box(Vector3(-0.4 + i * 0.2, 1.9, 0), Vector3(0.1, 0.03, 0.05), yellow)
			"icecream_cart":
				kit.cylinder(Vector3(0, 1.4, 0), 0.7, 0.0, 0.28, 8, Color("d9a35c"))
				kit.sphere(Vector3(0, 2.2, 0), Vector3(0.3, 0.3, 0.3), Color("f7c6d9"), 3, 8)
				kit.sphere(Vector3(0, 2.55, 0), Vector3(0.24, 0.24, 0.24), Color("6b3e26"), 3, 8)
				# Ice cream tubs in the counter.
				for i in 4:
					kit.box(Vector3(-0.6 + i * 0.4, 1.42, 0.2), Vector3(0.3, 0.06, 0.3), [Color("f7c6d9"), Color("fff3c0"), Color("6b3e26"), Color("9fe0a0")][i])
			"fries_stand":
				kit.cylinder(Vector3(0, 1.4, 0), 0.6, 0.12, 0.32, 6, red)
				for i in 9:
					var x := -0.2 + (i % 5) * 0.1
					var z := -0.08 + (i / 5) * 0.14
					kit.box(Vector3(x, 2.1 + (i % 3) * 0.05, z), Vector3(0.06, 0.32, 0.06), Color("f6cf4a"))
		return kit.commit())


static func kiosk() -> Mesh:
	return cached("kiosk", func() -> Mesh:
		var kit := MeshKit.new()
		var blue := Color("3f7cc2")
		# Hollow kiosk with an open sales window: the vendor stands inside, visible from the front.
		var wall := Color("e9dcc0")
		kit.box(Vector3(0, 1.4, -1.45), Vector3(4.0, 2.8, 0.1), wall)
		for x: float in [-1.95, 1.95]:
			kit.box(Vector3(x, 1.4, 0), Vector3(0.1, 2.8, 3.0), wall)
		for x: float in [-1.65, 1.65]:
			kit.box(Vector3(x, 1.4, 1.45), Vector3(0.7, 2.8, 0.1), wall)
		kit.box(Vector3(0, 0.675, 1.45), Vector3(2.6, 1.35, 0.1), wall)
		kit.box(Vector3(0, 2.625, 1.45), Vector3(2.6, 0.35, 0.1), wall)
		kit.box(Vector3(0, 0.02, 0), Vector3(3.8, 0.04, 2.8), Color("7a6a5a"))
		# Shelves with goods at the back wall.
		for i in 3:
			kit.box(Vector3(0, 1.2 + i * 0.45, -1.25), Vector3(3.2, 0.04, 0.3), WOOD_DARK)
			for k in 7:
				kit.box(Vector3(-1.4 + k * 0.45, 1.32 + i * 0.45, -1.25), Vector3(0.18, 0.2, 0.14),
					[Color("d0352b"), Color("f4c542"), Color("3f7cc2"), Color("9fe0a0")][(k + i) % 4])
		kit.box(Vector3(0, 1.3, 1.65), Vector3(2.8, 0.08, 0.35), WOOD_LIGHT)
		kit.box(Vector3(1.6, 1.0, 1.51), Vector3(0.6, 2.0, 0.02), WOOD_DARK)
		kit.prism(PackedVector2Array([Vector2(-2.3, -1.8), Vector2(2.3, -1.8), Vector2(2.3, 1.8), Vector2(-2.3, 1.8)]), 2.8, 2.95, Color("6b4a3a"))
		kit.lathe(PackedVector2Array([Vector2(3.0, 2.95), Vector2(0.0, 4.0)]), 4, Color("8a3b2b"), PI / 4)
		kit.translate(Vector3(0, 2.6, 1.5))
		_stripes(kit, 3.4, 1.0, 0.0, 0.4, blue, WHITE, 8)
		kit.pop()
		# Ice cream sign on the roof.
		kit.cylinder(Vector3(-1.4, 2.95, 0.8), 0.6, 0.0, 0.25, 6, Color("e0b070"))
		kit.sphere(Vector3(-1.4, 3.7, 0.8), Vector3(0.3, 0.3, 0.3), Color("f7c6d9"), 3, 6)
		# Fridge and newspaper rack.
		kit.box(Vector3(-2.4, 0.8, 0.9), Vector3(0.7, 1.6, 0.7), Color("d0352b"))
		kit.box(Vector3(-2.4, 0.9, 1.26), Vector3(0.5, 1.1, 0.02), Color("9fd3e8"))
		kit.box(Vector3(2.5, 0.5, 1.0), Vector3(0.6, 1.0, 0.5), Color("5a5a5a"))
		for i in 3:
			kit.box(Vector3(2.5, 0.75 + i * 0.12, 1.26), Vector3(0.5, 0.08, 0.06), [WHITE, Color("eaeaea"), Color("d8c9a0")][i])
		return kit.commit())


## Reverse vending machine for bottles.
static func bottle_machine() -> Mesh:
	return cached("bottle_machine", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.95, 0), Vector3(0.9, 1.9, 0.7), Color("2f8f5b"))
		kit.box(Vector3(0, 1.2, 0.36), Vector3(0.3, 0.3, 0.02), Color("1a1a1a"))
		kit.use("glow")
		kit.box(Vector3(0, 1.6, 0.36), Vector3(0.5, 0.18, 0.02), Color("8fe88f"))
		kit.use("solid")
		kit.box(Vector3(0, 1.95, 0), Vector3(1.0, 0.1, 0.8), Color("246f47"))
		return kit.commit())


## Snack machine (front = +z): a glowing window with rows of snacks, so it is found at night.
static func snack_machine() -> Mesh:
	return cached("snack_machine", func() -> Mesh:
		var kit := MeshKit.new()
		var red := Color("c8352b")
		kit.box(Vector3(0, 0.95, 0), Vector3(1.0, 1.9, 0.8), red)
		kit.box(Vector3(0, 1.95, 0), Vector3(1.1, 0.1, 0.9), red.darkened(0.3))
		kit.box(Vector3(0, 0.3, 0.41), Vector3(0.6, 0.22, 0.02), Color("1a1a1a"))  # output slot
		kit.box(Vector3(0.38, 1.0, 0.41), Vector3(0.14, 0.3, 0.02), Color("2a2a2a"))  # keypad
		kit.use("glow")
		kit.box(Vector3(-0.1, 1.15, 0.405), Vector3(0.66, 1.1, 0.01), Color("e8f4ff"))
		kit.box(Vector3(0, 1.8, 0.41), Vector3(0.8, 0.14, 0.02), Color("ffd84a"))
		kit.use("solid")
		var snacks := [Color("6b3e26"), Color("f4c542"), Color("3f7cc2"), Color("d0352b"), Color("9fe0a0")]
		for row in 4:
			kit.box(Vector3(-0.1, 0.66 + row * 0.26, 0.38), Vector3(0.66, 0.02, 0.06), Color("9a9a9a"))
			for k in 4:
				kit.box(Vector3(-0.34 + k * 0.16, 0.73 + row * 0.26, 0.4), Vector3(0.1, 0.12, 0.03), snacks[(k + row * 2) % snacks.size()])
		return kit.commit())


# --- Playground ---------------------------------------------------------------

static func swing_set() -> Mesh:
	return cached("swing_set", func() -> Mesh:
		var kit := MeshKit.new()
		var red := Color("d8463a")
		for x: float in [-1.8, 1.8]:
			kit.beam(Vector3(x, 0, -0.9), Vector3(x, 2.4, 0), Vector2(0.1, 0.1), red)
			kit.beam(Vector3(x, 0, 0.9), Vector3(x, 2.4, 0), Vector2(0.1, 0.1), red)
		kit.beam(Vector3(-1.9, 2.4, 0), Vector3(1.9, 2.4, 0), Vector2(0.12, 0.12), red)
		return kit.commit())


static func swing_seat() -> Mesh:
	return cached("swing_seat", func() -> Mesh:
		var kit := MeshKit.new()
		kit.beam(Vector3(-0.22, 0, 0), Vector3(-0.22, -1.9, 0), Vector2(0.02, 0.02), Color("999999"))
		kit.beam(Vector3(0.22, 0, 0), Vector3(0.22, -1.9, 0), Vector2(0.02, 0.02), Color("999999"))
		kit.box(Vector3(0, -1.92, 0), Vector3(0.5, 0.05, 0.22), Color("333333"))
		return kit.commit())


static func slide() -> Mesh:
	return cached("slide", func() -> Mesh:
		var kit := MeshKit.new()
		var blue := Color("3a7fd8")
		var yellow := Color("f2c230")
		for x: float in [-0.45, 0.45]:
			for z: float in [-0.45, 0.45]:
				kit.beam(Vector3(x, 0, z - 1.2), Vector3(x, 2.2, z - 1.2), Vector2(0.1, 0.1), yellow)
		kit.box(Vector3(0, 1.5, -1.2), Vector3(1.0, 0.08, 1.0), WOOD)
		kit.lathe(PackedVector2Array([Vector2(0.75, 2.2), Vector2(0.0, 2.8)]), 4, Color("d8463a"), PI / 4)
		for i in 5:
			kit.beam(Vector3(-0.35, 0.3 * i, -1.9 - 0.12 * i), Vector3(0.35, 0.3 * i, -1.9 - 0.12 * i), Vector2(0.05, 0.05), yellow)
		kit.beam(Vector3(-0.4, 0, -2.0), Vector3(-0.4, 1.5, -1.7), Vector2(0.06, 0.06), yellow)
		kit.beam(Vector3(0.4, 0, -2.0), Vector3(0.4, 1.5, -1.7), Vector2(0.06, 0.06), yellow)
		# Slide chute.
		kit.push(Transform3D(Basis(Vector3.RIGHT, 0.55), Vector3(0, 1.5, -0.7)))
		kit.box(Vector3(0, 0, 1.4), Vector3(0.7, 0.05, 2.8), blue)
		kit.box(Vector3(-0.36, 0.12, 1.4), Vector3(0.04, 0.25, 2.8), blue.darkened(0.2))
		kit.box(Vector3(0.36, 0.12, 1.4), Vector3(0.04, 0.25, 2.8), blue.darkened(0.2))
		kit.pop()
		return kit.commit())


static func sandbox() -> Mesh:
	return cached("sandbox", func() -> Mesh:
		var kit := MeshKit.new()
		for s: Vector3 in [Vector3(0, 0.15, 1.5), Vector3(0, 0.15, -1.5)]:
			kit.box(s, Vector3(3.2, 0.3, 0.2), WOOD)
		for s: Vector3 in [Vector3(1.5, 0.15, 0), Vector3(-1.5, 0.15, 0)]:
			kit.box(s, Vector3(0.2, 0.3, 3.0), WOOD)
		kit.box(Vector3(0, 0.08, 0), Vector3(2.9, 0.12, 2.9), Color("e8d39a"))
		kit.cylinder(Vector3(0.6, 0.12, 0.4), 0.25, 0.2, 0.12, 6, Color("d8463a"))
		kit.sphere(Vector3(-0.5, 0.25, -0.3), Vector3(0.35, 0.2, 0.35), Color("dcc68b"), 3, 6)
		return kit.commit())


static func seesaw() -> Mesh:
	return cached("seesaw", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.25, 0), Vector3(0.3, 0.5, 0.4), Color("3a7fd8"))
		kit.push(Transform3D(Basis(Vector3.BACK, 0.18), Vector3(0, 0.52, 0)))
		kit.box(Vector3.ZERO, Vector3(3.2, 0.08, 0.3), Color("f2c230"))
		for x: float in [-1.3, 1.3]:
			kit.beam(Vector3(x, 0.04, -0.15), Vector3(x, 0.3, -0.15), Vector2(0.04, 0.04), Color("d8463a"))
			kit.beam(Vector3(x, 0.3, -0.2), Vector3(x, 0.3, 0.2), Vector2(0.04, 0.04), Color("d8463a"))
		kit.pop()
		return kit.commit())


static func spring_duck() -> Mesh:
	return cached("spring_duck", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.08, 0.3, 0.3, 8, Color("555555"))
		for i in 6:
			kit.torus(Vector3(0, 0.12 + i * 0.07, 0), 0.12, 0.02, 8, 3, Color("aaaaaa"))
		kit.sphere(Vector3(0, 0.75, 0), Vector3(0.35, 0.25, 0.5), Color("f2c230"), 3, 8)
		kit.sphere(Vector3(0, 1.05, 0.35), Vector3(0.2, 0.2, 0.2), Color("f2c230"), 3, 6)
		kit.box(Vector3(0, 1.02, 0.58), Vector3(0.14, 0.06, 0.16), Color("f28a2a"))
		kit.beam(Vector3(-0.2, 0.95, 0.3), Vector3(0.2, 0.95, 0.3), Vector2(0.04, 0.04), Color("d8463a"))
		return kit.commit())


static func climbing_frame() -> Mesh:
	return cached("climbing_frame", func() -> Mesh:
		var kit := MeshKit.new()
		var col := Color("3aa86b")
		for i in 4:
			for j in 4:
				var p := Vector3(-1.2 + i * 0.8, 0, -1.2 + j * 0.8)
				kit.beam(p, p + Vector3(0, 2.0, 0), Vector2(0.06, 0.06), col)
		for y: float in [0.6, 1.3, 2.0]:
			for i in 4:
				kit.beam(Vector3(-1.2, y, -1.2 + i * 0.8), Vector3(1.2, y, -1.2 + i * 0.8), Vector2(0.05, 0.05), col)
				kit.beam(Vector3(-1.2 + i * 0.8, y, -1.2), Vector3(-1.2 + i * 0.8, y, 1.2), Vector2(0.05, 0.05), col)
		return kit.commit())


# --- Games and sport -------------------------------------------------------------

static func chess_table() -> Mesh:
	return cached("chess_table", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.7, 0.18, 0.14, 8, STONE)
		kit.box(Vector3(0, 0.74, 0), Vector3(0.9, 0.06, 0.9), STONE_LIGHT)
		for i in 8:
			for j in 8:
				var col := Color("2a2a2a") if (i + j) % 2 == 0 else Color("efe6d2")
				kit.box(Vector3(-0.28 + i * 0.08, 0.775, -0.28 + j * 0.08), Vector3(0.08, 0.01, 0.08), col)
		for z: float in [-0.85, 0.85]:
			kit.cylinder(Vector3(0, 0, z), 0.45, 0.17, 0.15, 7, STONE, true, STONE_LIGHT)
		return kit.commit())


static func chess_piece(kind: String, white: bool) -> Mesh:
	return cached("chess_%s_%s" % [kind, white], func() -> Mesh:
		var kit := MeshKit.new()
		var col := Color("f1ebdc") if white else Color("2c2a28")
		kit.lathe(PackedVector2Array([Vector2(0.32, 0.0), Vector2(0.3, 0.12), Vector2(0.18, 0.2), Vector2(0.12, 0.7),
			Vector2(0.2, 0.8), Vector2(0.0, 0.85)]), 10, col)
		match kind:
			"king":
				kit.cylinder(Vector3(0, 0.85, 0), 0.35, 0.18, 0.22, 8, col)
				kit.box(Vector3(0, 1.35, 0), Vector3(0.08, 0.3, 0.08), col)
				kit.box(Vector3(0, 1.38, 0), Vector3(0.24, 0.08, 0.08), col)
			"queen":
				kit.cylinder(Vector3(0, 0.85, 0), 0.4, 0.16, 0.24, 8, col)
				kit.sphere(Vector3(0, 1.3, 0), Vector3(0.09, 0.09, 0.09), col, 3, 6)
			"rook":
				kit.cylinder(Vector3(0, 0.8, 0), 0.3, 0.22, 0.22, 8, col)
			"knight":
				kit.push(Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, 0.85, 0)))
				kit.box(Vector3(0, 0.2, 0.06), Vector3(0.2, 0.42, 0.34), col)
				kit.pop()
			_:
				kit.sphere(Vector3(0, 0.95, 0), Vector3(0.14, 0.14, 0.14), col, 3, 6)
		return kit.commit())


## Giant 3x3 board for tic-tac-toe, 1.4 m cells; origin = board centre.
static func giant_board() -> Mesh:
	return cached("giant_board", func() -> Mesh:
		var kit := MeshKit.new()
		for i in 3:
			for j in 3:
				var col := Color("e9e2d0") if (i + j) % 2 == 0 else Color("b8ae98")
				kit.box(Vector3((i - 1) * 1.4, 0.03, (j - 1) * 1.4), Vector3(1.36, 0.06, 1.36), col)
		kit.box(Vector3(0, 0.02, 0), Vector3(4.5, 0.04, 4.5), STONE_DARK)
		return kit.commit())


static func giant_mark(is_x: bool) -> Mesh:
	return cached("giant_mark_%s" % is_x, func() -> Mesh:
		var kit := MeshKit.new()
		if is_x:
			var col := Color("d8463a")
			kit.push(Transform3D(Basis(Vector3.UP, PI / 4), Vector3.ZERO))
			kit.box(Vector3(0, 0.15, 0), Vector3(1.1, 0.3, 0.22), col)
			kit.box(Vector3(0, 0.15, 0), Vector3(0.22, 0.3, 1.1), col)
			kit.pop()
		else:
			kit.torus(Vector3(0, 0.15, 0), 0.42, 0.13, 14, 5, Color("3a7fd8"))
		return kit.commit())


static func boule_border() -> Mesh:
	return cached("boule_border", func() -> Mesh:
		var kit := MeshKit.new()
		var size: Vector2 = ParkLayout.AREAS["boule"]["size"]
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(0, 0.1, s * size.y * 0.5), Vector3(size.x + 0.3, 0.2, 0.15), WOOD)
			kit.box(Vector3(s * size.x * 0.5, 0.1, 0), Vector3(0.15, 0.2, size.y), WOOD)
		return kit.commit())


static func ball(color: Color, radius: float) -> Mesh:
	return cached("ball_%s_%.2f" % [color.to_html(), radius], func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("nosnow")
		kit.sphere(Vector3.ZERO, Vector3(radius, radius, radius), color, 4, 8)
		return kit.commit())


static func folding_table() -> Mesh:
	return cached("folding_table", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.8, 0), Vector3(1.0, 0.04, 0.6), Color("2f6b3a"))
		kit.beam(Vector3(-0.45, 0, -0.25), Vector3(0.45, 0.78, 0.25), Vector2(0.03, 0.03), IRON)
		kit.beam(Vector3(0.45, 0, -0.25), Vector3(-0.45, 0.78, 0.25), Vector2(0.03, 0.03), IRON)
		kit.beam(Vector3(-0.45, 0, 0.25), Vector3(0.45, 0.78, -0.25), Vector2(0.03, 0.03), IRON)
		kit.beam(Vector3(0.45, 0, 0.25), Vector3(-0.45, 0.78, -0.25), Vector2(0.03, 0.03), IRON)
		return kit.commit())


static func cup() -> Mesh:
	return cached("cup", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("nosnow")
		kit.cylinder(Vector3.ZERO, 0.2, 0.11, 0.07, 8, Color("c0392b"), true, Color("8e2a1f"))
		return kit.commit())


static func agility_hurdle() -> Mesh:
	return cached("hurdle", func() -> Mesh:
		var kit := MeshKit.new()
		for x: float in [-0.6, 0.6]:
			kit.cylinder(Vector3(x, 0, 0), 0.8, 0.03, 0.03, 5, WHITE)
		kit.beam(Vector3(-0.6, 0.45, 0), Vector3(0.6, 0.45, 0), Vector2(0.04, 0.04), Color("d8463a"))
		return kit.commit())


static func dog_tunnel() -> Mesh:
	return cached("dog_tunnel", func() -> Mesh:
		var kit := MeshKit.new()
		for i in 6:
			kit.push(Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(-1.0 + i * 0.4, 0.4, 0)))
			kit.torus(Vector3.ZERO, 0.38, 0.05, 10, 3, Color("3a7fd8") if i % 2 == 0 else Color("f2c230"))
			kit.pop()
		return kit.commit())


# --- Fences and gates -----------------------------------------------------------

## Iron fence segment of given length along +X with a stone post at the start.
static func fence_segment(length: float) -> Mesh:
	return cached("fence_%.2f" % length, func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.75, 0), Vector3(0.4, 1.5, 0.4), STONE, STONE_LIGHT)
		kit.box(Vector3(0, 1.55, 0), Vector3(0.48, 0.1, 0.48), STONE_LIGHT)
		kit.box(Vector3(length * 0.5, 0.12, 0), Vector3(length, 0.24, 0.25), STONE)
		kit.beam(Vector3(0, 0.45, 0), Vector3(length, 0.45, 0), Vector2(0.05, 0.03), IRON)
		kit.beam(Vector3(0, 1.25, 0), Vector3(length, 1.25, 0), Vector2(0.05, 0.03), IRON)
		var bars := int(length / 0.18)
		for i in bars:
			var x := 0.3 + (length - 0.5) * i / maxf(1.0, bars - 1)
			kit.beam(Vector3(x, 0.24, 0), Vector3(x, 1.4, 0), Vector2(0.025, 0.025), IRON)
			kit.cylinder(Vector3(x, 1.4, 0), 0.08, 0.03, 0.0, 4, IRON)
		return kit.commit())


static func low_fence(length: float) -> Mesh:
	return cached("low_fence_%.2f" % length, func() -> Mesh:
		var kit := MeshKit.new()
		var posts := maxi(1, int(length / 1.5))
		for i in posts + 1:
			var x := length * i / posts
			kit.box(Vector3(x, 0.45, 0), Vector3(0.1, 0.9, 0.1), WOOD_DARK)
		kit.box(Vector3(length * 0.5, 0.75, 0), Vector3(length, 0.08, 0.04), WOOD)
		kit.box(Vector3(length * 0.5, 0.35, 0), Vector3(length, 0.08, 0.04), WOOD)
		return kit.commit())


## Park gate with two pillars and an arch carrying the sign (text added separately).
static func gate(width: float) -> Mesh:
	return cached("gate_%.1f" % width, func() -> Mesh:
		var kit := MeshKit.new()
		for s: float in [-1.0, 1.0]:
			var x := s * (width * 0.5 + 0.4)
			kit.box(Vector3(x, 1.5, 0), Vector3(0.8, 3.0, 0.8), STONE, STONE_LIGHT)
			kit.box(Vector3(x, 3.05, 0), Vector3(0.95, 0.12, 0.95), STONE_LIGHT)
			kit.sphere(Vector3(x, 3.35, 0), Vector3(0.28, 0.28, 0.28), STONE_LIGHT, 3, 6)
		var arch_pts := 10
		for i in arch_pts:
			var t0 := float(i) / arch_pts
			var t1 := float(i + 1) / arch_pts
			var x0 := lerpf(-width * 0.5 - 0.1, width * 0.5 + 0.1, t0)
			var x1 := lerpf(-width * 0.5 - 0.1, width * 0.5 + 0.1, t1)
			var y0 := 3.0 + sin(PI * t0) * 0.7
			var y1 := 3.0 + sin(PI * t1) * 0.7
			kit.beam(Vector3(x0, y0, 0), Vector3(x1, y1, 0), Vector2(0.1, 0.1), IRON)
		kit.box(Vector3(0, 3.3, 0), Vector3(width * 0.6, 0.5, 0.06), PARK_GREEN)
		return kit.commit())


# --- City backdrop --------------------------------------------------------------

## Appends a city building with lit windows (glow surface) to `kit` at `pos`.
static func building_into(kit: MeshKit, pos: Vector3, size: Vector3, color: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	kit.translate(pos)
	kit.use("solid")
	kit.box(Vector3(0, size.y * 0.5, 0), size, color, color.darkened(0.25))
	kit.box(Vector3(0, size.y + 0.25, 0), Vector3(size.x + 0.3, 0.5, size.z + 0.3), color.darkened(0.15))
	# Ground floor shop band.
	kit.box(Vector3(0, 2.0, 0), Vector3(size.x + 0.1, 4.0, size.z + 0.1), color.darkened(0.35))
	if rng.randf() < 0.6:
		# Classic rooftop water tank.
		var p := Vector3(rng.randf_range(-size.x * 0.3, size.x * 0.3), size.y + 0.5, rng.randf_range(-size.z * 0.3, size.z * 0.3))
		for i in 4:
			var a := TAU * i / 4.0 + PI / 4
			kit.beam(p + Vector3(cos(a), 0, sin(a)) * 0.9, p + Vector3(cos(a), 0, sin(a)) * 0.9 + Vector3(0, 2.0, 0), Vector2(0.12, 0.12), Color("3a3a3a"))
		kit.cylinder(p + Vector3(0, 2.0, 0), 2.2, 1.2, 1.2, 8, Color("8a6040"))
		kit.cylinder(p + Vector3(0, 4.2, 0), 0.8, 1.25, 0.0, 8, Color("5a4030"))
	kit.use("glow")
	var floors := int(size.y / 3.2)
	for side in 4:
		var w := size.x if side % 2 == 0 else size.z
		var cols := maxi(1, int(w / 2.6))
		for f in range(2, floors):
			for c in cols:
				if rng.randf() < 0.5:
					continue
				var u := -w * 0.5 + (c + 0.5) * w / cols
				var y := f * 3.2 + 0.4
				var col := Color("ffd98a") if rng.randf() < 0.8 else Color("bfe0ff")
				match side:
					0: kit.box(Vector3(u, y, size.z * 0.5 + 0.03), Vector3(1.1, 1.5, 0.04), col)
					1: kit.box(Vector3(size.x * 0.5 + 0.03, y, u), Vector3(0.04, 1.5, 1.1), col)
					2: kit.box(Vector3(u, y, -size.z * 0.5 - 0.03), Vector3(1.1, 1.5, 0.04), col)
					3: kit.box(Vector3(-size.x * 0.5 - 0.03, y, u), Vector3(0.04, 1.5, 1.1), col)
	kit.use("solid")
	kit.pop()


static func car(color: Color) -> Mesh:
	return cached("car_%s" % color.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.55, 0), Vector3(1.8, 0.6, 4.2), color)
		kit.box(Vector3(0, 1.1, -0.2), Vector3(1.6, 0.55, 2.2), color.darkened(0.05))
		kit.box(Vector3(0, 1.1, -0.2), Vector3(1.62, 0.4, 2.0), Color("2b3a48"))
		for x: float in [-0.9, 0.9]:
			for z: float in [-1.35, 1.35]:
				kit.push(Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(x, 0.35, z)))
				kit.cylinder(Vector3(0, -0.12, 0), 0.24, 0.34, 0.34, 8, Color("1e1e1e"))
				kit.pop()
		kit.use("glow")
		for x: float in [-0.6, 0.6]:
			kit.box(Vector3(x, 0.65, 2.11), Vector3(0.35, 0.15, 0.02), Color("fff3c0"))
			kit.box(Vector3(x, 0.65, -2.11), Vector3(0.35, 0.15, 0.02), Color("ff4030"))
		return kit.commit())


# --- Small items (held in hands or lying around) --------------------------------

static func item(id: String) -> Mesh:
	return cached("item_" + id, func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("nosnow")
		match id:
			"donut":
				kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
				kit.torus(Vector3.ZERO, 0.06, 0.035, 8, 4, Color("d9a35c"))
				kit.pop()
				kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.012)))
				kit.torus(Vector3.ZERO, 0.06, 0.03, 8, 3, Color("f28db2"))
				kit.pop()
			"hotdog":
				kit.rod(Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0), 0.035, 0.035, 6, Color("e0b070"))
				kit.rod(Vector3(-0.12, 0.02, 0), Vector3(0.12, 0.02, 0), 0.022, 0.022, 6, Color("a8432e"))
				kit.box(Vector3(0, 0.045, 0), Vector3(0.16, 0.01, 0.02), Color("f4c542"))
			"icecream":
				kit.cylinder(Vector3(0, -0.12, 0), 0.14, 0.0, 0.045, 6, Color("d9a35c"))
				kit.sphere(Vector3(0, 0.05, 0), Vector3(0.05, 0.05, 0.05), Color("f7c6d9"), 3, 6)
				kit.sphere(Vector3(0, 0.12, 0), Vector3(0.045, 0.045, 0.045), Color("6b3e26"), 3, 6)
			"fries":
				kit.cylinder(Vector3(0, -0.1, 0), 0.13, 0.02, 0.05, 6, Color("e8402e"))
				for i in 6:
					kit.box(Vector3(-0.025 + (i % 3) * 0.025, 0.04 + (i % 2) * 0.015, -0.01 + (i / 3) * 0.02), Vector3(0.012, 0.07, 0.012), Color("f6cf4a"))
			"pretzel":
				kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
				kit.torus(Vector3(-0.04, 0, 0), 0.05, 0.016, 8, 3, Color("8a4a1c"))
				kit.torus(Vector3(0.04, 0, 0), 0.05, 0.016, 8, 3, Color("8a4a1c"))
				kit.pop()
			"chocolate":
				kit.box(Vector3.ZERO, Vector3(0.13, 0.035, 0.05), Color("d0352b"))
				kit.box(Vector3(0.075, 0, 0), Vector3(0.03, 0.03, 0.045), Color("6b3e26"))
			"sandwich":
				kit.box(Vector3(0, -0.02, 0), Vector3(0.12, 0.02, 0.1), Color("e8c890"))
				kit.box(Vector3(0, 0.0, 0), Vector3(0.125, 0.015, 0.105), Color("f4c542"))
				kit.box(Vector3(0, 0.012, 0), Vector3(0.13, 0.01, 0.11), Color("6fbf4a"))
				kit.box(Vector3(0, 0.03, 0), Vector3(0.12, 0.02, 0.1), Color("e8c890"))
			"bread":
				kit.sphere(Vector3.ZERO, Vector3(0.12, 0.06, 0.07), Color("d9a35c"), 3, 6)
			"bottle":
				kit.cylinder(Vector3(0, -0.12, 0), 0.18, 0.04, 0.04, 6, Color("5aa06a"))
				kit.cylinder(Vector3(0, 0.06, 0), 0.08, 0.04, 0.015, 6, Color("5aa06a"))
				kit.cylinder(Vector3(0, 0.14, 0), 0.02, 0.016, 0.016, 5, Color("e0e0e0"))
				kit.box(Vector3(0, -0.04, 0.0), Vector3(0.085, 0.06, 0.085), Color("f2f2f2"))
			"frisbee":
				kit.cylinder(Vector3(0, -0.015, 0), 0.03, 0.14, 0.12, 12, Color("f2552c"), true, Color("ff7a4d"))
			"camera":
				kit.box(Vector3.ZERO, Vector3(0.14, 0.09, 0.06), Color("2a2a2a"))
				kit.rod(Vector3(0, 0, 0.03), Vector3(0, 0, 0.09), 0.03, 0.03, 8, Color("444444"))
				kit.box(Vector3(-0.04, 0.055, 0), Vector3(0.03, 0.02, 0.03), Color("aaaaaa"))
			"phone":
				kit.box(Vector3.ZERO, Vector3(0.07, 0.14, 0.012), Color("1a1a1a"))
			"umbrella":
				kit.cylinder(Vector3(0, -0.9, 0), 1.0, 0.01, 0.01, 4, Color("333333"))
				var n := 8
				for i in n:
					var a0 := TAU * i / n
					var a1 := TAU * (i + 1) / n
					var col := Color("2b5f9e") if i % 2 == 0 else Color("e8e8e8")
					kit.tri(Vector3(0, 0.25, 0), Vector3(cos(a1) * 0.75, 0.0, sin(a1) * 0.75), Vector3(cos(a0) * 0.75, 0.0, sin(a0) * 0.75), col)
					kit.tri(Vector3(0, 0.24, 0), Vector3(cos(a0) * 0.75, -0.01, sin(a0) * 0.75), Vector3(cos(a1) * 0.75, -0.01, sin(a1) * 0.75), col.darkened(0.3))
			"newspaper":
				kit.box(Vector3.ZERO, Vector3(0.32, 0.4, 0.01), Color("eeeae0"))
				kit.box(Vector3(0, 0.12, 0.006), Vector3(0.26, 0.06, 0.002), Color("333333"))
			"map":
				kit.box(Vector3.ZERO, Vector3(0.45, 0.3, 0.005), Color("e8dfb8"))
				kit.box(Vector3(0.05, 0.02, 0.004), Vector3(0.15, 0.1, 0.002), Color("6aa84f"))
				kit.box(Vector3(-0.1, -0.05, 0.004), Vector3(0.08, 0.06, 0.002), Color("5aa0e6"))
			"balloon":
				kit.beam(Vector3.ZERO, Vector3(0, 1.0, 0), Vector2(0.006, 0.006), Color("eeeeee"))
				kit.sphere(Vector3(0, 1.25, 0), Vector3(0.22, 0.27, 0.22), Color("e8443a"), 4, 8)
			"briefcase":
				kit.box(Vector3(0, -0.2, 0), Vector3(0.42, 0.3, 0.1), Color("4a2e1e"))
				kit.box(Vector3(0, -0.03, 0), Vector3(0.12, 0.04, 0.03), Color("2a1a10"))
			"leash":
				kit.box(Vector3.ZERO, Vector3(0.05, 0.08, 0.05), Color("c0392b"))
			"putter":
				kit.beam(Vector3.ZERO, Vector3(0, -0.85, 0.05), Vector2(0.02, 0.02), Color("bbbbbb"))
				kit.box(Vector3(0, -0.88, 0.1), Vector3(0.05, 0.06, 0.16), Color("555555"))
			"boule":
				kit.sphere(Vector3.ZERO, Vector3(0.04, 0.04, 0.04), Color("9aa3ad"), 3, 6)
			"bag":
				kit.box(Vector3(0, -0.25, 0), Vector3(0.3, 0.32, 0.14), Color("e2c48a"))
				kit.beam(Vector3(-0.1, -0.1, 0), Vector3(0, 0, 0), Vector2(0.01, 0.01), Color("8a6a3a"))
				kit.beam(Vector3(0.1, -0.1, 0), Vector3(0, 0, 0), Vector2(0.01, 0.01), Color("8a6a3a"))
			"guitar":
				kit.sphere(Vector3(0, -0.15, 0), Vector3(0.2, 0.24, 0.07), Color("b5722e"), 3, 8)
				kit.beam(Vector3(0, 0.05, 0), Vector3(0, 0.55, 0), Vector2(0.05, 0.03), Color("4a2e1e"))
			"trumpet":
				kit.rod(Vector3(0, 0, -0.2), Vector3(0, 0, 0.15), 0.015, 0.015, 5, Color("e2b84a"))
				kit.rod(Vector3(0, 0, 0.15), Vector3(0, 0, 0.3), 0.02, 0.07, 8, Color("e2b84a"))
			"nut":
				kit.sphere(Vector3.ZERO, Vector3(0.025, 0.03, 0.025), Color("8a5a2c"), 2, 5)
			"coin":
				kit.cylinder(Vector3.ZERO, 0.005, 0.02, 0.02, 8, Color("e2c050"))
			"flower":
				kit.rod(Vector3.ZERO, Vector3(0, 0.25, 0), 0.008, 0.008, 3, Color("4c8a3a"))
				kit.sphere(Vector3(0, 0.27, 0), Vector3(0.04, 0.03, 0.04), Color("e8574a"), 2, 5)
			"broom":
				kit.beam(Vector3(0, 0.6, 0), Vector3(0, -0.8, 0), Vector2(0.03, 0.03), WOOD)
				kit.cylinder(Vector3(0, -1.1, 0), 0.32, 0.16, 0.05, 6, Color("c8a86a"))
			"axe":
				kit.beam(Vector3(0, 0.08, 0), Vector3(0, -0.62, 0), Vector2(0.035, 0.035), WOOD_LIGHT)
				kit.box(Vector3(0, -0.58, 0.09), Vector3(0.03, 0.14, 0.16), Color("9aa0a8"))
			"pickaxe":
				kit.beam(Vector3(0, 0.08, 0), Vector3(0, -0.66, 0), Vector2(0.035, 0.035), WOOD_LIGHT)
				kit.beam(Vector3(0, -0.62, -0.26), Vector3(0, -0.62, 0.26), Vector2(0.04, 0.05), Color("8a8f96"))
			"rod":
				kit.beam(Vector3(0, 0.1, 0), Vector3(0, -1.9, 0), Vector2(0.018, 0.018), WOOD)
				kit.cylinder(Vector3(0.03, -0.12, 0), 0.06, 0.04, 0.04, 6, Color("3a3a3e"))
			"basket":
				kit.cylinder(Vector3(0, -0.3, 0), 0.22, 0.15, 0.19, 8, Color("b5833f"), true, Color("8a5a2c"))
				kit.beam(Vector3(-0.15, -0.1, 0), Vector3(0.15, -0.1, 0), Vector2(0.02, 0.02), Color("8a5a2c"))
			_:
				kit.box(Vector3.ZERO, Vector3(0.08, 0.08, 0.08), Color.MAGENTA)
		return kit.commit())


## Picnic blanket with a basket.
static func picnic_blanket(color: Color) -> Mesh:
	return cached("blanket_%s" % color.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		for i in 6:
			for j in 6:
				var col := color if (i + j) % 2 == 0 else Color.WHITE
				kit.box(Vector3(-1.0 + i * 0.4 + 0.2, 0.02, -1.0 + j * 0.4 + 0.2), Vector3(0.4, 0.02, 0.4), col)
		kit.box(Vector3(0.7, 0.18, -0.6), Vector3(0.45, 0.3, 0.3), Color("b5833f"))
		kit.beam(Vector3(0.5, 0.33, -0.6), Vector3(0.9, 0.33, -0.6), Vector2(0.03, 0.03), Color("8a5a2c"))
		return kit.commit())


# --- Easter eggs ----------------------------------------------------------------------

## Garden gnome, 0.5 m tall; variant changes clothes and what it holds.
static func gnome(v: int) -> Mesh:
	return cached("gnome_%d" % v, func() -> Mesh:
		var kit := MeshKit.new()
		var shirts := [Color("2e6fbf"), Color("3a8a3a"), Color("8e44ad"), Color("e0752d"), Color("2a9a9a"), Color("c0392b"), Color("6b4a32")]
		var shirt: Color = shirts[v % shirts.size()]
		var skin := Color("f2c8a8")
		kit.cylinder(Vector3(0, 0, 0), 0.04, 0.12, 0.12, 8, Color("5a4a3a"))
		for x: float in [-0.05, 0.05]:
			kit.box(Vector3(x, 0.06, 0.02), Vector3(0.06, 0.08, 0.1), Color("3a2a20"))
		kit.lathe(PackedVector2Array([Vector2(0.1, 0.08), Vector2(0.11, 0.2), Vector2(0.08, 0.3), Vector2(0.0, 0.32)]), 8, shirt)
		kit.box(Vector3(0, 0.15, 0), Vector3(0.22, 0.03, 0.22), Color("3a2a20"))
		kit.sphere(Vector3(0, 0.36, 0), Vector3(0.075, 0.075, 0.075), skin, 4, 8)
		kit.sphere(Vector3(0, 0.355, 0.07), Vector3(0.025, 0.025, 0.025), Color("e89a8a"), 2, 5)
		kit.sphere(Vector3(0, 0.3, 0.04), Vector3(0.075, 0.07, 0.05), Color("f4f4f4"), 3, 7)
		kit.cylinder(Vector3(0, 0.41, 0), 0.2, 0.08, 0.0, 8, Color("d8402e"))
		kit.box(Vector3(-0.025, 0.37, 0.065), Vector3(0.012, 0.012, 0.01), Color("1a1a1a"))
		kit.box(Vector3(0.025, 0.37, 0.065), Vector3(0.012, 0.012, 0.01), Color("1a1a1a"))
		match v % 7:
			0: kit.beam(Vector3(0.11, 0.0, 0.05), Vector3(0.11, 0.42, 0.05), Vector2(0.015, 0.015), Color("8a6a3a"))
			1:
				kit.beam(Vector3(0.12, 0.18, 0.05), Vector3(0.12, 0.24, 0.05), Vector2(0.01, 0.01), Color("333333"))
				kit.use("glow")
				kit.box(Vector3(0.12, 0.14, 0.05), Vector3(0.05, 0.07, 0.05), Color("ffd98a"))
				kit.use("solid")
			2: kit.beam(Vector3(0.1, 0.2, 0.05), Vector3(0.3, 0.55, 0.15), Vector2(0.01, 0.01), Color("8a6a3a"))
			3:
				kit.cylinder(Vector3(0.12, 0.12, 0.06), 0.06, 0.012, 0.012, 4, Color("efe6d2"))
				kit.sphere(Vector3(0.12, 0.19, 0.06), Vector3(0.04, 0.025, 0.04), Color("d23a2a"), 2, 6)
			4: kit.box(Vector3(0.0, 0.2, 0.11), Vector3(0.1, 0.08, 0.02), Color("8e2a1f"))
			5: kit.sphere(Vector3(0.12, 0.2, 0.06), Vector3(0.04, 0.04, 0.04), Color("f2c230"), 2, 6)
			6: kit.rod(Vector3(0.03, 0.33, 0.08), Vector3(0.09, 0.36, 0.14), 0.008, 0.012, 4, Color("6b4a32"))
		return kit.commit())


static func nessie() -> Mesh:
	return cached("nessie", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("nosnow")
		var green := Color("3f7a5a")
		var belly := Color("8fbf8a")
		kit.rod(Vector3(0, -0.4, 0), Vector3(0, 2.0, 0.6), 0.35, 0.22, 8, green)
		kit.sphere(Vector3(0, 2.2, 0.85), Vector3(0.38, 0.32, 0.55), green, 4, 8, 0.0, 0, belly)
		for x: float in [-0.18, 0.18]:
			kit.sphere(Vector3(x, 2.38, 1.2), Vector3(0.07, 0.07, 0.07), Color("fbfbf8"), 2, 5)
			kit.sphere(Vector3(x, 2.38, 1.25), Vector3(0.035, 0.035, 0.035), Color("111111"), 2, 4)
		for i in 3:
			kit.sphere(Vector3(0, -0.1, -1.4 - i * 1.3), Vector3(0.45 - i * 0.08, 0.6 - i * 0.12, 0.6), green, 4, 8)
			kit.cylinder(Vector3(0, 0.35 - i * 0.12, -1.4 - i * 1.3), 0.25, 0.08, 0.0, 4, Color("2a5a3a"))
		return kit.commit())


static func ufo() -> Mesh:
	return cached("ufo", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("nosnow")
		kit.lathe(PackedVector2Array([Vector2(0.0, -0.4), Vector2(2.2, -0.1), Vector2(3.2, 0.0), Vector2(2.2, 0.25), Vector2(1.2, 0.4)]),
			16, Color("b8c0c8"), 0.0, [Color("8a9098"), Color("b8c0c8"), Color("d8dee4"), Color("b8c0c8")])
		kit.use("glow")
		kit.sphere(Vector3(0, 0.55, 0), Vector3(1.2, 0.9, 1.2), Color("8fe8c8"), 4, 10)
		for i in 10:
			var a := TAU * i / 10.0
			kit.sphere(Vector3(cos(a) * 2.7, 0.05, sin(a) * 2.7), Vector3(0.15, 0.15, 0.15), [Color("ff6060"), Color("60ff60"), Color("6080ff")][i % 3], 2, 5)
		return kit.commit())


# --- Seasonal decoration ---------------------------------------------------------

static func snowman() -> Mesh:
	return cached("snowman", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("nosnow")
		var white := Color("f4f6fa")
		kit.sphere(Vector3(0, 0.45, 0), Vector3(0.5, 0.45, 0.5), white, 4, 8)
		kit.sphere(Vector3(0, 1.15, 0), Vector3(0.36, 0.33, 0.36), white, 4, 8)
		kit.sphere(Vector3(0, 1.65, 0), Vector3(0.26, 0.25, 0.26), white, 4, 8)
		kit.rod(Vector3(0, 1.65, 0.22), Vector3(0, 1.62, 0.45), 0.04, 0.0, 5, Color("f28a2a"))
		for x: float in [-0.09, 0.09]:
			kit.sphere(Vector3(x, 1.73, 0.21), Vector3(0.03, 0.03, 0.03), Color("1a1a1a"), 2, 4)
		kit.cylinder(Vector3(0, 1.85, 0), 0.04, 0.3, 0.3, 8, Color("1a1a1a"))
		kit.cylinder(Vector3(0, 1.89, 0), 0.3, 0.18, 0.18, 8, Color("1a1a1a"))
		kit.torus(Vector3(0, 1.43, 0), 0.24, 0.06, 10, 4, Color("c0392b"))
		kit.rod(Vector3(0.3, 1.2, 0), Vector3(0.75, 1.5, 0), 0.025, 0.015, 3, Color("4e3524"))
		kit.rod(Vector3(-0.3, 1.2, 0), Vector3(-0.72, 1.45, 0.1), 0.025, 0.015, 3, Color("4e3524"))
		return kit.commit())


static func pumpkin(v: int) -> Mesh:
	return cached("pumpkin_%d" % v, func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("nosnow")
		var s := 0.25 + 0.08 * (v % 3)
		var col := Color("e8862a") if v % 2 == 0 else Color("d9702a")
		for i in 6:
			var a := TAU * i / 6.0
			kit.sphere(Vector3(cos(a) * s * 0.35, s * 0.7, sin(a) * s * 0.35), Vector3(s * 0.6, s * 0.7, s * 0.6), col, 3, 6)
		kit.rod(Vector3(0, s * 1.3, 0), Vector3(0.03, s * 1.6, 0), 0.04, 0.025, 4, Color("4c6a2a"))
		return kit.commit())


static func leaf_pile() -> Mesh:
	return cached("leaf_pile", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("nosnow")
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 6:
			var a := rng.randf() * TAU
			kit.sphere(Vector3(cos(a) * 0.4, 0.15, sin(a) * 0.4), Vector3(0.5, 0.25, 0.5),
				[Color("d9702a"), Color("c9452a"), Color("e8b03a")][i % 3], 3, 6, 0.2, i)
		return kit.commit())

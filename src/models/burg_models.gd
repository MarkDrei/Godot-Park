class_name BurgModels
extends RefCounted
## Procedural models of the Ritterburg (doc/burg.md): towers, the gate house, the hall of the
## exhibition, the tavern, the smithy, market stalls, the tournament's stands, lists and
## targets, the stage and the puppet theatre, torches. Origins sit on the ground; "front" faces
## +Z unless stated otherwise. Stone uses the "masonry" pattern, flames the "glow" surface.

const STONE := Color("a49c8e")
const STONE_DARK := Color("857d70")
const STONE_LIGHT := Color("bdb5a6")
const ROOF := Color("8e3b2c")
const SLATE := Color("4c5560")
const WOOD := Color("8a6440")
const WOOD_DARK := Color("5a3e26")
const PLASTER := Color("ece2cc")
const STRAW := Color("d6b866")
const IRON := Color("3a3a3e")
const FLAME := Color("ffb347")
const RED := Color("b8322a")
const BLUE := Color("2f5fa8")
const GOLD := Color("d9b44a")
const GREEN := Color("3f7a45")
const PURPLE := Color("4a2a66")
## Colours of the stalls' awnings.
const AWNINGS := [Color("b8322a"), Color("2f5fa8"), Color("d9b44a"), Color("3f7a45"), Color("7a4a8a"), Color("c96a2a")]
## The lookout tower: height of its platform.
const TOWER_TOP := 16.0


static func cached(key: String, builder: Callable) -> Mesh:
	return NatureModels.cached("burg_" + key, builder)


## Battlements on a wall top from a to b (local, at height y): merlons every 1.4 m.
static func merlons(kit: MeshKit, a: Vector3, b: Vector3, thick: float, col: Color) -> void:
	var d := b - a
	var n := int(d.length() / 1.4)
	var dir := d.normalized()
	for k in n:
		var c := a + dir * (k + 0.5) * d.length() / n
		kit.push(Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x)), c))
		kit.box(Vector3(0, 0.45, 0), Vector3(0.8, 0.9, thick), col)
		kit.pop()


## A round tower `r` wide and `h` high from y = -2 (sunk into slopes) with battlements and a
## pointed roof; a slit window on four sides.
static func round_tower(r: float, h: float) -> Mesh:
	return cached("round_tower_%.1f_%.1f" % [r, h], func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("masonry")
		kit.cylinder(Vector3(0, -2.0, 0), h + 2.0, r * 1.06, r, 12, STONE)
		kit.cylinder(Vector3(0, h, 0), 0.5, r + 0.25, r + 0.25, 12, STONE_LIGHT)
		for i in 10:
			var a := TAU * i / 10
			kit.push(Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * (r + 0.05)))
			kit.box(Vector3(0, h + 0.95, 0), Vector3(0.35, 0.9, 0.9), STONE_LIGHT)
			kit.pop()
		kit.use("solid")
		kit.cylinder(Vector3(0, h + 0.5, 0), h * 0.35, r - 0.1, 0.0, 12, ROOF)
		kit.rod(Vector3(0, h + 0.5 + h * 0.35, 0), Vector3(0, h + 2.2 + h * 0.35, 0), 0.04, 0.03, 4, IRON)
		for i in 4:
			var a := TAU * i / 4 + PI / 4
			kit.push(Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * (r + 0.02)))
			kit.box(Vector3(0, h * 0.6, 0), Vector3(0.05, 1.0, 0.25), Color("1d1b1a"))
			kit.pop()
		return kit.commit())


## The gate house: two square towers left and right of the opening (`width` wide, along x),
## a passage roof over it with battlements, the gate's open wooden leaves and a raised
## portcullis. The towers stand on y = -2 (slopes).
static func gatehouse(width: float, depth: float) -> Mesh:
	return cached("gatehouse_%.1f_%.1f" % [width, depth], func() -> Mesh:
		var kit := MeshKit.new()
		var hw := width * 0.5
		var tw := 4.2
		kit.use("masonry")
		for s: float in [-1.0, 1.0]:
			var x := s * (hw + tw * 0.5)
			kit.box(Vector3(x, 3.5, 0), Vector3(tw, 11.0, depth + 1.2), STONE)
			merlons(kit, Vector3(x - tw * 0.5, 9.0, depth * 0.5 + 0.5), Vector3(x + tw * 0.5, 9.0, depth * 0.5 + 0.5), 0.5, STONE_LIGHT)
			merlons(kit, Vector3(x - tw * 0.5, 9.0, -depth * 0.5 - 0.5), Vector3(x + tw * 0.5, 9.0, -depth * 0.5 - 0.5), 0.5, STONE_LIGHT)
		kit.box(Vector3(0, 7.4, 0), Vector3(width + 0.2, 3.2, depth), STONE)
		merlons(kit, Vector3(-hw, 9.0, depth * 0.5 - 0.2), Vector3(hw, 9.0, depth * 0.5 - 0.2), 0.5, STONE_LIGHT)
		# Arch over the opening.
		for i in 8:
			var t0 := float(i) / 8
			var t1 := float(i + 1) / 8
			var p0 := Vector3(lerpf(-hw, hw, t0), 4.6 + sin(PI * t0) * 1.2, 0)
			var p1 := Vector3(lerpf(-hw, hw, t1), 4.6 + sin(PI * t1) * 1.2, 0)
			kit.beam(p0 + Vector3(0, 0, depth * 0.5 + 0.02), p1 + Vector3(0, 0, depth * 0.5 + 0.02), Vector2(0.5, 0.3), STONE_LIGHT)
		kit.use("planks")
		for s: float in [-1.0, 1.0]:
			kit.push(Transform3D(Basis(Vector3.UP, s * 1.3), Vector3(s * hw, 0, depth * 0.5 - 0.3)))
			kit.box(Vector3(-s * hw * 0.5, 2.6, 0), Vector3(hw, 5.2, 0.18), WOOD_DARK)
			kit.pop()
		kit.use("solid")
		for k in 7:
			var x := -hw + 0.4 + k * (width - 0.8) / 6.0
			kit.box(Vector3(x, 5.6, -0.4), Vector3(0.12, 1.2, 0.12), IRON)
		kit.box(Vector3(0, 5.1, -0.4), Vector3(width - 0.6, 0.12, 0.12), IRON)
		# Banners on the towers' front.
		for s: float in [-1.0, 1.0]:
			var col := RED if s < 0 else BLUE
			kit.box(Vector3(s * (hw + tw * 0.5), 6.0, depth * 0.5 + 0.62), Vector3(1.4, 3.2, 0.05), col)
			kit.box(Vector3(s * (hw + tw * 0.5), 6.4, depth * 0.5 + 0.66), Vector3(0.6, 0.6, 0.03), GOLD)
		return kit.commit())


## The exhibition hall: stone walls, a slate roof, a big door at the front (+Z) between two
## banners, windows along the sides. `w` along x, `d` along z.
static func hall(w: float, d: float) -> Mesh:
	return cached("hall_%.1f_%.1f" % [w, d], func() -> Mesh:
		var kit := MeshKit.new()
		var hw := w * 0.5
		var hd := d * 0.5
		var h := 6.0
		kit.use("masonry")
		kit.box(Vector3(0, h * 0.5 - 1.0, 0), Vector3(w, h + 2.0, d), STONE)
		# Gable ends and roof.
		kit.tri(Vector3(hw, h, -hd), Vector3(hw, h + 3.4, 0), Vector3(hw, h, hd), STONE)
		kit.tri(Vector3(-hw, h, hd), Vector3(-hw, h + 3.4, 0), Vector3(-hw, h, -hd), STONE)
		kit.use("solid")
		kit.quad(Vector3(-hw - 0.4, h - 0.3, hd + 0.6), Vector3(hw + 0.4, h - 0.3, hd + 0.6), Vector3(hw + 0.4, h + 3.4, 0), Vector3(-hw - 0.4, h + 3.4, 0), SLATE)
		kit.quad(Vector3(hw + 0.4, h - 0.3, -hd - 0.6), Vector3(-hw - 0.4, h - 0.3, -hd - 0.6), Vector3(-hw - 0.4, h + 3.4, 0), Vector3(hw + 0.4, h + 3.4, 0), SLATE.darkened(0.15))
		kit.use("planks")
		kit.box(Vector3(0, 1.7, hd + 0.05), Vector3(2.6, 3.4, 0.12), WOOD_DARK)
		kit.use("solid")
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(s * 2.6, 3.2, hd + 0.08), Vector3(1.2, 3.6, 0.04), RED if s < 0 else BLUE)
			kit.box(Vector3(s * 2.6, 3.6, hd + 0.11), Vector3(0.5, 0.5, 0.02), GOLD)
			for k in 4:
				var x := -hw + 3.0 + k * (w - 6.0) / 3.0
				kit.box(Vector3(x, 3.4, s * (hd + 0.02)), Vector3(0.6, 1.6, 0.04), Color("2a3340"))
		return kit.commit())


## The lookout tower: square, `TOWER_TOP` high with a platform and battlements, a door at the
## front (+Z), a pointed roof over a small turret on the platform's back corner, a banner.
static func lookout_tower() -> Mesh:
	return cached("lookout_tower", func() -> Mesh:
		var kit := MeshKit.new()
		var s := 5.4
		kit.use("masonry")
		kit.box(Vector3(0, TOWER_TOP * 0.5 - 1.0, 0), Vector3(s, TOWER_TOP + 2.0, s), STONE)
		kit.box(Vector3(0, TOWER_TOP + 0.15, 0), Vector3(s + 0.6, 0.3, s + 0.6), STONE_LIGHT)
		var c := (s + 0.6) * 0.5
		for edge: Array in [[Vector3(-c, 0, c), Vector3(c, 0, c)], [Vector3(c, 0, c), Vector3(c, 0, -c)],
				[Vector3(c, 0, -c), Vector3(-c, 0, -c)], [Vector3(-c, 0, -c), Vector3(-c, 0, c)]]:
			merlons(kit, edge[0] + Vector3(0, TOWER_TOP + 0.3, 0), edge[1] + Vector3(0, TOWER_TOP + 0.3, 0), 0.4, STONE_LIGHT)
		kit.cylinder(Vector3(-1.6, TOWER_TOP, -1.6), 3.0, 1.0, 1.0, 8, STONE)
		kit.use("solid")
		kit.cylinder(Vector3(-1.6, TOWER_TOP + 3.0, -1.6), 2.4, 1.25, 0.0, 8, ROOF)
		kit.rod(Vector3(-1.6, TOWER_TOP + 5.4, -1.6), Vector3(-1.6, TOWER_TOP + 7.4, -1.6), 0.04, 0.03, 4, IRON)
		kit.box(Vector3(-1.1, TOWER_TOP + 6.9, -1.6), Vector3(1.0, 0.6, 0.03), RED)
		kit.use("planks")
		kit.box(Vector3(0, 1.3, s * 0.5 + 0.04), Vector3(1.4, 2.6, 0.1), WOOD_DARK)
		kit.use("solid")
		for y: float in [5.0, 9.0, 13.0]:
			for side in 4:
				kit.push(Transform3D(Basis(Vector3.UP, side * PI / 2), Vector3.ZERO))
				kit.box(Vector3(0, y, s * 0.5 + 0.01), Vector3(0.3, 1.2, 0.04), Color("1d1b1a"))
				kit.pop()
		return kit.commit())


## A half-timbered house `w` × `d` (tavern, stable): plaster with dark beams on a stone base,
## a steep roof, a door at the front (+Z).
static func timber_house(w: float, d: float, h: float, roof_col: Color) -> Mesh:
	return cached("timber_%.1f_%.1f_%.1f_%s" % [w, d, h, roof_col.to_html()], func() -> Mesh:
		var kit := MeshKit.new()
		var hw := w * 0.5
		var hd := d * 0.5
		kit.use("masonry")
		kit.box(Vector3(0, -0.4, 0), Vector3(w + 0.3, 1.6, d + 0.3), STONE_DARK)
		kit.use("solid")
		kit.box(Vector3(0, h * 0.5 + 0.4, 0), Vector3(w, h, d), PLASTER)
		# Beams: corners, sill, a band, diagonals.
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				kit.box(Vector3(sx * (hw - 0.1), h * 0.5 + 0.4, sz * (hd + 0.02)), Vector3(0.25, h, 0.06), WOOD_DARK)
		for sz: float in [-1.0, 1.0]:
			for y: float in [0.5, h * 0.55, h + 0.3]:
				kit.box(Vector3(0, y, sz * (hd + 0.03)), Vector3(w, 0.22, 0.06), WOOD_DARK)
			var n := int(w / 3.0)
			for k in n:
				var x0 := -hw + k * w / n
				var x1 := x0 + w / n
				kit.beam(Vector3(x0, 0.6, sz * (hd + 0.04)), Vector3(x1, h * 0.55, sz * (hd + 0.04)), Vector2(0.18, 0.05), WOOD_DARK)
		for sx: float in [-1.0, 1.0]:
			kit.box(Vector3(sx * (hw + 0.03), h * 0.55, 0), Vector3(0.06, 0.22, d), WOOD_DARK)
		# Gables and roof.
		var rise := d * 0.48
		for sx: float in [-1.0, 1.0]:
			var x := sx * hw
			if sx > 0:
				kit.tri(Vector3(x, h + 0.4, -hd), Vector3(x, h + 0.4 + rise, 0), Vector3(x, h + 0.4, hd), PLASTER)
			else:
				kit.tri(Vector3(x, h + 0.4, hd), Vector3(x, h + 0.4 + rise, 0), Vector3(x, h + 0.4, -hd), PLASTER)
		kit.quad(Vector3(-hw - 0.5, h + 0.1, hd + 0.7), Vector3(hw + 0.5, h + 0.1, hd + 0.7), Vector3(hw + 0.5, h + 0.4 + rise, 0), Vector3(-hw - 0.5, h + 0.4 + rise, 0), roof_col)
		kit.quad(Vector3(hw + 0.5, h + 0.1, -hd - 0.7), Vector3(-hw - 0.5, h + 0.1, -hd - 0.7), Vector3(-hw - 0.5, h + 0.4 + rise, 0), Vector3(hw + 0.5, h + 0.4 + rise, 0), roof_col.darkened(0.15))
		kit.use("planks")
		kit.box(Vector3(0, 1.5, hd + 0.08), Vector3(1.4, 2.4, 0.1), WOOD)
		kit.use("solid")
		for sx: float in [-1.0, 1.0]:
			for k in 2:
				var x := sx * (hw * 0.35 + k * hw * 0.35)
				kit.box(Vector3(x, 2.0, hd + 0.05), Vector3(0.9, 0.9, 0.05), Color("2a3340"))
				kit.box(Vector3(x, h * 0.78 + 0.4, hd + 0.05), Vector3(0.8, 0.8, 0.05), Color("2a3340"))
		return kit.commit())


## The smithy: an open shed with a roof on posts, a stone forge with glowing coals and a
## chimney, an anvil, a water trough, tools on the wall. Front +Z.
static func smithy() -> Mesh:
	return cached("smithy", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("solid")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				kit.box(Vector3(sx * 4.5, 1.6, sz * 3.2), Vector3(0.3, 3.2, 0.3), WOOD_DARK)
		kit.quad(Vector3(-5.2, 3.0, 4.0), Vector3(5.2, 3.0, 4.0), Vector3(5.2, 4.4, -4.0), Vector3(-5.2, 4.4, -4.0), ROOF.darkened(0.2))
		kit.quad(Vector3(5.2, 3.0, 4.0), Vector3(-5.2, 3.0, 4.0), Vector3(-5.2, 4.4, -4.0), Vector3(5.2, 4.4, -4.0), WOOD_DARK)
		kit.use("planks")
		kit.box(Vector3(0, 1.6, -3.3), Vector3(9.0, 3.2, 0.15), WOOD)
		kit.use("masonry")
		kit.box(Vector3(-2.6, 0.55, -2.2), Vector3(2.4, 1.1, 1.8), STONE_DARK)
		kit.box(Vector3(-2.6, 3.2, -2.6), Vector3(1.0, 4.6, 1.0), STONE_DARK)
		kit.use("glow")
		kit.box(Vector3(-2.6, 1.12, -2.1), Vector3(1.6, 0.08, 1.2), Color("ff6a2a"))
		kit.use("solid")
		kit.box(Vector3(0.6, 0.4, -0.6), Vector3(0.5, 0.8, 0.5), WOOD_DARK)
		kit.box(Vector3(0.6, 0.92, -0.6), Vector3(0.9, 0.25, 0.35), IRON)
		kit.box(Vector3(1.15, 0.97, -0.6), Vector3(0.3, 0.12, 0.2), IRON)
		kit.box(Vector3(3.2, 0.4, -2.2), Vector3(1.6, 0.8, 0.8), WOOD_DARK)
		kit.use("water")
		kit.box(Vector3(3.2, 0.78, -2.2), Vector3(1.4, 0.02, 0.6), Color("3d6a80"))
		kit.use("solid")
		for k in 4:
			kit.box(Vector3(-0.6 + k * 0.6, 2.0, -3.18), Vector3(0.08, 0.9, 0.04), IRON)
		kit.box(Vector3(0, 3.6, 4.05), Vector3(3.2, 0.7, 0.08), WOOD_DARK)
		return kit.commit())


## A market stall: plank counter, posts, a slanting canvas awning in `col`, goods on the
## counter by `kind` ("herbs", "potions", "food", "dice", "plain"). 4 m wide, front +Z.
static func stall(kind: String, col: Color) -> Mesh:
	return cached("stall_%s_%s" % [kind, col.to_html()], func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("planks")
		kit.box(Vector3(0, 0.5, 0.8), Vector3(3.8, 1.0, 0.7), WOOD)
		kit.box(Vector3(0, 1.03, 0.85), Vector3(4.0, 0.08, 0.85), WOOD.lightened(0.1))
		kit.use("solid")
		for sx: float in [-1.0, 1.0]:
			kit.box(Vector3(sx * 1.9, 1.4, 1.1), Vector3(0.14, 2.8, 0.14), WOOD_DARK)
			kit.box(Vector3(sx * 1.9, 1.7, -1.0), Vector3(0.14, 3.4, 0.14), WOOD_DARK)
		kit.use("canvas")
		var fixed := Color(col, 1.0)
		var free := Color(col.lightened(0.1), 0.6)
		kit.quad_c(Vector3(-2.15, 3.4, -1.15), Vector3(2.15, 3.4, -1.15), Vector3(2.15, 2.7, 1.6), Vector3(-2.15, 2.7, 1.6), fixed, fixed, free, free)
		kit.quad_c(Vector3(2.15, 3.4, -1.15), Vector3(-2.15, 3.4, -1.15), Vector3(-2.15, 2.7, 1.6), Vector3(2.15, 2.7, 1.6), fixed, fixed, free, free)
		for k in 6:
			var x := -2.15 + (k + 0.5) * 4.3 / 6.0
			var c2: Color = Color("f1e6cc") if k % 2 == 0 else col
			kit.tri(Vector3(x - 0.36, 2.7, 1.61), Vector3(x + 0.36, 2.7, 1.61), Vector3(x, 2.35, 1.62), c2)
		kit.use("solid")
		match kind:
			"herbs":
				for k in 7:
					var x := -1.6 + k * 0.53
					kit.rod(Vector3(x, 2.65, 0.2), Vector3(x, 2.15, 0.2), 0.02, 0.02, 3, WOOD_DARK)
					kit.sphere(Vector3(x, 2.05, 0.2), Vector3(0.14, 0.22, 0.14), GREEN.lightened(0.1 * (k % 3)), 2, 5)
				kit.use("solid")
				kit.cylinder(Vector3(-1.0, 1.07, 0.9), 0.25, 0.2, 0.22, 7, Color("6a5a3a"))
				kit.cylinder(Vector3(1.1, 1.07, 0.9), 0.25, 0.2, 0.22, 7, Color("7a3a5a"))
				kit.sphere(Vector3(0.0, 1.2, 0.9), Vector3(0.25, 0.15, 0.25), Color("c9a24a"), 2, 6)
			"potions":
				for k in 8:
					var x := -1.6 + k * 0.45
					var pc: Color = [Color("4ab0e0"), Color("e05a8a"), Color("7ae05a"), Color("e0c24a")][k % 4]
					kit.use("glow")
					kit.sphere(Vector3(x, 1.2, 0.95), Vector3(0.11, 0.13, 0.11), pc, 2, 6)
					kit.use("solid")
					kit.cylinder(Vector3(x, 1.3, 0.95), 0.12, 0.04, 0.03, 5, Color("d8d4c8"))
			"food":
				for k in 4:
					kit.sphere(Vector3(-1.4 + k * 0.9, 1.18, 0.9), Vector3(0.32, 0.12, 0.25), Color("c08a4a"), 2, 6)
			"dice":
				for k in 3:
					kit.box(Vector3(-0.3 + k * 0.3, 1.13, 0.9), Vector3(0.14, 0.14, 0.14), Color("f1eee6"))
				kit.cylinder(Vector3(0.8, 1.07, 0.9), 0.2, 0.18, 0.2, 8, WOOD_DARK)
		return kit.commit())


## The market's well: a round stone wall, a wooden frame with a little roof, a bucket on a rope.
static func well() -> Mesh:
	return cached("well", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("masonry")
		kit.cylinder(Vector3(0, -0.4, 0), 1.3, 1.25, 1.25, 12, STONE, true, STONE_LIGHT)
		kit.use("water")
		kit.disc(Vector3(0, 0.5, 0), 1.0, 12, Color("2e5a70"))
		kit.use("solid")
		for sx: float in [-1.0, 1.0]:
			kit.box(Vector3(sx * 1.1, 1.6, 0), Vector3(0.16, 2.4, 0.16), WOOD_DARK)
		kit.rod(Vector3(-1.2, 2.2, 0), Vector3(1.2, 2.2, 0), 0.06, 0.06, 6, WOOD)
		kit.quad(Vector3(-1.5, 2.6, 0.9), Vector3(1.5, 2.6, 0.9), Vector3(1.5, 3.3, 0), Vector3(-1.5, 3.3, 0), ROOF)
		kit.quad(Vector3(1.5, 2.6, -0.9), Vector3(-1.5, 2.6, -0.9), Vector3(-1.5, 3.3, 0), Vector3(1.5, 3.3, 0), ROOF.darkened(0.15))
		kit.rod(Vector3(0, 2.2, 0), Vector3(0, 1.4, 0), 0.01, 0.01, 3, Color("c9a86a"))
		kit.cylinder(Vector3(0, 1.1, 0), 0.3, 0.18, 0.2, 7, WOOD)
		return kit.commit())


## A cauldron on three legs over a small fire (the herb witch's).
static func cauldron() -> Mesh:
	return cached("cauldron", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("solid")
		for i in 3:
			var a := TAU * i / 3
			kit.rod(Vector3(cos(a) * 0.55, 0, sin(a) * 0.55), Vector3(cos(a) * 0.35, 0.7, sin(a) * 0.35), 0.03, 0.03, 4, IRON)
		kit.sphere(Vector3(0, 0.75, 0), Vector3(0.45, 0.35, 0.45), IRON, 3, 8)
		kit.use("glow")
		kit.disc(Vector3(0, 1.0, 0), 0.38, 10, Color("7ae05a"))
		kit.sphere(Vector3(0, 0.12, 0), Vector3(0.3, 0.12, 0.3), Color("ff7a2a"), 2, 6)
		return kit.commit())


## The tournament's stand: three tiers of benches under a striped canvas roof, `length`
## along x, the spectators face +Z. The tiers' seat heights: STAND_TIERS.
const STAND_TIERS := [0.45, 1.05, 1.65]
const STAND_DEPTH := 0.9
static func stand(length: float, col: Color) -> Mesh:
	return cached("stand_%.1f_%s" % [length, col.to_html()], func() -> Mesh:
		var kit := MeshKit.new()
		var hl := length * 0.5
		kit.use("planks")
		for i in STAND_TIERS.size():
			var y: float = STAND_TIERS[i]
			var z := -i * STAND_DEPTH
			kit.box(Vector3(0, y * 0.5, z), Vector3(length, y, STAND_DEPTH), WOOD)
		kit.use("solid")
		var n := int(length / 4.0)
		for k in n + 1:
			var x := -hl + k * length / n
			kit.box(Vector3(x, 1.9, 0.35), Vector3(0.14, 3.8, 0.14), WOOD_DARK)
			kit.box(Vector3(x, 2.5, -2.4), Vector3(0.14, 5.0, 0.14), WOOD_DARK)
		kit.use("canvas")
		for k in n:
			var x0 := -hl + k * length / n
			var x1 := x0 + length / n
			var c: Color = col if k % 2 == 0 else Color("f1e6cc")
			kit.quad_c(Vector3(x0, 5.0, -2.5), Vector3(x1, 5.0, -2.5), Vector3(x1, 3.8, 0.5), Vector3(x0, 3.8, 0.5), Color(c, 1.0), Color(c, 1.0), Color(c, 0.7), Color(c, 0.7))
			kit.quad_c(Vector3(x1, 5.0, -2.5), Vector3(x0, 5.0, -2.5), Vector3(x0, 3.8, 0.5), Vector3(x1, 3.8, 0.5), Color(c, 1.0), Color(c, 1.0), Color(c, 0.7), Color(c, 0.7))
		kit.use("solid")
		for k in n:
			var x := -hl + (k + 0.5) * length / n
			kit.box(Vector3(x, 3.4, 0.55), Vector3(1.0, 0.8, 0.04), RED if k % 2 == 0 else BLUE)
			kit.box(Vector3(x, 3.45, 0.58), Vector3(0.4, 0.4, 0.02), GOLD)
		return kit.commit())


## The tilt in the middle of the lists: a wooden barrier `length` long along x, painted in
## stripes, with a pennant pole at each end.
static func tilt(length: float) -> Mesh:
	return cached("tilt_%.1f" % length, func() -> Mesh:
		var kit := MeshKit.new()
		var hl := length * 0.5
		var n := int(length / 2.0)
		kit.use("solid")
		for k in n:
			var x := -hl + (k + 0.5) * length / n
			kit.box(Vector3(x, 0.75, 0), Vector3(length / n, 0.5, 0.12), RED if k % 2 == 0 else Color("f1e6cc"))
		for k in n + 1:
			kit.box(Vector3(-hl + k * length / n, 0.55, 0), Vector3(0.14, 1.1, 0.3), WOOD_DARK)
		for s: float in [-1.0, 1.0]:
			kit.rod(Vector3(s * (hl + 0.5), 0, 0), Vector3(s * (hl + 0.5), 4.0, 0), 0.05, 0.04, 5, WOOD_DARK)
			kit.box(Vector3(s * (hl + 0.5) - s * 0.6, 3.6, 0), Vector3(1.2, 0.6, 0.03), BLUE if s > 0 else RED)
		return kit.commit())


## A post-and-rail fence segment (lists, paddock, sword ring) `length` long along x.
static func rail_fence(length: float) -> Mesh:
	return cached("rail_%.1f" % length, func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("solid")
		kit.box(Vector3(0, 0.55, 0), Vector3(0.14, 1.1, 0.14), WOOD_DARK)
		for y: float in [0.45, 0.9]:
			kit.box(Vector3(length * 0.5, y, 0), Vector3(length, 0.1, 0.07), WOOD)
		return kit.commit())


## An archery target: a straw boss with painted rings on a wooden easel, facing +Z.
static func target() -> Mesh:
	return cached("target", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("solid")
		kit.beam(Vector3(-0.6, 0, -0.5), Vector3(0, 2.0, 0), Vector2(0.1, 0.1), WOOD_DARK)
		kit.beam(Vector3(0.6, 0, -0.5), Vector3(0, 2.0, 0), Vector2(0.1, 0.1), WOOD_DARK)
		kit.beam(Vector3(0, 0, -1.0), Vector3(0, 1.9, -0.1), Vector2(0.1, 0.1), WOOD_DARK)
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2 - 0.12), Vector3(0, 1.25, 0.05)))
		kit.cylinder(Vector3(0, -0.12, 0), 0.24, 0.62, 0.62, 16, STRAW)
		var rings := [[0.6, Color("f1eee6")], [0.48, Color("2a2a30")], [0.36, Color("2f5fa8")], [0.24, Color("b8322a")], [0.12, Color("e2c050")]]
		for k in rings.size():
			kit.cylinder(Vector3(0, 0.12 + k * 0.004, 0), 0.004, rings[k][0], rings[k][0], 16, rings[k][1], true)
		kit.pop()
		return kit.commit())


## A wooden stage 6 × 4 m, 0.8 m high, with steps at the front and a curtain backdrop in
## `col` (the jugglers' and minstrels').
static func stage(col: Color) -> Mesh:
	return cached("stage_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("planks")
		kit.box(Vector3(0, 0.4, 0), Vector3(6.0, 0.8, 4.0), WOOD)
		kit.box(Vector3(0, 0.15, 2.3), Vector3(1.6, 0.3, 0.6), WOOD)
		kit.box(Vector3(0, 0.45, 2.15), Vector3(1.6, 0.3, 0.3), WOOD)
		kit.use("solid")
		for sx: float in [-1.0, 1.0]:
			kit.box(Vector3(sx * 2.9, 2.6, -1.9), Vector3(0.18, 3.6, 0.18), WOOD_DARK)
		kit.box(Vector3(0, 4.35, -1.9), Vector3(6.0, 0.18, 0.18), WOOD_DARK)
		kit.use("canvas")
		for k in 8:
			var x0 := -2.8 + k * 0.7
			var c: Color = col if k % 2 == 0 else col.darkened(0.2)
			kit.quad_c(Vector3(x0, 4.25, -1.92), Vector3(x0 + 0.7, 4.25, -1.92), Vector3(x0 + 0.7, 0.8, -1.92), Vector3(x0, 0.8, -1.92), Color(c, 1), Color(c, 1), Color(c, 0.8), Color(c, 0.8))
			kit.quad_c(Vector3(x0 + 0.7, 4.25, -1.94), Vector3(x0, 4.25, -1.94), Vector3(x0, 0.8, -1.94), Vector3(x0 + 0.7, 0.8, -1.94), Color(c, 1), Color(c, 1), Color(c, 0.8), Color(c, 0.8))
		kit.use("solid")
		kit.box(Vector3(0, 4.0, -1.85), Vector3(2.4, 0.5, 0.04), GOLD)
		return kit.commit())


## The puppet theatre: a tall painted booth with a curtained window at the top front, two
## little puppets in it.
static func puppet_theatre() -> Mesh:
	return cached("puppet_theatre", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("boards")
		kit.box(Vector3(0, 1.0, 0), Vector3(2.6, 2.0, 1.2), Color("c96a2a"))
		kit.box(Vector3(0, 2.9, -0.4), Vector3(2.6, 1.8, 0.4), Color("c96a2a"))
		kit.box(Vector3(0, 3.95, 0), Vector3(2.8, 0.3, 1.3), Color("2f5fa8"))
		for sx: float in [-1.0, 1.0]:
			kit.box(Vector3(sx * 1.2, 2.9, 0.1), Vector3(0.2, 1.8, 0.4), Color("c96a2a"))
		kit.use("canvas")
		for sx: float in [-1.0, 1.0]:
			kit.quad_c(Vector3(sx * 1.1, 3.75, 0.32), Vector3(sx * 0.6, 3.75, 0.32), Vector3(sx * 0.8, 2.1, 0.32), Vector3(sx * 1.1, 2.1, 0.32), Color(RED, 1), Color(RED, 1), Color(RED, 0.7), Color(RED, 0.7))
		kit.use("solid")
		kit.box(Vector3(0, 2.05, 0.25), Vector3(2.2, 0.1, 0.3), WOOD)
		kit.sphere(Vector3(-0.35, 2.45, 0.2), Vector3(0.12, 0.14, 0.12), Color("f0c8a0"), 2, 6)
		kit.cylinder(Vector3(-0.35, 2.52, 0.2), 0.25, 0.09, 0.0, 6, RED)
		kit.box(Vector3(-0.35, 2.2, 0.2), Vector3(0.22, 0.3, 0.12), Color("e2c050"))
		kit.sphere(Vector3(0.35, 2.45, 0.2), Vector3(0.12, 0.14, 0.12), Color("e0b890"), 2, 6)
		kit.box(Vector3(0.35, 2.58, 0.2), Vector3(0.22, 0.08, 0.2), IRON)
		kit.box(Vector3(0.35, 2.2, 0.2), Vector3(0.22, 0.3, 0.12), Color("5a5a60"))
		kit.box(Vector3(0, 4.2, 0.66), Vector3(1.6, 0.4, 0.04), Color("f1e6cc"))
		return kit.commit())


## The magician's corner: a dark canopy on four posts with hanging stars, a table with a
## crystal ball and a high-backed chair. Front +Z.
static func magician_corner() -> Mesh:
	return cached("magician_corner", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("solid")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				kit.box(Vector3(sx * 1.8, 1.4, sz * 1.5), Vector3(0.12, 2.8, 0.12), Color("2a2030"))
		kit.use("canvas")
		kit.quad_c(Vector3(-2.0, 2.8, -1.7), Vector3(2.0, 2.8, -1.7), Vector3(2.0, 2.8, 1.7), Vector3(-2.0, 2.8, 1.7), Color(PURPLE, 1), Color(PURPLE, 1), Color(PURPLE, 0.8), Color(PURPLE, 0.8))
		kit.quad_c(Vector3(2.0, 2.8, -1.7), Vector3(-2.0, 2.8, -1.7), Vector3(-2.0, 2.8, 1.7), Vector3(2.0, 2.8, 1.7), Color(PURPLE, 1), Color(PURPLE, 1), Color(PURPLE, 0.8), Color(PURPLE, 0.8))
		kit.quad_c(Vector3(-2.0, 2.8, -1.72), Vector3(2.0, 2.8, -1.72), Vector3(2.0, 0.3, -1.72), Vector3(-2.0, 0.3, -1.72), Color(PURPLE.darkened(0.3), 1), Color(PURPLE.darkened(0.3), 1), Color(PURPLE.darkened(0.3), 0.8), Color(PURPLE.darkened(0.3), 0.8))
		kit.quad_c(Vector3(2.0, 2.8, -1.74), Vector3(-2.0, 2.8, -1.74), Vector3(-2.0, 0.3, -1.74), Vector3(2.0, 0.3, -1.74), Color(PURPLE.darkened(0.3), 1), Color(PURPLE.darkened(0.3), 1), Color(PURPLE.darkened(0.3), 0.8), Color(PURPLE.darkened(0.3), 0.8))
		kit.use("solid")
		kit.cylinder(Vector3(0, 0, 0.3), 0.8, 0.12, 0.12, 6, Color("2a2030"))
		kit.cylinder(Vector3(0, 0.8, 0.3), 0.05, 0.6, 0.6, 10, Color("1e2a4a"))
		kit.box(Vector3(0, 0.55, -0.9), Vector3(0.7, 1.1, 0.6), Color("3a2a1e"))
		kit.box(Vector3(0, 1.5, -1.15), Vector3(0.7, 1.3, 0.12), Color("3a2a1e"))
		kit.use("glow")
		kit.sphere(Vector3(0, 1.05, 0.3), Vector3(0.2, 0.2, 0.2), Color("9fd0ff"), 3, 7)
		for i in 7:
			var x := -1.5 + i * 0.5
			kit.box(Vector3(x, 2.4 - (i % 3) * 0.25, 1.2 - (i % 2) * 1.8), Vector3(0.14, 0.14, 0.03), GOLD)
		return kit.commit())


## A torch on a post (or on a wall bracket: `wall`), 2.6 m high; the flame is torch_flame().
const TORCH_Y := 2.6
static func torch(wall := false) -> Mesh:
	return cached("torch_%s" % wall, func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("solid")
		if wall:
			kit.box(Vector3(0, TORCH_Y - 0.5, -0.25), Vector3(0.1, 0.1, 0.5), IRON)
		else:
			kit.rod(Vector3(0, 0, 0), Vector3(0, TORCH_Y - 0.3, 0), 0.06, 0.05, 5, WOOD_DARK)
		kit.cylinder(Vector3(0, TORCH_Y - 0.35, 0), 0.3, 0.08, 0.16, 6, IRON)
		return kit.commit())


## Flames of all torches in one mesh (shown at night, Burg.flames).
static func flames_into(kit: MeshKit, p: Vector3) -> void:
	kit.use("glow")
	kit.cylinder(p + Vector3(0, -0.05, 0), 0.5, 0.13, 0.0, 5, FLAME)
	kit.cylinder(p + Vector3(0, -0.02, 0), 0.32, 0.08, 0.0, 4, Color("fff1a8"))


## A banner on a pole, `col` with a gold emblem.
static func banner(col: Color) -> Mesh:
	return cached("banner_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("solid")
		kit.rod(Vector3.ZERO, Vector3(0, 5.2, 0), 0.05, 0.04, 5, WOOD_DARK)
		kit.box(Vector3(0, 5.0, 0), Vector3(1.4, 0.06, 0.06), WOOD_DARK)
		kit.use("canvas")
		kit.quad_c(Vector3(-0.6, 4.95, 0), Vector3(0.6, 4.95, 0), Vector3(0.6, 2.6, 0), Vector3(-0.6, 2.6, 0), Color(col, 1), Color(col, 1), Color(col, 0.7), Color(col, 0.7))
		kit.quad_c(Vector3(0.6, 4.95, -0.01), Vector3(-0.6, 4.95, -0.01), Vector3(-0.6, 2.6, -0.01), Vector3(0.6, 2.6, -0.01), Color(col, 1), Color(col, 1), Color(col, 0.7), Color(col, 0.7))
		kit.use("solid")
		kit.box(Vector3(0, 4.0, 0.02), Vector3(0.5, 0.5, 0.02), GOLD)
		kit.box(Vector3(0, 4.0, -0.03), Vector3(0.5, 0.5, 0.02), GOLD)
		return kit.commit())


## The wooden gate in a border fence with a sign board over it (Burgpforte, Waldweg),
## `width` wide along x.
static func border_gate(width: float) -> Mesh:
	return cached("border_gate_%.1f" % width, func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("solid")
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(s * (width * 0.5 + 0.2), 1.9, 0), Vector3(0.35, 3.8, 0.35), WOOD_DARK)
			kit.sphere(Vector3(s * (width * 0.5 + 0.2), 3.9, 0), Vector3(0.22, 0.22, 0.22), WOOD_DARK, 2, 5)
		kit.box(Vector3(0, 3.5, 0), Vector3(width + 0.9, 0.3, 0.3), WOOD_DARK)
		kit.box(Vector3(0, 2.95, 0), Vector3(width * 0.8, 0.7, 0.08), Color("e8d8b0"))
		return kit.commit())


## The secret door in the rock: a low wooden door with iron bands under an overhang of rock.
static func secret_door() -> Mesh:
	return cached("secret_door", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("planks")
		kit.box(Vector3(0, 0.95, 0), Vector3(1.2, 1.9, 0.12), WOOD_DARK)
		kit.use("solid")
		for y: float in [0.4, 1.5]:
			kit.box(Vector3(0, y, 0.07), Vector3(1.22, 0.1, 0.03), IRON)
		kit.sphere(Vector3(0.4, 0.95, 0.09), Vector3(0.05, 0.05, 0.05), IRON, 2, 4)
		kit.use("masonry")
		kit.box(Vector3(0, 2.3, -0.2), Vector3(2.4, 0.8, 0.9), STONE_DARK)
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(s * 0.95, 1.0, -0.2), Vector3(0.5, 2.0, 0.8), STONE_DARK)
		return kit.commit())


## A display stand of the exhibition: a suit of armour on a pedestal (`col`: the plume).
static func armour(col: Color) -> Mesh:
	return cached("armour_%s" % col.to_html(), func() -> Mesh:
		var kit := MeshKit.new()
		var steel := Color("b8bcc0")
		kit.use("masonry")
		kit.box(Vector3(0, 0.2, 0), Vector3(0.9, 0.4, 0.9), STONE_LIGHT)
		kit.use("solid")
		for s: float in [-1.0, 1.0]:
			kit.cylinder(Vector3(s * 0.14, 0.4, 0), 0.85, 0.09, 0.1, 6, steel)
		kit.cylinder(Vector3(0, 1.2, 0), 0.65, 0.24, 0.3, 8, steel)
		for s: float in [-1.0, 1.0]:
			kit.sphere(Vector3(s * 0.34, 1.78, 0), Vector3(0.14, 0.12, 0.14), steel, 2, 6)
			kit.rod(Vector3(s * 0.36, 1.72, 0), Vector3(s * 0.4, 1.15, 0.08), 0.07, 0.06, 6, steel)
		kit.cylinder(Vector3(0, 1.85, 0), 0.4, 0.17, 0.15, 8, steel)
		kit.box(Vector3(0, 2.05, 0.15), Vector3(0.22, 0.05, 0.02), Color("1d1b1a"))
		kit.sphere(Vector3(0, 2.32, -0.05), Vector3(0.08, 0.22, 0.22), col, 2, 5)
		return kit.commit())


## A shield on the wall: round or heater-shaped, two colours.
static func shield(a: Color, b: Color) -> Mesh:
	return cached("shield_%s_%s" % [a.to_html(), b.to_html()], func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("solid")
		var pts := PackedVector2Array([Vector2(-0.4, 0.5), Vector2(0.4, 0.5), Vector2(0.4, 0.0), Vector2(0.0, -0.55), Vector2(-0.4, 0.0)])
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
		kit.prism(pts, 0.0, 0.05, a)
		kit.pop()
		kit.box(Vector3(0, 0.1, 0.06), Vector3(0.14, 0.8, 0.02), b)
		kit.box(Vector3(0, 0.15, 0.06), Vector3(0.7, 0.14, 0.02), b)
		return kit.commit())

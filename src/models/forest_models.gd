class_name ForestModels
extends RefCounted
## Procedural buildings and props of the Nordwald (doc/nordwald.md): lumber camp, sawmill,
## forest inn, quarry and the dwarves' mine. Origins sit on the ground; front faces +Z.

const LOG := Color("8a5a34")
const LOG_DARK := Color("5e3d22")
const LOG_END := Color("d2ac78")
const ROOF := Color("5a3a2a")
const ROOF_MOSS := Color("5d6e3a")
const ROCK := Color("8f897e")
const ROCK_DARK := Color("6e6960")
const IRON := Color("3a3a3e")
const FIRE := Color("ffb347")


static func cached(key: String, builder: Callable) -> Mesh:
	return NatureModels.cached("forest_" + key, builder)


## Gable roof over a w × d rectangle from height y0, ridge along X, overhang o.
static func _gable(kit: MeshKit, w: float, d: float, y0: float, rise: float, col: Color, o := 0.4) -> void:
	var x := w * 0.5 + o
	var z := d * 0.5 + o
	var top := y0 + rise
	var slab := 0.12
	for s: float in [1.0, -1.0]:
		var a := Vector3(-x, y0 - o * 0.4, z * s)
		var b := Vector3(x, y0 - o * 0.4, z * s)
		var c := Vector3(x, top, 0)
		var e := Vector3(-x, top, 0)
		if s > 0:
			kit.quad(a, b, c, e, col)
			kit.quad(a + Vector3(0, -slab, 0), e + Vector3(0, -slab, 0), c + Vector3(0, -slab, 0), b + Vector3(0, -slab, 0), col.darkened(0.3))
		else:
			kit.quad(b, a, e, c, col)
			kit.quad(b + Vector3(0, -slab, 0), c + Vector3(0, -slab, 0), e + Vector3(0, -slab, 0), a + Vector3(0, -slab, 0), col.darkened(0.3))
	# Gable triangles.
	for s: float in [1.0, -1.0]:
		var gx := w * 0.5 * s
		var p0 := Vector3(gx, y0, d * 0.5)
		var p1 := Vector3(gx, y0, -d * 0.5)
		var p2 := Vector3(gx, top - 0.05, 0)
		if s > 0:
			kit.tri(p0, p1, p2, LOG)
		else:
			kit.tri(p1, p0, p2, LOG)


## Log walls of a w × d cabin, height h: horizontal logs with light ends.
static func _log_walls(kit: MeshKit, w: float, d: float, h: float) -> void:
	kit.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), LOG)
	var rows := int(h / 0.32)
	for i in rows:
		var y := 0.16 + i * 0.32
		for s: float in [1.0, -1.0]:
			kit.box(Vector3(0, y, s * (d * 0.5 + 0.02)), Vector3(w, 0.05, 0.02), LOG_DARK)
			kit.box(Vector3(s * (w * 0.5 + 0.02), y, 0), Vector3(0.02, 0.05, d), LOG_DARK)
		# Crossed log ends at the corners.
		for sx: float in [1.0, -1.0]:
			for sz: float in [1.0, -1.0]:
				kit.box(Vector3(sx * (w * 0.5 + 0.12), y, sz * (d * 0.5 + 0.12)), Vector3(0.22, 0.26, 0.22), LOG_END)


## Window with a frame; glowing glass so it shows at night.
static func _window(kit: MeshKit, p: Vector3, size: Vector2, facing_z := true) -> void:
	var frame := Vector3(size.x + 0.16, size.y + 0.16, 0.06) if facing_z else Vector3(0.06, size.y + 0.16, size.x + 0.16)
	kit.box(p, frame, LOG_DARK)
	kit.use("glow")
	var glass := Vector3(size.x, size.y, 0.07) if facing_z else Vector3(0.07, size.y, size.x)
	kit.box(p, glass, PropModels.GLASS_WARM.darkened(0.25))
	kit.use("solid")


## Forest inn "Waldschänke": log house with a porch, chimney and a terrace in front (+Z).
static func forest_inn() -> Mesh:
	return cached("inn", func() -> Mesh:
		var kit := MeshKit.new()
		var w := 10.0
		var d := 6.5
		kit.translate(Vector3(0, 0, -2.0))
		kit.box(Vector3(0, 0.15, 0), Vector3(w + 0.6, 0.3, d + 0.6), PropModels.STONE_DARK)
		kit.translate(Vector3(0, 0.3, 0))
		_log_walls(kit, w, d, 3.2)
		_gable(kit, w, d, 3.2, 2.6, ROOF)
		kit.box(Vector3(3.0, 5.2, -1.2), Vector3(0.7, 2.4, 0.7), PropModels.STONE, PropModels.STONE_DARK)
		kit.box(Vector3(0, 1.1, d * 0.5 + 0.03), Vector3(1.2, 2.2, 0.06), LOG_DARK)
		kit.box(Vector3(0.4, 1.1, d * 0.5 + 0.07), Vector3(0.08, 0.08, 0.04), Color("d8b040"))
		for x: float in [-3.4, -1.8, 1.8, 3.4]:
			_window(kit, Vector3(x, 1.7, d * 0.5 + 0.03), Vector2(0.9, 0.9))
		for z: float in [-1.5, 1.5]:
			for s: float in [1.0, -1.0]:
				_window(kit, Vector3(s * (w * 0.5 + 0.03), 1.7, z), Vector2(0.8, 0.8), false)
		# Sign board over the door.
		kit.box(Vector3(0, 2.75, d * 0.5 + 0.08), Vector3(3.4, 0.6, 0.08), Color("3e2a1a"))
		kit.pop()
		kit.pop()
		# Terrace (low, so walkers' feet stay on it) with a railing open in the middle.
		kit.box(Vector3(0, 0.06, 3.3), Vector3(w, 0.12, 4.4), PropModels.WOOD_LIGHT)
		for i in 11:
			var x := -w * 0.5 + i * w / 10.0
			if absf(x) > 1.0:
				kit.box(Vector3(x, 0.45, 5.45), Vector3(0.08, 0.7, 0.08), LOG_DARK)
		kit.box(Vector3(-3.0, 0.8, 5.45), Vector3(4.0, 0.08, 0.1), LOG)
		kit.box(Vector3(3.0, 0.8, 5.45), Vector3(4.0, 0.08, 0.1), LOG)
		return kit.commit())


## Open sawmill shed: posts, roof, saw bench with a big blade, plank stack.
static func sawmill() -> Mesh:
	return cached("sawmill", func() -> Mesh:
		var kit := MeshKit.new()
		var w := 9.0
		var d := 5.0
		for x: float in [-w * 0.5, w * 0.5]:
			for z: float in [-d * 0.5, d * 0.5]:
				kit.box(Vector3(x, 1.6, z), Vector3(0.25, 3.2, 0.25), LOG_DARK)
		_gable(kit, w, d, 3.2, 1.5, ROOF_MOSS, 0.5)
		kit.box(Vector3(0, 0.05, 0), Vector3(w, 0.1, d), Color("8a7a5a"))
		# Saw bench along X with a log on it.
		kit.box(Vector3(0, 0.45, 0), Vector3(6.0, 0.9, 1.0), PropModels.WOOD)
		kit.rod(Vector3(-2.8, 1.25, 0), Vector3(-0.4, 1.25, 0), 0.35, 0.33, 8, LOG)
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0.2, 1.1, 0)))
		kit.cylinder(Vector3(0, -0.02, 0), 0.04, 0.6, 0.6, 14, Color("c8ccd0"))
		kit.pop()
		kit.box(Vector3(0.2, 0.75, 0), Vector3(0.4, 0.6, 0.5), IRON)
		kit.box(Vector3(0, 2.75, d * 0.5 + 0.05), Vector3(3.2, 0.6, 0.08), Color("3e2a1a"))
		# Plank stack and sawdust.
		for i in 5:
			kit.box(Vector3(3.2, 0.1 + i * 0.1, -1.6), Vector3(2.4, 0.08, 0.9), PropModels.WOOD_LIGHT.darkened(i * 0.04))
		kit.sphere(Vector3(1.2, 0.0, 0.7), Vector3(0.6, 0.15, 0.4), Color("e0c89a"), 2, 6)
		return kit.commit())


## A pile of logs (along X), ends showing.
static func log_pile(rows := 3) -> Mesh:
	return cached("log_pile_%d" % rows, func() -> Mesh:
		var kit := MeshKit.new()
		for r in rows:
			var n := rows - r + 1
			for i in n:
				var z := (i - (n - 1) * 0.5) * 0.46
				var y := 0.22 + r * 0.38
				kit.rod(Vector3(-1.4, y, z), Vector3(1.4, y, z), 0.22, 0.22, 7, LOG)
				for s: float in [-1.0, 1.0]:
					kit.push(Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(s * 1.41, y, z)))
					kit.cylinder(Vector3.ZERO, 0.01, 0.2, 0.2, 7, LOG_END)
					kit.pop()
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(s * 1.1, 0.5, (rows * 0.23 + 0.15)), Vector3(0.1, 1.0, 0.1), LOG_DARK)
			kit.box(Vector3(s * 1.1, 0.5, -(rows * 0.23 + 0.15)), Vector3(0.1, 1.0, 0.1), LOG_DARK)
		return kit.commit())


## Workbench with a vise, saw and hammer.
static func workbench() -> Mesh:
	return cached("workbench", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.88, 0), Vector3(2.2, 0.12, 0.9), PropModels.WOOD_LIGHT)
		for x: float in [-1.0, 1.0]:
			for z: float in [-0.35, 0.35]:
				kit.box(Vector3(x, 0.42, z), Vector3(0.1, 0.84, 0.1), PropModels.WOOD_DARK)
		kit.box(Vector3(0, 0.25, 0), Vector3(2.0, 0.06, 0.7), PropModels.WOOD)
		kit.box(Vector3(-0.8, 1.02, 0.42), Vector3(0.3, 0.16, 0.14), IRON)
		kit.box(Vector3(0.3, 0.96, 0.0), Vector3(0.7, 0.02, 0.14), Color("c8ccd0"))
		kit.box(Vector3(0.75, 0.97, 0.0), Vector3(0.18, 0.06, 0.08), PropModels.WOOD_DARK)
		kit.beam(Vector3(0.5, 0.96, -0.25), Vector3(0.9, 0.96, -0.3), Vector2(0.04, 0.04), PropModels.WOOD_DARK)
		kit.box(Vector3(0.92, 0.98, -0.3), Vector3(0.08, 0.1, 0.16), IRON)
		# Tool wall behind.
		kit.box(Vector3(0, 1.5, -0.48), Vector3(2.2, 1.1, 0.06), PropModels.WOOD)
		for i in 4:
			kit.beam(Vector3(-0.8 + i * 0.5, 1.2, -0.43), Vector3(-0.8 + i * 0.5, 1.8, -0.43), Vector2(0.04, 0.03), PropModels.WOOD_DARK)
			kit.box(Vector3(-0.8 + i * 0.5, 1.82, -0.42), Vector3(0.16, 0.1, 0.03), IRON)
		return kit.commit())


## Stone ring with crossed logs; the flames are a separate glowing mesh (campfire_flames).
static func campfire() -> Mesh:
	return cached("campfire", func() -> Mesh:
		var kit := MeshKit.new()
		for i in 9:
			var a := TAU * i / 9.0
			kit.sphere(Vector3(cos(a) * 0.75, 0.08, sin(a) * 0.75), Vector3(0.2, 0.14, 0.18), ROCK if i % 2 == 0 else ROCK_DARK, 2, 5)
		for i in 4:
			var a := TAU * i / 4.0 + 0.3
			kit.rod(Vector3(cos(a) * 0.55, 0.06, sin(a) * 0.55), Vector3(0, 0.38, 0), 0.07, 0.05, 5, LOG_DARK)
		kit.disc(Vector3(0, 0.03, 0), 0.55, 9, Color("2a2420"))
		return kit.commit())


static func campfire_flames() -> Mesh:
	return cached("flames", func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("glow")
		kit.cylinder(Vector3(0, 0.05, 0), 0.75, 0.3, 0.0, 6, FIRE)
		kit.cylinder(Vector3(0.12, 0.05, 0.05), 0.5, 0.18, 0.0, 5, Color("ff7a2a"))
		kit.cylinder(Vector3(-0.1, 0.05, -0.08), 0.55, 0.16, 0.0, 5, Color("ffd36a"))
		return kit.commit())


## Chopping block (a stump) with an axe stuck in it and split logs around.
static func chopping_block() -> Mesh:
	return cached("chopping_block", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.55, 0.42, 0.4, 9, LOG, true, LOG_END)
		kit.beam(Vector3(0.05, 0.55, 0), Vector3(0.35, 1.05, 0.1), Vector2(0.05, 0.04), PropModels.WOOD_LIGHT)
		kit.box(Vector3(0.03, 0.6, 0), Vector3(0.22, 0.12, 0.04), Color("b8bcc0"))
		for i in 5:
			var a := 0.6 + i * 0.5
			kit.push(Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 1.0, 0.1, sin(a) * 1.0)))
			kit.box(Vector3.ZERO, Vector3(0.45, 0.16, 0.16), LOG_END if i % 2 == 0 else LOG)
			kit.pop()
		return kit.commit())


## Axe-throwing target: round wooden disc with rings on an A-frame, facing +Z.
static func axe_target() -> Mesh:
	return cached("axe_target", func() -> Mesh:
		var kit := MeshKit.new()
		for s: float in [-1.0, 1.0]:
			kit.beam(Vector3(s * 0.9, 0, -0.5), Vector3(s * 0.7, 2.2, 0), Vector2(0.12, 0.12), LOG_DARK)
		kit.beam(Vector3(-0.9, 0.9, -0.25), Vector3(0.9, 0.9, -0.25), Vector2(0.08, 0.08), LOG_DARK)
		var rings := [Color("efe1c4"), Color("c0392b"), Color("efe1c4"), Color("2e6fb8"), Color("f2c230")]
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1.5, 0.05)))
		kit.cylinder(Vector3(0, -0.1, 0), 0.1, 0.75, 0.75, 16, LOG_END)
		for i in rings.size():
			kit.cylinder(Vector3(0, 0.0 + i * 0.004, 0), 0.004, 0.7 - i * 0.14, 0.7 - i * 0.14, 16, rings[i])
		kit.pop()
		return kit.commit())


## Hammock between two posts (along X).
static func hammock() -> Mesh:
	return cached("hammock", func() -> Mesh:
		var kit := MeshKit.new()
		for s: float in [-1.0, 1.0]:
			kit.cylinder(Vector3(s * 1.6, 0, 0), 1.8, 0.1, 0.09, 6, LOG_DARK)
		var cloth := [Color("d0573f"), Color("f2d080")]
		var n := 8
		for i in n:
			var t0 := float(i) / n
			var t1 := float(i + 1) / n
			var x0 := lerpf(-1.3, 1.3, t0)
			var x1 := lerpf(-1.3, 1.3, t1)
			var y0 := 1.25 - sin(PI * t0) * 0.55
			var y1 := 1.25 - sin(PI * t1) * 0.55
			kit.quad(Vector3(x0, y0, -0.4), Vector3(x0, y0, 0.4), Vector3(x1, y1, 0.4), Vector3(x1, y1, -0.4), cloth[i % 2])
			kit.quad(Vector3(x0, y0 - 0.02, 0.4), Vector3(x0, y0 - 0.02, -0.4), Vector3(x1, y1 - 0.02, -0.4), Vector3(x1, y1 - 0.02, 0.4), cloth[i % 2].darkened(0.2))
		for s: float in [-1.0, 1.0]:
			kit.beam(Vector3(s * 1.6, 1.55, 0), Vector3(s * 1.3, 1.25, 0), Vector2(0.03, 0.03), Color("d8c9a0"))
		return kit.commit())


## Storage chest with iron bands.
static func chest() -> Mesh:
	return cached("chest", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.35, 0), Vector3(1.2, 0.7, 0.7), PropModels.WOOD)
		kit.box(Vector3(0, 0.78, 0), Vector3(1.24, 0.16, 0.74), PropModels.WOOD_DARK)
		for x: float in [-0.4, 0.4]:
			kit.box(Vector3(x, 0.45, 0), Vector3(0.08, 0.9, 0.76), IRON)
		kit.box(Vector3(0, 0.62, 0.37), Vector3(0.14, 0.18, 0.04), Color("d8b040"))
		return kit.commit())


## Lumberjack's hut: small log cabin.
static func hut() -> Mesh:
	return cached("hut", func() -> Mesh:
		var kit := MeshKit.new()
		_log_walls(kit, 4.0, 3.2, 2.4)
		_gable(kit, 4.0, 3.2, 2.4, 1.4, ROOF_MOSS)
		kit.box(Vector3(0.6, 0.95, 1.63), Vector3(0.9, 1.9, 0.06), LOG_DARK)
		_window(kit, Vector3(-1.0, 1.4, 1.63), Vector2(0.6, 0.6))
		kit.box(Vector3(-1.4, 2.4, -0.6), Vector3(0.4, 1.6, 0.4), PropModels.STONE)
		return kit.commit())


## The dwarves' office: low stone hut with a turf roof, round door and round windows.
static func dwarf_office() -> Mesh:
	return cached("dwarf_office", func() -> Mesh:
		var kit := MeshKit.new()
		var w := 5.0
		var d := 4.0
		kit.box(Vector3(0, 1.1, 0), Vector3(w, 2.2, d), ROCK, ROCK_DARK)
		# Stone blocks pattern.
		for i in 6:
			for j in 3:
				var x := -w * 0.5 + 0.45 + i * 0.82 + (0.4 if j % 2 == 1 else 0.0)
				if x < w * 0.5 - 0.3:
					kit.box(Vector3(x, 0.35 + j * 0.7, d * 0.5 + 0.02), Vector3(0.7, 0.6, 0.03), ROCK.lightened(0.06 * ((i + j) % 3)))
		# Turf roof (rounded) with grass.
		kit.sphere(Vector3(0, 2.2, 0), Vector3(w * 0.62, 1.1, d * 0.66), Color("5f8a3c"), 3, 10, 0.06, 3, ROCK_DARK)
		# Round door (arched) and windows.
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.0, d * 0.5 + 0.03)))
		kit.cylinder(Vector3(0, 0, -0.85), 0.04, 0.7, 0.7, 12, Color("2e7d5b"))
		kit.pop()
		kit.box(Vector3(0, 0.42, d * 0.5 + 0.035), Vector3(1.4, 0.84, 0.04), Color("2e7d5b"))
		kit.box(Vector3(0.45, 0.8, d * 0.5 + 0.07), Vector3(0.1, 0.1, 0.04), Color("d8b040"))
		for x: float in [-1.7, 1.7]:
			kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(x, 0.0, d * 0.5 + 0.02)))
			kit.cylinder(Vector3(0, 0, -1.3), 0.03, 0.38, 0.38, 10, LOG_DARK)
			kit.use("glow")
			kit.cylinder(Vector3(0, 0.03, -1.3), 0.02, 0.3, 0.3, 10, PropModels.GLASS_WARM.darkened(0.25))
			kit.use("solid")
			kit.pop()
		# Sign board on two posts.
		kit.box(Vector3(0, 2.75, d * 0.5 + 0.35), Vector3(3.2, 0.55, 0.08), Color("3e2a1a"))
		return kit.commit())


## Mine entrance: timber frame in front of a dark opening (front +Z), lanterns.
static func mine_portal() -> Mesh:
	return cached("mine_portal", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 1.6, -1.2), Vector3(3.4, 3.2, 2.4), Color("141210"))
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(s * 1.8, 1.7, 0), Vector3(0.4, 3.4, 0.4), LOG_DARK)
			kit.box(Vector3(s * 1.8, 1.7, -0.8), Vector3(0.36, 3.4, 0.36), LOG_DARK)
		kit.box(Vector3(0, 3.5, 0), Vector3(4.4, 0.45, 0.5), LOG)
		kit.box(Vector3(0, 3.5, -0.8), Vector3(4.2, 0.4, 0.4), LOG_DARK)
		# Rock collar around the frame.
		for i in 9:
			var a := PI * i / 8.0
			kit.sphere(Vector3(cos(a) * 2.8, 0.4 + sin(a) * 3.4, -0.5), Vector3(0.9, 0.8, 0.9), ROCK if i % 2 == 0 else ROCK_DARK, 2, 6, 0.15, i)
		# Crossed hammers sign and two lanterns.
		kit.box(Vector3(0, 4.1, 0.1), Vector3(1.6, 0.6, 0.08), Color("3e2a1a"))
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(s * 1.8, 2.7, 0.35), Vector3(0.22, 0.32, 0.22), IRON)
			kit.use("glow")
			kit.box(Vector3(s * 1.8, 2.7, 0.35), Vector3(0.16, 0.24, 0.24), FIRE)
			kit.use("solid")
		return kit.commit())


## Straight track piece along +Z of `length`: two rails on sleepers.
static func rails(length: float) -> Mesh:
	return cached("rails_%.2f" % length, func() -> Mesh:
		var kit := MeshKit.new()
		var n := maxi(1, int(length / 0.7))
		for i in n:
			kit.box(Vector3(0, 0.05, (i + 0.5) * length / n), Vector3(1.4, 0.1, 0.22), LOG_DARK)
		for s: float in [-0.45, 0.45]:
			kit.box(Vector3(s, 0.14, length * 0.5), Vector3(0.07, 0.08, length), Color("6a6a70"))
		return kit.commit())


## Mine cart (along Z) with an optional load: "ore", "rock", "gems" or "".
static func mine_cart(load := "") -> Mesh:
	return cached("cart_" + load, func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.75, 0), Vector3(1.1, 0.7, 1.5), Color("6b5a48"), Color("2a2420"))
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(0, 0.75, s * 0.76), Vector3(1.12, 0.72, 0.04), IRON)
			kit.box(Vector3(s * 0.56, 0.75, 0), Vector3(0.04, 0.72, 1.52), IRON)
		for sx: float in [-0.45, 0.45]:
			for sz: float in [-0.5, 0.5]:
				kit.push(Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(sx, 0.22, sz)))
				kit.cylinder(Vector3(0, -0.05, 0), 0.1, 0.2, 0.2, 8, Color("2a2a2e"))
				kit.pop()
		var cols := []
		match load:
			"ore": cols = [Color("7a5a48"), Color("b06a3a"), Color("8a6a50")]
			"rock": cols = [ROCK, ROCK_DARK, Color("a39d91")]
			"gems": cols = [Color("3fb8e8"), Color("e84a8a"), Color("9a6ae8")]
		for i in (6 if cols.size() > 0 else 0):
			var x := -0.3 + (i % 3) * 0.3
			var z := -0.35 + (i / 3) * 0.6
			kit.sphere(Vector3(x, 1.12, z), Vector3(0.22, 0.18, 0.22), cols[i % 3], 2, 5, 0.2, i)
		return kit.commit())


## Small signal box on stilts with stairs and a big lever (front +Z).
static func switch_tower() -> Mesh:
	return cached("switch_tower", func() -> Mesh:
		var kit := MeshKit.new()
		for x: float in [-1.4, 1.4]:
			for z: float in [-1.2, 1.2]:
				kit.box(Vector3(x, 1.1, z), Vector3(0.22, 2.2, 0.22), LOG_DARK)
		kit.box(Vector3(0, 2.25, 0), Vector3(3.2, 0.15, 2.8), PropModels.WOOD)
		kit.translate(Vector3(0, 2.3, 0))
		kit.box(Vector3(0, 0.55, -1.2), Vector3(3.0, 1.1, 0.1), Color("c0392b"))
		for x: float in [-1.45, 1.45]:
			kit.box(Vector3(x, 0.55, 0), Vector3(0.1, 1.1, 2.5), Color("c0392b"))
		kit.box(Vector3(0, 0.45, 1.2), Vector3(3.0, 0.9, 0.1), Color("c0392b"))
		for x: float in [-1.45, 1.45]:
			for z: float in [-1.2, 1.2]:
				kit.box(Vector3(x, 1.4, z), Vector3(0.12, 0.8, 0.12), LOG_DARK)
		_gable(kit, 3.0, 2.6, 1.8, 0.9, ROOF, 0.3)
		kit.box(Vector3(0.6, 1.2, 0.6), Vector3(0.12, 0.6, 0.12), IRON)
		kit.box(Vector3(0.6, 1.55, 0.6), Vector3(0.18, 0.12, 0.18), Color("e8442e"))
		kit.pop()
		# Stairs on the side (+X).
		for i in 7:
			kit.box(Vector3(2.0, 0.15 + i * 0.32, 1.1 - i * 0.32), Vector3(0.8, 0.08, 0.32), PropModels.WOOD)
		kit.beam(Vector3(2.4, 0, 1.3), Vector3(2.4, 2.4, -1.0), Vector2(0.06, 0.06), LOG_DARK)
		return kit.commit())


## Quarry wall piece, `size` metres wide: stepped, cut stone terraces (front +Z).
static func rock_face(v: int, size: float) -> Mesh:
	return cached("rock_face_%d_%.1f" % [v, size], func() -> Mesh:
		var r := NatureModels._rng(v + 900)
		var kit := MeshKit.new()
		var steps := 3
		var y := 0.0
		for i in steps:
			var w := size * (1.0 - i * 0.18)
			var d := size * 0.55 * (1.0 - i * 0.22)
			var h := size * r.randf_range(0.18, 0.26)
			var poly := PackedVector2Array()
			for k in 7:
				var a := TAU * k / 7.0 + r.randf_range(-0.2, 0.2)
				poly.append(Vector2(cos(a) * w * 0.5, sin(a) * d * 0.5 - i * size * 0.08) * r.randf_range(0.85, 1.1))
			var col: Color = [ROCK, ROCK_DARK, Color("a39d91")][(i + v) % 3]
			kit.prism(poly, y - 0.2, y + h, col, col.lightened(0.12))
			y += h
		return kit.commit())


## Beehive: stacked wooden boxes on legs.
static func beehive() -> Mesh:
	return cached("beehive", func() -> Mesh:
		var kit := MeshKit.new()
		for x: float in [-0.3, 0.3]:
			kit.box(Vector3(x, 0.2, 0), Vector3(0.08, 0.4, 0.5), PropModels.WOOD_DARK)
		var cols := [Color("f2d080"), Color("e8b860"), Color("f2d080")]
		for i in 3:
			kit.box(Vector3(0, 0.55 + i * 0.32, 0), Vector3(0.75, 0.3, 0.6), cols[i])
		kit.box(Vector3(0, 1.55, 0), Vector3(0.85, 0.1, 0.7), ROOF)
		kit.box(Vector3(0, 0.45, 0.31), Vector3(0.3, 0.06, 0.02), Color("2a2420"))
		return kit.commit())

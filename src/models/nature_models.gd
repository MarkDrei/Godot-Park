class_name NatureModels
extends RefCounted
## Procedural trees, bushes and ground cover. Every builder is deterministic for
## a given variant number, so meshes can be cached and shared via MultiMesh.

const BARK := Color("6b4a32")
const BARK_DARK := Color("4e3524")
const BARK_GREY := Color("7a7068")
const BIRCH_WHITE := Color("e8e4da")
const GREENS := [Color("4f8a3c"), Color("5f9c45"), Color("3f7a35"), Color("6aa84f"), Color("568f3e")]
const PINE_GREENS := [Color("2f5d3a"), Color("35663f"), Color("2a5233")]
const FLOWER_COLORS := [Color("f2d34f"), Color("e8574a"), Color("f08ac0"), Color("8e6fe0"), Color("ffffff"), Color("f5913e"), Color("5aa0e6")]

## Tree kinds with their trunk radius (for obstacles) and number of variants.
const TREES := {
	"oak": {"trunk": 0.45, "variants": 4},
	"maple": {"trunk": 0.38, "variants": 3},
	"birch": {"trunk": 0.25, "variants": 3},
	"pine": {"trunk": 0.32, "variants": 3},
	"fir": {"trunk": 0.35, "variants": 3},
	"willow": {"trunk": 0.5, "variants": 2},
	"cherry": {"trunk": 0.3, "variants": 3},
	"chestnut": {"trunk": 0.45, "variants": 2},
}

static var _cache := {}


static func cached(key: String, builder: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


static func tree(kind: String, variant: int) -> Mesh:
	return cached("tree_%s_%d" % [kind, variant], func() -> Mesh:
		match kind:
			"oak": return oak(variant)
			"maple": return maple(variant)
			"birch": return birch(variant)
			"pine": return pine(variant)
			"fir": return fir(variant)
			"willow": return willow(variant)
			"cherry": return cherry(variant)
			"chestnut": return chestnut(variant)
		return oak(variant))


static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 7919 + 17
	return r


static func _trunk(kit: MeshKit, height: float, radius: float, color: Color, segments := 7, flare := 1.5) -> void:
	kit.use("solid")
	kit.lathe(PackedVector2Array([
		Vector2(radius * flare, 0.0), Vector2(radius * 1.1, 0.35), Vector2(radius, height * 0.5),
		Vector2(radius * 0.72, height), Vector2(0.0, height + 0.05)]), segments, color)
	# Roots peeking out of the ground.
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		var d := Vector3(cos(a), 0, sin(a))
		kit.rod(d * radius * 0.6 + Vector3(0, 0.25, 0), d * radius * 2.4 + Vector3(0, -0.05, 0), radius * 0.35, radius * 0.1, 4, color.darkened(0.1))


static func _branch(kit: MeshKit, from: Vector3, to: Vector3, r: float, color: Color) -> void:
	kit.use("solid")
	kit.rod(from, to, r, r * 0.55, 5, color)


static func _blob(kit: MeshKit, surface: String, center: Vector3, radius: Vector3, color: Color, rng: RandomNumberGenerator) -> void:
	kit.use(surface)
	kit.sphere(center, radius, color, 4, 7, 0.18, rng.randi(), color.darkened(0.18))


static func oak(v: int) -> Mesh:
	var rng := _rng(v + 100)
	var kit := MeshKit.new()
	var h := rng.randf_range(3.2, 4.2)
	_trunk(kit, h, 0.42, BARK)
	var tips: Array[Vector3] = []
	for i in rng.randi_range(3, 4):
		var a := TAU * i / 4.0 + rng.randf_range(-0.4, 0.4)
		var tip := Vector3(cos(a) * rng.randf_range(1.4, 2.2), h + rng.randf_range(0.8, 1.8), sin(a) * rng.randf_range(1.4, 2.2))
		_branch(kit, Vector3(0, h * 0.75, 0), tip, 0.2, BARK)
		tips.append(tip)
	tips.append(Vector3(0, h + 2.2, 0))
	for tip in tips:
		var r := rng.randf_range(1.9, 2.5)
		_blob(kit, "foliage", tip + Vector3(0, 0.6, 0), Vector3(r, r * 0.8, r), GREENS[rng.randi() % GREENS.size()], rng)
	return kit.commit()


static func chestnut(v: int) -> Mesh:
	var rng := _rng(v + 900)
	var kit := MeshKit.new()
	var h := rng.randf_range(3.0, 3.6)
	_trunk(kit, h, 0.45, BARK_DARK)
	var green := Color("3d7a32")
	_blob(kit, "foliage", Vector3(0, h + 2.4, 0), Vector3(3.4, 3.0, 3.4), green, rng)
	for i in 4:
		var a := TAU * i / 4.0 + 0.6
		_blob(kit, "foliage", Vector3(cos(a) * 2.0, h + 1.2, sin(a) * 2.0), Vector3(1.8, 1.5, 1.8), green.lightened(0.06 * i), rng)
	# Blossom candles.
	kit.use("flower")
	for i in 10:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * 2.9, h + 1.6 + rng.randf() * 2.2, sin(a) * 2.9)
		kit.cylinder(p, 0.5, 0.14, 0.0, 4, Color("f6efe3"))
	return kit.commit()


static func maple(v: int) -> Mesh:
	var rng := _rng(v + 200)
	var kit := MeshKit.new()
	var h := rng.randf_range(3.6, 4.6)
	_trunk(kit, h + 1.0, 0.35, BARK_GREY)
	var green: Color = GREENS[(v + 1) % GREENS.size()]
	_blob(kit, "foliage", Vector3(0, h + 0.8, 0), Vector3(2.6, 1.8, 2.6), green, rng)
	_blob(kit, "foliage", Vector3(0.3, h + 2.4, -0.2), Vector3(2.2, 1.7, 2.2), green.lightened(0.06), rng)
	_blob(kit, "foliage", Vector3(-0.2, h + 3.7, 0.2), Vector3(1.4, 1.2, 1.4), green.lightened(0.12), rng)
	return kit.commit()


static func birch(v: int) -> Mesh:
	var rng := _rng(v + 300)
	var kit := MeshKit.new()
	var h := rng.randf_range(6.0, 7.5)
	var lean := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
	kit.use("solid")
	kit.rod(Vector3.ZERO, Vector3(0, h, 0) + lean, 0.24, 0.12, 6, BIRCH_WHITE)
	# Black bark marks.
	for i in 9:
		var t := rng.randf_range(0.1, 0.9)
		var p := (Vector3(0, h, 0) + lean) * t
		var a := rng.randf() * TAU
		var r := lerpf(0.24, 0.12, t) + 0.01
		kit.box(p + Vector3(cos(a) * r, 0, sin(a) * r), Vector3(0.12, 0.05, 0.12), Color("2b2b2b"))
	var leaf := Color("8ab84a")
	for i in 5:
		var t := 0.55 + i * 0.1
		var c := (Vector3(0, h, 0) + lean) * t + Vector3(rng.randf_range(-0.8, 0.8), 0.4, rng.randf_range(-0.8, 0.8))
		_blob(kit, "foliage", c, Vector3(1.2, 1.4, 1.2) * rng.randf_range(0.8, 1.1), leaf.darkened(rng.randf() * 0.15), rng)
	return kit.commit()


static func pine(v: int) -> Mesh:
	var rng := _rng(v + 400)
	var kit := MeshKit.new()
	var h := rng.randf_range(7.0, 9.0)
	kit.use("solid")
	kit.rod(Vector3.ZERO, Vector3(0, h, 0), 0.3, 0.14, 6, Color("8a4f33"))
	for i in 4:
		var y := h * (0.62 + i * 0.11)
		var a := rng.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.3, 1.0)
		_branch(kit, Vector3(0, y - 0.6, 0), off * 1.4 + Vector3(0, y, 0), 0.1, Color("7a4530"))
		kit.use("evergreen")
		kit.sphere(off * 1.4 + Vector3(0, y + 0.2, 0), Vector3(1.6, 0.7, 1.6) * (1.2 - i * 0.12),
			PINE_GREENS[i % 3], 3, 7, 0.2, rng.randi())
	return kit.commit()


static func fir(v: int) -> Mesh:
	var rng := _rng(v + 500)
	var kit := MeshKit.new()
	var h := rng.randf_range(6.5, 8.5)
	kit.use("solid")
	kit.cylinder(Vector3.ZERO, 1.2, 0.32, 0.26, 6, BARK_DARK)
	kit.use("evergreen")
	var layers := 5
	for i in layers:
		var t := float(i) / layers
		var y := 0.8 + t * (h - 1.6)
		var r := lerpf(2.6, 0.7, t) * rng.randf_range(0.92, 1.05)
		kit.cylinder(Vector3(0, y, 0), (h - 0.8) / layers * 1.7, r, 0.0, 8, PINE_GREENS[i % 3], true,
			PINE_GREENS[i % 3].darkened(0.2), rng.randf() * TAU)
	return kit.commit()


static func willow(v: int) -> Mesh:
	var rng := _rng(v + 600)
	var kit := MeshKit.new()
	var h := 3.0
	_trunk(kit, h, 0.5, BARK_DARK, 7, 1.6)
	for i in 4:
		var a := TAU * i / 4.0 + 0.3
		_branch(kit, Vector3(0, h * 0.8, 0), Vector3(cos(a) * 1.8, h + 1.6, sin(a) * 1.8), 0.18, BARK_DARK)
	var green := Color("8db85a")
	_blob(kit, "foliage", Vector3(0, h + 2.2, 0), Vector3(3.2, 1.6, 3.2), green, rng)
	# Hanging strands.
	kit.use("foliage")
	var strands := 26
	for i in strands:
		var a := TAU * i / strands + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(2.4, 3.3)
		var top := Vector3(cos(a) * r, h + 2.0 + rng.randf_range(-0.2, 0.4), sin(a) * r)
		var bottom := Vector3(cos(a) * (r + 0.4), rng.randf_range(0.6, 1.8), sin(a) * (r + 0.4))
		kit.rod(top, bottom, 0.32, 0.08, 4, green.darkened(rng.randf() * 0.2), false)
	return kit.commit()


static func cherry(v: int) -> Mesh:
	var rng := _rng(v + 700)
	var kit := MeshKit.new()
	var h := rng.randf_range(2.4, 3.0)
	_trunk(kit, h, 0.28, Color("5a3a30"))
	var tips := []
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf_range(-0.3, 0.3)
		var tip := Vector3(cos(a) * 1.7, h + 1.2, sin(a) * 1.7)
		_branch(kit, Vector3(0, h * 0.8, 0), tip, 0.12, Color("5a3a30"))
		tips.append(tip)
	tips.append(Vector3(0, h + 1.9, 0))
	for tip: Vector3 in tips:
		var r := rng.randf_range(1.4, 1.9)
		_blob(kit, "cherry", tip + Vector3(0, 0.3, 0), Vector3(r, r * 0.7, r), Color("6aa04a"), rng)
	return kit.commit()


static func bush(v: int, flowering := false) -> Mesh:
	return cached("bush_%d_%s" % [v, flowering], func() -> Mesh:
		var rng := _rng(v + 800)
		var kit := MeshKit.new()
		var green: Color = GREENS[v % GREENS.size()].darkened(0.08)
		for i in rng.randi_range(3, 4):
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.6, 0.95)
			_blob(kit, "foliage", Vector3(cos(a) * 0.5, r * 0.75, sin(a) * 0.5), Vector3(r, r * 0.85, r), green, rng)
		if flowering:
			kit.use("flower")
			var col: Color = FLOWER_COLORS[v % FLOWER_COLORS.size()]
			for i in 14:
				var a := rng.randf() * TAU
				var y := rng.randf_range(0.5, 1.3)
				kit.sphere(Vector3(cos(a) * 0.9, y, sin(a) * 0.9), Vector3(0.12, 0.12, 0.12), col, 2, 4)
		return kit.commit())


static func hedge(length: float) -> Mesh:
	return cached("hedge_%.1f" % length, func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("evergreen")
		var rng := _rng(int(length * 10))
		var n := maxi(1, int(length / 1.2))
		for i in n:
			var x := -length * 0.5 + (i + 0.5) * length / n
			kit.sphere(Vector3(x, 0.75, 0), Vector3(length / n * 0.75, 0.85, 0.75), Color("3c6e34"), 3, 6, 0.12, rng.randi())
		kit.box(Vector3(0, 0.6, 0), Vector3(length, 1.2, 1.1), Color("3a6a32"))
		return kit.commit())


static func grass_tuft(v: int) -> Mesh:
	return cached("grass_%d" % v, func() -> Mesh:
		var rng := _rng(v + 1000)
		var kit := MeshKit.new()
		kit.use("grass")
		var base_col := Color("6aa84f") if v % 2 == 0 else Color("5c9a44")
		for i in 7:
			var a := rng.randf() * TAU
			var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.18)
			var h := rng.randf_range(0.22, 0.45)
			var lean := Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
			var side := Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)) * 0.035
			kit.tri(off - side, off + side, off + lean + Vector3(0, h, 0), base_col.lightened(rng.randf() * 0.15))
		return kit.commit())


static func flower(v: int) -> Mesh:
	return cached("flower_%d" % v, func() -> Mesh:
		var rng := _rng(v + 1100)
		var kit := MeshKit.new()
		kit.use("flower")
		var col: Color = FLOWER_COLORS[v % FLOWER_COLORS.size()]
		for i in 3:
			var a := rng.randf() * TAU
			var base := Vector3(cos(a), 0, sin(a)) * 0.12
			var h := rng.randf_range(0.25, 0.45)
			kit.rod(base, base + Vector3(0, h, 0), 0.015, 0.012, 3, Color("4c8a3a"), false)
			var head := base + Vector3(0, h, 0)
			for p in 5:
				var pa := TAU * p / 5.0
				kit.sphere(head + Vector3(cos(pa), 0, sin(pa)) * 0.05, Vector3(0.045, 0.02, 0.045), col, 2, 4)
			kit.sphere(head + Vector3(0, 0.01, 0), Vector3(0.03, 0.03, 0.03), Color("f2c230"), 2, 4)
		return kit.commit())


static func reeds(v: int) -> Mesh:
	return cached("reeds_%d" % v, func() -> Mesh:
		var rng := _rng(v + 1200)
		var kit := MeshKit.new()
		kit.use("grass")
		for i in 9:
			var base := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
			var h := rng.randf_range(1.0, 1.7)
			var lean := Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
			kit.rod(base, base + Vector3(0, h, 0) + lean, 0.025, 0.01, 3, Color("7d9a4a"), false)
			if i % 3 == 0:
				kit.rod(base + Vector3(0, h * 0.75, 0) + lean * 0.75, base + Vector3(0, h * 0.95, 0) + lean * 0.95,
					0.05, 0.05, 5, Color("6b4423"))
		return kit.commit())


static func rock(v: int) -> Mesh:
	return cached("rock_%d" % v, func() -> Mesh:
		var rng := _rng(v + 1300)
		var kit := MeshKit.new()
		var s := rng.randf_range(0.5, 1.1)
		kit.sphere(Vector3(0, s * 0.25, 0), Vector3(s, s * 0.6, s * 0.85), Color("8d8a84").darkened(rng.randf() * 0.2),
			3, 6, 0.3, rng.randi())
		return kit.commit())


static func lily_pad(v: int) -> Mesh:
	return cached("lily_%d" % v, func() -> Mesh:
		var kit := MeshKit.new()
		kit.use("nosnow")
		var r := 0.3 + 0.08 * (v % 3)
		for i in 10:
			if i == 0:
				continue
			var a0 := TAU * i / 10.0
			var a1 := TAU * (i + 1) / 10.0
			kit.tri(Vector3.ZERO, Vector3(cos(a1), 0, sin(a1)) * r, Vector3(cos(a0), 0, sin(a0)) * r, Color("4a8a3a"))
		if v % 2 == 0:
			for p in 6:
				var a := TAU * p / 6.0
				kit.rod(Vector3(0, 0.02, 0), Vector3(cos(a) * 0.12, 0.12, sin(a) * 0.12), 0.03, 0.05, 3, Color("f6d7e8"))
		return kit.commit())


static func mushroom(glowing: bool) -> Mesh:
	return cached("mushroom_%s" % glowing, func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.18, 0.04, 0.035, 5, Color("efe6d2"))
		kit.use("glow" if glowing else "solid")
		var cap := Color("6fe8d0") if glowing else Color("d23a2a")
		kit.sphere(Vector3(0, 0.2, 0), Vector3(0.12, 0.07, 0.12), cap, 3, 6, 0.0, 0, Color("efe6d2"))
		if not glowing:
			kit.use("solid")
			for i in 4:
				var a := TAU * i / 4.0
				kit.box(Vector3(cos(a) * 0.07, 0.25, sin(a) * 0.07), Vector3(0.03, 0.02, 0.03), Color.WHITE)
		return kit.commit())


static func stump() -> Mesh:
	return cached("stump", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.5, 0.45, 0.4, 8, BARK, true, Color("c9a77a"))
		return kit.commit())


static func log_mesh() -> Mesh:
	return cached("log", func() -> Mesh:
		var kit := MeshKit.new()
		kit.rod(Vector3(-1.4, 0.3, 0), Vector3(1.4, 0.3, 0), 0.3, 0.28, 7, BARK)
		return kit.commit())

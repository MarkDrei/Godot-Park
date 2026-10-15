class_name TownProps
extends RefCounted
## Small things of the Oststadt that CityDecor merges into one mesh per area (doc/oststadt.md):
## garden things for the back yards, street furniture, and stuff on the lots. Every function
## appends to a MeshKit in the kit's current transform; origin on the ground, front faces +Z.

const WOOD := Color("8a5a34")
const WOOD_LIGHT := Color("b08850")
const WOOD_DARK := Color("5a3a22")
const IRON := Color("3e444a")
const STEEL := Color("9aa0a6")
const WHITE := Color("f1eee6")
const GLASSY := Color("cfe2e8")
const LEAF := Color("4f8a3a")
const HEDGE := Color("3a6a32")


# --- Gardens --------------------------------------------------------------------------

## Garden shed with a lean-to roof, a door and a little window.
static func shed(kit: MeshKit, col: Color) -> void:
	kit.box(Vector3(0, 1.0, 0), Vector3(2.2, 2.0, 1.8), col)
	for i in 7:
		kit.box(Vector3(-0.95 + i * 0.32, 1.0, 0.91), Vector3(0.03, 1.9, 0.02), col.darkened(0.25))
	kit.box(Vector3(-0.45, 0.9, 0.92), Vector3(0.75, 1.75, 0.04), col.darkened(0.15))
	kit.box(Vector3(0.55, 1.35, 0.93), Vector3(0.6, 0.5, 0.03), Color("5a7085"))
	kit.push(Transform3D(Basis(Vector3.RIGHT, -0.18), Vector3(0, 2.12, 0)))
	kit.box(Vector3.ZERO, Vector3(2.5, 0.08, 2.3), Color("3a3a3e"))
	kit.pop()


## Two T-posts with a washing line and the washing on it (along x, 3.4 m).
static func washing_line(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	for x: float in [-1.7, 1.7]:
		kit.box(Vector3(x, 0.9, 0), Vector3(0.07, 1.8, 0.07), STEEL)
		kit.box(Vector3(x, 1.78, 0), Vector3(0.06, 0.06, 0.7), STEEL)
	for z: float in [-0.3, 0.3]:
		kit.box(Vector3(0, 1.76, z), Vector3(3.4, 0.015, 0.015), WHITE)
	var cols := [Color("e8e0d0"), Color("d8402e"), Color("2e86de"), Color("f2c230"), Color("f28db2"), Color("3e6e4a")]
	var x := -1.4
	while x < 1.3:
		var w := rng.randf_range(0.3, 0.6)
		var h := rng.randf_range(0.4, 0.75)
		kit.box(Vector3(x + w * 0.5, 1.76 - h * 0.5, -0.3 if rng.randf() < 0.5 else 0.3), Vector3(w, h, 0.02), cols[rng.randi() % cols.size()])
		x += w + rng.randf_range(0.1, 0.3)


static func trampoline(kit: MeshKit) -> void:
	for i in 6:
		var a := TAU * i / 6.0
		kit.beam(Vector3(cos(a) * 1.5, 0, sin(a) * 1.5), Vector3(cos(a) * 1.6, 0.75, sin(a) * 1.6), Vector2(0.05, 0.05), IRON)
	kit.cylinder(Vector3(0, 0.7, 0), 0.1, 1.7, 1.7, 14, Color("2e86de"))
	kit.cylinder(Vector3(0, 0.72, 0), 0.1, 1.45, 1.45, 14, Color("1e1e20"))


## Round table, chairs and a parasol.
static func garden_set(kit: MeshKit, col: Color) -> void:
	kit.cylinder(Vector3(0, 0.0, 0), 0.7, 0.05, 0.05, 6, WHITE)
	kit.cylinder(Vector3(0, 0.7, 0), 0.04, 0.5, 0.5, 10, WHITE)
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		kit.push(Transform3D(Basis(Vector3.UP, -a + PI / 2), Vector3(cos(a) * 0.85, 0, sin(a) * 0.85)))
		kit.box(Vector3(0, 0.42, 0), Vector3(0.42, 0.05, 0.42), WHITE)
		kit.box(Vector3(0, 0.7, 0.2), Vector3(0.42, 0.5, 0.04), WHITE)
		for sx: float in [-0.18, 0.18]:
			for sz: float in [-0.18, 0.18]:
				kit.box(Vector3(sx, 0.2, sz), Vector3(0.03, 0.42, 0.03), WHITE)
		kit.pop()
	kit.cylinder(Vector3(0, 0.74, 0), 1.4, 0.025, 0.025, 6, WHITE)
	kit.cylinder(Vector3(0, 1.9, 0), 0.35, 1.25, 0.05, 8, col)


static func raised_bed(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	kit.box(Vector3(0, 0.25, 0), Vector3(2.0, 0.5, 0.9), WOOD)
	kit.box(Vector3(0, 0.5, 0), Vector3(1.85, 0.04, 0.75), Color("4a3424"))
	for i in 5:
		var p := Vector3(-0.75 + i * 0.37, 0.65, rng.randf_range(-0.15, 0.15))
		kit.sphere(p, Vector3(0.18, 0.18, 0.18), LEAF.lightened(rng.randf_range(0.0, 0.2)), 2, 6)
		if rng.randf() < 0.5:
			kit.sphere(p + Vector3(0.08, 0.05, 0.12), Vector3(0.06, 0.06, 0.06), Color("d8402e"), 2, 5)


static func greenhouse(kit: MeshKit) -> void:
	kit.box(Vector3(0, 0.95, 0), Vector3(2.4, 1.9, 3.0), GLASSY)
	kit.push(Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0, 1.9, 0)))
	CityModels.gable_roof(kit, 3.0, 2.4, 0.0, 0.7, GLASSY.darkened(0.08), GLASSY)
	kit.pop()
	for x: float in [-1.2, 1.2]:
		for z: float in [-1.5, 0.0, 1.5]:
			kit.box(Vector3(x, 0.95, z), Vector3(0.05, 1.9, 0.05), WHITE)
	for z: float in [-1.5, 1.5]:
		kit.box(Vector3(0, 1.9, z), Vector3(2.4, 0.05, 0.05), WHITE)
	for i in 3:
		kit.sphere(Vector3(-0.6 + i * 0.6, 0.6, 0.5), Vector3(0.25, 0.5, 0.25), LEAF, 2, 6)


static func compost(kit: MeshKit) -> void:
	for i in 5:
		kit.box(Vector3(0, 0.1 + i * 0.18, 0.5), Vector3(1.2, 0.12, 0.04), WOOD_DARK)
		kit.box(Vector3(0, 0.1 + i * 0.18, -0.5), Vector3(1.2, 0.12, 0.04), WOOD_DARK)
		kit.box(Vector3(0.6, 0.1 + i * 0.18, 0), Vector3(0.04, 0.12, 1.0), WOOD_DARK)
		kit.box(Vector3(-0.6, 0.1 + i * 0.18, 0), Vector3(0.04, 0.12, 1.0), WOOD_DARK)
	kit.box(Vector3(0, 0.55, 0), Vector3(1.1, 0.4, 0.9), Color("5a4a2a"))


static func sandpit(kit: MeshKit) -> void:
	kit.box(Vector3(0, 0.12, 0), Vector3(1.8, 0.24, 1.8), WOOD_LIGHT)
	kit.box(Vector3(0, 0.2, 0), Vector3(1.6, 0.06, 1.6), Color("e6d29a"))
	kit.box(Vector3(0.4, 0.3, 0.3), Vector3(0.2, 0.15, 0.2), Color("d8402e"))


## Picket fence from a to b (local, on the ground), about 1 m high.
static func fence(kit: MeshKit, a: Vector3, b: Vector3, col := WHITE) -> void:
	var d := b - a
	var n := maxi(1, int(d.length() / 0.18))
	for i in n + 1:
		var p := a + d * (float(i) / n)
		kit.box(p + Vector3(0, 0.45, 0), Vector3(0.07, 0.9, 0.07), col)
	for y: float in [0.3, 0.7]:
		kit.beam(a + Vector3(0, y, 0), b + Vector3(0, y, 0), Vector2(0.04, 0.08), col.darkened(0.08))


## Hedge from a to b (leafy, on the foliage surface the trees of an area share).
static func hedge(kit: MeshKit, a: Vector3, b: Vector3, h := 1.3) -> void:
	kit.use("foliage")
	var d := b - a
	var length := d.length()
	kit.push(Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), (a + b) * 0.5))
	kit.box(Vector3(0, h * 0.5, 0), Vector3(0.9, h, length), HEDGE)
	var n := maxi(1, int(length / 1.2))
	for i in n:
		kit.sphere(Vector3(0, h * 0.62, -length * 0.5 + (i + 0.5) * length / n), Vector3(0.6, h * 0.62, length / n * 0.7), HEDGE.lightened(0.06), 2, 6)
	kit.pop()
	kit.use("solid")


# --- Street furniture -------------------------------------------------------------------

## Advertising column with posters and a green cap.
static func ad_column(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	kit.cylinder(Vector3.ZERO, 0.3, 0.7, 0.68, 12, Color("4a5a50"))
	kit.cylinder(Vector3(0, 0.3, 0), 2.6, 0.6, 0.6, 12, Color("e8e2d0"))
	var cols := [Color("d8402e"), Color("2e86de"), Color("f2c230"), Color("8e44ad"), Color("27ae60"), Color("e67e22"), Color("2c3e50")]
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.3
		kit.push(Transform3D(Basis(Vector3.UP, a), Vector3.ZERO))
		var h := rng.randf_range(0.8, 1.2)
		kit.box(Vector3(0, rng.randf_range(0.9, 1.8), 0.605), Vector3(0.55, h, 0.02), cols[rng.randi() % cols.size()])
		kit.box(Vector3(0, 2.3, 0.605), Vector3(0.5, 0.3, 0.02), cols[rng.randi() % cols.size()].lightened(0.3))
		kit.pop()
	kit.cylinder(Vector3(0, 2.9, 0), 0.12, 0.72, 0.72, 12, Color("3e5a48"))
	kit.sphere(Vector3(0, 3.02, 0), Vector3(0.7, 0.35, 0.7), Color("3e5a48"), 3, 12)
	kit.sphere(Vector3(0, 3.42, 0), Vector3(0.1, 0.1, 0.1), Color("c8a030"), 2, 6)


## Bus shelter, 3.2 m wide, open to +Z; the bench is a city bench of the builder. The stop sign
## stands at +x.
static func bus_shelter(kit: MeshKit) -> void:
	kit.box(Vector3(0, 1.25, -0.6), Vector3(3.2, 2.2, 0.05), GLASSY)
	for x: float in [-1.6, 1.6]:
		kit.box(Vector3(x, 1.25, -0.1), Vector3(0.05, 2.2, 1.0), GLASSY)
		kit.box(Vector3(x, 1.2, 0.42), Vector3(0.08, 2.4, 0.08), IRON)
		kit.box(Vector3(x, 1.2, -0.62), Vector3(0.08, 2.4, 0.08), IRON)
	kit.box(Vector3(0, 2.45, -0.05), Vector3(3.5, 0.12, 1.5), IRON)
	kit.box(Vector3(0, 2.38, 0.68), Vector3(3.5, 0.18, 0.04), Color("f2c230"))
	# Timetable and an advert on the back wall.
	kit.box(Vector3(-1.0, 1.4, -0.57), Vector3(0.6, 0.8, 0.02), WHITE)
	kit.box(Vector3(0.9, 1.3, -0.57), Vector3(1.0, 1.4, 0.02), Color("2e86de"))
	kit.box(Vector3(0.9, 1.6, -0.555), Vector3(0.8, 0.3, 0.02), Color("f2c230"))
	# Stop sign: a green H on a yellow disc.
	kit.cylinder(Vector3(2.1, 0, 0.3), 2.6, 0.04, 0.04, 6, STEEL)
	kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(2.1, 2.55, 0.3)))
	kit.cylinder(Vector3(0, -0.02, 0), 0.04, 0.3, 0.3, 14, Color("f2c230"))
	kit.pop()
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(2.1, 2.55, 0.3 + s * 0.025), Vector3(0.24, 0.05, 0.01), Color("2e7a3a"))
		for x: float in [-0.1, 0.1]:
			kit.box(Vector3(2.1 + x, 2.55, 0.3 + s * 0.025), Vector3(0.05, 0.3, 0.01), Color("2e7a3a"))


static func post_box(kit: MeshKit) -> void:
	kit.box(Vector3(0, 0.45, 0), Vector3(0.1, 0.9, 0.1), IRON)
	kit.box(Vector3(0, 1.15, 0), Vector3(0.45, 0.6, 0.35), Color("f2c230"))
	kit.box(Vector3(0, 1.48, 0), Vector3(0.5, 0.06, 0.4), Color("e0b020"))
	kit.box(Vector3(0, 1.28, 0.18), Vector3(0.3, 0.04, 0.02), Color("1a1a1a"))
	kit.box(Vector3(0, 1.05, 0.18), Vector3(0.12, 0.12, 0.02), Color("1a1a1a"))


static func hydrant(kit: MeshKit) -> void:
	kit.cylinder(Vector3.ZERO, 0.75, 0.12, 0.1, 8, Color("c0392b"))
	kit.sphere(Vector3(0, 0.78, 0), Vector3(0.12, 0.1, 0.12), Color("c0392b"), 2, 8)
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(s * 0.13, 0.5, 0), Vector3(0.1, 0.1, 0.1), Color("a83224"))


static func street_bin(kit: MeshKit) -> void:
	kit.box(Vector3(0, 0.5, 0), Vector3(0.08, 1.0, 0.08), IRON)
	kit.cylinder(Vector3(0, 0.45, 0.12), 0.55, 0.22, 0.2, 10, Color("e8702e"))
	kit.cylinder(Vector3(0, 1.0, 0.12), 0.03, 0.23, 0.23, 10, Color("3a3a3e"))


static func flower_tub(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	kit.cylinder(Vector3.ZERO, 0.55, 0.55, 0.62, 10, Color("b8b2a6"))
	kit.sphere(Vector3(0, 0.62, 0), Vector3(0.55, 0.3, 0.55), LEAF, 3, 8)
	var cols := [Color("d8402e"), Color("f28db2"), Color("f2c230"), Color("f4f0e6"), Color("8e44ad")]
	for i in 7:
		var a := TAU * i / 7.0
		kit.sphere(Vector3(cos(a) * 0.35, 0.8, sin(a) * 0.35), Vector3(0.1, 0.08, 0.1), cols[rng.randi() % cols.size()], 2, 5)


## Park lamp with a round glowing head (the light comes from World.lamps).
static func park_lamp(kit: MeshKit) -> void:
	kit.cylinder(Vector3.ZERO, 0.3, 0.12, 0.09, 8, IRON)
	kit.cylinder(Vector3(0, 0.3, 0), 3.0, 0.05, 0.04, 6, IRON)
	kit.use("glow")
	kit.sphere(Vector3(0, 3.45, 0), Vector3(0.24, 0.24, 0.24), Color("fff0c0"), 3, 8)
	kit.use("solid")
	kit.cylinder(Vector3(0, 3.62, 0), 0.08, 0.2, 0.05, 8, IRON)


## Wooden sign board on two posts (the name is a label of the builder).
static func park_sign(kit: MeshKit) -> void:
	for x: float in [-0.9, 0.9]:
		kit.box(Vector3(x, 0.9, 0), Vector3(0.12, 1.8, 0.12), WOOD_DARK)
	kit.box(Vector3(0, 1.55, 0), Vector3(2.2, 0.55, 0.08), WOOD)
	kit.box(Vector3(0, 1.88, 0), Vector3(2.3, 0.08, 0.16), WOOD_DARK)


# --- Lots -----------------------------------------------------------------------------

## Bottle bank (glass, paper …) with two round slots.
static func container(kit: MeshKit, col: Color) -> void:
	kit.box(Vector3(0, 0.8, 0), Vector3(1.6, 1.5, 1.5), col)
	kit.box(Vector3(0, 1.58, 0), Vector3(1.7, 0.08, 1.6), col.darkened(0.2))
	for x: float in [-0.4, 0.4]:
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(x, 1.2, 0.75)))
		kit.cylinder(Vector3.ZERO, 0.02, 0.15, 0.15, 10, Color("1a1a1a"))
		kit.pop()
	kit.box(Vector3(0, 0.03, 0), Vector3(1.4, 0.06, 1.3), Color("2a2a2e"))


static func drum(kit: MeshKit, col: Color) -> void:
	kit.cylinder(Vector3.ZERO, 0.9, 0.3, 0.3, 10, col)
	for y: float in [0.3, 0.6]:
		kit.cylinder(Vector3(0, y, 0), 0.03, 0.31, 0.31, 10, col.darkened(0.25))
	kit.cylinder(Vector3(0, 0.9, 0), 0.01, 0.28, 0.28, 10, col.darkened(0.15))


static func pallets(kit: MeshKit, n: int) -> void:
	for i in n:
		var y := i * 0.15
		for z: float in [-0.5, 0.0, 0.5]:
			kit.box(Vector3(0, y + 0.05, z), Vector3(1.2, 0.1, 0.1), WOOD_LIGHT)
		for x: float in [-0.5, -0.17, 0.17, 0.5]:
			kit.box(Vector3(x, y + 0.13, 0), Vector3(0.12, 0.03, 1.1), WOOD_LIGHT.darkened(0.08))


## Two-post car lift with its arms up at 1.6 m (a car stands on it, placed by the decor).
static func car_lift(kit: MeshKit) -> void:
	for x: float in [-1.45, 1.45]:
		kit.box(Vector3(x, 1.6, 0), Vector3(0.3, 3.2, 0.4), Color("2e5ea8"))
		kit.box(Vector3(x, 0.03, 0), Vector3(0.6, 0.06, 0.7), Color("3a3a3e"))
		for z: float in [-0.9, 0.9]:
			kit.beam(Vector3(x, 1.25, 0), Vector3(x * 0.45, 1.25, z), Vector2(0.1, 0.08), Color("f2c230"))
	kit.box(Vector3(0, 3.25, 0), Vector3(3.2, 0.14, 0.2), Color("2e5ea8"))


static func flag(kit: MeshKit, col: Color, col2: Color) -> void:
	kit.cylinder(Vector3.ZERO, 6.0, 0.06, 0.04, 6, WHITE)
	kit.box(Vector3(0, 5.3, 0.55), Vector3(0.02, 1.2, 1.0), col)
	kit.box(Vector3(0, 5.3, 0.55), Vector3(0.025, 0.35, 1.0), col2)


## Air and water column of the petrol station.
static func air_pump(kit: MeshKit) -> void:
	kit.box(Vector3(0, 0.75, 0), Vector3(0.5, 1.5, 0.4), Color("2e86de"))
	kit.box(Vector3(0, 1.2, 0.21), Vector3(0.36, 0.3, 0.02), WHITE)
	kit.box(Vector3(0, 0.75, 0.21), Vector3(0.2, 0.2, 0.02), Color("1a1a1a"))
	kit.torus(Vector3(0.32, 0.6, 0), 0.15, 0.02, 10, 3, Color("1a1a1a"))


static func barriers(kit: MeshKit) -> void:
	for i in 3:
		kit.push(Transform3D(Basis(), Vector3(0, i * 0.12, i * 0.05)))
		for x: float in [-0.8, 0.8]:
			kit.box(Vector3(x, 0.45, 0), Vector3(0.05, 0.9, 0.5), Color("9aa0a6"))
		for k in 5:
			kit.box(Vector3(-0.64 + k * 0.32, 0.75, 0), Vector3(0.32, 0.2, 0.04), Color("d0352b") if k % 2 == 0 else WHITE)
		kit.pop()


static func heap(kit: MeshKit, col: Color, r: float) -> void:
	kit.sphere(Vector3(0, 0, 0), Vector3(r, r * 0.55, r), col, 4, 10)


## Cafe parasol over a picnic table (the table is PropModels.picnic_table).
static func parasol(kit: MeshKit, col: Color) -> void:
	kit.cylinder(Vector3.ZERO, 2.3, 0.03, 0.03, 6, WHITE)
	for i in 8:
		var a0 := TAU * i / 8.0
		var a1 := TAU * (i + 1) / 8.0
		var c := col if i % 2 == 0 else WHITE
		var top := Vector3(0, 2.6, 0)
		var p0 := Vector3(cos(a0) * 1.6, 2.05, sin(a0) * 1.6)
		var p1 := Vector3(cos(a1) * 1.6, 2.05, sin(a1) * 1.6)
		kit.tri(top, p1, p0, c)
		kit.tri(top, p0, p1, c.darkened(0.3))

class_name StallParts
extends RefCounted
## Reusable parts for stands, stalls and kiosks all over the world (the coast's stands, the park's
## kiosk and donut stand, the city's ticket booths, the castle's market, the Nordwald's stall),
## modelled on the detail of the Kirmes booths (FairModels._stall). Every part draws into the
## caller's MeshKit, front +Z, and leaves the kit on the "solid" surface. Parts that can flutter
## or glow take `fancy`: true puts the canvas on "canvas" and lights on "bulbs" (one more draw call
## per surface where the area merges its models), false keeps everything on "solid".

const WHITE := Color("f4f1ea")
const GOLD := Color("d8b04a")
const IRON := Color("2f3336")
const CHALK := Color("26302c")
const BULB := Color("ffe9a8")
const WOOD := Color("9a6a3e")
const WOOD_LIGHT := Color("c49a63")
const WOOD_DARK := Color("6a4a2e")
## Colours for goods, pennants and bulbs.
const GAY := [Color("d8402e"), Color("f2c230"), Color("2f6fb0"), Color("2e9a6a"), Color("e07aa8"), Color("f08a2e")]


## A striped awning over a counter: `w` wide, hanging from `top_y` at z = `z0` forward by `reach`
## and down by `drop`, curved, stripes `col` and `col2`, a scalloped valance at its front edge and
## two struts back to the wall. Returns the front edge (y, z) for lights hung under it.
static func awning(kit: MeshKit, w: float, z0: float, top_y: float, col: Color, col2 := WHITE,
		reach := 1.05, drop := 0.48, fancy := false, scallops := true) -> Vector2:
	var hw := w * 0.5
	var prof: Array[Vector2] = []
	for k in 4:
		var t := k / 3.0
		prof.append(Vector2(z0 + reach * t, top_y - drop * (t * 0.55 + t * t * 0.45)))
	var alpha := [1.0, 0.85, 0.7, 0.55] if fancy else [1.0, 1.0, 1.0, 1.0]
	var stripes := maxi(2, int(round(w / 0.5)))
	var sw := w / stripes
	kit.use("canvas" if fancy else "solid")
	for i in stripes:
		var x0 := -hw + i * sw
		var x1 := x0 + sw
		var c: Color = col2 if i % 2 == 0 else col
		var under := c.darkened(0.25)
		for j in 3:
			var a: Vector2 = prof[j]
			var b: Vector2 = prof[j + 1]
			var ca := Color(c, alpha[j])
			var cb := Color(c, alpha[j + 1])
			kit.quad_c(Vector3(x0, a.y, a.x), Vector3(x0, b.y, b.x), Vector3(x1, b.y, b.x), Vector3(x1, a.y, a.x), ca, cb, cb, ca)
			var ua := Color(under, alpha[j])
			var ub := Color(under, alpha[j + 1])
			kit.quad_c(Vector3(x0, a.y - 0.01, a.x), Vector3(x1, a.y - 0.01, a.x), Vector3(x1, b.y - 0.01, b.x), Vector3(x0, b.y - 0.01, b.x), ua, ua, ub, ub)
		var front: Vector2 = prof[3]
		var mid := Vector3((x0 + x1) * 0.5, front.y, front.x)
		var ce := Color(c, alpha[3])
		var cu := Color(under, alpha[3])
		if scallops:
			var n := 6
			for k in n:
				var t0 := PI * k / n
				var t1 := PI * (k + 1) / n
				var p0 := mid + Vector3(cos(t0) * sw * 0.5, -sin(t0) * 0.2, 0)
				var p1 := mid + Vector3(cos(t1) * sw * 0.5, -sin(t1) * 0.2, 0)
				kit.tri_c(mid, p1, p0, ce, ce, ce)
				kit.tri_c(mid + Vector3(0, 0, -0.005), p0 + Vector3(0, 0, -0.005), p1 + Vector3(0, 0, -0.005), cu, cu, cu)
		else:
			kit.quad_c(Vector3(x0, front.y, front.x), Vector3(x0, front.y - 0.18, front.x), Vector3(x1, front.y - 0.18, front.x), Vector3(x1, front.y, front.x), ce, ce, ce, ce)
			kit.quad_c(Vector3(x1, front.y, front.x - 0.005), Vector3(x1, front.y - 0.18, front.x - 0.005), Vector3(x0, front.y - 0.18, front.x - 0.005), Vector3(x0, front.y, front.x - 0.005), cu, cu, cu, cu)
	kit.use("solid")
	var edge: Vector2 = prof[3]
	for s: float in [-1.0, 1.0]:
		kit.rod(Vector3(s * (hw - 0.08), top_y - 0.05, z0), Vector3(s * (hw - 0.08), edge.y - 0.03, edge.x - 0.06), 0.02, 0.02, 4, IRON)
	kit.rod(Vector3(-hw + 0.08, edge.y - 0.04, edge.x - 0.06), Vector3(hw - 0.08, edge.y - 0.04, edge.x - 0.06), 0.018, 0.018, 4, IRON)
	return Vector2(edge.y - 0.04, edge.x - 0.06)


## A wall of horizontal boards (shiplap) facing +Z: `size` (w, h), its middle at `center`, a
## darker gap line every `step` on the front face.
static func siding(kit: MeshKit, center: Vector3, size: Vector2, col: Color, step := 0.22, thick := 0.08) -> void:
	kit.box(center, Vector3(size.x, size.y, thick), col)
	var lines := int(size.y / step)
	for k in range(1, lines):
		var y := center.y - size.y * 0.5 + k * step
		kit.box(Vector3(center.x, y, center.z + thick * 0.5 + 0.004), Vector3(size.x - 0.02, 0.025, 0.008), col.darkened(0.18))


## A thin frame of border `t` round a rectangle of `size` facing +Z at `center`.
static func frame(kit: MeshKit, center: Vector3, size: Vector2, t: float, col := GOLD) -> void:
	var h := size * 0.5
	kit.box(center + Vector3(0, h.y - t * 0.5, 0), Vector3(size.x, t, 0.02), col)
	kit.box(center + Vector3(0, -h.y + t * 0.5, 0), Vector3(size.x, t, 0.02), col)
	kit.box(center + Vector3(h.x - t * 0.5, 0, 0), Vector3(t, size.y - 2.0 * t, 0.02), col)
	kit.box(center + Vector3(-h.x + t * 0.5, 0, 0), Vector3(t, size.y - 2.0 * t, 0.02), col)


## A sales counter `w` wide whose front face lies at z, top at `top_y`: framed panels with a
## diamond each in `col`, a plank top reaching forward, a trim line under it.
static func counter(kit: MeshKit, w: float, z: float, top_y: float, col: Color, top_col := WOOD_LIGHT,
		trim := GOLD, accent := WHITE) -> void:
	kit.box(Vector3(0, top_y * 0.5, z - 0.06), Vector3(w, top_y, 0.12), col.darkened(0.1))
	kit.box(Vector3(0, top_y + 0.03, z + 0.08), Vector3(w + 0.14, 0.06, 0.5), top_col)
	kit.box(Vector3(0, top_y - 0.04, z + 0.33), Vector3(w + 0.14, 0.03, 0.02), trim)
	var panels := maxi(1, int(round(w / 1.3)))
	var pw := (w - 0.3) / panels
	for k in panels:
		var x := -w * 0.5 + 0.15 + (k + 0.5) * pw
		var y := top_y * 0.52
		kit.box(Vector3(x, y, z + 0.01), Vector3(pw - 0.18, top_y * 0.55, 0.02), col.lightened(0.3))
		frame(kit, Vector3(x, y, z + 0.025), Vector2(pw - 0.14, top_y * 0.55 + 0.04), 0.035, trim)
		var dz := z + 0.03
		var r := minf(0.16, top_y * 0.18)
		kit.quad(Vector3(x, y - r, dz), Vector3(x + r, y, dz), Vector3(x, y + r, dz), Vector3(x - r, y, dz), accent)


## A name board facing +Z: a board `w` × `h` in `board`, a light field (the label goes in front of
## it at z + 0.07), a frame in `trim`, knobs at the ends; with `crest` a half-round top with a
## star. `fancy` adds bulbs along the top and the bottom.
static func sign_board(kit: MeshKit, center: Vector3, w: float, h: float, board: Color, field: Color,
		trim := GOLD, crest := false, fancy := false) -> void:
	kit.box(center, Vector3(w + 0.2, h, 0.08), board)
	kit.box(center + Vector3(0, 0, 0.045), Vector3(w - 0.1, h - 0.18, 0.02), field)
	frame(kit, center + Vector3(0, 0, 0.06), Vector2(w - 0.06, h - 0.14), 0.04, trim)
	for s: float in [-1.0, 1.0]:
		kit.sphere(center + Vector3(s * (w * 0.5 + 0.14), 0, 0), Vector3(0.11, 0.11, 0.07), trim, 2, 6)
	if crest:
		var top := center.y + h * 0.5
		var rx := minf(0.8, w * 0.22)
		var n := 10
		for k in n:
			var t0 := PI * k / n
			var t1 := PI * (k + 1) / n
			var p0 := Vector3(center.x + cos(t0) * rx, top + sin(t0) * 0.32, center.z)
			var p1 := Vector3(center.x + cos(t1) * rx, top + sin(t1) * 0.32, center.z)
			var c := Vector3(center.x, top, center.z)
			for dz: float in [0.04, -0.04]:
				if dz > 0:
					kit.tri(c + Vector3(0, 0, dz), p0 + Vector3(0, 0, dz), p1 + Vector3(0, 0, dz), board)
				else:
					kit.tri(c + Vector3(0, 0, dz), p1 + Vector3(0, 0, dz), p0 + Vector3(0, 0, dz), board)
			kit.beam(p0 + Vector3(0, 0, 0.045), p1 + Vector3(0, 0, 0.045), Vector2(0.03, 0.03), trim)
		star(kit, Vector3(center.x, top + 0.13, center.z + 0.05), 0.11, 0.05, trim)
	if fancy:
		kit.use("bulbs", 0.0)
		var count := int(w / 0.4)
		for i in count + 1:
			var x := center.x - w * 0.5 + i * w / count
			for s: float in [-1.0, 1.0]:
				kit.sphere(Vector3(x, center.y + s * (h * 0.5 - 0.02), center.z + 0.07), Vector3(0.04, 0.04, 0.035), BULB, 2, 4)
		kit.use("solid")


## A five-pointed star in the x-y plane facing +Z.
static func star(kit: MeshKit, center: Vector3, r_out: float, r_in: float, col: Color) -> void:
	for k in 10:
		var a0 := PI / 2 + TAU * k / 10
		var a1 := PI / 2 + TAU * (k + 1) / 10
		var r0 := r_out if k % 2 == 0 else r_in
		var r1 := r_out if k % 2 == 1 else r_in
		kit.tri(center, center + Vector3(cos(a0) * r0, sin(a0) * r0, 0), center + Vector3(cos(a1) * r1, sin(a1) * r1, 0), col)


## A chalk price board facing +Z (`size`), framed in wood, `lines` rows of a name and a price.
static func menu_board(kit: MeshKit, center: Vector3, size: Vector2, lines := 4, frame_col := WOOD_DARK, seed := 0) -> void:
	kit.box(center, Vector3(size.x + 0.1, size.y + 0.1, 0.05), frame_col)
	kit.box(center + Vector3(0, 0, 0.03), Vector3(size.x - 0.04, size.y - 0.04, 0.01), CHALK)
	var top := center.y + size.y * 0.5 - 0.16
	kit.box(Vector3(center.x, top, center.z + 0.04), Vector3(size.x * 0.55, 0.05, 0.005), Color("f2c230"))
	var row := (size.y - 0.32) / maxf(1.0, lines)
	for k in lines:
		var y := top - (k + 1) * row
		var name_w := size.x * (0.38 + 0.12 * ((k + seed) % 3) / 2.0)
		kit.box(Vector3(center.x - size.x * 0.5 + 0.1 + name_w * 0.5, y, center.z + 0.04), Vector3(name_w, 0.035, 0.005), WHITE)
		kit.box(Vector3(center.x + size.x * 0.5 - 0.22, y, center.z + 0.04), Vector3(0.2, 0.035, 0.005), [Color("f2c230"), Color("f08aa0"), Color("8fd3e8")][(k + seed) % 3])


## A pavement sign (an A-frame with a chalk board on both faces) standing at `pos`, facing +Z.
static func a_frame(kit: MeshKit, pos: Vector3, col := WOOD_DARK, seed := 0) -> void:
	for s: float in [1.0, -1.0]:
		kit.push(Transform3D(Basis(Vector3.UP, 0.0 if s > 0 else PI) * Basis(Vector3.RIGHT, -0.2), pos))
		kit.box(Vector3(0, 0.5, 0.11), Vector3(0.62, 1.0, 0.04), col)
		menu_board(kit, Vector3(0, 0.55, 0.14), Vector2(0.5, 0.72), 3, col, seed + int(s))
		kit.pop()


## Bulbs on a sagging wire from `a` to `b`. `fancy` puts them on the "bulbs" surface (steady,
## bright at night); otherwise plain coloured balls.
static func string_lights(kit: MeshKit, a: Vector3, b: Vector3, n: int, sag := 0.25, fancy := false, cols: Array = [BULB]) -> void:
	var prev := a
	for i in range(1, n + 2):
		var t := float(i) / (n + 1)
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		kit.beam(prev, p, Vector2(0.012, 0.012), IRON)
		prev = p
	kit.use("bulbs" if fancy else "solid", 0.0 if fancy else -1.0)
	for i in n:
		var t := (i + 1.0) / (n + 1)
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t) + 0.07, 0)
		kit.sphere(p, Vector3(0.05, 0.065, 0.05), cols[i % cols.size()], 2, 4)
	kit.use("solid")


## Pennants on a sagging line from `a` to `b` (double-sided; `fancy`: on "canvas", fluttering).
static func bunting(kit: MeshKit, a: Vector3, b: Vector3, n: int, sag := 0.3, cols: Array = GAY, fancy := false) -> void:
	var prev := a
	for i in range(1, n + 2):
		var t := float(i) / (n + 1)
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		kit.beam(prev, p, Vector2(0.01, 0.01), WHITE.darkened(0.3))
		prev = p
	kit.use("canvas" if fancy else "solid")
	var along := (b - a).normalized() * ((b - a).length() / (n + 1) * 0.36)
	for i in n:
		var t := (i + 0.5) / n
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var c: Color = cols[i % cols.size()]
		var tip := p + Vector3(0, -0.3, 0)
		var fixed := Color(c, 1.0)
		var free := Color(c, 0.3 if fancy else 1.0)
		kit.tri_c(p - along, p + along, tip, fixed, fixed, free)
		kit.tri_c(p + along, p - along, tip, fixed, fixed, free)
	kit.use("solid")


## A slatted wooden crate (`size`) on the ground at `pos`; `goods` fills its top with round
## things (fruit, fish, balls) in those colours.
static func crate(kit: MeshKit, pos: Vector3, size := Vector3(0.6, 0.35, 0.45), col := WOOD_LIGHT, goods: Array = []) -> void:
	var h := size * 0.5
	kit.box(pos + Vector3(0, h.y, 0), size, col.darkened(0.15))
	for k in 3:
		var y := pos.y + 0.06 + k * (size.y - 0.08) / 2.0
		for s: float in [-1.0, 1.0]:
			kit.box(Vector3(pos.x, y, pos.z + s * (h.z + 0.005)), Vector3(size.x, 0.07, 0.01), col)
	for s: float in [-1.0, 1.0]:
		kit.box(pos + Vector3(s * (h.x - 0.03), h.y, h.z + 0.012), Vector3(0.06, size.y, 0.012), col.darkened(0.3))
	if goods.is_empty():
		return
	var nx := maxi(1, int(size.x / 0.16))
	var nz := maxi(1, int(size.z / 0.16))
	for ix in nx:
		for iz in nz:
			var p := pos + Vector3(-h.x + (ix + 0.5) * size.x / nx, size.y + 0.02, -h.z + (iz + 0.5) * size.z / nz)
			kit.sphere(p, Vector3(0.075, 0.065, 0.075), goods[(ix + iz) % goods.size()], 2, 5)


## A barrel standing at `pos`.
static func barrel(kit: MeshKit, pos: Vector3, height := 0.8, r := 0.3, col := WOOD) -> void:
	kit.translate(pos)
	kit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(r * 0.85, 0.0), Vector2(r, height * 0.5), Vector2(r * 0.85, height), Vector2(0.0, height)]), 8, col)
	kit.pop()
	for y: float in [0.12, 0.5, 0.88]:
		var rr := lerpf(r * 0.85, r, 1.0 - absf(y - 0.5) * 2.0) + 0.012
		kit.cylinder(pos + Vector3(0, height * y - 0.025, 0), 0.05, rr, rr, 8, IRON, false)


## A flower box `w` long facing +Z at `pos` (its bottom middle).
static func flower_box(kit: MeshKit, pos: Vector3, w: float, col := WOOD, flowers: Array = [Color("e04a5a"), Color("f2c230"), WHITE, Color("b05ad8")]) -> void:
	kit.box(pos + Vector3(0, 0.1, 0), Vector3(w, 0.2, 0.22), col)
	var n := maxi(2, int(w / 0.14))
	for i in n:
		var x := pos.x - w * 0.5 + (i + 0.5) * w / n
		kit.sphere(Vector3(x, pos.y + 0.24, pos.z + (0.04 if i % 2 else -0.04)), Vector3(0.08, 0.07, 0.08), Color("3f8a3a"), 2, 4)
		kit.sphere(Vector3(x, pos.y + 0.3, pos.z + (0.05 if i % 2 else -0.03)), Vector3(0.045, 0.04, 0.045), flowers[i % flowers.size()], 2, 4)


## A row of bottles on a shelf from `a` along +X (`n`, `step` apart).
static func bottles(kit: MeshKit, a: Vector3, n: int, step := 0.16, cols: Array = [Color("2e9a6a"), Color("e8a030"), Color("c8352e"), Color("8fd3e8")]) -> void:
	for i in n:
		var p := a + Vector3(i * step, 0, 0)
		var c: Color = cols[i % cols.size()]
		kit.cylinder(p, 0.2, 0.045, 0.045, 6, c)
		kit.cylinder(p + Vector3(0, 0.2, 0), 0.08, 0.045, 0.018, 6, c)
		kit.cylinder(p + Vector3(0, 0.28, 0), 0.02, 0.022, 0.022, 4, WHITE)


## A row of glass jars with lids and coloured contents from `a` along +X.
static func jars(kit: MeshKit, a: Vector3, n: int, step := 0.22, cols: Array = GAY) -> void:
	for i in n:
		var p := a + Vector3(i * step, 0, 0)
		kit.cylinder(p, 0.2, 0.08, 0.08, 7, (cols[i % cols.size()] as Color).lightened(0.15))
		kit.cylinder(p + Vector3(0, 0.2, 0), 0.04, 0.085, 0.085, 7, GOLD)


## Shelves on a back wall facing +Z: `rows` boards `w` wide from `y0` up, each filled with goods
## ("bottles", "jars" or "boxes").
static func shelves(kit: MeshKit, center: Vector3, w: float, rows: int, goods: String, y0 := 1.15, gap := 0.45, seed := 0) -> void:
	for r in rows:
		var y := y0 + r * gap
		kit.box(Vector3(center.x, y, center.z), Vector3(w, 0.04, 0.3), WOOD_DARK)
		var a := Vector3(center.x - w * 0.5 + 0.12, y + 0.02, center.z)
		match goods:
			"bottles":
				bottles(kit, a, int((w - 0.2) / 0.16))
			"jars":
				jars(kit, a + Vector3(0.04, 0, 0), int((w - 0.2) / 0.22))
			_:
				var n := int((w - 0.2) / 0.3)
				for k in n:
					kit.box(a + Vector3(0.13 + k * 0.3, 0.12, 0), Vector3(0.22, 0.24, 0.16), GAY[(k + r + seed) % GAY.size()])


## A big symbol for a stand's roof that shows from afar what it sells: "fish", "ice_cone",
## "beach_ball", "shell", "wheel" (a ship's wheel), "drink", "ticket", "star". `s` scales it.
static func topper(kit: MeshKit, kind: String, pos: Vector3, s := 1.0, col := WHITE) -> void:
	kit.push(Transform3D(Basis().scaled(Vector3(s, s, s)), pos))
	kit.rod(Vector3(0, -0.4, -0.05), Vector3(0, 0.0, -0.05), 0.03, 0.03, 4, IRON)
	match kind:
		"fish":
			var body := Color("6fa8c8")
			kit.sphere(Vector3(0, 0.35, 0), Vector3(0.62, 0.3, 0.12), body, 3, 8)
			kit.sphere(Vector3(0.05, 0.28, 0), Vector3(0.5, 0.18, 0.125), Color("dfe8ee"), 2, 8)
			kit.tri(Vector3(-0.55, 0.35, 0.0), Vector3(-0.95, 0.65, 0.0), Vector3(-0.95, 0.05, 0.0), body.darkened(0.15))
			kit.tri(Vector3(-0.55, 0.35, 0.0), Vector3(-0.95, 0.05, 0.0), Vector3(-0.95, 0.65, 0.0), body.darkened(0.15))
			kit.tri(Vector3(-0.1, 0.62, 0.0), Vector3(0.25, 0.62, 0.0), Vector3(-0.2, 0.85, 0.0), body.darkened(0.25))
			kit.tri(Vector3(-0.1, 0.62, 0.0), Vector3(-0.2, 0.85, 0.0), Vector3(0.25, 0.62, 0.0), body.darkened(0.25))
			for z: float in [0.12, -0.12]:
				kit.sphere(Vector3(0.38, 0.42, z), Vector3(0.07, 0.07, 0.02), WHITE, 2, 5)
				kit.sphere(Vector3(0.4, 0.42, z * 1.12), Vector3(0.035, 0.035, 0.015), Color("1a1a1a"), 2, 4)
		"ice_cone":
			kit.cylinder(Vector3(0, -0.05, 0), 0.75, 0.0, 0.26, 8, Color("d9a35c"))
			for k in 3:
				kit.cylinder(Vector3(0, 0.15 + k * 0.2, 0), 0.02, 0.15 + k * 0.035, 0.15 + k * 0.035, 8, Color("b07a3a"))
			kit.sphere(Vector3(0, 0.82, 0), Vector3(0.3, 0.26, 0.3), Color("f7c6d9"), 3, 8)
			kit.sphere(Vector3(0, 1.1, 0), Vector3(0.25, 0.22, 0.25), Color("fff3c0"), 3, 8)
			kit.sphere(Vector3(0, 1.32, 0), Vector3(0.18, 0.16, 0.18), Color("6b3e26"), 3, 8)
			kit.sphere(Vector3(0.05, 1.48, 0), Vector3(0.06, 0.06, 0.06), Color("d8402e"), 2, 5)
		"beach_ball":
			var cols := [Color("d8402e"), WHITE, Color("2f6fb0"), WHITE, Color("f2c230"), WHITE]
			var c := Vector3(0, 0.45, 0)
			var rings := 6
			var segs := 12
			for k in segs:
				var a0 := TAU * k / segs
				var a1 := TAU * (k + 1) / segs
				for j in rings:
					var b0 := PI * j / rings
					var b1 := PI * (j + 1) / rings
					var p00 := c + Vector3(sin(b0) * cos(a0), cos(b0), sin(b0) * sin(a0)) * 0.42
					var p01 := c + Vector3(sin(b0) * cos(a1), cos(b0), sin(b0) * sin(a1)) * 0.42
					var p10 := c + Vector3(sin(b1) * cos(a0), cos(b1), sin(b1) * sin(a0)) * 0.42
					var p11 := c + Vector3(sin(b1) * cos(a1), cos(b1), sin(b1) * sin(a1)) * 0.42
					kit.quad(p00, p01, p11, p10, cols[k / 2])
		"shell":
			var sc := Color("f2c8a8")
			for k in 9:
				var a := lerpf(-1.2, 1.2, k / 8.0)
				kit.push(Transform3D(Basis(Vector3.FORWARD, a), Vector3(0, 0.05, 0)))
				kit.box(Vector3(0, 0.42, 0), Vector3(0.14, 0.8, 0.08), sc if k % 2 == 0 else sc.darkened(0.12))
				kit.pop()
			kit.sphere(Vector3(0, 0.05, 0), Vector3(0.16, 0.1, 0.1), sc.darkened(0.2), 2, 5)
		"wheel":
			kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.5, 0)))
			kit.torus(Vector3.ZERO, 0.42, 0.05, 14, 4, WOOD)
			kit.pop()
			for k in 8:
				var a := TAU * k / 8.0
				var d := Vector3(cos(a), sin(a), 0)
				kit.rod(Vector3(0, 0.5, 0) + d * 0.06, Vector3(0, 0.5, 0) + d * 0.62, 0.035, 0.03, 4, WOOD)
				kit.sphere(Vector3(0, 0.5, 0) + d * 0.64, Vector3(0.045, 0.045, 0.045), WOOD_DARK, 2, 4)
			kit.sphere(Vector3(0, 0.5, 0), Vector3(0.1, 0.1, 0.08), GOLD, 2, 6)
		"drink":
			kit.cylinder(Vector3(0, -0.05, 0), 0.1, 0.25, 0.25, 8, col.darkened(0.3))
			kit.cylinder(Vector3(0, 0.05, 0), 0.3, 0.04, 0.04, 5, Color("dfe8ee"))
			kit.cylinder(Vector3(0, 0.35, 0), 0.55, 0.1, 0.36, 8, Color("bfe4f0"))
			kit.cylinder(Vector3(0, 0.5, 0), 0.35, 0.18, 0.33, 8, col)
			kit.rod(Vector3(0.1, 0.6, 0), Vector3(0.3, 1.15, 0), 0.025, 0.025, 4, Color("d8402e"))
			kit.sphere(Vector3(-0.32, 0.88, 0), Vector3(0.12, 0.12, 0.04), Color("f2c230"), 2, 6)
		"ticket":
			kit.box(Vector3(0, 0.4, 0), Vector3(0.9, 0.48, 0.05), col)
			kit.box(Vector3(0, 0.4, 0.03), Vector3(0.7, 0.3, 0.02), WHITE)
			for side: float in [-1.0, 1.0]:
				kit.sphere(Vector3(side * 0.45, 0.4, 0), Vector3(0.08, 0.08, 0.06), col.darkened(0.3), 2, 5)
		_:
			star(kit, Vector3(0, 0.45, 0.02), 0.45, 0.2, col)
			kit.push(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.02)))
			star(kit, Vector3(0, 0.45, 0), 0.45, 0.2, col)
			kit.pop()
	kit.pop()

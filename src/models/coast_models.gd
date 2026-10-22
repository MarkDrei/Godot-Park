class_name CoastModels
extends RefCounted
## Procedural models of the Möwenbucht (doc/moewenbucht.md): the boats, Strandkörbe and parasols,
## the lifeguard tower, the stands, the bandstand, the pirate ship, the lighthouse, the cutter,
## buoys, posts, fences, beach grass and the seals. Origins sit on the ground (boats on the
## water line); "front" faces +Z unless stated otherwise.

const WHITE := Color("f4f1ea")
const RED := Color("c8352e")
const BLUE := Color("2f6fb0")
const NAVY := Color("24365a")
const WOOD := Color("9a6a3e")
const WOOD_LIGHT := Color("c49a63")
const WOOD_DARK := Color("6a4a2e")
const DRIFT := Color("a8987e")       # weathered wood (groynes, boardwalks)
const DECK := Color("a8927a")        # the pier's and the jetty's planks
const WICKER := Color("d9bf8a")
const STONE := Color("9d968a")
const STONE_DARK := Color("7e786e")
const IRON := Color("2f3b33")
const GLASS := Color("ffe7a8")
## Stripes of the Strandkörbe and parasols.
const STRIPES := [Color("2f6fb0"), Color("c8352e"), Color("2e9a6a"), Color("e0a32e"), Color("7a4a9a")]


static func cached(key: String, builder: Callable) -> Mesh:
	return NatureModels.cached("coast_" + key, builder)


## A face a-b-c-d seen from the side `outward` points to (the kit wants them anticlockwise).
static func _face(kit: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) >= 0.0:
		kit.quad(a, b, c, d, col)
	else:
		kit.quad(a, d, c, b, col)


## An open hull along z (stern at -length/2, bow at +length/2): outside `col`, inside `inner`,
## a white rubbing strake; y = 0 is the keel. `bow` < 1: a blunter bow (pedal boat).
static func _hull(kit: MeshKit, length: float, beam: float, depth: float, col: Color, inner: Color, bow := 1.0) -> void:
	var n := 9
	var stations: Array = []
	for i in n:
		var t := float(i) / (n - 1)
		var z := lerpf(-length * 0.5, length * 0.5, t)
		var u := (t - 0.42) / 0.58
		var w := beam * 0.5 * sqrt(maxf(0.0, 1.0 - u * u * bow))
		if t < 0.42:
			w = beam * 0.5 * lerpf(0.72, 1.0, smoothstep(0.0, 0.42, t))
		w = maxf(w, 0.03)
		var bottom := 0.16 * pow(t, 3.0)
		var top := depth + 0.1 * pow(t, 2.0)
		stations.append([Vector3(-w, top, z), Vector3(-w * 0.72, bottom + 0.07, z), Vector3(0, bottom, z),
			Vector3(w * 0.72, bottom + 0.07, z), Vector3(w, top, z)])
	for i in n - 1:
		var s0: Array = stations[i]
		var s1: Array = stations[i + 1]
		for j in 4:
			var a: Vector3 = s0[j]
			var b: Vector3 = s0[j + 1]
			var c: Vector3 = s1[j + 1]
			var d: Vector3 = s1[j]
			var mid := (a + b + c + d) * 0.25
			var out := Vector3(mid.x, mid.y - depth * 0.6, 0)
			_face(kit, a, b, c, d, col, out)
			_face(kit, a, b, c, d, inner, -out)
		for side in [0, 4]:
			kit.beam(s0[side] + Vector3(0, 0.02, 0), s1[side] + Vector3(0, 0.02, 0), Vector2(0.06, 0.06), WHITE)
	# The transom at the stern.
	var st: Array = stations[0]
	for j in 4:
		var a: Vector3 = st[j]
		var b: Vector3 = st[j + 1]
		var c := Vector3(0, depth, st[0].z)
		if (c - a).cross(b - a).dot(Vector3(0, 0, -1)) >= 0.0:
			kit.tri(a, c, b, col)
		else:
			kit.tri(a, b, c, col)
		if (b - a).cross(c - a).dot(Vector3(0, 0, 1)) >= 0.0:
			kit.tri(a, b, c, inner)
		else:
			kit.tri(a, c, b, inner)


## The boats: "rowboat" (wooden, two thwarts, the oarlocks; the oars are boat_parts) and
## "pedalo" (a white swan with two seats and the paddle wheel's box). The water line is y = 0.
static func boat(kind: String, col: Color) -> Mesh:
	return cached("boat_%s_%s" % [kind, col.to_html(false)], func() -> Mesh:
		var kit := MeshKit.new()
		if kind == "rowboat":
			kit.translate(Vector3(0, -0.18, 0))
			_hull(kit, 3.4, 1.3, 0.62, col, WOOD_LIGHT)
			kit.box(Vector3(0, 0.12, 0), Vector3(0.62, 0.03, 2.6), WOOD)
			for z: float in [-0.95, 0.15]:
				kit.box(Vector3(0, 0.36, z), Vector3(1.18, 0.05, 0.26), WOOD_DARK)
			kit.box(Vector3(0, 0.4, -1.45), Vector3(0.8, 0.05, 0.28), WOOD_DARK)
			for side: float in [-1.0, 1.0]:
				kit.cylinder(Vector3(side * 0.63, 0.62, 0.15), 0.12, 0.025, 0.025, 4, IRON)
			kit.pop()
		else:
			kit.translate(Vector3(0, -0.22, 0))
			_hull(kit, 2.7, 1.6, 0.6, WHITE, Color("dfe8ee"), 0.6)
			# Seats side by side, foot well, the paddle wheel's box at the stern.
			kit.box(Vector3(0, 0.18, 0.1), Vector3(1.2, 0.04, 1.6), Color("c9d6de"))
			for side: float in [-0.34, 0.34]:
				kit.box(Vector3(side, 0.42, -0.25), Vector3(0.5, 0.08, 0.45), Color("3a7ab8"))
				kit.box(Vector3(side, 0.7, -0.5), Vector3(0.5, 0.5, 0.08), Color("3a7ab8"))
			kit.box(Vector3(0, 0.55, -1.0), Vector3(0.5, 0.5, 0.55), WHITE)
			# The swan's neck and head at the bow.
			var neck := [Vector3(0, 0.55, 1.05), Vector3(0, 0.95, 1.2), Vector3(0, 1.3, 1.12), Vector3(0, 1.52, 1.2)]
			for i in neck.size() - 1:
				kit.rod(neck[i], neck[i + 1], 0.13 - i * 0.025, 0.11 - i * 0.025, 6, WHITE)
			kit.sphere(Vector3(0, 1.58, 1.26), Vector3(0.13, 0.12, 0.17), WHITE, 3, 6)
			kit.rod(Vector3(0, 1.56, 1.38), Vector3(0, 1.52, 1.55), 0.05, 0.02, 5, Color("e88a2a"))
			for side: float in [-1.0, 1.0]:
				kit.sphere(Vector3(side * 0.1, 1.62, 1.32), Vector3(0.025, 0.025, 0.025), Color("1a1a1a"), 2, 4)
				# Folded wings along the sides.
				kit.push(Transform3D(Basis(Vector3.UP, side * 0.08), Vector3(side * 0.74, 0.62, -0.1)))
				kit.box(Vector3.ZERO, Vector3(0.08, 0.22, 1.5), Color("eef0f2"))
				kit.pop()
			kit.pop()
		return kit.commit())


## The moving parts of a boat as children of `boat` (oars of a rowing boat, the paddle wheel of
## a pedal boat); move_boat_parts animates them.
static func boat_parts(boat: Node3D, kind: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if kind == "rowboat":
		for side: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.63, 0.5, 0.15)
			var mi := MeshInstance3D.new()
			mi.mesh = oar()
			mi.rotation.y = 0.0 if side > 0 else PI
			pivot.add_child(mi)
			pivot.set_meta("side", side)
			boat.add_child(pivot)
			out.append(pivot)
	elif kind == "pedalo":
		var wheel := Node3D.new()
		wheel.position = Vector3(0, 0.12, -1.3)
		var mi := MeshInstance3D.new()
		mi.mesh = paddle_wheel()
		wheel.add_child(mi)
		boat.add_child(wheel)
		out.append(wheel)
	return out


static func move_boat_parts(parts: Array[Node3D], kind: String, stroke: float, active: bool) -> void:
	if kind == "rowboat":
		for p in parts:
			var side: float = p.get_meta("side")
			var sweep := sin(stroke) * 0.55 if active else 0.0
			var lift := (cos(stroke) * 0.18 + 0.05) if active else 0.22
			p.rotation = Vector3(0, -sweep * side, -lift * side)
	elif not parts.is_empty():
		parts[0].rotation.x = stroke * 2.0


## An oar from its oarlock outwards along +x: the loom, the blade.
static func oar() -> Mesh:
	return cached("oar", func() -> Mesh:
		var kit := MeshKit.new()
		kit.rod(Vector3(-0.7, 0.05, 0), Vector3(1.4, -0.25, 0), 0.03, 0.025, 5, WOOD_LIGHT)
		kit.push(Transform3D(Basis(Vector3.FORWARD, 0.14), Vector3(1.7, -0.3, 0)))
		kit.box(Vector3.ZERO, Vector3(0.6, 0.02, 0.16), WOOD_LIGHT)
		kit.pop()
		return kit.commit())


## A pedal boat's paddle wheel (axis along x).
static func paddle_wheel() -> Mesh:
	return cached("paddle_wheel", func() -> Mesh:
		var kit := MeshKit.new()
		kit.rod(Vector3(-0.25, 0, 0), Vector3(0.25, 0, 0), 0.05, 0.05, 6, IRON)
		for k in 6:
			var a := TAU * k / 6.0
			kit.push(Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO))
			kit.box(Vector3(0, 0.22, 0), Vector3(0.4, 0.26, 0.03), Color("3a7ab8"))
			kit.pop()
		return kit.commit())


## A Strandkorb: a wicker basket for two with a rounded hood, striped cushions inside and a
## striped valance along the hood's edge (seen from behind too); seats face +Z at 0.45 m.
static func strandkorb(v: int) -> Mesh:
	return cached("strandkorb_%d" % v, func() -> Mesh:
		var kit := MeshKit.new()
		var stripe: Color = STRIPES[v % STRIPES.size()]
		var wicker := Color("e6d3a3")
		var weave := Color("c9b07a")
		# Base with the footrest drawers, back and sides, the weave's lines.
		kit.box(Vector3(0, 0.22, 0.02), Vector3(1.34, 0.44, 0.86), wicker)
		kit.box(Vector3(0, 0.22, 0.46), Vector3(1.1, 0.3, 0.04), weave)
		kit.box(Vector3(0, 0.85, -0.38), Vector3(1.34, 0.84, 0.12), wicker)
		for side: float in [-1.0, 1.0]:
			kit.box(Vector3(side * 0.62, 0.85, -0.02), Vector3(0.1, 0.84, 0.76), wicker)
			kit.box(Vector3(side * 0.62, 0.7, 0.3), Vector3(0.14, 0.06, 0.3), WOOD_LIGHT)
		for k in 9:
			var y := 0.1 + k * 0.13
			kit.box(Vector3(0, y, -0.445), Vector3(1.35, 0.025, 0.01), weave)
			for side: float in [-1.0, 1.0]:
				kit.box(Vector3(side * 0.675, y, -0.02), Vector3(0.01, 0.025, 0.78), weave)
		# The hood: an arc from the back over the seats, wicker outside, the lining inside.
		var segs := 8
		var c := Vector3(0, 1.27, -0.02)
		var r := 0.44
		for k in segs:
			var a0 := PI - PI * k / segs
			var a1 := PI - PI * (k + 1) / segs
			var p0 := c + Vector3(0, sin(a0) * r, cos(a0) * r)
			var p1 := c + Vector3(0, sin(a1) * r, cos(a1) * r)
			var mid := (p0 + p1) * 0.5
			var len := p0.distance_to(p1) + 0.03
			kit.push(Transform3D(Basis(Vector3.RIGHT, -(a0 + a1) * 0.5 + PI / 2), mid))
			kit.box(Vector3.ZERO, Vector3(1.34, 0.07, len), wicker if k % 2 == 0 else weave.lightened(0.15))
			kit.box(Vector3(0, -0.045, 0), Vector3(1.2, 0.02, len), stripe if k % 2 == 0 else WHITE)
			kit.pop()
		# The hood's sides: half discs.
		for side: float in [-1.0, 1.0]:
			var o := c + Vector3(side * 0.66, 0, 0)
			for k in segs:
				var a0 := PI - PI * k / segs
				var a1 := PI - PI * (k + 1) / segs
				var q0 := o + Vector3(0, sin(a0) * r, cos(a0) * r)
				var q1 := o + Vector3(0, sin(a1) * r, cos(a1) * r)
				if (q0 - o).cross(q1 - o).x * side >= 0.0:
					kit.tri(o, q0, q1, weave)
				else:
					kit.tri(o, q1, q0, weave)
		# The striped valance along the hood's front edge.
		for k in 6:
			kit.box(Vector3(-0.56 + k * 0.224, 1.2, 0.43), Vector3(0.224, 0.14, 0.03), stripe if k % 2 == 0 else WHITE)
		# Cushions: seat and back, striped.
		kit.box(Vector3(0, 0.47, 0.06), Vector3(1.16, 0.07, 0.66), stripe)
		for k in 5:
			kit.box(Vector3(-0.464 + k * 0.232, 0.88, -0.315), Vector3(0.232, 0.74, 0.03), stripe if k % 2 == 0 else WHITE)
		return kit.commit())


## A beach parasol, striped.
static func parasol(v: int) -> Mesh:
	return cached("parasol_%d" % v, func() -> Mesh:
		var kit := MeshKit.new()
		var col: Color = STRIPES[(v + 2) % STRIPES.size()]
		kit.cylinder(Vector3(0, -0.3, 0), 2.6, 0.03, 0.03, 5, WHITE)
		for k in 8:
			var a0 := TAU * k / 8.0
			var a1 := TAU * (k + 1) / 8.0
			var top := Vector3(0, 2.35, 0)
			var e0 := Vector3(cos(a0) * 1.3, 1.95, sin(a0) * 1.3)
			var e1 := Vector3(cos(a1) * 1.3, 1.95, sin(a1) * 1.3)
			var c := col if k % 2 == 0 else WHITE
			kit.tri(top, e1, e0, c)
			kit.tri(top, e0, e1, c.darkened(0.15))
		return kit.commit())


## A towel lying on the sand.
static func towel(v: int) -> Mesh:
	return cached("towel_%d" % v, func() -> Mesh:
		var kit := MeshKit.new()
		var col: Color = STRIPES[(v + 1) % STRIPES.size()]
		for k in 4:
			kit.box(Vector3(0, 0.01, -0.75 + k * 0.5 + 0.25), Vector3(0.8, 0.02, 0.5), col if k % 2 == 0 else WHITE)
		return kit.commit())


## The lifeguard tower: a hut on stilts with a ladder, a flag and a lifebuoy (front +Z, the sea).
static func lifeguard_tower() -> Mesh:
	return cached("lifeguard_tower", func() -> Mesh:
		var kit := MeshKit.new()
		for x: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				kit.beam(Vector3(x * 1.25, -0.4, z * 1.25), Vector3(x * 1.0, 2.6, z * 1.0), Vector2(0.14, 0.14), WOOD)
		kit.box(Vector3(0, 2.65, 0.2), Vector3(2.8, 0.12, 2.8), WOOD_DARK)
		kit.box(Vector3(0, 3.6, -0.7), Vector3(2.3, 1.8, 1.0), WHITE)
		for x: float in [-1.1, 1.1]:
			kit.box(Vector3(x, 3.6, 0.1), Vector3(0.08, 1.8, 2.4), WHITE)
		kit.box(Vector3(0, 3.0, 1.35), Vector3(2.3, 0.6, 0.06), RED)
		kit.prism(PackedVector2Array([Vector2(-1.5, -1.4), Vector2(1.5, -1.4), Vector2(1.5, 1.7), Vector2(-1.5, 1.7)]), 4.5, 4.65, RED)
		# Ladder down to the beach at the front.
		for x: float in [-0.35, 0.35]:
			kit.beam(Vector3(x, -0.2, 2.9), Vector3(x, 2.7, 1.4), Vector2(0.07, 0.07), WOOD)
		for k in 6:
			var t := (k + 0.5) / 6.0
			kit.box(Vector3(0, lerpf(-0.2, 2.7, t), lerpf(2.9, 1.4, t)), Vector3(0.7, 0.04, 0.12), WOOD_LIGHT)
		kit.cylinder(Vector3(1.3, 4.6, -1.3), 2.0, 0.035, 0.03, 5, WHITE)
		kit.box(Vector3(1.6, 6.3, -1.3), Vector3(0.6, 0.4, 0.02), Color("e8c02e"))
		kit.box(Vector3(1.6, 6.3, -1.29), Vector3(0.6, 0.13, 0.02), RED)
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(-0.8, 3.4, 1.42)))
		kit.torus(Vector3.ZERO, 0.28, 0.07, 12, 4, Color("f06a2a"))
		kit.pop()
		return kit.commit())


## A seaside stand: a little white wooden hut with a counter and an awning in `col`, its name
## board left blank (the builder puts the letters on). Front +Z; the vendor stands inside.
static func beach_stand(col: Color) -> Mesh:
	return cached("beach_stand_%s" % col.to_html(false), func() -> Mesh:
		var kit := MeshKit.new()
		var wall := Color("eef0ec")
		kit.box(Vector3(0, 0.03, 0), Vector3(3.6, 0.06, 2.6), WOOD_DARK)
		kit.box(Vector3(0, 1.35, -1.25), Vector3(3.6, 2.7, 0.1), wall)
		for x: float in [-1.75, 1.75]:
			kit.box(Vector3(x, 1.35, 0), Vector3(0.1, 2.7, 2.6), wall)
		kit.box(Vector3(0, 0.55, 1.25), Vector3(3.6, 1.1, 0.1), wall)
		kit.box(Vector3(0, 1.12, 1.35), Vector3(3.7, 0.08, 0.4), WOOD_LIGHT)
		for x: float in [-1.6, 1.6]:
			kit.box(Vector3(x, 1.9, 1.25), Vector3(0.12, 1.6, 0.12), wall)
		# Boards of the walls (blue lines), the roof, the awning.
		for k in 5:
			kit.box(Vector3(0, 0.3 + k * 0.5, -1.31), Vector3(3.6, 0.03, 0.02), Color("9bb6c8"))
		kit.prism(PackedVector2Array([Vector2(-2.0, -1.5), Vector2(2.0, -1.5), Vector2(2.0, 1.4), Vector2(-2.0, 1.4)]), 2.7, 2.85, Color("5a6a78"))
		for k in 6:
			var x0 := -1.9 + k * 3.8 / 6.0
			kit.push(Transform3D(Basis(Vector3.RIGHT, 0.45), Vector3(x0 + 3.8 / 12.0, 2.45, 1.75)))
			kit.box(Vector3.ZERO, Vector3(3.8 / 6.0, 0.03, 0.9), col if k % 2 == 0 else WHITE)
			kit.pop()
		kit.box(Vector3(0, 3.15, 1.2), Vector3(3.0, 0.6, 0.08), WHITE)
		kit.box(Vector3(0, 3.15, 1.17), Vector3(3.1, 0.68, 0.04), col.darkened(0.2))
		return kit.commit())


## The beach bar: posts, a counter at the front (+Z), shelves with bottles, a straw roof.
static func beach_bar() -> Mesh:
	return cached("beach_bar", func() -> Mesh:
		var kit := MeshKit.new()
		var straw := Color("d8c07a")
		for x: float in [-2.0, 2.0]:
			for z: float in [-1.4, 1.4]:
				kit.cylinder(Vector3(x, -0.2, z), 2.8, 0.1, 0.09, 6, DRIFT)
		kit.box(Vector3(0, 0.03, 0), Vector3(4.3, 0.06, 3.1), WOOD)
		kit.box(Vector3(0, 0.55, 1.4), Vector3(4.2, 1.1, 0.2), Color("6fb0c0"))
		kit.box(Vector3(0, 1.14, 1.5), Vector3(4.4, 0.08, 0.5), WOOD_LIGHT)
		kit.box(Vector3(0, 1.2, -1.45), Vector3(3.8, 0.05, 0.3), WOOD_DARK)
		for k in 9:
			kit.cylinder(Vector3(-1.6 + k * 0.4, 1.23, -1.45), 0.3, 0.05, 0.04, 5, [Color("2e9a6a"), Color("e8a030"), Color("c8352e")][k % 3])
		# The straw roof in layers.
		for layer in 3:
			var y := 2.6 + layer * 0.28
			var r := 3.2 - layer * 0.9
			kit.cylinder(Vector3(0, y, 0), 0.32, r, r - 0.75, 8, straw.darkened(layer * 0.06), true, straw.darkened(0.2), PI / 8)
		kit.box(Vector3(0, 2.25, 1.55), Vector3(2.6, 0.45, 0.06), Color("2e9a6a"))
		return kit.commit())


## A bar stool (a seat at 0.45 m facing +Z, like a bench's).
static func bar_stool() -> Mesh:
	return cached("bar_stool", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.42, 0.04, 0.04, 5, IRON)
		kit.cylinder(Vector3(0, 0.42, 0), 0.06, 0.2, 0.2, 8, Color("e8742e"))
		return kit.commit())


## A cluster of shells and a little seaweed on the sand (a gathering spot).
static func shells(v: int) -> Mesh:
	return cached("shells_%d" % v, func() -> Mesh:
		var rng := NatureModels.seeded_rng(v + 4600)
		var kit := MeshKit.new()
		for i in 5:
			var a := rng.randf() * TAU
			var q := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.28)
			var col: Color = [Color("f0d8c0"), Color("e8c8b0"), Color("f4ece0"), Color("d8b8a0")][i % 4]
			kit.push(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q))
			kit.sphere(Vector3(0, 0.02, 0), Vector3(0.07, 0.035, 0.06), col, 2, 6)
			kit.pop()
		kit.box(Vector3(0.15, 0.01, -0.12), Vector3(0.35, 0.01, 0.06), Color("4a6a3a"))
		return kit.commit())


## The bandstand (Kurmuschel): a white shell over a round stage, open to +Z.
static func bandstand() -> Mesh:
	return cached("bandstand", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.6, 5.2, 5.2, 16, Color("d8d2c4"), true, Color("b99a6a"))
		for k in 4:
			kit.box(Vector3(0, 0.1 + k * 0.15, 5.3 + k * 0.0), Vector3(3.0, 0.15, 0.4), Color("d8d2c4"))
		# The shell: ribs and panels in a half dome behind the stage.
		var segs := 10
		var rings := 6
		for i in segs:
			var a0 := PI * i / segs
			var a1 := PI * (i + 1) / segs
			for j in rings:
				var b0 := PI * 0.5 * j / rings
				var b1 := PI * 0.5 * (j + 1) / rings
				var p := func(a: float, b: float) -> Vector3:
					return Vector3(cos(a) * cos(b) * 5.0, 0.6 + sin(b) * 6.0, -sin(a) * cos(b) * 5.0)
				var c: Color = WHITE if (i + j) % 2 == 0 else Color("e9e4d6")
				var q00: Vector3 = p.call(a0, b0)
				var q10: Vector3 = p.call(a1, b0)
				var q11: Vector3 = p.call(a1, b1)
				var q01: Vector3 = p.call(a0, b1)
				_face(kit, q00, q10, q11, q01, c, -((q00 + q11) * 0.5 - Vector3(0, 0.6, 0)))
				_face(kit, q00, q10, q11, q01, c.darkened(0.12), (q00 + q11) * 0.5 - Vector3(0, 0.6, 0))
		kit.box(Vector3(0, 6.75, 0), Vector3(0.3, 0.3, 0.3), Color("e0b040"))
		return kit.commit())


## The pirate ship of the playground: a wooden hull on the sand, a deck, a mast with a sail and
## a flag, a slide off the stern and a rope ladder. Bow +Z.
static func pirate_ship() -> Mesh:
	return cached("pirate_ship", func() -> Mesh:
		var kit := MeshKit.new()
		kit.translate(Vector3(0, -0.2, 0))
		_hull(kit, 9.0, 3.4, 1.8, Color("7a4a2a"), WOOD_LIGHT)
		kit.pop()
		kit.box(Vector3(0, 1.2, -0.4), Vector3(2.9, 0.1, 6.4), WOOD)
		kit.box(Vector3(0, 2.2, -3.4), Vector3(3.0, 0.1, 2.0), WOOD)
		for x: float in [-1.4, 1.4]:
			kit.box(Vector3(x, 1.2, -3.4), Vector3(0.1, 2.0, 2.0), Color("6a3e22"))
		kit.cylinder(Vector3(0, 1.2, 0.6), 7.0, 0.12, 0.08, 6, WOOD_DARK)
		kit.beam(Vector3(-1.8, 6.2, 0.6), Vector3(1.8, 6.2, 0.6), Vector2(0.08, 0.08), WOOD_DARK)
		kit.quad(Vector3(-1.7, 6.1, 0.65), Vector3(1.7, 6.1, 0.65), Vector3(1.9, 3.1, 0.75), Vector3(-1.9, 3.1, 0.75), Color("efe6d0"))
		kit.quad(Vector3(-1.7, 6.1, 0.55), Vector3(-1.9, 3.1, 0.45), Vector3(1.9, 3.1, 0.45), Vector3(1.7, 6.1, 0.55), Color("e2d8c0"))
		kit.box(Vector3(0, 7.6, 0.6), Vector3(0.02, 0.5, 0.8), Color("1a1a1a"))
		kit.sphere(Vector3(0, 7.6, 0.75), Vector3(0.03, 0.1, 0.1), WHITE, 2, 4)
		# Slide from the stern deck down to the sand.
		kit.beam(Vector3(0.0, 2.25, -4.4), Vector3(0.0, 0.1, -7.6), Vector2(0.8, 0.06), Color("d8a02e"))
		for x: float in [-0.42, 0.42]:
			kit.beam(Vector3(x, 2.4, -4.4), Vector3(x, 0.25, -7.6), Vector2(0.06, 0.2), Color("c8352e"))
		# Rope ladder on the side.
		for k in 5:
			kit.box(Vector3(1.85, 0.25 + k * 0.28, 0.0), Vector3(0.06, 0.04, 0.8), Color("c9b48a"))
		return kit.commit())


## The beach volleyball net with its poles, along x.
static func volleyball_net() -> Mesh:
	return cached("volleyball_net", func() -> Mesh:
		var kit := MeshKit.new()
		for x: float in [-4.8, 4.8]:
			kit.cylinder(Vector3(x, -0.3, 0), 2.9, 0.06, 0.06, 6, WHITE)
		kit.box(Vector3(0, 2.38, 0), Vector3(9.6, 0.07, 0.02), WHITE)
		for k in 8:
			kit.box(Vector3(0, 1.62 + k * 0.1, 0), Vector3(9.5, 0.012, 0.012), Color("2a2a2a"))
		for k in 48:
			kit.box(Vector3(-4.7 + k * 0.2, 1.97, 0), Vector3(0.012, 0.8, 0.012), Color("2a2a2a"))
		return kit.commit())


## The lighthouse: a round tower in red and white bands, the gallery, the lantern room (glows)
## and a red cap; the door faces +Z.
static func lighthouse() -> Mesh:
	return cached("lighthouse", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 1.2, 3.0, 2.8, 14, STONE_DARK)
		var bands := 6
		var h := 15.0
		for k in bands:
			var y0 := 1.2 + h * k / bands
			var r0 := lerpf(2.4, 1.6, float(k) / bands)
			var r1 := lerpf(2.4, 1.6, float(k + 1) / bands)
			kit.cylinder(Vector3(0, y0, 0), h / bands, r0, r1, 14, RED if k % 2 == 0 else WHITE, false)
		var top := 1.2 + h
		kit.cylinder(Vector3(0, top, 0), 0.2, 2.4, 2.4, 14, IRON)
		for k in 16:
			var a := TAU * k / 16.0
			kit.cylinder(Vector3(cos(a) * 2.25, top + 0.2, sin(a) * 2.25), 0.9, 0.03, 0.03, 4, IRON)
		kit.torus(Vector3(0, top + 1.1, 0), 2.25, 0.04, 16, 4, IRON)
		kit.use("glow")
		kit.cylinder(Vector3(0, top + 0.2, 0), 1.7, 1.15, 1.15, 10, GLASS)
		kit.use("solid")
		kit.cylinder(Vector3(0, top + 1.9, 0), 0.9, 1.4, 0.2, 10, RED)
		kit.sphere(Vector3(0, top + 2.9, 0), Vector3(0.18, 0.18, 0.18), IRON, 2, 5)
		kit.box(Vector3(0, 2.3, 2.45), Vector3(1.1, 2.1, 0.3), Color("3a4a5a"))
		for k in 3:
			kit.box(Vector3(0, 6.0 + k * 4.0, 2.05 - k * 0.2), Vector3(0.5, 0.7, 0.2), Color("2a3442"))
		return kit.commit())


## The lighthouse's beam at night: a long pale cone (additive, see-through), turned by the
## runtime.
static func light_beam() -> Mesh:
	return cached("light_beam", func() -> Mesh:
		var kit := MeshKit.new()
		var near := Color(1.0, 0.93, 0.7, 0.5)
		var far := Color(1.0, 0.93, 0.7, 0.0)
		var n := 10
		for k in n:
			var a0 := TAU * k / n
			var a1 := TAU * (k + 1) / n
			var b0 := Vector3(cos(a0) * 0.5, sin(a0) * 0.5, 0)
			var b1 := Vector3(cos(a1) * 0.5, sin(a1) * 0.5, 0)
			var t0 := Vector3(cos(a0) * 5.0, sin(a0) * 5.0, 70.0)
			var t1 := Vector3(cos(a1) * 5.0, sin(a1) * 5.0, 70.0)
			kit.quad_c(b0, b1, t1, t0, near, near, far, far)
		var mesh := kit.commit()
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.no_depth_test = false
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.45)
		mesh.surface_set_material(0, mat)
		return mesh)


## A fishing cutter moored at the quay: hull, wheelhouse, mast with a boom and nets. Bow +Z.
static func cutter() -> Mesh:
	return cached("cutter", func() -> Mesh:
		var kit := MeshKit.new()
		kit.translate(Vector3(0, -0.6, 0))
		_hull(kit, 11.0, 3.6, 2.0, Color("2e5a8a"), Color("c9c2b0"))
		kit.pop()
		kit.box(Vector3(0, 0.9, -0.5), Vector3(3.2, 0.1, 8.0), Color("b0a48a"))
		kit.box(Vector3(0, 2.0, -2.8), Vector3(2.2, 2.1, 2.4), WHITE)
		kit.box(Vector3(0, 2.4, -1.58), Vector3(1.8, 0.6, 0.04), Color("3a4a5a"))
		kit.prism(PackedVector2Array([Vector2(-1.25, -4.1), Vector2(1.25, -4.1), Vector2(1.25, -1.5), Vector2(-1.25, -1.5)]), 3.05, 3.2, RED)
		kit.cylinder(Vector3(0, 0.9, 1.5), 6.5, 0.1, 0.07, 6, WOOD_DARK)
		kit.beam(Vector3(0, 2.2, 1.5), Vector3(0, 5.0, 4.4), Vector2(0.08, 0.08), WOOD_DARK)
		kit.sphere(Vector3(0.6, 1.2, 3.2), Vector3(0.7, 0.35, 0.9), Color("3a6a4a"), 2, 6)
		kit.cylinder(Vector3(0, 7.4, 1.5), 0.4, 0.05, 0.0, 4, RED)
		for side: float in [-1.0, 1.0]:
			for z: float in [-3.0, 0.0, 3.0]:
				kit.push(Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(side * 1.85, 0.5, z)))
				kit.torus(Vector3.ZERO, 0.25, 0.1, 8, 4, Color("2a2a2a"))
				kit.pop()
		return kit.commit())


## A buoy: a red or yellow float with a top mark.
static func buoy(v: int) -> Mesh:
	return cached("buoy_%d" % v, func() -> Mesh:
		var kit := MeshKit.new()
		var col: Color = [RED, Color("e8c02e"), RED, WHITE][v % 4]
		kit.sphere(Vector3(0, 0.05, 0), Vector3(0.45, 0.4, 0.45), col, 3, 8)
		kit.cylinder(Vector3(0, 0.3, 0), 0.7, 0.18, 0.1, 6, col.darkened(0.1))
		kit.box(Vector3(0, 0.62, 0), Vector3(0.36, 0.08, 0.36), WHITE)
		kit.sphere(Vector3(0, 1.08, 0), Vector3(0.12, 0.12, 0.12), col, 2, 5)
		return kit.commit())


## A weathered wooden post (groynes, bollards of the jetty), 2.4 m from y = -1.2.
static func post(v: int) -> Mesh:
	return cached("post_%d" % v, func() -> Mesh:
		var kit := MeshKit.new()
		var h := 2.4 - (v % 3) * 0.25
		kit.cylinder(Vector3(0, -1.2, 0), h, 0.15, 0.13, 6, DRIFT.darkened((v % 4) * 0.05))
		kit.cylinder(Vector3(0, -1.2 + h, 0), 0.04, 0.13, 0.1, 6, Color("8a8070"))
		return kit.commit())


## A bollard on the quay.
static func bollard() -> Mesh:
	return cached("bollard", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.55, 0.16, 0.14, 8, IRON)
		kit.cylinder(Vector3(0, 0.55, 0), 0.08, 0.22, 0.22, 8, IRON)
		return kit.commit())


## A post with a lifebuoy (Rettungsring).
static func lifebuoy_stand() -> Mesh:
	return cached("lifebuoy_stand", func() -> Mesh:
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.75, 0), Vector3(0.12, 1.5, 0.12), WOOD_DARK)
		kit.box(Vector3(0, 1.2, 0.08), Vector3(0.7, 0.7, 0.04), WHITE)
		kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1.2, 0.14)))
		for k in 8:
			kit.push(Transform3D(Basis(Vector3.UP, TAU * k / 8.0), Vector3.ZERO))
			kit.box(Vector3(0.25, 0, 0), Vector3(0.12, 0.1, 0.2), RED if k % 2 == 0 else WHITE)
			kit.pop()
		kit.pop()
		return kit.commit())


## A seaside lamp: a slim white post with a round globe.
static func sea_lamp() -> Mesh:
	return cached("sea_lamp", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 0.3, 0.16, 0.12, 8, NAVY)
		kit.cylinder(Vector3(0, 0.3, 0), 3.2, 0.06, 0.05, 6, WHITE)
		kit.cylinder(Vector3(0, 3.5, 0), 0.1, 0.12, 0.12, 6, NAVY)
		kit.use("glow")
		kit.sphere(Vector3(0, 3.82, 0), Vector3(0.24, 0.24, 0.24), GLASS, 3, 7)
		kit.use("solid")
		kit.cylinder(Vector3(0, 4.05, 0), 0.06, 0.1, 0.0, 6, NAVY)
		return kit.commit())


## A sand fence across the dunes: thin sticks with a wire, `length` metres along x.
static func sand_fence(length: float) -> Mesh:
	return cached("sand_fence_%d" % int(length), func() -> Mesh:
		var kit := MeshKit.new()
		var n := int(length / 0.18)
		for k in n:
			var x := -length * 0.5 + (k + 0.5) * length / n
			kit.box(Vector3(x, 0.4 + (k % 3) * 0.03, 0), Vector3(0.04, 0.8 + (k % 3) * 0.06, 0.03), DRIFT.lightened((k % 4) * 0.04))
		for y: float in [0.25, 0.65]:
			kit.box(Vector3(0, y, 0.02), Vector3(length, 0.015, 0.015), Color("6a6a6a"))
		return kit.commit())


## Marram grass on the dunes (a tall, pale tuft).
static func beach_grass(v: int) -> Mesh:
	return cached("beach_grass_%d" % v, func() -> Mesh:
		var rng := NatureModels.seeded_rng(v + 4400)
		var kit := MeshKit.new()
		kit.use("grass")
		var base := Color("a8b46a") if v % 2 == 0 else Color("98a85c")
		for i in 14:
			var a := rng.randf() * TAU
			var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.3)
			var h := rng.randf_range(0.5, 0.95)
			var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.1, 0.35)
			var side := Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)) * 0.03
			kit.tri(off - side, off + side, off + lean + Vector3(0, h, 0), base.lightened(rng.randf() * 0.2))
		return kit.commit())


## A granite rock of the point in the west: light grey with a darker, weathered foot.
static func rock(v: int) -> Mesh:
	return cached("rock_%d" % v, func() -> Mesh:
		var rng := NatureModels.seeded_rng(v + 4500)
		var kit := MeshKit.new()
		var col: Color = [Color("b3aa9c"), Color("a39a8c"), Color("bfb6a6"), Color("9c958a")][v % 4]
		kit.sphere(Vector3(0, 0.45, 0), Vector3(1.0, 0.75, 0.85), col, 3, 7, 0.28, rng.randi(), col.darkened(0.25))
		kit.sphere(Vector3(rng.randf_range(-0.4, 0.4), 0.9, rng.randf_range(-0.3, 0.3)), Vector3(0.55, 0.4, 0.5), col.lightened(0.05), 2, 6, 0.25, rng.randi())
		return kit.commit())


## A flat skipping stone, bright so it is seen in flight.
static func skipping_stone() -> Mesh:
	return cached("skipping_stone", func() -> Mesh:
		var kit := MeshKit.new()
		kit.sphere(Vector3.ZERO, Vector3(0.14, 0.04, 0.11), Color("d8d4cc"), 2, 8)
		return kit.commit())


## A fish roll (Fischbrötchen) on the counter: a bun, the herring, onion rings.
static func fish_roll() -> Mesh:
	return cached("fish_roll", func() -> Mesh:
		var kit := MeshKit.new()
		kit.sphere(Vector3(0, 0.06, 0), Vector3(0.18, 0.07, 0.09), Color("d9a55c"), 3, 8)
		kit.sphere(Vector3(0, 0.12, 0), Vector3(0.2, 0.03, 0.06), Color("b8c4cc"), 2, 8)
		kit.sphere(Vector3(0, 0.17, 0), Vector3(0.17, 0.05, 0.085), Color("e0b070"), 3, 8)
		for x: float in [-0.06, 0.05]:
			kit.torus(Vector3(x, 0.135, 0.06), 0.025, 0.006, 8, 3, Color("f0e8e0"))
		return kit.commit())


## A diving gull (wings spread, beak forward along -Z, as look_at points).
static func gull_mesh() -> Mesh:
	return cached("gull_mesh", func() -> Mesh:
		var kit := MeshKit.new()
		kit.sphere(Vector3.ZERO, Vector3(0.12, 0.11, 0.28), WHITE, 3, 8)
		kit.sphere(Vector3(0, 0.06, -0.26), Vector3(0.09, 0.09, 0.1), WHITE, 3, 7)
		kit.rod(Vector3(0, 0.05, -0.34), Vector3(0, 0.03, -0.46), 0.03, 0.01, 5, Color("f2c230"))
		for side: float in [-1.0, 1.0]:
			kit.quad(Vector3(side * 0.08, 0.02, -0.12), Vector3(side * 0.55, 0.12, -0.02), Vector3(side * 0.55, 0.12, 0.12), Vector3(side * 0.08, 0.02, 0.1), Color("9aa4ae"))
			kit.quad(Vector3(side * 0.08, 0.02, 0.1), Vector3(side * 0.55, 0.12, 0.12), Vector3(side * 0.55, 0.12, -0.02), Vector3(side * 0.08, 0.02, -0.12), Color("8a949e"))
			kit.box(Vector3(side * 0.56, 0.12, 0.05), Vector3(0.08, 0.02, 0.14), Color("2a2a30"))
			kit.sphere(Vector3(side * 0.05, 0.09, -0.32), Vector3(0.015, 0.015, 0.015), Color("1a1a1a"), 2, 4)
		kit.box(Vector3(0, 0.0, 0.3), Vector3(0.16, 0.03, 0.12), Color("e4e4e0"))
		return kit.commit())


## A seal lying on the sandbank.
static func seal(v: int) -> Mesh:
	return cached("seal_%d" % v, func() -> Mesh:
		var kit := MeshKit.new()
		var col: Color = [Color("7a7268"), Color("8e8578"), Color("5f5a52")][v % 3]
		kit.sphere(Vector3(0, 0.3, 0), Vector3(0.45, 0.32, 0.85), col, 4, 8)
		kit.sphere(Vector3(0, 0.3, -0.85), Vector3(0.22, 0.18, 0.4), col, 3, 6)
		kit.sphere(Vector3(0, 0.62, 0.8), Vector3(0.24, 0.24, 0.27), col.lightened(0.05), 3, 7)
		kit.sphere(Vector3(0, 0.58, 1.05), Vector3(0.12, 0.1, 0.08), col.lightened(0.15), 2, 5)
		for side: float in [-1.0, 1.0]:
			kit.sphere(Vector3(side * 0.12, 0.7, 1.0), Vector3(0.04, 0.04, 0.03), Color("15151a"), 2, 4)
			kit.push(Transform3D(Basis(Vector3.UP, side * 0.6), Vector3(side * 0.42, 0.12, 0.3)))
			kit.box(Vector3.ZERO, Vector3(0.12, 0.05, 0.4), col.darkened(0.15))
			kit.pop()
		for side: float in [-1.0, 1.0]:
			kit.push(Transform3D(Basis(Vector3.UP, side * 0.5), Vector3(side * 0.18, 0.15, -1.25)))
			kit.box(Vector3.ZERO, Vector3(0.28, 0.04, 0.3), col.darkened(0.15))
			kit.pop()
		return kit.commit())


## A sandcastle with a little flag.
static func sandcastle(v: int) -> Mesh:
	return cached("sandcastle_%d" % v, func() -> Mesh:
		var kit := MeshKit.new()
		var sand := Color("d9c08a")
		kit.cylinder(Vector3.ZERO, 0.25, 0.6, 0.55, 8, sand)
		for k in 4:
			var a := TAU * k / 4.0 + v * 0.3
			kit.cylinder(Vector3(cos(a) * 0.45, 0.2, sin(a) * 0.45), 0.35, 0.16, 0.13, 6, sand.lightened(0.05))
		kit.cylinder(Vector3(0, 0.25, 0), 0.55, 0.25, 0.2, 6, sand.lightened(0.08))
		kit.cylinder(Vector3(0, 0.8, 0), 0.4, 0.01, 0.01, 3, WOOD_DARK)
		kit.box(Vector3(0.08, 1.12, 0), Vector3(0.16, 0.1, 0.01), [RED, BLUE, Color("e8c02e")][v % 3])
		return kit.commit())


## A bucket and a spade on the sand.
static func bucket(v: int) -> Mesh:
	return cached("bucket_%d" % v, func() -> Mesh:
		var kit := MeshKit.new()
		var col: Color = [RED, BLUE, Color("e8c02e"), Color("2e9a6a")][v % 4]
		kit.cylinder(Vector3.ZERO, 0.22, 0.1, 0.13, 8, col)
		kit.torus(Vector3(0, 0.22, 0), 0.13, 0.012, 8, 3, col.darkened(0.2))
		kit.beam(Vector3(0.25, 0.0, 0.05), Vector3(0.45, 0.28, 0.1), Vector2(0.03, 0.03), col.darkened(0.1))
		kit.box(Vector3(0.22, 0.02, 0.04), Vector3(0.1, 0.02, 0.14), col.darkened(0.1))
		return kit.commit())


## The sign over the forecourt: two white posts and a board (letters from the builder).
static func sign_arch(width: float) -> Mesh:
	return cached("sign_arch_%d" % int(width * 10.0), func() -> Mesh:
		var kit := MeshKit.new()
		for x: float in [-width * 0.5, width * 0.5]:
			kit.cylinder(Vector3(x, 0, 0), 4.2, 0.14, 0.12, 8, WHITE)
			kit.sphere(Vector3(x, 4.3, 0), Vector3(0.18, 0.18, 0.18), BLUE, 2, 6)
		kit.box(Vector3(0, 3.65, 0), Vector3(width + 0.2, 0.9, 0.12), BLUE)
		kit.box(Vector3(0, 3.65, 0), Vector3(width - 0.1, 0.75, 0.16), NAVY)
		# Waves painted under the board.
		for k in 8:
			kit.box(Vector3(-width * 0.4 + k * width * 0.8 / 7.0, 3.1, 0), Vector3(0.4, 0.08, 0.1), WHITE)
		return kit.commit())


## The pier head's pavilion: eight white posts, a blue roof with a little tower.
static func pier_pavilion() -> Mesh:
	return cached("pier_pavilion", func() -> Mesh:
		var kit := MeshKit.new()
		var r := 3.2
		for k in 8:
			var a := TAU * k / 8.0
			kit.cylinder(Vector3(cos(a) * r, 0, sin(a) * r), 2.8, 0.09, 0.09, 6, WHITE)
		kit.cylinder(Vector3(0, 2.8, 0), 0.25, r + 0.4, r + 0.4, 8, WHITE)
		kit.cylinder(Vector3(0, 3.05, 0), 1.6, r + 0.5, 0.6, 8, BLUE, true, BLUE.darkened(0.3))
		kit.cylinder(Vector3(0, 4.65, 0), 0.7, 0.5, 0.5, 8, WHITE)
		kit.cylinder(Vector3(0, 5.35, 0), 0.6, 0.65, 0.0, 8, BLUE)
		kit.cylinder(Vector3(0, 5.9, 0), 0.8, 0.02, 0.02, 3, IRON)
		kit.box(Vector3(0.2, 6.55, 0), Vector3(0.4, 0.22, 0.01), RED)
		return kit.commit())


## A coin telescope on a post (the pier head).
static func telescope() -> Mesh:
	return cached("telescope", func() -> Mesh:
		var kit := MeshKit.new()
		kit.cylinder(Vector3.ZERO, 1.1, 0.1, 0.08, 6, IRON)
		kit.box(Vector3(0, 1.2, 0), Vector3(0.3, 0.25, 0.25), Color("3a6a8a"))
		kit.rod(Vector3(0, 1.32, -0.3), Vector3(0, 1.45, 0.45), 0.09, 0.12, 8, Color("3a6a8a"))
		for side: float in [-1.0, 1.0]:
			kit.rod(Vector3(side * 0.08, 1.4, -0.35), Vector3(side * 0.08, 1.38, -0.45), 0.04, 0.04, 5, IRON)
		return kit.commit())

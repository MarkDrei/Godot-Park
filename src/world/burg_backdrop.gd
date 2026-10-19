class_name BurgBackdrop
extends RefCounted
## The Ritterburg as seen from the Westpark and the Nordwald until it is loaded or while it
## sleeps (World.load_area, World.enter_area): the hill as a coarse mesh, the walls with their
## towers, the gate house, the lookout tower, the hall and the tavern, the stands of the lists,
## trees on the slopes and the gates. It invites the player up without costing the whole castle.

const STEP := 6.0


static func build(world: World) -> Node3D:
	var root := Node3D.new()
	root.name = "BurgBackdrop"
	var kit := MeshKit.new()
	var lo := ParkLayout.BURG_MIN
	var hi := ParkLayout.BURG_MAX
	# The hill, a little below the real ground (the real one covers it once loaded).
	var nx := int((hi.x - lo.x) / STEP)
	var nz := int((hi.y - lo.y) / STEP)
	var grass := Color("6d9a48")
	var castle := Color("8aa65e")
	for iz in nz:
		for ix in nx:
			var p00 := lo + Vector2(ix, iz) * STEP
			var p11 := p00 + Vector2(STEP, STEP)
			var v := func(p: Vector2) -> Vector3: return Vector3(p.x, BurgLayout.height(p) - 0.15, p.y)
			var mid := (p00 + p11) * 0.5
			var col := castle if BurgLayout.in_castle(mid, 2.0) else grass
			if absf(mid.y - BurgLayout.LISTS.y) < 10.0 and absf(mid.x - BurgLayout.LISTS.x) < 36.0:
				col = Color("d8c48a")
			kit.quad(v.call(p00), v.call(Vector2(p00.x, p11.y)), v.call(p11), v.call(Vector2(p11.x, p00.y)), col)
	kit.use("masonry")
	for seg: Array in BurgMap.walls():
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var d := b - a
		var n := maxi(1, int(ceil(d.length() / 6.0)))
		for k in n:
			var mid := a + d * (k + 0.5) / n
			var top := BurgLayout.height(mid + Vector2(-d.y, d.x).normalized() * 2.0) + 4.4
			top = maxf(top, BurgLayout.height(mid - Vector2(-d.y, d.x).normalized() * 2.0) + 4.4)
			kit.push(Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(mid.x, 0, mid.y)))
			kit.box(Vector3(0, (top - 1.0) * 0.5, 0), Vector3(d.length() / n + 0.05, top + 1.0, BurgLayout.WALL_THICK), BurgModels.STONE)
			kit.pop()
	var w := BurgLayout.WALL_W
	var e := BurgLayout.WALL_E
	# Everything else merged into the same mesh: one draw call per surface.
	for c: Vector2 in [Vector2(w, BurgLayout.WALL_S), Vector2(e, BurgLayout.WALL_S), Vector2(w, BurgLayout.INNER_Z),
			Vector2(e, BurgLayout.INNER_Z), Vector2(w, BurgLayout.ROCK_Z + 2.0), Vector2(e, BurgLayout.ROCK_Z + 2.0)]:
		var h := maxf(BurgLayout.height(c + Vector2(4, 4)), BurgLayout.height(c - Vector2(4, 4)))
		_add(kit, BurgModels.round_tower(3.4, h + 8.0 - BurgLayout.height(c)), c)
	_add(kit, BurgModels.gatehouse(BurgLayout.GATE_HALF * 2.0, 4.0), BurgLayout.place("gatehouse"))
	_add(kit, BurgModels.lookout_tower(), BurgLayout.place("tower"))
	_add(kit, BurgModels.hall(26.0, 11.0), BurgLayout.place("exhibition"))
	_add(kit, BurgModels.timber_house(16.0, 10.0, 5.0, BurgModels.ROOF), BurgLayout.place("tavern"))
	for side: float in [-1.0, 1.0]:
		var p := Vector2(BurgLayout.LISTS.x, BurgLayout.LISTS.y + side * (BurgLayout.LISTS_SIZE.y * 0.5 + 4.5))
		_add(kit, BurgModels.stand(40.0, BurgModels.RED if side > 0 else BurgModels.BLUE), p, PI if side > 0 else 0.0)
	_add(kit, BurgModels.border_gate(4.6), BurgLayout.GATE_SOUTH)
	_add(kit, BurgModels.border_gate(4.6), BurgLayout.GATE_EAST, PI / 2)
	kit.add_mesh(NatureModels.massif(Vector2(110, 26), 26.0, 21, 0.25), Transform3D(Basis(), Vector3(-262, 4.0, -292)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7070
	for i in 140:
		var p := Vector2(rng.randf_range(lo.x + 3, hi.x - 3), rng.randf_range(lo.y + 3, BurgLayout.WALL_S + 6.0))
		if BurgLayout.in_castle(p, -5.0) or p.y < BurgLayout.ROCK_Z - 2.0:
			continue
		var kind: String = ["fir", "pine", "oak", "birch"][rng.randi() % 4]
		var s := rng.randf_range(0.9, 1.2)
		kit.add_mesh(NatureModels.tree(kind, rng.randi() % int(NatureModels.TREES[kind]["variants"])),
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, BurgLayout.height(p) - 0.1, p.y)))
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = kit.commit()
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ground)
	world.burg_backdrop = root
	return root


static func _add(kit: MeshKit, mesh: Mesh, p: Vector2, yaw := 0.0) -> void:
	kit.add_mesh(mesh, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, BurgLayout.height(p), p.y)))

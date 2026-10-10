class_name ItemIcons
extends RefCounted
## Draws a small flat icon for every bag item into a rectangle of a Control
## (no textures needed; the UI font lacks most symbols).

const BARK := Color("8a5a34")
const BARK_END := Color("d9b07a")
const GREY := Color("9a958c")
const GREY_DARK := Color("6e6960")
const OUTLINE := Color(0, 0, 0, 0.35)


static func draw(c: CanvasItem, id: String, r: Rect2) -> void:
	var s := minf(r.size.x, r.size.y)
	var o := r.get_center()
	var u := s / 100.0   # icons are designed on a 100 × 100 grid around the centre
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * u
	match id:
		"bread":
			_round_rect(c, p.call(-34, -16), Vector2(68, 34) * u, Color("d9a55c"), 14 * u)
			for x: float in [-16, 0, 16]:
				c.draw_line(p.call(x - 4, -12), p.call(x + 4, 12), Color("a86f30"), 3 * u)
		"empty_bottle":
			_bottle(c, p, u, Color("4f9a6a"))
		"nut":
			c.draw_circle(p.call(0, 6), 24 * u, Color("a8743c"))
			_poly(c, [p.call(-24, 0), p.call(24, 0), p.call(18, -20), p.call(-18, -20)], Color("6b4a2a"))
			c.draw_line(p.call(0, -20), p.call(0, -30), Color("6b4a2a"), 4 * u)
		"invisible_key":
			var col := Color(1, 1, 1, 0.35)
			c.draw_arc(p.call(-18, 0), 14 * u, 0, TAU, 20, col, 4 * u)
			c.draw_line(p.call(-4, 0), p.call(32, 0), col, 4 * u)
			c.draw_line(p.call(22, 0), p.call(22, 12), col, 4 * u)
			c.draw_line(p.call(30, 0), p.call(30, 10), col, 4 * u)
		"twig":
			c.draw_line(p.call(-34, 26), p.call(30, -24), BARK, 7 * u)
			c.draw_line(p.call(-2, 2), p.call(-12, -24), BARK, 5 * u)
			c.draw_line(p.call(12, -10), p.call(30, -4), BARK, 4 * u)
			c.draw_circle(p.call(-12, -26), 6 * u, Color("6aa84f"))
		"log", "cherry_wood":
			var bark := BARK if id == "log" else Color("9a4a3a")
			var end := BARK_END if id == "log" else Color("d98a6a")
			_round_rect(c, p.call(-36, -16), Vector2(56, 32) * u, bark, 4 * u)
			c.draw_circle(p.call(20, 0), 17 * u, bark.darkened(0.2))
			c.draw_circle(p.call(20, 0), 14 * u, end)
			c.draw_arc(p.call(20, 0), 8 * u, 0, TAU, 14, bark, 2 * u)
		"board":
			_poly(c, [p.call(-38, 4), p.call(28, -22), p.call(38, -12), p.call(-28, 14)], Color("d2a36c"))
			c.draw_line(p.call(-30, 4), p.call(28, -18), Color("b07f48"), 2 * u)
		"stone":
			_poly(c, [p.call(-30, 14), p.call(-22, -14), p.call(4, -24), p.call(28, -8), p.call(30, 16), p.call(0, 24)], GREY)
			_poly(c, [p.call(-22, -14), p.call(4, -24), p.call(10, -6), p.call(-12, 0)], GREY.lightened(0.15))
		"slab":
			_poly(c, [p.call(-36, 6), p.call(-6, -18), p.call(36, -8), p.call(6, 16)], GREY.lightened(0.1))
			_poly(c, [p.call(-36, 6), p.call(6, 16), p.call(6, 24), p.call(-36, 14)], GREY_DARK)
			_poly(c, [p.call(6, 16), p.call(36, -8), p.call(36, 0), p.call(6, 24)], GREY)
		"ore":
			_poly(c, [p.call(-30, 14), p.call(-22, -14), p.call(4, -24), p.call(28, -8), p.call(30, 16), p.call(0, 24)], Color("7a6a5c"))
			for q: Vector2 in [Vector2(-10, -4), Vector2(8, 6), Vector2(14, -10), Vector2(-14, 12)]:
				c.draw_circle(p.call(q.x, q.y), 5 * u, Color("d8843a"))
		"gem":
			_poly(c, [p.call(-26, -8), p.call(-12, -24), p.call(12, -24), p.call(26, -8), p.call(0, 28)], Color("3fb8e8"))
			_poly(c, [p.call(-26, -8), p.call(26, -8), p.call(0, 28)], Color("2a8ac0"))
			c.draw_line(p.call(-12, -24), p.call(-4, -8), Color(1, 1, 1, 0.6), 2 * u)
		"berries":
			for q: Vector2 in [Vector2(-12, 8), Vector2(10, 10), Vector2(0, -8), Vector2(-2, 22)]:
				c.draw_circle(p.call(q.x, q.y), 12 * u, Color("6a2a8a"))
				c.draw_circle(p.call(q.x - 4, q.y - 4), 3 * u, Color(1, 1, 1, 0.5))
			_poly(c, [p.call(4, -22), p.call(28, -30), p.call(18, -14)], Color("4f8a3c"))
		"mushroom":
			_round_rect(c, p.call(-10, -6), Vector2(20, 34) * u, Color("efe6d2"), 5 * u)
			var cap := [p.call(-32, -2)]
			for i in 11:
				var a := PI + PI * i / 10.0
				cap.append(o + Vector2(cos(a) * 32, -2 + sin(a) * 28) * u)
			_poly(c, cap, Color("8a5a2a"))
		"apple", "baked_apple":
			var col := Color("d23a2a") if id == "apple" else Color("9a5a2a")
			c.draw_circle(p.call(-8, 6), 22 * u, col)
			c.draw_circle(p.call(8, 6), 22 * u, col)
			c.draw_line(p.call(0, -12), p.call(4, -28), Color("5a3a20"), 4 * u)
			_poly(c, [p.call(4, -24), p.call(24, -30), p.call(14, -16)], Color("4f8a3c"))
			if id == "baked_apple":
				c.draw_arc(p.call(0, 4), 12 * u, PI * 1.1, PI * 1.9, 8, Color("f2d080"), 4 * u)
		"fish", "grilled_fish":
			var col := Color("8ab0c8") if id == "fish" else Color("b07a3a")
			if id == "grilled_fish":
				c.draw_line(p.call(-40, 26), p.call(36, -14), Color("d8c9a0"), 4 * u)
			_ellipse(c, p.call(-2, 2), Vector2(28, 14) * u, col)
			_poly(c, [p.call(22, 2), p.call(40, -14), p.call(40, 18)], col.darkened(0.15))
			c.draw_circle(p.call(-18, -2), 3 * u, Color("1a1a1a"))
		"honey", "jam":
			var col := Color("f2b030") if id == "honey" else Color("8a2a5a")
			_round_rect(c, p.call(-22, -12), Vector2(44, 40) * u, col, 8 * u)
			_rect(c, p.call(-24, -24), Vector2(48, 12) * u, Color("e8e2d0") if id == "jam" else Color("c8a060"))
			_rect(c, p.call(-14, 0), Vector2(28, 14) * u, Color(1, 1, 1, 0.75))
		"dwarf_stew":
			c.draw_circle(p.call(0, 6), 30 * u, Color("3a3a3e"))
			c.draw_circle(p.call(0, 2), 25 * u, Color("8a4a2a"))
			for q: Vector2 in [Vector2(-10, -4), Vector2(8, 4), Vector2(-2, 10), Vector2(12, -8)]:
				c.draw_circle(p.call(q.x, q.y), 5 * u, [Color("d8b060"), Color("d23a2a")][int(q.x) % 2 & 1])
			c.draw_line(p.call(-36, -10), p.call(-26, -2), Color("3a3a3e"), 5 * u)
			c.draw_line(p.call(36, -10), p.call(26, -2), Color("3a3a3e"), 5 * u)
		"mushroom_pan":
			c.draw_line(p.call(20, 8), p.call(44, 22), Color("2a2a2e"), 7 * u)
			c.draw_circle(p.call(-6, 0), 30 * u, Color("2a2a2e"))
			c.draw_circle(p.call(-6, 0), 25 * u, Color("c8a060"))
			for q: Vector2 in [Vector2(-16, -8), Vector2(2, -10), Vector2(-8, 8), Vector2(8, 6)]:
				c.draw_circle(p.call(q.x, q.y), 6 * u, Color("8a5a2a"))
		"stone_axe", "iron_axe", "dwarf_axe":
			c.draw_line(p.call(-26, 34), p.call(14, -26), Color("a8743c"), 7 * u)
			var head: Color = {"stone_axe": GREY, "iron_axe": Color("b8bcc4"), "dwarf_axe": Color("e8c040")}[id]
			_poly(c, [p.call(4, -30), p.call(30, -34), p.call(34, -6), p.call(14, -10)], head)
		"stone_pickaxe", "iron_pickaxe", "dwarf_pickaxe":
			c.draw_line(p.call(-24, 34), p.call(10, -20), Color("a8743c"), 7 * u)
			var head2: Color = {"stone_pickaxe": GREY, "iron_pickaxe": Color("b8bcc4"), "dwarf_pickaxe": Color("e8c040")}[id]
			c.draw_arc(p.call(10, -2), 32 * u, -PI * 0.95, -PI * 0.15, 12, head2, 8 * u)
		"fishing_rod":
			c.draw_line(p.call(-34, 34), p.call(30, -34), Color("a8743c"), 4 * u)
			c.draw_line(p.call(30, -34), p.call(34, 20), Color(1, 1, 1, 0.7), 1.5 * u)
			c.draw_circle(p.call(-20, 18), 7 * u, Color("3a3a3e"))
			c.draw_circle(p.call(34, 22), 4 * u, Color("e8442e"))
		"big_bag":
			_round_rect(c, p.call(-26, -20), Vector2(52, 52) * u, Color("8a6a3a"), 10 * u)
			_round_rect(c, p.call(-18, 0), Vector2(36, 18) * u, Color("6e5230"), 5 * u)
			c.draw_arc(p.call(0, -20), 12 * u, PI, TAU, 10, Color("6e5230"), 5 * u)
		"birdhouse":
			_rect(c, p.call(-20, -6), Vector2(40, 36) * u, Color("d2a36c"))
			_poly(c, [p.call(-28, -6), p.call(0, -32), p.call(28, -6)], Color("8a3b2b"))
			c.draw_circle(p.call(0, 6), 7 * u, Color("3a2a1a"))
			c.draw_line(p.call(0, 18), p.call(0, 26), Color("6e4a2c"), 3 * u)
		"carving":
			_ellipse(c, p.call(0, 14), Vector2(16, 20) * u, Color("c8945c"))
			c.draw_circle(p.call(0, -14), 12 * u, Color("c8945c"))
			_ellipse(c, p.call(18, 4), Vector2(8, 22) * u, Color("b07f48"))
			c.draw_circle(p.call(-4, -16), 2 * u, Color("3a2a1a"))
		"stone_gnome":
			_ellipse(c, p.call(0, 16), Vector2(18, 16) * u, GREY)
			c.draw_circle(p.call(0, -2), 11 * u, GREY.lightened(0.15))
			_poly(c, [p.call(-14, -6), p.call(14, -6), p.call(0, -36)], GREY_DARK)
			_poly(c, [p.call(-8, 2), p.call(8, 2), p.call(0, 16)], Color("c4beb2"))
		"horn_duck", "horn_cucaracha", "horn_fanfare":
			var hc: Color = {"horn_duck": Color("f2c230"), "horn_cucaracha": Color("e8602e"), "horn_fanfare": Color("d8b040")}[id]
			_poly(c, [p.call(-30, -8), p.call(-6, -8), p.call(28, -26), p.call(28, 26), p.call(-6, 8), p.call(-30, 8)], hc)
			c.draw_circle(p.call(-32, 0), 10 * u, Color("2a2a2e"))
			c.draw_line(p.call(34, -16), p.call(42, -24), Color.WHITE, 3 * u)
			c.draw_line(p.call(36, 0), p.call(46, 0), Color.WHITE, 3 * u)
			c.draw_line(p.call(34, 16), p.call(42, 24), Color.WHITE, 3 * u)
		_:
			c.draw_circle(o, 26 * u, Color("8a8a8a"))


static func _poly(c: CanvasItem, pts: Array, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array(pts), col)


static func _rect(c: CanvasItem, pos: Vector2, size: Vector2, col: Color) -> void:
	if col.a > 0.0:
		c.draw_rect(Rect2(pos, size), col)


static func _round_rect(c: CanvasItem, pos: Vector2, size: Vector2, col: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	c.draw_style_box(sb, Rect2(pos, size))


static func _ellipse(c: CanvasItem, center: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	c.draw_colored_polygon(pts, col)


static func _bottle(c: CanvasItem, p: Callable, u: float, col: Color) -> void:
	_round_rect(c, p.call(-14, -10), Vector2(28, 44) * u, col, 8 * u)
	_rect(c, p.call(-6, -32), Vector2(12, 24) * u, col)
	_rect(c, p.call(-7, -36), Vector2(14, 6) * u, Color("d8d8d8"))
	_rect(c, p.call(-10, 4), Vector2(20, 12) * u, Color(1, 1, 1, 0.7))

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
		"teddy":
			c.draw_circle(p.call(0, 10), 22 * u, Color("a0703a"))
			c.draw_circle(p.call(0, -20), 16 * u, Color("a0703a"))
			c.draw_circle(p.call(-14, -32), 7 * u, Color("80582c"))
			c.draw_circle(p.call(14, -32), 7 * u, Color("80582c"))
			c.draw_circle(p.call(0, -16), 6 * u, Color("d9b48a"))
		"pocket_watch":
			c.draw_circle(p.call(0, 6), 26 * u, Color("c8a040"))
			c.draw_circle(p.call(0, 6), 21 * u, Color("f4eecb"))
			c.draw_line(p.call(0, 6), p.call(0, -10), Color("2a2a2e"), 3 * u)
			c.draw_line(p.call(0, 6), p.call(10, 10), Color("2a2a2e"), 3 * u)
			c.draw_circle(p.call(0, -24), 5 * u, Color("c8a040"))
		"hoppel":
			_ellipse(c, p.call(0, 12), Vector2(24, 18) * u, Color("f4f2ee"))
			c.draw_circle(p.call(10, -8), 13 * u, Color("f4f2ee"))
			_ellipse(c, p.call(4, -32), Vector2(5, 14) * u, Color("f4f2ee"))
			_ellipse(c, p.call(16, -32), Vector2(5, 14) * u, Color("f4f2ee"))
			c.draw_circle(p.call(16, -10), 2.5 * u, Color("2a2a2e"))
		"golden_duck":
			_ellipse(c, p.call(-4, 12), Vector2(26, 18) * u, Color("f0c040"))
			c.draw_circle(p.call(12, -12), 13 * u, Color("f0c040"))
			_poly(c, [p.call(22, -14), p.call(34, -10), p.call(22, -6)], Color("e67e22"))
			c.draw_circle(p.call(14, -16), 2.5 * u, Color("2a2a2e"))
		"vendor_tray":
			_round_rect(c, p.call(-32, -4), Vector2(64, 26) * u, Color("c0392b"), 6 * u)
			_rect(c, p.call(-28, -12), Vector2(56, 10) * u, Color("f2c230"))
			c.draw_line(p.call(-30, -6), p.call(-12, -34), Color("6e4a2c"), 3 * u)
			c.draw_line(p.call(30, -6), p.call(12, -34), Color("6e4a2c"), 3 * u)
			for k in 3:
				c.draw_circle(p.call(-16 + k * 16, -14), 6 * u, [Color("ffc0dd"), Color("8a5a2a"), Color("2e86de")][k])
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
		"plush_unicorn":
			var body := Color("f8f2f4")
			_ellipse(c, p.call(4, 14), Vector2(28, 18) * u, body)
			for x: float in [-14, 18]:
				_round_rect(c, p.call(x - 5, 22), Vector2(10, 16) * u, body, 4 * u)
			_ellipse(c, p.call(-20, -12), Vector2(17, 15) * u, body)
			_ellipse(c, p.call(-30, -6), Vector2(9, 7) * u, Color("f5c6d6"))
			_poly(c, [p.call(-24, -24), p.call(-14, -26), p.call(-24, -50)], Color("e8b830"))
			c.draw_line(p.call(-22, -30), p.call(-16, -32), Color("c8962a"), 2 * u)
			c.draw_line(p.call(-23, -38), p.call(-18, -40), Color("c8962a"), 2 * u)
			var mane := [Color("e8442e"), Color("f2a03d"), Color("f2d23d"), Color("6ac46a"), Color("5aa0e6"), Color("a070d8")]
			for i in mane.size():
				c.draw_circle(p.call(-8 + i * 3, -20 + i * 5), 6 * u, mane[i])
			c.draw_circle(p.call(-22, -14), 2.5 * u, Color("2a2a2e"))
			c.draw_line(p.call(32, 8), p.call(42, 20), Color("a070d8"), 5 * u)
			c.draw_line(p.call(32, 8), p.call(40, 26), Color("f2a03d"), 4 * u)
		"toy_car":
			var red := Color("d8463a")
			_round_rect(c, p.call(-38, -2), Vector2(76, 22) * u, red, 8 * u)
			_poly(c, [p.call(-20, -2), p.call(-12, -22), p.call(14, -22), p.call(24, -2)], red)
			_poly(c, [p.call(-15, -4), p.call(-9, -18), p.call(-1, -18), p.call(-1, -4)], Color("bfe0f2"))
			_poly(c, [p.call(3, -4), p.call(3, -18), p.call(11, -18), p.call(19, -4)], Color("bfe0f2"))
			_rect(c, p.call(30, 2), Vector2(8, 6) * u, Color("f8e08a"))
			for x: float in [-22, 22]:
				c.draw_circle(p.call(x, 22), 11 * u, Color("2a2a2e"))
				c.draw_circle(p.call(x, 22), 5 * u, Color("c8c8c8"))
		"troll_crown":
			var gold := Color("e0b030")
			_poly(c, [p.call(-30, 20), p.call(30, 20), p.call(34, -18), p.call(16, 0), p.call(0, -26), p.call(-16, 0), p.call(-34, -18)], gold)
			_rect(c, p.call(-30, 14), Vector2(60, 12) * u, Color("c09020"))
			for q: Vector2 in [Vector2(-34, -20), Vector2(0, -28), Vector2(34, -20)]:
				c.draw_circle(p.call(q.x, q.y), 5 * u, Color("e8442e"))
			c.draw_circle(p.call(0, 6), 5 * u, Color("3f7cc2"))
		"rusty_key":
			var rust := Color("a8602e")
			var dark := Color("6e3a1a")
			c.draw_circle(p.call(-22, 0), 20 * u, rust)
			c.draw_circle(p.call(-22, 0), 20 * u, dark, false, 3 * u)
			_rect(c, p.call(-4, -6), Vector2(42, 12) * u, rust)
			_rect(c, p.call(22, 6), Vector2(8, 16) * u, rust)
			_rect(c, p.call(32, 6), Vector2(6, 12) * u, rust)
			for q: Vector2 in [Vector2(6, -2), Vector2(18, 2), Vector2(30, -3)]:
				c.draw_circle(p.call(q.x, q.y), 2.5 * u, dark)
			# The tiny troll face on the bow.
			c.draw_circle(p.call(-22, 0), 11 * u, Color("7a9a5a"))
			c.draw_circle(p.call(-26, -3), 2 * u, Color("2a2a2e"))
			c.draw_circle(p.call(-18, -3), 2 * u, Color("2a2a2e"))
			c.draw_circle(p.call(-22, 2), 3 * u, Color("5e7a44"))
			c.draw_line(p.call(-27, 6), p.call(-17, 6), Color("2a2a2e"), 1.5 * u)
			_poly(c, [p.call(-31, -8), p.call(-36, -16), p.call(-28, -10)], Color("7a9a5a"))
			_poly(c, [p.call(-13, -8), p.call(-8, -16), p.call(-16, -10)], Color("7a9a5a"))
		"takeaway_hotdog":
			_round_rect(c, p.call(-38, -4), Vector2(76, 26) * u, Color("d9a55c"), 12 * u)
			_round_rect(c, p.call(-42, -12), Vector2(84, 14) * u, Color("b5523a"), 7 * u)
			for i in 6:
				var x := -30.0 + i * 12.0
				c.draw_line(p.call(x, -6), p.call(x + 6, -10), Color("f2c230"), 3 * u)
			_round_rect(c, p.call(-40, 8), Vector2(80, 16) * u, Color("f1eee6"), 4 * u)
		"takeaway_fries":
			for i in 6:
				var x := -18.0 + i * 7.0
				_rect(c, p.call(x, -32 + (i % 3) * 5), Vector2(5, 30) * u, Color("f2c230"))
			_poly(c, [p.call(-26, -6), p.call(26, -6), p.call(20, 30), p.call(-20, 30)], Color("d8463a"))
			_poly(c, [p.call(-8, 4), p.call(8, 4), p.call(6, 16), p.call(-6, 16)], Color("f1eee6"))
		"chamomile", "st_johns_wort", "lavender", "woodruff", "wild_garlic":
			# A little bunch: stems and the flowers or leaves of each herb.
			for x: float in [-14, 0, 14]:
				c.draw_line(p.call(x * 0.4, 30), p.call(x, -8), Color("4f8a3c"), 4 * u)
			match id:
				"chamomile", "st_johns_wort":
					var petal := Color("f4f2ec") if id == "chamomile" else Color("f2c230")
					for q: Vector2 in [Vector2(-14, -14), Vector2(0, -24), Vector2(14, -14)]:
						for k in 6:
							var a := TAU * k / 6.0
							c.draw_circle(p.call(q.x + cos(a) * 7, q.y + sin(a) * 7), 5 * u, petal)
						c.draw_circle(p.call(q.x, q.y), 4.5 * u, Color("f2b030") if id == "chamomile" else Color("d88a20"))
				"lavender":
					for x: float in [-14, 0, 14]:
						for k in 4:
							_ellipse(c, p.call(x, -12 - k * 7), Vector2(5, 4) * u, Color("8e6fe0").darkened(k * 0.05))
				"woodruff":
					for q: Vector2 in [Vector2(-14, -10), Vector2(0, -18), Vector2(14, -10)]:
						for k in 6:
							var a := TAU * k / 6.0
							_poly(c, [p.call(q.x, q.y), p.call(q.x + cos(a - 0.25) * 14, q.y + sin(a - 0.25) * 14),
								p.call(q.x + cos(a + 0.25) * 14, q.y + sin(a + 0.25) * 14)], Color("5f9c45"))
						c.draw_circle(p.call(q.x, q.y), 3 * u, Color("f4f2ec"))
				"wild_garlic":
					for x: float in [-14, 0, 14]:
						_ellipse(c, p.call(x, -16), Vector2(8, 22) * u, Color("4f9a3c"))
					c.draw_circle(p.call(0, -36), 5 * u, Color("f4f2ec"))
		"elder", "rose_hip":
			c.draw_line(p.call(-20, -26), p.call(16, 22), Color("6b4a32"), 4 * u)
			var pts := [Vector2(-8, -8), Vector2(4, -2), Vector2(-4, 6), Vector2(10, 8), Vector2(0, 16), Vector2(-14, 2), Vector2(8, -14)]
			var shown: Array = pts if id == "elder" else pts.slice(0, 4)
			for q: Vector2 in shown:
				if id == "elder":
					c.draw_circle(p.call(q.x, q.y), 6 * u, Color("2a1a3a"))
				else:
					_ellipse(c, p.call(q.x, q.y), Vector2(8, 11) * u, Color("d8462a"))
			_poly(c, [p.call(-20, -26), p.call(-36, -32), p.call(-28, -16)], Color("4f8a3c"))
		"potion_speed", "potion_herbs", "potion_mining":
			var col: Color = {"potion_speed": Color("4ab0e0"), "potion_herbs": Color("7ae05a"), "potion_mining": Color("e07a3a")}[id]
			c.draw_circle(p.call(0, 10), 26 * u, col)
			c.draw_circle(p.call(-8, 2), 7 * u, Color(1, 1, 1, 0.45))
			_rect(c, p.call(-8, -30), Vector2(16, 22) * u, col.lightened(0.35))
			_rect(c, p.call(-10, -36), Vector2(20, 8) * u, Color("8a5a34"))
		"morwen_staff", "star_staff":
			c.draw_line(p.call(-22, 34), p.call(14, -14), Color("6b4a32"), 7 * u)
			var star := Color("f2e27a") if id == "star_staff" else Color("8a8a8a")
			if id == "star_staff":
				c.draw_circle(p.call(18, -20), 22 * u, Color(1, 0.95, 0.5, 0.3))
			var pts := []
			for k in 10:
				var a := -PI / 2 + k * PI / 5
				var rad := 16.0 if k % 2 == 0 else 7.0
				pts.append(p.call(18 + cos(a) * rad, -20 + sin(a) * rad))
			_poly(c, pts, star)
		"star_splinter":
			_poly(c, [p.call(0, -30), p.call(12, 4), p.call(2, 30), p.call(-12, 0)], Color("f2e27a"))
			_poly(c, [p.call(0, -30), p.call(4, 0), p.call(-12, 0)], Color(1, 1, 1, 0.6))
		"morwen_letter", "hedwig_letter", "gisbert_letter":
			var paper: Color = {"morwen_letter": Color("e8dcb8"), "hedwig_letter": Color("f0e0f0"), "gisbert_letter": Color("e8f0ff")}[id]
			_rect(c, p.call(-30, -20), Vector2(60, 42) * u, paper)
			_poly(c, [p.call(-30, -20), p.call(30, -20), p.call(0, 4)], paper.darkened(0.15))
			c.draw_circle(p.call(0, 4), 7 * u, Color("b8322a") if id == "morwen_letter" else Color("8e6fe0"))
		"ghost_lantern", "hedwig_lantern":
			_rect(c, p.call(-16, -20), Vector2(32, 44) * u, Color("3a3a3e"))
			_rect(c, p.call(-12, -16), Vector2(24, 36) * u, Color("f2e27a") if id == "hedwig_lantern" else Color("8aa0b0"))
			c.draw_arc(p.call(0, -24), 10 * u, PI, TAU, 10, Color("3a3a3e"), 4 * u)
			if id == "hedwig_lantern":
				c.draw_circle(p.call(0, 2), 7 * u, Color("f4f0ff"))
		"kasper":
			_poly(c, [p.call(-16, -6), p.call(16, -6), p.call(-4, -38)], Color("d8322a"))
			c.draw_circle(p.call(-4, -38), 4 * u, Color("f2c230"))
			c.draw_circle(p.call(0, 6), 15 * u, Color("f0c8a0"))
			c.draw_circle(p.call(0, 8), 4 * u, Color("d8462a"))
			c.draw_arc(p.call(0, 10), 9 * u, 0.3, PI - 0.3, 8, Color("6a2a2a"), 2 * u)
			_rect(c, p.call(-18, 20), Vector2(36, 16) * u, Color("f2c230"))
		"horseshoe":
			c.draw_arc(p.call(0, 0), 26 * u, PI * 0.15, PI * 1.85, 20, Color("6e6960"), 12 * u)
			for k in 6:
				var a := PI * 0.3 + k * PI * 0.28
				c.draw_circle(p.call(cos(a + PI / 2) * 26, sin(a + PI / 2) * 26), 2.5 * u, Color("2a2a30"))
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

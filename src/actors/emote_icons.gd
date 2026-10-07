class_name EmoteIcons
extends RefCounted
## Small procedurally drawn billboard icons (no emoji font needed on web).

static var _cache := {}


static func get_icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match id:
		"sad":
			_face(img, Color("7ab8f0"), false)
		"happy":
			_face(img, Color("ffd34d"), true)
		"heart":
			_heart(img, Color("ff4f6d"))
		"note":
			_note(img, Color("ffffff"))
		"hungry":
			_disc(img, Vector2(32, 32), 26, Color("ffffff"))
			_ring(img, Vector2(32, 32), 26, 3, Color("5a3a1a"))
			for i in 3:
				_line(img, Vector2(20 + i * 12, 16), Vector2(20 + i * 12, 46), 3, Color("9a6a3e"))
		"angry":
			_face(img, Color("ff7a5a"), false)
			_line(img, Vector2(16, 18), Vector2(28, 24), 3, Color("3a1a1a"))
			_line(img, Vector2(48, 18), Vector2(36, 24), 3, Color("3a1a1a"))
		"idea":
			_disc(img, Vector2(32, 26), 18, Color("fff3a0"))
			_disc(img, Vector2(32, 50), 8, Color("aaaaaa"))
		"money":
			_disc(img, Vector2(32, 32), 24, Color("e8c040"))
			_ring(img, Vector2(32, 32), 24, 3, Color("a07a10"))
			_line(img, Vector2(26, 22), Vector2(38, 22), 3, Color("a07a10"))
			_line(img, Vector2(26, 42), Vector2(38, 42), 3, Color("a07a10"))
			_line(img, Vector2(26, 22), Vector2(26, 42), 3, Color("a07a10"))
		"star":
			_star(img, Color("ffe066"))
		"sweat":
			_disc(img, Vector2(32, 40), 14, Color("8fd0ff"))
			_line(img, Vector2(32, 14), Vector2(24, 34), 6, Color("8fd0ff"))
			_line(img, Vector2(32, 14), Vector2(40, 34), 6, Color("8fd0ff"))
		_:
			_disc(img, Vector2(32, 32), 20, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x, y).distance_to(c) <= r:
				img.set_pixel(x, y, col)


static func _ring(img: Image, c: Vector2, r: float, w: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x, y).distance_to(c)
			if d <= r and d >= r - w:
				img.set_pixel(x, y, col)


static func _line(img: Image, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var p := Vector2(x, y)
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= w * 0.5:
				img.set_pixel(x, y, col)


static func _face(img: Image, col: Color, happy: bool) -> void:
	_disc(img, Vector2(32, 32), 27, col)
	_ring(img, Vector2(32, 32), 27, 3, col.darkened(0.45))
	_disc(img, Vector2(23, 26), 3.5, Color("2a2a2a"))
	_disc(img, Vector2(41, 26), 3.5, Color("2a2a2a"))
	for i in 15:
		var t := float(i) / 14.0
		var x := lerpf(20, 44, t)
		var bend := sin(t * PI) * 7.0
		var y := 40.0 + bend if happy else 46.0 - bend
		_disc(img, Vector2(x, y), 1.8, Color("2a2a2a"))
	if not happy:
		_disc(img, Vector2(44, 34), 3.5, Color("e0f4ff"))


static func _heart(img: Image, col: Color) -> void:
	for y in 64:
		for x in 64:
			var u := (x - 32.0) / 26.0
			var v := (30.0 - y) / 26.0
			var f := pow(u * u + v * v - 0.5, 3.0) - u * u * v * v * v * 0.9
			if f <= 0.0:
				img.set_pixel(x, y, col)


static func _note(img: Image, col: Color) -> void:
	_disc(img, Vector2(22, 46), 9, col)
	_disc(img, Vector2(46, 40), 9, col)
	_line(img, Vector2(30, 46), Vector2(30, 12), 4, col)
	_line(img, Vector2(54, 40), Vector2(54, 8), 4, col)
	_line(img, Vector2(30, 12), Vector2(54, 8), 6, col)


static func _star(img: Image, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var r := 28.0 if i % 2 == 0 else 12.0
		pts.append(Vector2(32, 34) + Vector2(cos(a), sin(a)) * r)
	for y in 64:
		for x in 64:
			if Geometry2D.is_point_in_polygon(Vector2(x, y), pts):
				img.set_pixel(x, y, col)

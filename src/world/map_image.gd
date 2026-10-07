class_name MapImage
extends RefCounted
## Renders the park as a stylised map texture (used by the map screen and info boards).

const COLORS := {
	ParkMap.Ground.GRASS: Color("9cc77a"),
	ParkMap.Ground.PATH: Color("f3ead2"),
	ParkMap.Ground.GRAVEL: Color("e6d3a8"),
	ParkMap.Ground.SAND: Color("f0dc9c"),
	ParkMap.Ground.WATER: Color("6fb3d6"),
	ParkMap.Ground.BANK: Color("8fbf73"),
	ParkMap.Ground.PLAZA: Color("ddd4c3"),
	ParkMap.Ground.TRAIL: Color("d8c49a"),
	ParkMap.Ground.BRIDGE: Color("b0886a"),
	ParkMap.Ground.STONES: Color("8f8f8f"),
}

static var _texture: ImageTexture


## Texture with 2 px per metre. Trees are drawn as darker dots.
static func texture(map: ParkMap, trees: Array = []) -> ImageTexture:
	if _texture:
		return _texture
	var scale := 2
	var img := Image.create(ParkMap.W * scale, ParkMap.H * scale, false, Image.FORMAT_RGB8)
	for z in ParkMap.H:
		for x in ParkMap.W:
			var kind: int = map.ground[z * ParkMap.W + x]
			var col: Color = COLORS[kind]
			if kind == ParkMap.Ground.GRASS:
				var shade := 0.04 * sin(x * 0.3) * cos(z * 0.27)
				col = col.lightened(shade) if shade > 0 else col.darkened(-shade)
			img.fill_rect(Rect2i(x * scale, z * scale, scale, scale), col)
	for t: Dictionary in trees:
		var p: Vector2 = t["pos"] - ParkMap.ORIGIN
		var r := 2 if t["kind"] in ["fir", "pine"] else 3
		var col := Color("4f8a4a") if t["kind"] in ["fir", "pine"] else Color("6ea65a")
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dz * dz <= r * r:
					var px := int(p.x * scale) + dx
					var pz := int(p.y * scale) + dz
					if px >= 0 and pz >= 0 and px < img.get_width() and pz < img.get_height():
						img.set_pixel(px, pz, col)
	_texture = ImageTexture.create_from_image(img)
	return _texture


static func reset() -> void:
	_texture = null

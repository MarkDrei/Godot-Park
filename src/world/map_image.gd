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
	ParkMap.Ground.ROCK: Color("c4beb2"),
}

const SCALE := 2
## The two map views: city park and Nordwald (world rectangles in metres).
const PARK_VIEW := Rect2(-130, -90, 260, 180)
const FOREST_VIEW := Rect2(-130, -270, 260, 180)

static var _texture: ImageTexture


## Texture with 2 px per metre. Trees are drawn as darker dots.
static func texture(map: ParkMap, trees: Array = []) -> ImageTexture:
	if _texture:
		return _texture
	var scale := SCALE
	var img := Image.create(ParkMap.W * scale, ParkMap.H * scale, false, Image.FORMAT_RGB8)
	for z in ParkMap.H:
		for x in ParkMap.W:
			var kind: int = map.ground[z * ParkMap.W + x]
			var col: Color = COLORS[kind]
			if kind == ParkMap.Ground.GRASS and z + ParkMap.ORIGIN.y < ParkLayout.FOREST_EDGE:
				col = col.darkened(0.12)
			if kind == ParkMap.Ground.GRASS:
				var shade := 0.04 * sin(x * 0.3) * cos(z * 0.27)
				col = col.lightened(shade) if shade > 0 else col.darkened(-shade)
			img.fill_rect(Rect2i(x * scale, z * scale, scale, scale), col)
	# The dwarves' mountain (not walkable) as grey rock.
	var lo := ParkMap.to_cell(ParkLayout.MOUNTAIN_CENTER - ParkLayout.MOUNTAIN_RADII)
	var hi := ParkMap.to_cell(ParkLayout.MOUNTAIN_CENTER + ParkLayout.MOUNTAIN_RADII)
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var w := ParkMap.ORIGIN + Vector2(x + 0.5, z + 0.5)
			if Vegetation.in_mountain(w):
				var col := Color("b3aa9c") if Vegetation.in_mountain(w, -2.0) else Color("8c8476")
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


## Part of the map texture showing `view` (a world rectangle).
static func view_texture(map: ParkMap, view: Rect2, trees: Array = []) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = texture(map, trees)
	at.region = Rect2((view.position - ParkMap.ORIGIN) * SCALE, view.size * SCALE)
	return at


static func reset() -> void:
	_texture = null

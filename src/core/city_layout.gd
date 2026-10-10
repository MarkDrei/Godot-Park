class_name CityLayout
extends RefCounted
## Static design of the Oststadt (doc/oststadt.md): street grid, blocks, lots, places and
## houses. Coordinates like ParkLayout: Vector2(x, z) in metres, +x east, +z south.
## CityMap writes it into the ParkMap, CityBuilder builds the meshes from it.

const MIN := Vector2(130, -270)
const MAX := Vector2(390, 90)
const ROAD_HALF := 6.0          # two lanes of 3.5 m and two parking strips of 2.5 m
const LANE_OFFSET := 1.75       # centre of the right lane from the street axis
const LANE_EDGE := 3.5          # outer edge of the lanes (parking strip beyond)
const PARK_OFFSET := 4.75       # centre of the parking strip
const WALK := 3.0               # sidewalk width
const BLOCK_GAP := 9.0          # street axis to block edge
const BAY := 5.5                # length of a parking bay

## North–south streets (x) and east–west streets (z). The grid is closed: every street ends at
## another one, so cars never meet a dead end.
const X_STREETS := [
	{"id": "parkstrasse", "name": "Parkstraße", "x": 141.0},
	{"id": "hauptstrasse", "name": "Hauptstraße", "x": 210.0},
	{"id": "lindenstrasse", "name": "Lindenstraße", "x": 280.0},
	{"id": "ostring", "name": "Ostring", "x": 350.0},
]
const Z_STREETS := [
	{"id": "waldrandstrasse", "name": "Waldrandstraße", "z": -240.0},
	{"id": "forststrasse", "name": "Forststraße", "z": -160.0},
	{"id": "nordstrasse", "name": "Nordstraße", "z": -90.0},
	{"id": "parkallee", "name": "Parkallee", "z": -12.0},
	{"id": "suedring", "name": "Südring", "z": 60.0},
]
## Crossings with traffic lights (x, z); the others are plain crossings.
const LIGHTS := [Vector2(210, -90), Vector2(210, -12), Vector2(280, -90), Vector2(280, -12), Vector2(141, -12)]

## Special areas inside the blocks. rect: footprint; ground: lot (asphalt, drivable),
## plaza, grass or dirt (a lot with a dirt look). Driveways cross the sidewalk to a street.
const LOTS := {
	"cinema": {"rect": Rect2(150, -231, 51, 62), "ground": "lot", "name": "Autokino",
		"drives": [Rect2(171, -169, 9, 3)]},
	"karting": {"rect": Rect2(219, -231, 52, 62), "ground": "grass", "name": "Kartbahn",
		"drives": [Rect2(241, -169, 9, 3)]},
	"scrapyard": {"rect": Rect2(289, -231, 52, 62), "ground": "dirt", "name": "Schrottplatz",
		"drives": [Rect2(310, -169, 9, 3)]},
	"depot": {"rect": Rect2(359, -231, 31, 62), "ground": "lot", "name": "Betriebshof",
		"drives": [Rect2(356, -206, 3, 9)]},
	"petrol": {"rect": Rect2(150, -151, 51, 52), "ground": "lot", "name": "Tankstelle",
		"drives": [Rect2(168, -154, 10, 3), Rect2(168, -99, 10, 3)]},
	"garage": {"rect": Rect2(219, -151, 52, 52), "ground": "lot", "name": "Werkstatt",
		"drives": [Rect2(238, -99, 10, 3)]},
	"school": {"rect": Rect2(289, -151, 52, 52), "ground": "lot", "name": "Fahrschule",
		"drives": [Rect2(286, -137, 3, 10), Rect2(318, -99, 10, 3)]},
	"drive_in": {"rect": Rect2(150, -81, 51, 60), "ground": "lot", "name": "Drive-in „Zum Durchfahrer“",
		"drives": [Rect2(155, -84, 10, 3), Rect2(155, -21, 10, 3)]},
	"market": {"rect": Rect2(219, -66, 42, 30), "ground": "plaza", "name": "Marktplatz"},
	"church": {"rect": Rect2(289, -66, 52, 30), "ground": "grass", "name": "Kirche"},
	"taxi": {"rect": Rect2(163, -3, 38, 19), "ground": "lot", "name": "Taxi-Zentrale",
		"drives": [Rect2(178, -6, 10, 3)]},
	"egon": {"rect": Rect2(306, 69, 18, 21), "ground": "lot", "name": "Garage von Opa Egon",
		"drives": [Rect2(310, 66, 10, 3)]},
}

## Buildings of the lots (not houses): rect, height, roof colour.
const BUILDINGS := [
	{"id": "depot_hall", "rect": Rect2(362, -229, 26, 14), "h": 7.0, "color": Color("b8b2a6"), "roof": "flat"},
	{"id": "petrol_shop", "rect": Rect2(152, -136, 10, 16), "h": 4.0, "color": Color("f1eee6"), "roof": "flat"},
	{"id": "car_wash", "rect": Rect2(191, -137, 8, 20), "h": 4.6, "color": Color("3f7cc2"), "roof": "flat", "open_z": true},
	{"id": "garage_hall", "rect": Rect2(222, -149, 30, 14), "h": 6.5, "color": Color("c9c2b0"), "roof": "flat"},
	{"id": "school_office", "rect": Rect2(289, -113, 14, 14), "h": 6.4, "color": Color("e8d8a8"), "roof": "gable"},
	{"id": "drive_in", "rect": Rect2(166, -60, 16, 20), "h": 4.4, "color": Color("d8402e"), "roof": "flat", "band": Color("f2c230")},
	{"id": "scrap_office", "rect": Rect2(292, -183, 9, 5), "h": 2.8, "color": Color("6f8a6a"), "roof": "flat"},
	{"id": "kart_pits", "rect": Rect2(222, -182, 10, 8), "h": 3.2, "color": Color("e8e2d0"), "roof": "flat"},
	{"id": "taxi_office", "rect": Rect2(150, -3, 12, 12), "h": 6.4, "color": Color("f2d16b"), "roof": "gable"},
	{"id": "egon_garage", "rect": Rect2(324, 72, 10, 12), "h": 3.4, "color": Color("a85a3c"), "roof": "flat"},
	{"id": "church", "rect": Rect2(302, -60, 26, 12), "h": 9.5, "color": Color("e8e0cc"), "roof": "gable"},
	{"id": "church_tower", "rect": Rect2(296, -57, 6, 6), "h": 18.0, "color": Color("e8e0cc"), "roof": "spire"},
	{"id": "gelateria", "rect": Rect2(292, 38, 12, 10), "h": 6.4, "color": Color("f7c6d9"), "roof": "gable"},
]

## Kart track: closed centre line and width (inside the "karting" lot).
const TRACK := [Vector2(230, -188), Vector2(262, -188), Vector2(266, -192), Vector2(266, -200), Vector2(262, -204),
	Vector2(250, -206), Vector2(246, -210), Vector2(250, -214), Vector2(262, -216), Vector2(266, -220), Vector2(264, -226),
	Vector2(258, -228), Vector2(234, -228), Vector2(228, -226), Vector2(226, -220), Vector2(226, -196), Vector2(227, -191)]
const TRACK_WIDTH := 7.0
const KART_PIT := Rect2(233, -184, 14, 15)

## Named places (map labels, signposts, taxi destinations).
const PLACES := {
	"cinema": {"pos": Vector2(175, -200), "name": "Autokino"},
	"karting": {"pos": Vector2(245, -205), "name": "Kartbahn"},
	"scrapyard": {"pos": Vector2(315, -200), "name": "Schrottplatz"},
	"depot": {"pos": Vector2(375, -200), "name": "Betriebshof"},
	"petrol": {"pos": Vector2(176, -125), "name": "Tankstelle"},
	"garage": {"pos": Vector2(245, -125), "name": "Werkstatt"},
	"school": {"pos": Vector2(318, -130), "name": "Fahrschule"},
	"drive_in": {"pos": Vector2(175, -50), "name": "Drive-in"},
	"market": {"pos": Vector2(240, -51), "name": "Marktplatz"},
	"church": {"pos": Vector2(315, -51), "name": "Kirche"},
	"taxi": {"pos": Vector2(182, 6), "name": "Taxi-Zentrale"},
	"gelateria": {"pos": Vector2(298, 43), "name": "Gelateria"},
	"egon": {"pos": Vector2(315, 79), "name": "Opas Garage"},
}

## Lot sides that carry no houses (the block edge is the lot itself).
const HOUSE_COLORS := [Color("e8d8b8"), Color("d9b48f"), Color("c98f6f"), Color("e6c9a8"), Color("b5c4b1"), Color("c7d3dd"),
	Color("e8e0cc"), Color("d8a7a0"), Color("f0dca0"), Color("a9b9c9"), Color("d6c6e0"), Color("c9b48a")]
const ROOF_COLORS := [Color("8a3b2b"), Color("6b3e26"), Color("5a5a5e"), Color("7a4a3a"), Color("4a4a50")]

static var _houses: Array = []
static var _blocks: Array = []


static func x_of(street: Dictionary) -> float:
	return street["x"]


## All blocks: {id, rect}. Columns A–D from west to east, rows 0–5 from north to south.
static func blocks() -> Array:
	if not _blocks.is_empty():
		return _blocks
	var x_edges := []
	for i in X_STREETS.size():
		var x0: float = X_STREETS[i]["x"] + BLOCK_GAP
		var x1: float = X_STREETS[i + 1]["x"] - BLOCK_GAP if i + 1 < X_STREETS.size() else MAX.x
		x_edges.append([x0, x1])
	var z_edges := [[MIN.y, Z_STREETS[0]["z"] - BLOCK_GAP]]
	for i in Z_STREETS.size():
		var z0: float = Z_STREETS[i]["z"] + BLOCK_GAP
		var z1: float = Z_STREETS[i + 1]["z"] - BLOCK_GAP if i + 1 < Z_STREETS.size() else MAX.y
		z_edges.append([z0, z1])
	for r in z_edges.size():
		for c in x_edges.size():
			var x: Array = x_edges[c]
			var z: Array = z_edges[r]
			_blocks.append({"id": "%s%d" % ["ABCD"[c], r], "rect": Rect2(x[0], z[0], x[1] - x[0], z[1] - z[0])})
	return _blocks


## Road rectangles of the streets (lanes and parking strips), crossings included.
static func roads() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var zl: float = Z_STREETS[0]["z"] - ROAD_HALF
	var zh: float = Z_STREETS[-1]["z"] + ROAD_HALF
	var xl: float = X_STREETS[0]["x"] - ROAD_HALF
	var xh: float = X_STREETS[-1]["x"] + ROAD_HALF
	for s: Dictionary in X_STREETS:
		out.append(Rect2(s["x"] - ROAD_HALF, zl, ROAD_HALF * 2.0, zh - zl))
	for s: Dictionary in Z_STREETS:
		out.append(Rect2(xl, s["z"] - ROAD_HALF, xh - xl, ROAD_HALF * 2.0))
	return out


## Crossings: {pos, arms: [Vector2 directions that have a street], lights: bool}.
static func crossings() -> Array:
	var out := []
	for xs: Dictionary in X_STREETS:
		for zs: Dictionary in Z_STREETS:
			var p := Vector2(xs["x"], zs["z"])
			var arms: Array[Vector2] = []
			if p.x < X_STREETS[-1]["x"]:
				arms.append(Vector2.RIGHT)
			if p.x > X_STREETS[0]["x"]:
				arms.append(Vector2.LEFT)
			if p.y < Z_STREETS[-1]["z"]:
				arms.append(Vector2.DOWN)
			if p.y > Z_STREETS[0]["z"]:
				arms.append(Vector2.UP)
			out.append({"pos": p, "arms": arms, "lights": LIGHTS.has(p), "x_street": xs["name"], "z_street": zs["name"]})
	return out


## Crosswalk rectangles: on every arm of every crossing, in line with the sidewalks.
static func crosswalks() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c: Dictionary in crossings():
		var p: Vector2 = c["pos"]
		for arm: Vector2 in c["arms"]:
			if arm.x != 0.0:
				var x0 := p.x + ROAD_HALF if arm.x > 0 else p.x - ROAD_HALF - WALK
				out.append(Rect2(x0, p.y - ROAD_HALF, WALK, ROAD_HALF * 2.0))
			else:
				var z0 := p.y + ROAD_HALF if arm.y > 0 else p.y - ROAD_HALF - WALK
				out.append(Rect2(p.x - ROAD_HALF, z0, ROAD_HALF * 2.0, WALK))
	return out


## Name of the street nearest to p.
static func street_at(p: Vector2) -> String:
	var best := ""
	var best_d := INF
	for s: Dictionary in X_STREETS:
		var d := absf(p.x - s["x"])
		if d < best_d and p.y >= Z_STREETS[0]["z"] - 9.0 and p.y <= Z_STREETS[-1]["z"] + 9.0:
			best_d = d
			best = s["name"]
	for s: Dictionary in Z_STREETS:
		var d := absf(p.y - s["z"])
		if d < best_d and p.x >= X_STREETS[0]["x"] - 9.0 and p.x <= X_STREETS[-1]["x"] + 9.0:
			best_d = d
			best = s["name"]
	return best


static func lot_at(p: Vector2) -> String:
	for id: String in LOTS:
		if (LOTS[id]["rect"] as Rect2).has_point(p):
			return id
	return ""


## Houses along the streets: {id, rect, front (Vector2 direction to the street), door
## (Vector2 on the front path), curb (Vector2 on the parking strip in front), floors, h,
## roof ("gable"/"flat"), color, roof_color, street, number}. Deterministic.
static func houses() -> Array:
	if not _houses.is_empty():
		return _houses
	var rng := RandomNumberGenerator.new()
	rng.seed = 9090
	var taken: Array[Rect2] = []
	for id: String in LOTS:
		taken.append((LOTS[id]["rect"] as Rect2).grow(0.5))
	for b: Dictionary in BUILDINGS:
		taken.append((b["rect"] as Rect2).grow(0.5))
	var numbers := {}
	for blk: Dictionary in blocks():
		var r: Rect2 = blk["rect"]
		# Each block edge that faces a street (not the world edge): front direction outwards.
		var sides := []
		if r.position.y > MIN.y + 1.0:
			sides.append(Vector2.UP)
		if r.end.y < MAX.y - 1.0:
			sides.append(Vector2.DOWN)
		if r.position.x > MIN.x + 1.0:
			sides.append(Vector2.LEFT)
		if r.end.x < MAX.x - 1.0:
			sides.append(Vector2.RIGHT)
		for front: Vector2 in sides:
			var along := Vector2(absf(front.y), absf(front.x))   # unit vector along the edge
			var length := r.size.x if front.y != 0.0 else r.size.y
			var t := 1.0 + rng.randf_range(0.0, 2.0)
			while t < length - 7.0:
				var w := rng.randf_range(8.0, 13.0)
				if t + w > length - 0.5:
					w = length - 0.5 - t
				if w < 7.0:
					break
				var depth := rng.randf_range(8.0, 11.0)
				var setback := rng.randf_range(0.8, 2.6)
				var foot: Rect2
				if front == Vector2.UP:
					foot = Rect2(r.position.x + t, r.position.y + setback, w, depth)
				elif front == Vector2.DOWN:
					foot = Rect2(r.position.x + t, r.end.y - setback - depth, w, depth)
				elif front == Vector2.LEFT:
					foot = Rect2(r.position.x + setback, r.position.y + t, depth, w)
				else:
					foot = Rect2(r.end.x - setback - depth, r.position.y + t, depth, w)
				var free := true
				for q: Rect2 in taken:
					if q.intersects(foot.grow(0.3)):
						free = false
						break
				if free:
					taken.append(foot)
					var c := foot.get_center()
					var half := (foot.size.y if front.y != 0.0 else foot.size.x) * 0.5
					var door := c + front * (half + 0.7)
					var curb := _curb_point(c, front, r)
					var street := street_at(curb)
					numbers[street] = numbers.get(street, 0) + 1 + rng.randi() % 2
					var floors := 2 if rng.randf() < 0.55 else 3
					var roof := "gable" if (floors == 2 or rng.randf() < 0.15) and rng.randf() < 0.8 else "flat"
					if floors == 3:
						roof = "flat"
					var h := floors * 3.0 + (0.0 if roof == "flat" else 2.2)
					_houses.append({"id": "house_%d" % _houses.size(), "rect": foot, "front": front, "door": door, "curb": curb,
						"floors": floors, "h": h, "roof": roof, "color": HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()],
						"roof_color": ROOF_COLORS[rng.randi() % ROOF_COLORS.size()], "street": street, "number": numbers[street],
						"block": blk["id"]})
					t += w + rng.randf_range(0.0, 1.6)
				else:
					t += 2.0
	return _houses


## Point on the parking strip in front of a house (where a car stops for it).
static func _curb_point(c: Vector2, front: Vector2, block: Rect2) -> Vector2:
	if front == Vector2.UP:
		return Vector2(c.x, block.position.y - WALK - (ROAD_HALF - PARK_OFFSET))
	if front == Vector2.DOWN:
		return Vector2(c.x, block.end.y + WALK + (ROAD_HALF - PARK_OFFSET))
	if front == Vector2.LEFT:
		return Vector2(block.position.x - WALK - (ROAD_HALF - PARK_OFFSET), c.y)
	return Vector2(block.end.x + WALK + (ROAD_HALF - PARK_OFFSET), c.y)


static func house(id: String) -> Dictionary:
	for h: Dictionary in houses():
		if h["id"] == id:
			return h
	return {}


## Short German address of a house ("Lindenstraße 12").
static func address(h: Dictionary) -> String:
	return "%s %d" % [h["street"], h["number"]]


static func place(id: String) -> Vector2:
	return PLACES[id]["pos"]


static func place_name(id: String) -> String:
	return PLACES[id]["name"]


## Parking bays along the streets: [{pos, yaw}] centred on the parking strips, away from
## crossings and driveways. yaw: the car faces along the street in the lane direction.
static func parking_bays() -> Array:
	var out := []
	var drives: Array[Rect2] = []
	for id: String in LOTS:
		for d: Rect2 in LOTS[id].get("drives", []):
			drives.append(d.grow(1.5))
	var count := 0
	for s: Dictionary in X_STREETS:
		var x: float = s["x"]
		for side: float in [-1.0, 1.0]:
			# West side (side -1) belongs to the southbound lane: cars face +z (yaw 0).
			var yaw := 0.0 if side < 0 else PI
			var px := x + side * PARK_OFFSET
			if x == X_STREETS[0]["x"] and side < 0:
				continue   # no parking on the park side of the Parkstraße
			for i in range(Z_STREETS.size() - 1):
				var z0: float = Z_STREETS[i]["z"] + BLOCK_GAP + 4.0
				var z1: float = Z_STREETS[i + 1]["z"] - BLOCK_GAP - 4.0
				var z := z0 + BAY * 0.5
				while z < z1 - BAY * 0.5:
					var p := Vector2(px, z)
					if not drives.any(func(d: Rect2) -> bool: return d.has_point(p) or d.has_point(Vector2(x + side * 7.5, z))):
						count += 1
						out.append({"pos": p, "yaw": yaw, "street": s["name"], "tree": count % 6 == 3})
					z += BAY
	for s: Dictionary in Z_STREETS:
		var z: float = s["z"]
		for side: float in [-1.0, 1.0]:
			# North side (side -1) is the westbound lane: cars face -x (yaw -PI/2).
			var yaw := -PI / 2 if side < 0 else PI / 2
			var pz := z + side * PARK_OFFSET
			for i in range(X_STREETS.size() - 1):
				var x0: float = X_STREETS[i]["x"] + BLOCK_GAP + 4.0
				var x1: float = X_STREETS[i + 1]["x"] - BLOCK_GAP - 4.0
				var x := x0 + BAY * 0.5
				while x < x1 - BAY * 0.5:
					var p := Vector2(x, pz)
					if not drives.any(func(d: Rect2) -> bool: return d.has_point(p) or d.has_point(Vector2(x, z + side * 7.5))):
						count += 1
						out.append({"pos": p, "yaw": yaw, "street": s["name"], "tree": count % 6 == 3})
					x += BAY
	return out


## Random point on a sidewalk (for strolling city people).
static func random_sidewalk_point(rng: RandomNumberGenerator) -> Vector2:
	var mid := WALK * 0.5
	for i in 20:
		var blk: Dictionary = blocks()[rng.randi() % blocks().size()]
		var r: Rect2 = blk["rect"]
		var p: Vector2
		match rng.randi() % 4:
			0: p = Vector2(rng.randf_range(r.position.x, r.end.x), r.position.y - mid)
			1: p = Vector2(rng.randf_range(r.position.x, r.end.x), r.end.y + mid)
			2: p = Vector2(r.position.x - mid, rng.randf_range(r.position.y, r.end.y))
			_: p = Vector2(r.end.x + mid, rng.randf_range(r.position.y, r.end.y))
		if p.x > MIN.x + 2.0 and p.x < MAX.x - 2.0 and p.y > MIN.y + 2.0 and p.y < MAX.y - 2.0:
			return p
	return Vector2(X_STREETS[1]["x"] + ROAD_HALF + mid, -40.0)

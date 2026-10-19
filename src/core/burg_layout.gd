class_name BurgLayout
extends RefCounted
## Static design of the Ritterburg (doc/burg.md): the tournament ground in front of the walls,
## the market paths up the hill, the inner square and the knights' exhibition at the top.
## Coordinates are metres on the ground plane as Vector2(x, z), like ParkLayout; the area spans
## ParkLayout.BURG_MIN..BURG_MAX. North of the castle the hill runs into the mountain.

## The mountain reaches into the area from the north as a round front (an ellipse round
## MOUNT_C); nobody walks on it. The castle's outer wall is a polygon (OUTER): a straight south
## wall with the gate house, two slanting pieces at the lower corners, the sides, and to the
## north a bend into the rock, which closes the castle. The inner wall is an arc round INNER_C
## in front of the rock; behind it lies the top with the exhibition.
const MOUNT_C := Vector2(-265, -320)
const MOUNT_R := Vector2(175, 75)
const OUTER := [Vector2(-212, -248.5), Vector2(-198, -240), Vector2(-186, -225), Vector2(-182, -205), Vector2(-188, -166),
	Vector2(-220, -148), Vector2(-310, -148), Vector2(-342, -166), Vector2(-348, -205), Vector2(-344, -225),
	Vector2(-332, -240), Vector2(-318, -248.5)]
const INNER_C := Vector2(-265, -262)
const INNER_R := 34.0
const WALL_S := -148.0
const WALL_THICK := 2.4
## Heights: the inner square and the top (exhibition); the market's ramp from the gate house
## up to the square (z range).
const SQUARE_Y := 7.0
const TOP_Y := 9.0
const RAMP_Z := Vector2(-152.0, -192.0)
const GATE_HALF := 2.6          # half the opening of the gate house
const INNER_GATE_HALF := 2.2

## The joust lists (centre, size along x and z).
const LISTS := Vector2(-288, -118)
const LISTS_SIZE := Vector2(70, 12)
const PADDOCK := Vector2(-364, -112)
const PADDOCK_SIZE := Vector2(30, 24)

## Named places. `r` is the footprint radius kept free of trees.
const PLACES := {
	"lists": {"pos": LISTS, "r": 38.0, "name": "Turnierbahn"},
	"paddock": {"pos": PADDOCK, "r": 17.0, "name": "Koppel"},
	"stable": {"pos": Vector2(-374, -138), "r": 7.0, "name": "Stall"},
	"sword_ring": {"pos": Vector2(-214, -110), "r": 8.0, "name": "Schwertkampfring"},
	"betting": {"pos": Vector2(-224, -99), "r": 3.0, "name": "Wettbude"},
	"tug": {"pos": Vector2(-200, -136), "r": 7.0, "name": "Tauziehen"},
	"archery": {"pos": Vector2(-152, -104), "r": 4.0, "name": "Bogenstand"},
	"archery_targets": {"pos": Vector2(-152, -140), "r": 4.0, "name": "Zielscheiben"},
	"gatehouse": {"pos": Vector2(-265, WALL_S), "r": 6.0, "name": "Torhaus"},
	"tavern": {"pos": Vector2(-298, -154.8), "r": 8.0, "name": "Taverne"},
	"smithy": {"pos": Vector2(-232, -155.2), "r": 6.0, "name": "Schmiede"},
	"herb_witch": {"pos": Vector2(-333, -183), "r": 4.0, "name": "Kräuterhexe"},
	"alchemist": {"pos": Vector2(-197, -183), "r": 4.0, "name": "Alchemist"},
	"campfire": {"pos": Vector2(-304, -190), "r": 4.0, "name": "Lagerfeuer"},
	"dice": {"pos": Vector2(-238, -186), "r": 3.0, "name": "Würfeltisch"},
	"well": {"pos": Vector2(-265, -178), "r": 5.0, "name": "Marktbrunnen"},
	"square": {"pos": Vector2(-265, -208), "r": 16.0, "name": "Innenplatz"},
	"stage": {"pos": Vector2(-250, -219), "r": 4.0, "name": "Gauklerbühne"},
	"puppets": {"pos": Vector2(-241, -199), "r": 4.0, "name": "Puppentheater"},
	"magician": {"pos": Vector2(-290, -219), "r": 4.0, "name": "Magierecke"},
	"inner_gate": {"pos": Vector2(-265, -228), "r": 4.0, "name": "Inneres Tor"},
	"exhibition": {"pos": Vector2(-265, -239.5), "r": 9.0, "name": "Ritterausstellung"},
	"tower": {"pos": Vector2(-241, -235.5), "r": 4.0, "name": "Aussichtsturm"},
	"passage": {"pos": Vector2(-287, -244.8), "r": 2.0, "name": "Geheimgang"},
	"herb_slope": {"pos": Vector2(-368, -205), "r": 6.0, "name": "Kräuterhang"},
	"hedges": {"pos": Vector2(-160, -222), "r": 6.0, "name": "Hagebuttenhecken"},
	# Where the people of the castle come and go (outside the west fence).
	"gate_burg_w": {"pos": Vector2(-390, -126), "r": 4.0, "name": "Westpfad"},
}

## The gates into the castle area: from the Westpark in the south, from the Nordwald in the
## east (the forest's old "Waldweg" gate, ParkLayout gate_forest).
const GATE_SOUTH := Vector2(-260, -90)
const GATE_EAST := Vector2(-130, -200)

## Rectangular areas: centre, size, rotation (radians), ground kind (as ParkLayout.AREAS).
const AREAS := {
	"lists": {"pos": LISTS, "size": LISTS_SIZE + Vector2(6, 10), "rot": 0.0, "ground": "sand"},
	"paddock": {"pos": PADDOCK, "size": PADDOCK_SIZE, "rot": 0.0, "ground": "trail"},
	"stable": {"pos": Vector2(-374, -138), "size": Vector2(14, 8), "rot": 0.0, "ground": "gravel"},
	"archery": {"pos": Vector2(-152, -122), "size": Vector2(10, 42), "rot": 0.0, "ground": "grass"},
	"tug": {"pos": Vector2(-200, -136), "size": Vector2(16, 6), "rot": 0.0, "ground": "trail"},
	"tavern": {"pos": Vector2(-298, -159), "size": Vector2(18, 13), "rot": 0.0, "ground": "gravel"},
	"smithy": {"pos": Vector2(-232, -156), "size": Vector2(12, 9), "rot": 0.0, "ground": "gravel"},
	"top": {"pos": Vector2(-265, -239), "size": Vector2(70, 16), "rot": 0.0, "ground": "plaza"},
}

## Round plazas: centre, radius.
const PLAZAS := {
	"square": {"pos": Vector2(-265, -208), "r": 16.5},
	"sword_ring": {"pos": Vector2(-214, -110), "r": 7.0},
	"campfire": {"pos": Vector2(-304, -190), "r": 4.5},
	"well": {"pos": Vector2(-265, -178), "r": 5.5},
}

## Paths: control points, width and surface kind (as ParkLayout.PATHS); ids start with "burg_".
const PATHS := [
	# From the Westpark's gate round the east end of the lists to the gate house ...
	{"id": "burg_south", "kind": "main", "width": 4.0, "points": [
		Vector2(-260, -91), Vector2(-256, -99), Vector2(-246, -108), Vector2(-242, -124), Vector2(-250, -136),
		Vector2(-262, -142), Vector2(-265, -147)]},
	# ... from the Nordwald's gate down along the hedges.
	{"id": "burg_east", "kind": "main", "width": 3.6, "points": [
		Vector2(-131, -200), Vector2(-146, -188), Vector2(-168, -170), Vector2(-188, -150), Vector2(-210, -140),
		Vector2(-232, -134), Vector2(-246, -128)]},
	# Round the lists: the south stand, the paddock, the north stand.
	{"id": "burg_lists_s", "kind": "side", "width": 3.0, "points": [
		Vector2(-250, -102), Vector2(-280, -100), Vector2(-310, -100), Vector2(-334, -102), Vector2(-346, -108)]},
	{"id": "burg_lists_n", "kind": "side", "width": 3.0, "points": [
		Vector2(-246, -134), Vector2(-280, -137), Vector2(-312, -137), Vector2(-334, -132), Vector2(-346, -124)]},
	{"id": "burg_ring", "kind": "side", "width": 2.8, "points": [
		Vector2(-246, -108), Vector2(-232, -106), Vector2(-222, -106)]},
	{"id": "burg_archery", "kind": "side", "width": 2.6, "points": [
		Vector2(-206, -106), Vector2(-184, -102), Vector2(-164, -101), Vector2(-152, -100)]},
	{"id": "burg_tug", "kind": "trail", "width": 2.2, "points": [
		Vector2(-232, -134), Vector2(-214, -137), Vector2(-208, -137)]},
	{"id": "burg_west_gate", "kind": "trail", "width": 2.4, "points": [
		Vector2(-391, -126), Vector2(-382, -126), Vector2(-372, -124), Vector2(-358, -124), Vector2(-346, -124)]},
	# Inside the walls: from the gate house up the west and the east path to the inner square,
	# past the tavern and the smithy at the south wall.
	{"id": "burg_up_west", "kind": "main", "width": 3.2, "points": [
		Vector2(-265, -151), Vector2(-266, -160), Vector2(-276, -167), Vector2(-298, -168), Vector2(-318, -172),
		Vector2(-331, -185), Vector2(-327, -199), Vector2(-306, -207), Vector2(-282, -209)]},
	{"id": "burg_up_east", "kind": "main", "width": 3.2, "points": [
		Vector2(-265, -151), Vector2(-264, -160), Vector2(-254, -167), Vector2(-232, -168), Vector2(-212, -172),
		Vector2(-199, -185), Vector2(-203, -199), Vector2(-224, -207), Vector2(-248, -209)]},
	{"id": "burg_well", "kind": "side", "width": 2.6, "points": [
		Vector2(-265, -160), Vector2(-265, -173)]},
	{"id": "burg_campfire", "kind": "trail", "width": 2.0, "points": [
		Vector2(-322, -195), Vector2(-308, -191)]},
	# From the square through the inner gate to the exhibition, the tower and the rock.
	{"id": "burg_inner", "kind": "main", "width": 3.0, "points": [
		Vector2(-265, -223), Vector2(-265, -229), Vector2(-265, -233)]},
	{"id": "burg_top", "kind": "side", "width": 2.4, "points": [
		Vector2(-287, -242.5), Vector2(-283, -236), Vector2(-276, -233.2), Vector2(-265, -233), Vector2(-254, -233.2),
		Vector2(-246, -236), Vector2(-242, -238.6)]},
	# Trails outside the walls: the herb slope in the west, the hedges in the east.
	{"id": "burg_herbs", "kind": "trail", "width": 1.8, "points": [
		Vector2(-358, -124), Vector2(-364, -150), Vector2(-370, -180), Vector2(-369, -210), Vector2(-364, -238)]},
	{"id": "burg_hedges", "kind": "trail", "width": 1.8, "points": [
		Vector2(-158, -180), Vector2(-160, -200), Vector2(-163, -222), Vector2(-168, -242)]},
]

## Where the castle's people work (HumanBrain "burg:<id>" spots): [position, facing].
const POSTS := {
	"herb_witch": [Vector2(-333, -183), PI],
	"alchemist": [Vector2(-197, -183), PI],
	"tavern": [Vector2(-298, -160.4), PI],
	"smithy": [Vector2(-232.5, -156.2), PI],
	"dice": [Vector2(-238, -184.4), PI],
	"crier": [Vector2(-252, -162), PI * 0.8],
	"beggar": [Vector2(-273, -143), 0.0],
	"stage": [Vector2(-250, -219.5), 0.0],
	"puppets": [Vector2(-241, -200.5), 0.0],
	"magician": [Vector2(-290, -218.5), PI * 0.25],
	"exhibition": [Vector2(-258, -233.6), 0.0],
	"stable": [Vector2(-364, -97.5), 0.0],
	"betting": [Vector2(-224, -97.5), 0.0],
	"sword_ring": [Vector2(-214, -103.5), 0.0],
	"tug": [Vector2(-192, -136), PI / 2],
	"archery": [Vector2(-147, -104), 0.0],
	"lists_w": [Vector2(-326, -118), PI / 2],
	"lists_e": [Vector2(-250, -118), -PI / 2],
}


## Terrain height of the castle area: the tournament ground at the foot, the hill inside the
## walls rising to the inner square and the top, slopes outside the walls rising to the
## mountain, the mountain's rock steep; faded to street level along the borders with the
## Westpark and the Nordwald.
static func height(p: Vector2) -> float:
	var h := 0.18 * sin(p.x * 0.051 + 0.7) * cos(p.y * 0.072) + 0.1 * sin(p.x * 0.13 - p.y * 0.09) + 0.25
	var rock := mountain_depth(p)
	if in_castle(p):
		var ramp := SQUARE_Y * smoothstep(RAMP_Z.x, RAMP_Z.y, p.y)
		# Behind the inner wall's arc the top, a ramp through the inner gate.
		var d := p.distance_to(INNER_C) - INNER_R
		h += lerpf(TOP_Y, ramp, smoothstep(-3.0, 3.0, d))
		return h + maxf(rock, 0.0) * 1.6
	h += 6.5 * smoothstep(-150.0, -265.0, p.y)
	if rock > 0.0:
		h += rock * 1.6
	var lo := ParkLayout.BURG_MIN
	var hi := ParkLayout.BURG_MAX
	var edge := minf(minf((p.x - lo.x) / 12.0, (hi.x - p.x) / 16.0), (hi.y - p.y) / 6.0)
	return h * clampf(edge, 0.0, 1.0)


## How far (m, roughly) p lies inside the mountain's front; negative outside.
static func mountain_depth(p: Vector2) -> float:
	var q := (p - MOUNT_C) / MOUNT_R
	return (1.0 - q.length()) * MOUNT_R.y


static func in_mountain(p: Vector2, margin := 0.0) -> bool:
	return mountain_depth(p) > margin


## The castle's outline: OUTER closed along the mountain's front.
static func outline() -> PackedVector2Array:
	var pts := PackedVector2Array(OUTER)
	var a: Vector2 = OUTER[OUTER.size() - 1]
	var b: Vector2 = OUTER[0]
	for k in range(1, 12):
		var x := lerpf(a.x, b.x, k / 12.0)
		var dx := (x - MOUNT_C.x) / MOUNT_R.x
		pts.append(Vector2(x, MOUNT_C.y + MOUNT_R.y * sqrt(maxf(0.0, 1.0 - dx * dx)) - 1.0))
	return pts


static var _outline := PackedVector2Array()


## Inside the castle's walls (margin > 0: that far inside; < 0: also that close outside).
static func in_castle(p: Vector2, margin := 0.0) -> bool:
	if _outline.is_empty():
		_outline = outline()
	if p.x < -352.0 - maxf(-margin, 0.0) or p.x > -178.0 + maxf(-margin, 0.0) or p.y > WALL_S + maxf(-margin, 0.0):
		return false
	var inside := Geometry2D.is_point_in_polygon(p, _outline)
	if margin == 0.0:
		return inside
	var best := INF
	for i in _outline.size():
		var q := Geometry2D.get_closest_point_to_segment(p, _outline[i], _outline[(i + 1) % _outline.size()])
		best = minf(best, q.distance_to(p))
	return (inside and best >= margin) if margin > 0.0 else (inside or best < -margin)


static func path_polylines() -> Array:
	var result := []
	for p: Dictionary in PATHS:
		result.append({"id": p["id"], "kind": p["kind"], "width": p["width"], "points": ParkLayout.smooth(p["points"], 1.5),
			"closed": false})
	return result


static func place(id: String) -> Vector2:
	return PLACES[id]["pos"]


static func place_name(id: String) -> String:
	return PLACES[id]["name"]

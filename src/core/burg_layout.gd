class_name BurgLayout
extends RefCounted
## Static design of the Ritterburg (doc/burg.md): the tournament ground in front of the walls,
## the market paths up the hill, the inner square and the knights' exhibition at the top.
## Coordinates are metres on the ground plane as Vector2(x, z), like ParkLayout; the area spans
## ParkLayout.BURG_MIN..BURG_MAX. North of the castle the hill runs into the mountain.

## The outer wall: x from WALL_W to WALL_E, from WALL_S up to the rock face at ROCK_Z; the
## inner wall at INNER_Z separates the exhibition at the top.
const WALL_W := -345.0
const WALL_E := -185.0
const WALL_S := -152.0
const INNER_Z := -236.0
const ROCK_Z := -263.0
const WALL_THICK := 2.4
## Heights: the inner square, the top (exhibition) and the ramp between the market's foot and
## the square.
const SQUARE_Y := 7.0
const TOP_Y := 9.0
const RAMP_Z := Vector2(-156.0, -198.0)
const STEPS_Z := Vector2(-233.0, -241.0)
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
	"tavern": {"pos": Vector2(-265, -180), "r": 9.0, "name": "Taverne"},
	"smithy": {"pos": Vector2(-205, -162), "r": 6.0, "name": "Schmiede"},
	"herb_witch": {"pos": Vector2(-334, -181), "r": 4.0, "name": "Kräuterhexe"},
	"alchemist": {"pos": Vector2(-195, -184), "r": 4.0, "name": "Alchemist"},
	"campfire": {"pos": Vector2(-302, -190), "r": 4.0, "name": "Lagerfeuer"},
	"dice": {"pos": Vector2(-238, -189), "r": 3.0, "name": "Würfeltisch"},
	"square": {"pos": Vector2(-265, -214), "r": 18.0, "name": "Innenplatz"},
	"stage": {"pos": Vector2(-252, -228), "r": 4.0, "name": "Gauklerbühne"},
	"puppets": {"pos": Vector2(-240, -205), "r": 4.0, "name": "Puppentheater"},
	"magician": {"pos": Vector2(-292, -228), "r": 4.0, "name": "Magierecke"},
	"inner_gate": {"pos": Vector2(-265, INNER_Z), "r": 4.0, "name": "Inneres Tor"},
	"exhibition": {"pos": Vector2(-288, -252), "r": 12.0, "name": "Ritterausstellung"},
	"tower": {"pos": Vector2(-232, -251), "r": 5.0, "name": "Aussichtsturm"},
	"passage": {"pos": Vector2(-318, -259), "r": 2.0, "name": "Geheimgang"},
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
	"tavern": {"pos": Vector2(-265, -174), "size": Vector2(22, 16), "rot": 0.0, "ground": "gravel"},
	"smithy": {"pos": Vector2(-205, -162), "size": Vector2(12, 9), "rot": 0.0, "ground": "gravel"},
	"top": {"pos": Vector2(-265, -251), "size": Vector2(150, 20), "rot": 0.0, "ground": "plaza"},
}

## Round plazas: centre, radius.
const PLAZAS := {
	"square": {"pos": Vector2(-265, -214), "r": 19.0},
	"sword_ring": {"pos": Vector2(-214, -110), "r": 7.0},
	"campfire": {"pos": Vector2(-302, -190), "r": 4.5},
}

## Paths: control points, width and surface kind (as ParkLayout.PATHS); ids start with "burg_".
const PATHS := [
	# From the Westpark's gate round the east end of the lists to the gate house ...
	{"id": "burg_south", "kind": "main", "width": 4.0, "points": [
		Vector2(-260, -91), Vector2(-256, -99), Vector2(-246, -108), Vector2(-242, -124), Vector2(-250, -138),
		Vector2(-262, -146), Vector2(-265, -151)]},
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
	# and straight up to the tavern's terrace.
	{"id": "burg_up_west", "kind": "main", "width": 3.2, "points": [
		Vector2(-265, -155), Vector2(-277, -158), Vector2(-292, -161), Vector2(-310, -166), Vector2(-322, -175),
		Vector2(-325, -186), Vector2(-318, -196), Vector2(-304, -203), Vector2(-288, -207), Vector2(-280, -209)]},
	{"id": "burg_up_east", "kind": "main", "width": 3.2, "points": [
		Vector2(-265, -155), Vector2(-253, -158), Vector2(-238, -161), Vector2(-221, -166), Vector2(-209, -175),
		Vector2(-205, -186), Vector2(-212, -196), Vector2(-226, -203), Vector2(-242, -207), Vector2(-250, -209)]},
	{"id": "burg_terrace", "kind": "side", "width": 2.8, "points": [
		Vector2(-265, -156), Vector2(-265, -163)]},
	{"id": "burg_smithy", "kind": "side", "width": 2.4, "points": [
		Vector2(-221, -166), Vector2(-212, -164)]},
	{"id": "burg_campfire", "kind": "trail", "width": 2.0, "points": [
		Vector2(-314, -197), Vector2(-305, -192)]},
	# From the square through the inner gate to the exhibition and the tower.
	{"id": "burg_inner", "kind": "main", "width": 3.0, "points": [
		Vector2(-265, -231), Vector2(-265, -240), Vector2(-265, -246)]},
	{"id": "burg_top", "kind": "side", "width": 2.8, "points": [
		Vector2(-316, -256), Vector2(-300, -247), Vector2(-280, -245), Vector2(-265, -246), Vector2(-250, -246),
		Vector2(-238, -248)]},
	# Trails outside the walls: the herb slope in the west, the hedges in the east.
	{"id": "burg_herbs", "kind": "trail", "width": 1.8, "points": [
		Vector2(-358, -124), Vector2(-364, -150), Vector2(-370, -180), Vector2(-369, -210), Vector2(-362, -240)]},
	{"id": "burg_hedges", "kind": "trail", "width": 1.8, "points": [
		Vector2(-158, -180), Vector2(-160, -200), Vector2(-163, -222), Vector2(-170, -244)]},
]

## Where the castle's people work (HumanBrain "burg:<id>" spots): [position, facing].
const POSTS := {
	"smithy": [Vector2(-205, -158.5), PI],
	"herb_witch": [Vector2(-334, -178.5), PI],
	"alchemist": [Vector2(-195, -181.5), PI],
	"tavern": [Vector2(-265, -168.2), PI],
	"dice": [Vector2(-238, -187.4), PI],
	"crier": [Vector2(-251, -165), PI * 0.8],
	"beggar": [Vector2(-273, -146), 0.0],
	"stage": [Vector2(-252, -228.5), 0.0],
	"puppets": [Vector2(-240, -207.5), 0.0],
	"magician": [Vector2(-292, -227.5), PI * 0.25],
	"exhibition": [Vector2(-280, -244.5), 0.0],
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
## mountain; faded to street level along the borders with the Westpark and the Nordwald.
static func height(p: Vector2) -> float:
	var h := 0.18 * sin(p.x * 0.051 + 0.7) * cos(p.y * 0.072) + 0.1 * sin(p.x * 0.13 - p.y * 0.09) + 0.25
	if in_castle(p):
		if p.y > STEPS_Z.x:
			h += SQUARE_Y * smoothstep(RAMP_Z.x, RAMP_Z.y, p.y)
		elif p.y < STEPS_Z.y:
			h += TOP_Y
		else:
			h += lerpf(SQUARE_Y, TOP_Y, inverse_lerp(STEPS_Z.x, STEPS_Z.y, p.y))
		if p.y < ROCK_Z:
			h += (ROCK_Z - p.y) * 1.6
		return h
	# Outside: slopes up to the north, the rock behind the castle.
	var slope := 6.5 * smoothstep(-150.0, -265.0, p.y)
	if p.y < ROCK_Z and p.x > WALL_W - 6.0 and p.x < WALL_E + 6.0:
		slope += (ROCK_Z - p.y) * 1.6
	h += slope
	var lo := ParkLayout.BURG_MIN
	var hi := ParkLayout.BURG_MAX
	var edge := minf(minf((p.x - lo.x) / 12.0, (hi.x - p.x) / 16.0), (hi.y - p.y) / 6.0)
	return h * clampf(edge, 0.0, 1.0)


## Inside the outer wall (the castle's hill), up to the rock.
static func in_castle(p: Vector2, margin := 0.0) -> bool:
	return p.x > WALL_W + margin and p.x < WALL_E - margin and p.y < WALL_S - margin


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

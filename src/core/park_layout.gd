class_name ParkLayout
extends RefCounted
## Static design of the park: creek, pond, paths, plazas and points of interest.
## Coordinates are metres on the ground plane as Vector2(x, z); +x east, +z south.
## Everything else (terrain, navigation, decoration) is derived from this data.

const HALF := Vector2(130, 90)          # the city park extends from -HALF to +HALF
## The whole walkable world: the city park plus the Nordwald north of it (doc/nordwald.md).
const WORLD_MIN := Vector2(-130, -270)
const WORLD_MAX := Vector2(130, 90)
const FOREST_EDGE := -90.0               # z of the fence between park and Nordwald
const WATER_Y := -0.35                   # water surface height
const CREEK_HALF_WIDTH := 2.4
const BANK_WIDTH := 3.5

const POND_CENTER := Vector2(45, 6)
const POND_RADII := Vector2(20, 12)
const ISLAND_CENTER := Vector2(51, 2)
const ISLAND_RADIUS := 4.2
## Forest pond in the Nordwald, fed by a brook from the dwarves' mountain.
const FOREST_POND_CENTER := Vector2(-45, -224)
const FOREST_POND_RADII := Vector2(15, 9)
## Rock massif at the north edge (not walkable); the mine portal is on its south face.
const MOUNTAIN_CENTER := Vector2(78, -284)
const MOUNTAIN_RADII := Vector2(50, 32)

const CREEK_POINTS := [
	Vector2(-92, -50), Vector2(-80, -44), Vector2(-68, -39), Vector2(-56, -32), Vector2(-44, -25),
	Vector2(-30, -19), Vector2(-16, -11), Vector2(-2, -6), Vector2(12, -2), Vector2(26, 4),
]
const BROOK_POINTS := [
	Vector2(36, -258), Vector2(26, -250), Vector2(12, -243), Vector2(-2, -240), Vector2(-16, -236),
	Vector2(-28, -230), Vector2(-38, -226),
]
const CREEK_OUT_POINTS := [
	Vector2(64, 9), Vector2(78, 16), Vector2(90, 28), Vector2(98, 42), Vector2(106, 56),
	Vector2(116, 70), Vector2(126, 83), Vector2(134, 94),
]

## Named places. `r` is the footprint radius kept free of trees.
const PLACES := {
	"pavilion": {"pos": Vector2(-24, -52), "r": 11.0, "name": "Musikpavillon"},
	"fountain": {"pos": Vector2(-56, 18), "r": 12.0, "name": "Brunnenplatz"},
	"food_court": {"pos": Vector2(6, 48), "r": 13.0, "name": "Imbissplatz"},
	"donut_stand": {"pos": Vector2(-2, 41), "r": 3.0, "name": "Donut-Stand"},
	"kiosk": {"pos": Vector2(6, 58), "r": 4.0, "name": "Kiosk"},
	# Food stands spread over the park; `face` is the path point the counter faces.
	"hotdog_stand": {"pos": Vector2(-72, 19.5), "r": 5.0, "name": "Hot-Dog-Stand", "face": Vector2(-72, 14)},
	"icecream_cart": {"pos": Vector2(5, -50.5), "r": 5.0, "name": "Eiswagen", "face": Vector2(5, -54)},
	"fries_stand": {"pos": Vector2(91.4, 5.2), "r": 5.0, "name": "Pommesbude", "face": Vector2(88, 2)},
	# Snack machines by the west and east gates, open day and night.
	"vending_west": {"pos": Vector2(-118, 8.9), "r": 2.5, "name": "Snackautomat", "face": Vector2(-118, 5.8)},
	"vending_east": {"pos": Vector2(120, -7.5), "r": 2.5, "name": "Snackautomat", "face": Vector2(120, -10.7)},
	"playground": {"pos": Vector2(-38, 62), "r": 12.0, "name": "Spielplatz"},
	"minigolf": {"pos": Vector2(-90, 52), "r": 16.0, "name": "Minigolf"},
	"boule": {"pos": Vector2(-88, -16), "r": 10.0, "name": "Boule-Platz"},
	"chess": {"pos": Vector2(80, -24), "r": 9.0, "name": "Schachecke"},
	"shell_game": {"pos": Vector2(12, 78), "r": 3.0, "name": "Hütchenspieler"},
	"dog_meadow": {"pos": Vector2(62, 56), "r": 14.0, "name": "Hundewiese"},
	"great_meadow": {"pos": Vector2(32, -40), "r": 20.0, "name": "Große Wiese"},
	"picnic": {"pos": Vector2(-24, 30), "r": 10.0, "name": "Picknickwiese"},
	"sled_hill": {"pos": Vector2(92, -60), "r": 9.0, "name": "Rodelhügel"},
	"grotto": {"pos": Vector2(-96, -53), "r": 6.0, "name": "Quellgrotte"},
	"pier": {"pos": Vector2(40, 21), "r": 3.0, "name": "Bootssteg"},
	"statue": {"pos": Vector2(22, 26), "r": 3.0, "name": "Entendenkmal"},
	"island": {"pos": ISLAND_CENTER, "r": ISLAND_RADIUS, "name": "Teichinsel"},
	"gate_n": {"pos": Vector2(0, -90), "r": 4.0, "name": "Waldtor"},
	"gate_s": {"pos": Vector2(0, 90), "r": 4.0, "name": "Südtor"},
	"gate_w": {"pos": Vector2(-130, 5), "r": 4.0, "name": "Westtor"},
	"gate_e": {"pos": Vector2(130, -12), "r": 4.0, "name": "Osttor"},
	# Nordwald (doc/nordwald.md); park visitors never come here.
	"lumber_camp": {"pos": Vector2(-40, -160), "r": 14.0, "name": "Holzfällerlager", "forest": true},
	"sawmill": {"pos": Vector2(-72, -126), "r": 9.0, "name": "Sägewerk", "forest": true},
	"forest_inn": {"pos": Vector2(28, -152), "r": 12.0, "name": "Waldschänke", "forest": true},
	"forest_pond": {"pos": FOREST_POND_CENTER, "r": 4.0, "name": "Waldweiher", "forest": true},
	"berry_glade": {"pos": Vector2(2, -204), "r": 9.0, "name": "Beerenlichtung", "forest": true},
	"mushroom_glade": {"pos": Vector2(-96, -228), "r": 7.0, "name": "Pilzlichtung", "forest": true},
	"orchard": {"pos": Vector2(96, -140), "r": 15.0, "name": "Obstwiese", "forest": true},
	"quarry": {"pos": Vector2(62, -232), "r": 15.0, "name": "Steinbruch", "forest": true},
	"dwarf_office": {"pos": Vector2(34, -238), "r": 7.0, "name": "Zwergenkontor", "forest": true},
	"mine_portal": {"pos": Vector2(74, -254), "r": 6.0, "name": "Zwergenmine", "forest": true},
	"switch_tower": {"pos": Vector2(98, -240), "r": 6.0, "name": "Stellwerk", "forest": true},
	"gate_forest": {"pos": Vector2(-130, -200), "r": 4.0, "name": "Waldweg", "forest": true},
	"gate_forest_e": {"pos": Vector2(130, -160), "r": 4.0, "name": "Waldweg Ost", "forest": true},
	"farm_shop": {"pos": Vector2(9, -101), "r": 4.0, "name": "Hofladen", "forest": true, "face": Vector2(1, -103)},
}

## Rectangular areas: centre, size, rotation (radians), ground kind.
const AREAS := {
	"boule": {"pos": Vector2(-88, -16), "size": Vector2(18, 6), "rot": 0.0, "ground": "gravel"},
	"minigolf": {"pos": Vector2(-90, 52), "size": Vector2(28, 18), "rot": 0.0, "ground": "gravel"},
	"playground": {"pos": Vector2(-38, 62), "size": Vector2(20, 14), "rot": 0.0, "ground": "sand"},
	"dog_meadow": {"pos": Vector2(62, 56), "size": Vector2(26, 18), "rot": 0.0, "ground": "grass"},
	"chess": {"pos": Vector2(80, -24), "size": Vector2(14, 10), "rot": 0.0, "ground": "plaza"},
	"shell_game": {"pos": Vector2(12, 78), "size": Vector2(5, 4), "rot": 0.0, "ground": "plaza"},
	"lumber_camp": {"pos": Vector2(-40, -160), "size": Vector2(24, 18), "rot": 0.15, "ground": "dirt"},
	"sawmill": {"pos": Vector2(-72, -126), "size": Vector2(14, 10), "rot": 0.0, "ground": "dirt"},
	"forest_inn": {"pos": Vector2(28, -152), "size": Vector2(18, 14), "rot": 0.0, "ground": "gravel"},
	"quarry": {"pos": Vector2(62, -232), "size": Vector2(30, 20), "rot": -0.1, "ground": "rock"},
	"dwarf_office": {"pos": Vector2(34, -238), "size": Vector2(9, 7), "rot": 0.0, "ground": "gravel"},
}

## Round plazas: centre, radius.
const PLAZAS := {
	"fountain": {"pos": Vector2(-56, 18), "r": 10.0},
	"food_court": {"pos": Vector2(6, 48), "r": 10.0},
	"pavilion": {"pos": Vector2(-24, -52), "r": 9.0},
	"statue": {"pos": Vector2(22, 26), "r": 3.5},
}

## Open lawns where no trees are planted (centre, radii).
const MEADOWS := [
	{"pos": Vector2(32, -40), "radii": Vector2(26, 14)},
	{"pos": Vector2(-24, 30), "radii": Vector2(13, 9)},
	{"pos": Vector2(62, 56), "radii": Vector2(14, 10)},
	{"pos": Vector2(92, -60), "radii": Vector2(12, 12)},
	{"pos": Vector2(2, -204), "radii": Vector2(12, 9)},
	{"pos": Vector2(96, -140), "radii": Vector2(18, 14)},
	{"pos": Vector2(-96, -228), "radii": Vector2(8, 7)},
	{"pos": Vector2(18, -112), "radii": Vector2(14, 10)},
]

## Gentle hills: centre, height, sigma.
const HILLS := [
	{"pos": Vector2(92, -60), "h": 7.0, "s": 13.0},
	{"pos": Vector2(-72, -72), "h": 2.6, "s": 11.0},
	{"pos": Vector2(-108, 38), "h": 2.0, "s": 10.0},
	{"pos": Vector2(16, -70), "h": 1.6, "s": 14.0},
	{"pos": Vector2(102, 20), "h": 1.4, "s": 9.0},
	{"pos": Vector2(-60, 74), "h": 1.2, "s": 10.0},
	{"pos": Vector2(-92, -190), "h": 4.0, "s": 18.0},
	{"pos": Vector2(-10, -128), "h": 1.8, "s": 14.0},
	{"pos": Vector2(108, -195), "h": 3.2, "s": 14.0},
	{"pos": Vector2(60, -112), "h": 2.0, "s": 12.0},
	{"pos": Vector2(-70, -255), "h": 3.0, "s": 14.0},
	{"pos": Vector2(118, -250), "h": 4.0, "s": 12.0},
]

## Path definitions: control points, width and surface kind.
## kind: "main" (paved), "side" (gravel), "trail" (narrow dirt track).
const PATHS := [
	{"id": "ring", "kind": "main", "width": 3.6, "ring": true},
	{"id": "north", "kind": "main", "width": 4.0, "points": [
		Vector2(0, -92), Vector2(0, -78), Vector2(-7, -66), Vector2(-17, -58)]},
	{"id": "pavilion_center", "kind": "main", "width": 3.4, "points": [
		Vector2(-19, -45), Vector2(-15, -32), Vector2(-11, -19), Vector2(-7, -5), Vector2(-3, 9)]},
	{"id": "center_food", "kind": "main", "width": 3.4, "points": [
		Vector2(-3, 9), Vector2(1, 24), Vector2(4, 38)]},
	{"id": "food_south", "kind": "main", "width": 3.6, "points": [
		Vector2(5, 58), Vector2(3, 70), Vector2(0, 80), Vector2(0, 92)]},
	{"id": "west", "kind": "main", "width": 3.6, "points": [
		Vector2(-132, 5), Vector2(-114, 6), Vector2(-90, 11), Vector2(-66, 16)]},
	{"id": "fountain_center", "kind": "main", "width": 3.2, "points": [
		Vector2(-46, 16), Vector2(-26, 12), Vector2(-3, 9)]},
	{"id": "pond_south", "kind": "main", "width": 3.2, "points": [
		Vector2(-3, 9), Vector2(14, 17), Vector2(28, 22), Vector2(40, 25), Vector2(55, 23),
		Vector2(68, 17), Vector2(80, 8), Vector2(96, -4), Vector2(114, -10), Vector2(132, -12)]},
	{"id": "pond_north", "kind": "side", "width": 2.6, "points": [
		Vector2(-11, -19), Vector2(8, -15), Vector2(28, -14), Vector2(46, -13), Vector2(62, -9),
		Vector2(74, -1), Vector2(80, 8)]},
	{"id": "meadow_north", "kind": "side", "width": 2.8, "points": [
		Vector2(-17, -58), Vector2(-4, -52), Vector2(16, -58), Vector2(40, -60), Vector2(62, -54),
		Vector2(74, -40), Vector2(78, -30)]},
	{"id": "chess_east", "kind": "side", "width": 2.6, "points": [
		Vector2(80, -18), Vector2(86, -8), Vector2(96, -4)]},
	{"id": "boule_west", "kind": "side", "width": 2.6, "points": [
		Vector2(-66, 16), Vector2(-76, 4), Vector2(-84, -10)]},
	{"id": "boule_pavilion", "kind": "side", "width": 2.6, "points": [
		Vector2(-78, -20), Vector2(-66, -27), Vector2(-54, -36), Vector2(-42, -44), Vector2(-31, -50)]},
	{"id": "fountain_south", "kind": "side", "width": 2.8, "points": [
		Vector2(-56, 29), Vector2(-54, 40), Vector2(-46, 50), Vector2(-38, 54)]},
	{"id": "minigolf", "kind": "side", "width": 2.4, "points": [
		Vector2(-54, 40), Vector2(-66, 41), Vector2(-76, 42)]},
	{"id": "playground_food", "kind": "side", "width": 2.6, "points": [
		Vector2(-28, 56), Vector2(-14, 54), Vector2(-4, 50)]},
	{"id": "food_dogs", "kind": "side", "width": 2.6, "points": [
		Vector2(16, 50), Vector2(32, 53), Vector2(48, 55)]},
	{"id": "south_east", "kind": "side", "width": 2.6, "points": [
		Vector2(14, 57), Vector2(30, 66), Vector2(58, 70), Vector2(84, 66), Vector2(100, 58)]},
	{"id": "grotto_trail", "kind": "trail", "width": 1.6, "points": [
		Vector2(-90, -21), Vector2(-96, -32), Vector2(-99, -44), Vector2(-97, -50)]},
	{"id": "hill_trail", "kind": "trail", "width": 1.6, "points": [
		Vector2(66, -52), Vector2(78, -58), Vector2(88, -60)]},
	{"id": "statue", "kind": "side", "width": 2.0, "points": [
		Vector2(14, 17), Vector2(18, 22), Vector2(22, 26)]},
	{"id": "pier", "kind": "side", "width": 2.0, "points": [
		Vector2(40, 25), Vector2(40, 21.5)]},
	{"id": "picnic", "kind": "trail", "width": 1.6, "points": [
		Vector2(-12, 11), Vector2(-18, 22), Vector2(-24, 28)]},
	# Nordwald: gravel forest roads and dirt trails.
	{"id": "forest_main", "kind": "side", "width": 3.0, "points": [
		Vector2(0, -88), Vector2(1, -104), Vector2(-3, -120), Vector2(2, -138), Vector2(10, -156),
		Vector2(18, -176), Vector2(26, -198), Vector2(36, -218), Vector2(48, -228)]},
	{"id": "forest_camp", "kind": "side", "width": 2.6, "points": [
		Vector2(-3, -120), Vector2(-18, -134), Vector2(-30, -148), Vector2(-36, -156)]},
	{"id": "forest_sawmill", "kind": "side", "width": 2.6, "points": [
		Vector2(-18, -134), Vector2(-40, -136), Vector2(-62, -136), Vector2(-86, -142), Vector2(-104, -156),
		Vector2(-114, -178), Vector2(-122, -196), Vector2(-132, -200)]},
	{"id": "forest_inn", "kind": "side", "width": 2.4, "points": [
		Vector2(2, -138), Vector2(12, -146), Vector2(22, -150)]},
	{"id": "forest_east", "kind": "side", "width": 2.4, "points": [
		Vector2(18, -176), Vector2(42, -172), Vector2(66, -162), Vector2(84, -150), Vector2(92, -142)]},
	{"id": "camp_pond", "kind": "trail", "width": 1.6, "points": [
		Vector2(-46, -170), Vector2(-56, -186), Vector2(-58, -204), Vector2(-52, -214)]},
	{"id": "pond_glade", "kind": "trail", "width": 1.6, "points": [
		Vector2(-34, -216), Vector2(-20, -212), Vector2(-6, -206), Vector2(10, -202), Vector2(26, -198)]},
	{"id": "mushroom_trail", "kind": "trail", "width": 1.4, "points": [
		Vector2(-58, -206), Vector2(-74, -218), Vector2(-90, -226)]},
	{"id": "forest_east_gate", "kind": "trail", "width": 1.8, "points": [
		Vector2(92, -142), Vector2(108, -150), Vector2(120, -158), Vector2(132, -160)]},
	{"id": "orchard_quarry", "kind": "trail", "width": 1.6, "points": [
		Vector2(96, -148), Vector2(104, -172), Vector2(100, -204), Vector2(96, -232)]},
	{"id": "quarry_office", "kind": "side", "width": 2.4, "points": [
		Vector2(36, -218), Vector2(34, -232)]},
]

## Explicit walk structures over water (not auto-generated bridges).
const PIER := {"from": Vector2(40, 21.0), "to": Vector2(40, 12.5), "width": 2.4, "height": 0.25}
const STEPPING_STONES := [
	Vector2(46.5, -8.4), Vector2(47.6, -6.6), Vector2(48.4, -4.8), Vector2(49.4, -3.0), Vector2(50.0, -1.4),
]

## Bridges are found automatically where paths cross the creek; these anchors name them.
const BRIDGE_NAMES := [
	{"pos": Vector2(-8, -8), "name": "Steinbrücke"},
	{"pos": Vector2(-58, -33), "name": "Holzsteg"},
	{"pos": Vector2(73, 13), "name": "Entenbrücke"},
	{"pos": Vector2(105, 55), "name": "Ostbrücke"},
	{"pos": Vector2(0, -240), "name": "Bachsteg"},
]

const RING_RADII := Vector2(114, 76)
const RING_EXPONENT := 4.0


## Catmull-Rom smoothing; returns points spaced roughly `step` metres apart.
static func smooth(points: Array, step := 1.5, closed := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	if n < 2:
		for p: Vector2 in points:
			out.append(p)
		return out
	var count := n if closed else n - 1
	for i in count:
		var p0: Vector2 = points[(i - 1 + n) % n] if (closed or i > 0) else points[0]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[(i + 1) % n]
		var p3: Vector2 = points[(i + 2) % n] if (closed or i + 2 < n) else points[n - 1]
		var seg := maxi(1, int(ceil(p1.distance_to(p2) / step)))
		for s in seg:
			var t := float(s) / seg
			out.append(_catmull(p0, p1, p2, p3, t))
	if not closed:
		out.append(points[n - 1])
	return out


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


static func ring_points(samples := 96) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in samples:
		var a := TAU * i / samples
		var c := cos(a)
		var s := sin(a)
		pts.append(Vector2(RING_RADII.x * signf(c) * pow(absf(c), 2.0 / RING_EXPONENT),
			RING_RADII.y * signf(s) * pow(absf(s), 2.0 / RING_EXPONENT)))
	return pts


static func creek_polyline() -> PackedVector2Array:
	return smooth(CREEK_POINTS, 1.5)


static func creek_out_polyline() -> PackedVector2Array:
	return smooth(CREEK_OUT_POINTS, 1.5)


static func brook_polyline() -> PackedVector2Array:
	return smooth(BROOK_POINTS, 1.5)


## Ponds as [centre, radii]; the first is the city pond with the island.
static func ponds() -> Array:
	return [[POND_CENTER, POND_RADII], [FOREST_POND_CENTER, FOREST_POND_RADII]]


static func in_forest(p: Vector2) -> bool:
	return p.y < FOREST_EDGE


static func is_forest_place(id: String) -> bool:
	return PLACES[id].get("forest", false)


## All paths as smoothed polylines: [{id, kind, width, points: PackedVector2Array, closed}]
static func path_polylines() -> Array:
	var result := []
	for p: Dictionary in PATHS:
		var pts: PackedVector2Array
		var closed := false
		if p.get("ring", false):
			pts = smooth(Array(ring_points(48)), 2.0, true)
			closed = true
		else:
			pts = smooth(p["points"], 1.5)
		result.append({"id": p["id"], "kind": p["kind"], "width": p["width"], "points": pts, "closed": closed})
	return result


static func place(id: String) -> Vector2:
	return PLACES[id]["pos"]


static func place_name(id: String) -> String:
	return PLACES[id]["name"]

class_name FairLayout
extends RefCounted
## Static design of the Westpark with the Kirmes (doc/kirmes.md): pond, paths, plazas, rides,
## booths and oases. Coordinates are metres on the ground plane as Vector2(x, z), like
## ParkLayout; the Westpark spans ParkLayout.FAIR_MIN..FAIR_MAX.

## The rides, booths and machines open at 10:00 and run until midnight.
const OPENS := 10.0

const POND_CENTER := Vector2(-160, -54)
const POND_RADII := Vector2(15, 9)

## Named places. `r` is the footprint radius kept free of trees.
const PLACES := {
	"fest_square": {"pos": Vector2(-264, 0), "r": 24.0, "name": "Festplatz"},
	"ferris_wheel": {"pos": Vector2(-264, -8), "r": 14.0, "name": "Riesenrad"},
	"booth_street": {"pos": Vector2(-210, 3), "r": 8.0, "name": "Budenmeile"},
	"bumper_cars": {"pos": Vector2(-338, 4), "r": 17.0, "name": "Autoscooter"},
	"coaster": {"pos": Vector2(-344, -64), "r": 24.0, "name": "Achterbahn"},
	"ghost_train": {"pos": Vector2(-286, -64), "r": 15.0, "name": "Geisterbahn"},
	"arcade": {"pos": Vector2(-236, -64), "r": 14.0, "name": "Spielhalle"},
	"prize_counter": {"pos": Vector2(-206, -52), "r": 4.0, "name": "Gewinnausgabe"},
	"chain_swing": {"pos": Vector2(-318, -22), "r": 10.0, "name": "Kettenkarussell"},
	"carousel": {"pos": Vector2(-300, 24), "r": 8.0, "name": "Karussell"},
	"swing_boat": {"pos": Vector2(-292, 62), "r": 9.0, "name": "Schiffschaukel"},
	"high_striker": {"pos": Vector2(-246, 22), "r": 3.0, "name": "Hau den Lukas"},
	"food_court": {"pos": Vector2(-236, 60), "r": 13.0, "name": "Schlemmergasse"},
	"magic_stage": {"pos": Vector2(-188, 66), "r": 8.0, "name": "Zauberbühne"},
	"fortune_teller": {"pos": Vector2(-366, 72), "r": 5.0, "name": "Wahrsagerin"},
	"pond": {"pos": POND_CENTER, "r": 4.0, "name": "Seerosenteich"},
	"meadow": {"pos": Vector2(-160, 18), "r": 6.0, "name": "Festwiese"},
	# Oases of rest (doc/kirmes.md): benches, quiet music; sitting there rests faster.
	"oasis_lights": {"pos": Vector2(-160, 54), "r": 8.0, "name": "Lichtergarten", "oasis": true},
	"oasis_pond": {"pos": Vector2(-160, -42), "r": 2.5, "name": "Teichufer", "oasis": true},
	"oasis_limes": {"pos": Vector2(-330, 78), "r": 7.0, "name": "Lindenhain", "oasis": true},
	"oasis_roses": {"pos": Vector2(-190, -76), "r": 6.0, "name": "Rosenlaube", "oasis": true},
	"oasis_wheel": {"pos": Vector2(-275, 13), "r": 5.0, "name": "Bankrunde am Riesenrad", "oasis": true},
	# Where the people of the Westpark come and go (outside the fence).
	"gate_fair_w": {"pos": Vector2(-390, 2), "r": 4.0, "name": "Westpforte"},
	"gate_fair_s": {"pos": Vector2(-300, 90), "r": 4.0, "name": "Südpforte"},
}

## Rectangular areas: centre, size, rotation (radians), ground kind (as ParkLayout.AREAS).
const AREAS := {
	"booth_street": {"pos": Vector2(-210, 3), "size": Vector2(60, 10), "rot": 0.0, "ground": "plaza"},
	"bumper_cars": {"pos": Vector2(-338, 4), "size": Vector2(30, 22), "rot": 0.0, "ground": "plaza"},
	"coaster": {"pos": Vector2(-344, -64), "size": Vector2(56, 30), "rot": 0.0, "ground": "grass"},
	"ghost_train": {"pos": Vector2(-286, -63), "size": Vector2(30, 20), "rot": 0.0, "ground": "gravel"},
	"arcade": {"pos": Vector2(-236, -63), "size": Vector2(28, 20), "rot": 0.0, "ground": "plaza"},
	"food_court": {"pos": Vector2(-236, 60), "size": Vector2(30, 18), "rot": 0.0, "ground": "gravel"},
	"swing_boat": {"pos": Vector2(-292, 62), "size": Vector2(16, 12), "rot": 0.0, "ground": "gravel"},
	"magic_stage": {"pos": Vector2(-188, 66), "size": Vector2(16, 14), "rot": 0.0, "ground": "gravel"},
}

## Round plazas: centre, radius.
const PLAZAS := {
	"fest_square": {"pos": Vector2(-264, 0), "r": 22.0},
	"chain_swing": {"pos": Vector2(-318, -22), "r": 10.0},
	"carousel": {"pos": Vector2(-300, 24), "r": 8.5},
	"oasis_lights": {"pos": Vector2(-160, 54), "r": 7.0},
}

## Open lawns where no trees are planted (centre, radii).
const MEADOWS := [
	{"pos": Vector2(-160, 18), "radii": Vector2(20, 13)},
	{"pos": Vector2(-206, -26), "radii": Vector2(12, 8)},
	{"pos": Vector2(-338, 40), "radii": Vector2(14, 8)},
]

## Gentle hills: centre, height, sigma.
const HILLS := [
	{"pos": Vector2(-366, 70), "h": 1.6, "s": 10.0},
	{"pos": Vector2(-150, -10), "h": 1.2, "s": 12.0},
	{"pos": Vector2(-200, 76), "h": 1.0, "s": 9.0},
	{"pos": Vector2(-376, -30), "h": 1.4, "s": 10.0},
]

## Paths: control points, width and surface kind (as ParkLayout.PATHS).
const PATHS := [
	# From the park's Westtor along the meadow into the booth street ...
	{"id": "fair_main", "kind": "main", "width": 4.4, "points": [
		Vector2(-132, 5), Vector2(-146, 6), Vector2(-160, 4), Vector2(-172, 3), Vector2(-182, 3)]},
	# ... through it onto the Festplatz, and on to the bumper cars.
	{"id": "fair_west", "kind": "main", "width": 4.0, "points": [
		Vector2(-286, 3), Vector2(-300, 4), Vector2(-322, 4)]},
	{"id": "fair_north_arm", "kind": "main", "width": 3.6, "points": [
		Vector2(-264, -21), Vector2(-266, -32), Vector2(-268, -40)]},
	{"id": "fair_south_arm", "kind": "main", "width": 3.6, "points": [
		Vector2(-264, 21), Vector2(-264, 32), Vector2(-266, 40)]},
	# The promenade around the fair: north row, east and south rows, west link.
	{"id": "fair_north", "kind": "side", "width": 3.2, "points": [
		Vector2(-366, -44), Vector2(-340, -46), Vector2(-310, -44), Vector2(-286, -48), Vector2(-268, -40),
		Vector2(-248, -48), Vector2(-226, -48), Vector2(-206, -46), Vector2(-190, -40), Vector2(-182, -28),
		Vector2(-178, -14), Vector2(-174, 1)]},
	{"id": "fair_south", "kind": "side", "width": 3.2, "points": [
		Vector2(-366, 40), Vector2(-344, 46), Vector2(-318, 44), Vector2(-292, 46), Vector2(-266, 40),
		Vector2(-246, 46), Vector2(-222, 46), Vector2(-204, 46), Vector2(-190, 40), Vector2(-182, 28),
		Vector2(-178, 16), Vector2(-174, 5)]},
	{"id": "fair_west_link", "kind": "side", "width": 3.2, "points": [
		Vector2(-366, -44), Vector2(-374, -26), Vector2(-376, -6), Vector2(-374, 16), Vector2(-370, 30),
		Vector2(-366, 40)]},
	{"id": "fair_west_gate", "kind": "side", "width": 3.0, "points": [
		Vector2(-392, 2), Vector2(-384, 2), Vector2(-376, 0)]},
	{"id": "fair_south_gate", "kind": "side", "width": 3.0, "points": [
		Vector2(-300, 92), Vector2(-300, 80), Vector2(-302, 70), Vector2(-302, 58), Vector2(-297, 48)]},
	# North between the ghost train and the arcade to the gate of the Ritterburg.
	{"id": "fair_burg", "kind": "side", "width": 3.0, "points": [
		Vector2(-266, -46), Vector2(-262, -60), Vector2(-260, -76), Vector2(-260, -89)]},
	{"id": "fair_bumper_north", "kind": "side", "width": 2.6, "points": [
		Vector2(-340, -46), Vector2(-338, -28), Vector2(-338, -8)]},
	# East: the pond loop and the light garden.
	{"id": "fair_pond", "kind": "side", "width": 2.8, "points": [
		Vector2(-148, 6), Vector2(-146, -12), Vector2(-150, -30), Vector2(-160, -38), Vector2(-172, -36),
		Vector2(-182, -28)]},
	{"id": "fair_garden", "kind": "side", "width": 2.8, "points": [
		Vector2(-158, 5), Vector2(-156, 24), Vector2(-158, 40), Vector2(-160, 47)]},
	{"id": "fair_garden_south", "kind": "side", "width": 2.6, "points": [
		Vector2(-167, 54), Vector2(-178, 52), Vector2(-188, 46), Vector2(-190, 40)]},
	{"id": "fair_roses", "kind": "trail", "width": 1.8, "points": [
		Vector2(-199, -46), Vector2(-196, -60), Vector2(-192, -72)]},
	{"id": "fair_magic", "kind": "trail", "width": 2.0, "points": [
		Vector2(-196, 46), Vector2(-192, 56)]},
	# A narrow trail through the trees to the fortune teller's tent and the lime grove.
	{"id": "fair_fortune", "kind": "trail", "width": 1.6, "points": [
		Vector2(-366, 40), Vector2(-362, 54), Vector2(-364, 66)]},
	{"id": "fair_limes", "kind": "trail", "width": 1.6, "points": [
		Vector2(-344, 46), Vector2(-338, 60), Vector2(-332, 72)]},
]


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


static func oases() -> Array[String]:
	var out: Array[String] = []
	for id: String in PLACES:
		if PLACES[id].get("oasis", false):
			out.append(id)
	return out

class_name CoastLayout
extends RefCounted
## Static design of the Möwenbucht (doc/moewenbucht.md): the promenade along the park's south
## fence, the dunes, the sand beach in a bay, the pier, the harbour with its jetty and the mole
## with the lighthouse, the rocky point in the west, the sandbank and the buoys. Coordinates are
## metres on the ground plane as Vector2(x, z), like ParkLayout; the area spans
## ParkLayout.COAST_MIN..COAST_MAX, the sea goes on beyond it.

const W := ParkLayout.WATER_Y
## The promenade's line and the dunes' band (z).
const PROMENADE_Z := 108.0
const DUNES := Vector2(113.0, 136.0)
## The harbour: the quay's edge (z) east of QUAY_X, the mole round the basin.
const QUAY_X := 80.0
const QUAY_Z := 150.0
const QUAY_Y := 0.95
const MOLE := [Vector2(126, 132), Vector2(126, 200), Vector2(122, 214), Vector2(112, 223), Vector2(98, 228)]
const MOLE_HALF := 3.0
const MOLE_Y := 1.15
## The rocky point in the west (rock, nobody walks there).
const ROCKS := [Vector2(-131, 132), Vector2(-112, 136), Vector2(-100, 150), Vector2(-97, 168), Vector2(-102, 186),
	Vector2(-112, 200), Vector2(-124, 208), Vector2(-131, 210)]
## The sandbank with the seals (ellipse), the buoys' line (the boats' limit).
## Where the cliff west of the bay (CoastBackdrop, beyond the area) meets the sea.
const SEA_CLIFF_Z := 205.0
const SANDBANK := Vector2(-58, 226)
const SANDBANK_R := Vector2(13, 5)
const BUOY_Z := 262.0
const BUOY_X := 124.0

## The pier (Seebrücke): from the beach out to its head; the deck's height above the water.
const PIER_X := 0.0
const PIER_Z := Vector2(138.0, 236.0)
const PIER_HALF := 2.0
const PIER_Y := W + 1.6
const PIER_HEAD := Vector2(0, 244)
const PIER_HEAD_SIZE := Vector2(18, 16)
## The jetty in the harbour (Bootssteg): from the quay's edge south into the basin, the boats
## moored along both sides.
const JETTY := [Vector2(96, QUAY_Z - 3.0), Vector2(96, 178)]
const JETTY_HALF := 1.3
const JETTY_Y := W + 0.55
## Wooden groynes (Buhnen) from the beach into the sea: [x, length].
const GROYNES := [[-64.0, 26.0], [36.0, 24.0]]
## Boardwalks over the dunes (x): planks from the promenade to the beach.
const BOARDWALKS := [-60.0, 0.0, 50.0]

const GATE := Vector2(0, 90)

## Named places. `r` is the footprint radius kept free of plants.
const PLACES := {
	"forecourt": {"pos": Vector2(0, 100), "r": 6.0, "name": "Vorplatz"},
	"promenade": {"pos": Vector2(-30, PROMENADE_Z), "r": 3.0, "name": "Strandpromenade"},
	"bandstand": {"pos": Vector2(-84, 99), "r": 9.0, "name": "Kurmuschel"},
	"fish_stand": {"pos": Vector2(-44, 99), "r": 4.0, "name": "Fischbude"},
	"ice_stand": {"pos": Vector2(-22, 99), "r": 4.0, "name": "Eisdiele"},
	"kiosk": {"pos": Vector2(24, 99), "r": 4.0, "name": "Kiosk"},
	"souvenirs": {"pos": Vector2(48, 99), "r": 4.0, "name": "Souvenirs"},
	"boat_rental": {"pos": Vector2(92, 138), "r": 5.0, "name": "Bootsverleih"},
	"playground": {"pos": Vector2(-96, 124), "r": 10.0, "name": "Piratenschiff"},
	"volleyball": {"pos": Vector2(-50, 150), "r": 10.0, "name": "Beachvolleyball"},
	"lifeguard": {"pos": Vector2(-22, 160), "r": 4.0, "name": "Rettungsturm"},
	"beach_bar": {"pos": Vector2(24, 142), "r": 6.0, "name": "Strandbar"},
	"sandcastles": {"pos": Vector2(60, 154), "r": 6.0, "name": "Sandburgenplatz"},
	"campfire": {"pos": Vector2(-80, 158), "r": 5.0, "name": "Lagerfeuer"},
	"pier": {"pos": Vector2(PIER_X, 200), "r": 3.0, "name": "Seebrücke"},
	"pier_head": {"pos": PIER_HEAD, "r": 9.0, "name": "Brückenkopf"},
	"harbour": {"pos": Vector2(102, 140), "r": 8.0, "name": "Hafen"},
	"jetty": {"pos": Vector2(96, 165), "r": 3.0, "name": "Bootssteg"},
	"cutter": {"pos": Vector2(113, 154), "r": 5.0, "name": "Fischkutter"},
	"mole": {"pos": Vector2(126, 180), "r": 3.0, "name": "Mole"},
	"lighthouse": {"pos": Vector2(97, 229), "r": 4.0, "name": "Leuchtturm"},
	"rocks": {"pos": Vector2(-114, 170), "r": 10.0, "name": "Felsen"},
	"sandbank": {"pos": SANDBANK, "r": 13.0, "name": "Sandbank"},
	"gate_coast": {"pos": GATE, "r": 4.0, "name": "Südtor"},
}

## Rectangular areas: centre, size, rotation (radians), ground kind (as ParkLayout.AREAS).
const AREAS := {
	"volleyball": {"pos": Vector2(-50, 150), "size": Vector2(18, 10), "rot": 0.0, "ground": "sand"},
	"quay": {"pos": Vector2(104, 140), "size": Vector2(48, 20), "rot": 0.0, "ground": "plaza"},
}

## Round plazas: centre, radius.
const PLAZAS := {
	"forecourt": {"pos": Vector2(0, 100), "r": 6.0},
	"bandstand": {"pos": Vector2(-84, 99), "r": 8.0},
}

## Paths: control points, width and surface kind (as ParkLayout.PATHS); ids start with "coast_".
const PATHS := [
	{"id": "coast_gate", "kind": "main", "width": 4.0, "points": [Vector2(0, 89), Vector2(0, 106)]},
	{"id": "coast_promenade", "kind": "main", "width": 5.0, "points": [
		Vector2(-126, 109), Vector2(-100, 108), Vector2(-70, 107.5), Vector2(-40, 108), Vector2(0, 108.5),
		Vector2(40, 108), Vector2(70, 107.5), Vector2(90, 110), Vector2(98, 118), Vector2(100, 128)]},
	{"id": "coast_stands", "kind": "side", "width": 2.6, "points": [
		Vector2(-76, 103), Vector2(-60, 102.5), Vector2(-30, 103), Vector2(-8, 103)]},
	{"id": "coast_stands_e", "kind": "side", "width": 2.6, "points": [
		Vector2(8, 103), Vector2(30, 103), Vector2(56, 103), Vector2(64, 106)]},
	{"id": "coast_playground", "kind": "trail", "width": 2.0, "points": [
		Vector2(-100, 108.5), Vector2(-98, 114)]},
	# Sand tracks along the beach.
	{"id": "coast_beach_w", "kind": "trail", "width": 2.0, "points": [
		Vector2(-60, 137), Vector2(-58, 141), Vector2(-46, 143)]},
	{"id": "coast_beach_e", "kind": "trail", "width": 2.0, "points": [
		Vector2(50, 137), Vector2(56, 143), Vector2(72, 141), Vector2(82, 136)]},
]

## Where the coast's people work (HumanBrain "coast:<id>" spots): [position, facing]. Phase 4.
const POSTS := {}


## The shore line of the bay (z at x): deepest in the middle.
static func shore_z(x: float) -> float:
	return 166.0 + 10.0 * cos(clampf(x / 125.0, -1.0, 1.0) * PI * 0.5)


## Signed distance to the water's edge: positive on land, negative in the sea (metres,
## roughly). The quay and the mole are land, the rocky point too, the sandbank a low island.
static func land_dist(p: Vector2) -> float:
	var d := shore_z(p.x) - p.y
	if p.x > QUAY_X:
		# The harbour: a quay with a straight edge, the basin behind the mole.
		var quay := QUAY_Z - p.y
		d = lerpf(d, quay, smoothstep(QUAY_X, QUAY_X + 6.0, p.x))
	d = maxf(d, MOLE_HALF - mole_dist(p))
	d = maxf(d, rock_depth(p))
	d = maxf(d, sandbank_depth(p))
	return d


## Distance from p to the mole's middle line.
static func mole_dist(p: Vector2) -> float:
	var best := INF
	for i in MOLE.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, MOLE[i], MOLE[i + 1]).distance_to(p))
	return best


static var _rocks := PackedVector2Array()


## How far p lies inside the rocky point (negative outside).
static func rock_depth(p: Vector2) -> float:
	if p.x > -90.0 or p.y < 128.0 or p.y > 215.0:
		return -INF
	if _rocks.is_empty():
		_rocks = PackedVector2Array(ROCKS)
	var best := INF
	for i in _rocks.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, _rocks[i], _rocks[i + 1]).distance_to(p))
	return best if p.x < -130.0 or Geometry2D.is_point_in_polygon(p, _rocks) else -best


static func sandbank_depth(p: Vector2) -> float:
	var q := (p - SANDBANK) / SANDBANK_R
	return (1.0 - q.length()) * SANDBANK_R.y


static func in_rocks(p: Vector2, margin := 0.0) -> bool:
	return rock_depth(p) > margin


## Terrain height: the strip by the park's fence, the promenade, the dunes, the beach falling
## into the sea, the sea floor, the quay and the mole, the rocks; street level at the fence.
static func height(p: Vector2) -> float:
	var land := land_dist(p)
	var h: float
	if p.y < PROMENADE_Z:
		h = 0.45 * smoothstep(ParkLayout.COAST_EDGE, ParkLayout.COAST_EDGE + 10.0, p.y)
	else:
		h = 0.45 + 1.9 * dune(p) - 0.1 * smoothstep(DUNES.y, DUNES.y + 8.0, p.y)
	# The beach: from the dunes' foot down to the water and on below it.
	var beach := W - 0.12 + clampf(land, 0.0, 30.0) * 0.035
	if land < 0.0:
		beach = W - 0.12 - 3.0 * smoothstep(0.0, 34.0, -land) - 0.6 * smoothstep(0.0, 4.0, -land)
	if p.y > DUNES.y - 4.0 or land < 30.0:
		h = lerpf(h, beach, smoothstep(DUNES.y - 4.0, DUNES.y + 6.0, p.y)) if land >= 0.0 else beach
	if p.x > QUAY_X - 4.0 and p.y > PROMENADE_Z + 12.0 and p.y < QUAY_Z + 0.5:
		h = lerpf(h, QUAY_Y, smoothstep(QUAY_X - 4.0, QUAY_X + 2.0, p.x))
	var mole := MOLE_HALF + 0.5 - mole_dist(p)
	if mole > 0.0:
		h = maxf(h, lerpf(W - 2.0, MOLE_Y, smoothstep(0.0, 1.0, mole)))
	var rock := rock_depth(p)
	if rock > -2.0:
		h = maxf(h, lerpf(W - 1.0, 2.0 + 4.5 * smoothstep(0.0, 18.0, rock) + 1.2 * sin(p.x * 0.31 + p.y * 0.17), smoothstep(-2.0, 2.0, rock)))
	var bank := sandbank_depth(p)
	if bank > -6.0:
		h = maxf(h, W - 0.12 + 0.4 * smoothstep(-2.0, 3.0, bank) - 1.5 * smoothstep(-2.0, -6.0, bank))
	return h


## The dunes' height (0..1) between the promenade and the beach, low where the boardwalks cross.
static func dune(p: Vector2) -> float:
	var t := (p.y - (DUNES.x + DUNES.y) * 0.5) / ((DUNES.y - DUNES.x) * 0.5)
	if absf(t) >= 1.0:
		return 0.0
	var bell := 0.5 + 0.5 * cos(t * PI)
	var waves := 0.75 + 0.25 * sin(p.x * 0.09 + 1.1) + 0.15 * sin(p.x * 0.23 + p.y * 0.4)
	var gap := 1.0
	for x: float in BOARDWALKS:
		gap = minf(gap, lerpf(0.45, 1.0, smoothstep(2.5, 7.0, absf(p.x - x))))
	if p.x > QUAY_X - 6.0:
		gap *= 1.0 - smoothstep(QUAY_X - 6.0, QUAY_X, p.x)
	return bell * waves * gap


## Inside the line of buoys (where boats may go).
static func in_bay(p: Vector2, margin := 0.0) -> bool:
	return absf(p.x) <= BUOY_X - margin and p.y <= BUOY_Z - margin and p.y > ParkLayout.COAST_EDGE


## The walk decks over the water and the dunes: the pier (sloping up from the beach), its head
## and the jetty, as ParkMap.decks.
static func decks() -> Array[Dictionary]:
	var start := Vector2(PIER_X, PIER_Z.x)
	var beach_y := height(start)
	return [
		{"a": start, "b": Vector2(PIER_X, PIER_Z.x + 16.0), "half": PIER_HALF, "h0": beach_y + 0.12, "h1": PIER_Y},
		{"a": Vector2(PIER_X, PIER_Z.x + 16.0), "b": Vector2(PIER_X, PIER_Z.y), "half": PIER_HALF, "h0": PIER_Y, "h1": PIER_Y},
		{"a": PIER_HEAD - Vector2(0, PIER_HEAD_SIZE.y * 0.5), "b": PIER_HEAD + Vector2(0, PIER_HEAD_SIZE.y * 0.5),
			"half": PIER_HEAD_SIZE.x * 0.5, "h0": PIER_Y, "h1": PIER_Y},
		{"a": JETTY[0], "b": JETTY[0] + Vector2(0, 6.0), "half": JETTY_HALF, "h0": QUAY_Y, "h1": JETTY_Y},
		{"a": JETTY[0] + Vector2(0, 6.0), "b": JETTY[1], "half": JETTY_HALF, "h0": JETTY_Y, "h1": JETTY_Y},
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

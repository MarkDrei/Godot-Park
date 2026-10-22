class_name Coast
extends Node3D
## The Möwenbucht at runtime (doc/moewenbucht.md): built when the player comes close
## (World.load_area). Keeps the posts of its people, the spots of its games and its boats; turns
## the lighthouse's beam at night; picks the places its visitors stroll to.

var world: World
var rng := RandomNumberGenerator.new()
var time := 0.0

## Where the coast's people work (id -> [position, yaw]; HumanBrain "coast:<id>" spots), where
## its games start (id -> position).
var posts := {}
var spots := {}
## The pedal and rowing boats (Cars with spec "water"), moored at the jetty.
var boats: Array[Car] = []
var light_beam: MeshInstance3D
## The seals on the sandbank: they breathe, rock now and then and call when someone is near.
var seals: Array[MeshInstance3D] = []
var _seal_call := 4.0

## The boats at the jetty: [kind, colour, side of the jetty (-1 west, 1 east), z, yaw]. East of
## the jetty they lie side by side with the stern to it, bow out into the basin (gas takes them
## straight out); west of it, where the beach is near, along it with the bow to the south.
const BOATS := [
	["pedalo", Color("f4f1ea"), 1.0, 154.0, PI / 2], ["pedalo", Color("f4f1ea"), 1.0, 157.0, PI / 2],
	["pedalo", Color("f4f1ea"), 1.0, 160.0, PI / 2], ["pedalo", Color("f4f1ea"), 1.0, 163.0, PI / 2],
	["rowboat", Color("c8553d"), 1.0, 166.5, PI / 2], ["rowboat", Color("2f6fb0"), 1.0, 170.0, PI / 2],
	["rowboat", Color("2e7a5a"), -1.0, 162.0, 0.0], ["pedalo", Color("f4f1ea"), -1.0, 172.0, 0.0],
]


func setup(w: World) -> void:
	world = w
	name = "Coast"
	rng.seed = 8080


## The stands as shops (their vendors are the coast's people): shop id -> post id.
const SHOPS := {"coast_fish": "fish_stand", "coast_ice": "ice_stand", "coast_kiosk": "kiosk", "coast_souvenirs": "souvenirs",
	"coast_bar": "beach_bar", "coast_cutter": "cutter"}


## The shops and the boats at their moorings (once the coast is in the tree).
func setup_gameplay() -> void:
	for id: String in SHOPS:
		var post: String = SHOPS[id]
		var vendor: Vector3 = posts[post][0]
		var counter: Vector3 = spots.get(post, vendor + Vector3(0, 0, 2.0))
		world.shop_spots[id] = {"pos": counter, "vendor": vendor}
		var shop := Shop.new()
		shop.setup(world, id, world.shop_spots[id])
		add_child(shop)
		world.shops[id] = shop
	var fishing := BoatFishing.new()
	fishing.setup(world)
	add_child(fishing)
	for b: Array in BOATS:
		var car := Car.new()
		add_child(car)
		car.setup(world, b[0], b[1], mooring(boats.size()), b[4])
		boats.append(car)


## Where boat i lies at the jetty.
func mooring(i: int) -> Vector2:
	var b: Array = BOATS[i]
	var spec := CarSpecs.spec(b[0])
	var across: bool = absf(sin(float(b[4]))) > 0.5
	var half: float = float(spec["length"] if across else spec["width"]) * 0.5
	var x: float = CoastLayout.JETTY[0].x + float(b[2]) * (CoastLayout.JETTY_HALF + half + 0.3)
	return Vector2(x, b[3])


func mooring_yaw(i: int) -> float:
	return BOATS[i][4]


## Puts every boat nobody sits in back to its mooring (tests, the next day); a boat beyond the
## eight (CoastStories' drifted one) stays where it is.
func moor_boats() -> void:
	for i in mini(boats.size(), BOATS.size()):
		var car := boats[i]
		if car.driver == null:
			car.speed = 0.0
			car.set_input(0.0, 0.0)
			car.place(mooring(i), mooring_yaw(i))


func _process(delta: float) -> void:
	time += delta
	_seals(delta)
	if light_beam:
		var night := Clock.daylight() < 0.45 and not CoastStories.lamp_broken()
		light_beam.visible = night
		if night:
			light_beam.rotation.y = fmod(time * 0.6, TAU)


func _seals(delta: float) -> void:
	for i in seals.size():
		var s := seals[i]
		var k := time * 0.8 + i * 1.7
		s.scale = Vector3(1.0, 1.0 + 0.04 * sin(k * 2.0), 1.0)
		s.rotation.z = 0.12 * maxf(0.0, sin(k * 0.35)) * (1.0 if i % 2 == 0 else -1.0)
	_seal_call -= delta
	if _seal_call <= 0.0 and not seals.is_empty():
		_seal_call = rng.randf_range(5.0, 11.0)
		if world.focus.distance_to(seals[0].position) < 45.0:
			Sound.play("seal", seals[rng.randi() % seals.size()].position, -2.0)


## A place the coast's visitors stroll to: on a path, on the beach, on the pier.
func random_point(r: RandomNumberGenerator) -> Vector2:
	for i in 40:
		var p: Vector2
		var pick := r.randf()
		if pick < 0.45:
			var paths := CoastMap.paths(world.map)
			var path: Dictionary = paths[r.randi() % paths.size()]
			var pts: PackedVector2Array = path["points"]
			p = pts[r.randi() % pts.size()]
		elif pick < 0.85:
			var x := r.randf_range(-90.0, CoastLayout.QUAY_X - 6.0)
			p = Vector2(x, r.randf_range(CoastLayout.DUNES.y + 3.0, CoastLayout.shore_z(x) - 6.0))
		else:
			p = Vector2(CoastLayout.PIER_X + r.randf_range(-1.2, 1.2), r.randf_range(CoastLayout.PIER_Z.x + 10.0, CoastLayout.PIER_HEAD.y + 6.0))
		if ParkMap.in_coast(p, 3.0) and not world.map.is_solid(p):
			return p
	return CoastLayout.place("forecourt")

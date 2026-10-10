class_name City
extends Node3D
## The Oststadt at runtime (doc/oststadt.md): built when the player comes close (World.load_city).
## Owns the cars, the drive-ins and the town's registries; actors ask it about cars in their way.

var world: World
var cars: Array[Car] = []
var drive_in: DriveIn
var cinema: Cinema
var traffic: Traffic
var rng := RandomNumberGenerator.new()


func setup(w: World) -> void:
	world = w
	name = "City"
	rng.seed = 3131


## Parked cars on the parking strips and the special vehicles on their lots.
func spawn_cars() -> void:
	for bay: Dictionary in CityLayout.parking_bays():
		if bay.get("tree", false) or rng.randf() > 0.42:
			continue
		var kind: String = CarSpecs.ORDINARY[rng.randi() % CarSpecs.ORDINARY.size()]
		spawn_car(kind, CarSpecs.COLORS[rng.randi() % CarSpecs.COLORS.size()], bay["pos"], bay["yaw"])
	# The town's special vehicles (their jobs come with the minigames).
	for v: Array in VEHICLES:
		var c := spawn_car(v[0], v[1], v[2], v[3])
		c.name = "Car_" + v[4]
		c.job = v[4]


## [kind, colour, position, yaw, id] of the special vehicles.
const VEHICLES := [
	["taxi", Color("e8e0b8"), Vector2(199.0, 10.5), PI, "taxi"],
	["taxi", Color("e8e0b8"), Vector2(193.0, 10.5), PI, "taxi2"],
	["tow", Color("e8602e"), Vector2(232.0, -112.0), PI / 2, "tow"],
	["learner", Color("ecf0f1"), Vector2(300.0, -124.0), PI / 2, "learner"],
	["garbage", Color("e8702e"), Vector2(368.0, -206.0), 0.0, "garbage"],
	["icecream", Color("f4f0e8"), Vector2(298.0, 55.25), -PI / 2, "icecream"],
	["oldtimer", Color("7a1f2b"), Vector2(318.0, 77.0), PI, "oldtimer"],
	["delivery", Color("d8402e"), Vector2(192.0, -66.0), -PI / 2, "delivery"],
	["kart", Color("d0352b"), Vector2(236.0, -178.0), PI, "kart1"],
	["kart", Color("2e86de"), Vector2(240.0, -178.0), PI, "kart2"],
	["kart", Color("27ae60"), Vector2(244.0, -178.0), PI, "kart3"],
	["kart", Color("f2c230"), Vector2(236.0, -173.0), PI, "kart4"],
	["kombi", Color("2c3e50"), Vector2(176.0, -128.0 + 3.0), 0.0, ""],
]


## Counters of the town's traders: [id, counter (customer side), vendor spot, yaw facing the customer].
const SHOPS := [
	["petrol_shop", Vector2(164.6, -128.0), Vector2(162.7, -128.0), PI / 2],
	["drive_in_counter", Vector2(174.0, -37.3), Vector2(174.0, -39.3), 0.0],
	["scrapyard", Vector2(296.5, -175.3), Vector2(296.5, -177.3), 0.0],
]


## The traders, the drive-in burger, the drive-in cinema and the traffic.
func setup_gameplay() -> void:
	for sh: Array in SHOPS:
		var counter: Vector2 = sh[1]
		var vendor: Vector2 = sh[2]
		var yaw: float = sh[3]
		var mid := (counter + vendor) * 0.5
		var mi := MeshInstance3D.new()
		mi.mesh = CityModels.counter()
		mi.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, world.map.walk_height(mid.x, mid.y), mid.y))
		add_child(mi)
		world.map.add_obstacle_rect(mid, Vector2(2.0, 0.6), -yaw, 7)
		world.shop_spots[sh[0]] = {"pos": Vector3(counter.x, world.map.walk_height(counter.x, counter.y), counter.y),
			"vendor": Vector3(vendor.x, world.map.walk_height(vendor.x, vendor.y), vendor.y)}
		var shop := Shop.new()
		shop.setup(world, sh[0], world.shop_spots[sh[0]])
		add_child(shop)
		world.shops[sh[0]] = shop
	drive_in = DriveIn.new()
	add_child(drive_in)
	drive_in.setup(world)
	cinema = Cinema.new()
	cinema.setup(UI.game)
	cinema.build_city(self)
	traffic = Traffic.new()
	add_child(traffic)
	traffic.setup(world)
	traffic.build_lights(self)
	traffic.spawn_all()


func spawn_car(kind: String, col: Color, pos: Vector2, yaw: float) -> Car:
	var c := Car.new()
	add_child(c)
	c.setup(world, kind, col, pos, yaw)
	cars.append(c)
	return c


func remove_car(c: Car) -> void:
	cars.erase(c)
	if is_instance_valid(c):
		c.queue_free()


## The car whose footprint (grown by `margin`) covers p, or null. Actors can't walk into cars.
func car_at(p: Vector2, margin := 0.0) -> Car:
	for c in cars:
		if c.pos2().distance_squared_to(p) < 36.0 and c.contains(p, margin):
			return c
	return null


func find_car(id: String) -> Car:
	for c in cars:
		if c.name == "Car_" + id:
			return c
	return null


func nearest_car(p: Vector2, max_dist := 30.0, filter := Callable()) -> Car:
	var best: Car = null
	var best_d := max_dist
	for c in cars:
		var d := c.pos2().distance_to(p)
		if d < best_d and (not filter.is_valid() or filter.call(c)):
			best_d = d
			best = c
	return best

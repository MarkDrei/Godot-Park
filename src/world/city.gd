class_name City
extends Node3D
## The Oststadt at runtime (doc/oststadt.md): built when the player comes close (World.load_area).
## Owns the cars, the drive-ins and the town's registries; actors ask it about cars in their way.

var world: World
var cars: Array[Car] = []
var drive_in: DriveIn
var cinema: Cinema
var traffic: Traffic
var rng := RandomNumberGenerator.new()
const GRID := 10.0                 # metres per bucket of cars_near
var _grid := {}                    # Vector2i -> Array of Car
var _grid_frame := -1


func setup(w: World) -> void:
	world = w
	name = "City"
	rng.seed = 3131


## Parked cars on the parking strips and the special vehicles on their lots.
func spawn_cars() -> void:
	for bay: Dictionary in CityLayout.parking_bays():
		if bay.get("tree", false) or rng.randf() > 0.34:   # about a third of the bays (draw calls on the long streets)
			continue
		var kind: String = CarSpecs.ORDINARY[rng.randi() % CarSpecs.ORDINARY.size()]
		spawn_car(kind, CarSpecs.COLORS[rng.randi() % CarSpecs.COLORS.size()], bay["pos"], bay["yaw"])
	# The town's special vehicles (their jobs come with the minigames).
	for v: Array in CityLayout.VEHICLES:
		var c := spawn_car(v[0], v[1], v[2], v[3])
		c.name = "Car_" + v[4]
		c.job = v[4]




## Counters of the town's traders: [id, counter (customer side), vendor spot, yaw facing the customer].
const SHOPS := [
	["petrol_shop", Vector2(164.6, -128.0), Vector2(162.7, -128.0), PI / 2],
	["drive_in_counter", Vector2(174.0, -37.3), Vector2(174.0, -39.3), 0.0],
	["scrapyard", Vector2(296.5, -175.3), Vector2(296.5, -177.3), 0.0],
	["supermarket", Vector2(519.0, -130.6), Vector2(519.0, -132.6), 0.0],
]


## The traders, the drive-in burger, the drive-in cinema (a minigame of Gameplay) and the traffic.
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
		world.map.add_obstacle_rect(mid, Vector2(2.0, 0.6), -yaw, ParkMap.BLOCK_ALL)
		world.shop_spots[sh[0]] = {"pos": Vector3(counter.x, world.map.walk_height(counter.x, counter.y), counter.y),
			"vendor": Vector3(vendor.x, world.map.walk_height(vendor.x, vendor.y), vendor.y)}
		var shop := Shop.new()
		shop.setup(world, sh[0], world.shop_spots[sh[0]])
		add_child(shop)
		world.shops[sh[0]] = shop
	# Snack machines and the Imbiss stalls (built by CityBuilder, which set their spots).
	for e: Array in CityLayout.MACHINES + CityLayout.STALLS:
		var shop := Shop.new()
		shop.setup(world, e[0], world.shop_spots[e[0]])
		add_child(shop)
		world.shops[e[0]] = shop
	drive_in = DriveIn.new()
	add_child(drive_in)
	drive_in.setup(world)
	cinema = Gameplay.minigames["cinema"]
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
	_grid_frame = -1
	return c


func remove_car(c: Car) -> void:
	cars.erase(c)
	_grid_frame = -1
	if is_instance_valid(c):
		c.queue_free()


## The car whose footprint (grown by `margin`) covers p, or null. Actors can't walk into cars.
func car_at(p: Vector2, margin := 0.0) -> Car:
	for c in cars_near(p, 6.0):
		if c.contains(p, margin):
			return c
	return null


## A car was put somewhere (Car.place): sort the cars again before the next query.
func moved_by_hand() -> void:
	_grid_frame = -1


## Cars whose centre lies within `radius` of p. A bucket grid (rebuilt once per physics frame)
## keeps this cheap with ~170 cars: walkers and drivers only look at the cars around them.
func cars_near(p: Vector2, radius: float) -> Array[Car]:
	var f := Engine.get_physics_frames()
	if f != _grid_frame:
		_grid_frame = f
		_grid.clear()
		for c in cars:
			var k := Vector2i(floori(c.position.x / GRID), floori(c.position.z / GRID))
			if _grid.has(k):
				(_grid[k] as Array).append(c)
			else:
				_grid[k] = [c]
	var out: Array[Car] = []
	var r2 := radius * radius
	for gx in range(floori((p.x - radius) / GRID), floori((p.x + radius) / GRID) + 1):
		for gz in range(floori((p.y - radius) / GRID), floori((p.y + radius) / GRID) + 1):
			var bucket: Variant = _grid.get(Vector2i(gx, gz))
			if bucket == null:
				continue
			for c: Car in bucket:
				if is_instance_valid(c) and Vector2(c.position.x, c.position.z).distance_squared_to(p) <= r2:
					out.append(c)
	return out


func find_car(id: String) -> Car:
	for c in cars:
		if c.name == "Car_" + id:
			return c
	return null


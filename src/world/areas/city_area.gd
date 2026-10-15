class_name CityArea
extends Area
## The Oststadt (doc/oststadt.md), built when the player comes near: ground kinds and
## navigation (CityMap), meshes and props (CityBuilder), the runtime with cars, drive-in,
## cinema and traffic (City). Until then, and while it sleeps, the park sees the EastBackdrop.


func _init(w: World) -> void:
	super(w)
	id = "city"
	name_in = "in der Oststadt"
	loading_text = "Fahre in die Oststadt …"
	go_question = "Willst du in die Oststadt gehen?"
	sleeps_line = "Die Oststadt wird solange entladen."
	go_yes = "Ja, in die Oststadt"


func is_built() -> bool:
	return world.city != null


func is_open() -> bool:
	return world.map.city_open


func _set_open(on: bool) -> void:
	world.map.city_open = on


func _build() -> void:
	await step(0.1, "Vermesse die Oststadt …")
	CityMap.build(world.map)
	await step(0.3, "Teere die Straßen …")
	_show_backdrop(false)
	root = Node3D.new()
	root.name = "Oststadt"
	world.static_root.add_child(root)
	var builder := CityBuilder.new(world, root)
	builder.build_ground()
	await step(0.5, "Baue die Häuser …")
	builder.build_props()
	await step(0.7, "Plane die Gehwege …")
	world.map.build_city_navigation()
	MapImage.add_city(world.map)
	await step(0.85, "Parke die Autos …")
	var city := City.new()
	city.setup(world)
	world.add_child(city)
	world.city = city   # its cars, shops and traffic look it up there
	runtime = city
	city.spawn_cars()
	city.setup_gameplay()


func _show_backdrop(on: bool) -> void:
	for n: String in ["EastSurroundings", "EastBackdrop"]:
		var node := world.static_root.get_node_or_null(n) as Node3D
		if node:
			node.visible = on


func cast() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var defs: Array = []
	defs.append_array(Cast.CITY)
	for i in 10:
		defs.append(Cast.city_person(i, rng))
	for i in 4:
		defs.append(Cast.city_kid(i, rng))
	return defs

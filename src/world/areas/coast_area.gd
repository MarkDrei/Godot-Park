class_name CoastArea
extends Area
## The Möwenbucht (doc/moewenbucht.md), built when the player comes near: heights, ground kinds
## and navigation (CoastMap), terrain, promenade, beach, pier and harbour (CoastBuilder), the
## runtime with its boats (Coast). Until then, and while it sleeps, the others see the
## CoastBackdrop; the sea itself is always there (CoastBackdrop.horizon).


func _init(w: World) -> void:
	super(w)
	id = "coast"
	name_in = "an der Möwenbucht"
	loading_text = "Ab ans Meer …"
	go_question = "Willst du an die Möwenbucht?"
	sleeps_line = "Die Möwenbucht wird solange entladen."
	go_yes = "Ja, ans Meer"


func is_built() -> bool:
	return world.coast != null


func is_open() -> bool:
	return world.map.coast_open


func _set_open(on: bool) -> void:
	world.map.coast_open = on


func _build() -> void:
	await step(0.1, "Vermesse die Bucht …")
	CoastMap.build(world.map)
	await step(0.25, "Harke den Strand …")
	root = Node3D.new()
	root.name = "Moewenbucht"
	world.static_root.add_child(root)
	# `world.coast` is set only when it is complete: code that checks it may run between the steps.
	var coast := Coast.new()
	coast.setup(world)
	var builder := CoastBuilder.new(world, coast, root)
	builder.build_ground()
	await step(0.45, "Baue die Seebrücke …")
	builder.build_props()
	await step(0.7, "Stelle die Strandkörbe auf …")
	world.map.build_coast_navigation()
	MapImage.add_coast(world.map)
	# Its people come along the coast: from the cliff path in the west and the harbour town in the east.
	world.coast_entrances.append([Vector3(-134.0, 0.0, 109.0), Vector3(-124.0, 0.0, 109.0)])
	world.coast_entrances.append([Vector3(134.0, 0.0, 140.0), Vector3(118.0, 0.0, 140.0)])
	await step(0.85, "Lasse die Boote zu Wasser …")
	world.add_child(coast)
	world.coast = coast
	runtime = coast
	coast.setup_gameplay()
	Sound.add_ambient("surf")
	_show_backdrop(false)


func _show_backdrop(on: bool) -> void:
	if world.coast_backdrop:
		world.coast_backdrop.visible = on


func cast() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8383
	var defs: Array = []
	defs.append_array(Cast.COAST_ANIMALS)
	for i in 12:
		defs.append(Cast.coast_visitor(i, rng))
	for i in 5:
		defs.append(Cast.coast_kid(i, rng))
	return defs

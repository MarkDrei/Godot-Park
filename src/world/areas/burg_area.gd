class_name BurgArea
extends Area
## The Ritterburg (doc/burg.md), built when the player comes near: heights, ground kinds and
## navigation (BurgMap), terrain, walls, buildings and booths (BurgBuilder), the runtime with
## its posts and torches (Burg). Until then, and while it sleeps, the others see the BurgBackdrop.


func _init(w: World) -> void:
	super(w)
	id = "burg"
	name_in = "auf der Burg"
	loading_text = "Hinauf zur Ritterburg …"
	go_question = "Willst du zur Ritterburg?"
	sleeps_line = "Die Ritterburg wird solange entladen."
	go_yes = "Ja, zur Burg"


func is_built() -> bool:
	return world.burg != null


func is_open() -> bool:
	return world.map.burg_open


func _set_open(on: bool) -> void:
	world.map.burg_open = on


func _build() -> void:
	await step(0.1, "Vermesse den Burgberg …")
	BurgMap.build(world.map)
	await step(0.25, "Harke den Turnierplatz …")
	root = Node3D.new()
	root.name = "Ritterburg"
	world.static_root.add_child(root)
	# `world.burg` is set only when it is complete: code that checks it may run between the steps.
	var burg := Burg.new()
	burg.setup(world)
	var builder := BurgBuilder.new(world, burg, root)
	builder.build_ground()
	await step(0.45, "Mauere die Burg …")
	builder.build_props()
	await step(0.7, "Plane die Marktpfade …")
	world.map.build_burg_navigation()
	MapImage.add_burg(world.map, world.burg_trees)
	await step(0.85, "Entzünde die Fackeln …")
	world.add_child(burg)
	world.burg = burg
	runtime = burg
	burg.setup_gameplay()
	_show_backdrop(false)


func _show_backdrop(on: bool) -> void:
	if world.burg_backdrop:
		world.burg_backdrop.visible = on


func cast() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7373
	var defs: Array = []
	defs.append_array(Cast.BURG)
	defs.append_array(Cast.BURG_ANIMALS)
	for i in 10:
		defs.append(Cast.burg_visitor(i, rng))
	for i in 4:
		defs.append(Cast.burg_kid(i, rng))
	return defs

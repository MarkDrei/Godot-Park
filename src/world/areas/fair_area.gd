class_name FairArea
extends Area
## The Westpark with the Kirmes (doc/kirmes.md), built when the player comes near: ground kinds
## and navigation (FairMap), terrain, rides, booths and trees (FairBuilder), the runtime that
## moves the rides (Fair). Until then, and while it sleeps, the park sees the FairBackdrop.


func _init(w: World) -> void:
	super(w)
	id = "fair"
	name_in = "im Westpark"
	loading_text = "Auf zur Kirmes …"
	go_question = "Willst du zur Kirmes in den Westpark?"
	sleeps_line = "Der Westpark wird solange entladen."
	go_yes = "Ja, zur Kirmes"


func is_built() -> bool:
	return world.fair != null


func is_open() -> bool:
	return world.map.fair_open


func _set_open(on: bool) -> void:
	world.map.fair_open = on


func _build() -> void:
	await step(0.1, "Vermesse den Westpark …")
	FairMap.build(world.map)
	await step(0.25, "Mähe die Festwiese …")
	root = Node3D.new()
	root.name = "Westpark"
	world.static_root.add_child(root)
	# `world.fair` is set only when it is complete: code that checks it may run between the steps.
	var fair := Fair.new()
	fair.setup(world)
	var builder := FairBuilder.new(world, fair, root)
	builder.build_ground()
	await step(0.45, "Baue das Riesenrad auf …")
	builder.build_props()
	await step(0.7, "Plane die Wege …")
	world.map.build_fair_navigation()
	MapImage.add_fair(world.map, world.fair_trees)
	await step(0.85, "Hänge die Lichterketten auf …")
	Sound.add_ambient("fair")
	world.add_child(fair)
	fair.ready_parts()
	world.fair = fair
	runtime = fair
	fair.setup_gameplay()
	_show_backdrop(false)


func _show_backdrop(on: bool) -> void:
	world.fair_backdrop.visible = on


func cast() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5353
	var defs: Array = []
	defs.append_array(Cast.FAIR)
	for i in 12:
		defs.append(Cast.fair_visitor(i, rng))
	for i in 6:
		defs.append(Cast.fair_kid(i, rng))
	return defs

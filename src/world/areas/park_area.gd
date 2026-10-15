class_name ParkArea
extends Area
## The city park with the Nordwald, built at the start (World.build). Asleep, the town and the
## Westpark see the WestBackdrop instead.


func _init(w: World) -> void:
	super(w)
	id = "park"
	name_in = "im Park"
	loading_text = "Zurück in den Park …"
	go_question = "Willst du zurück in den Park?"
	sleeps_line = "Park und Nordwald werden solange entladen."
	go_yes = "Ja, in den Park"


## Built with the world; `root` is World.park_root (seal_park).
func is_built() -> bool:
	return true


func is_open() -> bool:
	return world.map.park_open


func _set_open(on: bool) -> void:
	world.map.park_open = on
	root = world.park_root


func _show_backdrop(on: bool) -> void:
	if on and world.west_backdrop == null:
		world.west_backdrop = WestBackdrop.build(world)
		world.static_root.add_child(world.west_backdrop)
	if world.west_backdrop:
		world.west_backdrop.visible = on


func cast() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var defs: Array = []
	defs.append_array(Cast.PEOPLE)
	for i in 10:
		defs.append(Cast.visitor(i, rng))
	defs.append_array(Cast.FOREST)
	defs.append_array(Cast.ANIMALS)
	return defs

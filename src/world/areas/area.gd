class_name Area
extends RefCounted
## One part of the world (doc/arc42.md §8.8): the park with the Nordwald, the Oststadt, the
## Westpark. World keeps them in `areas`. An area is built once (the park at the start, the others
## when the player comes near), then awake or asleep: asleep means hidden and not processed, its
## ground solid in ParkMap, its people dormant, a cheap backdrop standing in for it. A new area
## is one more subclass plus its layout, map, builder and cast.

var id := ""
## How the game calls being there ("im Park").
var name_in := ""
## The loading screen's line while the player goes there.
var loading_text := ""
## The gate's question with split areas (AreaGates): going there, what sleeps when leaving it,
## the button.
var go_question := ""
var sleeps_line := ""
var go_yes := ""
var world: World
var loading := false
## Its scenery under World.static_root and what moves in it (City, Fair).
var root: Node3D
var runtime: Node3D


func _init(w: World) -> void:
	world = w


func is_built() -> bool:
	return root != null


## Override: the ParkMap switch that keeps the area's ground walkable.
func is_open() -> bool:
	return true


func _set_open(_on: bool) -> void:
	pass


func is_awake() -> bool:
	return is_built() and is_open()


## Builds the area once, behind a loading screen; World.area_loaded tells the game (its people,
## Gameplay its game spots) before the loading screen goes.
func load() -> void:
	if is_built() or loading:
		return
	loading = true
	var t0 := Time.get_ticks_msec()
	UI.show_loading(loading_text)
	await _build()
	world.area_loaded.emit(id)
	await step(1.0, "Fertig!")
	UI.hide_loading()
	loading = false
	print("BANKFREI %s in %d ms" % [id.to_upper(), Time.get_ticks_msec() - t0])


## Override: build map cells, navigation, scenery and runtime; set `root` (and `runtime`).
func _build() -> void:
	pass


## One step of the loading screen (two frames, so it shows).
func step(fraction: float, text: String) -> void:
	UI.loading_progress(fraction, text)
	await world.get_tree().process_frame
	await world.get_tree().process_frame


func set_awake(on: bool) -> void:
	if on == is_open():
		return
	_set_open(on)
	for n: Node3D in [root, runtime]:
		if n:
			n.visible = on
			n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	_show_backdrop(not on)
	world.set_people_awake(id, on)


## Override: the cheap view of the area while it is not there (not built or asleep).
func _show_backdrop(_on: bool) -> void:
	pass


## Override: the people and animals of the area (Cast definitions), spawned once it is built.
func cast() -> Array:
	return []

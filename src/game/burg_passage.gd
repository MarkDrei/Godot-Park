class_name BurgPassage
extends RefCounted
## The secret passage through the mountain (doc/burg.md): a low door in the rock at the top of
## the Ritterburg and one beside the dwarves' mine in the Nordwald. Going through: the screen
## goes dark with a line of text, the areas swap as at a gate (AreaGates.cross: what belongs to
## the area stays) and the player steps out at the other end. The mine's door opens only from
## inside until the passage is found from the castle (stat "passage").

const CASTLE := Vector2(-318, -259)      # the door (BurgLayout "passage")
const CASTLE_OUT := Vector2(-318, -256.4)
const MINE := Vector2(58, -253.6)
const MINE_OUT := Vector2(58, -251.0)
const TEXT_IN := "Du tastest dich durch den dunklen Gang tief in den Berg …"
const TEXT_OUT := "Durch den Berg, an den Zwergenstollen vorbei, hinauf zur Burg …"


## The door beside the mine (built with the park).
static func setup(world: World) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "MinePassageDoor"
	mi.mesh = BurgModels.secret_door()
	mi.position = Vector3(MINE.x, world.map.height_at(MINE.x, MINE.y), MINE.y)
	world.static_root.add_child(mi)
	world.map.add_obstacle_rect(MINE + Vector2(0, -0.6), Vector2(2.6, 1.2), 0.0)
	_spot(world, world, MINE_OUT, func(_a: Actor) -> String:
		return "Durch die Felsentür" if GameState.stat("passage") > 0 else "Felsentür untersuchen",
		func(a: Actor) -> void:
			if GameState.stat("passage") > 0:
				go(a, "burg")
			else:
				GameState.toast.emit("Die Tür ist fest verschlossen. Von innen vielleicht?", "info"))


## The door at the top of the castle (when the Burg is loaded).
static func setup_burg(world: World) -> void:
	_spot(world, world.burg, CASTLE_OUT, func(_a: Actor) -> String: return "Durch den Geheimgang",
		func(a: Actor) -> void: go(a, "park"))


static func _spot(world: World, parent: Node, p: Vector2, prompt: Callable, action: Callable) -> void:
	var s := FunctionSpot.new()
	s.name = "PassageDoor"
	s.position = Vector3(p.x, world.map.walk_height(p.x, p.y), p.y)
	s.radius = 2.0
	s.prompt_fn = prompt
	s.action_fn = action
	parent.add_child(s)


## Through the passage into area `to` ("burg" or "park").
static func go(a: Actor, to: String) -> void:
	var pc: PlayerController = UI.game.player
	if a != pc.actor or pc.actor.vehicle:
		return
	var world: World = pc.world
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var text := UiTheme.label(TEXT_OUT if to == "burg" else TEXT_IN, 26)
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.modulate.a = 0.0
	shade.add_child(text)
	UI.root.add_child(shade)
	a.stop_moving()
	var tw := shade.create_tween()
	tw.tween_property(shade, "color:a", 1.0, 0.9)
	tw.tween_property(text, "modulate:a", 1.0, 0.4)
	await tw.finished
	await shade.get_tree().create_timer(1.4, false).timeout
	for line in pc.gates.leave_behind(to):
		GameState.toast.emit(line, "info")
	await world.enter_area(to)
	var q := CASTLE_OUT if to == "burg" else MINE_OUT
	a.teleport(Vector3(q.x, world.map.walk_height(q.x, q.y), q.y))
	a.face(a.global_position + Vector3(0, 0, 1), true)
	pc.camera.follow(a, false)
	GameState.add_stat("passage")
	tw = shade.create_tween()
	tw.tween_property(text, "modulate:a", 0.0, 0.3)
	tw.tween_property(shade, "color:a", 0.0, 1.0)
	await tw.finished
	shade.queue_free()

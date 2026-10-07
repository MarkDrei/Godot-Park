class_name DuckFeedingGame
extends Minigame
## Futterchaos with Oma Gertrud on the pier: throw bread to the hungry ducks
## (marked with "!"), but don't let greedy Gustav the goose get it.

const DURATION := 60.0

var time_left := DURATION
var score := 0
var target := Vector3.ZERO
var marker: MeshInstance3D
var hungry: Array[Actor] = []
var marks := {}
var pier_end := Vector3.ZERO
var _cooldown := 0.0
var _bread_before := 0


func _init() -> void:
	title = "Futterchaos"
	host_id = "gertrud"


func describe() -> String:
	return "Wirf hungrigen Enten (mit Ausrufezeichen) Brot zu – aber Gans Gustav ist gierig! Oma Gertrud füttert oft am Bootssteg."


func begin() -> void:
	var pier := ParkLayout.PIER
	var to: Vector2 = pier["to"]
	pier_end = Vector3(to.x, world.map.walk_height(to.x, to.y), to.y + 0.8)
	actor.teleport(pier_end)
	actor.face(pier_end + Vector3(0, 0, -5), true)
	var h := host()
	if h:
		h.teleport(pier_end + Vector3(0.8, 0, 2.2))
		h.face(pier_end + Vector3(0, 0, -5))
		h.say("Die mit dem Ausrufezeichen haben Hunger, Kind!", 3.5)
	look(pier_end + Vector3(0, 4.2, 3.6), pier_end + Vector3(0, -0.5, -7))
	target = pier_end + Vector3(0, 0, -6)
	marker = MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.use("unshaded")
	kit.torus(Vector3.ZERO, 0.5, 0.05, 20, 4, UiTheme.ACCENT)
	marker.mesh = kit.commit()
	add_child(marker)
	# Bring the ducks close.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for a in world.actors:
		if a.species in ["duck", "goose"] and not a.controlled:
			var p := Vector3(pier_end.x + rng.randf_range(-7, 7), 0, pier_end.z - rng.randf_range(3, 9))
			if world.map.is_water(Vector2(p.x, p.z)):
				a.teleport(p)
				a.inside = false
				a.visible = true
	_bread_before = actor.inventory.get("bread", 0)
	world.food_eaten.connect(_on_eaten)
	for i in 3:
		_mark_new()
	score = 0
	time_left = DURATION
	set_info("Ziel bewegen: Maus, WASD oder Knöpfe · Aktion/Klick: Brot werfen")
	add_button("<", func() -> void: target.x -= 1.0, 80)
	add_button("Weiter", func() -> void: target.z -= 1.0, 110)
	add_button("Werfen!", func() -> void: _throw(), 180)
	add_button("Näher", func() -> void: target.z += 1.0, 110)
	add_button(">", func() -> void: target.x += 1.0, 80)


func _mark_new() -> void:
	var options: Array[Actor] = []
	for a in world.actors:
		if a.species == "duck" and not hungry.has(a) and not a.inside and a.distance_to(pier_end) < 25.0:
			options.append(a)
	if options.is_empty():
		return
	var d: Actor = options[randi() % options.size()]
	hungry.append(d)
	var l := Label3D.new()
	l.text = "!"
	l.font_size = 96
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = UiTheme.GOLD
	l.outline_size = 16
	l.position = Vector3(0, d.rig.height + 0.35, 0)
	d.add_child(l)
	marks[d] = l


func _unmark(d: Actor) -> void:
	hungry.erase(d)
	if marks.has(d):
		(marks[d] as Node).queue_free()
		marks.erase(d)


func _on_eaten(eater: Actor, feeder: Actor) -> void:
	if not active or feeder != actor:
		return
	if eater.species == "goose":
		score = maxi(0, score - 1)
		eater.say("Schnatter! Meins!", 1.5)
		set_info("Gustav war schneller! −1")
		Sound.play("fail", eater.global_position, -6.0)
	elif hungry.has(eater):
		score += 1
		eater.emote("heart")
		_unmark(eater)
		_mark_new()
		Sound.play("pickup", eater.global_position, -4.0)
		set_info("Lecker! +1")
	else:
		eater.emote("happy")


func _throw() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = 0.45
	actor.add_item("bread", 1)
	Conversations.throw_bread(actor, target)


func _process(delta: float) -> void:
	if not active:
		return
	time_left -= delta
	_cooldown -= delta
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	target += Vector3(move.x, 0, move.y) * delta * 6.0
	target.x = clampf(target.x, pier_end.x - 14, pier_end.x + 14)
	target.z = clampf(target.z, pier_end.z - 14, pier_end.z - 1.5)
	target.y = ParkLayout.WATER_Y + 0.03
	marker.global_position = target
	actor.face(target)
	set_score("Zeit: %d s  ·  Satte Enten: %d" % [maxi(0, int(time_left)), score])
	# Hungry ducks that wandered off get replaced.
	for d in hungry.duplicate():
		if d.distance_to(pier_end) > 30.0 or d.inside:
			_unmark(d)
			_mark_new()
	if time_left <= 0.0:
		_finish()


func _finish() -> void:
	GameState.set_stat_max("duck_game_best", score)
	var h := host()
	if h:
		h.say("Fein gemacht!" if score >= 8 else "Die Enten danken dir!", 3.0)
	end({"won": score >= 8, "money": score * 20, "joy": 20.0 + score,
		"text": "Du hast %d hungrige Enten satt gemacht!" % score})


func game_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_throw()
	elif event is InputEventMouseMotion and not Controls.touch_mode:
		_aim_at((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var pos := (event as InputEventMouseButton).position
		if not UI.point_blocked(pos):
			_aim_at(pos)
			_throw()


func _aim_at(screen: Vector2) -> void:
	var cam: Camera3D = game.camera
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.01:
		return
	var k := (ParkLayout.WATER_Y - o.y) / d.y
	if k > 0.0:
		var p := o + d * k
		target = Vector3(p.x, target.y, p.z)


func cleanup() -> void:
	if world.food_eaten.is_connected(_on_eaten):
		world.food_eaten.disconnect(_on_eaten)
	for d in hungry.duplicate():
		_unmark(d)
	actor.inventory.erase("bread")
	if _bread_before > 0:
		actor.inventory["bread"] = _bread_before
	if marker:
		marker.queue_free()
		marker = null

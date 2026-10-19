class_name BurgArchery
extends Minigame
## Bogenschießen with Ritterin Adelheid (doc/burg.md): five arrows at the middle target 36 m
## away. The crosshair wanders over the target; "Schießen!" (Aktion) lets the arrow fly, the wind
## from the flag pushes it. Rings 10, 8, 6, 4, 2; 0,20 € per point. Three bullseyes in one round:
## "Ins Schwarze".

const ARROWS := 5
const RINGS := [0.12, 0.24, 0.36, 0.48, 0.6]
const POINTS := [10, 8, 6, 4, 2]

var center := Vector3.ZERO
var stand := Vector3.ZERO
var arrows_left := ARROWS
var score := 0
var bullseyes := 0
var state := "aim"
var t := 0.0
var aim := Vector2.ZERO
var wind := 0.0
var crosshair: MeshInstance3D
var flying: Node3D
var stuck: Array[Node3D] = []
var last_points := -1
var _fly_from := Vector3.ZERO
var _fly_to := Vector3.ZERO
var _fly_t := 0.0
var pace := 1.0


func _init() -> void:
	title = "Bogenschießen"
	host_id = "adelheid"
	cost = 100


func describe() -> String:
	return "Fünf Pfeile auf die Zielscheibe am Turnierplatz. Drei Mal ins Schwarze in einer Runde! Einsatz 1 €."


func goal_done() -> bool:
	return GameState.stat("archery_bullseyes") >= 3


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.burg != null


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Bogenschießen (%s)" % GameState.format_money(cost)


func begin() -> void:
	var tp := BurgLayout.place("archery_targets")
	center = Vector3(tp.x, world.map.height_at(tp.x, tp.y) + 1.25, tp.y + 0.12)
	var sp := BurgLayout.place("archery")
	stand = Vector3(sp.x, world.map.walk_height(sp.x, sp.y), sp.y - 1.6)
	actor.teleport(stand)
	actor.face(center, true)
	actor.set_item("bow")
	var h := host()
	if h:
		h.teleport(stand + Vector3(2.4, 0, 1.0))
		h.face(center)
	# Close to the target (36 m away it would be a dot): the arrow flies in from behind.
	look(center + Vector3(1.4, 0.5, 8.5), center + Vector3(0, -0.1, 0))
	crosshair = MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.use("glow")
	kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	kit.torus(Vector3.ZERO, 0.1, 0.02, 14, 3, Color("ff3b30"))
	kit.pop()
	crosshair.mesh = kit.commit()
	add_child(crosshair)
	arrows_left = ARROWS
	score = 0
	bullseyes = 0
	stuck.clear()
	host_say("Ruhig atmen. Dann loslassen.", 3.0)
	set_info("Das Fadenkreuz wandert über die Scheibe. „Schießen!“ (Aktion) – die Fahne zeigt, woher der Wind weht.")
	add_button("Schießen!", func() -> void: shoot(), 220)
	_next()


func _next() -> void:
	state = "aim"
	t = rng.randf() * 10.0
	wind = rng.randf_range(-0.15, 0.15)
	_update_score()


func _update_score() -> void:
	var w := "Wind: %s %d" % ["von rechts" if wind < 0.0 else "von links", int(absf(wind) * 100.0)] if absf(wind) > 0.02 else "Kein Wind"
	set_score("Punkte: %d  ·  Pfeile: %d  ·  %s" % [score, arrows_left, w])


func _on_target(off: Vector2) -> Vector3:
	return center + Vector3(off.x, off.y, 0)


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	match state:
		"aim":
			var speed := (1.0 + (ARROWS - arrows_left) * 0.1) * pace
			# 2 : 3 – the crosshair passes the middle every few seconds.
			aim = Vector2(sin(t * 1.6 * speed) * 0.5, sin(t * 2.4 * speed) * 0.42)
			crosshair.visible = true
			crosshair.global_position = _on_target(aim) + Vector3(0, 0, 0.05)
		"flying":
			_fly_t += delta / 0.9
			var k := clampf(_fly_t, 0.0, 1.0)
			var pos := _fly_from.lerp(_fly_to, k) + Vector3(0, sin(k * PI) * 1.2, 0)
			var ahead := _fly_from.lerp(_fly_to, minf(k + 0.05, 1.0)) + Vector3(0, sin(minf(k + 0.05, 1.0) * PI) * 1.2, 0) - pos
			flying.global_position = pos
			if ahead.length() > 0.01:
				flying.global_transform = Transform3D(Basis.looking_at(ahead, Vector3.UP), pos)
			if k >= 1.0:
				_land()


func shoot() -> void:
	if state != "aim" or not active:
		return
	state = "flying"
	crosshair.visible = false
	var hit := aim + Vector2(wind, 0) + Vector2(rng.randf_range(-0.025, 0.025), rng.randf_range(-0.025, 0.025))
	_fly_from = actor.global_position + Vector3(0.2, 1.5, -0.4)
	_fly_to = _on_target(hit)
	_fly_t = 0.0
	flying = Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = PropModels.item("arrow")
	mi.rotation.y = PI
	flying.add_child(mi)
	add_child(flying)
	flying.set_meta("hit", hit)
	actor.play_anim("throw", 0.5)
	Sound.play("whistle", actor.global_position, -6.0)


func points_for(off: Vector2) -> int:
	var d := off.length()
	for i in RINGS.size():
		if d <= RINGS[i]:
			return POINTS[i]
	return 0


func _land() -> void:
	var hit: Vector2 = flying.get_meta("hit")
	last_points = points_for(hit)
	score += last_points
	arrows_left -= 1
	if last_points == 10:
		bullseyes += 1
	if last_points > 0:
		stuck.append(flying)
		Sound.play("hit", center)
		host_say(["Ins Schwarze!", "Gut gezielt!", "Getroffen!"][0 if last_points == 10 else (1 if last_points >= 6 else 2)], 1.8)
	else:
		flying.queue_free()
		Sound.play("click", center)
		host_say("Vorbei! Der Wind war schuld.", 1.8)
	flying = null
	if arrows_left <= 0:
		state = "done"
		_update_score()
		GameState.set_stat_max("archery_bullseyes", bullseyes)
		GameState.set_stat_max("archery_best", score)
		end_after(1.4, {"won": score >= 30, "money": score * 20, "joy": 18.0 if score >= 30 else 10.0,
			"text": "%d Punkte, %d Mal ins Schwarze. %s" % [score, bullseyes, "Adelheid nickt anerkennend." if score >= 30 else "„Der Bogen will geübt sein“, sagt Adelheid."]})
	else:
		_next()


func cleanup() -> void:
	for n in stuck:
		if is_instance_valid(n):
			n.queue_free()
	stuck.clear()
	if crosshair:
		crosshair.queue_free()
		crosshair = null
	if is_instance_valid(flying):
		flying.queue_free()
	actor.set_item("")


func game_input(event: InputEvent) -> void:
	if primary_pressed(event):
		shoot()

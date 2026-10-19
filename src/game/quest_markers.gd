class_name QuestMarkers
extends Node3D
## Soft glowing rings on the ground that point out what can be done nearby: quest
## givers with an open quest and unfound garden gnomes (gold), minigames not yet
## mastered (light blue; a driving job's ring lies under its vehicle, as big as the vehicle).
## Only near the player, fading in from FADE_FAR to FADE_NEAR.

const QUEST := Color(1.0, 0.82, 0.3)
const GAME := Color(0.55, 0.85, 1.0)
const FADE_FAR := 18.0
const FADE_NEAR := 12.0

var game: Game
var world: World
var _rings: Array[MeshInstance3D] = []
var _material: ShaderMaterial
var _refresh := 0.0
var _targets: Array[Dictionary] = []
var _t := 0.0


func setup(g: Game) -> void:
	game = g
	world = g.world
	name = "QuestMarkers"
	world.add_child(self)
	_material = ShaderMaterial.new()
	_material.shader = load("res://src/shaders/quest_ring.gdshader")


## Everything worth a ring for `player` (any distance): {"pos", "color", "radius", "what", "node"}
## (the ring follows `node`, a person or a vehicle).
func targets(player: Actor) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player == null or Gameplay.any_active():
		return out
	var ringed := {}   # one ring per person, also when two modules have a quest for them
	for m in Gameplay.modules:
		for id: String in m.quest_givers():
			var npc := world.find_actor(id)
			if not ringed.has(id) and _present(npc, player) and m.has_quest(player, npc):
				ringed[id] = true
				out.append(_ring(npc.global_position, QUEST, 0.75, id, npc))
	for id: String in Gameplay.eggs.gnome_spots:
		if not GameState.has_in_set("gnomes", id):
			out.append(_ring(Gameplay.eggs.gnome_spots[id], QUEST, 0.55, id))
	if player.is_human():
		for id: String in Gameplay.minigames:
			var m: Minigame = Gameplay.minigames[id]
			if m.goal_done() or not m.host_available():
				continue
			var job := m as DriveJob
			if job and job.vehicle_kind != "":
				# The job goes with its vehicle (once the order is taken, where there is one).
				if not job.needs_order or job.order_for == player:
					for c in _job_cars(job, player):
						out.append(_ring(c.global_position, GAME, c.length() * 0.5 + 0.6, id, c))
					continue
			elif Gameplay.game_spots.has(id):
				out.append(_ring(Gameplay.game_spots[id], GAME, 0.9, id))
				continue
			if _present(m.host(), player):
				out.append(_ring(m.host().global_position, GAME, 0.75, id, m.host()))
	return out


func _present(a: Actor, player: Actor) -> bool:
	return a != null and a != player and not a.inside and a.visible and not a.controlled


## The town's vehicles for `job` (not the one the player drives: the prompt shows the job there).
func _job_cars(job: DriveJob, player: Actor) -> Array[Car]:
	var out: Array[Car] = []
	if world.city:
		for c in world.city.cars:
			if c.job != "" and c.kind == job.vehicle_kind and c != player.vehicle and is_instance_valid(c):
				out.append(c)
	return out


func _ring(pos: Vector3, color: Color, radius: float, what: String, node: Node3D = null) -> Dictionary:
	return {"pos": pos, "color": color, "radius": radius, "what": what, "node": node}


func _process(delta: float) -> void:
	_t += delta
	var player: Actor = game.player.actor if game.player else null
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		_targets = []
		if player:
			for t: Dictionary in targets(player):
				if player.global_position.distance_to(t["pos"]) < FADE_FAR:
					_targets.append(t)
	# Rings follow walking NPCs and moving vehicles between refreshes.
	for t: Dictionary in _targets:
		if t["node"] and is_instance_valid(t["node"]):
			t["pos"] = (t["node"] as Node3D).global_position
	while _rings.size() < _targets.size():
		var r := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		q.size = Vector2(2, 2)
		r.mesh = q
		r.material_override = _material.duplicate()
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(r)
		_rings.append(r)
	for i in _rings.size():
		var r := _rings[i]
		r.visible = i < _targets.size()
		if not r.visible:
			continue
		var t := _targets[i]
		var p: Vector3 = t["pos"]
		var radius: float = t["radius"]
		r.position = Vector3(p.x, world.map.walk_height(p.x, p.z) + 0.06, p.z)
		r.scale = Vector3.ONE * radius * (1.0 + 0.06 * sin(_t * 2.4))
		var d := player.global_position.distance_to(p) if player else FADE_FAR
		var fade := clampf((FADE_FAR - d) / (FADE_FAR - FADE_NEAR), 0.0, 1.0)
		var mat := r.material_override as ShaderMaterial
		mat.set_shader_parameter("color", t["color"])
		mat.set_shader_parameter("strength", fade * (0.75 + 0.25 * sin(_t * 2.4)))

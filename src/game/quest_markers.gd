class_name QuestMarkers
extends Node3D
## Soft glowing rings on the ground that point out what can be done nearby: quest
## givers with an open quest and unfound garden gnomes (gold), minigames not yet
## mastered (light blue). Only near the player, fading in from FADE_FAR to FADE_NEAR.

const QUEST := Color(1.0, 0.82, 0.3)
const GAME := Color(0.55, 0.85, 1.0)
const FADE_FAR := 18.0
const FADE_NEAR := 12.0
const QUEST_NPCS := ["mia", "pierre", "lena", "bruno", "grimbart", "brakka", "nori", "thrain"]

var game: Node
var world: World
var _rings: Array[MeshInstance3D] = []
var _material: ShaderMaterial
var _refresh := 0.0
var _targets: Array[Dictionary] = []
var _t := 0.0


func setup(g: Node) -> void:
	game = g
	world = g.world
	name = "QuestMarkers"
	world.add_child(self)
	_material = ShaderMaterial.new()
	_material.shader = load("res://src/shaders/quest_ring.gdshader")


## Everything worth a ring for `player` (any distance): {"pos", "color", "radius", "what", "actor"}.
func targets(player: Actor) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player == null or Gameplay.any_active():
		return out
	for id: String in QUEST_NPCS:
		var npc := world.find_actor(id)
		if _present(npc, player) and (not Gameplay.quests._options(player, npc).is_empty()
				or not Gameplay.dwarves.options(player, npc).is_empty()):
			out.append(_ring(npc.global_position, QUEST, 0.75, id, npc))
	for id: String in Gameplay.eggs.gnome_spots:
		if not GameState.has_in_set("gnomes", id):
			out.append(_ring(Gameplay.eggs.gnome_spots[id], QUEST, 0.55, id))
	if player.is_human():
		for id: String in Gameplay.minigames:
			var m: Minigame = Gameplay.minigames[id]
			if Gameplay.minigame_done(id) or not m.host_available():
				continue
			if Gameplay.game_spots.has(id):
				out.append(_ring(Gameplay.game_spots[id], GAME, 0.9, id))
			elif _present(m.host(), player):
				out.append(_ring(m.host().global_position, GAME, 0.75, id, m.host()))
	return out


func _present(a: Actor, player: Actor) -> bool:
	return a != null and a != player and not a.inside and a.visible and not a.controlled


func _ring(pos: Vector3, color: Color, radius: float, what: String, actor: Actor = null) -> Dictionary:
	return {"pos": pos, "color": color, "radius": radius, "what": what, "actor": actor}


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
	# Rings follow walking NPCs between refreshes.
	for t: Dictionary in _targets:
		if t["actor"] and is_instance_valid(t["actor"]):
			t["pos"] = (t["actor"] as Actor).global_position
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

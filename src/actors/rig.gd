class_name Rig
extends Node3D
## Base for procedural character rigs: skeleton access, smoothed posing,
## emote icons, speech bubbles and held items.

var skel: Skeleton3D
var height := 1.75                      # top of the head, for bubbles
var idx := {}                           # bone name -> index
var rest := {}                          # bone index -> rest origin
var hand_bone := "hand_r"
var item_id := ""
var phase := 0.0
var lod := 0                            # 0 full, 1 reduced, 2 culled
var time := 0.0

var _target := {}                       # bone -> Vector3 euler
var _current := {}
var _pos_target := {}                   # bone -> Vector3 offset
var _pos_current := {}
var _scale := {}                        # bone -> Vector3 scale
var _held: MeshInstance3D
var _attach: BoneAttachment3D
var _emotes: Array = []                 # [{node, age}]
var _speech: Label3D
var _speech_time := 0.0
var _accum := 0.0


func _init_skeleton(s: Skeleton3D) -> void:
	skel = s
	add_child(skel)
	for i in skel.get_bone_count():
		idx[skel.get_bone_name(i)] = i
		rest[i] = skel.get_bone_rest(i).origin
	(skel.get_node("Body") as MeshInstance3D).visibility_range_end = 140.0


func has_bone(name: String) -> bool:
	return idx.has(name)


## Target rotation (euler, radians) for a bone this frame.
func rot(bone: String, euler: Vector3) -> void:
	_target[bone] = euler


func add_rot(bone: String, euler: Vector3) -> void:
	_target[bone] = _target.get(bone, Vector3.ZERO) + euler


func offset(bone: String, v: Vector3) -> void:
	_pos_target[bone] = v


func set_bone_scale(bone: String, s: Vector3) -> void:
	if idx.has(bone):
		_scale[bone] = s
		skel.set_bone_pose_scale(idx[bone], s)


func clear_pose() -> void:
	_target.clear()
	_pos_target.clear()


## Applies the targets with smoothing; `sharpness` ~ 1/seconds.
func apply_pose(delta: float, sharpness := 12.0) -> void:
	var k := clampf(delta * sharpness, 0.0, 1.0)
	for bone: String in idx:
		var tgt: Vector3 = _target.get(bone, Vector3.ZERO)
		var cur: Vector3 = _current.get(bone, Vector3.ZERO)
		cur = cur.lerp(tgt, k)
		_current[bone] = cur
		var i: int = idx[bone]
		skel.set_bone_pose_rotation(i, Quaternion.from_euler(cur))
		var pt: Vector3 = _pos_target.get(bone, Vector3.ZERO)
		var pc: Vector3 = _pos_current.get(bone, Vector3.ZERO)
		pc = pc.lerp(pt, k)
		_pos_current[bone] = pc
		skel.set_bone_pose_position(i, rest[i] + pc)


## Snap to the current targets (after teleporting, sitting down...).
func snap_pose() -> void:
	apply_pose(1.0, 1.0)


# --- Items -------------------------------------------------------------------

func set_item(id: String, local := Transform3D.IDENTITY) -> void:
	if id == item_id:
		return
	item_id = id
	if _attach == null:
		_attach = BoneAttachment3D.new()
		_attach.bone_name = hand_bone
		skel.add_child(_attach)
		_held = MeshInstance3D.new()
		_attach.add_child(_held)
	if id == "":
		_held.visible = false
		return
	_held.visible = true
	_held.mesh = PropModels.item(id)
	_held.transform = local


# --- Emotes and speech -----------------------------------------------------------

func emote(icon: String, count := 1) -> void:
	if lod >= 2:
		return
	for i in count:
		var s := Sprite3D.new()
		s.texture = EmoteIcons.get_icon(icon)
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = 0.006
		s.no_depth_test = false
		s.shaded = false
		s.position = Vector3(randf_range(-0.2, 0.2), height + 0.25 + i * 0.25, randf_range(-0.2, 0.2))
		add_child(s)
		_emotes.append({"node": s, "age": -i * 0.35})


func emote_text(text: String, color := Color.WHITE) -> void:
	if lod >= 2:
		return
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 72
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_size = 12
	l.position = Vector3(0.25, height + 0.2, 0)
	add_child(l)
	_emotes.append({"node": l, "age": 0.0})


func say(text: String, duration := 3.5) -> void:
	if _speech == null:
		_speech = Label3D.new()
		_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_speech.font_size = 42
		_speech.pixel_size = 0.0045
		_speech.outline_size = 14
		_speech.outline_modulate = Color(0.1, 0.1, 0.12, 0.9)
		_speech.modulate = Color(1, 1, 1)
		_speech.width = 420.0
		_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_speech.position = Vector3(0, height + 0.45, 0)
		_speech.no_depth_test = true
		_speech.render_priority = 5
		add_child(_speech)
	_speech.text = text
	_speech.visible = true
	_speech_time = duration


func is_speaking() -> bool:
	return _speech_time > 0.0


func _update_overlays(delta: float) -> void:
	for i in range(_emotes.size() - 1, -1, -1):
		var e: Dictionary = _emotes[i]
		e["age"] += delta
		var node: Node3D = e["node"]
		var age: float = e["age"]
		node.visible = age >= 0.0
		if age > 0.0:
			node.position.y += delta * 0.45
			var alpha := clampf(2.2 - age, 0.0, 1.0)
			if node is Sprite3D:
				(node as Sprite3D).modulate.a = alpha
			elif node is Label3D:
				(node as Label3D).modulate.a = alpha
		if age > 2.2:
			node.queue_free()
			_emotes.remove_at(i)
	if _speech_time > 0.0:
		_speech_time -= delta
		if _speech_time <= 0.0 and _speech:
			_speech.visible = false


## Called by the actor every frame. `st` describes the desired pose.
func animate(delta: float, st: Dictionary) -> void:
	time += delta
	_update_overlays(delta)
	if lod >= 2:
		return
	if lod == 1:
		# Reduced update rate for distant characters.
		_accum += delta
		if _accum < 0.1:
			return
		delta = _accum
	_accum = 0.0
	clear_pose()
	pose(delta, st)
	apply_pose(delta, st.get("sharpness", 10.0))


## Override: set rot/offset targets for the given state.
func pose(_delta: float, _st: Dictionary) -> void:
	pass

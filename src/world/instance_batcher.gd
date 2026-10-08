class_name InstanceBatcher
extends RefCounted
## Collects many copies of the same mesh and emits chunked MultiMeshInstance3Ds,
## so identical props/plants cost one draw call per chunk while staying cullable.

var chunk_size := 60.0
var _groups := {}   # key -> {mesh, shadow, range, chunks: {Vector2i: Array[Transform3D]}, handles: {Vector2i: Array[int]}}
var _next_handle := 0
## After build: handle -> [MultiMesh, index, Transform3D], to hide single instances (felled trees).
var instances := {}


func _init(size := 60.0) -> void:
	chunk_size = size


## Adds an instance; returns a handle for set_instance_visible() after build().
func add(mesh: Mesh, xform: Transform3D, shadow := true, visibility_end := 0.0) -> int:
	var key := "%d_%s_%d" % [mesh.get_instance_id(), shadow, int(visibility_end)]
	if not _groups.has(key):
		_groups[key] = {"mesh": mesh, "shadow": shadow, "range": visibility_end, "chunks": {}, "handles": {}}
	var g: Dictionary = _groups[key]
	var c := Vector2i(int(floor(xform.origin.x / chunk_size)), int(floor(xform.origin.z / chunk_size)))
	if not g["chunks"].has(c):
		g["chunks"][c] = []
		g["handles"][c] = []
	g["chunks"][c].append(xform)
	_next_handle += 1
	g["handles"][c].append(_next_handle)
	return _next_handle


func build(parent: Node3D, name := "Batch") -> void:
	var root := Node3D.new()
	root.name = name
	parent.add_child(root)
	for key: String in _groups:
		var g: Dictionary = _groups[key]
		for c: Vector2i in g["chunks"]:
			var xforms: Array = g["chunks"][c]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = g["mesh"]
			mm.instance_count = xforms.size()
			var handles: Array = g["handles"][c]
			for i in xforms.size():
				mm.set_instance_transform(i, xforms[i])
				instances[handles[i]] = [mm, i, xforms[i]]
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if g["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if g["range"] > 0.0:
				mmi.visibility_range_end = g["range"]
				mmi.visibility_range_end_margin = 8.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			root.add_child(mmi)
	_groups.clear()


func set_instance_visible(handle: int, on: bool) -> void:
	var e: Array = instances.get(handle, [])
	if e.is_empty():
		return
	var xf: Transform3D = e[2]
	(e[0] as MultiMesh).set_instance_transform(e[1], xf if on else xf.scaled_local(Vector3(0.001, 0.001, 0.001)))

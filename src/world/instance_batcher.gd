class_name InstanceBatcher
extends RefCounted
## Collects many copies of the same mesh and emits chunked MultiMeshInstance3Ds,
## so identical props/plants cost one draw call per chunk while staying cullable.

var chunk_size := 60.0
var _groups := {}   # key -> {mesh, shadow, range, chunks: {Vector2i: Array[Transform3D]}}


func _init(size := 60.0) -> void:
	chunk_size = size


func add(mesh: Mesh, xform: Transform3D, shadow := true, visibility_end := 0.0) -> void:
	var key := "%d_%s_%d" % [mesh.get_instance_id(), shadow, int(visibility_end)]
	if not _groups.has(key):
		_groups[key] = {"mesh": mesh, "shadow": shadow, "range": visibility_end, "chunks": {}}
	var g: Dictionary = _groups[key]
	var c := Vector2i(int(floor(xform.origin.x / chunk_size)), int(floor(xform.origin.z / chunk_size)))
	if not g["chunks"].has(c):
		g["chunks"][c] = []
	g["chunks"][c].append(xform)


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
			for i in xforms.size():
				mm.set_instance_transform(i, xforms[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if g["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if g["range"] > 0.0:
				mmi.visibility_range_end = g["range"]
				mmi.visibility_range_end_margin = 8.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			root.add_child(mmi)
	_groups.clear()

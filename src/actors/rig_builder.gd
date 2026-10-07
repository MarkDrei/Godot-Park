class_name RigBuilder
extends RefCounted
## Builds a Skeleton3D plus one rigidly skinned mesh. Bones have identity rest
## rotations, so poses are plain rotations around each bone's joint.

var skel := Skeleton3D.new()
var kit := MeshKit.new(true)
var bones := {}        # name -> index
var origins := {}      # name -> model-space joint position


func _init() -> void:
	kit.use("character")


func bone(name: String, parent: String, origin: Vector3) -> int:
	var idx := skel.add_bone(name)
	var parent_origin := Vector3.ZERO
	if parent != "":
		skel.set_bone_parent(idx, bones[parent])
		parent_origin = origins[parent]
	skel.set_bone_rest(idx, Transform3D(Basis(), origin - parent_origin))
	bones[name] = idx
	origins[name] = origin
	return idx


## Subsequent geometry is bound to this bone.
func on(name: String) -> MeshKit:
	kit.bone = bones[name]
	return kit


func finish() -> Skeleton3D:
	skel.reset_bone_poses()
	var skin := Skin.new()
	for name: String in bones:
		skin.add_named_bind(name, Transform3D(Basis(), -origins[name]))
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = kit.commit()
	mi.skin = skin
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	return skel

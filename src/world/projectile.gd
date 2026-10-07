class_name Projectile
extends Node3D
## A thrown item flying along an arc (frisbee, coin, bread). Lands and lingers.

var from := Vector3.ZERO
var to := Vector3.ZERO
var duration := 1.0
var arc := 2.0
var t := 0.0
var linger := 6.0
var spin := 0.0
var landed := false

signal landed_at(pos: Vector3)


static func throw_item(world: World, item_id: String, start: Vector3, target: Vector3, secs := 1.0, height := 2.0, stay := 6.0) -> Projectile:
	var p := Projectile.new()
	p.from = start
	var ty := world.map.walk_height(target.x, target.z)
	if world.map.is_water(Vector2(target.x, target.z)):
		ty = ParkLayout.WATER_Y
	p.to = Vector3(target.x, ty + 0.05, target.z)
	p.duration = secs
	p.arc = height
	p.linger = stay
	p.spin = 12.0 if item_id == "frisbee" else 4.0
	var mi := MeshInstance3D.new()
	mi.mesh = PropModels.item(item_id)
	p.add_child(mi)
	p.add_to_group("projectiles")
	world.add_child(p)
	p.global_position = start
	return p


static func clear_landed(world: World, near: Vector3) -> void:
	for n in world.get_tree().get_nodes_in_group("projectiles"):
		var p := n as Projectile
		if p.landed and p.global_position.distance_to(near) < 3.0:
			p.queue_free()


func _process(delta: float) -> void:
	if not landed:
		t += delta / duration
		var k := clampf(t, 0.0, 1.0)
		global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * arc, 0)
		rotation.y += spin * delta
		if k >= 1.0:
			landed = true
			landed_at.emit(global_position)
	else:
		linger -= delta
		if linger <= 0.0:
			queue_free()

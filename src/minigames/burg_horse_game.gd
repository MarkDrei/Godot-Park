class_name BurgHorseGame
extends Minigame
## The tournament's riding games at the Ritterburg (doc/burg.md): the player rides one of the
## castle's horses down the lists with a lance. The horses are the paddock's (Cast.BURG_ANIMALS),
## taken out of their brains while the game uses them ("ridden") and put back after.
## Subclasses decide what happens on the way (Tjost, Ringstechen). The riders' lances are not
## hand items but meshes the game points (point_lance): couched under the right arm, the tip
## where the game wants it, so what the player sees is what counts.

## The lanes either side of the tilt (z) and the ends of the lists (x).
const LANE_S := -116.4
const LANE_N := -119.6
const X0 := -320.0
const X1 := -256.0
## Where the rider's feet go above the horse's (sit poses lower the hips to the saddle).
const SADDLE := 1.1

## The lance's length from the grip to the tip (PropModels "lance").
const LANCE := 3.0

var _horses: Array[Actor] = []
var _lances := {}               # rider -> MeshInstance3D


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.burg != null and world.burg.show_t < 0.0


func host_available() -> bool:
	return world.burg != null and super()


func lane(x: float, z: float) -> Vector3:
	return Vector3(x, world.map.walk_height(x, z), z)


## Takes a horse out of the paddock for the game.
func take_horse(id: String) -> Actor:
	var h := world.find_actor(id)
	if h == null:
		return null
	h.inside = false
	h.visible = true
	h.stop_moving()
	h.custom_motion = true
	(h.brain as AnimalBrain).state = "ridden"
	_horses.append(h)
	return h


## The horse and its rider at p, facing yaw, going `speed` m/s (the legs follow the speed).
func ride(rider: Actor, h: Actor, p: Vector3, yaw: float, speed: float) -> void:
	h.global_position = p
	h.yaw = yaw
	h.rotation.y = yaw
	h.velocity = Vector3(sin(yaw), 0, cos(yaw)) * speed
	if rider:
		rider.custom_motion = true
		rider.global_transform = Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, SADDLE, 0))
		rider.yaw = yaw
		rider.velocity = Vector3.ZERO
		rider.anim = "ride"


## Gives the rider a lance the game points (point_lance); takes the hand item away.
func give_lance(rider: Actor) -> MeshInstance3D:
	rider.set_item("")
	var mi := MeshInstance3D.new()
	mi.name = "Lance"
	mi.mesh = PropModels.item("lance")
	add_child(mi)
	_lances[rider] = mi
	return mi


## Where the rider holds the lance: under the right arm, in front of the saddle.
func lance_grip(rider: Actor) -> Vector3:
	var f := Vector3(sin(rider.yaw), 0, cos(rider.yaw))
	var r := Vector3(cos(rider.yaw), 0, -sin(rider.yaw))
	return rider.global_position + Vector3(0, 0.9, 0) + f * 0.35 + r * 0.22


## Points the rider's lance from the grip at `target`; `reach` pushes it forward (a thrust).
## Returns the tip.
func point_lance(rider: Actor, target: Vector3, reach := 0.0) -> Vector3:
	var mi: MeshInstance3D = _lances.get(rider)
	var grip := lance_grip(rider)
	var dir := (target - grip).normalized()
	if mi:
		mi.global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), grip + dir * reach)
	return grip + dir * (LANCE + reach)


func drop_lances() -> void:
	for mi: MeshInstance3D in _lances.values():
		if is_instance_valid(mi):
			mi.queue_free()
	_lances.clear()


## Back to the paddock: the horses graze again, the riders stand beside the lists.
func release_horses() -> void:
	for h in _horses:
		if not is_instance_valid(h):
			continue
		h.custom_motion = false
		h.velocity = Vector3.ZERO
		(h.brain as AnimalBrain).state = "idle"
		var home: Array = h.def.get("home", [])
		if home.size() == 2:
			h.teleport(Vector3(home[0], world.map.walk_height(home[0], home[1]), home[1]))
	_horses.clear()


func dismount(rider: Actor, at: Vector3) -> void:
	if not is_instance_valid(rider):
		return
	rider.custom_motion = false
	rider.anim = "idle"
	rider.set_item("")
	rider.rotation = Vector3(0, rider.yaw, 0)
	rider.teleport(at)

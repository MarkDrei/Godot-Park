class_name BurgHorseGame
extends Minigame
## The tournament's riding games at the Ritterburg (doc/burg.md): the player rides one of the
## castle's horses down the lists with a lance. The horses are the paddock's (Cast.BURG_ANIMALS),
## taken out of their brains while the game uses them ("ridden") and put back after.
## Subclasses decide what happens on the way (Tjost, Ringstechen).

## The lanes either side of the tilt (z) and the ends of the lists (x).
const LANE_S := -116.4
const LANE_N := -119.6
const X0 := -320.0
const X1 := -256.0
## Where the rider's feet go above the horse's (sit poses lower the hips to the saddle).
const SADDLE := 1.1

var _horses: Array[Actor] = []


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

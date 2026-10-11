class_name Ride
extends Minigame
## A ride at the Kirmes (doc/kirmes.md): pay, sit in, the camera rides along, joy and a stamp
## for the stamp card at the end. Subclasses move the ride (through the Fair node) and say
## where the rider sits (mount()) and where the camera is (camera_pose()).

var ride_id := ""            # stamp id (FairPass.STAMPS)
var duration := 30.0         # seconds; a subclass may end earlier or later with finish()
var joy := 30.0
var t := 0.0
var exit_spot := Vector3.ZERO
var rides_along := true      # the rider sits still on the ride, the camera rides with them
var _finishing := false


func fair() -> Fair:
	return world.fair


## Open from 10:00 to midnight, and only when its operator (if any) is there.
func open_now() -> bool:
	var h := Clock.hour()
	return h >= 10.0 and world.fair != null


func host_available() -> bool:
	return open_now() and super()


func unavailable_text() -> String:
	return "geschlossen" if not open_now() else super()


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.fair != null


func begin() -> void:
	t = 0.0
	_finishing = false
	exit_spot = actor.global_position
	if rides_along:
		actor.custom_motion = true
		actor.anim = "sit"
	ride_begin()
	if rides_along:
		_place_rider()
	set_info(info_text())
	show_power(0.0)


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	ride_update(delta)
	if not active:
		return   # the ride ended in ride_update: the rider is off it, the camera follows again
	if rides_along:
		_place_rider()
		var cam: Array = camera_pose()
		look(cam[0], cam[1])
	show_power(progress())
	if t >= duration and not _finishing:
		finish()


## 0..1 for the bar under the title: how much of the ride is done.
func progress() -> float:
	return clampf(t / duration, 0.0, 1.0)


## The ride is over: off the ride, joy, the stamp.
func finish() -> void:
	if _finishing:
		return
	_finishing = true
	end({"won": true, "joy": joy, "text": end_text()})


func cleanup() -> void:
	ride_end()
	if actor:
		actor.custom_motion = false
		actor.anim = "idle"
		actor.rotation = Vector3(0, actor.yaw, 0)   # upright again (a coaster car tilts its rider)
		actor.teleport(exit_spot)
		game.camera.follow(actor, false)
	if t >= duration * 0.5 or _finishing:
		FairPass.rode(ride_id)


func _place_rider() -> void:
	var xf: Transform3D = mount()
	actor.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
	actor.yaw = actor.rotation.y
	actor.anim = rider_anim()


# --- Override --------------------------------------------------------------------------

func ride_begin() -> void:
	pass


func ride_update(_delta: float) -> void:
	pass


func ride_end() -> void:
	pass


## Where the rider's hips go (the actor's origin is at its feet; sit poses lower the hips).
func mount() -> Transform3D:
	return Transform3D(Basis(), exit_spot)


## [eye, target] of the camera.
func camera_pose() -> Array:
	return [exit_spot + Vector3(0, 6, 8), exit_spot]


func rider_anim() -> String:
	return "sit"


func info_text() -> String:
	return "Lehn dich zurück und genieß die Fahrt!"


func end_text() -> String:
	return "Was für eine Fahrt!"

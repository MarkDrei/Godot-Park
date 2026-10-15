class_name BoothGame
extends Minigame
## A game at a booth of the Kirmes (doc/kirmes.md): the player stands at the counter, the
## camera looks over the shoulder into the booth, the host calls out. It pays out tickets (the
## Kirmes's second currency, redeemed at the prize counter) and stamps the stamp card.

var booth := ""              # FairBuilder.BOOTHS kind (and stamp id)
var tickets := 0             # won in this round
var pace := 1.0              # how fast markers and bars move (tests slow them down)
var _root: Node3D            # the game's own things (freed in cleanup)
var _host_moved := false     # the host stepped aside for the game (back to the post after it)


func fair() -> Fair:
	return world.fair


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.fair != null


func host_available() -> bool:
	return Fair.open_now(world) and super()


func unavailable_text() -> String:
	return "geschlossen" if not Fair.open_now(world) else super()


func begin() -> void:
	tickets = 0
	pace = 1.0
	# The player stands at the left end of the counter, the camera looks past them into the booth.
	actor.teleport(lp(-1.5, 0, 1.95))
	actor.face(lp(-0.6, 0, -1.0), true)
	_root = Node3D.new()
	_root.name = "BoothGame_" + booth
	add_child(_root)
	_show_deco(false)
	move_host_aside()
	booth_begin()
	var cam := camera()
	look(cam[0], cam[1])


## [eye, target] of the camera: over the player's shoulder into the booth.
func camera() -> Array:
	return [lp(0.7, 2.0, 4.2), lp(0.15, 1.3, -0.5)]


## Where the host waits during the game: outside beside the booth, out of the picture (in
## the booth they stood right between the player and the targets).
func host_spot() -> Vector3:
	return lp(3.4, 0, 2.3)


func move_host_aside() -> void:
	_host_moved = false
	var h := host()
	var post: Array = fair().posts.get(booth, [])
	if h == null or post.is_empty() or h.global_position.distance_to(post[0]) > 3.0:
		return
	h.stop_moving()
	h.teleport(host_spot())
	h.face(actor.global_position, true)
	_host_moved = true


func _host_back() -> void:
	var h := host()
	var post: Array = fair().posts.get(booth, []) if world.fair else []
	if not _host_moved or h == null or post.is_empty():
		return
	_host_moved = false
	var p: Vector3 = post[0]
	h.teleport(p)
	h.face(p + Vector3(sin(post[1]), 0, cos(post[1])), true)


## The booth's forward (towards the customer) and right, and a point in its own frame
## (x right, y up from the ground, z towards the customer; the counter is at z 1.4).
func fwd() -> Vector3:
	var yaw: float = fair().booths[booth]["yaw"]
	return Vector3(sin(yaw), 0, cos(yaw))


func right() -> Vector3:
	var yaw: float = fair().booths[booth]["yaw"]
	return Vector3(cos(yaw), 0, -sin(yaw))


func center() -> Vector3:
	var b: Dictionary = fair().booths[booth]
	return (b["pos"] as Vector3) - fwd() * 2.4


func lp(x: float, y: float, z: float) -> Vector3:
	var c := center()
	return Vector3(c.x, world.map.height_at(c.x, c.z), c.z) + right() * x + Vector3.UP * y + fwd() * z


func basis() -> Basis:
	var yaw: float = fair().booths[booth]["yaw"]
	return Basis(Vector3.UP, yaw)


func add_prop(mesh: Mesh, p: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(basis(), p)
	_root.add_child(mi)
	return mi


## Ends the round after a moment: tickets, stamp, the result dialog.
func finish_round(text: String, won: bool, delay := 1.4) -> void:
	if tickets > 0:
		text += "\n\nDu gewinnst %d Ticket%s." % [tickets, "" if tickets == 1 else "s"]
	end_after(delay, {"won": won, "joy": 12.0 + tickets * 1.5, "text": text, "tickets": tickets})


func end(result: Dictionary) -> void:
	if active:
		var n: int = result.get("tickets", 0)
		if n > 0:
			GameState.add_tickets(n, title)
		if result.has("tickets"):
			FairPass.stamp(booth)
	super(result)


## The booth's own wares (the decoration) give way to the game's things.
func _show_deco(on: bool) -> void:
	var d: Node3D = fair().booth_deco.get(booth) if world.fair else null
	if d:
		d.visible = on


func cleanup() -> void:
	_show_deco(true)
	_host_back()
	booth_end()
	if is_instance_valid(_root):
		_root.queue_free()


# --- Override --------------------------------------------------------------------------

func booth_begin() -> void:
	pass


func booth_end() -> void:
	pass


func goal_done() -> bool:
	return FairPass.has(booth)

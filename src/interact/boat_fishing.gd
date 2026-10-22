class_name BoatFishing
extends Interactable
## Fishing from a rowing boat that lies still on the water (doc/moewenbucht.md): "Angeln" while
## sitting in it; a bite, "Aktion", the catch of the deep bay (Gathering.CATCH "boat"). It goes
## with the player's boat; Gathering does the fishing.

var world: World


func setup(w: World) -> void:
	world = w
	name = "BoatFishing"
	from_car = true
	radius = 1.5


func _boat(a: Actor) -> Car:
	return a.vehicle if a and a.vehicle and a.vehicle.kind == "rowboat" else null


func anchor() -> Vector3:
	var a := _player()
	return a.global_position if _boat(a) else Vector3(1e6, 0, 1e6)


func _player() -> Actor:
	var pc: PlayerController = UI.game.player if UI.game else null
	return pc.actor if pc else null


func get_prompt(a: Actor) -> String:
	var boat := _boat(a)
	if boat == null:
		return ""
	var g := Gameplay.gathering
	if g and not g.fishing.is_empty():
		return "Biss! Schnell einholen!" if g.fishing["bite_left"] > 0.0 else "Angeln … warte auf einen Biss"
	if not boat.is_standing():
		return ""
	if Items.tool_tier(a.inventory, "rod") == 0:
		return "Angeln – dafür brauchst du eine Angel"
	return "Angeln"


func can_interact(a: Actor) -> bool:
	var boat := _boat(a)
	if boat == null or Gameplay.gathering == null:
		return false
	return not Gameplay.gathering.fishing.is_empty() or (boat.is_standing() and Items.tool_tier(a.inventory, "rod") > 0)


func interact(a: Actor) -> void:
	var g := Gameplay.gathering
	if not g.fishing.is_empty():
		g.interact(a)
		return
	var boat := _boat(a)
	if boat == null or not boat.is_standing():
		return
	boat.speed = 0.0
	var f := boat.forward2()
	var side := Car.right_of(f) * 3.0
	g.start(a, {"id": "boat", "kind": "fishing", "catch": "boat", "nodes": [], "pos": a.global_position,
		"face": a.global_position + Vector3(side.x, 0, side.y)})

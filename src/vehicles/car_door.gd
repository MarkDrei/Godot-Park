class_name CarDoor
extends Interactable
## "Einsteigen" at a standing car (every car can be taken, see Car.can_enter).

var car: Car


func get_prompt(actor: Actor) -> String:
	if car == null or actor.vehicle != null or not actor.is_human():
		return ""
	if car.locked:
		return ""
	if not car.is_standing():
		return ""
	if car.driver:
		return ""
	return "Einsteigen: %s" % CarSpecs.name_of(car.kind)


func can_interact(actor: Actor) -> bool:
	return car != null and car.can_enter(actor)


func interact(actor: Actor) -> void:
	if UI.game and car.can_enter(actor):
		(UI.game.player as PlayerController).enter_car(car)

class_name BoatPhoto
extends Interactable
## The seals' photo for Hinnerk (CoastStories "seals"): in a boat close to the sandbank (lying
## still), "Robben fotografieren" takes it: a flash, the photo in the bag.

var world: World


func setup(w: World) -> void:
	world = w
	name = "BoatPhoto"
	from_car = true
	radius = 1.5


func _boat(a: Actor) -> Car:
	if a == null or a.vehicle == null or not a.vehicle.on_water():
		return null
	if CoastStories.quest_stage("seals") != QuestModule.ACTIVE or a.has_item("seal_photo"):
		return null
	if a.vehicle.pos2().distance_to(CoastLayout.SANDBANK) > CoastStories.PHOTO_REACH:
		return null
	return a.vehicle


func anchor() -> Vector3:
	var pc: PlayerController = UI.game.player if UI.game else null
	var a := pc.actor if pc else null
	return a.global_position if _boat(a) else Vector3(1e6, 0, 1e6)


func get_prompt(a: Actor) -> String:
	var b := _boat(a)
	return "Robben fotografieren" if b and b.is_standing() else ""


func can_interact(a: Actor) -> bool:
	var b := _boat(a)
	return b != null and b.is_standing()


func interact(a: Actor) -> void:
	if not can_interact(a):
		return
	a.add_item("seal_photo")
	Sound.play("click", a.global_position)
	_flash()
	GameState.toast.emit("Klick! Ein schönes Foto von den Robben auf der Sandbank.", "info")


## A camera's white flash over the screen.
func _flash() -> void:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.85)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.root.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.4)
	tw.tween_callback(r.queue_free)

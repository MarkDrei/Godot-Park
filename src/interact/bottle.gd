class_name Bottle
extends Interactable
## An empty deposit bottle lying around. Humans pick it up (25 ct at the machine).


func _ready() -> void:
	super()
	radius = 1.6
	prompt_text = "Pfandflasche aufheben"
	var mi := MeshInstance3D.new()
	mi.mesh = PropModels.item("bottle")
	mi.rotation = Vector3(PI / 2, randf() * TAU, 0)
	mi.position.y = 0.05
	add_child(mi)


func interact(actor: Actor) -> void:
	actor.add_item("empty_bottle")
	actor.play_anim("squat", 0.8)
	Sound.play("pickup")
	GameState.toast.emit("Pfandflasche eingesammelt (%d dabei)" % actor.inventory["empty_bottle"], "info")
	var w := actor.world
	w.remove_bottle(self)
	w.bottle_collected.emit()

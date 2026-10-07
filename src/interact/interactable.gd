class_name Interactable
extends Node3D
## Something the controlled actor can use when standing close to it.
## Subclasses override get_prompt / can_interact / interact.

@export var radius := 2.2
## Which kinds of actors may use it: "human", "animal" or "any".
@export var users := "human"
var prompt_text := ""


func _ready() -> void:
	add_to_group("interactables")


func get_prompt(_actor: Actor) -> String:
	return prompt_text


func can_interact(actor: Actor) -> bool:
	if users == "any":
		return true
	return actor.is_human() == (users == "human")


func interact(_actor: Actor) -> void:
	pass


## Position used for distance checks (ground level).
func anchor() -> Vector3:
	return global_position

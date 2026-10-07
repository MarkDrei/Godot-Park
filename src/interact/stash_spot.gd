class_name StashSpot
extends Interactable
## Easter egg: the hollow oak where Nussi hides stolen donuts.


func _ready() -> void:
	super()
	users = "any"
	radius = 2.0


func get_prompt(_actor: Actor) -> String:
	return "Astloch untersuchen"


func interact(actor: Actor) -> void:
	var n := actor.world.stash_count
	if GameState.add_to_set("secrets", "stash"):
		GameState.add_stat("stash")
	UI.dialog("Astloch", "Im hohlen Baum liegen %d angeknabberte Donuts. Das ist also Nussis geheimes Versteck!" % maxi(n, 2) +
		("\n\nDu nimmst dir einen. Schmeckt noch!" if n > 0 and actor.is_human() else ""),
		[{"text": "Hihi.", "id": ""}], func(_c: String) -> void:
			if n > 0 and actor.is_human():
				actor.consume("donut"))

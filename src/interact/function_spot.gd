class_name FunctionSpot
extends Interactable
## Interactable defined by two callables (prompt and action) – for one-off spots.

var prompt_fn: Callable
var action_fn: Callable
var available_fn := Callable()


func get_prompt(actor: Actor) -> String:
	return prompt_fn.call(actor) if prompt_fn.is_valid() else prompt_text


func can_interact(actor: Actor) -> bool:
	if available_fn.is_valid() and not available_fn.call(actor):
		return false
	return super(actor)


func interact(actor: Actor) -> void:
	if action_fn.is_valid():
		action_fn.call(actor)

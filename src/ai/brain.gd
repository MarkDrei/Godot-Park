class_name Brain
extends RefCounted
## Base for NPC decision making. The actor calls update() while not controlled.

var actor: Actor
var world: World
var rng := RandomNumberGenerator.new()


func _init(a: Actor) -> void:
	actor = a
	world = a.world
	rng.seed = hash(a.actor_id) + randi()


func update(_delta: float) -> void:
	pass


## The player took over this actor: stop whatever we were doing.
func suspend() -> void:
	pass


## The player left this actor: pick up life again.
func resume() -> void:
	pass


## Short German description of the current doing, for the UI ("sitzt auf einer Bank").
func doing() -> String:
	return ""

class_name QuestModule
extends Node
## Base of the quest modules (Quests, DwarfQuests, FairStories, PlaygroundQuests), created by
## Gameplay.setup and listed in Gameplay.modules. A module says what its characters offer in a
## conversation (`options`), what goes into the notebook (`tasks`) and under whom a quest ring
## glows (`quest_givers`, `has_quest`; QuestMarkers asks every module).

var game: Game
var world: World


func setup(g: Game) -> void:
	game = g
	world = g.world
	name = get_script().get_global_name()
	world.add_child(self)
	Conversations.register(options)
	TaskBoard.register(tasks)


## Override: the options `npc` offers `player` now ([{"text", "action"}]).
func options(_player: Actor, _npc: Actor) -> Array:
	return []


## Override: notebook entries ([{"title", "desc", "done"} or "active"]).
func tasks() -> Array:
	return []


## Override: the ids of the characters whose quests this module tells.
func quest_givers() -> Array:
	return []


## A quest step is open with `npc` (gold ring). By default: `npc` has something to offer.
## Override when collecting the options has side effects or offers more than quest steps.
func has_quest(player: Actor, npc: Actor) -> bool:
	return not options(player, npc).is_empty()

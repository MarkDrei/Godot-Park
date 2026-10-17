class_name QuestModule
extends Node
## Base of the quest modules (Quests, DwarfQuests, FairStories, PlaygroundQuests), created by
## Gameplay.setup and listed in Gameplay.modules. A module says what its characters offer in a
## conversation (`options`), what goes into the notebook (`tasks`) and under whom a quest ring
## glows (`quest_givers`, options marked "quest"; QuestMarkers asks every module).

## Stages of a simple quest (GameState.stage): taken on, then done. Longer quests count on.
const OPEN := 0
const ACTIVE := 1
const DONE := 2

var game: Game
var world: World


func setup(g: Game) -> void:
	game = g
	world = g.world
	name = get_script().get_global_name()
	world.add_child(self)
	Conversations.register(options)
	TaskBoard.register(tasks)


## Override: the options `npc` offers `player` now ([{"text", "action"}]); an option that
## moves a quest on says so with "quest": true (it puts the gold ring under `npc`). Only build
## the list here: what happens when somebody talks goes into `talked`.
func options(_player: Actor, _npc: Actor) -> Array:
	return []


## Override: `player` started talking to `npc` (before the options are shown).
func talked(_player: Actor, _npc: Actor) -> void:
	pass


## Override: notebook entries ([{"title", "desc", "done"} or "active", "area" if not the park]).
func tasks() -> Array:
	return []


## Override: the ids of the characters whose quests this module tells.
func quest_givers() -> Array:
	return []


## A quest is done: `npc` cheers with a heart, `player` is glad, the success sound plays.
func thank(player: Actor, npc: Actor, joy := 20.0) -> void:
	npc.play_anim("cheer", 3.0)
	npc.emote("heart", 2)
	player.needs.cheer(joy)
	Sound.play("success")


## A quest step is open with `npc` (gold ring): one of its options is marked "quest".
func has_quest(player: Actor, npc: Actor) -> bool:
	for o: Dictionary in options(player, npc):
		if o.get("quest", false):
			return true
	return false

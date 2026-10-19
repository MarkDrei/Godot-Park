class_name BurgTrade
extends RefCounted
## Brewing and forging at the Ritterburg (doc/burg.md): talking to the herb witch, the alchemist
## or the smith while they work offers to have something made (Crafting, their station, a fee).
## Potions can't be bought: whoever brings the ingredients pays only the brewing.

const OPTIONS := {"walburga": ["witch", "Einen Trank brauen lassen"], "quirin": ["alchemist", "Einen Trank brauen lassen"],
	"brunhild": ["smithy", "Etwas schmieden lassen"]}


static func setup() -> void:
	Conversations.register(options)


static func options(player: Actor, npc: Actor) -> Array:
	if not OPTIONS.has(npc.actor_id) or not player.is_human() or not at_work(npc):
		return []
	var o: Array = OPTIONS[npc.actor_id]
	return [{"text": o[1], "action": func() -> void: UI.open_craft(o[0])}]


## The master is at the stand or the forge in working hours.
static func at_work(npc: Actor) -> bool:
	var b := npc.brain as HumanBrain
	if b == null or not b.at_work_now():
		return false
	var post := b.work_pos()
	return post != Vector3.INF and npc.global_position.distance_to(post) < 6.0

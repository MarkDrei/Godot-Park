class_name Crafting
extends RefCounted
## Recipes for the workbench and the campfire at the lumber camp (doc/nordwald.md), and for the
## Ritterburg's brewers and smithy (doc/burg.md): there the master makes it for a fee (cents).
## Ingredients come from the bag of the character at the station.

## id -> station, needs (item -> count), out (count), [item: what it makes if not the id],
## [fee: cents for the master], [unlock: quest]. Order = order on the screen.
const RECIPES := {
	# Workbench: materials and tools.
	"board": {"station": "workbench", "needs": {"log": 1}, "out": 1},
	"slab": {"station": "workbench", "needs": {"stone": 2}, "out": 1},
	"stone_axe": {"station": "workbench", "needs": {"twig": 3, "stone": 2}, "out": 1},
	"stone_pickaxe": {"station": "workbench", "needs": {"twig": 3, "stone": 3}, "out": 1},
	"fishing_rod": {"station": "workbench", "needs": {"twig": 4, "board": 1}, "out": 1},
	"iron_axe": {"station": "workbench", "needs": {"board": 2, "ore": 2}, "out": 1},
	"iron_pickaxe": {"station": "workbench", "needs": {"board": 2, "ore": 3}, "out": 1},
	# Workbench: goods to sell.
	"birdhouse": {"station": "workbench", "needs": {"board": 3, "twig": 2}, "out": 1},
	"carving": {"station": "workbench", "needs": {"log": 2}, "out": 1},
	"stone_gnome": {"station": "workbench", "needs": {"slab": 2}, "out": 1},
	# Campfire: cooking.
	"grilled_fish": {"station": "campfire", "needs": {"fish": 1, "twig": 1}, "out": 1},
	"mushroom_pan": {"station": "campfire", "needs": {"mushroom": 3}, "out": 1},
	"jam": {"station": "campfire", "needs": {"berries": 5}, "out": 1},
	"baked_apple": {"station": "campfire", "needs": {"apple": 2, "honey": 1}, "out": 2},
	# Brakka's secret recipe, after her quest.
	"dwarf_stew": {"station": "campfire", "needs": {"mushroom": 2, "fish": 1, "apple": 1}, "out": 1, "unlock": "dq_hunger"},
	# The castle: Walburga and Quirin brew, Brunhild forges (a fee each).
	"potion_speed": {"station": "witch", "needs": {"woodruff": 2, "chamomile": 2, "berries": 2}, "out": 1, "fee": 100},
	"potion_herbs": {"station": "witch", "needs": {"st_johns_wort": 2, "wild_garlic": 2, "elder": 2}, "out": 1, "fee": 100},
	"potion_mining": {"station": "alchemist", "needs": {"rose_hip": 2, "lavender": 2, "ore": 1}, "out": 1, "fee": 100},
	"horseshoe": {"station": "smithy", "needs": {"ore": 1}, "out": 1, "fee": 50},
	"forge_iron_axe": {"station": "smithy", "item": "iron_axe", "needs": {"ore": 3}, "out": 1, "fee": 200},
	"forge_iron_pickaxe": {"station": "smithy", "item": "iron_pickaxe", "needs": {"ore": 4}, "out": 1, "fee": 200},
}

const STATIONS := {"workbench": "Werkbank", "campfire": "Lagerfeuer", "witch": "Kräuterhexe Walburga",
	"alchemist": "Magister Quirin", "smithy": "Schmiedin Brunhild"}
## Who makes it at a station (the station needs her or him at work).
const MASTERS := {"witch": "walburga", "alchemist": "quirin", "smithy": "brunhild"}


## The item a recipe makes.
static func item_of(id: String) -> String:
	return RECIPES[id].get("item", id)


static func fee(id: String) -> int:
	return int(RECIPES[id].get("fee", 0))


static func for_station(station: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in RECIPES:
		var unlock: String = RECIPES[id].get("unlock", "")
		if RECIPES[id]["station"] == station and (unlock == "" or GameState.stage(unlock) == QuestModule.DONE):
			out.append(id)
	return out


static func missing(a: Actor, id: String) -> Dictionary:
	var m := {}
	var needs: Dictionary = RECIPES[id]["needs"]
	for item: String in needs:
		var have := int(a.inventory.get(item, 0))
		if have < int(needs[item]):
			m[item] = int(needs[item]) - have
	return m


static func can_craft(a: Actor, id: String) -> bool:
	return missing(a, id).is_empty() and GameState.money >= fee(id)


## Takes the ingredients and puts the result into the bag. False when something is missing
## or the bag has no room for the result.
static func craft(a: Actor, id: String) -> bool:
	var unlock: String = RECIPES[id].get("unlock", "")
	if not can_craft(a, id) or (unlock != "" and GameState.stage(unlock) != QuestModule.DONE):
		return false
	var r: Dictionary = RECIPES[id]
	var needs: Dictionary = r["needs"]
	# Room check as if the ingredients were already gone.
	var after := a.inventory.duplicate()
	for item: String in needs:
		after[item] = int(after[item]) - int(needs[item])
		if after[item] <= 0:
			after.erase(item)
	var out := item_of(id)
	after[out] = int(after.get(out, 0)) + int(r["out"])
	if Items.slots_used(after) > a.bag_slots():
		a.bag_full(out)
		return false
	if fee(id) > 0 and not GameState.spend(fee(id)):
		return false
	for item: String in needs:
		a.take_item(item, int(needs[item]))
	a.add_item(out, int(r["out"]))
	GameState.add_stat("crafted")
	GameState.add_to_set("recipes", id)
	if Potions.is_potion(out):
		GameState.add_to_set("potions_brewed", out)
	return true

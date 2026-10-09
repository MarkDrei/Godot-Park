class_name Crafting
extends RefCounted
## Recipes for the workbench and the campfire at the lumber camp (doc/nordwald.md).
## Ingredients come from the bag of the character at the station.

## id -> station, needs (item -> count), out (count). Order = order on the screen.
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
}

const STATIONS := {"workbench": "Werkbank", "campfire": "Lagerfeuer"}


static func for_station(station: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in RECIPES:
		var unlock: String = RECIPES[id].get("unlock", "")
		if RECIPES[id]["station"] == station and (unlock == "" or GameState.flags.get(unlock, "") == "done"):
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
	return missing(a, id).is_empty()


## Takes the ingredients and puts the result into the bag. False when something is missing
## or the bag has no room for the result.
static func craft(a: Actor, id: String) -> bool:
	var unlock: String = RECIPES[id].get("unlock", "")
	if not can_craft(a, id) or (unlock != "" and GameState.flags.get(unlock, "") != "done"):
		return false
	var r: Dictionary = RECIPES[id]
	var needs: Dictionary = r["needs"]
	# Room check as if the ingredients were already gone.
	var after := a.inventory.duplicate()
	for item: String in needs:
		after[item] = int(after[item]) - int(needs[item])
		if after[item] <= 0:
			after.erase(item)
	after[id] = int(after.get(id, 0)) + int(r["out"])
	if Items.slots_used(after) > a.bag_slots():
		GameState.toast.emit("Der Rucksack ist voll! Kein Platz für %s." % Items.name_of(id), "warn")
		return false
	for item: String in needs:
		a.take_item(item, int(needs[item]))
	a.add_item(id, int(r["out"]))
	GameState.add_stat("crafted")
	GameState.add_to_set("recipes", id)
	return true

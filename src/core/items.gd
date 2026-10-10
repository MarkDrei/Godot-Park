class_name Items
extends RefCounted
## Everything a character can carry in the bag (doc/nordwald.md): names, categories, stack
## sizes, base values and tool tiers. Edible items also have an entry in Food.ITEMS (effects).

const CATEGORIES := {
	"food": "Essen",
	"material": "Rohstoffe",
	"tool": "Werkzeug",
	"goods": "Waren",
	"quest": "Besonderes",
	"misc": "Krimskrams",
}

## Bag slots per character; a stack of one item fills one slot.
const BAG_SLOTS := 12
const BIG_BAG_SLOTS := 18

## id -> name, cat, stack (per slot), value (cents, what traders pay at most), desc;
## tools: tool (axe | pickaxe | rod | bag) and tier.
const DEFS := {
	# Park things.
	"bread": {"name": "Entenbrot", "cat": "misc", "stack": 20, "value": 10, "desc": "Für die Enten. Nicht für dich."},
	"empty_bottle": {"name": "Pfandflasche", "cat": "misc", "stack": 20, "value": 25, "desc": "Bring sie zum Pfandautomaten."},
	"nut": {"name": "Nuss", "cat": "misc", "stack": 20, "value": 5, "desc": "Eichhörnchen-Währung."},
	"invisible_key": {"name": "Unsichtbarer Schlüssel", "cat": "quest", "stack": 1, "value": 0, "desc": "Man sieht ihn nicht, aber er ist da."},
	# Nordwald materials.
	"twig": {"name": "Äste", "cat": "material", "stack": 20, "value": 5, "desc": "Liegen überall im Wald herum."},
	"log": {"name": "Holzscheit", "cat": "material", "stack": 20, "value": 40, "desc": "Frisch geschlagen. Riecht nach Harz."},
	"cherry_wood": {"name": "Kirschholz", "cat": "material", "stack": 10, "value": 250, "desc": "Edles Holz aus dem Stadtpark. Woher nur?"},
	"board": {"name": "Brett", "cat": "material", "stack": 20, "value": 90, "desc": "Gesägt und gehobelt."},
	"stone": {"name": "Stein", "cat": "material", "stack": 20, "value": 30, "desc": "Ein solider Brocken aus dem Steinbruch."},
	"slab": {"name": "Steinplatte", "cat": "material", "stack": 10, "value": 80, "desc": "Sauber behauen."},
	"ore": {"name": "Erzbrocken", "cat": "material", "stack": 20, "value": 150, "desc": "Die Zwerge werden hellhörig."},
	"gem": {"name": "Edelstein", "cat": "material", "stack": 10, "value": 900, "desc": "Funkelt. Zwerge lieben das."},
	# Food from the forest (effects in Food.ITEMS).
	"berries": {"name": "Waldbeeren", "cat": "food", "stack": 10, "value": 30, "desc": "Süß und ein bisschen sauer."},
	"mushroom": {"name": "Steinpilz", "cat": "food", "stack": 10, "value": 60, "desc": "Roh nicht so lecker. Lieber braten."},
	"apple": {"name": "Apfel", "cat": "food", "stack": 10, "value": 40, "desc": "Frisch von der Obstwiese."},
	"fish": {"name": "Forelle", "cat": "food", "stack": 10, "value": 120, "desc": "Aus dem Waldweiher. Am besten gegrillt."},
	"honey": {"name": "Waldhonig", "cat": "food", "stack": 10, "value": 300, "desc": "Von den Bienen an der Obstwiese."},
	"grilled_fish": {"name": "Steckerlfisch", "cat": "food", "stack": 10, "value": 350, "desc": "Über dem Lagerfeuer gegrillt."},
	"mushroom_pan": {"name": "Pilzpfanne", "cat": "food", "stack": 10, "value": 300, "desc": "Mit Zwiebeln. Herrlich."},
	"jam": {"name": "Beerenmarmelade", "cat": "food", "stack": 10, "value": 400, "desc": "Im Glas. Der Hofladen zahlt gut dafür."},
	"baked_apple": {"name": "Bratapfel", "cat": "food", "stack": 10, "value": 200, "desc": "Warm, mit Honig."},
	"dwarf_stew": {"name": "Zwergeneintopf", "cat": "food", "stack": 10, "value": 500, "desc": "Brakkas Geheimrezept. Macht satt bis übermorgen."},
	# Tools (never break; the tier sets the speed).
	"stone_axe": {"name": "Steinaxt", "cat": "tool", "stack": 1, "value": 300, "tool": "axe", "tier": 1, "desc": "Fällt Bäume. Langsam."},
	"iron_axe": {"name": "Eisenaxt", "cat": "tool", "stack": 1, "value": 900, "tool": "axe", "tier": 2, "desc": "Fällt Bäume doppelt so schnell."},
	"dwarf_axe": {"name": "Zwergenaxt", "cat": "tool", "stack": 1, "value": 2500, "tool": "axe", "tier": 3, "desc": "Zwergenarbeit. Ein Hieb, ein Baum. Fast."},
	"stone_pickaxe": {"name": "Steinhacke", "cat": "tool", "stack": 1, "value": 300, "tool": "pickaxe", "tier": 1, "desc": "Für Steine im Steinbruch."},
	"iron_pickaxe": {"name": "Eisenhacke", "cat": "tool", "stack": 1, "value": 900, "tool": "pickaxe", "tier": 2, "desc": "Schneller im Steinbruch, findet öfter Erz."},
	"dwarf_pickaxe": {"name": "Zwergenhacke", "cat": "tool", "stack": 1, "value": 2500, "tool": "pickaxe", "tier": 3, "desc": "Findet Edelsteine, wo andere nur Kies sehen."},
	"fishing_rod": {"name": "Angel", "cat": "tool", "stack": 1, "value": 400, "tool": "rod", "tier": 1, "desc": "Für den Waldweiher."},
	"big_bag": {"name": "Zwergenrucksack", "cat": "tool", "stack": 1, "value": 1500, "tool": "bag", "tier": 1, "desc": "Sechs Plätze mehr im Rucksack."},
	# Horns for the car (car parts at the scrapyard): the best one sounds when the player honks.
	"horn_duck": {"name": "Quak-Hupe", "cat": "tool", "stack": 1, "value": 400, "tool": "horn", "tier": 1, "desc": "Hupt wie Erpel Erwin."},
	"horn_cucaracha": {"name": "Cucaracha-Hupe", "cat": "tool", "stack": 1, "value": 700, "tool": "horn", "tier": 2, "desc": "Spielt ein Lied. Die Nachbarn freuen sich. Nicht."},
	"horn_fanfare": {"name": "Fanfaren-Hupe", "cat": "tool", "stack": 1, "value": 1000, "tool": "horn", "tier": 3, "desc": "Tätä-tätää! Platz da!"},
	# Crafted goods to sell.
	"birdhouse": {"name": "Vogelhäuschen", "cat": "goods", "stack": 5, "value": 900, "desc": "Handgemacht. Die Meisen sind begeistert."},
	"carving": {"name": "Holzfigur", "cat": "goods", "stack": 5, "value": 600, "desc": "Soll ein Eichhörnchen sein."},
	"stone_gnome": {"name": "Steinzwerg", "cat": "goods", "stack": 5, "value": 700, "desc": "Ein Gartenzwerg aus Stein. Echte Zwerge finden das gar nicht witzig."},
}


static func def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func name_of(id: String) -> String:
	return DEFS.get(id, {}).get("name", id)


static func category(id: String) -> String:
	return DEFS.get(id, {}).get("cat", "misc")


static func stack_size(id: String) -> int:
	return int(DEFS.get(id, {}).get("stack", 20))


static func value(id: String) -> int:
	return int(DEFS.get(id, {}).get("value", 0))


static func is_edible(id: String) -> bool:
	return Food.is_edible(id)


## Slots `count` pieces of `id` take.
static func slots_for(id: String, count: int) -> int:
	if count <= 0:
		return 0
	return int(ceil(float(count) / stack_size(id)))


## Slots an inventory (id -> count) takes.
static func slots_used(inv: Dictionary) -> int:
	var n := 0
	for id: String in inv:
		n += slots_for(id, int(inv[id]))
	return n


## Best tier of a tool kind ("axe", "pickaxe", "rod") in the inventory, 0 if none.
static func tool_tier(inv: Dictionary, kind: String) -> int:
	var best := 0
	for id: String in inv:
		var d: Dictionary = DEFS.get(id, {})
		if d.get("tool", "") == kind and int(inv[id]) > 0:
			best = maxi(best, int(d.get("tier", 1)))
	return best


## Inventory ids sorted for display: by category, then name.
static func sorted_ids(inv: Dictionary) -> Array[String]:
	var order := CATEGORIES.keys()
	var ids: Array[String] = []
	for id: String in inv:
		if int(inv[id]) > 0:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca := order.find(category(a))
		var cb := order.find(category(b))
		return ca < cb if ca != cb else name_of(a) < name_of(b))
	return ids

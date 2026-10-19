class_name Items
extends RefCounted
## Everything a character can carry in the bag (doc/nordwald.md): names, categories, stack
## sizes, base values and tool tiers. Edible items also have an entry in Food.ITEMS (effects).

const CATEGORIES := {
	"food": "Essen",
	"material": "Rohstoffe",
	"tool": "Werkzeug",
	"goods": "Waren",
	"herb": "Kräuter",
	"potion": "Tränke",
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
	# Kirmes (FairStories).
	"teddy": {"name": "Teddy Brummi", "cat": "quest", "stack": 1, "value": 0, "desc": "Lia sucht ihn überall."},
	"pocket_watch": {"name": "Alte Taschenuhr", "cat": "quest", "stack": 1, "value": 0, "desc": "Sie tickt noch. Hundert Jahre alt, mindestens."},
	"hoppel": {"name": "Kaninchen Hoppel", "cat": "quest", "stack": 1, "value": 0, "desc": "Mümmelt an einer Möhre und schaut dich unschuldig an."},
	"takeaway_hotdog": {"name": "Hot Dog zum Mitnehmen", "cat": "quest", "stack": 1, "value": 0, "desc": "Für Muskel-Max. Schnell, solange er warm ist!"},
	"takeaway_fries": {"name": "Pommes zum Mitnehmen", "cat": "quest", "stack": 1, "value": 0, "desc": "Für Muskel-Max. Schnell, solange sie warm sind!"},
	# Playground (PlaygroundQuests).
	"plush_unicorn": {"name": "Stoff-Einhorn", "cat": "quest", "stack": 1, "value": 0, "desc": "Weiß, mit Regenbogenmähne. Finja wünscht sich so eins."},
	"toy_car": {"name": "Spielzeugauto", "cat": "quest", "stack": 1, "value": 0, "desc": "Aus dem Kindermenü. Mika sammelt die."},
	"rusty_key": {"name": "Rostiger Schlüssel", "cat": "quest", "stack": 1, "value": 0, "desc": "Aus dem Sandkasten. Am Griff grinst ein kleines Trollgesicht."},
	"troll_crown": {"name": "Trollkrone", "cat": "quest", "stack": 1, "value": 0, "desc": "Klein, verbeult, aus Gold. Für einen sehr großen Kopf gemacht."},
	"golden_duck": {"name": "Goldene Ente", "cat": "misc", "stack": 10, "value": 2500, "desc": "Glänzt wie ein Schatz. Ist auch einer."},
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
	"vendor_tray": {"name": "Bauchladen", "cat": "tool", "stack": 1, "value": 1500, "tool": "tray", "tier": 1, "desc": "Der Hauptgewinn der Kirmes: sechs Plätze mehr, auch zusätzlich zum Zwergenrucksack."},
	# Horns for the car (car parts at the scrapyard): the best one sounds when the player honks.
	"horn_duck": {"name": "Quak-Hupe", "cat": "tool", "stack": 1, "value": 400, "tool": "horn", "tier": 1, "desc": "Hupt wie Erpel Erwin."},
	"horn_cucaracha": {"name": "Cucaracha-Hupe", "cat": "tool", "stack": 1, "value": 700, "tool": "horn", "tier": 2, "desc": "Spielt ein Lied. Die Nachbarn freuen sich. Nicht."},
	"horn_fanfare": {"name": "Fanfaren-Hupe", "cat": "tool", "stack": 1, "value": 1000, "tool": "horn", "tier": 3, "desc": "Tätä-tätää! Platz da!"},
	# Herbs and berries for the potions of the Ritterburg (doc/burg.md), and the potions.
	"chamomile": {"name": "Kamille", "cat": "herb", "stack": 20, "value": 25, "desc": "Von den Wiesen im Stadtpark. Riecht nach Sommer."},
	"elder": {"name": "Holunderbeeren", "cat": "herb", "stack": 20, "value": 30, "desc": "Dunkle Beeren aus den Hecken. Roh lieber nicht essen."},
	"woodruff": {"name": "Waldmeister", "cat": "herb", "stack": 20, "value": 30, "desc": "Wächst unter den Bäumen im Nordwald."},
	"wild_garlic": {"name": "Bärlauch", "cat": "herb", "stack": 20, "value": 25, "desc": "Am Bach im Nordwald. Riecht kräftig."},
	"lavender": {"name": "Lavendel", "cat": "herb", "stack": 20, "value": 35, "desc": "Aus den Gärten der Kirmes. Beruhigt."},
	"st_johns_wort": {"name": "Johanniskraut", "cat": "herb", "stack": 20, "value": 40, "desc": "Gelbe Blüten vom Kräuterhang der Burg."},
	"rose_hip": {"name": "Hagebutten", "cat": "herb", "stack": 20, "value": 35, "desc": "Rote Früchte aus den Hecken an der Burg."},
	"potion_speed": {"name": "Lauftrank", "cat": "potion", "stack": 5, "value": 800, "desc": "Acht Stunden lang 50 % schneller, ohne vom Laufen müde zu werden."},
	"potion_herbs": {"name": "Kräutertrank", "cat": "potion", "stack": 5, "value": 800, "desc": "Acht Stunden lang doppelt so viele Kräuter und Beeren beim Pflücken."},
	"potion_mining": {"name": "Abbautrank", "cat": "potion", "stack": 5, "value": 800, "desc": "Acht Stunden lang Bäume und Steine doppelt so schnell abbauen."},
	"horseshoe": {"name": "Hufeisen", "cat": "goods", "stack": 5, "value": 200, "desc": "Frisch geschmiedet. Bringt Glück. Und Pferden Halt."},
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


## Slots of a bag holding `inv`: the dwarf bag and the vendor tray add some each.
static func bag_slots(inv: Dictionary) -> int:
	return BAG_SLOTS + (BIG_BAG_SLOTS - BAG_SLOTS) * ((1 if inv.has("big_bag") else 0) + (1 if inv.has("vendor_tray") else 0))


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

class_name Food
extends RefCounted
## Menu items: name, price (cents), held item mesh, effect on needs. Things that are not eaten
## (duck bread, balloon, newspaper) are marked "thing"; food from the bag takes its name and
## value from Items.DEFS and has only its effect here.

const ITEMS := {
	"donut": {"name": "Donut", "price": 150, "item": "donut", "hunger": 30.0, "joy": 10.0, "fatigue": 0.0},
	"coffee": {"name": "Kaffee", "price": 200, "item": "bottle", "hunger": 0.0, "joy": 4.0, "fatigue": -25.0},
	"hotdog": {"name": "Hot Dog", "price": 250, "item": "hotdog", "hunger": 55.0, "joy": 8.0, "fatigue": 0.0},
	"fries": {"name": "Pommes", "price": 220, "item": "fries", "hunger": 45.0, "joy": 9.0, "fatigue": 0.0},
	"pretzel": {"name": "Brezel", "price": 180, "item": "pretzel", "hunger": 30.0, "joy": 5.0, "fatigue": 0.0},
	"icecream": {"name": "Eis", "price": 200, "item": "icecream", "hunger": 12.0, "joy": 16.0, "fatigue": 0.0},
	"water": {"name": "Wasser (mit Pfand)", "price": 125, "item": "bottle", "hunger": 4.0, "joy": 2.0, "fatigue": -8.0},
	"bread": {"name": "Entenbrot (5 Stück)", "price": 50, "item": "", "thing": true, "hunger": 0.0, "joy": 0.0, "fatigue": 0.0},
	"balloon": {"name": "Luftballon", "price": 200, "item": "balloon", "thing": true, "hunger": 0.0, "joy": 12.0, "fatigue": 0.0},
	"newspaper": {"name": "Zeitung", "price": 120, "item": "newspaper", "thing": true, "hunger": 0.0, "joy": 4.0, "fatigue": 0.0},
	"chocolate": {"name": "Schokoriegel", "price": 130, "item": "chocolate", "hunger": 18.0, "joy": 8.0, "fatigue": -3.0},
	"sandwich": {"name": "Käse-Sandwich", "price": 290, "item": "sandwich", "hunger": 40.0, "joy": 3.0, "fatigue": 0.0},
	"sausage": {"name": "Würstchen", "price": 0, "item": "hotdog", "hunger": 45.0, "joy": 20.0, "fatigue": 0.0},
	# Hot meals at the Waldschänke.
	"kaiserschmarrn": {"name": "Kaiserschmarrn", "price": 450, "item": "", "hunger": 55.0, "joy": 16.0, "fatigue": 0.0},
	"pilzsuppe": {"name": "Pilzsuppe", "price": 380, "item": "", "hunger": 40.0, "joy": 8.0, "fatigue": 0.0},
	"apfelschorle": {"name": "Apfelschorle", "price": 220, "item": "bottle", "hunger": 4.0, "joy": 4.0, "fatigue": -12.0},
	# Nordwald food, eaten from the bag (Items.DEFS).
	"berries": {"item": "", "hunger": 8.0, "joy": 5.0, "fatigue": 0.0},
	"mushroom": {"item": "", "hunger": 6.0, "joy": -4.0, "fatigue": 0.0},
	"apple": {"item": "", "hunger": 12.0, "joy": 4.0, "fatigue": 0.0},
	"honey": {"item": "", "hunger": 6.0, "joy": 12.0, "fatigue": -4.0},
	"grilled_fish": {"item": "", "hunger": 55.0, "joy": 14.0, "fatigue": 0.0},
	"mushroom_pan": {"item": "", "hunger": 50.0, "joy": 12.0, "fatigue": 0.0},
	"jam": {"item": "", "hunger": 12.0, "joy": 14.0, "fatigue": 0.0},
	"baked_apple": {"item": "", "hunger": 28.0, "joy": 16.0, "fatigue": 0.0},
	"dwarf_stew": {"item": "", "hunger": 80.0, "joy": 20.0, "fatigue": -10.0},
	# Oststadt: the drive-in "Zum Durchfahrer", the cinema's popcorn.
	"burger": {"name": "Hamburger", "price": 350, "item": "", "hunger": 50.0, "joy": 9.0, "fatigue": 0.0},
	"cheeseburger": {"name": "Cheeseburger", "price": 390, "item": "", "hunger": 55.0, "joy": 11.0, "fatigue": 0.0},
	"kids_menu": {"name": "Kindermenü (mit Spielzeugauto)", "price": 450, "item": "", "hunger": 45.0, "joy": 14.0, "fatigue": 0.0},
	"burger_menu": {"name": "Durchfahrer-Menü (Burger, Pommes, Cola)", "price": 650, "item": "", "hunger": 85.0, "joy": 16.0, "fatigue": -8.0},
	"shake": {"name": "Milchshake", "price": 280, "item": "", "hunger": 14.0, "joy": 14.0, "fatigue": -4.0},
	"cola": {"name": "Cola", "price": 180, "item": "", "hunger": 4.0, "joy": 5.0, "fatigue": -10.0},
	"popcorn": {"name": "Popcorn", "price": 200, "item": "", "hunger": 16.0, "joy": 8.0, "fatigue": 0.0},
	# The Imbiss on the Rathausplatz.
	"currywurst": {"name": "Currywurst mit Pommes", "price": 420, "item": "fries", "hunger": 65.0, "joy": 11.0, "fatigue": 0.0},
	"doener": {"name": "Döner", "price": 550, "item": "sandwich", "hunger": 70.0, "joy": 11.0, "fatigue": 0.0},
	"falafel": {"name": "Falafel im Fladenbrot", "price": 450, "item": "sandwich", "hunger": 55.0, "joy": 9.0, "fatigue": 0.0},
	"ayran": {"name": "Ayran", "price": 150, "item": "bottle", "hunger": 6.0, "joy": 4.0, "fatigue": -6.0},
	# The Kirmes in the Westpark (doc/kirmes.md).
	"candy_floss": {"name": "Zuckerwatte", "price": 250, "item": "candyfloss", "hunger": 10.0, "joy": 18.0, "fatigue": 0.0},
	"almonds": {"name": "Gebrannte Mandeln", "price": 300, "item": "almond_cone", "hunger": 20.0, "joy": 12.0, "fatigue": 0.0},
	"bratwurst": {"name": "Bratwurst im Brötchen", "price": 320, "item": "hotdog", "hunger": 55.0, "joy": 9.0, "fatigue": 0.0},
	"crepe": {"name": "Crêpe mit Zimt und Zucker", "price": 280, "item": "crepe", "hunger": 30.0, "joy": 14.0, "fatigue": 0.0},
	"lemonade": {"name": "Limonade", "price": 200, "item": "bottle", "hunger": 4.0, "joy": 6.0, "fatigue": -8.0},
	# The market of the Ritterburg (doc/burg.md): no mead.
	"stew_bread": {"name": "Eintopf im Brotlaib", "price": 480, "item": "", "hunger": 65.0, "joy": 12.0, "fatigue": 0.0},
	"flatbread": {"name": "Brotfladen mit Kräutern", "price": 260, "item": "sandwich", "hunger": 35.0, "joy": 6.0, "fatigue": 0.0},
	"suckling_pig": {"name": "Spanferkel im Brot", "price": 450, "item": "sandwich", "hunger": 60.0, "joy": 10.0, "fatigue": 0.0},
	"honey_cake": {"name": "Honigkuchen", "price": 220, "item": "pretzel", "hunger": 20.0, "joy": 14.0, "fatigue": -3.0},
	"smoked_fish": {"name": "Räucherfisch im Brötchen", "price": 380, "item": "sandwich", "hunger": 45.0, "joy": 8.0, "fatigue": 0.0},
	# The Möwenbucht (doc/moewenbucht.md).
	"fish_roll": {"name": "Fischbrötchen", "price": 320, "item": "sandwich", "hunger": 40.0, "joy": 10.0, "fatigue": 0.0},
	"backfisch": {"name": "Backfisch mit Remoulade", "price": 480, "item": "sandwich", "hunger": 60.0, "joy": 10.0, "fatigue": 0.0},
	"spaghetti_ice": {"name": "Spaghettieis", "price": 380, "item": "icecream", "hunger": 18.0, "joy": 20.0, "fatigue": 0.0},
	"soft_ice": {"name": "Softeis", "price": 200, "item": "icecream", "hunger": 10.0, "joy": 14.0, "fatigue": 0.0},
	"coconut_shake": {"name": "Kokos-Shake", "price": 300, "item": "bottle", "hunger": 10.0, "joy": 14.0, "fatigue": -6.0},
}

## The Kirmes's food stands; the sweets count for "Zuckerschock 2.0".
const FAIR := ["candy_floss", "almonds", "bratwurst", "crepe", "lemonade"]
const FAIR_SWEETS := ["candy_floss", "almonds", "crepe"]

## The drive-in's menu (DriveIn) and the cinema's snack.
const DRIVE_IN := ["burger", "cheeseburger", "fries", "burger_menu", "kids_menu", "shake", "cola"]

## Eaten from the bag rather than bought at a stand.
const FOREST := ["berries", "mushroom", "apple", "honey", "grilled_fish", "mushroom_pan", "jam", "baked_apple", "dwarf_stew"]

## Items that count for the "Feinschmecker" achievement.
const GOURMET := ["donut", "hotdog", "icecream", "pretzel", "fries"]


static func item_for(food: String) -> String:
	return ITEMS.get(food, {}).get("item", "")


static func is_edible(food: String) -> bool:
	return ITEMS.has(food) and not ITEMS[food].get("thing", false)


## Applies the food's effect to the actor's needs and the player's stats.
static func apply(actor: Actor, food: String) -> void:
	var it: Dictionary = ITEMS.get(food, {})
	if it.is_empty():
		return
	actor.needs.eat(it["hunger"], it["joy"])
	actor.needs.fatigue = clampf(actor.needs.fatigue + it["fatigue"], 0.0, 100.0)
	if not actor.controlled:
		return
	if food in GOURMET:
		GameState.add_to_set("foods", food)
	if food in FAIR_SWEETS:
		GameState.add_to_set("fair_sweets", food)
	if food == "donut":
		GameState.set_stat("donut_streak_now", GameState.stat("donut_streak_now") + 1)
		GameState.set_stat_max("donut_streak", GameState.stat("donut_streak_now"))
		if GameState.stat("donut_streak_now") >= 4:
			actor.emote("sweat")
	elif is_edible(food):
		GameState.set_stat("donut_streak_now", 0)
	if food == "water":
		actor.add_item("empty_bottle")
		GameState.toast.emit("Leere Flasche – bring sie zum Pfandautomaten!", "info")

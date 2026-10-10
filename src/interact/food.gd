class_name Food
extends RefCounted
## Menu items: price (cents), held item mesh, effect on needs.

const ITEMS := {
	"donut": {"name": "Donut", "price": 150, "item": "donut", "hunger": 30.0, "joy": 10.0, "fatigue": 0.0},
	"coffee": {"name": "Kaffee", "price": 200, "item": "bottle", "hunger": 0.0, "joy": 4.0, "fatigue": -25.0},
	"hotdog": {"name": "Hot Dog", "price": 250, "item": "hotdog", "hunger": 55.0, "joy": 8.0, "fatigue": 0.0},
	"fries": {"name": "Pommes", "price": 220, "item": "fries", "hunger": 45.0, "joy": 9.0, "fatigue": 0.0},
	"pretzel": {"name": "Brezel", "price": 180, "item": "pretzel", "hunger": 30.0, "joy": 5.0, "fatigue": 0.0},
	"icecream": {"name": "Eis", "price": 200, "item": "icecream", "hunger": 12.0, "joy": 16.0, "fatigue": 0.0},
	"water": {"name": "Wasser (mit Pfand)", "price": 125, "item": "bottle", "hunger": 4.0, "joy": 2.0, "fatigue": -8.0},
	"bread": {"name": "Entenbrot (5 Stück)", "price": 50, "item": "", "hunger": 0.0, "joy": 0.0, "fatigue": 0.0},
	"balloon": {"name": "Luftballon", "price": 200, "item": "balloon", "hunger": 0.0, "joy": 12.0, "fatigue": 0.0},
	"newspaper": {"name": "Zeitung", "price": 120, "item": "newspaper", "hunger": 0.0, "joy": 4.0, "fatigue": 0.0},
	"chocolate": {"name": "Schokoriegel", "price": 130, "item": "chocolate", "hunger": 18.0, "joy": 8.0, "fatigue": -3.0},
	"sandwich": {"name": "Käse-Sandwich", "price": 290, "item": "sandwich", "hunger": 40.0, "joy": 3.0, "fatigue": 0.0},
	"sausage": {"name": "Würstchen", "price": 0, "item": "hotdog", "hunger": 45.0, "joy": 20.0, "fatigue": 0.0},
	# Hot meals at the Waldschänke.
	"kaiserschmarrn": {"name": "Kaiserschmarrn", "price": 450, "item": "", "hunger": 55.0, "joy": 16.0, "fatigue": 0.0},
	"pilzsuppe": {"name": "Pilzsuppe", "price": 380, "item": "", "hunger": 40.0, "joy": 8.0, "fatigue": 0.0},
	"apfelschorle": {"name": "Apfelschorle", "price": 220, "item": "bottle", "hunger": 4.0, "joy": 4.0, "fatigue": -12.0},
	# Nordwald food, eaten from the bag (Items.DEFS).
	"berries": {"name": "Waldbeeren", "price": 30, "item": "", "hunger": 8.0, "joy": 5.0, "fatigue": 0.0},
	"mushroom": {"name": "Steinpilz", "price": 60, "item": "", "hunger": 6.0, "joy": -4.0, "fatigue": 0.0},
	"apple": {"name": "Apfel", "price": 40, "item": "", "hunger": 12.0, "joy": 4.0, "fatigue": 0.0},
	"honey": {"name": "Waldhonig", "price": 300, "item": "", "hunger": 6.0, "joy": 12.0, "fatigue": -4.0},
	"grilled_fish": {"name": "Steckerlfisch", "price": 350, "item": "", "hunger": 55.0, "joy": 14.0, "fatigue": 0.0},
	"mushroom_pan": {"name": "Pilzpfanne", "price": 300, "item": "", "hunger": 50.0, "joy": 12.0, "fatigue": 0.0},
	"jam": {"name": "Beerenmarmelade", "price": 400, "item": "", "hunger": 12.0, "joy": 14.0, "fatigue": 0.0},
	"baked_apple": {"name": "Bratapfel", "price": 200, "item": "", "hunger": 28.0, "joy": 16.0, "fatigue": 0.0},
	"dwarf_stew": {"name": "Zwergeneintopf", "price": 500, "item": "", "hunger": 80.0, "joy": 20.0, "fatigue": -10.0},
	# Oststadt: the drive-in "Zum Durchfahrer", the cinema's popcorn.
	"burger": {"name": "Hamburger", "price": 350, "item": "", "hunger": 50.0, "joy": 9.0, "fatigue": 0.0},
	"cheeseburger": {"name": "Cheeseburger", "price": 390, "item": "", "hunger": 55.0, "joy": 11.0, "fatigue": 0.0},
	"burger_menu": {"name": "Durchfahrer-Menü (Burger, Pommes, Cola)", "price": 650, "item": "", "hunger": 85.0, "joy": 16.0, "fatigue": -8.0},
	"shake": {"name": "Milchshake", "price": 280, "item": "", "hunger": 14.0, "joy": 14.0, "fatigue": -4.0},
	"cola": {"name": "Cola", "price": 180, "item": "", "hunger": 4.0, "joy": 5.0, "fatigue": -10.0},
	"popcorn": {"name": "Popcorn", "price": 200, "item": "", "hunger": 16.0, "joy": 8.0, "fatigue": 0.0},
}

## The drive-in's menu (DriveIn) and the cinema's snack.
const DRIVE_IN := ["burger", "cheeseburger", "fries", "burger_menu", "shake", "cola"]

## Eaten from the bag rather than bought at a stand.
const FOREST := ["berries", "mushroom", "apple", "honey", "grilled_fish", "mushroom_pan", "jam", "baked_apple", "dwarf_stew"]

## Items that count for the "Feinschmecker" achievement.
const GOURMET := ["donut", "hotdog", "icecream", "pretzel", "fries"]


static func item_for(food: String) -> String:
	return ITEMS.get(food, {}).get("item", "")


static func is_edible(food: String) -> bool:
	return food in ["donut", "coffee", "hotdog", "fries", "pretzel", "icecream", "water", "sausage", "chocolate", "sandwich"] \
		or food in FOREST or food in ["kaiserschmarrn", "pilzsuppe", "apfelschorle"] or food in DRIVE_IN or food == "popcorn"


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

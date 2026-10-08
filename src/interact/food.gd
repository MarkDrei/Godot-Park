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
}

## Items that count for the "Feinschmecker" achievement.
const GOURMET := ["donut", "hotdog", "icecream", "pretzel", "fries"]


static func item_for(food: String) -> String:
	return ITEMS.get(food, {}).get("item", "")


static func is_edible(food: String) -> bool:
	return food in ["donut", "coffee", "hotdog", "fries", "pretzel", "icecream", "water", "sausage", "chocolate", "sandwich"]


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

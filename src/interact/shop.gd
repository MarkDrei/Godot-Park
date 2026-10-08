class_name Shop
extends Interactable
## A food stand. Open while its vendor is at work behind the counter.
## Players buy from a menu; dogs can beg for a sausage at the hot dog stand.

var shop_id := ""
var title := ""
var menu: Array = []
var vendor_id := ""
var counter := Vector3.ZERO
var vendor_spot := Vector3.ZERO
var world: World
var _beg_cooldown := 0.0

const ADVERTS := {
	"donut_stand": ["Frische Donuts! Mit Streuseln!", "Donuts machen glücklich!", "Heute: Pink mit Glitzer!"],
	"hotdog_stand": ["Hot Dogs! Heiß und lecker!", "Mit Senf oder mit viel Senf?", "Der beste Hot Dog der Stadt!"],
	"icecream_cart": ["Eis! Eiskalt und cremig!", "Drei Kugeln, drei Glücksmomente!", "Heute neu: Gurke-Zitrone. Mutig?"],
	"fries_stand": ["Pommes! Rot-weiß oder schranke?", "Frisch frittiert, schön knusprig!", "Wer Pommes isst, ist nie allein!"],
	"kiosk": ["Eis, Brezeln, Entenbrot!", "Pfandflaschen werden hier angenommen!", "Na, was darf's sein?"],
}


func setup(w: World, id: String, spot: Dictionary) -> void:
	world = w
	shop_id = id
	users = "any"
	radius = 2.6
	counter = spot["pos"]
	vendor_spot = spot["vendor"]
	position = counter
	match id:
		"donut_stand":
			title = "Donut-Stand"
			vendor_id = "dora"
			menu = ["donut", "coffee"]
		"hotdog_stand":
			title = "Hot-Dog-Stand"
			vendor_id = "heinz"
			menu = ["hotdog", "pretzel"]
		"icecream_cart":
			title = "Eiswagen"
			vendor_id = "enzo"
			menu = ["icecream", "coffee", "water"]
		"fries_stand":
			title = "Pommesbude"
			vendor_id = "paula"
			menu = ["fries", "water"]
		"kiosk":
			title = "Kiosk"
			vendor_id = "kemal"
			menu = ["icecream", "water", "bread", "balloon", "newspaper"]


func vendor() -> Actor:
	return world.find_actor(vendor_id)


func is_open() -> bool:
	var v := vendor()
	if v == null or v.inside or v.controlled or not v.visible:
		return false
	var b := v.brain as HumanBrain
	return b != null and b.current is Activities.Work and (b.current as Activities.Work).at_post()


func food_entries() -> Array:
	return menu.filter(func(f: String) -> bool: return Food.is_edible(f))


func distance_to(a: Actor) -> float:
	return a.distance_to(counter)


func customer_spot() -> Vector3:
	return counter


func vendor_pos() -> Vector3:
	return vendor_spot


func advert() -> String:
	var lines: Array = ADVERTS.get(shop_id, ["Hallo!"])
	return lines[randi() % lines.size()]


## NPC purchase; returns the food id (or "" when closed).
func serve_npc(customer: Actor, wanted := "") -> String:
	if not is_open():
		return ""
	var food := wanted
	if food == "":
		var edible := food_entries()
		food = edible[randi() % edible.size()]
	if food == "bread":
		customer.add_item("bread", 5)
	var v := vendor()
	v.play_anim("wave", 1.0)
	v.say(["Bitte schön!", "Guten Appetit!", "Lassen Sie's sich schmecken!", "Danke, beehren Sie uns wieder!"][randi() % 4], 2.0)
	return food


func get_prompt(actor: Actor) -> String:
	if not actor.is_human():
		if actor.species == "dog" and shop_id == "hotdog_stand":
			return "Betteln" if is_open() else "Niemand da …"
		return ""
	if not is_open():
		return "%s (geschlossen)" % title
	return "Einkaufen: %s" % title


func can_interact(actor: Actor) -> bool:
	if not actor.is_human():
		return actor.species == "dog" and shop_id == "hotdog_stand"
	return true


func interact(actor: Actor) -> void:
	if not is_open():
		GameState.toast.emit("Hier ist gerade niemand. Komm später wieder!", "warn")
		return
	if not actor.is_human():
		_beg(actor)
		return
	var v := vendor()
	v.say(advert(), 2.5)
	v.face(actor.global_position)
	var options: Array = []
	for f: String in menu:
		var it: Dictionary = Food.ITEMS[f]
		options.append({"text": "%s – %s" % [it["name"], GameState.format_money(it["price"])], "id": f})
	if shop_id == "kiosk" and actor.has_item("empty_bottle"):
		options.push_front({"text": "Pfandflaschen abgeben (%d)" % actor.inventory["empty_bottle"], "id": "_return"})
	options.append({"text": "Nichts, danke.", "id": ""})
	UI.dialog(v.display_name, advert(), options, func(choice: String) -> void: _buy(actor, choice))


func _buy(actor: Actor, food: String) -> void:
	if food == "":
		return
	if food == "_return":
		world.return_bottles(actor)
		return
	var it: Dictionary = Food.ITEMS[food]
	if not GameState.spend(it["price"]):
		return
	Sound.play("coin")
	vendor().say("Bitte schön!", 2.0)
	if food == "bread":
		actor.add_item("bread", 5)
		GameState.toast.emit("Du hast jetzt %d Stück Entenbrot." % actor.inventory["bread"], "info")
		return
	if food in ["balloon", "newspaper"]:
		actor.set_item(it["item"])
		Food.apply(actor, food)
		return
	actor.consume(food)


func _beg(dog: Actor) -> void:
	var v := vendor()
	if _beg_cooldown > Time.get_ticks_msec() / 1000.0:
		v.say("Du schon wieder? Nein!", 2.0)
		dog.play_anim("sit", 2.0)
		return
	dog.play_anim("beg", 2.5)
	if randf() < 0.5:
		_beg_cooldown = Time.get_ticks_msec() / 1000.0 + 60.0
		v.say("Na gut, weil du so lieb guckst …", 2.5)
		dog.consume("sausage")
		dog.emote("heart", 2)
	else:
		v.say("Nix da, das ist für die Kundschaft!", 2.5)
		dog.emote("sad")

class_name Shop
extends Interactable
## A food stand. Open while its vendor is at work behind the counter.
## Players buy from a menu; dogs can beg for a sausage at the hot dog stand.
## Snack machines (no vendor_id) are open day and night.

var shop_id := ""
var title := ""
var menu: Array = []
var vendor_id := ""
var counter := Vector3.ZERO
var vendor_spot := Vector3.ZERO
var world: World
var _beg_cooldown := 0.0
## Nordwald traders: items sold into the bag (id -> price), items bought from the player
## (at Items.value × buy_rate), and the inn's room for the night.
var goods := {}
var buys: Array = []
var buy_rate := 1.0
var room := false
const ROOM_PRICE := 1200

const ADVERTS := {
	"donut_stand": ["Frische Donuts! Mit Streuseln!", "Donuts machen glücklich!", "Heute: Pink mit Glitzer!"],
	"hotdog_stand": ["Hot Dogs! Heiß und lecker!", "Mit Senf oder mit viel Senf?", "Der beste Hot Dog der Stadt!"],
	"icecream_cart": ["Eis! Eiskalt und cremig!", "Drei Kugeln, drei Glücksmomente!", "Heute neu: Gurke-Zitrone. Mutig?"],
	"fries_stand": ["Pommes! Rot-weiß oder schranke?", "Frisch frittiert, schön knusprig!", "Wer Pommes isst, ist nie allein!"],
	"kiosk": ["Eis, Brezeln, Entenbrot!", "Pfandflaschen werden hier angenommen!", "Na, was darf's sein?"],
	"lumber_camp": ["Ohne Axt kein Holz!", "Brauchst du Werkzeug?", "Holz hacken macht hungrig. Und glücklich."],
	"sawmill": ["Wie bitte? Ach so, Holz! Immer her damit!", "Ich kaufe jedes Scheit.", "Bretter, frisch gesägt!"],
	"forest_inn": ["Kaiserschmarrn ist fertig!", "Ein warmes Bett gefällig?", "Setz dich, iss was!"],
	"beehives": ["Summ summ – frischer Honig!", "Meine Bienen haben fleißig gearbeitet.", "Honig vom Waldrand!"],
	"farm_shop": ["Ich kauf dir alles ab, was schmeckt!", "Selbstgemacht verkauft sich am besten!", "Marmelade? Her damit!"],
	"dwarf_office": ["Steine! Erz! Edelsteine!", "Glück auf! Was bringst du?", "Zwerge zahlen fair. Meistens."],
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
		"vending_west", "vending_east":
			title = "Snackautomat"
			menu = ["chocolate", "sandwich", "water"]
		# Nordwald.
		"lumber_camp":
			title = "Holzfällerlager"
			vendor_id = "holger"
			goods = {"stone_axe": 450, "fishing_rod": 600}
		"sawmill":
			title = "Sägewerk"
			vendor_id = "sepp"
			goods = {"board": 150}
			buys = ["log", "board", "cherry_wood", "twig"]
		"forest_inn":
			title = "Waldschänke"
			vendor_id = "waltraud"
			menu = ["kaiserschmarrn", "pilzsuppe", "apfelschorle"]
			buys = ["fish", "mushroom", "berries", "apple"]
			buy_rate = 0.8
			room = true
		"beehives":
			title = "Imkerei"
			vendor_id = "ilse"
			goods = {"honey": 350}
		"farm_shop":
			title = "Hofladen"
			vendor_id = "berta"
			buys = ["apple", "berries", "honey", "jam", "grilled_fish", "mushroom_pan", "baked_apple", "birdhouse", "carving", "stone_gnome"]
		"dwarf_office":
			title = "Zwergenkontor"
			vendor_id = "grimbart"
			goods = {"stone_pickaxe": 450}
			buys = ["stone", "slab", "ore", "gem"]


func vendor() -> Actor:
	return world.find_actor(vendor_id) if vendor_id != "" else null


func is_machine() -> bool:
	return vendor_id == ""


func is_open() -> bool:
	if is_machine():
		return true
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
	if v:
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
	return ("Handeln: %s" if not buys.is_empty() or not goods.is_empty() else "Einkaufen: %s") % title


func can_interact(actor: Actor) -> bool:
	if not actor.is_human():
		return actor.species == "dog" and shop_id == "hotdog_stand"
	return true


## The machine's dialog: no vendor, the snacks drop into the slot.
func _machine_menu(actor: Actor) -> void:
	var options: Array = []
	for f: String in menu:
		var it: Dictionary = Food.ITEMS[f]
		options.append({"text": "%s – %s" % [it["name"], GameState.format_money(it["price"])], "id": f})
	options.append({"text": "Nichts, danke.", "id": ""})
	UI.dialog(title, "Rund um die Uhr geöffnet. Bitte wählen Sie:", options, func(choice: String) -> void: _buy(actor, choice))


func interact(actor: Actor) -> void:
	if not is_open():
		GameState.toast.emit("Hier ist gerade niemand. Komm später wieder!", "warn")
		return
	if not actor.is_human():
		_beg(actor)
		return
	if is_machine():
		_machine_menu(actor)
		return
	var v := vendor()
	v.say(advert(), 2.5)
	v.face(actor.global_position)
	var options: Array = trade_options(actor)
	for f: String in menu:
		var it: Dictionary = Food.ITEMS[f]
		options.append({"text": "%s – %s" % [it["name"], GameState.format_money(it["price"])], "id": f})
	if shop_id == "kiosk" and actor.has_item("empty_bottle"):
		options.push_front({"text": "Pfandflaschen abgeben (%d)" % actor.inventory["empty_bottle"], "id": "_return"})
	options.append({"text": "Nichts, danke.", "id": ""})
	UI.dialog(v.display_name, advert(), options, func(choice: String) -> void: _buy(actor, choice))


## Price a trader pays for one piece of `id`.
func sell_price(id: String) -> int:
	return int(round(Items.value(id) * buy_rate))


## Dialog options for trading: sell everything / single items the trader buys, buy goods,
## rent the room.
func trade_options(actor: Actor) -> Array:
	var out := []
	var total := 0
	var sell := []
	for id: String in Items.sorted_ids(actor.inventory):
		if id in buys:
			var n := int(actor.inventory[id])
			total += n * sell_price(id)
			sell.append({"text": "Verkaufen: %s ×%d – %s" % [Items.name_of(id), n, GameState.format_money(n * sell_price(id))], "id": "sell:" + id})
	if sell.size() > 1:
		out.append({"text": "Alles verkaufen – %s" % GameState.format_money(total), "id": "sell_all"})
	out.append_array(sell)
	if shop_id == "dwarf_office" and actor.has_item("stone_gnome"):
		out.append({"text": "Einen Steinzwerg anbieten", "id": "gnome"})
	for id: String in goods:
		out.append({"text": "Kaufen: %s – %s" % [Items.name_of(id), GameState.format_money(goods[id])], "id": "buy:" + id})
	if room:
		var night := Clock.daylight() < 0.25 or Clock.hour() >= 20.0
		out.append({"text": "%s – %s" % ["Zimmer für die Nacht" if night else "Mittagsschlaf im Gästezimmer",
			GameState.format_money(ROOM_PRICE if night else ROOM_PRICE / 2)], "id": "room"})
	return out


## Sells all pieces of `id` the actor carries; returns the money earned (cents).
func sell(actor: Actor, id: String) -> int:
	var n := int(actor.inventory.get(id, 0))
	if n <= 0 or not id in buys:
		return 0
	actor.take_item(id, n)
	var cents := n * sell_price(id)
	GameState.add_money(cents, "%d× %s verkauft" % [n, Items.name_of(id)])
	GameState.add_stat("trade_cents", cents)
	Sound.play("coin")
	return cents


func _trade(actor: Actor, choice: String) -> void:
	var v := vendor()
	if choice == "sell_all":
		for id: String in actor.inventory.keys():
			if id in buys:
				sell(actor, id)
	elif choice.begins_with("sell:"):
		sell(actor, choice.substr(5))
	elif choice.begins_with("buy:"):
		var id := choice.substr(4)
		if not actor.can_add(id):
			GameState.toast.emit("Der Rucksack ist voll!", "warn")
			return
		if not GameState.spend(goods[id]):
			return
		actor.add_item(id)
		Sound.play("coin")
		GameState.toast.emit("%s ist jetzt im Rucksack." % Items.name_of(id), "info")
	elif choice == "gnome":
		actor.take_item("stone_gnome")
		GameState.set_stat("gnome_insult", 1)
		if v:
			v.say("Ein GARTENZWERG?! Raus damit! Das ist eine Beleidigung!", 4.0)
			v.play_anim("stuck", 2.0)
		GameState.toast.emit("Grimbart wirft den Steinzwerg in hohem Bogen in den Steinbruch.", "info")
		return
	elif choice == "room":
		var night := Clock.daylight() < 0.25 or Clock.hour() >= 20.0
		if not GameState.spend(ROOM_PRICE if night else ROOM_PRICE / 2):
			return
		Sound.play("coin")
		(UI.game.player as PlayerController).sleep_in_bed(night)
		return
	if v:
		v.say("Danke schön!", 2.0)


func _buy(actor: Actor, food: String) -> void:
	if food == "":
		return
	if food.begins_with("sell") or food.begins_with("buy:") or food in ["gnome", "room"]:
		_trade(actor, food)
		return
	if food == "_return":
		world.return_bottles(actor)
		return
	var it: Dictionary = Food.ITEMS[food]
	if food == "bread" and not actor.can_add("bread", 5):
		GameState.toast.emit("Der Rucksack ist voll! Kein Platz für Entenbrot.", "warn")
		return
	if not GameState.spend(it["price"]):
		return
	Sound.play("coin")
	if is_machine():
		GameState.toast.emit("Klonk! %s fällt in die Ausgabe." % it["name"], "info")
	else:
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

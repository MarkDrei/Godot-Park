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

## Every stand and shop: title, menu (Food.ITEMS), goods it sells into the bag (id -> price),
## things it buys from the player (at Items.value × buy_rate), a room for the night, the
## vendor's calls. The vendor is whoever has the shop as work in Cast; machines have none.
const SHOPS := {
	"donut_stand": {"title": "Donut-Stand", "menu": ["donut", "coffee"], "ads": ["Frische Donuts! Mit Streuseln!", "Donuts machen glücklich!", "Heute: Pink mit Glitzer!"]},
	"hotdog_stand": {"title": "Hot-Dog-Stand", "menu": ["hotdog", "pretzel"], "ads": ["Hot Dogs! Heiß und lecker!", "Mit Senf oder mit viel Senf?", "Der beste Hot Dog der Stadt!"]},
	"icecream_cart": {"title": "Eiswagen", "menu": ["icecream", "coffee", "water"], "ads": ["Eis! Eiskalt und cremig!", "Drei Kugeln, drei Glücksmomente!", "Heute neu: Gurke-Zitrone. Mutig?"]},
	"fries_stand": {"title": "Pommesbude", "menu": ["fries", "water"], "ads": ["Pommes! Rot-weiß oder schranke?", "Frisch frittiert, schön knusprig!", "Wer Pommes isst, ist nie allein!"]},
	"kiosk": {"title": "Kiosk", "menu": ["icecream", "water", "bread", "balloon", "newspaper"], "ads": ["Eis, Brezeln, Entenbrot!", "Pfandflaschen werden hier angenommen!", "Na, was darf's sein?"]},
	"vending_west": {"title": "Snackautomat", "menu": ["chocolate", "sandwich", "water"]},
	"vending_east": {"title": "Snackautomat", "menu": ["chocolate", "sandwich", "water"]},
	# Nordwald.
	"lumber_camp": {"title": "Holzfällerlager", "goods": {"stone_axe": 450, "fishing_rod": 600}, "ads": ["Ohne Axt kein Holz!", "Brauchst du Werkzeug?", "Holz hacken macht hungrig. Und glücklich."]},
	"sawmill": {"title": "Sägewerk", "goods": {"board": 150}, "buys": ["log", "board", "cherry_wood", "twig"], "ads": ["Wie bitte? Ach so, Holz! Immer her damit!", "Ich kaufe jedes Scheit.", "Bretter, frisch gesägt!"]},
	"forest_inn": {"title": "Waldschänke", "menu": ["kaiserschmarrn", "pilzsuppe", "apfelschorle"], "buys": ["fish", "mushroom", "berries", "apple"], "buy_rate": 0.8, "room": true, "ads": ["Kaiserschmarrn ist fertig!", "Ein warmes Bett gefällig?", "Setz dich, iss was!"]},
	"beehives": {"title": "Imkerei", "goods": {"honey": 350}, "ads": ["Summ summ – frischer Honig!", "Meine Bienen haben fleißig gearbeitet.", "Honig vom Waldrand!"]},
	"farm_shop": {"title": "Hofladen", "buys": ["apple", "berries", "honey", "jam", "grilled_fish", "mushroom_pan", "baked_apple", "birdhouse", "carving", "stone_gnome"], "ads": ["Ich kauf dir alles ab, was schmeckt!", "Selbstgemacht verkauft sich am besten!", "Marmelade? Her damit!"]},
	# Oststadt.
	"petrol_shop": {"title": "Tankstellen-Shop", "menu": ["coffee", "chocolate", "sandwich", "water", "cola"], "ads": ["Kaffee für die Fahrt?", "Schokoriegel gegen den Hunger!", "Frisch gebrühter Kaffee!"]},
	"drive_in_counter": {"title": "Drive-in-Tresen", "menu": ["burger", "cheeseburger", "fries", "shake", "cola"], "ads": ["Burger! Auch zu Fuß!", "Heute Cheeseburger im Angebot!", "Der Milchshake ist legendär!"]},
	"scrapyard": {"title": "Schrott & Teile", "goods": {"horn_duck": 500, "horn_cucaracha": 800, "horn_fanfare": 1200}, "ads": ["Hupen! Die lustigsten Hupen der Stadt!", "Ersatzteile für jedes Auto!", "Quak! Hören Sie mal!"]},
	# The Kirmes in the Westpark.
	"fair_candy": {"title": "Zuckerwatte", "menu": ["candy_floss"], "ads": ["Zuckerwatte! Rosa wie der Sonnenuntergang!", "So groß wie dein Kopf!", "Süß, süßer, Zuckerwatte!"]},
	"fair_almonds": {"title": "Gebrannte Mandeln", "menu": ["almonds"], "ads": ["Gebrannte Mandeln! Frisch aus dem Kessel!", "Riechst du das? Zimt und Zucker!", "Eine Tüte Glück!"]},
	"fair_sausage": {"title": "Bratwurst", "menu": ["bratwurst", "lemonade"], "ads": ["Bratwurst! Vom Holzkohlegrill!", "Mit Senf, Ketchup oder beidem?", "Heute Wurst, morgen Wurst!"]},
	"fair_crepes": {"title": "Crêpes", "menu": ["crepe", "coffee", "lemonade"], "ads": ["Crêpes! Wie in Paris!", "Zimt und Zucker, très bien!", "Dünn, warm, köstlich!"]},
	"dwarf_office": {"title": "Zwergenkontor", "goods": {"stone_pickaxe": 450}, "buys": ["stone", "slab", "ore", "gem"], "ads": ["Steine! Erz! Edelsteine!", "Glück auf! Was bringst du?", "Zwerge zahlen fair. Meistens."]},
}


func setup(w: World, id: String, spot: Dictionary) -> void:
	world = w
	shop_id = id
	users = "any"
	radius = 2.6
	counter = spot["pos"]
	vendor_spot = spot["vendor"]
	position = counter
	var d: Dictionary = SHOPS[id]
	title = d["title"]
	vendor_id = Cast.vendor_of(id)
	menu = d.get("menu", []).duplicate()
	goods = d.get("goods", {}).duplicate()
	buys = d.get("buys", []).duplicate()
	buy_rate = d.get("buy_rate", 1.0)
	room = d.get("room", false)


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
	var lines: Array = SHOPS[shop_id].get("ads", ["Hallo!"])
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
	var takeaway := FairStories.takeaway_for(shop_id)
	if takeaway != "" and FairStories.delivery_active() and not actor.has_item(takeaway):
		options.push_front({"text": "%s für Max – %s" % [Items.name_of(takeaway), GameState.format_money(FairStories.TAKEAWAY_PRICE)], "id": "_takeaway"})
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
		if not actor.room_for(id):
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
	if food == "_takeaway":
		var id := FairStories.takeaway_for(shop_id)
		if not actor.room_for(id):
			return
		if not GameState.spend(FairStories.TAKEAWAY_PRICE):
			return
		Sound.play("coin")
		actor.add_item(id)
		vendor().say("Schön warm eingepackt!", 2.0)
		GameState.toast.emit("%s ist im Rucksack. Ab zu Muskel-Max!" % Items.name_of(id), "info")
		return
	var it: Dictionary = Food.ITEMS[food]
	if food == "bread" and not actor.room_for("bread", 5):
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
	if _beg_cooldown > Clock.now():
		v.say("Du schon wieder? Nein!", 2.0)
		dog.play_anim("sit", 2.0)
		return
	dog.play_anim("beg", 2.5)
	if randf() < 0.5:
		_beg_cooldown = Clock.now() + 60.0
		v.say("Na gut, weil du so lieb guckst …", 2.5)
		dog.consume("sausage")
		dog.emote("heart", 2)
	else:
		v.say("Nix da, das ist für die Kundschaft!", 2.5)
		dog.emote("sad")

class_name FairTrade
extends RefCounted
## Tickets in and out (doc/kirmes.md): Los-Lothar's lottery tickets and the prize counter,
## where Spielhallen-Sascha trades tickets for useful things only – no cuddly toys.

## Prizes: item id -> tickets. The Bauchladen is the biggest prize (Hauptgewinn).
const PRIZES := {"honey": 10, "ore": 15, "cherry_wood": 25, "horn_duck": 25, "fishing_rod": 30, "gem": 60,
	"iron_axe": 70, "iron_pickaxe": 70, "vendor_tray": 150}
const GRAND_PRIZE := "vendor_tray"
const LOT_PRICE := 50
## A lottery ticket: [chance, tickets, Lothar's line].
const LOTS := [
	[0.5, 0, "Niete! Aber was für eine schöne."],
	[0.3, 2, "Zwei Tickets! Immerhin."],
	[0.14, 5, "Fünf Tickets! Das Glück ist mit dir."],
	[0.05, 15, "Fünfzehn Tickets! Donnerwetter!"],
	[0.01, 50, "Das Hauptgewinn-Los! Fünfzig Tickets!"],
]


## Buys a lottery ticket and draws it; returns the tickets won (or -1 without money).
static func buy_lot(a: Actor) -> int:
	if not GameState.spend(LOT_PRICE):
		return -1
	var r := randf()
	var lot: Array = LOTS[0]
	for l: Array in LOTS:
		r -= l[0]
		if r <= 0.0:
			lot = l
			break
	var won: int = lot[1]
	FairPass.stamp("lots")
	GameState.add_stat("lots_bought")
	var host := a.world.find_actor("lothar")
	if host:
		host.say(lot[2], 3.0)
		host.play_anim("cheer" if won > 0 else "talk", 1.5)
	if won > 0:
		GameState.add_tickets(won, "Los")
		Sound.play("coin")
	else:
		GameState.toast.emit("Niete.", "info")
	return won


## The prize counter's dialog.
static func open_prizes(a: Actor) -> void:
	var options := []
	for id: String in PRIZES:
		var n: int = PRIZES[id]
		options.append({"text": "%s – %d Tickets" % [Items.name_of(id), n], "id": id})
	options.append({"text": "Nichts, danke.", "id": ""})
	var host := a.world.find_actor("sascha")
	var who := host.display_name if host else "Gewinnausgabe"
	UI.dialog(who, "Du hast %d Tickets. Hier gibt's nur Nützliches – versprochen!" % GameState.tickets, options,
		func(choice: String) -> void:
			if choice != "":
				redeem(a, choice))


## Trades tickets for a prize into the bag; returns true when it worked.
static func redeem(a: Actor, id: String) -> bool:
	var n: int = PRIZES.get(id, 0)
	if n <= 0:
		return false
	if not a.can_add(id):
		GameState.toast.emit("Der Rucksack ist voll!", "warn")
		return false
	if not GameState.spend_tickets(n):
		return false
	a.add_item(id)
	Sound.play("success")
	GameState.toast.emit("%s ist jetzt im Rucksack." % Items.name_of(id), "info")
	if id == GRAND_PRIZE:
		GameState.set_stat("grand_prize", 1)
	return true

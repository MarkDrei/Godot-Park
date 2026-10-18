class_name DeliveryJob
extends DriveJob
## Burger delivery for Burger-Bodo: in the "Burger-Express" van, bring three orders to their
## addresses while they are still warm (a minute each). Stop in front of the house. Bodo gives
## the orders: take them at his counter, then get into the van; he calls over the radio.

const ORDERS := 3
const WARM := 60.0

var delivered := 0
var earned := 0
var warm := 0.0
var house := {}
var _hurried := false


func _init() -> void:
	super()
	title = "Burger-Lieferdienst"
	host_id = "bodo"
	vehicle_kind = "delivery"
	needs_order = true
	order_option = "Lieferaufträge übernehmen"
	order_line = "Drei Bestellungen! Der Burger-Express steht vorn am Drive-in, die Tüten sind schon drin."
	order_hint = "Burger-Bodos Aufträge: Steig in den Burger-Express am Drive-in."
	bump_lines = ["Vorsicht, die Burger! Die sind gestapelt!", "Wenn die Soße ausläuft, wischst du!"]


func describe() -> String:
	return "Bei Burger-Bodo (Drive-in) die Lieferaufträge holen, dann mit dem Burger-Express drei Bestellungen ausliefern, solange sie warm sind."


func goal_done() -> bool:
	return GameState.stat("deliveries_warm") >= 3


func begin() -> void:
	start_driving()
	delivered = 0
	earned = 0
	host_say("Drei Bestellungen! Schnell, bevor sie kalt werden!", 3.0)
	_next()


func _next() -> void:
	house = house_away_from(car().pos2(), 70.0, rng, 230.0)
	warm = WARM
	_hurried = false
	show_target(house["curb"], CityLayout.address(house), Color(1.0, 0.6, 0.3))


func job_tick(delta: float) -> void:
	warm = maxf(0.0, warm - delta)
	if warm < 20.0 and not _hurried:
		_hurried = true
		radio("Beeil dich, die Pommes werden labbrig!")
	set_score("Bestellung %d/%d · noch warm: %d s · %s" % [delivered + 1, ORDERS, int(warm), way_text()])
	if arrived():
		_deliver()


func _deliver() -> void:
	var pay := 250 + (200 if warm > 0.0 else 0) - bumps * 50
	pay = maxi(150, pay)
	earned += pay
	delivered += 1
	bumps = 0
	GameState.add_stat("deliveries")
	if warm > 0.0:
		GameState.add_stat("deliveries_warm")
	GameState.add_money(pay, "Lieferung %s" % ("noch warm!" if warm > 0.0 else "(lauwarm)"))
	Sound.play("coin")
	if delivered >= ORDERS:
		end({"won": true, "joy": 18.0, "text": "Alle drei Bestellungen ausgeliefert – %s verdient." % GameState.format_money(earned)
			+ quote("Alle satt! Du bist mein bester Fahrer.")})
	else:
		radio("Der Kunde ist begeistert! Weiter zur nächsten Adresse." if warm > 0.0 else "Lauwarm? Der Kunde hat gemeckert. Die nächste schneller!")
		_next()


func left_line() -> String:
	return "He, die Burger werden kalt!"

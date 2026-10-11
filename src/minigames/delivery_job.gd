class_name DeliveryJob
extends DriveJob
## Burger delivery for Burger-Bodo: in the "Burger-Express" van, bring three orders to their
## addresses while they are still warm (a minute each). Stop in front of the house.

const ORDERS := 3
const WARM := 60.0

var rng := RandomNumberGenerator.new()
var delivered := 0
var earned := 0
var warm := 0.0
var house := {}


func _init() -> void:
	super()
	title = "Burger-Lieferdienst"
	host_id = "bodo"
	vehicle_kind = "delivery"
	rng.randomize()


func describe() -> String:
	return "Mit Burger-Bodos Lieferwagen (am Drive-in) drei Bestellungen ausliefern, solange sie warm sind."


func begin() -> void:
	start_driving()
	delivered = 0
	earned = 0
	host_say("Drei Bestellungen! Schnell, bevor sie kalt werden!", 3.0)
	_next()


func _next() -> void:
	house = house_away_from(car().pos2(), 70.0, rng)
	warm = WARM
	show_target(house["curb"], CityLayout.address(house), Color(1.0, 0.6, 0.3))


func job_tick(delta: float) -> void:
	warm = maxf(0.0, warm - delta)
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
		end({"won": true, "joy": 18.0, "text": "Alle drei Bestellungen ausgeliefert – %s verdient." % GameState.format_money(earned)})
	else:
		_next()

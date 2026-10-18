class_name TaxiJob
extends DriveJob
## Taxi with Taxi-Tanja: get into a taxi and start a shift at the taxi company. People wave at
## the roadside; pick them up (stop next to them), drive them to their address, get paid by
## the way and the time; bumps cost the tip. Four fares per shift. Tanja is on the radio
## from the Taxi-Zentrale; the passenger talks from the back seat (in the panel).

const FARES := 4
const START_LINES := ["Taxi-Zentrale hier. Schön, dass du fährst! Gleich kommt Kundschaft.",
	"Zentrale an Taxi: Kundschaft wartet schon. Ich schick dir den Standort."]
const TIP_LINES := ["Trinkgeld! So mag ich das. Der Nächste winkt schon.",
	"Sauber gefahren! Ich hab schon die nächste Kundschaft für dich."]
const NO_TIP_LINES := ["Kein Trinkgeld? Sanfter fahren, dann klappt's. Der Nächste wartet.",
	"Na ja, das ging holprig. Weiter, da winkt schon jemand."]
const BUMP_LINES := ["Hey, das ist mein Taxi! Sachte!", "Pass auf die Stoßstange auf!", "Autsch. Das hab ich bis hierher gehört."]
## The passenger on the way (no voice: anyone from the town).
const CHAT := ["Schönes Wetter heute, oder?", "Ich bin echt spät dran.", "Sie fahren ja richtig gut!",
	"Meine Oma wohnt da vorne. Na ja, ungefähr.", "Darf ich das Radio anmachen? War ein Witz.", "Hier hat sich ja viel verändert."]
const OUCH := ["Huch! Vorsicht!", "Autsch, mein Kaffee!", "Geht's auch sanfter?"]

var fares_done := 0
var earned := 0
var passenger: Actor
var state := ""               # pickup, ride
var ride_time := 0.0
var ride_dist := 0.0
var destination := {}
var _chat_at := 0.0


func _init() -> void:
	super()
	title = "Taxi fahren"
	host_id = "tanja"
	vehicle_kind = "taxi"


func describe() -> String:
	return "Steig in eines von Taxi-Tanjas Taxis (Taxi-Zentrale an der Parkallee) und starte dort eine Schicht: vier Fahrgäste, Trinkgeld für zügiges, sanftes Fahren."


func goal_done() -> bool:
	return GameState.stat("taxi_fares") >= 4


func begin() -> void:
	start_driving()
	fares_done = 0
	earned = 0
	set_info("Fahrgäste winken am Straßenrand. Neben ihnen anhalten zum Einsteigen.")
	radio(pick(START_LINES))
	_next_fare()


func _next_fare() -> void:
	passenger = _pick_passenger()
	if passenger == null:
		end({"won": fares_done > 0, "money": 0, "text": "Heute will niemand mehr Taxi fahren."})
		return
	state = "pickup"
	var p := _roadside_spot()
	passenger.brain.suspend()
	(passenger.brain as HumanBrain).think = 600.0
	passenger.teleport(Vector3(p.x, 0, p.y))
	passenger.play_anim("wave", 600.0)
	var curb := _curb_of(p)
	show_target(curb, "%s winkt" % passenger.display_name, Color(1.0, 0.85, 0.2))
	_update_score()


## A passer-by out in town, not near the car.
func _pick_passenger() -> Actor:
	var options: Array[Actor] = []
	for a in world.actors:
		if a.home_region == "city" and a.actor_id.begins_with("citizen_") and not a.inside and not a.controlled and a.visible:
			options.append(a)
	if options.is_empty():
		# Nobody out: somebody steps out of a house.
		for a in world.actors:
			if a.actor_id.begins_with("citizen_") and not a.controlled:
				a.inside = false
				a.visible = true
				options.append(a)
	return options[rng.randi() % options.size()] if not options.is_empty() else null


## A sidewalk spot 50–200 m from the car, at a house front.
func _roadside_spot() -> Vector2:
	var c := car().pos2()
	var houses := CityLayout.houses()
	for i in 60:
		var h: Dictionary = houses[rng.randi() % houses.size()]
		var d := (h["curb"] as Vector2).distance_to(c)
		if d > 50.0 and d < 200.0:
			return _sidewalk_of(h)
	return _sidewalk_of(houses[0])


## The sidewalk in front of a house (between the front garden and the road).
static func _sidewalk_of(h: Dictionary) -> Vector2:
	var curb: Vector2 = h["curb"]
	var front: Vector2 = h["front"]
	return curb - front * (CityLayout.ROAD_HALF - CityLayout.PARK_OFFSET + CityLayout.WALK * 0.5)


## Where the taxi stops for a sidewalk spot: the parking strip next to it.
static func _curb_of(p: Vector2) -> Vector2:
	for h: Dictionary in CityLayout.houses():
		if _sidewalk_of(h).distance_to(p) < 0.5:
			return h["curb"]
	return p


func job_tick(delta: float) -> void:
	set_score("Fahrgast %d/%d · %s · %s" % [mini(fares_done + 1, FARES), FARES, GameState.format_money(earned), way_text()])
	match state:
		"pickup":
			if arrived():
				_pick_up()
		"ride":
			ride_time += delta
			if ride_time >= _chat_at and _chat_at > 0.0:
				_chat_at = 0.0
				panel_line(passenger.display_name, pick(CHAT))
			if arrived():
				_drop_off()


func _pick_up() -> void:
	passenger.play_anim("idle", 0.0)
	passenger.visible = false
	state = "ride"
	ride_time = 0.0
	bumps = 0
	destination = house_away_from(car().pos2(), 120.0, rng, 400.0)
	ride_dist = car().pos2().distance_to(destination["curb"])
	show_target(destination["curb"], CityLayout.address(destination), Color(0.5, 0.9, 1.0))
	passenger.last_said = "Zur %s, bitte!" % CityLayout.address(destination)
	panel_line(passenger.display_name, passenger.last_said)
	GameState.toast.emit("%s steigt ein: „Zur %s, bitte!“" % [passenger.display_name, CityLayout.address(destination)], "info")
	_chat_at = rng.randf_range(8.0, 14.0)
	Sound.play("click")


## A hard bump: the passenger in the back complains, without one Tanja does.
func bumped_hard() -> void:
	if state == "ride" and passenger:
		panel_line(passenger.display_name, pick(OUCH))
	else:
		radio(pick(BUMP_LINES))


## Fare: 3 € + 2,50 € per 100 m (straight line); tip for a quick, gentle ride.
func fare() -> Dictionary:
	var base := 300 + int(ride_dist * 2.5)
	var expected := ride_dist / 7.0 * 1.6 + 8.0
	var tip := 0
	if ride_time < expected:
		tip = 150
	tip = maxi(0, tip + 100 - bumps * 80)
	return {"base": base, "tip": tip}


func _drop_off() -> void:
	var f := fare()
	var pay: int = f["base"] + f["tip"]
	earned += pay
	fares_done += 1
	GameState.add_stat("taxi_fares")
	GameState.add_money(pay, "Taxifahrt%s" % (" mit Trinkgeld" if f["tip"] > 0 else ""))
	var drop := _sidewalk_of(destination)
	passenger.teleport(Vector3(drop.x, 0, drop.y))
	passenger.visible = true
	passenger.say(["Danke, stimmt so!", "Schnell und sicher!", "Das war eine Fahrt!", "Puh, endlich da."][rng.randi() % 4] if f["tip"] > 0 else "Na ja … Danke.", 2.5)
	(passenger.brain as HumanBrain).think = 1.0
	passenger = null
	hide_target()
	if fares_done >= FARES:
		GameState.set_stat_max("taxi_best_shift", earned)
		end({"won": true, "joy": 20.0, "text": "Schicht geschafft! %d Fahrgäste, %s verdient." % [fares_done, GameState.format_money(earned)]
			+ quote("Feierabend! Du fährst fast so gut wie ich.")})
	else:
		radio(pick(TIP_LINES if f["tip"] > 0 else NO_TIP_LINES))
		_next_fare()


func left_line() -> String:
	return "Schon Feierabend? Stell das Taxi bitte ordentlich ab."


func _update_score() -> void:
	set_score("Fahrgäste %d / %d · verdient %s" % [fares_done, FARES, GameState.format_money(earned)])


func cleanup() -> void:
	super()
	if passenger and is_instance_valid(passenger):
		passenger.visible = true
		passenger.play_anim("idle", 0.0)
		if passenger.brain is HumanBrain:
			(passenger.brain as HumanBrain).think = 1.0
		if state == "ride":
			var p := actor.ground_pos() if actor else passenger.ground_pos()
			var c := world.nav.nearest_open(p)
			if c.x >= 0:
				var q := ParkMap.cell_center(c)
				passenger.teleport(Vector3(q.x, 0, q.y))
	passenger = null
	state = ""

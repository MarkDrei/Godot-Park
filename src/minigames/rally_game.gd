class_name RallyGame
extends DriveJob
## Oldtimer rally with Opa Egon: in his oldtimer, five riddles lead through the Oststadt. Drive
## to the place the riddle means and stop there for a photo. After 45 seconds a light pillar
## helps. The faster, the more Egon pays.

const STAGES := 5
const HINT_AFTER := 45.0
## Riddle, place name, point on the road in front of it.
const CLUES := [
	["Wo man unter freiem Himmel Filme schaut.", "Autokino", Vector2(175.5, -158.25)],
	["Hier reicht man Burger durchs Autofenster.", "Drive-in", Vector2(160.3, -60.0)],
	["Ein Turm, der sonntags läutet.", "Kirche St. Martin", Vector2(281.75, -51.0)],
	["Wo alte Autos übereinander schlafen.", "Schrottplatz", Vector2(314.5, -161.75)],
	["Hier drehen kleine Rennwagen ihre Runden.", "Kartbahn", Vector2(245.5, -161.75)],
	["Wo Toni die Scheiben putzt.", "Tankstelle", Vector2(176.0, -118.0)],
	["Ein Brunnen, Bänke und viele Tauben – mitten in der Stadt.", "Marktplatz", Vector2(211.75, -51.0)],
	["Wo die Müllwagen nachts schlafen.", "Betriebshof", Vector2(351.75, -201.0)],
	["Taxi-Tanja wartet hier auf Kundschaft.", "Taxi-Zentrale", Vector2(183.0, -10.25)],
	["Wo man lernt, rückwärts einzuparken.", "Fahrschule", Vector2(281.75, -132.0)],
]

var rng := RandomNumberGenerator.new()
var order: Array[int] = []
var stage := 0
var stage_time := 0.0
var total_time := 0.0


func _init() -> void:
	super()
	title = "Oldtimer-Rallye"
	host_id = "egon"
	vehicle_kind = "oldtimer"
	rng.randomize()


func describe() -> String:
	return "Opa Egon leiht dir seinen Oldtimer (vor seiner Garage am Südring): fünf Rätsel, fünf Orte in der Oststadt – je schneller, desto besser."


func begin() -> void:
	start_driving()
	order.clear()
	var all := range(CLUES.size())
	all.shuffle()
	for i in STAGES:
		order.append(all[i])
	stage = 0
	total_time = 0.0
	host_say("Gib gut auf ihn acht! Und nun: das erste Rätsel.", 3.0)
	_show_clue()


func clue() -> Array:
	return CLUES[order[stage]]


func _show_clue() -> void:
	stage_time = 0.0
	hide_target()
	target = clue()[2]          # known to arrived(), but no pillar yet
	set_info("Rätsel %d/%d: „%s“" % [stage + 1, STAGES, clue()[0]])


func job_tick(delta: float) -> void:
	stage_time += delta
	total_time += delta
	set_score("Rätsel %d/%d · %d s" % [stage + 1, STAGES, int(total_time)])
	if stage_time > HINT_AFTER and (_beam == null or not _beam.visible):
		show_target(clue()[2], "", Color(1.0, 0.9, 0.5))
		set_info("Rätsel %d/%d: „%s“ – Tipp: die Lichtsäule." % [stage + 1, STAGES, clue()[0]])
	if arrived(10.0):
		Sound.play("click")
		GameState.toast.emit("Klick! Foto vor dem Ort „%s“." % clue()[1], "info")
		stage += 1
		if stage >= STAGES:
			_finish()
		else:
			_show_clue()


func _finish() -> void:
	var t := int(total_time)
	var money := maxi(200, 1200 - t * 3)
	GameState.add_stat("rallies")
	if GameState.stats.get("rally_best_time", 0) == 0 or t < GameState.stats.get("rally_best_time", 0):
		GameState.stats["rally_best_time"] = t
	GameState.set_stat_max("rally_fast", 1 if t <= 240 else 0)
	end({"won": t <= 240, "money": money, "joy": 22.0,
		"text": "Rallye geschafft in %d:%02d Minuten! Opa Egon strahlt." % [t / 60, t % 60]})


func job_left() -> void:
	end({"won": false, "joy": 3.0, "text": "Rallye abgebrochen – Egon nimmt seinen Oldtimer zurück."})

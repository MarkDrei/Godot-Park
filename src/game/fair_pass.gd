class_name FairPass
extends RefCounted
## The Kirmes's stamp card (doc/kirmes.md): one stamp for every ride, booth and the arcade,
## shown in the notebook. Rides also count per ride for "Karussell-Profi" (every ride three
## times).

const STAMPS := [
	["ferris", "Riesenrad"], ["carousel", "Karussell"], ["chain", "Kettenkarussell"], ["swing", "Schiffschaukel"],
	["ghost", "Geisterbahn"], ["coaster", "Achterbahn"], ["bumper", "Autoscooter"],
	["cans", "Dosenwerfen"], ["ducks", "Entenangeln"], ["rings", "Ringwurf"], ["darts", "Ballon-Darts"],
	["moles", "Hau den Maulwurf"], ["wheel", "Glücksrad"], ["lots", "Lose"], ["striker", "Hau den Lukas"],
	["arcade", "Spielhalle"],
]
const RIDES := ["ferris", "carousel", "chain", "swing", "ghost", "coaster", "bumper"]


static func stamp_name(id: String) -> String:
	for s: Array in STAMPS:
		if s[0] == id:
			return s[1]
	return id


static func has(id: String) -> bool:
	return GameState.has_in_set("stamps", id)


## A stamp on the card (once per booth or ride).
static func stamp(id: String) -> void:
	if GameState.add_to_set("stamps", id):
		GameState.toast.emit("Stempelpass: %s gestempelt! (%d von %d)" % [stamp_name(id), GameState.stat("stamps"), STAMPS.size()], "info")


## After a ride: the stamp and the ride counter (three times every ride: Karussell-Profi).
static func rode(id: String) -> void:
	GameState.add_stat("ride_" + id)
	stamp(id)
	var thrice := 0
	for r: String in RIDES:
		if GameState.stat("ride_" + r) >= 3:
			thrice += 1
	GameState.set_stat_max("rides_thrice", thrice)


## The notebook's entry.
static func tasks() -> Array:
	var done: Array[String] = []
	var missing: Array[String] = []
	for s: Array in STAMPS:
		(done if has(s[0]) else missing).append(s[1])
	var desc := "Probier jede Bude und jedes Fahrgeschäft der Kirmes einmal aus."
	if not done.is_empty():
		desc += "\nGestempelt: " + ", ".join(done)
	if not missing.is_empty():
		desc += "\nFehlt noch: " + ", ".join(missing)
	return [{"title": "Kirmes: Stempelpass (%d/%d)" % [done.size(), STAMPS.size()], "desc": desc, "done": missing.is_empty(), "area": "fair"}]

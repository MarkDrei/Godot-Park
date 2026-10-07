class_name Achievements
extends RefCounted
## Achievement definitions. Each one is unlocked when its stat reaches `target`.
## Stats are counters or sets kept in GameState (`set` = number of distinct items).

const DEFS := [
	{"id": "duck_whisperer", "title": "Entenflüsterer", "desc": "Füttere 20 Enten.", "stat": "ducks_fed", "target": 20, "reward": 300},
	{"id": "sugar_rush", "title": "Zuckerschock", "desc": "Iss 5 Donuts hintereinander.", "stat": "donut_streak", "target": 5, "reward": 200},
	{"id": "bench_presser", "title": "Bankdrücker", "desc": "Sitz auf 25 verschiedenen Parkbänken.", "stat": "benches", "target": 25, "reward": 1000},
	{"id": "boule_king", "title": "Boule-König", "desc": "Gewinne 3 Partien Boule.", "stat": "boule_wins", "target": 3, "reward": 400},
	{"id": "hole_in_one", "title": "Ass!", "desc": "Schaffe beim Minigolf ein Hole-in-One.", "stat": "hole_in_one", "target": 1, "reward": 300},
	{"id": "minigolf_pro", "title": "Minigolf-Profi", "desc": "Spiele eine Runde Minigolf unter Par.", "stat": "minigolf_under_par", "target": 1, "reward": 500},
	{"id": "eagle_eye", "title": "Adlerauge", "desc": "Gewinne 3-mal hintereinander beim Hütchenspiel.", "stat": "shell_streak", "target": 3, "reward": 300},
	{"id": "frisbee_pro", "title": "Frisbee-Profi", "desc": "Der Hund fängt 5 Würfe in einer Runde.", "stat": "frisbee_catches", "target": 5, "reward": 300},
	{"id": "star_photographer", "title": "Starfotograf", "desc": "Mach ein perfektes Foto für eine Touristin.", "stat": "perfect_photos", "target": 1, "reward": 300},
	{"id": "bottle_king", "title": "Pfandkönig", "desc": "Sammle 50 Pfandflaschen.", "stat": "bottles", "target": 50, "reward": 500},
	{"id": "dog_walker", "title": "Gassi-Profi", "desc": "Erledige 5 Gassi-Aufträge.", "stat": "dog_walks", "target": 5, "reward": 500},
	{"id": "duck_feast", "title": "Futterchaos", "desc": "Erreiche 15 Punkte beim Entenfüttern.", "stat": "duck_game_best", "target": 15, "reward": 300},
	{"id": "boris_beaten", "title": "Großmeister", "desc": "Besiege Boris im Tic-Tac-Toe.", "stat": "ttt_wins", "target": 1, "reward": 400},
	{"id": "shape_shifter", "title": "Verwandlungskünstler", "desc": "Spiele 10 verschiedene Figuren.", "stat": "characters", "target": 10, "reward": 500},
	{"id": "night_owl", "title": "Nachteule", "desc": "Sei um Mitternacht im Park.", "stat": "midnight", "target": 1, "reward": 200},
	{"id": "rain_dancer", "title": "Regentänzer", "desc": "Tanze im Regen.", "stat": "rain_dance", "target": 1, "reward": 200},
	{"id": "all_seasons", "title": "Vier Jahreszeiten", "desc": "Erlebe alle Jahreszeiten im Park.", "stat": "seasons", "target": 4, "reward": 500},
	{"id": "saver", "title": "Sparschwein", "desc": "Habe 50 € auf einmal.", "stat": "money_max", "target": 5000, "reward": 0},
	{"id": "cat_and_mouse", "title": "Katz und Maus", "desc": "Erschrecke als Katze 3 Mäuse.", "stat": "mice_scared", "target": 3, "reward": 200},
	{"id": "squirrel_climber", "title": "Kletterass", "desc": "Klettere als Eichhörnchen auf 5 Bäume.", "stat": "trees_climbed", "target": 5, "reward": 200},
	{"id": "gourmet", "title": "Feinschmecker", "desc": "Probiere alles: Donut, Hot Dog, Eis, Brezel.", "stat": "foods", "target": 4, "reward": 300},
	{"id": "gnome_hunter", "title": "Zwergenjäger", "desc": "Finde alle 7 versteckten Gartenzwerge.", "stat": "gnomes", "target": 7, "reward": 1000, "hidden": true},
	{"id": "mime_saver", "title": "Unsichtbare Hilfe", "desc": "Befreie den Pantomimen aus seiner Box.", "stat": "mime_freed", "target": 1, "reward": 500, "hidden": true},
	{"id": "nessie", "title": "Seeungeheuer!", "desc": "Sichte das Ungeheuer im Ententeich.", "stat": "nessie", "target": 1, "reward": 700, "hidden": true},
	{"id": "troll", "title": "Brückenrätsel", "desc": "Löse das Rätsel des Brückentrolls.", "stat": "troll", "target": 1, "reward": 700, "hidden": true},
	{"id": "wishing_well", "title": "Wunschbrunnen", "desc": "Wirf eine Münze in den Brunnen.", "stat": "wishes", "target": 1, "reward": 0, "hidden": true},
	{"id": "stash", "title": "Diebesgut", "desc": "Finde Nussis geheimes Donut-Versteck.", "stat": "stash", "target": 1, "reward": 500, "hidden": true},
	{"id": "ufo", "title": "Unheimliche Begegnung", "desc": "Beobachte das UFO über der Großen Wiese.", "stat": "ufo", "target": 1, "reward": 700, "hidden": true},
	{"id": "quack", "title": "Quak!", "desc": "Entdecke den Enten-Code.", "stat": "quack", "target": 1, "reward": 100, "hidden": true},
]


static func get_def(id: String) -> Dictionary:
	for d: Dictionary in DEFS:
		if d["id"] == id:
			return d
	return {}


static func for_stat(stat: String) -> Array:
	var out := []
	for d: Dictionary in DEFS:
		if d["stat"] == stat:
			out.append(d)
	return out

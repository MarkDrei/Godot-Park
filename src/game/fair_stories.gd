class_name FairStories
extends QuestModule
## Figures, quests and secrets of the Kirmes (doc/kirmes.md, phase 6):
## - Madame Esmeralda reads the future: one cryptic hint per day about a real secret.
## - The great Zambini's mental arithmetic tricks, and his story: Hoppel, his rabbit, vanished
##   during the vanishing trick (the only multi-stage quest of the Westpark).
## - Gisbert, the fair ghost, floats at the ghost train at night and looks for his pocket watch.
## - Lia lost her teddy.
## - Easter eggs without hints: the golden duck (a new place every day), the golden gondola,
##   the bench under the rose arbour (sit on it ten times), Los-Lothar's third line, the
##   arcade's back room (for the Highscore-König).
## State: GameState flags "fs_teddy", "fs_ghost" ("" | "active" | "done"), stats
## "assistant_step" (0..6), "hint_day", "teddy_spot", "golden_duck_day", "rose_sits", the set
## "tricks".

## The assistant quest: 0 untold, 1 ask Esmeralda, 2 ride the ghost train, 3 ask Gustav,
## 4 follow the carrots, 5 Hoppel in the bag, 6 done.
const TEDDY_SPOTS := [Vector2(-297.5, 70.5), Vector2(-149.5, -47.5), Vector2(-179.0, 71.0), Vector2(-327.0, 70.0)]
const TEDDY_HINTS := ["unter einem Schiff, das nie ins Wasser fährt", "im Schilf am Seerosenteich",
	"neben der Bühne, auf der gezaubert wird", "unter den Linden, wo es ganz ruhig ist"]
const DUCK_SPOTS := [Vector2(-160, -52), Vector2(-257, -1.5), Vector2(-184, 11.5), Vector2(-156.5, 49.5),
	Vector2(-236, -75), Vector2(-371, 77), Vector2(-191.5, -73.5), Vector2(-337, -45.5)]
const HOPPEL_AT := Vector2(-189.0, -74.6)
const GHOST_AT := Vector2(-293.5, -51.0)
const TRICKS := ["cards", "1089", "four", "guess"]
const TRICK_NAMES := {"cards": "Der Gedankenleser", "1089": "Die magische 1089", "four": "Immer die Vier", "guess": "Die erratene Zahl"}
const ROSE_SITS := 10
## Hunger delivery: Muskel-Max wants a hot dog and fries from the city park, still warm.
const TAKEAWAY_PRICE := 250
const WARM_MINUTES := 360.0
const TAKEAWAY := {"hotdog_stand": "takeaway_hotdog", "fries_stand": "takeaway_fries"}

var ghost: Node3D
var _ghost_spot: FunctionSpot
var _teddy: Node3D
var _duck: Node3D
var _hoppel: Node3D
var _carrots: Node3D
var _flock: Node3D
var _flock_t := 0.0
var _rose_seat_was := false
var _t := 0.0


func setup(g: Game) -> void:
	super(g)
	world.fair_built.connect(_build)


func quest_givers() -> Array:
	return ["esmeralda", "zambini", "geistgustav", "fairkid_1", "max"]


static func step() -> int:
	return GameState.stat("assistant_step")


static func set_step(n: int) -> void:
	GameState.set_stat_max("assistant_step", n)


## The world's things of the stories, once the Westpark is built.
func _build() -> void:
	var f := world.fair
	ghost = Node3D.new()
	ghost.name = "Gisbert"
	var gm := MeshInstance3D.new()
	gm.mesh = FairModels.ghost()
	ghost.add_child(gm)
	ghost.position = _ground(GHOST_AT)
	ghost.rotation.y = 0.4
	f.add_child(ghost)
	_ghost_spot = _spot(f, GHOST_AT + Vector2(0, 1.2), 2.4, func(_a: Actor) -> String:
		return "Den Geist ansprechen" if ghost_out() else "", _talk_ghost)
	_teddy = _thing(f, FairModels.teddy(), Vector2.ZERO, "Teddy")
	_spot(f, Vector2.ZERO, 1.4, func(_a: Actor) -> String: return "Teddy aufheben" if _teddy.visible else "", _pick_teddy, _teddy)
	_duck = _thing(f, FairModels.golden_duck(), Vector2.ZERO, "GoldenDuck")
	_spot(f, Vector2.ZERO, 1.2, func(_a: Actor) -> String: return "Goldene Ente aufheben" if _duck.visible else "", _pick_duck, _duck)
	_hoppel = _thing(f, FairModels.rabbit(), HOPPEL_AT, "Hoppel")
	_spot(f, HOPPEL_AT, 1.4, func(_a: Actor) -> String: return "Hoppel einfangen" if _hoppel.visible else "", _catch_hoppel, _hoppel)
	_carrots = Node3D.new()
	_carrots.name = "Carrots"
	f.add_child(_carrots)
	var from := Vector2(-272, -73.5)
	for i in 12:
		var p := from.lerp(HOPPEL_AT + Vector2(-2.5, 0.5), float(i) / 11.0) + Vector2(sin(i * 1.7) * 0.8, cos(i * 1.3) * 0.6)
		var c := MeshInstance3D.new()
		c.mesh = FairModels.carrot()
		c.position = _ground(p)
		c.rotation.y = i * 0.9
		_carrots.add_child(c)
	# The arcade's back room door (left wall, at the back).
	var hall := FairLayout.place("arcade")
	var door := hall + Vector2(-11.2, -4.5)
	var dk := MeshKit.new()
	dk.box(Vector3(0, 1.05, 0), Vector3(0.08, 2.1, 1.0), Color("3a2a1a"))
	dk.box(Vector3(0.05, 1.6, 0), Vector3(0.02, 0.25, 0.6), Color("c0392b"))
	var dm := MeshInstance3D.new()
	dm.mesh = dk.commit()
	dm.position = _ground(hall + Vector2(-11.55, -4.5))
	f.add_child(dm)
	_spot(f, door, 1.4, func(_a: Actor) -> String: return "Tür „Privat“", _back_room)
	_refresh()


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, world.map.walk_height(p.x, p.y), p.y)


func _thing(parent: Node3D, mesh: Mesh, p: Vector2, n: String) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.position = _ground(p)
	mi.visible = false
	parent.add_child(mi)
	return mi


## A spot that follows `follow` (when given) so things can move between places.
func _spot(parent: Node3D, p: Vector2, r: float, prompt: Callable, action: Callable, follow: Node3D = null) -> FunctionSpot:
	var s := FunctionSpot.new()
	s.position = _ground(p)
	s.radius = r
	s.users = "human"
	s.prompt_fn = prompt
	s.available_fn = func(a: Actor) -> bool: return prompt.call(a) != ""
	s.action_fn = action
	parent.add_child(s)
	if follow:
		s.set_meta("follow", follow)
	return s


## Puts the things where the stories are right now.
func _refresh() -> void:
	if world.fair == null:
		return
	var teddy_on: bool = str(GameState.flags.get("fs_teddy", "")) == "active" and not _player_has("teddy")
	_teddy.visible = teddy_on
	_teddy.position = _ground(TEDDY_SPOTS[GameState.stat("teddy_spot") % TEDDY_SPOTS.size()])
	_duck.visible = GameState.stat("golden_duck_day") != Clock.day + 1
	_duck.position = _ground(DUCK_SPOTS[(Clock.day * 5 + 3) % DUCK_SPOTS.size()])
	if (_duck.position as Vector3).distance_to(Vector3(FairLayout.POND_CENTER.x, 0, FairLayout.POND_CENTER.y)) < 6.0:
		_duck.position.y = ParkLayout.WATER_Y
	_hoppel.visible = step() == 4
	_carrots.visible = step() == 4
	for s in world.fair.get_children():
		if s is FunctionSpot and s.has_meta("follow"):
			var n: Node3D = s.get_meta("follow")
			s.position = n.position


func _player_has(id: String) -> bool:
	var a: Actor = game.player.actor if game.player else null
	return a != null and a.has_item(id)


func _process(delta: float) -> void:
	if world.fair == null or not world.area_awake("fair"):
		return
	_t += delta
	if ghost:
		ghost.visible = ghost_out()
		ghost.position.y = world.map.walk_height(GHOST_AT.x, GHOST_AT.y) + 0.35 + sin(_t * 1.6) * 0.15
		ghost.rotation.y = 0.4 + sin(_t * 0.7) * 0.3
	if Engine.get_process_frames() % 30 == 0:
		_refresh()
	_check_rose_bench()
	if _flock:
		_flock_t += delta
		var c := FairLayout.place("oasis_roses")
		for i in _flock.get_child_count():
			var b: Node3D = _flock.get_child(i)
			var a := _flock_t * 1.2 + TAU * i / _flock.get_child_count()
			var r := 6.0 + sin(i * 2.3) * 2.0
			b.position = Vector3(c.x + cos(a) * r, world.map.height_at(c.x, c.y) + 6.0 + sin(_flock_t * 2.0 + i) * 1.2, c.y + sin(a) * r)
			b.rotation.y = -a
		if _flock_t > 14.0:
			_flock.queue_free()
			_flock = null


## Gisbert comes out between ten at night and three in the morning.
static func ghost_out() -> bool:
	var h := Clock.hour()
	return h >= 22.0 or h < 3.0


# --- Conversations -------------------------------------------------------------------------

func options(player: Actor, npc: Actor) -> Array:
	var out := []
	if not player.is_human():
		return out
	match npc.actor_id:
		"esmeralda":
			out.append({"text": "Die Zukunft lesen lassen (1,00 €)", "action": func() -> void: _fortune(player, npc)})
			if step() == 1:
				out.append({"text": "Nach Hoppel fragen", "action": func() -> void: _ask_esmeralda(npc)})
		"zambini":
			out.append({"text": "Einen Zaubertrick sehen", "action": func() -> void: _choose_trick(npc)})
			if step() == 0 and GameState.stat("tricks") > 0:
				out.append({"text": "Wo ist eigentlich Ihr Assistent?", "action": func() -> void: _tell_story(npc)})
			if step() == 5 and player.has_item("hoppel"):
				out.append({"text": "Hoppel zurückgeben", "action": func() -> void: _return_hoppel(player, npc)})
		"geistgustav":
			if step() == 3:
				out.append({"text": "Haben Sie ein weißes Kaninchen gesehen?", "action": func() -> void: _ask_gustav(npc)})
		"lothar":
			GameState.add_stat("lothar_talks")
			if GameState.stat("lothar_talks") == 3:
				out.append({"text": "Psst, Lothar …?", "action": func() -> void:
					UI.dialog(npc.display_name, "„Unter uns: Die echten Hauptgewinne stecken nicht in meinen Losen. Schau dir mal die Gondeln vom Riesenrad genau an. Eine davon glänzt anders.“", [{"text": "Danke für den Tipp!", "id": ""}])})
		"max":
			if delivery_active() and player.has_item("takeaway_hotdog") and player.has_item("takeaway_fries"):
				out.append({"text": "Hier, dein Essen aus dem Park!", "action": func() -> void: _deliver(player, npc)})
			elif not delivery_active() and GameState.stat("delivery_day") != Clock.day + 1 and Clock.hour() >= 11.0 and Clock.hour() < 20.0:
				out.append({"text": "Hast du Hunger, Max?", "action": func() -> void: _order(npc)})
		"fairkid_1":
			var state := str(GameState.flags.get("fs_teddy", ""))
			if state == "":
				out.append({"text": "Warum bist du so traurig?", "action": func() -> void: _teddy_ask(npc)})
			elif state == "active" and player.has_item("teddy"):
				out.append({"text": "Den Teddy zurückgeben", "action": func() -> void: _teddy_return(player, npc)})
	return out


## An open quest step with this person (for the quest rings).
func has_quest(player: Actor, npc: Actor) -> bool:
	match npc.actor_id:
		"esmeralda": return step() == 1
		"zambini": return (step() == 0 and GameState.stat("tricks") > 0) or (step() == 5 and player.has_item("hoppel"))
		"geistgustav": return step() == 3
		"max": return delivery_active() and player.has_item("takeaway_hotdog") and player.has_item("takeaway_fries")
		"fairkid_1":
			var st := str(GameState.flags.get("fs_teddy", ""))
			return st == "" or (st == "active" and player.has_item("teddy"))
	return false


func tasks() -> Array:
	var out := []
	if world.fair == null and step() == 0 and str(GameState.flags.get("fs_teddy", "")) == "" and str(GameState.flags.get("fs_ghost", "")) == "":
		return out
	match step():
		1: out.append({"title": "Der verschwundene Assistent", "desc": "Zambinis Kaninchen Hoppel ist verschwunden. Vielleicht weiß Madame Esmeralda mehr.", "active": true})
		2: out.append({"title": "Der verschwundene Assistent", "desc": "„Zwischen Gelächter und Gespenstern …“ – eine Fahrt mit der Geisterbahn?", "active": true})
		3: out.append({"title": "Der verschwundene Assistent", "desc": "Hoppel hoppelte in der Geisterbahn nach hinten hinaus. Frag Geister-Gustav.", "active": true})
		4: out.append({"title": "Der verschwundene Assistent", "desc": "Folge der Möhrenspur hinter der Geisterbahn.", "active": true})
		5: out.append({"title": "Der verschwundene Assistent", "desc": "Bring Hoppel zurück zum großen Zambini.", "active": true})
		6: out.append({"title": "Der verschwundene Assistent", "desc": "Hoppel ist zurück. Aber wie ist er überhaupt verschwunden?", "done": true})
	match str(GameState.flags.get("fs_teddy", "")):
		"active": out.append({"title": "Lias Teddy", "desc": "Lia hat ihren Teddy auf der Kirmes verloren. Madame Esmeralda kann vielleicht helfen.", "active": true})
		"done": out.append({"title": "Lias Teddy", "desc": "Lia hat ihren Teddy wieder.", "done": true})
	match str(GameState.flags.get("fs_ghost", "")):
		"active": out.append({"title": "Gisberts Taschenuhr", "desc": "Der Kirmesgeist hat seine Taschenuhr verloren – ganz oben auf dem Riesenrad.", "active": true})
		"done": out.append({"title": "Gisberts Taschenuhr", "desc": "Gisbert weiß wieder, wann Geisterstunde ist.", "done": true})
	if delivery_active():
		out.append({"title": "Hunger-Lieferung", "desc": "Muskel-Max will einen Hot Dog von Heinz und Pommes von Paula aus dem Stadtpark – noch warm! (Zum Mitnehmen an den Ständen.)", "active": true})
	if GameState.stat("tricks") > 0:
		out.append({"title": "Zambinis Zaubertricks", "desc": "%d von 4 Tricks erlebt." % GameState.stat("tricks"), "done": GameState.stat("tricks") >= 4})
	return out


# --- Madame Esmeralda ---------------------------------------------------------------------

## The secrets she knows: [done?, hint]. The first one not done is told.
func hints() -> Array:
	var teddy: String = TEDDY_HINTS[GameState.stat("teddy_spot") % TEDDY_HINTS.size()]
	return [
		[str(GameState.flags.get("fs_teddy", "")) != "active", "Ein kleines Mädchen weint … ich sehe ihren Teddy – %s." % teddy],
		[str(GameState.flags.get("fs_ghost", "")) != "active" or _player_has("pocket_watch"), "Der Geist sucht, was er oben verlor. Ganz oben, wo man die ganze Gegend sieht."],
		[GameState.stat("gnomes") >= 7, "Ich sehe rote Mützen im Grünen. Sieben kleine Herren, die sich gern verstecken – bei Steinen, am Wasser und unter Brücken."],
		[GameState.is_unlocked("troll"), "Unter der Steinbrücke wohnt einer, der Rätsel liebt. Aber er kommt nur in der Nacht heraus."],
		[GameState.is_unlocked("stash"), "Ein kleiner Dieb mit buschigem Schwanz hortet Süßes in einer alten Eiche beim Picknick."],
		[GameState.is_unlocked("nessie"), "Wenn Nebel über dem Ententeich liegt, schaut manchmal ein langer Hals aus dem Wasser …"],
		[GameState.is_unlocked("ufo"), "Nachts über der Großen Wiese … ein Licht, das nicht von dieser Welt ist."],
		[GameState.is_unlocked("quack"), "Die Bronze-Ente am Teich mag es, wenn man sie mehrmals hintereinander streichelt."],
		[GameState.is_unlocked("wishing_well"), "Wasser, das Wünsche hört … eine Münze am Brunnenplatz."],
		[str(GameState.flags.get("fs_ghost", "")) != "", "Nach zehn Uhr abends spukt es an der Geisterbahn. Ganz harmlos. Meistens."],
		[GameState.is_unlocked("mime_saver"), "Ein Mann ohne Worte steckt manchmal fest. Ein Kind weiß, wie man ihn befreit."],
		[GameState.is_unlocked("highscore_king"), "Wer an allen Automaten der Beste ist, dem öffnet sich eine Tür."],
		[false, "Die Kugel zeigt … Zuckerwatte. Viel Zuckerwatte. Das ist alles."],
	]


func _fortune(_player: Actor, npc: Actor) -> void:
	if GameState.stat("hint_day") == Clock.day + 1:
		UI.dialog_then(npc.display_name, "„Die Kugel ist müde, mein Kind. Komm morgen wieder.“", [{"text": "Bis morgen!", "id": ""}])
		return
	if not GameState.spend(100):
		return
	GameState.set_stat("hint_day", Clock.day + 1)
	var hint := ""
	for h: Array in hints():
		if not h[0]:
			hint = h[1]
			break
	npc.play_anim("talk", 3.0)
	Sound.play("whistle", npc.global_position, -10.0)
	UI.dialog_then(npc.display_name, "(Madame Esmeralda beugt sich über die Kugel. Ein Nebel zieht darin auf.)\n\n„%s“" % hint, [{"text": "Hmm …", "id": ""}])


func _ask_esmeralda(npc: Actor) -> void:
	set_step(2)
	UI.dialog_then(npc.display_name, "„Ein Kaninchen? Lass mich sehen …\n\nIch sehe ein weißes Ohr … zwischen Gelächter und Gespenstern … dort, wo es dunkel ist und trotzdem jemand lacht.“",
		[{"text": "Die Geisterbahn!", "id": ""}])


# --- The great Zambini ----------------------------------------------------------------------

func _choose_trick(npc: Actor) -> void:
	var opts := []
	for id: String in TRICKS:
		opts.append({"text": TRICK_NAMES[id], "id": id})
	opts.append({"text": "Ein andermal.", "id": ""})
	UI.dialog_then(npc.display_name, "„Willkommen, willkommen! Welchen Trick darf der große Zambini vorführen?“", opts, func(c: String) -> void:
		_start_trick(npc, c))


const STEPS_1089 := ["Denk dir eine dreistellige Zahl, deren erste und letzte Ziffer sich um mindestens zwei unterscheiden. Zum Beispiel 731.",
	"Dreh die Zahl um und zieh die kleinere von der größeren ab. (731 − 137 = 594)",
	"Dreh das Ergebnis um und zähl beide zusammen. (594 + 495)"]
const STEPS_FOUR := ["Denk dir eine beliebige Zahl.", "Verdopple sie.", "Zähl 8 dazu.", "Halbiere das Ergebnis.", "Zieh deine Ausgangszahl ab."]


func _start_trick(npc: Actor, id: String) -> void:
	match id:
		"cards":
			_cards(npc)
		"1089":
			_steps(npc, "1089", STEPS_1089, "Deine Zahl ist … 1089!")
		"four":
			_steps(npc, "four", STEPS_FOUR, "Es kommt … die 4 heraus!")
		"guess":
			_guess(npc)


## Instructions one after the other, then the reveal.
func _steps(npc: Actor, id: String, lines: Array, reveal: String, i := 0) -> void:
	if i >= lines.size():
		_reveal(npc, id, reveal)
		return
	UI.dialog_then(npc.display_name, "„%s“" % lines[i], [{"text": "Weiter" if i < lines.size() - 1 else "Fertig", "id": "go"}], func(c: String) -> void:
		if c == "go":
			_steps(npc, id, lines, reveal, i + 1))


## The binary cards: five cards with the numbers 1–31; yes or no for each.
func _cards(npc: Actor) -> void:
	UI.dialog_then(npc.display_name, "„Denk dir eine Zahl von 1 bis 31. Ich zeige dir fünf Karten – sag mir nur, ob deine Zahl darauf steht.“",
		[{"text": "Ich hab eine!", "id": "go"}], func(c: String) -> void:
			if c == "go":
				_card(npc, 0, 0))


func _card(npc: Actor, card: int, total: int) -> void:
	if card >= 5:
		if total == 0:
			UI.dialog_then(npc.display_name, "„Auf keiner Karte? Dann hast du dich verzählt, mein Freund!“", [{"text": "Hoppla.", "id": ""}])
			return
		_reveal(npc, "cards", "Deine Zahl ist … die %d!" % total)
		return
	var nums: Array[String] = []
	for n in range(1, 32):
		if n & (1 << card):
			nums.append(str(n))
	UI.dialog_then(npc.display_name, "Karte %d:\n%s\n\n„Steht deine Zahl darauf?“" % [card + 1, "  ".join(nums)],
		[{"text": "Ja", "id": "y"}, {"text": "Nein", "id": "n"}], func(c: String) -> void:
			if c != "":
				_card(npc, card + 1, total + ((1 << card) if c == "y" else 0)))


## Double it, add ten, halve it: from the result back to the number.
func _guess(npc: Actor) -> void:
	UI.dialog_then(npc.display_name, "„Denk dir eine Zahl von 1 bis 10. Verdopple sie, zähl 10 dazu und halbiere das Ergebnis. Was kommt heraus?“",
		[{"text": "6 bis 10", "id": "lo"}, {"text": "11 bis 15", "id": "hi"}], func(c: String) -> void:
			if c == "":
				return
			var opts := []
			for n in (range(6, 11) if c == "lo" else range(11, 16)):
				opts.append({"text": str(n), "id": str(n)})
			UI.dialog_then(npc.display_name, "„Welche Zahl genau?“", opts, func(n: String) -> void:
				if n != "":
					_reveal(npc, "guess", "Deine Zahl war … die %d!" % (int(n) - 5))))


func _reveal(npc: Actor, id: String, text: String) -> void:
	npc.play_anim("cheer", 2.0)
	Sound.play("achievement", npc.global_position, -6.0)
	UI.dialog_then(npc.display_name, "„%s“" % text, [{"text": "Stimmt! Wie hast du das gemacht?", "id": "ok"}, {"text": "Stimmt nicht.", "id": "no"}],
		func(c: String) -> void:
			if c == "ok":
				var first := GameState.add_to_set("tricks", id)
				game.player.actor.needs.cheer(10.0)
				if first:
					GameState.add_tickets(4, "Zaubertrick")
				UI.dialog_then(npc.display_name, "„Ein Zauberer verrät seine Tricks nie! … Na gut: Es ist alles nur Rechnen. Aber psst!“", [{"text": "Toll!", "id": ""}])
			elif c == "no":
				UI.dialog_then(npc.display_name, "„Dann hast du dich verrechnet, mein Freund! Die Zahlen lügen nie. Noch einmal?“", [{"text": "Na gut.", "id": ""}]))


func _tell_story(npc: Actor) -> void:
	set_step(1)
	UI.dialog_then(npc.display_name, "„Ach, mein armer Hoppel! Mein Kaninchen. Bei der letzten Vorstellung habe ich ihn weggezaubert – und er ist nie wieder aufgetaucht! Dabei war das nur ein Trick … glaube ich.\n\nVielleicht weiß Madame Esmeralda etwas. Ihre Kugel sieht mehr als wir alle.“",
		[{"text": "Ich helfe suchen!", "id": ""}])


func _ask_gustav(npc: Actor) -> void:
	set_step(4)
	_refresh()
	UI.dialog_then(npc.display_name, "„Ein Kaninchen? In MEINER Geisterbahn? … Jetzt, wo du's sagst: Hinter der Bahn liegen seit Tagen Möhrenstückchen. Die Spur führt nach Osten, zur Rosenlaube.“",
		[{"text": "Danke!", "id": ""}])


func _catch_hoppel(a: Actor) -> void:
	if step() != 4:
		return
	set_step(5)
	a.add_item("hoppel")
	_hoppel.visible = false
	_carrots.visible = false
	Sound.play("pickup")
	GameState.toast.emit("Hoppel sitzt jetzt im Rucksack und mümmelt an einer Möhre.", "info")


func _return_hoppel(a: Actor, npc: Actor) -> void:
	a.take_item("hoppel")
	set_step(6)
	GameState.set_stat("assistant_found", 1)
	GameState.add_tickets(30, "Hoppel gefunden")
	GameState.add_money(1000, "Zambinis Belohnung")
	npc.play_anim("cheer", 3.0)
	Gameplay.eggs.confetti(npc.global_position + Vector3(0, 1.5, 0))
	UI.dialog_then(npc.display_name, "„HOPPEL! Mein Hoppel! Danke, danke!\n\n… Unter uns: Ich habe ihn damals gar nicht weggezaubert. Der Trick ging schief – ich habe nur ein Tuch geschwenkt. Und plötzlich war er weg. Wirklich weg. Wie, weiß ich bis heute nicht …“",
		[{"text": "Unheimlich!", "id": ""}])


# --- Gisbert, the fair ghost ---------------------------------------------------------------

func _talk_ghost(a: Actor) -> void:
	var state := str(GameState.flags.get("fs_ghost", ""))
	if state == "":
		GameState.flags["fs_ghost"] = "active"
		Sound.play("owl", ghost.global_position, -4.0)
		UI.dialog("Kirmesgeist Gisbert", "„Huuuh! … Oh, Verzeihung, das ist Gewohnheit. Ich bin Gisbert, der Kirmesgeist.\n\nVor hundert Jahren habe ich meine Taschenuhr verloren – ganz oben auf dem Riesenrad. Seitdem weiß ich nie, wann Geisterstunde ist. Würdest du nach ihr suchen?“",
			[{"text": "Ich schau mal oben nach.", "id": ""}])
	elif state == "active" and a.has_item("pocket_watch"):
		a.take_item("pocket_watch")
		GameState.flags["fs_ghost"] = "done"
		GameState.set_stat("ghost_helped", 1)
		GameState.add_tickets(20, "Gisberts Dank")
		UI.dialog("Kirmesgeist Gisbert", "„Meine Uhr! Sie tickt sogar noch! Endlich weiß ich wieder, wann Geisterstunde ist.\n\nZum Dank ein Geheimnis: Eine goldene Ente versteckt sich jeden Tag an einem anderen Ort im Westpark. Halt die Augen offen!“",
			[{"text": "Danke, Gisbert!", "id": ""}])
	elif state == "active":
		UI.dialog("Kirmesgeist Gisbert", "„Ganz oben auf dem Riesenrad muss sie sein … Huuuh, hoffentlich.“", [{"text": "Ich suche weiter.", "id": ""}])
	else:
		UI.dialog("Kirmesgeist Gisbert", ["„Es ist %s. Fast Geisterstunde!“" % Clock.time_string(), "„Huuuh! … Hach, das tut gut.“", "„Grüß die Wahrsagerin von mir.“"][randi() % 3],
			[{"text": "Gute Nacht, Gisbert.", "id": ""}])


## The Ferris wheel at the top (FerrisRide): the watch for the ghost, the golden gondola.
func at_wheel_top(ride: FerrisRide) -> String:
	var lines: Array[String] = []
	var a := ride.actor
	if str(GameState.flags.get("fs_ghost", "")) == "active" and not a.has_item("pocket_watch"):
		a.add_item("pocket_watch")
		lines.append("In der Gondel blitzt etwas: eine alte Taschenuhr! Die muss Gisbert gehören.")
	if ride.gondola == 0:
		GameState.set_stat("golden_gondola", 1)
		lines.append("Aus der goldenen Gondel siehst du ganz hinten am Berg der Zwerge jemanden winken.")
	return " ".join(lines)


## The ghost train: Hoppel in the dark (GhostRide).
func in_ghost_train() -> String:
	if step() == 2:
		set_step(3)
		return "Da! Ein weißes Kaninchen! Es hoppelt durch eine Tür nach hinten hinaus."
	return ""


# --- Lia's teddy -----------------------------------------------------------------------------

func _teddy_ask(npc: Actor) -> void:
	GameState.flags["fs_teddy"] = "active"
	GameState.set_stat("teddy_spot", absi(hash(Clock.day)) % TEDDY_SPOTS.size())
	_refresh()
	UI.dialog_then(npc.display_name, "„Ich hab meinen Teddy verloren! Er heißt Brummi. Ich war überall auf der Kirmes … Madame Esmeralda weiß bestimmt, wo er ist!“",
		[{"text": "Ich suche ihn!", "id": ""}])


func _pick_teddy(a: Actor) -> void:
	if not _teddy.visible:
		return
	a.add_item("teddy")
	_teddy.visible = false
	Sound.play("pickup")
	GameState.toast.emit("Teddy Brummi ist im Rucksack.", "info")


func _teddy_return(a: Actor, npc: Actor) -> void:
	a.take_item("teddy")
	GameState.flags["fs_teddy"] = "done"
	GameState.set_stat("teddy_found", 1)
	GameState.add_tickets(10, "Brummi gefunden")
	npc.emote("heart", 2)
	npc.play_anim("cheer", 2.0)
	UI.dialog_then(npc.display_name, "„BRUMMI! Danke, danke, danke! Du bist der Beste!“", [{"text": "Gern geschehen!", "id": ""}])


# --- Hunger delivery ---------------------------------------------------------------------------

static func delivery_active() -> bool:
	return str(GameState.flags.get("fs_delivery", "")) == "active"


static func takeaway_for(shop_id: String) -> String:
	return TAKEAWAY.get(shop_id, "")


static func game_minutes() -> float:
	return Clock.day * 1440.0 + Clock.hour() * 60.0


func _order(npc: Actor) -> void:
	GameState.flags["fs_delivery"] = "active"
	GameState.set_stat("delivery_start", int(game_minutes()))
	UI.dialog_then(npc.display_name, "„Hunger? Ich könnte einen Bären verspeisen! Bring mir einen Hot Dog von Hot-Dog-Heinz und Pommes von Pommes-Paula aus dem Stadtpark. Aber schnell, solange alles warm ist!“",
		[{"text": "Bin gleich zurück!", "id": ""}])


func _deliver(a: Actor, npc: Actor) -> void:
	a.take_item("takeaway_hotdog")
	a.take_item("takeaway_fries")
	GameState.flags["fs_delivery"] = ""
	GameState.set_stat("delivery_day", Clock.day + 1)
	var warm := game_minutes() - GameState.stat("delivery_start") <= WARM_MINUTES
	npc.play_anim("eat", 3.0)
	if warm:
		GameState.add_money(600, "Lieferung für Max")
		GameState.add_tickets(15, "Lieferung für Max")
		GameState.add_stat("fair_deliveries")
		UI.dialog_then(npc.display_name, "„Noch warm! Du bist ein Held. Mit dieser Kraft läute ich heute zehnmal die Glocke!“", [{"text": "Guten Appetit!", "id": ""}])
	else:
		GameState.add_money(200, "Lieferung für Max")
		GameState.add_tickets(5, "Lieferung für Max")
		UI.dialog_then(npc.display_name, "„Kalt … Na gut, ich ess es trotzdem. Danke dir.“", [{"text": "Beim nächsten Mal schneller!", "id": ""}])


# --- Easter eggs -----------------------------------------------------------------------------

func _pick_duck(a: Actor) -> void:
	if not _duck.visible or not a.can_add("golden_duck"):
		return
	a.add_item("golden_duck")
	GameState.set_stat("golden_duck_day", Clock.day + 1)
	GameState.add_stat("golden_ducks")
	_duck.visible = false
	Sound.play("achievement")
	GameState.toast.emit("Eine goldene Ente! Sie glänzt im Rucksack.", "info")


## Sitting on the bench under the rose arbour ten times calls the birds.
func _check_rose_bench() -> void:
	var a: Actor = game.player.actor if game.player else null
	var on := a != null and a.seat != null and a.seat.oasis == "oasis_roses" and a.seat.owner_id == _rose_bench_id()
	if on and not _rose_seat_was:
		GameState.add_stat("rose_sits")
		if GameState.stat("rose_sits") % ROSE_SITS == 0:
			_birds()
	_rose_seat_was = on


func _rose_bench_id() -> String:
	for b: Bench in world.fair_benches:
		if b.oasis == "oasis_roses":
			return b.bench_id
	return ""


func _birds() -> void:
	if _flock:
		return
	_flock = Node3D.new()
	_flock.name = "Flock"
	world.fair.add_child(_flock)
	_flock_t = 0.0
	for i in 24:
		var b := MeshInstance3D.new()
		b.mesh = FairModels.flock_bird()
		_flock.add_child(b)
	GameState.set_stat("bird_flock", 1)
	Sound.play("flap", null, 0.0)
	GameState.toast.emit("Ein Vogelschwarm kreist über der Rosenlaube!", "info")


func _back_room(_a: Actor) -> void:
	if not GameState.is_unlocked("highscore_king"):
		UI.dialog("Tür „Privat“", "Abgeschlossen. Auf einem Schild steht: „Nur für Highscore-Könige. Gez. Sascha“", [{"text": "Schade.", "id": ""}])
		return
	GameState.set_stat("back_room", 1)
	UI.dialog("Hinterzimmer", "Die Tür quietscht auf. Ein staubiger Raum, Kisten voller Ersatzteile, an der Wand die Highscore-Listen von vierzig Jahren. In der Mitte ein Automat unter einer Decke.\n\nAuf dem Zettel daran: „RETRO RACER – bald wieder in Betrieb. Gez. Sascha“",
		[{"text": "Bald? Ich komme wieder!", "id": ""}])

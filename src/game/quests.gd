class_name Quests
extends Node
## Jobs and story quests: dog walking for Mia, the mime stuck in his invisible
## box, the bridge troll's riddles.

var game: Node
var world: World

# Dog walking job.
var walk_dog: Actor
var walk_state := ""          # "", "to_meadow", "playing", "back"
var walk_time := 0.0
var _walk_play := 0.0

const RIDDLES := [
	{"q": "Was hat einen Hals, aber keinen Kopf?", "a": ["Eine Flasche", "Eine Giraffe", "Eine Brücke"], "ok": 0},
	{"q": "Je mehr man davon wegnimmt, desto größer wird es. Was ist das?", "a": ["Ein Berg", "Ein Loch", "Ein Donut"], "ok": 1},
	{"q": "Es hat Zähne, aber es beißt nicht. Was ist das?", "a": ["Ein Kamm", "Eine Gans", "Ein Troll"], "ok": 0},
	{"q": "Welche Ente kann nicht schwimmen?", "a": ["Die Stockente", "Die Zeitungsente", "Die Gummiente"], "ok": 1},
	{"q": "Was wird nass, während es trocknet?", "a": ["Ein Handtuch", "Der Teich", "Ein Eis"], "ok": 0},
]


func setup(g: Node) -> void:
	game = g
	world = g.world
	name = "Quests"
	world.add_child(self)
	Conversations.register(_options)
	TaskBoard.register(_tasks)


func _options(player: Actor, npc: Actor) -> Array:
	var out := []
	match npc.actor_id:
		"mia":
			if player.is_human() and walk_state == "" and npc.def.has("dogs"):
				out.append({"text": "Gassi-Auftrag annehmen (4,00 €)", "action": func() -> void: _start_walk(player, npc)})
			elif walk_state == "back" and walk_dog and walk_dog.leash_owner == player:
				out.append({"text": "%s zurückbringen" % walk_dog.display_name, "action": func() -> void: _finish_walk(player, npc)})
		"pierre":
			if GameState.flag("mime_stuck") and not GameState.flag("mime_freed"):
				if player.has_item("invisible_key"):
					out.append({"text": "Den unsichtbaren Schlüssel geben", "action": func() -> void: _free_mime(player, npc)})
				else:
					out.append({"text": "Was ist los, Pierre?", "action": func() -> void:
						UI.dialog("Pantomime Pierre", "(Pierre tastet verzweifelt die Wände einer unsichtbaren Kiste ab. Dann zeigt er auf ein unsichtbares Schlüsselloch und zuckt mit den Schultern.)\n\nEr braucht wohl einen unsichtbaren Schlüssel …",
							[{"text": "Ich halte die Augen offen.", "id": ""}])})
		"lena":
			if GameState.flag("mime_stuck") and not GameState.flag("mime_freed") and not player.has_item("invisible_key") and player != npc:
				out.append({"text": "Hast du etwas gefunden?", "action": func() -> void:
					UI.dialog("Lena", "„Guck mal, ich hab im Sandkasten was Unsichtbares gefunden! Ich glaub, das ist ein Schlüssel. Willst du ihn haben?“",
						[{"text": "Ja, gerne!", "id": "y"}, {"text": "Nein, behalt ihn.", "id": ""}], func(c: String) -> void:
							if c == "y":
								player.add_item("invisible_key")
								GameState.toast.emit("Du hast einen unsichtbaren Schlüssel. Glaubst du jedenfalls.", "info"))})
		"bruno":
			if not GameState.is_unlocked("troll"):
				out.append({"text": "Ein Rätsel lösen", "action": func() -> void: _riddle(player, npc)})
	return out


func _tasks() -> Array:
	var out := []
	var mia := world.find_actor("mia")
	if walk_state != "":
		out.append({"title": "Gassi mit %s" % walk_dog.display_name, "desc": {"to_meadow": "Bring %s zur Hundewiese." % walk_dog.display_name,
			"playing": "%s tobt sich auf der Hundewiese aus …" % walk_dog.display_name, "back": "Bring %s zurück zu Mia." % walk_dog.display_name}[walk_state]})
	else:
		out.append({"title": "Gassi gehen für Hundesitterin Mia", "desc": "Führe einen ihrer Hunde zur Hundewiese und zurück. Lohn: 4,00 €. (%s)" % (
			"Mia ist gerade im Park" if mia and not mia.inside else "Mia kommt tagsüber in den Park"), "done": false})
	if GameState.flag("mime_freed"):
		out.append({"title": "Unsichtbare Hilfe", "desc": "Pierre ist frei. Er bedankt sich stumm, aber herzlich.", "done": true})
	elif GameState.flag("mime_stuck"):
		out.append({"title": "Der Pantomime steckt fest!", "desc": "Pierre sitzt in einer unsichtbaren Kiste am Brunnen. Vielleicht hat ein Kind etwas gefunden?"})
	var gnomes := GameState.stat("gnomes")
	if gnomes > 0:
		out.append({"title": "Gartenzwerge", "desc": "%d von 7 versteckten Gartenzwergen gefunden." % gnomes, "done": gnomes >= 7})
	return out


# --- Dog walking -------------------------------------------------------------------

func _start_walk(player: Actor, mia: Actor) -> void:
	var dogs: Array = mia.def.get("dogs", [])
	var options: Array[Actor] = []
	for id: String in dogs:
		var d := world.find_actor(id)
		if d and not d.controlled and not d.inside:
			options.append(d)
	if options.is_empty():
		UI.dialog("Hundesitterin Mia", "„Die Hunde sind gerade alle unterwegs. Komm später wieder!“", [{"text": "Okay", "id": ""}])
		return
	walk_dog = options[randi() % options.size()]
	if walk_dog.leash_owner:
		walk_dog.leash_owner.detach_leash(walk_dog)
	player.attach_leash(walk_dog)
	walk_state = "to_meadow"
	walk_time = 0.0
	mia.say("Pass gut auf %s auf!" % walk_dog.display_name, 3.0)
	GameState.toast.emit("%s läuft jetzt mit dir. Ab zur Hundewiese!" % walk_dog.display_name, "info")


func _process(delta: float) -> void:
	if walk_state == "" or walk_dog == null:
		return
	walk_time += delta
	var owner := walk_dog.leash_owner
	match walk_state:
		"to_meadow":
			if world.dog_meadow.has_point(walk_dog.ground_pos()):
				walk_state = "playing"
				_walk_play = 12.0
				if owner:
					owner.detach_leash(walk_dog)
				GameState.toast.emit("%s tobt über die Hundewiese!" % walk_dog.display_name, "info")
		"playing":
			_walk_play -= delta
			if _walk_play <= 0.0:
				var p := game.player.actor as Actor
				if p and p.is_human():
					p.attach_leash(walk_dog)
					walk_state = "back"
					GameState.toast.emit("Genug getobt. Bring %s zurück zu Mia." % walk_dog.display_name, "info")
	if walk_dog.leash_owner == null and walk_state != "playing":
		# Player switched characters: job is cancelled.
		_cancel_walk()


func _cancel_walk() -> void:
	var mia := world.find_actor("mia")
	if mia and walk_dog and not mia.inside:
		mia.attach_leash(walk_dog)
	walk_state = ""
	walk_dog = null


func _finish_walk(player: Actor, mia: Actor) -> void:
	player.detach_leash(walk_dog)
	mia.attach_leash(walk_dog)
	mia.say("Danke! %s sieht glücklich aus." % walk_dog.display_name, 3.0)
	walk_dog.emote("heart", 2)
	GameState.add_stat("dog_walks")
	GameState.add_money(400, "Gassi-Auftrag")
	player.needs.cheer(15.0)
	walk_state = ""
	walk_dog = null


# --- Mime --------------------------------------------------------------------------

## Called every game hour: sometimes Pierre gets stuck in his invisible box.
func hourly() -> void:
	var pierre := world.find_actor("pierre")
	if pierre and not pierre.inside and not GameState.flag("mime_stuck") and not GameState.flag("mime_freed") and randf() < 0.5:
		GameState.set_flag("mime_stuck")
	_update_mime()


func _update_mime() -> void:
	var pierre := world.find_actor("pierre")
	if pierre == null:
		return
	var stuck := GameState.flag("mime_stuck") and not GameState.flag("mime_freed")
	var work: Dictionary = pierre.def["work"]
	work["anim"] = "stuck" if stuck else "mime"
	var b := pierre.brain as HumanBrain
	if b and b.current is Activities.Perform:
		(b.current as Activities.Perform).perf_anim = work["anim"]


func _free_mime(player: Actor, pierre: Actor) -> void:
	player.take_item("invisible_key")
	GameState.set_flag("mime_freed")
	GameState.add_stat("mime_freed")
	_update_mime()
	pierre.play_anim("cheer", 3.0)
	pierre.emote("heart", 3)
	UI.dialog("Pantomime Pierre", "Du überreichst Pierre den unsichtbaren Schlüssel. Er schließt feierlich eine unsichtbare Tür auf, tritt heraus – und umarmt dich stumm.\n\nDann verbeugt er sich so tief, dass sein Barett herunterfällt.",
		[{"text": "Gern geschehen!", "id": ""}])


# --- Troll ------------------------------------------------------------------------------

func _riddle(player: Actor, troll: Actor) -> void:
	if GameState.flag("troll_today_%d" % Clock.day):
		UI.dialog(troll.display_name, "„Hrmpf! Für heute hast du genug geraten. Komm morgen Nacht wieder.“", [{"text": "Na gut.", "id": ""}])
		return
	var r: Dictionary = RIDDLES[randi() % RIDDLES.size()]
	var opts := []
	for i in r["a"].size():
		opts.append({"text": r["a"][i], "id": str(i)})
	UI.dialog(troll.display_name, "„Wer unter meiner Brücke stehen will, muss mein Rätsel lösen!\n\n%s“" % r["q"], opts, func(c: String) -> void:
		if c == "":
			return
		if int(c) == r["ok"]:
			GameState.add_stat("troll")
			troll.play_anim("cheer", 2.0)
			UI.dialog(troll.display_name, "„RICHTIG! Grmpf. Niemand löst meine Rätsel. Hier, nimm das Trollgold. Und erzähl keinem, wo ich wohne!“",
				[{"text": "Danke, Bruno!", "id": ""}])
			player.needs.cheer(20.0)
		else:
			GameState.set_flag("troll_today_%d" % Clock.day)
			troll.say("FALSCH! Hrmpf!", 2.5)
			UI.dialog(troll.display_name, "„Falsch, falsch, falsch! Komm morgen Nacht wieder.“", [{"text": "Mist.", "id": ""}]))

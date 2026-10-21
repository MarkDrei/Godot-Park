class_name BurgStories
extends QuestModule
## Stories and quests of the Ritterburg (doc/burg.md, phase 4):
## - Der Sternenstab: Meister Morwen's staff lost its light; a splinter of its star is in Zambini's
##   top hat, his old apprentice at the Kirmes (that is how Hoppel really vanished). Esmeralda, Morwen's
##   sister, knows. Brunhild sets the splinter back, Morwen writes a letter of reconciliation.
##   Stat "staff_step": 0 untold, 1 ask Zambini, 2 ask Esmeralda, 3 look into the hat, 4 to the
##   smithy, 5 back to Morwen, 6 the letter to Zambini, 7 done.
## - Zwei Gespenster: Fräulein Hedwig haunts the castle's top at night and is lonely; letters go to
##   and fro with Gisbert, the Kirmes ghost; in a ghost lantern from the smithy she rides to the
##   top of the Ferris wheel at night. Stat "ghosts_step": 0, 1 her letter to Gisbert, 2 his answer
##   back, 3 a lantern from the smithy, 4 to the Ferris wheel at night, 5 done.
## - Single quests (stages "bq_<id>"), Lumpen-Ludwig's riddles (one a day, stat "riddles"), the
##   exhibition's boards (set "burg_boards").

const HEDWIG_AT := Vector2(-279, -233.6)
const HEDWIG := "Burggespenst Hedwig"
const GISBERT := "Kirmesgeist Gisbert"

## The single quests: npc, title, what they ask for, the reward (cents; `item`: a thing too,
## given again (`ask_again`, `again`) to whoever finished the quest without it, e.g. an older save),
## the lines.
const QUESTS := [
	{"id": "horseshoe", "npc": "jolanda", "title": "Ein Eisen für Blitz", "needs": {"horseshoe": 1}, "money": 400,
		"ask": "„Blitz hat schon wieder ein Hufeisen verloren. Brunhild in der Schmiede macht dir eins, wenn du ihr Erz bringst. Bringst du es mir?“",
		"task": "Lass bei Schmiedin Brunhild ein Hufeisen schmieden (ein Erzbrocken) und bring es Jolanda.",
		"thanks": "„Danke! Blitz trabt schon ganz ungeduldig. Für dich ist der nächste Ritt umsonst – na ja, fast.“"},
	{"id": "ore", "npc": "brunhild", "title": "Erz für die Esse", "needs": {"ore": 5}, "money": 800,
		"ask": "„Meine Esse hat Hunger! Fünf Erzbrocken aus dem Steinbruch der Zwerge, dann kann ich wieder richtig schmieden.“",
		"task": "Bring Schmiedin Brunhild fünf Erzbrocken aus dem Steinbruch im Nordwald.",
		"thanks": "„Zwergenerz! Riechst du das? So riecht gutes Eisen. Danke dir!“"},
	{"id": "fish", "npc": "wirtin", "title": "Fisch für die Taverne", "needs": {"fish": 3}, "money": 600,
		"ask": "„Fiete räuchert mir alle Forellen weg. Bringst du mir drei frische aus dem Waldweiher? Dann gibt's Fischsuppe.“",
		"task": "Angle drei Forellen im Waldweiher und bring sie Wirtin Gertrud.",
		"thanks": "„Prachtvolle Forellen! Die Suppe wird ein Gedicht. Komm heute Abend vorbei!“"},
	{"id": "honey", "npc": "hannes", "title": "Die heisere Stimme", "needs": {"honey": 1}, "money": 500,
		"ask": "(Hannes krächzt.) „Hört, hört … ach, es geht nicht. Honig! Ein Glas Waldhonig hilft mir immer.“",
		"task": "Bring Marktschreier Hannes ein Glas Waldhonig gegen seine heisere Stimme.",
		"thanks": "„HÖRT, HÖRT! Sie ist wieder da! Und ein Geheimnis zum Dank: Ganz oben in der Burg, wo der Fels beginnt, gibt es eine Tür, die keiner beachtet.“"},
	{"id": "herbs", "npc": "walburga", "title": "Kräuterkunde", "needs": {"st_johns_wort": 1, "rose_hip": 1}, "money": 300,
		"item": Items.POUCH,
		"ask": "„Du willst Tränke? Dann lern erst die Kräuter! Bring mir Johanniskraut vom Hang im Westen und Hagebutten aus den Hecken im Osten. Dafür kriegst du meinen alten Kräuterbeutel.“",
		"task": "Bring Kräuterhexe Walburga Johanniskraut und Hagebutten von den Hängen der Burg. Sie gibt dir dafür ihren Kräuterbeutel: Kräuter und Beeren brauchen dann keinen Platz mehr im Rucksack.",
		"thanks": "„Hehe, du lernst schnell. Hier, mein alter Kräuterbeutel: Da passen alle Kräuter und Beeren rein, die du findest, und dein Rucksack bleibt frei. Kamille wächst im Stadtpark, Waldmeister und Bärlauch im Nordwald, Lavendel auf der Kirmes. Merk dir das!“",
		"ask_again": "Bekomme ich noch einen Kräuterbeutel?",
		"again": "„Ach, Kindchen, dir fehlt ja noch mein Kräuterbeutel! Hier, nimm ihn.“"},
	{"id": "kasper", "npc": "liesel", "title": "Kasper ist weg", "needs": {"kasper": 1}, "money": 600,
		"ask": "„Kasper ist weg! Ohne Kasper kann ich nicht spielen. Ein Junge von der Kirmes hat ihn gestern so lieb angeschaut …“",
		"task": "Liesels Kasperpuppe ist auf der Kirmes. Frag die Kinder dort.",
		"thanks": "„Kasper! Tri-tra-trullala, Kasper ist wieder da! Danke!“"},
]

const RIDDLES := [
	["„Ich habe Zähne, aber beiße nie. Ich habe einen Kopf, aber denke nie. Was bin ich?“", ["Ein Kamm", "Ein Kohlkopf", "Ein Burgtor"], 0],
	["„Je mehr man davon wegnimmt, desto größer wird es. Was ist es?“", ["Ein Loch", "Ein Berg", "Ein Schatten"], 0],
	["„Ich laufe und habe keine Beine, ich rausche und habe keinen Mund. Was bin ich?“", ["Ein Bach", "Ein Ritter", "Der Wind"], 0],
]

## The exhibition's boards: [position, title, text].
const BOARDS := [
	[Vector2(-277.0, -234.4), "Die Gründung", "Vor achthundert Jahren baute Ritter Klappenstein der Ältere hier oben einen Turm aus Feldsteinen. Er wollte sehen, wer den Berg hinaufkommt. Es kam jahrelang niemand."],
	[Vector2(-253.0, -234.4), "Der Bergfried", "Der Aussichtsturm ist das älteste Stück der Burg. Hundertzwölf Stufen. Kastellanin Ottilie zählt sie jeden Morgen nach."],
	[Vector2(-266.0, -224.0), "Das innere Tor", "Durch das innere Tor durften früher nur Ritter. Heute dürfen alle durch, die sich die Schuhe abtreten."],
	[Vector2(-255.0, -144.6), "Das Torhaus", "Das Fallgitter wurde nur einmal heruntergelassen: als eine Ziege den Markt stürmen wollte."],
	[Vector2(-248.0, -128.5), "Das Turnier", "Seit dreihundert Jahren wird hier tjostiert. Die Lanzen sind aus Holz und brechen leicht. Die Ritter auch, behauptet Oma Hiltrud."],
	[Vector2(-244.0, -241.0), "Die Zwerge", "Die Zwerge im Berg handelten schon mit der Burg, als sie noch ein Turm war. Ein alter Gang verbindet beide. Wo genau, weiß keiner mehr. Fast keiner."],
]

var hedwig: Node3D
var hedwig_fair: Node3D
var _t := 0.0


func setup(g: Game) -> void:
	super(g)
	world.area_loaded.connect(func(id: String) -> void:
		if id == "burg":
			_build_burg()
		elif id == "fair":
			_build_fair())


func quest_givers() -> Array:
	var out := ["morwen", "zambini", "esmeralda", "brunhild", "ludwig", "fairkid_0"]
	for q: Dictionary in QUESTS:
		out.append(q["npc"])
	return out


static func staff() -> int:
	return GameState.stat("staff_step")


static func ghosts() -> int:
	return GameState.stat("ghosts_step")


static func _staff(n: int) -> void:
	GameState.set_stat_max("staff_step", n)


static func _ghosts(n: int) -> void:
	GameState.set_stat_max("ghosts_step", n)


static func quest_stage(id: String) -> int:
	return GameState.stage("bq_" + id)


## Hedwig floats at the castle's top from ten at night to three in the morning.
static func ghost_out() -> bool:
	return FairStories.ghost_out()


func _build_burg() -> void:
	var b := world.burg
	hedwig = Node3D.new()
	hedwig.name = "Hedwig"
	var mi := MeshInstance3D.new()
	mi.mesh = BurgModels.lady_ghost()
	hedwig.add_child(mi)
	hedwig.position = _ground(HEDWIG_AT)
	b.add_child(hedwig)
	_spot(b, HEDWIG_AT + Vector2(0, 1.4), 2.4, func(_a: Actor) -> String:
		return "Das Gespenst ansprechen" if ghost_out() else "", _talk_hedwig)
	for i in BOARDS.size():
		var e: Array = BOARDS[i]
		var p: Vector2 = e[0]
		var board := MeshInstance3D.new()
		board.mesh = PropModels.info_board()
		board.position = _ground(p)
		b.add_child(board)
		world.map.add_obstacle_rect(p, Vector2(2.0, 0.4), 0.0, ParkMap.BLOCK_PEOPLE)
		_spot(b, p + Vector2(0, 1.2), 1.6, func(_a: Actor) -> String: return "Tafel lesen: %s" % e[1], func(_a: Actor) -> void: _read_board(i))


func _build_fair() -> void:
	hedwig_fair = Node3D.new()
	hedwig_fair.name = "HedwigAtTheFair"
	var mi := MeshInstance3D.new()
	mi.mesh = BurgModels.lady_ghost()
	hedwig_fair.add_child(mi)
	hedwig_fair.position = _ground(FairStories.GHOST_AT + Vector2(1.6, 0.4))
	hedwig_fair.visible = false
	world.fair.add_child(hedwig_fair)


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, world.map.walk_height(p.x, p.y), p.y)


func _spot(parent: Node3D, p: Vector2, r: float, prompt: Callable, action: Callable) -> FunctionSpot:
	var s := FunctionSpot.new()
	s.position = _ground(p)
	s.radius = r
	s.users = "human"
	s.prompt_fn = prompt
	s.available_fn = func(a: Actor) -> bool: return prompt.call(a) != ""
	s.action_fn = action
	parent.add_child(s)
	return s


func _process(delta: float) -> void:
	_t += delta
	var night := ghost_out()
	if hedwig and world.burg and world.area_awake("burg"):
		# After the two met, on odd days she visits Gisbert at the Kirmes instead.
		var away := ghosts() >= 5 and Clock.day % 2 == 1
		hedwig.visible = night and not away
		hedwig.position.y = world.map.walk_height(HEDWIG_AT.x, HEDWIG_AT.y) + 0.45 + sin(_t * 1.4) * 0.15
		hedwig.rotation.y = sin(_t * 0.5) * 0.4
	if hedwig_fair and world.fair and world.area_awake("fair"):
		hedwig_fair.visible = night and ghosts() >= 5 and Clock.day % 2 == 1
		hedwig_fair.position.y = world.map.walk_height(hedwig_fair.position.x, hedwig_fair.position.z) + 0.5 + sin(_t * 1.5 + 1.0) * 0.15


# --- Conversations -----------------------------------------------------------------------

func options(player: Actor, npc: Actor) -> Array:
	var out := []
	if not player.is_human():
		return out
	match npc.actor_id:
		"morwen":
			if staff() == 0 and GameState.stat("crystal_best") > 0:
				out.append({"quest": true, "text": "Was ist mit Ihrem Stab?", "action": func() -> void: _morwen_story(player, npc)})
			elif staff() == 5 and player.has_item("star_staff"):
				out.append({"quest": true, "text": "Ihr Stab leuchtet wieder!", "action": func() -> void: _morwen_staff(player, npc)})
		"zambini":
			if staff() == 1:
				out.append({"quest": true, "text": "Kennen Sie Meister Morwen?", "action": func() -> void: _zambini_nervous(npc)})
			elif staff() == 3:
				out.append({"quest": true, "text": "Darf ich in Ihren Zylinder schauen?", "action": func() -> void: _zambini_hat(player, npc)})
			elif staff() == 6 and player.has_item("morwen_letter"):
				out.append({"quest": true, "text": "Ein Brief von Meister Morwen", "action": func() -> void: _zambini_letter(player, npc)})
		"esmeralda":
			if staff() == 2:
				out.append({"quest": true, "text": "Wer war Zambini früher?", "action": func() -> void: _esmeralda_brother(npc)})
		"ludwig":
			if GameState.stat("riddles") < RIDDLES.size():
				out.append({"quest": not GameState.done_today("riddle_day"), "text": "Ein Rätsel hören", "action": func() -> void: _riddle(player, npc)})
		"fairkid_0":
			if quest_stage("kasper") == ACTIVE and not player.has_item("kasper"):
				out.append({"quest": true, "text": "Hast du eine Kasperpuppe?", "action": func() -> void: _kasper_kid(player, npc)})
	for q: Dictionary in QUESTS:
		if q["npc"] != npc.actor_id:
			continue
		var st := GameState.stage("bq_" + q["id"])
		if st == OPEN:
			out.append({"quest": true, "text": "Kann ich helfen?", "action": func() -> void: _ask(q, npc)})
		elif st == ACTIVE and _has(player, q["needs"]):
			out.append({"quest": true, "text": "Hier, bitte!", "action": func() -> void: _deliver(q, player, npc)})
		elif st == DONE and q.has("item") and not player.has_item(q["item"]):
			out.append({"quest": true, "text": q["ask_again"], "action": func() -> void: _give_again(q, player, npc)})
	return out


func _has(a: Actor, needs: Dictionary) -> bool:
	for item: String in needs:
		if int(a.inventory.get(item, 0)) < int(needs[item]):
			return false
	return true


func _ask(q: Dictionary, npc: Actor) -> void:
	GameState.set_stage("bq_" + q["id"], ACTIVE)
	UI.dialog_then(npc.display_name, q["ask"], [{"text": "Mach ich!", "id": ""}])


func _deliver(q: Dictionary, a: Actor, npc: Actor) -> void:
	for item: String in q["needs"]:
		a.take_item(item, int(q["needs"][item]))
	GameState.set_stage("bq_" + q["id"], DONE)
	GameState.add_money(int(q["money"]), q["title"])
	if q.has("item"):
		a.add_item(q["item"])
	thank(a, npc)
	UI.dialog_then(npc.display_name, q["thanks"], [{"text": "Gern geschehen!", "id": ""}])


func _give_again(q: Dictionary, a: Actor, npc: Actor) -> void:
	a.add_item(q["item"])
	UI.dialog_then(npc.display_name, q["again"], [{"text": "Danke!", "id": ""}])


func tasks() -> Array:
	var out := []
	for q: Dictionary in QUESTS:
		match GameState.stage("bq_" + q["id"]):
			ACTIVE: out.append({"title": q["title"], "desc": q["task"], "active": true})
			DONE: out.append({"title": q["title"], "desc": q["task"], "done": true})
	var staff_tasks := ["", "Meister Morwens Stab hat sein Licht verloren. Er hatte einmal einen Lehrling, der lieber rechnete … der große Zambini?",
		"Zambini wird nervös, wenn man Morwen erwähnt. Madame Esmeralda weiß, wer er früher war.",
		"„Was einst verschwand, kam aus dem Hut.“ Schau in Zambinis Zylinder.",
		"Schmiedin Brunhild soll den Sternensplitter in Morwens Stab setzen (zwei Erzbrocken, ein Edelstein).",
		"Bring Meister Morwen seinen leuchtenden Stab.", "Bring Zambini Morwens Brief.", "Zwei Zauberer haben sich versöhnt."]
	if staff() > 0:
		out.append({"title": "Der Sternenstab", "desc": staff_tasks[staff()], "active": staff() < 7, "done": staff() >= 7})
	var ghost_tasks := ["", "Bring Hedwigs Brief nachts zum Kirmesgeist Gisbert an der Geisterbahn.",
		"Bring Gisberts Antwort nachts zu Hedwig auf die Burg.", "Lass bei Schmiedin Brunhild eine Geisterlaterne schmieden (zwei Erzbrocken, ein Brett) und bring sie nachts zu Hedwig.",
		"Fahr nachts mit Hedwig in der Laterne auf das Riesenrad.", "Hedwig und Gisbert haben sich gefunden."]
	if ghosts() > 0:
		out.append({"title": "Zwei Gespenster", "desc": ghost_tasks[ghosts()], "active": ghosts() < 5, "done": ghosts() >= 5})
	var r := GameState.stat("riddles")
	if r > 0:
		out.append({"title": "Lumpen-Ludwigs Rätsel", "desc": "%d von %d Rätseln gelöst (eins am Tag)." % [r, RIDDLES.size()], "done": r >= RIDDLES.size()})
	var boards: int = GameState.sets.get("burg_boards", {}).size()
	if boards > 0:
		out.append({"title": "Burggeschichte", "desc": "%d von %d Tafeln gelesen." % [boards, BOARDS.size()], "done": boards >= BOARDS.size()})
	for e: Dictionary in out:
		if not e.has("area"):
			e["area"] = "burg"
	return out


# --- Der Sternenstab ----------------------------------------------------------------------

func _morwen_story(a: Actor, npc: Actor) -> void:
	_staff(1)
	a.add_item("morwen_staff")
	UI.dialog_then(npc.display_name, "„Mein Stab? Früher leuchtete er wie ein Stern. Bis ein Splitter vom Stern verschwand – an dem Tag, als mein Lehrling ging. Er rechnete lieber, als zu zaubern. Er nennt sich jetzt … der große Soundso. Auf der Kirmes.\n\nNimm den Stab. Vielleicht findest du, was ihm fehlt.“",
		[{"text": "Der große Zambini?", "id": ""}])


func _zambini_nervous(npc: Actor) -> void:
	_staff(2)
	UI.dialog_then(npc.display_name, "„M-Morwen? Nie gehört! … Na gut, vielleicht ein bisschen. Lange her. Frag doch Madame Esmeralda, die weiß, wer ich mal war. Ich muss jetzt … Zahlen üben.“",
		[{"text": "Hm …", "id": ""}])


func _esmeralda_brother(npc: Actor) -> void:
	_staff(3)
	UI.dialog_then(npc.display_name, "(Madame Esmeralda lächelt.) „Zambini war Morwens Lehrling. Und Morwen … ist mein Bruder. Ich bin mit Zambini zur Kirmes gegangen, als die beiden sich stritten.\n\nDie Kugel zeigt mir einen Satz: Was einst verschwand, kam aus dem Hut.“",
		[{"text": "Aus dem Hut …", "id": ""}])


func _zambini_hat(a: Actor, npc: Actor) -> void:
	if FairStories.step() < 6:
		UI.dialog_then(npc.display_name, "„Mein Zylinder? Nicht, solange mein Hoppel verschwunden ist! Ohne ihn ist der Hut so leer …“",
			[{"text": "Ich suche Hoppel.", "id": ""}])
		return
	_staff(4)
	a.add_item("star_splinter")
	Sound.play("achievement", npc.global_position, -6.0)
	UI.dialog_then(npc.display_name, "„Na gut, schau hinein … Was ist das? Ein glitzernder Splitter, ganz unten im Futter! Der muss aus Morwens Stab sein … Deshalb ist Hoppel damals wirklich verschwunden! Mein Hut hat echt gezaubert!\n\nBring ihn zurück. Bitte.“",
		[{"text": "Mach ich.", "id": ""}])


## The smithy's recipe "star_staff" (Crafting) moves the story on.
static func staff_mended() -> void:
	_staff(5)


func _morwen_staff(a: Actor, npc: Actor) -> void:
	a.take_item("star_staff")
	_staff(6)
	a.add_item("morwen_letter")
	Gameplay.eggs.confetti(npc.global_position + Vector3(0, 2.0, 0))
	UI.dialog_then(npc.display_name, "(Der Stab leuchtet hell auf. Morwen schweigt eine Weile.)\n\n„Er leuchtet. Wie früher … Ich war damals zu streng mit dem Jungen. Bring ihm diesen Brief. Und sag ihm … Rechnen ist auch eine Art Zauberei.“",
		[{"text": "Ich bringe ihn hin.", "id": ""}])


func _zambini_letter(a: Actor, npc: Actor) -> void:
	a.take_item("morwen_letter")
	_staff(7)
	GameState.add_money(2000, "Der Sternenstab")
	thank(a, npc, 30.0)
	Gameplay.eggs.confetti(npc.global_position + Vector3(0, 2.0, 0))
	npc.play_anim("cheer", 3.0)
	UI.dialog_then(npc.display_name, "(Zambini liest. Er schluckt.)\n\n„Er schreibt, er sei stolz auf mich. Auf MICH!\n\nUnd sieh nur – mein Hut!“ (Aus dem Zylinder flattert eine weiße Taube und dreht eine Runde über der Bühne.) „Echte Zauberei! Esmeralda, hast du das gesehen?“",
		[{"text": "Zwei Zauberer!", "id": ""}])


# --- Zwei Gespenster ----------------------------------------------------------------------

func _talk_hedwig(a: Actor) -> void:
	match ghosts():
		0:
			if GameState.stage("ghost") != DONE:
				UI.dialog(HEDWIG, "„Huch! Ein Besucher, so spät? Ich bin Hedwig, das Burgfräulein. Seit dreihundert Jahren. Niemand bleibt wach für mich …\n\nMan erzählt sich von einem Herrn Gespenst auf der Kirmes, der seine Uhr verloren hat. Ein Herr mit Uhr! Wie elegant.“",
					[{"text": "Gute Nacht, Hedwig.", "id": ""}])
				return
			_ghosts(1)
			a.add_item("hedwig_letter")
			UI.dialog(HEDWIG, "„Huch! Ein Besucher! Ich bin Hedwig, das Burgfräulein.\n\nMan sagt, der Herr Kirmesgeist hat seine Uhr wieder. Ein Herr, der pünktlich ist! Würdest du ihm einen Brief bringen? Nachts natürlich, tagsüber schlafen wir.“",
				[{"text": "Ich bringe ihn hin.", "id": ""}])
		2 when a.has_item("gisbert_letter"):
			a.take_item("gisbert_letter")
			_ghosts(3)
			UI.dialog(HEDWIG, "(Hedwig liest und wird ein wenig durchsichtiger vor Freude.)\n\n„Er schreibt, er wartet jede Nacht oben auf dem Riesenrad! Aber ich kann die Burg nicht verlassen … Es sei denn – in einer Geisterlaterne! Schmiedin Brunhild kann so etwas.“",
				[{"text": "Ich frag Brunhild.", "id": ""}])
		3 when a.has_item("ghost_lantern"):
			a.take_item("ghost_lantern")
			a.add_item("hedwig_lantern")
			_ghosts(4)
			UI.dialog(HEDWIG, "„Eine Laterne! Wie hübsch.“ (Hedwig schrumpft zu einem Lichtlein und schlüpft hinein.)\n\n„Zum Riesenrad, bitte! Ganz nach oben. Und nachts, sonst sehe ich nichts.“",
				[{"text": "Auf zur Kirmes!", "id": ""}])
		_:
			UI.dialog(HEDWIG, ["„Huuh … oh, du bist es.“", "„Hörst du die Fackeln knistern? Ich liebe das.“", "„Grüß den Herrn Kirmesgeist von mir.“"][randi() % 3] if ghosts() != 4 else "„Ich bin doch in der Laterne!“",
				[{"text": "Gute Nacht, Hedwig.", "id": ""}])


## Gisbert at the ghost train (FairStories): Hedwig's letter and his answer. True if he said
## something about it (FairStories then says nothing else).
func ghost_talk(a: Actor) -> bool:
	if ghosts() == 1 and a.has_item("hedwig_letter"):
		a.take_item("hedwig_letter")
		a.add_item("gisbert_letter")
		_ghosts(2)
		UI.dialog(GISBERT, "„Ein Brief? Für MICH? Von einem Burgfräulein?“ (Gisbert wird ganz rosa, soweit Geister rosa werden.)\n\n„Bring ihr meine Antwort, ja? Ich warte jede Nacht oben auf dem Riesenrad. Um Mitternacht. Pünktlich – ich hab ja meine Uhr wieder!“",
			[{"text": "Ich bringe sie hin.", "id": ""}])
		return true
	if ghosts() == 4 and a.has_item("hedwig_lantern"):
		UI.dialog(GISBERT, "„Ist sie … in der Laterne? Schnell, aufs Riesenrad! Ganz nach oben!“", [{"text": "Bin schon unterwegs!", "id": ""}])
		return true
	if ghosts() >= 5:
		UI.dialog(GISBERT, ["„Hedwig sagt, du bist der netteste Mensch, den sie kennt. Seit dreihundert Jahren!“", "„Es ist %s. Gleich kommt Hedwig vorbei.“" % Clock.time_string()][randi() % 2],
			[{"text": "Gute Nacht, Gisbert.", "id": ""}])
		return true
	return false


## On top of the Ferris wheel (FairStories.at_wheel_top): with Hedwig in the lantern at night
## the two ghosts meet.
func at_wheel_top(a: Actor) -> String:
	if ghosts() != 4 or not a.has_item("hedwig_lantern") or not ghost_out():
		return ""
	a.take_item("hedwig_lantern")
	_ghosts(5)
	GameState.add_money(1500, "Zwei Gespenster")
	a.needs.cheer(30.0)
	var hint := " Hedwig flüstert dir zum Dank zu: „Ganz oben in der Burg, wo der Fels beginnt, ist eine Tür in den Berg.“" if GameState.stat("passage") == 0 else ""
	return "Oben in der Gondel schwebt Gisbert. Hedwig schlüpft aus der Laterne – und die beiden Gespenster drehen eine Runde um das Rad, Hand in Hand.%s" % hint


# --- Lumpen-Ludwig, the boards, the Kasper puppet -------------------------------------------

func _riddle(a: Actor, npc: Actor) -> void:
	if GameState.done_today("riddle_day"):
		UI.dialog_then(npc.display_name, "„Ein Rätsel am Tag, mehr verträgt mein Kopf nicht. Komm morgen wieder.“", [{"text": "Bis morgen!", "id": ""}])
		return
	var r: Array = RIDDLES[GameState.stat("riddles")]
	var opts := []
	for i in r[1].size():
		opts.append({"text": r[1][i], "id": str(i)})
	UI.dialog_then(npc.display_name, r[0], opts, func(c: String) -> void:
		if c == "":
			return
		GameState.mark_today("riddle_day")
		if int(c) == r[2]:
			GameState.add_stat("riddles")
			GameState.add_money(200, "Ludwigs Rätsel")
			thank(a, npc, 10.0)
			var last := GameState.stat("riddles") >= RIDDLES.size()
			UI.dialog_then(npc.display_name, "„Richtig! Du hast einen hellen Kopf.“" + ("\n\n„Und weil du alle gelöst hast, mein größtes Geheimnis: Die Zwerge und die Burg sind durch einen Gang verbunden. Die Tür ist da, wo der Fels beginnt.“" if last else ""),
				[{"text": "Danke, Ludwig!", "id": ""}])
		else:
			UI.dialog_then(npc.display_name, "„Leider falsch! Denk drüber nach und komm morgen wieder.“", [{"text": "Hmpf.", "id": ""}]))


func _read_board(i: int) -> void:
	var e: Array = BOARDS[i]
	GameState.add_to_set("burg_boards", str(i))
	UI.dialog("Ritterausstellung: %s" % e[1], e[2], [{"text": "Interessant!", "id": ""}])


func _kasper_kid(a: Actor, npc: Actor) -> void:
	UI.dialog_then(npc.display_name, "„Der Kasper? Den hab ich gefunden! … Na gut, er gehört mir nicht. Aber kriege ich dafür eine Fahrt mit dem Karussell? Die kostet 1,50 €.“",
		[{"text": "1,50 € geben", "id": "pay"}, {"text": "Ein andermal.", "id": ""}], func(c: String) -> void:
			if c == "pay" and a.room_for("kasper", 1) and GameState.spend(150):
				a.add_item("kasper")
				UI.dialog_then(npc.display_name, "„Juhu! Hier ist Kasper. Tschüss, Kasper!“", [{"text": "Danke!", "id": ""}]))

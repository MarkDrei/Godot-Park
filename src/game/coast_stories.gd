class_name CoastStories
extends QuestModule
## Stories and quests of the Möwenbucht (doc/moewenbucht.md, phase 4):
## - Flaschenpost: a message in a bottle lies on the beach by the rocks, written forty years ago
##   by a boy called Fiete who wanted to build the biggest sandcastle in the world and to smoke
##   fish on a castle one day. Opa Fietje knows him: his nephew, Räucher-Fiete at the Ritterburg.
##   Fiete sends his uncle a smoked fish back. Stat "bottle_step": 0 untold, 1 to Opa Fietje,
##   2 to Fiete at the castle, 3 the fish to Fietje, 4 done.
## - Leuchtfeuer: the lighthouse's lens has a crack, at night the tower stays dark; Brunhild at the
##   castle's smithy makes a new one (the cracked lens, a piece of amber, ore). Stat "lamp_step":
##   0, 1 to the smithy, 2 back to Hinnerk, 3 done.
## - Single quests (stages "cq_<id>"): herring for Uwe, berries for Giulia's sauce, amber for
##   Sönke, shells for Klaus's rattle, Svenja's sunglasses in the dunes, the pedal boat that
##   drifted onto the beach for Ole, a photo of the seals for Hinnerk (BoatPhoto, from a boat by
##   the sandbank).

const QUESTS := [
	{"id": "herring", "npc": "uwe", "title": "Heringe für Uwe", "needs": {"herring": 5}, "money": 500,
		"ask": "„Mir gehen die Heringe aus! Fünf frische, von der Seebrücke oder der Mole. Dann gibt's wieder Fischbrötchen.“",
		"task": "Angle fünf Heringe (Seebrücke, Mole, Hafen) und bring sie Fischbrötchen-Uwe.",
		"thanks": "„Fünf Prachtheringe! Die Möwen werden neidisch. Danke dir!“"},
	{"id": "berries", "npc": "giulia", "title": "Beerensoße", "needs": {"berries": 6}, "money": 400,
		"ask": "„Für mein Spaghettieis brauche ich Beeren. Echte Waldbeeren! Sechs Stück. Im Nordwald wachsen die besten.“",
		"task": "Pflück sechs Waldbeeren im Nordwald und bring sie Eis-Giulia.",
		"thanks": "„Perfetto! Die Soße wird ein Traum. Sag Gianni nichts davon, ja?“"},
	{"id": "amber", "npc": "soenke", "title": "Bernstein für Sönke", "needs": {"amber": 2}, "money": 1000,
		"ask": "„Ein Kunde will eine Bernsteinkette. Zwei Stücke fehlen mir. Das Meer spült sie mit den Muscheln an, wenn man Glück hat.“",
		"task": "Such Bernstein beim Muschelnsammeln am Strand und bring Souvenir-Sönke zwei Stücke.",
		"thanks": "„Zwei! Und so klar! Die Kette wird wunderschön. Hier, du hast es dir verdient.“"},
	{"id": "shells", "npc": "klaus", "title": "Die Muschelrassel", "needs": {"shell": 6}, "money": 400,
		"ask": "„Mein Akkordeon ist kaputt, aber ein Shanty braucht Takt! Sechs Muscheln, dann bastle ich mir eine Rassel.“",
		"task": "Sammle sechs Muscheln am Strand und bring sie Kapellmeister Klaus.",
		"thanks": "(Klaus rasselt.) „Hörst du das? Das ist Rhythmus! Heute Nachmittag spiele ich nur für dich.“"},
	{"id": "glasses", "npc": "svenja", "title": "Svenjas Sonnenbrille", "needs": {"svenja_glasses": 1}, "money": 300,
		"ask": "„Ich hab meine Sonnenbrille in den Dünen verloren, beim Joggen. Ohne sie sehe ich bei der Sonne fast nichts!“",
		"task": "Such Svenjas Sonnenbrille in den Dünen (irgendwo glitzert es im Sand) und bring sie ihr.",
		"thanks": "„Meine Brille! Jetzt hab ich wieder alles im Blick. Danke!“"},
	{"id": "boat", "npc": "ole", "title": "Das abgetriebene Tretboot", "needs": {}, "money": 400,
		"ask": "„Mir ist heute Nacht ein Tretboot abgetrieben! Es liegt am Strand bei den Felsen. Fährst du es zurück zum Steg?“",
		"task": "Fahr Oles abgetriebenes Tretboot vom Strand bei den Felsen zurück zum Bootssteg und sag ihm Bescheid.",
		"thanks": "„Da ist es ja! Acht Boote, alle da. Danke, Kapitän!“"},
	{"id": "seals", "npc": "hinnerk", "title": "Ein Foto der Robben", "needs": {"seal_photo": 1}, "money": 500,
		"ask": "„An meiner Wand fehlt ein Foto von den Robben. Fahr mit einem Boot zur Sandbank und knips sie. Aber leise!“",
		"task": "Fahr mit einem Boot nah an die Sandbank, fotografier die Robben und bring Leuchtturmwärter Hinnerk das Foto.",
		"thanks": "„Da liegen sie ja, die Faulpelze. Das kommt an die Wand, gleich neben den Sturm von achtundsiebzig.“"},
]

## Where the bottle lies, where Svenja's sunglasses are, where the drifted boat lies.
const BOTTLE_AT := Vector2(-88, 166)
const GLASSES_AT := Vector2(28, 124)
const DRIFT_AT := Vector2(-84, 172.4)
## Close enough to the sandbank for the photo (from a boat).
const PHOTO_REACH := 24.0

var bottle: Node3D
var glasses: Node3D
var drift_boat: Car


func setup(g: Game) -> void:
	super(g)
	world.area_loaded.connect(func(id: String) -> void:
		if id == "coast":
			_build_coast())


func quest_givers() -> Array:
	var out := ["fietje", "fiete", "hinnerk"]
	for q: Dictionary in QUESTS:
		out.append(q["npc"])
	return out


static func bottle_step() -> int:
	return GameState.stat("bottle_step")


static func lamp_step() -> int:
	return GameState.stat("lamp_step")


static func _bottle(n: int) -> void:
	GameState.set_stat_max("bottle_step", n)


static func _lamp(n: int) -> void:
	GameState.set_stat_max("lamp_step", n)


static func quest_stage(id: String) -> int:
	return GameState.stage("cq_" + id)


## The lighthouse is dark at night while its lens is broken.
static func lamp_broken() -> bool:
	return lamp_step() >= 1 and lamp_step() <= 2


## The smithy's recipe "lighthouse_lens" (Crafting) moves the story on.
static func lens_mended() -> void:
	_lamp(2)


func _build_coast() -> void:
	var c := world.coast
	bottle = MeshInstance3D.new()
	(bottle as MeshInstance3D).mesh = CoastModels.message_bottle()
	bottle.position = _ground(BOTTLE_AT) + Vector3(0, 0.05, 0)
	bottle.rotation = Vector3(0, 0.6, PI / 2)
	bottle.scale = Vector3(1.8, 1.8, 1.8)   # big enough to be seen on the sand
	c.add_child(bottle)
	_spot(c, BOTTLE_AT, 1.8, func(_a: Actor) -> String: return "Eine Flaschenpost aufheben" if bottle_step() == 0 else "", _pick_bottle)
	glasses = MeshInstance3D.new()
	(glasses as MeshInstance3D).mesh = CoastModels.sunglasses()
	glasses.position = _ground(GLASSES_AT) + Vector3(0, 0.03, 0)
	c.add_child(glasses)
	_spot(c, GLASSES_AT, 1.8, func(a: Actor) -> String:
		return "Etwas glitzert im Sand" if quest_stage("glasses") == ACTIVE and not a.has_item("svenja_glasses") else "", _pick_glasses)
	var photo := BoatPhoto.new()
	photo.setup(world)
	c.add_child(photo)
	_refresh()


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


## What lies about shows by the stories' state; the drifted boat while its quest runs.
func _refresh() -> void:
	if bottle:
		bottle.visible = bottle_step() == 0
	if glasses:
		glasses.visible = quest_stage("glasses") == ACTIVE and not (UI.game and UI.game.player.actor and UI.game.player.actor.has_item("svenja_glasses"))
	if world.coast and quest_stage("boat") == ACTIVE and drift_boat == null:
		drift_boat = Car.new()
		world.coast.add_child(drift_boat)
		drift_boat.setup(world, "pedalo", Color("f4f1ea"), DRIFT_AT, PI / 2 + 0.15)
		world.coast.boats.append(drift_boat)


func _process(_delta: float) -> void:
	if world and world.coast and world.area_awake("coast"):
		_refresh()


## The drifted boat is back: by the jetty.
func boat_back() -> bool:
	return drift_boat != null and drift_boat.pos2().distance_to(CoastLayout.place("jetty")) < 14.0


# --- Conversations -----------------------------------------------------------------------

func options(player: Actor, npc: Actor) -> Array:
	var out := []
	if not player.is_human():
		return out
	match npc.actor_id:
		"fietje":
			if bottle_step() == 1 and player.has_item("message_bottle"):
				out.append({"quest": true, "text": "Kennen Sie einen Fiete?", "action": func() -> void: _fietje_nephew(npc)})
			elif bottle_step() == 3 and player.has_item("fiete_fish"):
				out.append({"quest": true, "text": "Ein Gruß von Fiete", "action": func() -> void: _fietje_fish(player, npc)})
		"fiete":
			if bottle_step() == 2 and player.has_item("message_bottle"):
				out.append({"quest": true, "text": "Eine Flaschenpost für Sie", "action": func() -> void: _fiete_bottle(player, npc)})
		"hinnerk":
			if lamp_step() == 0 and GameState.stat("lighthouse_view") > 0:
				out.append({"quest": true, "text": "Warum ist der Leuchtturm nachts dunkel?", "action": func() -> void: _hinnerk_lens(player, npc)})
			elif lamp_step() == 2 and player.has_item("lighthouse_lens"):
				out.append({"quest": true, "text": "Die neue Linse!", "action": func() -> void: _hinnerk_light(player, npc)})
	for q: Dictionary in QUESTS:
		if q["npc"] != npc.actor_id:
			continue
		var st := quest_stage(q["id"])
		if st == OPEN:
			out.append({"quest": true, "text": "Kann ich helfen?", "action": func() -> void: _ask(q, npc)})
		elif st == ACTIVE and _can_deliver(q, player):
			out.append({"quest": true, "text": "Hier, bitte!" if not q["needs"].is_empty() else "Dein Tretboot ist zurück!", "action": func() -> void: _deliver(q, player, npc)})
	return out


func _can_deliver(q: Dictionary, a: Actor) -> bool:
	if q["id"] == "boat":
		return boat_back()
	for item: String in q["needs"]:
		if int(a.inventory.get(item, 0)) < int(q["needs"][item]):
			return false
	return true


func _ask(q: Dictionary, npc: Actor) -> void:
	GameState.set_stage("cq_" + q["id"], ACTIVE)
	_refresh()
	UI.dialog_then(npc.display_name, q["ask"], [{"text": "Mach ich!", "id": ""}])


func _deliver(q: Dictionary, a: Actor, npc: Actor) -> void:
	for item: String in q["needs"]:
		a.take_item(item, int(q["needs"][item]))
	GameState.set_stage("cq_" + q["id"], DONE)
	GameState.add_money(int(q["money"]), q["title"])
	if q["id"] == "seals":
		GameState.add_stat("seal_photo")
	if q["id"] == "boat" and drift_boat:
		# One more boat for the rental: it stays at the jetty.
		drift_boat.place(CoastLayout.place("jetty") + Vector2(-2.4, 10.0), 0.0)
	thank(a, npc)
	UI.dialog_then(npc.display_name, q["thanks"], [{"text": "Gern geschehen!", "id": ""}])


func _pick_bottle(a: Actor) -> void:
	if bottle_step() != 0:
		return
	_bottle(1)
	a.add_item("message_bottle")
	Sound.play("pickup", a.global_position)
	UI.dialog_then("Flaschenpost", "In der Flasche steckt ein Zettel, mit Kinderschrift:\n\n„Wer das findet: Ich heiße Fiete und bin neun. Ich baue die größte Sandburg der Welt. Wenn ich groß bin, räuchere ich Fisch auf einer echten Burg! Bitte bring diesen Brief zu meinem Onkel Fietje.\n– Fiete, Möwenbucht“\n\nDas Papier ist ganz vergilbt. Die Flasche muss sehr lange getrieben sein.",
		[{"text": "Opa Fietje …?", "id": ""}])


func _pick_glasses(a: Actor) -> void:
	a.add_item("svenja_glasses")
	Sound.play("pickup", a.global_position)
	GameState.toast.emit("Eine Sonnenbrille! Sicher die von Svenja.", "info")


# --- Flaschenpost -------------------------------------------------------------------------

func _fietje_nephew(npc: Actor) -> void:
	_bottle(2)
	UI.dialog_then(npc.display_name, "(Opa Fietje liest und wird ganz still.)\n\n„Fiete … Das ist mein Neffe! Die Flasche hat er vor vierzig Jahren geworfen, hier vom Strand. Die größte Sandburg hat er nie gebaut. Aber den Fisch – den räuchert er heute auf der Ritterburg, hab ich gehört.\n\nBring ihm seinen Brief. Er soll wissen, dass sein alter Onkel noch Sandburgen baut.“",
		[{"text": "Ich bringe ihn zur Burg.", "id": ""}])


func _fiete_bottle(a: Actor, npc: Actor) -> void:
	a.take_item("message_bottle")
	_bottle(3)
	a.add_item("fiete_fish")
	UI.dialog_then(npc.display_name, "„Meine Flaschenpost! Die hab ich als Junge vom Strand geworfen … Und Onkel Fietje baut immer noch Sandburgen?\n\nIch vermisse die Küste, weißt du. Bring ihm meinen besten Räucherfisch. Und sag ihm: Sonntags komme ich ihn besuchen. Moin, Onkel!“",
		[{"text": "Mach ich!", "id": ""}])


func _fietje_fish(a: Actor, npc: Actor) -> void:
	a.take_item("fiete_fish")
	_bottle(4)
	GameState.add_money(1500, "Flaschenpost")
	thank(a, npc, 25.0)
	Gameplay.eggs.confetti(npc.global_position + Vector3(0, 2.0, 0))
	UI.dialog_then(npc.display_name, "„Räucherfisch von Fiete! Und er kommt sonntags? Dann bauen wir zusammen die größte Sandburg der Welt. Vierzig Jahre zu spät – aber was macht das schon.\n\nDanke, mien Jung. Danke.“",
		[{"text": "Gern geschehen!", "id": ""}])


# --- Leuchtfeuer --------------------------------------------------------------------------

func _hinnerk_lens(a: Actor, npc: Actor) -> void:
	_lamp(1)
	a.add_item("cracked_lens")
	UI.dialog_then(npc.display_name, "„Die Linse hat einen Sprung. Seit dem letzten Sturm. Nachts bleibt mein Turm dunkel, und die Kutter finden den Hafen nicht.\n\nOben auf der Burg gibt's eine Schmiedin, Brunhild. Die kann alles. Bring ihr die Linse – und ein Stück Bernstein, für den Glanz. Erz hat sie bestimmt.“",
		[{"text": "Ich frage Brunhild.", "id": ""}])


func _hinnerk_light(a: Actor, npc: Actor) -> void:
	a.take_item("lighthouse_lens")
	_lamp(3)
	GameState.add_money(1000, "Leuchtfeuer")
	thank(a, npc, 25.0)
	UI.dialog_then(npc.display_name, "„Die passt! Heute Nacht dreht sich das Licht wieder. Die Kutter werden sich freuen – und die Robben auch, die gucken immer so gern.“",
		[{"text": "Gern geschehen!", "id": ""}])


func tasks() -> Array:
	var out := []
	for q: Dictionary in QUESTS:
		match quest_stage(q["id"]):
			ACTIVE: out.append({"title": q["title"], "desc": q["task"], "active": true})
			DONE: out.append({"title": q["title"], "desc": q["task"], "done": true})
	var bottle_tasks := ["", "Bring die Flaschenpost zu Opa Fietje an den Sandburgen.", "Bring Fiete seine Flaschenpost: Räucher-Fiete auf der Ritterburg.",
		"Bring Opa Fietje den Räucherfisch von Fiete.", "Fiete und sein Onkel Fietje haben sich wiedergefunden."]
	if bottle_step() > 0:
		out.append({"title": "Flaschenpost", "desc": bottle_tasks[bottle_step()], "active": bottle_step() < 4, "done": bottle_step() >= 4})
	var lamp_tasks := ["", "Lass bei Schmiedin Brunhild auf der Burg eine neue Linse machen (die gesprungene Linse, ein Bernstein, ein Erzbrocken).",
		"Bring Leuchtturmwärter Hinnerk die neue Linse.", "Der Leuchtturm leuchtet wieder."]
	if lamp_step() > 0:
		out.append({"title": "Leuchtfeuer", "desc": lamp_tasks[lamp_step()], "active": lamp_step() < 3, "done": lamp_step() >= 3})
	for e: Dictionary in out:
		e["area"] = "coast"
	return out

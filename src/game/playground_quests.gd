class_name PlaygroundQuests
extends QuestModule
## The playground gang and the troll's chest (doc/playground.md).
## - Robin, Finja and Mika play at the playground in the city park. One after the other they
##   ask for something and say where to find it: Robin an apple (Apfelwiese in the Oststadt,
##   Obstwiese in the Nordwald), Finja a cuddly unicorn (prize counter at the Kirmes, for
##   tickets), Mika a toy car (the drive-in's Kindermenü, ordered from a car).
## - Digging in the sandbox (SandDigGame) turns up an old rusty key with a troll's face. Bruno
##   under the Steinbrücke knows it: the key to his old chest, hidden by the bridge. Open it,
##   bring him his crown.
## State: stat "pg_step" (kid i of KIDS: 2i = may ask, 2i + 1 = wish open, 2i + 2 = done;
## DONE when all three are happy), stat
## "troll_chest" (0, 1 Bruno told, 2 chest opened, 3 crown back), item "rusty_key".

const KIDS := ["robin", "finja", "mika"]   # in this order, one wish after the other
const WANTS := {"robin": "apple", "finja": "plush_unicorn", "mika": "toy_car"}
## [the ask, the hint where to find it, the thanks].
const LINES := {
	"robin": ["„Ich hab sooo einen Hunger! Kannst du mir einen Apfel bringen? Einen echten, frisch vom Baum!“",
		"„Auf der Apfelwiese in der Oststadt hängen ganz viele. Und auf der Obstwiese im Nordwald, ganz im Osten. Man muss nur pflücken!“",
		"„Mmmh, knackig! Danke! Du, Finja ist heute so traurig. Frag sie mal.“"],
	"finja": ["„Alle haben ein Kuscheltier, nur ich nicht. Ich wünsch mir ein Einhorn. Ein weißes, mit Regenbogenmähne!“",
		"„Auf der Kirmes im Westpark gibt's bei der Gewinnausgabe eins. Dafür braucht man Tickets – die gibt's bei Los-Lothar für Lose oder an den Buden.“",
		"„Ein Einhorn! Ich nenn es Glitzer. Danke, danke, danke! Mika will dich auch noch was fragen.“"],
	"mika": ["„Mir fehlt noch ein Auto für meine Sammlung. Ein rotes Spielzeugauto, so eins wie im Kindermenü!“",
		"„Im Drive-in „Zum Durchfahrer“ in der Oststadt gibt's ein Kindermenü, da ist immer ein Spielzeugauto drin. Aber da muss man mit dem Auto hinfahren!“",
		"„Wroooom! Das ist das schönste in meiner Sammlung! Du bist jetzt in unserer Spielplatzbande.“"],
}
const DONE := 6

var chest: MeshInstance3D
var chest_spot: FunctionSpot


func setup(g: Game) -> void:
	super(g)
	_build_chest()


func quest_givers() -> Array:
	return KIDS + ["bruno"]


static func step() -> int:
	return GameState.stat("pg_step")


static func troll_step() -> int:
	return GameState.stat("troll_chest")


func options(player: Actor, npc: Actor) -> Array:
	var out := []
	if not player.is_human():
		return out
	var id := npc.actor_id
	if id in KIDS:
		var s := step()
		var i := KIDS.find(id)
		if s == 2 * i:
			out.append({"text": "Was ist los, %s?" % npc.display_name, "action": func() -> void: _ask(npc)})
		elif s == 2 * i + 1:
			if player.has_item(WANTS[id]):
				out.append({"text": "Hier, für dich: %s" % Items.name_of(WANTS[id]), "action": func() -> void: _give(player, npc)})
			else:
				out.append({"text": "Wo finde ich das noch mal?", "action": func() -> void:
					UI.dialog_then(npc.display_name, LINES[id][1], [{"text": "Ich schau mal!", "id": ""}])})
		if s >= DONE and troll_step() == 0 and not player.has_item("rusty_key"):
			out.append({"text": "Habt ihr mal was Besonderes gefunden?", "action": func() -> void:
				UI.dialog_then(npc.display_name, "„Im Sandkasten ist ein Schatz vergraben, ganz echt! Opa sagt, früher war da eine Sandgrube, und ein Troll hat dort gespielt. Grab doch mal – aber nicht nur an einer Stelle!“",
					[{"text": "Ein Troll? Spannend!", "id": ""}])})
	elif id == "bruno":
		if troll_step() == 0 and player.has_item("rusty_key"):
			out.append({"text": "Kennst du diesen Schlüssel?", "action": func() -> void: _show_key(npc)})
		elif troll_step() == 2 and player.has_item("troll_crown"):
			out.append({"text": "Deine Krone, Bruno!", "action": func() -> void: _return_crown(player, npc)})
	return out


func has_quest(player: Actor, npc: Actor) -> bool:
	if not player.is_human():
		return false
	match npc.actor_id:
		"robin", "finja", "mika":
			var i := KIDS.find(npc.actor_id)
			return step() == 2 * i or (step() == 2 * i + 1 and player.has_item(WANTS[npc.actor_id]))
		"bruno":
			return (troll_step() == 0 and player.has_item("rusty_key")) or (troll_step() == 2 and player.has_item("troll_crown"))
	return false


func _ask(npc: Actor) -> void:
	var id := npc.actor_id
	GameState.set_stat_max("pg_step", 2 * KIDS.find(id) + 1)
	npc.play_anim("talk", 3.0)
	UI.dialog_then(npc.display_name, "%s\n\n%s" % [LINES[id][0], LINES[id][1]], [{"text": "Mach ich!", "id": ""}])


func _give(player: Actor, npc: Actor) -> void:
	var id := npc.actor_id
	player.take_item(WANTS[id])
	GameState.set_stat_max("pg_step", 2 * KIDS.find(id) + 2)
	npc.play_anim("cheer", 3.0)
	npc.emote("heart", 2)
	player.needs.cheer(20.0)
	Sound.play("success")
	if step() >= DONE:
		GameState.toast.emit("Die Spielplatzbande hat ein neues Mitglied: dich!", "info")
	UI.dialog_then(npc.display_name, LINES[id][2], [{"text": "Gern geschehen!", "id": ""}])


func tasks() -> Array:
	var out := []
	var s := step()
	if s >= DONE:
		out.append({"title": "Die Spielplatzbande", "desc": "Robin, Finja und Mika sind glücklich. Du gehörst jetzt dazu.", "done": true})
	elif s > 0:
		var id: String = KIDS[s / 2]
		var kid := world.find_actor(id)
		var who := kid.display_name if kid else id.capitalize()
		var desc := "%s wünscht sich: %s." % [who, Items.name_of(WANTS[id])] if s % 2 == 1 else "%s will dich auch noch was fragen." % who
		out.append({"title": "Die Spielplatzbande", "desc": "%s (%d von 3 Wünschen erfüllt)" % [desc, s / 2], "active": true})
	match troll_step():
		1: out.append({"title": "Brunos alte Truhe", "desc": "Bruno hat seine Schatztruhe vor langer Zeit an der Steinbrücke versteckt. Schließ sie mit dem rostigen Schlüssel auf.", "active": true})
		2: out.append({"title": "Brunos alte Truhe", "desc": "Bring Bruno seine Trollkrone. Er kommt nur nachts unter der Steinbrücke hervor.", "active": true})
		3: out.append({"title": "Brunos alte Truhe", "desc": "Bruno trägt wieder seine Krone. Er sieht sehr würdevoll aus. Fast.", "done": true})
	return out


# --- Bruno's chest -------------------------------------------------------------------------

func _show_key(npc: Actor) -> void:
	GameState.set_stat_max("troll_chest", 1)
	npc.play_anim("cheer", 2.0)
	UI.dialog_then(npc.display_name, "„Hrmpf?! Mein Schlüssel! Den hab ich als kleiner Troll im Sand verbuddelt, vor dreihundert Jahren! Damals war da noch eine richtige Sandgrube.\n\nDer passt zu meiner Truhe. Die steht noch hier an der Brücke, unten am Ufer. Ich krieg sie nicht auf, meine Finger sind zu dick. Mach du sie auf – aber was drin ist, gehört mir! Na gut, das Gold darfst du behalten.“",
		[{"text": "Abgemacht!", "id": ""}])


func _return_crown(player: Actor, npc: Actor) -> void:
	player.take_item("troll_crown")
	GameState.set_stat_max("troll_chest", 3)
	npc.play_anim("cheer", 3.0)
	npc.emote("heart", 3)
	player.needs.cheer(25.0)
	Sound.play("success")
	UI.dialog_then(npc.display_name, "(Bruno setzt sich die kleine, verbeulte Krone auf den riesigen Kopf. Sie rutscht ihm über ein Ohr.)\n\n„König Bruno der Erste, Herrscher über die Steinbrücke! Hrmpf. Danke, Mensch. Ab jetzt darfst du ohne Rätsel unter meiner Brücke stehen.“",
		[{"text": "Majestät!", "id": ""}])


## Where the chest stands: on the bank by the Steinbrücke, opposite the troll's spot.
func chest_pos() -> Vector2:
	for br in world.map.bridges:
		if br["name"] != "Steinbrücke":
			continue
		var c: Vector2 = br["center"]
		var d: Vector2 = br["dir"]
		var side := Vector2(-d.y, d.x)
		for e: Vector2 in [Vector2(-2.6, -1.0), Vector2(-3.2, -1.6), Vector2(-2.6, 1.0), Vector2(2.6, -1.0)]:
			var p := c + side * e.x + d * (float(br["length"]) * 0.5 + e.y)
			if not world.map.is_solid(p) and world.map.water_dist_at(p.x, p.y) > 0.4 and world.map.path_dist_at(p) > 0.6:
				return p
		return c + side * 2.6 + d * (float(br["length"]) * 0.5 - 1.0)
	return Vector2(-8, -8)


func _build_chest() -> void:
	var p := chest_pos()
	chest = MeshInstance3D.new()
	chest.name = "TrollChest"
	chest.mesh = PlaygroundModels.treasure_chest(troll_step() >= 2)
	chest.position = Vector3(p.x, world.map.height_at(p.x, p.y), p.y)
	chest.rotation.y = 0.5
	world.static_root.add_child(chest)
	world.map.add_obstacle_circle(p, 0.45, ParkMap.BLOCK_PEOPLE)
	chest_spot = FunctionSpot.new()
	chest_spot.name = "TrollChestSpot"
	chest_spot.position = chest.position
	chest_spot.radius = 1.6
	chest_spot.users = "human"
	chest_spot.prompt_fn = func(a: Actor) -> String:
		if troll_step() >= 2:
			return ""
		if a.has_item("rusty_key"):
			return "Truhe mit dem rostigen Schlüssel öffnen"
		return "Alte Truhe (verschlossen)"
	chest_spot.available_fn = func(a: Actor) -> bool: return troll_step() < 2 and a.has_item("rusty_key")
	chest_spot.action_fn = _open_chest
	world.static_root.add_child(chest_spot)


## The chest shows whether it was opened (a new game closes it again).
func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 30 != 0 or chest == null:
		return
	var open := troll_step() >= 2
	if chest.has_meta("open") and chest.get_meta("open") == open:
		return
	chest.set_meta("open", open)
	chest.mesh = PlaygroundModels.treasure_chest(open)


func _open_chest(a: Actor) -> void:
	if not a.can_add("troll_crown"):
		GameState.toast.emit("Der Rucksack ist voll!", "warn")
		return
	a.take_item("rusty_key")
	a.add_item("troll_crown")
	GameState.set_stat_max("troll_chest", 2)
	chest.mesh = PlaygroundModels.treasure_chest(true)
	GameState.add_money(1500, "Trollgold")
	Sound.play("success", chest.global_position)
	a.play_anim("cheer", 2.0)
	UI.dialog("Alte Truhe", "Knarrend springt der Deckel auf. Drinnen: ein Haufen Goldmünzen (15,00 €) und eine kleine, verbeulte Krone.\n\nDie Krone gehört wohl Bruno …",
		[{"text": "Ab zu Bruno!", "id": ""}])

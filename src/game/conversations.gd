class_name Conversations
extends RefCounted
## Talking to characters. Minigames and quests register providers that add
## options for specific characters: provider(player: Actor, npc: Actor) -> Array
## of {"text": String, "action": Callable}.

static var providers: Array[Callable] = []

const GREETINGS := {
	"jens": ["Keine Zeit, muss laufen!", "Noch drei Runden!", "Puh … gleich … weiter."],
	"herbert": ["Früher war das hier alles Wiese.", "Die Tauben kennen mich schon.", "Ach, setz dich doch ein bisschen."],
	"peggy": ["Howdy! Weißt du, wo das Entendenkmal ist?", "Everything is so cute here!", "Ich hab schon 400 Fotos gemacht!"],
	"heinz": ["Hot Dogs! Die besten der Stadt!", "Senf ist Gemüse, sag ich immer."],
	"dora": ["Ein Donut am Tag hält den Kummer fern!", "Heute mit Streuseln!"],
	"kemal": ["Na, Chef? Alles gut?", "Pfandflaschen nehm ich an, bring sie her!"],
	"mia": ["Fünf Hunde, zwei Hände. Läuft!", "Bello, NEIN!"],
	"boris": ["Schach? Heute bin ich zu müde. Tic-Tac-Toe vielleicht.", "Ich habe 1983 gegen einen Großmeister remis gespielt."],
	"pierre": ["…", "(zeigt auf eine unsichtbare Wand)", "(verbeugt sich stumm)"],
	"thorsten": ["Ich bin gerade in einem Call!", "Zeit ist Geld!"],
	"gertrud": ["Die Enten freuen sich immer so.", "Kind, du siehst hungrig aus."],
	"lena": ["Weißt du, was ich im Sand gefunden hab?", "Ich kann schon ganz hoch schaukeln!"],
	"sabine": ["Lena, nicht so wild!", "Endlich mal fünf Minuten Ruhe …"],
	"kalle": ["Wer wirft nur die ganzen Flaschen ins Gebüsch?", "Im Herbst hab ich am meisten zu tun."],
	"lukas": ["Balu ist der beste Frisbee-Hund der Welt!", "Lernen? Morgen."],
	"jacques": ["Boule ist Leben, mon ami!", "Wer nicht wirft, hat schon verloren."],
	"harry": ["Pssst … Lust auf ein kleines Spiel?", "Wo ist die Nuss? Wo ist die Nuss?"],
	"ricarda": ["Wünsch dir ein Lied!", "Die Akustik im Pavillon ist toll."],
	"yvonne": ["Atme ein … und aus …", "Namasté!"],
	"anna": ["Ist das nicht ein wunderschöner Tag?", "Ben hat Erdbeeren mitgebracht!"],
	"ben": ["Ich hab Senf auf die Erdbeeren getan. Aus Versehen.", "Psst, ich will Anna überraschen."],
	"nico": ["Die Nacht ist jung!", "Hast du die Eule gehört?"],
	"bruno": ["Hrmpf. Wer da?", "Unter Brücken ist es gemütlicher, als man denkt."],
}


static func register(provider: Callable) -> void:
	providers.append(provider)


static func talk(player: Actor, npc: Actor, controller: PlayerController) -> void:
	npc.face(player.global_position)
	if npc.brain and not npc.controlled:
		npc.play_anim("wave" if npc.is_human() else "idle", 1.0)
	var options: Array = []
	for p in providers:
		var extra: Array = p.call(player, npc)
		options.append_array(extra)
	if player.is_human() and npc.is_human():
		options.append({"text": "Plaudern", "action": func() -> void: _chat(player, npc)})
	elif not npc.is_human():
		options.append({"text": "Streicheln" if npc.species in ["dog", "cat"] else "Anschauen", "action": func() -> void: _pet(player, npc)})
		if npc.species in ["duck", "duckling", "goose"] and player.has_item("bread"):
			options.append({"text": "Brot zuwerfen (%d übrig)" % player.inventory["bread"], "action": func() -> void: throw_bread(player, npc.global_position)})
	if npc.playable:
		options.append({"text": "Zu %s wechseln" % npc.display_name, "action": func() -> void: controller.control(npc)})
	options.append({"text": "Tschüss!", "action": Callable()})
	var line := _greeting(npc)
	var doing := npc.brain.doing() if npc.brain else ""
	var text := line
	if doing != "" and not npc.controlled:
		text = "„%s“\n\n(%s %s.)" % [line, npc.display_name, doing]
	var opts := []
	for i in options.size():
		opts.append({"text": options[i]["text"], "id": str(i)})
	UI.dialog(npc.display_name, text, opts, func(choice: String) -> void:
		if choice == "":
			return
		var o: Dictionary = options[int(choice)]
		var act: Callable = o["action"]
		if act.is_valid():
			act.call())


static func _greeting(npc: Actor) -> String:
	var lines: Array = GREETINGS.get(npc.actor_id, [])
	if lines.is_empty():
		if npc.is_human():
			lines = ["Schöner Tag heute!", "Hallo!", "Kennen wir uns?", "Ich genieße einfach den Park."]
		else:
			lines = {"dog": ["Wuff!", "*wedelt mit dem Schwanz*"], "cat": ["Miau.", "*schnurrt*"], "duck": ["Quak?", "Quak!"],
				"duckling": ["Piep!"], "goose": ["Schnatter!", "Zisch!"], "squirrel": ["*knabbert*", "*schaut neugierig*"],
				"pigeon": ["Gurr.", "Ruckedigu!"], "mouse": ["Fiep!"], "hedgehog": ["*schnüffel*"], "fox": ["*schaut scheu*"]
			}.get(npc.species, ["…"])
	if npc.needs.is_sad():
		return ["Ach, mir geht's heute nicht so gut.", "Seufz …"][randi() % 2] if npc.is_human() else "*schaut traurig*"
	if npc.needs.hunger > 75.0 and npc.is_human():
		return "Ich hab so einen Hunger!"
	return lines[randi() % lines.size()]


static func _chat(player: Actor, npc: Actor) -> void:
	player.play_anim("talk", 2.5)
	npc.play_anim("talk", 2.5)
	npc.say(Activities.Chat.SMALLTALK[randi() % Activities.Chat.SMALLTALK.size()], 3.5)
	player.needs.cheer(5.0)
	npc.needs.cheer(5.0)


static func _pet(player: Actor, npc: Actor) -> void:
	if npc.species in ["dog", "cat"]:
		player.play_anim("squat", 2.0)
		npc.play_anim("roll" if npc.species == "dog" else "sit", 2.0)
		npc.emote("heart", 2)
		player.needs.cheer(8.0)
		npc.needs.cheer(10.0)
		Sound.play("purr" if npc.species == "cat" else "bark", npc.global_position, -6.0)
	else:
		npc.emote("happy")
		player.needs.cheer(3.0)


## Throw a piece of bread towards a point (feeding ducks/pigeons).
static func throw_bread(player: Actor, at: Vector3) -> void:
	if not player.take_item("bread"):
		GameState.toast.emit("Kein Brot mehr. Am Kiosk gibt's welches!", "info")
		return
	player.face(at)
	player.play_anim("throw", 0.8)
	var target := at + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
	var p := Projectile.throw_item(player.world, "bread", player.global_position + Vector3(0, 1.3, 0), target, 0.7, 1.2, 0.1)
	p.landed_at.connect(func(pos: Vector3) -> void: player.world.add_food(pos, "bread", player))
	player.needs.cheer(2.0)

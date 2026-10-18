class_name Conversations
extends RefCounted
## Talking to characters. Minigames and quests register providers that add
## options for specific characters: provider(player: Actor, npc: Actor) -> Array
## of {"text": String, "action": Callable}. What people say when greeted is in Cast ("greet").

const HUNGRY := "Ich hab so einen Hunger!"
const SAD := ["Ach, mir geht's heute nicht so gut.", "Seufz …"]

static var providers: Array[Callable] = []


static func register(provider: Callable) -> void:
	providers.append(provider)


static func talk(player: Actor, npc: Actor, controller: PlayerController) -> void:
	npc.face(player.global_position)
	npc.listen(player)
	if npc.brain and not npc.controlled:
		npc.play_anim("wave" if npc.is_human() else "idle", 1.0)
	for m in Gameplay.modules:
		m.talked(player, npc)
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
	var lines: Array = npc.def.get("greet", [])
	if lines.is_empty():
		if npc.is_human():
			lines = ["Schöner Tag heute!", "Hallo!", "Kennen wir uns?", "Ich genieße einfach den Park."]
		else:
			lines = {"dog": ["Wuff!", "*wedelt mit dem Schwanz*"], "cat": ["Miau.", "*schnurrt*"], "duck": ["Quak?", "Quak!"],
				"duckling": ["Piep!"], "goose": ["Schnatter!", "Zisch!"], "squirrel": ["*knabbert*", "*schaut neugierig*"],
				"pigeon": ["Gurr.", "Ruckedigu!"], "mouse": ["Fiep!"], "hedgehog": ["*schnüffel*"], "fox": ["*schaut scheu*"]
			}.get(npc.species, ["…"])
	if npc.needs.is_sad():
		return SAD[randi() % SAD.size()] if npc.is_human() else "*schaut traurig*"
	if npc.needs.hunger > 75.0 and npc.is_human():
		return HUNGRY
	return lines[randi() % lines.size()]


static func _chat(player: Actor, npc: Actor) -> void:
	player.play_anim("talk", 2.5)
	npc.play_anim("talk", 2.5)
	var talk := Cast.smalltalk(npc.def)
	npc.say(talk[randi() % talk.size()], 4.5)
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

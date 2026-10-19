class_name DwarfQuests
extends QuestModule
## The dwarves' jobs (doc/nordwald.md). Rewards are better tools that work faster.
## State per quest: the stage "dq_<id>" (OPEN, ACTIVE, DONE).
## Also gives the campfire its bonus: sitting next to it rests faster and cheers up.

const QUESTS := [
	{"id": "props", "npc": "grimbart", "title": "Grubenholz",
		"ask": "„Glück auf! Unsere Stollen brauchen neue Stützen. Bring mir 6 Holzscheite und 6 Steine, dann bekommst du eine richtige Eisenhacke.“",
		"needs": {"log": 6, "stone": 6}, "reward": {"iron_pickaxe": 1}, "money": 500,
		"thanks": "„Gutes Holz, gute Steine. Hier, deine Eisenhacke. Damit findest du auch öfter Erz.“"},
	{"id": "hunger", "npc": "brakka", "title": "Zwergenhunger",
		"ask": "„Die Jungs haben Hunger, und ich hab keine Zeit zum Kochen! Bring mir eine Pilzpfanne und ein Glas Beerenmarmelade. Am Lagerfeuer im Holzfällerlager kannst du kochen.“",
		"needs": {"mushroom_pan": 1, "jam": 1}, "reward": {"honey": 2}, "money": 800,
		"thanks": "„Mmmh! Dafür verrate ich dir mein Geheimrezept: Zwergeneintopf. Den kannst du jetzt am Lagerfeuer kochen.“"},
	{"id": "sparkle", "npc": "nori", "title": "Funkelsteine",
		"ask": "„Ich sammle Edelsteine. Drei Stück, und ich schmiede dir eine Zwergenaxt. Die fällt einen Baum mit zwei Hieben!“",
		"needs": {"gem": 3}, "reward": {"dwarf_axe": 1}, "money": 0,
		"thanks": "„Wunderschön! Hör nur, wie sie klingen … Hier, deine Zwergenaxt.“"},
	{"id": "master", "npc": "grimbart", "title": "Meisterprobe", "after": "props",
		"ask": "„Du hast dich bewährt. Für die Meisterprobe brauche ich 5 Erzbrocken und 4 Steinplatten. Dann gehört die Zwergenhacke dir.“",
		"needs": {"ore": 5, "slab": 4}, "reward": {"dwarf_pickaxe": 1}, "money": 1000,
		"thanks": "„Meisterlich! Die Zwergenhacke findet Edelsteine, wo andere nur Kies sehen.“"},
	{"id": "nightshift", "npc": "thrain", "title": "Nachtschicht",
		"ask": "„Kannst du Weichen stellen? Schaff beim Stellwerk 15 Loren richtig, dann bekommst du einen Zwergenrucksack mit sechs Plätzen mehr.“",
		"score": 15, "reward": {"big_bag": 1}, "money": 0,
		"thanks": "„Na also! Du bist ein echter Weichensteller. Hier, dein Zwergenrucksack.“"},
]

const CAMPFIRE := Vector3(-40, 0, -159)



func quest_givers() -> Array:
	return ["grimbart", "brakka", "nori", "thrain"]


static func state(id: String) -> int:
	return GameState.stage("dq_" + id)


## The dwarf quest a dwarf has to offer or expects back right now (or {}).
static func current(npc_id: String) -> Dictionary:
	for q: Dictionary in QUESTS:
		if q["npc"] != npc_id or state(q["id"]) == DONE:
			continue
		if q.has("after") and state(q["after"]) != DONE:
			continue
		return q
	return {}


static func deliverable(player: Actor, q: Dictionary) -> bool:
	if q.has("score"):
		return GameState.stat("switch_best") >= int(q["score"])
	for item: String in q["needs"]:
		if int(player.inventory.get(item, 0)) < int(q["needs"][item]):
			return false
	return true


func options(player: Actor, npc: Actor) -> Array:
	var out := []
	if not player.is_human():
		return out
	var q := current(npc.actor_id)
	if q.is_empty():
		return out
	match state(q["id"]):
		OPEN:
			out.append({"quest": true, "text": "Hast du Arbeit für mich?", "action": func() -> void: _offer(player, npc, q)})
		ACTIVE:
			if deliverable(player, q):
				out.append({"quest": true, "text": "Auftrag abgeben: %s" % q["title"], "action": func() -> void: _deliver(player, npc, q)})
			else:
				out.append({"text": "Was brauchtest du nochmal?", "action": func() -> void:
					UI.dialog(npc.display_name, q["ask"] + "\n\n" + progress(player, q), [{"text": "Bin dran!", "id": ""}])})
	return out


func _offer(player: Actor, npc: Actor, q: Dictionary) -> void:
	UI.dialog(npc.display_name, q["ask"], [{"text": "Mach ich!", "id": "y"}, {"text": "Vielleicht später.", "id": ""}],
		func(c: String) -> void:
			if c == "y":
				GameState.set_stage("dq_" + q["id"], ACTIVE)
				npc.say("Glück auf!", 2.0)
				GameState.toast.emit("Neuer Auftrag: %s (Notizbuch: J)" % q["title"], "info"))


func _deliver(player: Actor, npc: Actor, q: Dictionary) -> void:
	if not deliverable(player, q):
		return
	var needs: Dictionary = q.get("needs", {})
	for item: String in needs:
		player.take_item(item, int(needs[item]))
	var reward: Dictionary = q["reward"]
	for item: String in reward:
		var n := mini(player.room(item), int(reward[item]))
		player.add_item(item, n)
		if n < int(reward[item]):
			GameState.storage[item] = int(GameState.storage.get(item, 0)) + int(reward[item]) - n
			GameState.toast.emit("Kein Platz – %s liegt in der Lagerkiste." % Items.name_of(item), "info")
	if int(q["money"]) > 0:
		GameState.add_money(int(q["money"]), q["title"])
	GameState.set_stage("dq_" + q["id"], DONE)
	GameState.add_stat("dwarf_quests")
	Sound.play("achievement")
	npc.play_anim("cheer", 2.0)
	UI.dialog(npc.display_name, q["thanks"], [{"text": "Glück auf!", "id": ""}])


static func progress(player: Actor, q: Dictionary) -> String:
	if q.has("score"):
		return "Bester Lauf am Stellwerk: %d von %d Loren." % [GameState.stat("switch_best"), q["score"]]
	var parts := []
	for item: String in q["needs"]:
		parts.append("%s %d/%d" % [Items.name_of(item), mini(int(player.inventory.get(item, 0)), int(q["needs"][item])), int(q["needs"][item])])
	return "Dabei: " + ", ".join(parts)


func tasks() -> Array:
	var out := []
	var player: Actor = game.player.actor if game.player else null
	for q: Dictionary in QUESTS:
		var st := state(q["id"])
		var who := _name_of(q["npc"])
		if st == DONE:
			out.append({"title": "Zwerge: %s" % q["title"], "desc": "Erledigt für %s." % who, "done": true, "area": "forest"})
		elif st == ACTIVE:
			out.append({"title": "Zwerge: %s" % q["title"], "desc": "%s – %s" % [who, progress(player, q) if player else ""], "active": true, "area": "forest"})
		elif not q.has("after") or state(q["after"]) == DONE:
			out.append({"title": "Zwerge: %s" % q["title"], "desc": "%s im Nordwald hat Arbeit zu vergeben." % who, "done": false, "area": "forest"})
	return out


func _name_of(id: String) -> String:
	var a := world.find_actor(id)
	return a.display_name if a else id


# --- Campfire ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	var minutes := delta * Clock.MINUTES_PER_SECOND * Clock.time_scale
	for a in world.actors_near(CAMPFIRE, 4.5):
		if a.seat:
			# On top of the normal rest on a seat: warm and cosy.
			a.needs.fatigue = clampf(a.needs.fatigue - minutes / 60.0 * 30.0, 0.0, 100.0)
			a.needs.cheer(minutes / 60.0 * 10.0)

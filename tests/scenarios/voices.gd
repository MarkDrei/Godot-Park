extends Scenario
## Recorded voice lines (doc/voices.md): the Stadtpark's adults speak their dialog lines and
## speech bubbles from the clips in assets/voice, anonymous people with a crowd voice; closing
## the dialog stops them, the "Stimmen" slider mutes them, a bubble out of hearing isn't shown.


func _talk_to(id: String) -> Actor:
	var npc := present(id)
	npc.brain.suspend()
	await next_to(id)
	clear_around(npc.global_position, 4.0, [id])
	await press("interact")
	await wait(0.2)
	return npc


func test_kemal_speaks_at_the_kiosk() -> void:
	Voice.last_played = ""
	await open_menu("kiosk")
	check(Voice.last_played.begins_with("res://assets/voice/kemal/"), "Kemal's call is spoken (got '%s')" % Voice.last_played)
	var ads: Array = Shop.SHOPS["kiosk"]["ads"]
	var spoken := ads.filter(func(ad: String) -> bool: return Voice.path("kemal", ad) == Voice.last_played)
	check(spoken.size() == 1 and spoken[0] in dialog_text(), "the clip of the line in the dialog (%s)" % dialog_text())
	check(await choose("Nichts, danke."), "close the menu")
	check(not Voice.is_speaking(), "closing the dialog stops the voice")


func test_voice_slider_mutes() -> void:
	var before: float = GameState.settings.get("voice", 1.0)
	GameState.settings["voice"] = 0.0
	Voice.last_played = ""
	await open_menu("kiosk")
	check_eq(Voice.last_played, "", "no voice with the slider at 0")
	await choose("Nichts, danke.")
	GameState.settings["voice"] = before


func test_speech_bubble_plays_at_the_speaker() -> void:
	var kemal := hold_npc("kemal")
	await put_player(kemal.global_position + Vector3(3, 0, 0), kemal.global_position)
	Voice.last_played = ""
	kemal.say("Na, Chef? Alles gut?")
	check_eq(Voice.last_played, Voice.path("kemal", "Na, Chef? Alles gut?"), "the bubble line is spoken")
	check(kemal.get_children().any(func(c: Node) -> bool: return c is AudioStreamPlayer3D), "from where Kemal stands")
	Voice.last_played = ""
	kemal.say("Das sagt Kemal nie.")
	check_eq(Voice.last_played, "", "a line without a clip stays silent")


## Anonymous people speak with a crowd voice (VoiceLines.crowd); a named person has one fixed
## line of each common set (a horn, applause) and answers a chat with their own small talk.
func test_crowd_and_common_lines_are_spoken() -> void:
	var v: Actor = null
	for a in world.actors:
		if a.actor_id.begins_with("visitor_") and not a.inside:
			v = a
			break
	check(v != null and v.voice() in VoiceLines.CROWD_ADULTS, "a visitor has a crowd voice (%s)" % (v.voice() if v else "none"))
	if v == null:
		return
	hold_npc(v.actor_id)
	await put_player(v.global_position + Vector3(3, 0, 0), v.global_position)
	Voice.last_played = ""
	v.say(Activities.Chat.SMALLTALK[0])
	check_eq(Voice.last_played, Voice.path(v.voice(), Activities.Chat.SMALLTALK[0]), "the visitor's small talk is spoken")
	var kemal := hold_npc("kemal")
	await put_player(kemal.global_position + Vector3(3, 0, 0), kemal.global_position)
	var cheer := VoiceLines.pick(kemal, Activities.Watch.CHEERS)
	check(cheer == VoiceLines.pick(kemal, Activities.Watch.CHEERS) and cheer == VoiceLines.pick(kemal, Activities.Watch.CHEERS), "Kemal always cheers the same")
	for line: String in [cheer, VoiceLines.pick(kemal, VoiceLines.HONKED), Shop.HERE_YOU_ARE]:
		await wait(0.1)
		Voice.last_played = ""
		kemal.say(line)
		check_eq(Voice.last_played, Voice.path("kemal", line), "Kemal says „%s“" % line)
	check(VoiceLines.reply(kemal) in Cast.smalltalk(kemal.def), "Kemal answers a chat with his own small talk")
	# A woman's name, look and voice go together (the name lists once started with the wrong sex).
	var rng := RandomNumberGenerator.new()
	for i in 12:
		for d: Dictionary in [Cast.visitor(i, rng), Cast.city_person(i, rng), Cast.fair_visitor(i, rng), Cast.burg_visitor(i, rng)]:
			var woman := (d["name"] as String).begins_with("Besucherin") or (d["name"] as String).begins_with("Passantin")
			check(woman == (d["voice"] as String).begins_with("volk_frau"), "%s speaks with %s" % [d["name"], d["voice"]])


## A bubble out of hearing (Voice.HEAR from the camera) is neither shown nor spoken: it looked
## like a missing voice.
func test_no_bubble_out_of_hearing() -> void:
	var kemal := hold_npc("kemal")
	await put_player(kemal.global_position + Vector3(Voice.HEAR + 15.0, 0, 0), kemal.global_position)
	await wait_until(func() -> bool: return not kemal.rig.is_speaking(), 5.0)   # the last test's bubble
	Voice.last_played = ""
	kemal.say("Na, Chef? Alles gut?")
	check(not kemal.rig.is_speaking() and Voice.last_played == "", "no bubble, no voice far away")
	check_eq(kemal.last_said, "Na, Chef? Alles gut?", "but it was said")
	await put_player(kemal.global_position + Vector3(8, 0, 0), kemal.global_position)
	await wait(0.5)
	kemal.say("Na, Chef? Alles gut?")
	check(kemal.rig.is_speaking() and Voice.last_played == Voice.path("kemal", "Na, Chef? Alles gut?"), "bubble and voice nearby")


## Bruno at night: the riddle dialog speaks the challenge, then the riddle itself.
func test_bruno_speaks_the_riddle() -> void:
	await reset("jens", 23.0)
	await _talk_to("bruno")
	check(Voice.last_played.begins_with("res://assets/voice/bruno/"), "Bruno's greeting is spoken (got '%s')" % Voice.last_played)
	check(await choose("Ein Rätsel lösen"), "Bruno offers a riddle")
	await wait(0.2)
	check_eq(Voice.last_played, Voice.path("bruno", "Wer unter meiner Brücke stehen will, muss mein Rätsel lösen!"), "the challenge is spoken")
	check(Voice.is_speaking(), "the riddle comes next")
	var riddle := ""
	for r: Dictionary in Quests.RIDDLES:
		if dialog_text().contains(r["q"]):
			riddle = r["q"]
	check(riddle != "" and Voice.has_clip("bruno", riddle), "the riddle has a clip")


## Peggy's verdict after the photo game is spoken by Peggy (the minigame's host), not the title.
func test_minigame_host_speaks_the_result() -> void:
	Voice.last_played = ""
	UI.dialog("Foto für Peggy", "Peggy schaut sich die Fotos an.\n„Wonderful, danke schön!“", [{"text": "Super!", "id": ""}])
	Voice.dialog("Foto für Peggy", "Peggy schaut sich die Fotos an.\n„Wonderful, danke schön!“", "peggy")
	check_eq(Voice.last_played, Voice.path("peggy", "Wonderful, danke schön!"), "Peggy's words")
	UI.close_dialog("")


## "Plaudern": everybody answers with their own small talk (Cast "smalltalk"), spoken if voiced.
func test_chat_is_their_own_small_talk() -> void:
	var herbert := await _talk_to("herbert")
	check(await choose("Plaudern"), "Plaudern offered")
	await wait(0.2)
	check(herbert.last_said in Cast.smalltalk(herbert.def), "Herbert's own line (got '%s')" % herbert.last_said)
	check(herbert.last_said not in Activities.Chat.SMALLTALK, "not the common small talk")
	if Voice.has_clip("herbert", herbert.last_said):
		check_eq(Voice.last_played, Voice.path("herbert", herbert.last_said), "spoken by Herbert")


## Robin asks for the apple: both parts of the dialog (the wish, where to find it) are spoken.
func test_robin_speaks_the_wish() -> void:
	GameState.set_stage("pg_step", 0)
	await _talk_to("robin")
	check(UI.is_dialog_open(), "Robin's dialog opens")
	check(Voice.last_played.begins_with("res://assets/voice/robin/"), "Robin's greeting is spoken (got '%s')" % Voice.last_played)
	check(await choose("Was ist los"), "ask Robin (%s)" % str(dialog_options()))
	await wait(0.2)
	check_eq(Voice.last_played, Voice.path("robin", PlaygroundQuests.LINES["robin"][0]), "the wish is spoken")
	check(Voice.is_speaking(), "the hint comes next")

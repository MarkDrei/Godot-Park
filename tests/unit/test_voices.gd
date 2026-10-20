extends TestCase
## Recorded voice lines (doc/voices.md): tools/voices/voices.json, the clips in assets/voice and
## the lines the game shows stay in step.

const CONFIG := "res://tools/voices/voices.json"


func _config() -> Dictionary:
	var f := FileAccess.open(CONFIG, FileAccess.READ)
	check(f != null, "voices.json readable")
	return JSON.parse_string(f.get_as_text()) if f else {}


func test_every_line_of_a_voice_has_its_clip() -> void:
	var cfg := _config()
	for speaker: String in cfg.get("lines", {}):
		if str(cfg["voices"][speaker].get("voice_id", "")) == "":
			continue
		for line: Dictionary in cfg["lines"][speaker]:
			if not line.get("pending", false):   # left for next month's credits
				check(Voice.has_clip(speaker, line["text"]), "%s has a clip for „%s“ (scripts/voices.py generate)" % [speaker, line["text"]])


## Every line a voiced speaker says in the game (VoiceLines) is in voices.json: a changed or new
## text needs `scripts/voices.py sync`.
func test_voiced_speakers_cover_their_game_lines() -> void:
	var cfg := _config()
	for speaker: String in cfg.get("lines", {}):
		var have := {}
		for line: Dictionary in cfg["lines"][speaker]:
			have[line["text"]] = true
		for text in VoiceLines.of(speaker):
			check(have.has(text), "voices.json has %s's line „%s“ (scripts/voices.py sync)" % [speaker, text])


## Every line in voices.json still appears in the game's code or in VoiceLines (filled-in lines:
## a taxi passenger's street, Mia's dogs; quest lines are not collected by VoiceLines): a changed
## text leaves a clip nobody plays.
func test_voiced_lines_are_still_in_the_game() -> void:
	var source := _source("res://src").replace("\\n", "\n")
	var cfg := _config()
	for speaker: String in cfg.get("lines", {}):
		var game := VoiceLines.of(speaker)
		for line: Dictionary in cfg["lines"][speaker]:
			check(line["text"] in source or line["text"] in game, "%s's line „%s“ is still in src/ (else fix or remove it in voices.json)" % [speaker, line["text"]])


func _source(dir: String) -> String:
	var out := ""
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out += FileAccess.get_file_as_string(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out += _source(dir.path_join(d))
	return out


func test_dialog_parts() -> void:
	check_eq(VoiceLines.parts("„Eins.“\n\n„Zwei!“"), ["Eins.", "Zwei!"] as Array[String], "quoted parts")
	check_eq(VoiceLines.parts("„Hallo“\n\n(Robin spielt gerade.)"), ["Hallo"] as Array[String], "narration is not spoken")
	check_eq(VoiceLines.parts("Na, Chef?"), ["Na, Chef?"] as Array[String], "unquoted text as a whole")
	check_eq(VoiceLines.parts("Spiel abgebrochen.", true), [] as Array[String], "a minigame's narration is not spoken")
	check_eq(Voice.path("kemal", "„Na, Chef? Alles gut?“"), Voice.path("kemal", "Na, Chef? Alles gut?"), "quotes do not change the key")
	check(Voice.speaker_of("Kiosk-Kemal") == "kemal" and Voice.speaker_of("Alte Truhe") == "", "speaker by display name")
	check(not VoiceLines.spoken("(verbeugt sich stumm)") and not VoiceLines.spoken("…") and VoiceLines.spoken("Hrmpf."), "stage directions are not spoken")

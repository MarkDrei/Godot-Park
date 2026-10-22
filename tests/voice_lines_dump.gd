extends Node
## Prints VoiceLines.of(id) for the ids after "--" as JSON (used by scripts/voices.py sync).
## A line "PEOPLE <area> <id> …" lists the adults of each area. Run as a scene
## (tests/voice_lines_dump.tscn), not with -s: VoiceLines reaches scripts that need the
## autoloads (GameState, UI …), and without them those fail to compile and lines go missing.


func _ready() -> void:
	var ids := OS.get_cmdline_user_args()
	var out := {}
	for id in ids:
		out[id] = VoiceLines.of(id)
	print("VOICE_LINES " + JSON.stringify(out))
	for area: String in ["park", "forest", "city", "fair", "burg", "coast"]:
		var list: Array = {"park": Cast.PEOPLE, "forest": Cast.FOREST, "city": Cast.CITY, "fair": Cast.FAIR, "burg": Cast.BURG, "coast": Cast.COAST}[area]
		var adults := []
		for d: Dictionary in list:
			if d.get("role", "") != "kid":
				adults.append(d["id"])
		print("PEOPLE %s %s" % [area, " ".join(adults)])
	get_tree().quit()

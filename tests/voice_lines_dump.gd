extends SceneTree
## Prints VoiceLines.of(id) for the ids after "--" as JSON (used by scripts/voices.py sync).
## A line "PEOPLE <area> <id> …" lists the adults of each area.


func _init() -> void:
	var ids := OS.get_cmdline_user_args()
	var out := {}
	for id in ids:
		out[id] = VoiceLines.of(id)
	print("VOICE_LINES " + JSON.stringify(out))
	for area: String in ["park", "forest", "city", "fair", "burg"]:
		var list: Array = {"park": Cast.PEOPLE, "forest": Cast.FOREST, "city": Cast.CITY, "fair": Cast.FAIR, "burg": Cast.BURG}[area]
		var adults := []
		for d: Dictionary in list:
			if d.get("role", "") != "kid":
				adults.append(d["id"])
		print("PEOPLE %s %s" % [area, " ".join(adults)])
	quit()

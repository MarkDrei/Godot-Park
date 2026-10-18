class_name VoiceLines
extends RefCounted
## Everything a person says out loud that can get a recorded voice (doc/voices.md): greetings,
## work lines, small talk, the shop's calls, quest lines and the hungry/sad lines everybody has. Stage
## directions ("(verbeugt sich)", "*schnurrt*", "…") are not spoken. scripts/voices.py sync
## takes the lines from here into tools/voices/voices.json; tests/unit/test_voices.gd checks
## that every voiced person's lines are there.


static func of(id: String) -> Array[String]:
	var said: Array = []
	var d := person(id)
	said.append_array(d.get("greet", []))
	said.append_array(d.get("work", {}).get("lines", []))
	said.append_array(d.get("smalltalk", []))
	for shop: String in Shop.SHOPS:
		if Cast.vendor_of(shop) == id:
			said.append_array(Shop.SHOPS[shop].get("ads", []))
	if id in PlaygroundQuests.KIDS:
		said.append_array(PlaygroundQuests.LINES[id])
		said.append(PlaygroundQuests.SANDBOX_HINT)
	said.append(Conversations.HUNGRY)
	said.append_array(Conversations.SAD)
	var out: Array[String] = []
	for text: String in said:
		for part in parts(text):
			var p := part.strip_edges()
			if spoken(p) and p not in out:
				out.append(p)
	return out


## The spoken parts of a dialog text: the quoted ones, or the whole text when nothing is quoted
## (a narrator's "(Bruno setzt sich …)" stays silent then too, it has no clip) unless
## `quoted_only`.
static func parts(text: String, quoted_only := false) -> Array[String]:
	var out: Array[String] = []
	var i := text.find("„")
	while i >= 0:
		var j := text.find("“", i + 1)
		if j < 0:
			break
		out.append(text.substr(i + 1, j - i - 1))
		i = text.find("„", j + 1)
	if out.is_empty() and not quoted_only:
		out.append(text)
	return out


## Not a stage direction or a bare ellipsis.
static func spoken(text: String) -> bool:
	if text.begins_with("(") or text.begins_with("*"):
		return false
	for c in text:
		if c.to_lower() != c.to_upper():
			return true
	return false


static func person(id: String) -> Dictionary:
	for list: Array in [Cast.PEOPLE, Cast.FOREST, Cast.CITY, Cast.FAIR]:
		for d: Dictionary in list:
			if d["id"] == id:
				return d
	return {}

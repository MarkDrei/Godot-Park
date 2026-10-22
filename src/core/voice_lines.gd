class_name VoiceLines
extends RefCounted
## Everything a person says out loud that can get a recorded voice (doc/voices.md): greetings,
## work lines, small talk, the shop's calls, quest lines and the hungry/sad lines everybody has. Stage
## directions ("(verbeugt sich)", "*schnurrt*", "…") are not spoken. scripts/voices.py sync
## takes the lines from here into tools/voices/voices.json; tests/unit/test_voices.gd checks
## that every voiced person's lines are there.
##
## Anonymous people (visitors, passers-by, taxi passengers, children) speak with one of the
## crowd voices (`crowd`, Cast "voice"), which have all the common lines. A named person has
## only one of each set of common reactions (`pick`), so each person costs a few clips.

const CROWD_ADULTS := ["volk_frau_jung", "volk_frau_mittel", "volk_frau_alt", "volk_mann_jung", "volk_mann_mittel", "volk_mann_alt"]
const CROWD_KIDS := ["volk_maedchen", "volk_junge"]
## Waving back at the player, a horn nearby, a vendor serving somebody, a dog walker's treat,
## Mia handing a dog over and getting it back.
const WAVE_BACK := ["Hallo!", "Moin!", "Servus!", "Grüß Gott!", "Hi!"]
const HONKED := ["Jaja, schon gut!", "Huch!", "Nicht so laut!", "Hallo auch!"]
const SERVED := ["Bitte schön!", "Guten Appetit!", "Lassen Sie's sich schmecken!", "Danke, beehren Sie uns wieder!"]
const TREAT := "Hier, ein Leckerli!"
const TAKE_CARE := "Pass gut auf %s auf!"
const DOG_BACK := "Danke! %s sieht glücklich aus."


## The crowd voice of an anonymous adult (Cast.visitor: `age` 0..1, grey hair above 0.8).
static func crowd(female: bool, age: float) -> String:
	return "volk_%s_%s" % ["frau" if female else "mann", "alt" if age > 0.8 else ("jung" if age < 0.4 else "mittel")]


## One of `lines` for `a` to say: the crowd says any, a named person always the same one.
static func pick(a: Actor, lines: Array) -> String:
	return lines[randi() % lines.size()] if a.def.has("voice") else one_of(a.actor_id, lines)


static func one_of(id: String, lines: Array) -> String:
	return lines[absi(id.hash()) % lines.size()]


## The answer in a chat: the crowd's "Ach was!", a named person's own small talk.
static func reply(a: Actor) -> String:
	var lines: Array = Activities.Chat.REPLIES if a.def.has("voice") else Cast.smalltalk(a.def)
	return lines[randi() % lines.size()]


## Waving back at the player: a named person with one of their greetings.
static func wave_back(a: Actor) -> String:
	var greet: Array = a.def.get("greet", [])
	if a.def.has("voice") or greet.is_empty():
		return pick(a, WAVE_BACK)
	return greet[randi() % greet.size()]


static func of(id: String) -> Array[String]:
	if id in CROWD_ADULTS or id in CROWD_KIDS:
		return _clean(_crowd_lines(id in CROWD_KIDS))
	var said: Array = []
	var d := person(id)
	if d.is_empty():
		return [] as Array[String]
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
	said.append_array(_reactions(id, d))
	return _clean(said)


## The common lines a named person says in speech bubbles, by what they do.
static func _reactions(id: String, d: Dictionary) -> Array:
	var said := [one_of(id, Activities.Watch.CHEERS), one_of(id, HONKED)]
	if d.get("greet", []).is_empty():
		said.append(one_of(id, WAVE_BACK))
	var likes: Dictionary = d.get("likes", {})
	if likes.has("phone"):
		said.append_array(Activities.Phone.LINES)
	if likes.has("photo"):
		said.append_array(Activities.Photo.LINES)
	if likes.has("lost"):
		said.append_array(Activities.Lost.LINES)
	if likes.has("dance"):
		said.append_array(HumanBrain.DANCE_LINES)
	match d.get("work", {}).get("type", ""):
		"garden":
			said.append_array(Activities.Garden.LINES)
		"dogwalk":
			said.append_array(Activities.DogWalk.LINES)
			said.append(TREAT)
	if id == "mia":   # the dog walking quest (Quests): her dogs by name
		for a: Dictionary in Cast.ANIMALS:
			if a["id"] in d.get("dogs", []):
				said.append_array([TAKE_CARE % a["name"], DOG_BACK % a["name"]])
	for shop: String in Shop.SHOPS:
		if Cast.vendor_of(shop) == id:
			said.append_array([one_of(id, SERVED), Shop.HERE_YOU_ARE, Shop.THANK_YOU, Shop.BEG_AGAIN, Shop.BEG_YES, Shop.BEG_NO])
			if FairStories.takeaway_for(shop) != "":
				said.append(Shop.WRAPPED)
			if shop == "dwarf_office":
				said.append(Shop.GNOME)
	if id == "petra":
		said.append_array(Traffic.RED_LINES)
	if id == "lothar":
		for lot: Array in FairTrade.LOTS:
			said.append(lot[2])
	return said


## Everything the crowd says: small talk and its replies, cheering, waving, a horn, the tourists'
## lines, the almond stand's customers; the adults are the taxi's passengers, the children
## queue at the ice cream van.
static func _crowd_lines(kid: bool) -> Array:
	var said: Array = []
	said.append_array(Activities.Chat.REPLIES)
	said.append_array(Activities.Watch.CHEERS)
	said.append_array(WAVE_BACK)
	said.append_array(HONKED)
	said.append_array(AlmondShift.RIGHT_LINES)
	said.append_array(AlmondShift.WRONG_LINES)
	if kid:
		for f: String in IceVanJob.FLAVOURS:
			said.append_array([IceVanJob.ORDER % f, IceVanJob.WRONG % f])
		said.append_array(IceVanJob.HAPPY)
		return said
	said.append_array(Activities.Chat.SMALLTALK)
	said.append_array(Activities.Photo.LINES)
	said.append_array(Activities.Lost.LINES)
	said.append_array(TaxiJob.CHAT)
	said.append_array(TaxiJob.OUCH)
	said.append_array(TaxiJob.THANKS)
	said.append(TaxiJob.NO_TIP_THANKS)
	for s: Dictionary in CityLayout.X_STREETS + CityLayout.Z_STREETS:
		said.append(TaxiJob.to_street(s["name"]))
	return said


static func _clean(said: Array) -> Array[String]:
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
	for list: Array in [Cast.PEOPLE, Cast.FOREST, Cast.CITY, Cast.FAIR, Cast.BURG, Cast.COAST]:
		for d: Dictionary in list:
			if d["id"] == id:
				return d
	return {}

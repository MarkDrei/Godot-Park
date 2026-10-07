extends TestCase
## Character definitions are complete and consistent.


func test_people_definitions() -> void:
	var ids := {}
	for d: Dictionary in Cast.PEOPLE:
		check(not ids.has(d["id"]), "unique id %s" % d["id"])
		ids[d["id"]] = true
		check(d.has("name") and d.has("desc") and d.has("hours") and d.has("look"), "%s complete" % d["id"])
		for h: Array in d["hours"]:
			check(h[0] < h[1], "%s hours ordered" % d["id"])
		if d.has("dogs"):
			for dog: String in d["dogs"]:
				var found := false
				for a: Dictionary in Cast.ANIMALS:
					if a["id"] == dog:
						found = true
						check_eq(a.get("owner", ""), d["id"], "%s belongs to %s" % [dog, d["id"]])
				check(found, "dog %s exists" % dog)


func test_animals_definitions() -> void:
	for a: Dictionary in Cast.ANIMALS:
		check(a.has("species") and a.has("preset") and a.has("name"), "%s complete" % a["id"])
		if a["species"] in ["dog", "cat", "mouse", "squirrel", "hedgehog", "fox"]:
			check(QuadrupedRig.PRESETS.has(a["preset"]), "quadruped preset %s" % a["preset"])
		else:
			check(BirdRig.PRESETS.has(a["preset"]), "bird preset %s" % a["preset"])
		if a.has("mother"):
			var found := false
			for m: Dictionary in Cast.ANIMALS:
				found = found or m["id"] == a["mother"]
			check(found, "%s has a mother" % a["id"])


func test_visitors_are_random_but_valid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 12:
		var v := Cast.visitor(i, rng)
		check((v["name"] as String).begins_with("Besucher"), "visitor name")
		check(v["hours"][0][1] <= 24, "visitor leaves before midnight")


func test_rigs_build() -> void:
	for d: Dictionary in Cast.PEOPLE.slice(0, 4):
		var r := HumanRig.new()
		r.build(d["look"])
		check_eq(r.skel.get_bone_count(), 19, "human skeleton bones")
		r.free()
	for p: String in QuadrupedRig.PRESETS:
		var q := QuadrupedRig.new()
		q.build(p)
		check(q.skel.get_bone_count() >= 10, "%s skeleton" % p)
		q.free()
	for p: String in BirdRig.PRESETS:
		var b := BirdRig.new()
		b.build(p)
		check(b.skel.get_bone_count() >= 8, "%s skeleton" % p)
		b.free()

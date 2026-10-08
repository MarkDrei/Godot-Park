extends TestCase
## Item registry (Items) against the food effects (Food) and the bag arithmetic.


func test_food_items_have_effects() -> void:
	for id: String in Items.DEFS:
		if Items.category(id) == "food" and id != "fish":
			check(Food.ITEMS.has(id) and Food.is_edible(id), "%s has an effect in Food.ITEMS" % id)
	for id: String in Food.FOREST:
		check(Items.DEFS.has(id), "%s is a bag item" % id)


func test_every_item_has_name_and_stack() -> void:
	for id: String in Items.DEFS:
		var d: Dictionary = Items.DEFS[id]
		check(d.get("name", "") != "" and int(d.get("stack", 0)) > 0, "%s: name and stack" % id)
		check(Items.CATEGORIES.has(d.get("cat", "")), "%s: known category" % id)
		if d.get("cat") == "tool":
			check(d.has("tool") and d.has("tier"), "%s: tool kind and tier" % id)


func test_slots() -> void:
	check_eq(Items.slots_for("log", 20), 1, "20 logs fill one slot")
	check_eq(Items.slots_for("log", 21), 2, "21 logs need two")
	check_eq(Items.slots_for("stone_axe", 2), 2, "tools do not stack")
	check_eq(Items.slots_used({"log": 21, "gem": 1}), 3, "slots of a bag")
	check_eq(Items.tool_tier({"stone_axe": 1, "iron_axe": 1}, "axe"), 2, "best axe counts")
	check_eq(Items.tool_tier({"stone_axe": 1}, "pickaxe"), 0, "no pickaxe")

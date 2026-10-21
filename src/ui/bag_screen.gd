class_name BagScreen
extends Control
## The controlled character's bag ("Rucksack"): one tile per slot, details of the selected
## item, eat and throw away; below the bag the herb pouch (Items.POUCH) with its own green slots,
## as many as its herbs and berries need; with nothing selected the character's traits (pace, hunger,
## fatigue, mood, swimming; traits()). With the storage chest open, both side by side: tapping a tile
## moves that one slot (one stack) across.

const TILE := 96
## The herb pouch's slots are tinted green.
const POUCH_COLOR := Color("6fbf5a")

var game: Game
var actor: Actor
var chest := false                     # storage chest open next to the bag
var selected := ""
var title: Label
var capacity: Label
var bag_grid: GridContainer
var pouch_title: Label
var pouch_grid: GridContainer
var chest_box: VBoxContainer
var chest_grid: GridContainer
var detail: VBoxContainer
var detail_name: Label
var detail_text: Label
var detail_buttons: HBoxContainer
var stats: VBoxContainer
var stats_title: Label
var stats_desc: Label
var stats_grid: GridContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func build(g: Game) -> void:
	game = g
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.1, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 40
	v.offset_right = -40
	v.offset_top = 24
	v.offset_bottom = -24
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	title = UiTheme.label("Rucksack", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	capacity = UiTheme.label("", 18, Color(UiTheme.CREAM, 0.8))
	capacity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(capacity)
	var close := UiTheme.button_node("Schließen", func() -> void: UI.close_screens())
	top.add_child(close)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 30)
	v.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(scroll)
	bag_grid = GridContainer.new()
	bag_grid.add_theme_constant_override("h_separation", 8)
	bag_grid.add_theme_constant_override("v_separation", 8)
	var bag_col := VBoxContainer.new()
	bag_col.add_theme_constant_override("separation", 10)
	scroll.add_child(bag_col)
	bag_col.add_child(bag_grid)
	pouch_title = UiTheme.label("", 18, POUCH_COLOR.lightened(0.3))
	bag_col.add_child(pouch_title)
	pouch_grid = GridContainer.new()
	pouch_grid.name = "Pouch"
	pouch_grid.add_theme_constant_override("h_separation", 8)
	pouch_grid.add_theme_constant_override("v_separation", 8)
	bag_col.add_child(pouch_grid)
	# Right: item details, or the chest.
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 10)
	row.add_child(detail)
	detail_name = UiTheme.label("", 26, UiTheme.GOLD)
	detail.add_child(detail_name)
	detail_text = UiTheme.label("", 17, Color(UiTheme.CREAM, 0.85))
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_text.custom_minimum_size = Vector2(300, 0)
	detail.add_child(detail_text)
	detail_buttons = HBoxContainer.new()
	detail_buttons.add_theme_constant_override("separation", 10)
	detail.add_child(detail_buttons)
	stats = VBoxContainer.new()
	stats.name = "Traits"
	stats.add_theme_constant_override("separation", 6)
	detail.add_child(stats)
	stats_title = UiTheme.label("", 22, UiTheme.GOLD)
	stats.add_child(stats_title)
	stats_desc = UiTheme.label("", 16, Color(UiTheme.CREAM, 0.7))
	stats_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_desc.custom_minimum_size = Vector2(300, 0)
	stats.add_child(stats_desc)
	stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 18)
	stats_grid.add_theme_constant_override("v_separation", 4)
	stats.add_child(stats_grid)
	var note := UiTheme.label("×1 ist normal. Beim Rennen: Hunger ×1,6, Müdigkeit ×3.", 14, Color(UiTheme.CREAM, 0.55))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(300, 0)
	stats.add_child(note)
	chest_box = VBoxContainer.new()
	chest_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chest_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(chest_box)
	chest_box.add_child(UiTheme.label("Lagerkiste – tippe zum Umpacken", 20, UiTheme.GOLD))
	var cscroll := ScrollContainer.new()
	cscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chest_box.add_child(cscroll)
	chest_grid = GridContainer.new()
	chest_grid.add_theme_constant_override("h_separation", 8)
	chest_grid.add_theme_constant_override("v_separation", 8)
	cscroll.add_child(chest_grid)


func open(a: Actor, with_chest := false) -> void:
	actor = a
	chest = with_chest
	selected = ""
	refresh()


func refresh() -> void:
	if actor == null:
		return
	title.text = "Rucksack – %s" % actor.display_name
	capacity.text = "%d / %d Plätze" % [Items.slots_used(actor.inventory), actor.bag_slots()]
	if actor.overfull():
		capacity.text += " – übervoll!"
	capacity.add_theme_color_override("font_color", UiTheme.RED if actor.overfull() else Color(UiTheme.CREAM, 0.8))
	if GameState.tickets > 0:
		capacity.text += " · %d Kirmes-Tickets" % GameState.tickets
	# Bag: 4 columns next to the chest, 6 when alone.
	bag_grid.columns = 4 if chest else 6
	pouch_grid.columns = bag_grid.columns
	chest_grid.columns = 4
	detail.visible = not chest
	chest_box.visible = chest
	var pouch := actor.inventory.has(Items.POUCH)
	_fill(bag_grid, actor.inventory, actor.bag_slots(), false, func(id: String) -> bool: return not Items.in_pouch(actor.inventory, id))
	pouch_title.visible = pouch
	pouch_grid.visible = pouch
	if pouch:
		pouch_title.text = "Kräuterbeutel – %d Plätze, wächst mit" % Items.pouch_slots(actor.inventory)
		# The pouch's own tile first, then its slots and always one free: it never runs full.
		_fill(pouch_grid, actor.inventory, Items.pouch_slots(actor.inventory) + 2, false,
			func(id: String) -> bool: return Items.in_pouch(actor.inventory, id), true)
	if chest:
		_fill(chest_grid, GameState.storage, 0, true)
	_show_detail()


## One tile per slot (full stacks and the rest) of the items `keep` lets through, then empty
## slots up to `slots`; `pouch`: the herb pouch's green tiles.
func _fill(grid: GridContainer, inv: Dictionary, slots: int, in_chest: bool, keep := Callable(), pouch := false) -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var used := 0
	var ids := Items.sorted_ids(inv)
	if pouch and ids.has(Items.POUCH):
		ids.erase(Items.POUCH)
		ids.push_front(Items.POUCH)
	for id: String in ids:
		if keep.is_valid() and not keep.call(id):
			continue
		var left := int(inv[id])
		var stack := Items.stack_size(id)
		while left > 0:
			var n := mini(left, stack)
			grid.add_child(_tile(id, n, in_chest, pouch))
			left -= n
			used += 1
	for i in maxi(0, slots - used):
		grid.add_child(_tile("", 0, in_chest, pouch))
	if in_chest and used == 0:
		grid.add_child(UiTheme.label("Die Kiste ist leer.", 17, Color(UiTheme.CREAM, 0.7)))


func _tile(id: String, count: int, in_chest: bool, pouch := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(TILE, TILE)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = Items.name_of(id) if id != "" else ""
	var on := id != "" and id == selected and not chest
	var tint := POUCH_COLOR if pouch else Color.WHITE
	var sb := UiTheme.panel(Color(tint, 0.3 if on else 0.16) if pouch else Color(tint, 0.16 if on else 0.07), 10)
	if pouch:
		sb.border_color = Color(POUCH_COLOR, 0.7)
	if on:
		sb.border_color = UiTheme.GOLD
	for state: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	if id == "":
		b.disabled = true
		var empty := UiTheme.panel(Color(tint, 0.08 if pouch else 0.03), 10)
		if pouch:
			empty.border_color = Color(POUCH_COLOR, 0.4)
		b.add_theme_stylebox_override("disabled", empty)
		return b
	b.name = "Item_" + id
	var icon := Control.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void: ItemIcons.draw(icon, id, Rect2(Vector2(8, 4), Vector2(TILE - 16, TILE - 22))))
	b.add_child(icon)
	var n := UiTheme.label("×%d" % count if count > 1 else "", 16)
	n.position = Vector2(TILE - 44, TILE - 26)  # no anchors: the tile has no size yet
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(n)
	b.pressed.connect(func() -> void: _on_tile(id, count, in_chest))
	return b


func _on_tile(id: String, count: int, in_chest: bool) -> void:
	if chest:
		if in_chest:
			take_from_chest(id, count)
		else:
			put_in_chest(id, count)
		return
	selected = id
	refresh()


func _show_detail() -> void:
	for c in detail_buttons.get_children():
		detail_buttons.remove_child(c)
		c.queue_free()
	stats.visible = selected == "" or not actor.has_item(selected)
	if stats.visible:
		selected = ""
		detail_name.text = "Dein Rucksack" if not actor.inventory.is_empty() else "Der Rucksack ist leer."
		detail_text.text = "Tippe auf einen Gegenstand." if not actor.inventory.is_empty() \
			else "Im Nordwald findest du Holz, Steine, Beeren und mehr."
		_show_traits()
		return
	var d := Items.def(selected)
	detail_name.text = Items.name_of(selected)
	var lines := ["%s · %d Stück" % [Items.CATEGORIES.get(d.get("cat", "misc"), ""), int(actor.inventory[selected])],
		d.get("desc", "")]
	if Items.value(selected) > 0:
		lines.append("Händler zahlen bis zu %s pro Stück." % GameState.format_money(Items.value(selected)))
	detail_text.text = "\n".join(lines)
	if Items.is_edible(selected):
		detail_buttons.add_child(UiTheme.button_node("Essen", func() -> void: eat(selected)))
	if Potions.is_potion(selected) and actor.controlled:
		detail_buttons.add_child(UiTheme.button_node("Trinken", func() -> void: drink(selected)))
	if d.get("cat", "") != "quest":
		detail_buttons.add_child(UiTheme.button_node("Wegwerfen", func() -> void: drop(selected)))


func _show_traits() -> void:
	stats_title.text = "Eigenschaften von %s" % actor.display_name
	stats_desc.text = actor.description
	stats_desc.visible = actor.description != ""
	for c in stats_grid.get_children():
		stats_grid.remove_child(c)
		c.queue_free()
	for row: Array in traits(actor):
		stats_grid.add_child(UiTheme.label(row[0], 17, Color(UiTheme.CREAM, 0.85)))
		stats_grid.add_child(UiTheme.label(row[1], 17, UiTheme.CREAM))


## The character's own values as [label, value] rows: pace and how fast hunger, fatigue and
## mood change, relative to most people (×1), whether it swims, the needs right now and a
## running Lauftrank.
static func traits(a: Actor) -> Array:
	var rates: Dictionary = a.def.get("rates", {})
	var rows := [
		["Gehtempo", times(a.walk_speed / Actor.BASE_WALK)],
		["Renntempo", times(a.run_speed / Actor.BASE_RUN)],
		["Wird hungrig", times(rates.get("hunger", 1.0))],
		["Wird müde", times(rates.get("fatigue", 1.0))],
		["Laune sinkt", times(rates.get("joy", 1.0))],
		["Schwimmen", "ja" if a.can_swim else "nein"],
		["Gerade", "Hunger %d %% · Müde %d %% · Laune %d %%" % [roundi(a.needs.hunger), roundi(a.needs.fatigue), roundi(a.needs.joy)]],
	]
	if Potions.speed_factor(a) > 1.0:
		var h := Potions.hours_left("speed")
		rows.append([Potions.NAMES["speed"], "Tempo %s, noch %s" % [times(Potions.SPEED),
			("%d h" % ceili(h)) if h >= 1.0 else ("%d min" % ceili(h * 60.0))]])
	return rows


## A factor as the UI shows it: "×1,4" (German comma, one decimal, "×1" when whole).
static func times(f: float) -> String:
	var s := "%.1f" % snappedf(f, 0.1)
	if s.ends_with(".0"):
		s = s.left(-2)
	return "×" + s.replace(".", ",")


## Eats one piece (the character holds it and eats, like food from a stand).
func eat(id: String) -> void:
	if not actor.take_item(id):
		return
	actor.consume(id)
	GameState.toast.emit("%s isst: %s" % [actor.display_name, Items.name_of(id)], "info")
	UI.close_screens()


## Drinks a potion (Potions): its effect runs for 8 game hours.
func drink(id: String) -> void:
	if Potions.drink(actor, id):
		UI.close_screens()


func drop(id: String) -> void:
	if actor.take_item(id):
		GameState.toast.emit("%s weggeworfen." % Items.name_of(id), "info")
	refresh()


## Moves one slot of `id` (the tapped tile: at most one stack) from the bag into the chest.
func put_in_chest(id: String, count: int) -> void:
	var n := mini(count, int(actor.inventory.get(id, 0)))
	if n <= 0 or Items.category(id) == "quest":
		return
	actor.take_item(id, n)
	GameState.storage[id] = int(GameState.storage.get(id, 0)) + n
	refresh()


## Takes one slot of `id` (the tapped tile: at most one stack) from the chest, as far as it
## fits into the bag.
func take_from_chest(id: String, count: int) -> void:
	var n := int(GameState.storage.get(id, 0))
	var moved := mini(mini(count, n), actor.room(id))
	if moved <= 0:
		actor.bag_full(id)
		return
	actor.add_item(id, moved)
	GameState.storage[id] = n - moved
	if GameState.storage[id] <= 0:
		GameState.storage.erase(id)
	refresh()

class_name BagScreen
extends Control
## The controlled character's bag ("Rucksack"): one tile per slot, details of the selected
## item, eat and throw away. With the storage chest open, both side by side: tapping a tile
## moves that stack across.

const TILE := 96

var game: Node
var actor: Actor
var chest := false                     # storage chest open next to the bag
var selected := ""
var title: Label
var capacity: Label
var bag_grid: GridContainer
var chest_box: VBoxContainer
var chest_grid: GridContainer
var detail: VBoxContainer
var detail_name: Label
var detail_text: Label
var detail_buttons: HBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func build(g: Node) -> void:
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
	scroll.add_child(bag_grid)
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
	# Bag: 4 columns next to the chest, 6 when alone.
	bag_grid.columns = 4 if chest else 6
	chest_grid.columns = 4
	detail.visible = not chest
	chest_box.visible = chest
	_fill(bag_grid, actor.inventory, actor.bag_slots(), false)
	if chest:
		_fill(chest_grid, GameState.storage, 0, true)
	_show_detail()


## One tile per slot (full stacks and the rest), then empty slots up to `slots`.
func _fill(grid: GridContainer, inv: Dictionary, slots: int, in_chest: bool) -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var used := 0
	for id: String in Items.sorted_ids(inv):
		var left := int(inv[id])
		var stack := Items.stack_size(id) if not in_chest else 999
		while left > 0:
			var n := mini(left, stack)
			grid.add_child(_tile(id, n, in_chest))
			left -= n
			used += 1
	for i in maxi(0, slots - used):
		grid.add_child(_tile("", 0, in_chest))
	if in_chest and used == 0:
		grid.add_child(UiTheme.label("Die Kiste ist leer.", 17, Color(UiTheme.CREAM, 0.7)))


func _tile(id: String, count: int, in_chest: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(TILE, TILE)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = Items.name_of(id) if id != "" else ""
	var on := id != "" and id == selected and not chest
	var sb := UiTheme.panel(Color(1, 1, 1, 0.16) if on else Color(1, 1, 1, 0.07), 10)
	if on:
		sb.border_color = UiTheme.GOLD
	for state: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	if id == "":
		b.disabled = true
		b.add_theme_stylebox_override("disabled", UiTheme.panel(Color(1, 1, 1, 0.03), 10))
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
	b.pressed.connect(func() -> void: _on_tile(id, in_chest))
	return b


func _on_tile(id: String, in_chest: bool) -> void:
	if chest:
		if in_chest:
			take_from_chest(id)
		else:
			put_in_chest(id)
		return
	selected = id
	refresh()


func _show_detail() -> void:
	for c in detail_buttons.get_children():
		detail_buttons.remove_child(c)
		c.queue_free()
	if selected == "" or not actor.has_item(selected):
		selected = ""
		detail_name.text = "Dein Rucksack" if not actor.inventory.is_empty() else "Der Rucksack ist leer."
		detail_text.text = "Tippe auf einen Gegenstand." if not actor.inventory.is_empty() \
			else "Im Nordwald findest du Holz, Steine, Beeren und mehr."
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
	if d.get("cat", "") != "quest":
		detail_buttons.add_child(UiTheme.button_node("Wegwerfen", func() -> void: drop(selected)))


## Eats one piece (the character holds it and eats, like food from a stand).
func eat(id: String) -> void:
	if not actor.take_item(id):
		return
	actor.consume(id)
	GameState.toast.emit("%s isst: %s" % [actor.display_name, Items.name_of(id)], "info")
	UI.close_screens()


func drop(id: String) -> void:
	if actor.take_item(id):
		GameState.toast.emit("%s weggeworfen." % Items.name_of(id), "info")
	refresh()


## Moves the whole stack of `id` from the bag into the chest.
func put_in_chest(id: String) -> void:
	var n := int(actor.inventory.get(id, 0))
	if n <= 0 or Items.category(id) == "quest":
		return
	actor.take_item(id, n)
	GameState.storage[id] = int(GameState.storage.get(id, 0)) + n
	refresh()


## Takes as much of `id` from the chest as fits into the bag.
func take_from_chest(id: String) -> void:
	var n := int(GameState.storage.get(id, 0))
	var moved := actor.add_item(id, n)
	if moved <= 0:
		return
	GameState.storage[id] = n - moved
	if GameState.storage[id] <= 0:
		GameState.storage.erase(id)
	refresh()

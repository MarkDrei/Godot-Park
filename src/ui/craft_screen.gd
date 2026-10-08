class_name CraftScreen
extends Control
## Workbench or campfire: every recipe with its ingredients (what the bag has / needs) and a
## button to make it. Making something takes the ingredients from the bag at once.

var game: Node
var actor: Actor
var station := "workbench"
var title: Label
var list: VBoxContainer


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
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	title = UiTheme.label("", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UiTheme.button_node("Schließen", func() -> void: UI.close_screens()))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)


func open(a: Actor, st: String) -> void:
	actor = a
	station = st
	refresh()


func refresh() -> void:
	title.text = "%s – %s" % [Crafting.STATIONS[station], actor.display_name]
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	for id: String in Crafting.for_station(station):
		list.add_child(_row(id))


func _row(id: String) -> PanelContainer:
	var r: Dictionary = Crafting.RECIPES[id]
	var ok := Crafting.can_craft(actor, id)
	var p := PanelContainer.new()
	p.name = "Recipe_" + id
	p.add_theme_stylebox_override("panel", UiTheme.panel(Color(1, 1, 1, 0.08 if ok else 0.04), 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void: ItemIcons.draw(icon, id, Rect2(Vector2.ZERO, Vector2(56, 56))))
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var out := int(r["out"])
	v.add_child(UiTheme.label(Items.name_of(id) + (" ×%d" % out if out > 1 else ""), 20, UiTheme.CREAM if ok else Color(UiTheme.CREAM, 0.6)))
	var parts := []
	var needs: Dictionary = r["needs"]
	for item: String in needs:
		parts.append("%s %d/%d" % [Items.name_of(item), int(actor.inventory.get(item, 0)), int(needs[item])])
	v.add_child(UiTheme.label(" · ".join(parts), 16, UiTheme.GREEN if ok else Color("e0a090")))
	var b := UiTheme.button_node("Herstellen", func() -> void: make(id), 18)
	b.name = "Make_" + id
	b.disabled = not ok
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return p


func make(id: String) -> void:
	if not Crafting.craft(actor, id):
		return
	Sound.play("success")
	actor.play_anim("sweep" if station == "workbench" else "feed", 1.5)
	GameState.toast.emit("%s hergestellt!" % Items.name_of(id), "info")
	refresh()

class_name TasksScreen
extends Control
## Tabs: open tasks, achievements and the park residents.

var game: Node
var tabs: TabContainer


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
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := UiTheme.label("Notizbuch", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UiTheme.button_node("Schließen", func() -> void: UI.close_screens()))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)


func refresh() -> void:
	for c in tabs.get_children():
		c.queue_free()
	tabs.add_child(_page("Aufgaben", _task_rows()))
	tabs.add_child(_page("Erfolge", _achievement_rows()))
	tabs.add_child(_page("Parkbewohner", _resident_rows()))


func _page(name: String, rows: Array) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.name = name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	for r: Control in rows:
		list.add_child(r)
	return sc


func _row(title: String, desc: String, done := false, accent := UiTheme.CREAM) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel(Color(1, 1, 1, 0.06) if not done else Color(0.9, 0.75, 0.25, 0.18), 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var t := UiTheme.label(title + ("  – geschafft!" if done else ""), 20, UiTheme.GOLD if done else accent)
	v.add_child(t)
	var d := UiTheme.label(desc, 16, Color(UiTheme.CREAM, 0.8))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	return p


func _task_rows() -> Array:
	var rows := []
	var entries := TaskBoard.entries()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("done", false)) < int(b.get("done", false)))
	for e: Dictionary in entries:
		rows.append(_row(e["title"], e["desc"], e.get("done", false)))
	if rows.is_empty():
		rows.append(_row("Keine Aufgaben", "Sprich mit den Leuten im Park!"))
	return rows


func _achievement_rows() -> Array:
	var rows := []
	var unlocked := 0
	for d: Dictionary in Achievements.DEFS:
		if GameState.is_unlocked(d["id"]):
			unlocked += 1
	rows.append(UiTheme.label("%d von %d Erfolgen freigeschaltet" % [unlocked, Achievements.DEFS.size()], 18, UiTheme.GOLD))
	for d: Dictionary in Achievements.DEFS:
		var done := GameState.is_unlocked(d["id"])
		if d.get("hidden", false) and not done:
			rows.append(_row("???", "Ein Geheimnis des Parks. Halte die Augen offen!"))
			continue
		var target: int = d["target"] if d["target"] > 0 else GameState.bench_count
		var progress := mini(GameState.stat(d["stat"]), target)
		var desc: String = d["desc"]
		if not done and target > 1:
			desc += "  (%d/%d)" % [progress, target]
		if d.get("reward", 0) > 0:
			desc += "  Belohnung: %s" % GameState.format_money(d["reward"])
		rows.append(_row(d["title"], desc, done))
	return rows


func _resident_rows() -> Array:
	var rows := []
	rows.append(UiTheme.label("Du hast %d Figuren gespielt." % GameState.stat("characters"), 18, UiTheme.GOLD))
	for a: Actor in game.world.actors:
		var played := GameState.has_in_set("characters", a.actor_id)
		var where := a.brain.doing() if a.brain and not a.controlled else "wird gerade von dir gespielt"
		var desc := "%s\nGerade: %s" % [a.description, where]
		if not a.playable:
			desc += "\n(nicht spielbar)"
		rows.append(_row(a.display_name + ("  (schon gespielt)" if played else ""), desc, false))
	return rows

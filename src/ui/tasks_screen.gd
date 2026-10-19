class_name TasksScreen
extends Control
## Tabs: open tasks, achievements and the park residents. Chips above a list filter it: tasks
## and residents by area (the notebook opens on the area the player is in), tasks and
## achievements by open/done.

const AREAS := {"park": "Stadtpark", "forest": "Nordwald", "city": "Oststadt", "fair": "Westpark", "burg": "Ritterburg"}
const SHOW := {"open": "Offen", "done": "Erledigt", "all": "Alle"}

var game: Game
var tabs: TabContainer
var area := ""        # "" = every area
var show := "open"
var _lists := {}      # tab name -> VBoxContainer of its rows
var _bars := {}       # tab name -> HFlowContainer of its chips


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
	for name: String in ["Aufgaben", "Erfolge", "Parkbewohner"]:
		_page(name)


## Called when the notebook opens: on the open tasks of the area the player is in.
func refresh() -> void:
	var a := game.player.actor if game.player else null
	area = ParkLayout.region_of(Vector2(a.global_position.x, a.global_position.z)) if a else ""
	show = "open"
	_fill()


func set_filter(new_area: String, new_show: String) -> void:
	area = new_area
	show = new_show
	_fill()


## The rows of the tab `name` as shown now (tests).
func rows(name: String) -> Array[Node]:
	return (_lists[name] as Node).get_children()


func _page(name: String) -> void:
	var v := VBoxContainer.new()
	v.name = name
	v.add_theme_constant_override("separation", 8)
	tabs.add_child(v)
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 6)
	bar.add_theme_constant_override("v_separation", 6)
	v.add_child(bar)
	_bars[name] = bar
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	_lists[name] = list


func _fill() -> void:
	var tasks := TaskBoard.entries()
	_set_rows("Aufgaben", _task_rows(tasks))
	_set_bar("Aufgaben", tasks.map(func(e: Dictionary) -> Array: return [e.get("area", "park"), e.get("done", false)]), true, true)
	_set_rows("Erfolge", _achievement_rows())
	_set_bar("Erfolge", Achievements.DEFS.map(func(d: Dictionary) -> Array: return ["", GameState.is_unlocked(d["id"])]), false, true)
	var people := _residents()
	_set_rows("Parkbewohner", _resident_rows(people))
	_set_bar("Parkbewohner", game.world.actors.map(func(a: Actor) -> Array: return [a.home_region, false]), true, false)


func _set_rows(name: String, rows: Array) -> void:
	var list: VBoxContainer = _lists[name]
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	for r: Control in rows:
		list.add_child(r)


## Chips for the area and/or open/done. `items` are [area, done] pairs: each area chip counts
## what it would show with the current open/done choice.
func _set_bar(name: String, items: Array, by_area: bool, by_done: bool) -> void:
	var bar: HFlowContainer = _bars[name]
	for c in bar.get_children():
		bar.remove_child(c)
		c.queue_free()
	if by_area:
		for id: String in [""] + AREAS.keys():
			var n := items.filter(func(it: Array) -> bool: return (id == "" or it[0] == id) and (not by_done or _shown(it[1]))).size()
			if n == 0 and id != "" and id != area:
				continue   # e.g. no Westpark people before it is built
			bar.add_child(_chip("%s (%d)" % [AREAS.get(id, "Überall"), n], id == area, set_filter.bind(id, show)))
	if by_area and by_done:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(14, 0)
		bar.add_child(gap)
	if by_done:
		for id: String in SHOW:
			bar.add_child(_chip(SHOW[id], id == show, set_filter.bind(area, id)))


func _chip(text: String, on: bool, cb: Callable) -> Button:
	var b := UiTheme.button_node(text, cb, 16)
	b.name = "Chip_" + text.get_slice(" (", 0)
	b.toggle_mode = true
	b.button_pressed = on
	b.add_theme_color_override("font_hover_pressed_color", Color("1f3a2e"))   # like the theme's pressed text
	return b


func _shown(done: bool) -> bool:
	return show == "all" or (show == "done") == done


func _row(title: String, desc: String, done := false, accent := UiTheme.CREAM) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS   # a finger on a row still drags the list (phones)
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


func _header(text: String) -> Label:
	var l := UiTheme.label(text, 18, UiTheme.GOLD)
	l.name = "Header_" + text
	return l


## Grouped by area when all areas are shown; in a group running quests first, done ones last.
func _task_rows(entries: Array) -> Array:
	var rows := []
	var rank := func(e: Dictionary) -> int: return 0 if e.get("active", false) else (2 if e.get("done", false) else 1)
	for id: String in AREAS:
		if area != "" and id != area:
			continue
		var group := range(entries.size()).filter(func(i: int) -> bool:
			return entries[i].get("area", "park") == id and _shown(entries[i].get("done", false)))
		group.sort_custom(func(a: int, b: int) -> bool: return [rank.call(entries[a]), a] < [rank.call(entries[b]), b])
		if group.is_empty():
			continue
		if area == "":
			rows.append(_header(AREAS[id]))
		for i: int in group:
			var e: Dictionary = entries[i]
			rows.append(_row(e["title"], e["desc"], e.get("done", false), UiTheme.ACCENT if e.get("active", false) else UiTheme.CREAM))
	if rows.is_empty():
		rows.append(_row("Alles erledigt!" if show == "open" else "Noch nichts erledigt",
			"Hier gibt es gerade nichts zu tun. Schau dich in einem anderen Gebiet um." if show == "open" else "Sprich mit den Leuten im Park!"))
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
		if not _shown(done):
			continue
		if d.get("hidden", false) and not done:
			rows.append(_row("???", "Ein Geheimnis des Parks. Halte die Augen offen!"))
			continue
		var target: int = d["target"]
		var progress := mini(GameState.stat(d["stat"]), target)
		var desc: String = d["desc"]
		if not done and target > 1:
			desc += "  (%d/%d)" % [progress, target]
		if d.get("reward", 0) > 0:
			desc += "  Belohnung: %s" % GameState.format_money(d["reward"])
		rows.append(_row(d["title"], desc, done))
	return rows


func _residents() -> Array[Actor]:
	var out: Array[Actor] = []
	for a: Actor in game.world.actors:
		if area == "" or a.home_region == area:
			out.append(a)
	return out


func _resident_rows(people: Array[Actor]) -> Array:
	var rows := []
	rows.append(UiTheme.label("Du hast %d Figuren gespielt." % GameState.stat("characters"), 18, UiTheme.GOLD))
	for a in people:
		var played := GameState.has_in_set("characters", a.actor_id)
		var where := a.brain.doing() if a.brain and not a.controlled else "wird gerade von dir gespielt"
		var desc := "%s\nGerade: %s" % [a.description, where]
		if not a.playable:
			desc += "\n(nicht spielbar)"
		rows.append(_row(a.display_name + ("  (schon gespielt)" if played else ""), desc, false))
	return rows

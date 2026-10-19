class_name MapScreen
extends Control
## Full-screen park map with place names, characters and the player.
## Tapping a spot sends the controlled character there. The "Gesamtkarte" shows every area at
## once with their names and the player; tapping it opens that area's map.

var game: Game
var tex_rect: TextureRect
var overlay: Control
var _show_animals := true
var view := MapImage.PARK_VIEW
var title: Label
var switch_button: Button
var view_buttons := {}          # view name -> Button (the Oststadt ones only once it is loaded)
const VIEWS := {"Ritterburg": MapImage.BURG_VIEW, "Westpark": MapImage.FAIR_VIEW, "Stadtpark": MapImage.PARK_VIEW,
	"Nordwald": MapImage.FOREST_VIEW, "Oststadt Nord": MapImage.CITY_NORTH_VIEW, "Oststadt Süd": MapImage.CITY_SOUTH_VIEW}
const OVERVIEW := "Gesamtkarte"
## Area names on the whole map: world position -> name.
const AREA_LABELS := {"Westpark": Vector2(-260, 0), "Stadtpark": Vector2(0, 0), "Nordwald": Vector2(0, -180),
	"Oststadt": Vector2(390, -90), "Ritterburg": Vector2(-265, -196)}


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
	v.offset_left = 30
	v.offset_right = -30
	v.offset_top = 20
	v.offset_bottom = -20
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	title = UiTheme.label("Parkplan – Stadtpark", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var all := VIEWS.duplicate()
	all[OVERVIEW] = MapImage.WORLD_VIEW
	for n: String in all:
		var b := UiTheme.button_node(n, func() -> void: show_view(all[n]), 16)
		top.add_child(b)
		view_buttons[n] = b
	switch_button = view_buttons["Nordwald"]
	top.add_child(UiTheme.button_node("Schließen", func() -> void: UI.close_screens()))
	tex_rect = TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	tex_rect.gui_input.connect(_on_map_input)
	v.add_child(tex_rect)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	tex_rect.add_child(overlay)
	visibility_changed.connect(func() -> void:
		if visible:
			_show_player_view())
	_show_player_view()


## Opens the view the controlled character is in.
func _show_player_view() -> void:
	var pc: PlayerController = game.player
	var v := MapImage.PARK_VIEW
	if pc != null and pc.actor != null:
		for n: String in VIEWS:
			if (VIEWS[n] as Rect2).has_point(pc.actor.ground_pos()):
				v = VIEWS[n]
	show_view(v)


func show_view(v: Rect2) -> void:
	view = v
	# Without the baked image the Oststadt, the Westpark and the Burg are drawn only once they
	# are loaded.
	var baked := MapImage.has_baked()
	var city: bool = baked or game.world.city != null
	var fair: bool = baked or game.world.fair != null
	var burg: bool = baked or game.world.burg != null
	tex_rect.texture = MapImage.view_texture(game.world.map, v, game.world.trees)
	for n: String in view_buttons:
		var b: Button = view_buttons[n]
		var r: Rect2 = MapImage.WORLD_VIEW if n == OVERVIEW else VIEWS[n]
		b.visible = r != v and (city or not n.begins_with("Oststadt")) and (fair or n != "Westpark") \
			and (burg or n != "Ritterburg") and (n != OVERVIEW or (city and fair and burg))
	if v == MapImage.WORLD_VIEW:
		title.text = OVERVIEW
	for n: String in VIEWS:
		if VIEWS[n] == v:
			title.text = ("Stadtplan – %s" if n.begins_with("Oststadt") else ("Burgplan – %s" if n == "Ritterburg" else "Parkplan – %s")) % n


func overview() -> bool:
	return view == MapImage.WORLD_VIEW


func _process(_delta: float) -> void:
	if visible:
		overlay.queue_redraw()


func _map_rect() -> Rect2:
	var sz := tex_rect.size
	var aspect := view.size.x / view.size.y
	var w := sz.x
	var h := w / aspect
	if h > sz.y:
		h = sz.y
		w = h * aspect
	return Rect2((sz - Vector2(w, h)) * 0.5, Vector2(w, h))


func world_to_map(p: Vector3) -> Vector2:
	var r := _map_rect()
	var uv := (Vector2(p.x, p.z) - view.position) / view.size
	return r.position + uv * r.size


func map_to_world(m: Vector2) -> Vector3:
	var r := _map_rect()
	var uv := (m - r.position) / r.size
	var w := view.position + uv * view.size
	return Vector3(w.x, 0, w.y)


func _draw_overlay() -> void:
	var font := get_theme_default_font()
	var world: World = game.world
	if overview():
		_draw_overview(font)
		return
	for id: String in ParkLayout.PLACES:
		if id.begins_with("gate") or id in ["island", "donut_stand", "kiosk", "pier", "grotto"]:
			continue
		var p := ParkLayout.place(id)
		if not view.has_point(p):
			continue
		var m := world_to_map(Vector3(p.x, 0, p.y))
		var text := ParkLayout.place_name(id)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		overlay.draw_string_outline(font, m - Vector2(w * 0.5, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.7))
		overlay.draw_string(font, m - Vector2(w * 0.5, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("1f3a2e"))
	if view.position.x >= ParkLayout.CITY_EDGE:
		_draw_city_labels(font)
	if view == MapImage.BURG_VIEW:
		for id: String in BurgLayout.PLACES:
			if id.begins_with("gate") or id in ["archery_targets", "inner_gate", "betting", "passage"]:
				continue
			var p := BurgLayout.place(id)
			var m := world_to_map(Vector3(p.x, 0, p.y))
			var text := BurgLayout.place_name(id)
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			overlay.draw_string_outline(font, m - Vector2(w * 0.5, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.7))
			overlay.draw_string(font, m - Vector2(w * 0.5, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("3a2a10"))
	if view == MapImage.FAIR_VIEW:
		for id: String in FairLayout.PLACES:
			if id.begins_with("gate") or id == "fest_square":
				continue
			var p := FairLayout.place(id)
			var m := world_to_map(Vector3(p.x, 0, p.y))
			var text := FairLayout.place_name(id)
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			overlay.draw_string_outline(font, m - Vector2(w * 0.5, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.7))
			overlay.draw_string(font, m - Vector2(w * 0.5, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("3a1f3a"))
	for b in world.map.bridges:
		var c: Vector2 = b["center"]
		if not view.has_point(c):
			continue
		var m2 := world_to_map(Vector3(c.x, 0, c.y))
		overlay.draw_string(font, m2 + Vector2(6, -6), b["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("5a3a20"))
	for a in world.actors:
		if a.inside or not a.visible or not view.has_point(a.ground_pos()):
			continue
		var col := Color("3a7fd8") if a.is_human() else Color("e8a030")
		overlay.draw_circle(world_to_map(a.global_position), 3.0, col)
	_draw_player()
	var y := overlay.size.y - 14
	overlay.draw_circle(Vector2(12, y - 5), 5.0, Color("3a7fd8"))
	overlay.draw_string(font, Vector2(22, y), "Menschen", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.CREAM)
	overlay.draw_circle(Vector2(112, y - 5), 5.0, Color("e8a030"))
	overlay.draw_string(font, Vector2(122, y), "Tiere", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.CREAM)
	overlay.draw_circle(Vector2(182, y - 5), 5.0, UiTheme.RED)
	overlay.draw_string(font, Vector2(192, y), "Du", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.CREAM)


## The whole map: the areas' names and the player (people would be dust at this size).
func _draw_overview(font: Font) -> void:
	for n: String in AREA_LABELS:
		var m := world_to_map(Vector3(AREA_LABELS[n].x, 0, AREA_LABELS[n].y))
		var w := font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		overlay.draw_string_outline(font, m - Vector2(w * 0.5, -8), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(1, 1, 1, 0.75))
		overlay.draw_string(font, m - Vector2(w * 0.5, -8), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("1f3a2e"))
	_draw_player()
	var y := overlay.size.y - 14
	overlay.draw_circle(Vector2(12, y - 5), 5.0, UiTheme.RED)
	overlay.draw_string(font, Vector2(22, y), "Du  ·  Tippe auf ein Gebiet für seine Karte", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.CREAM)


func _draw_player() -> void:
	var pc: PlayerController = game.player
	if pc and pc.actor and view.has_point(pc.actor.ground_pos()):
		var m3 := world_to_map(pc.actor.global_position)
		var f := Vector2(sin(pc.actor.yaw), cos(pc.actor.yaw))
		var r := Vector2(-f.y, f.x)
		overlay.draw_colored_polygon(PackedVector2Array([m3 + f * 12.0, m3 + r * 7.0 - f * 6.0, m3 - r * 7.0 - f * 6.0]), UiTheme.RED)
		overlay.draw_arc(m3, 14.0, 0, TAU, 24, Color(1, 1, 1, 0.8), 2.0)


## Street names along the streets and the places of the Oststadt.
func _draw_city_labels(font: Font) -> void:
	for id: String in CityLayout.PLACES:
		var p := CityLayout.place(id)
		if not view.has_point(p):
			continue
		var m := world_to_map(Vector3(p.x, 0, p.y))
		var text := CityLayout.place_name(id)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		overlay.draw_string_outline(font, m - Vector2(w * 0.5, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.7))
		overlay.draw_string(font, m - Vector2(w * 0.5, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("3a2a10"))
	for st: Dictionary in CityLayout.Z_STREETS:
		var z: float = st["z"]
		if z < view.position.y or z > view.end.y:
			continue
		for x: float in [CityLayout.X_STREETS[0]["x"] + 34.0, CityLayout.ALLEE_X + 34.0]:
			var m := world_to_map(Vector3(x, 0, z))
			overlay.draw_string(font, m + Vector2(0, 4), st["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("2a2a30"))
	for st: Dictionary in CityLayout.X_STREETS:
		var x: float = st["x"]
		var zc := clampf(view.get_center().y + 30.0, view.position.y + 10.0, view.end.y - 10.0)
		var m := world_to_map(Vector3(x, 0, zc))
		overlay.draw_set_transform(m + Vector2(4, 0), PI / 2, Vector2.ONE)
		overlay.draw_string(font, Vector2.ZERO, st["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("2a2a30"))
		overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_map_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
	if pos == Vector2.INF:
		return
	var p := map_to_world(pos)
	if overview():
		_open_view_at(Vector2(p.x, p.z))
		return
	if not ParkMap.in_world(Vector2(p.x, p.z), 1.0) or not view.has_point(Vector2(p.x, p.z)):
		return
	var pc: PlayerController = game.player
	var to := World.area_of(p)
	if _closed(to, pc.actor):
		if not _to_gate(pc.actor, to, Vector2(p.x, p.z)):
			GameState.toast.emit("Da kommt %s nicht hin." % pc.actor.display_name, "warn")
	elif pc.actor.go_to(p, true):
		UI.close_screens()
		UI.show_marker(Vector3(p.x, game.world.map.walk_height(p.x, p.z), p.z))
		GameState.toast.emit("Unterwegs …", "info")
	else:
		GameState.toast.emit("Da kommt %s nicht hin." % pc.actor.display_name, "warn")


## Another area than the actor's that is not loaded or sleeps.
func _closed(id: String, actor: Actor) -> bool:
	var a: Area = game.world.area(id)
	return id != World.area_of(actor.global_position) and not (a.is_built() and a.is_open())


## A tap into an area that is not loaded or sleeps: walks to the gate towards it nearest to `goal`
## (there the gate asks or the area is built, AreaGates). False if there is no such way.
func _to_gate(actor: Actor, to: String, goal: Vector2) -> bool:
	var from := World.area_of(actor.global_position)
	var best := ""
	for g: String in AreaGates.GATES:
		if AreaGates.beyond(g, from) == to and (best == "" or goal.distance_to(AreaGates.gate_pos(g)) < goal.distance_to(AreaGates.gate_pos(best))):
			best = g
	if best == "":
		return false
	var gp := AreaGates.gate_pos(best)
	if not actor.go_to(Vector3(gp.x, game.world.map.walk_height(gp.x, gp.y), gp.y), true):
		return false
	UI.close_screens()
	GameState.toast.emit("Unterwegs %s …" % AreaGates.GATES[best]["to"], "info")
	return true


## Opens the map of the view at p (a tap on the whole map).
func _open_view_at(p: Vector2) -> void:
	for n: String in VIEWS:
		if (VIEWS[n] as Rect2).has_point(p):
			show_view(VIEWS[n])
			return

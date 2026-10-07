class_name MapScreen
extends Control
## Full-screen park map with place names, characters and the player.
## Tapping a spot sends the controlled character there.

var game: Node
var tex_rect: TextureRect
var overlay: Control
var _show_animals := true


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
	v.offset_left = 30
	v.offset_right = -30
	v.offset_top = 20
	v.offset_bottom = -20
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := UiTheme.label("Parkplan – Stadtpark", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UiTheme.label("Tippe auf die Karte, um dorthin zu laufen.", 16, Color(UiTheme.CREAM, 0.7)))
	top.add_child(UiTheme.button_node("Schließen", func() -> void: UI.close_screens()))
	tex_rect = TextureRect.new()
	tex_rect.texture = MapImage.texture(game.world.map, game.world.trees)
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


func _process(_delta: float) -> void:
	if visible:
		overlay.queue_redraw()


func _map_rect() -> Rect2:
	var sz := tex_rect.size
	var aspect := float(ParkMap.W) / ParkMap.H
	var w := sz.x
	var h := w / aspect
	if h > sz.y:
		h = sz.y
		w = h * aspect
	return Rect2((sz - Vector2(w, h)) * 0.5, Vector2(w, h))


func world_to_map(p: Vector3) -> Vector2:
	var r := _map_rect()
	var u := (p.x - ParkMap.ORIGIN.x) / ParkMap.W
	var v := (p.z - ParkMap.ORIGIN.y) / ParkMap.H
	return r.position + Vector2(u, v) * r.size


func map_to_world(m: Vector2) -> Vector3:
	var r := _map_rect()
	var uv := (m - r.position) / r.size
	return Vector3(ParkMap.ORIGIN.x + uv.x * ParkMap.W, 0, ParkMap.ORIGIN.y + uv.y * ParkMap.H)


func _draw_overlay() -> void:
	var font := get_theme_default_font()
	var world: World = game.world
	for id: String in ParkLayout.PLACES:
		if id.begins_with("gate") or id in ["island", "donut_stand", "hotdog_stand", "pier", "grotto"]:
			continue
		var p := ParkLayout.place(id)
		var m := world_to_map(Vector3(p.x, 0, p.y))
		var text := ParkLayout.place_name(id)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		overlay.draw_string_outline(font, m - Vector2(w * 0.5, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.7))
		overlay.draw_string(font, m - Vector2(w * 0.5, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("1f3a2e"))
	for b in world.map.bridges:
		var c: Vector2 = b["center"]
		var m2 := world_to_map(Vector3(c.x, 0, c.y))
		overlay.draw_string(font, m2 + Vector2(6, -6), b["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("5a3a20"))
	for a in world.actors:
		if a.inside or not a.visible or not ParkMap.in_park(a.ground_pos()):
			continue
		var col := Color("3a7fd8") if a.is_human() else Color("e8a030")
		overlay.draw_circle(world_to_map(a.global_position), 3.0, col)
	var pc: PlayerController = game.player
	if pc and pc.actor:
		var m3 := world_to_map(pc.actor.global_position)
		var f := Vector2(sin(pc.actor.yaw), cos(pc.actor.yaw))
		var r := Vector2(-f.y, f.x)
		overlay.draw_colored_polygon(PackedVector2Array([m3 + f * 12.0, m3 + r * 7.0 - f * 6.0, m3 - r * 7.0 - f * 6.0]), UiTheme.RED)
		overlay.draw_arc(m3, 14.0, 0, TAU, 24, Color(1, 1, 1, 0.8), 2.0)
	var y := overlay.size.y - 14
	overlay.draw_circle(Vector2(12, y - 5), 5.0, Color("3a7fd8"))
	overlay.draw_string(font, Vector2(22, y), "Menschen", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.CREAM)
	overlay.draw_circle(Vector2(112, y - 5), 5.0, Color("e8a030"))
	overlay.draw_string(font, Vector2(122, y), "Tiere", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.CREAM)
	overlay.draw_circle(Vector2(182, y - 5), 5.0, UiTheme.RED)
	overlay.draw_string(font, Vector2(192, y), "Du", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.CREAM)


func _on_map_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
	if pos == Vector2.INF:
		return
	var p := map_to_world(pos)
	if not ParkMap.in_park(Vector2(p.x, p.z), 1.0):
		return
	var pc: PlayerController = game.player
	if pc.actor.go_to(p, true):
		UI.close_screens()
		UI.show_marker(Vector3(p.x, game.world.map.walk_height(p.x, p.z), p.z))
		GameState.toast.emit("Unterwegs …", "info")
	else:
		GameState.toast.emit("Da kommt %s nicht hin." % pc.actor.display_name, "warn")

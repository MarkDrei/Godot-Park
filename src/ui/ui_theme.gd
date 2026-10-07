class_name UiTheme
extends RefCounted
## Shared look of all menus: dark park green panels, cream text, warm accents.

const BG := Color(0.1, 0.19, 0.15, 0.9)
const BG_SOLID := Color(0.1, 0.19, 0.15, 1.0)
const CREAM := Color("f3ead2")
const ACCENT := Color("f2a03d")
const GOLD := Color("e8c040")
const RED := Color("e8574a")
const BLUE := Color("5aa0e6")
const GREEN := Color("7ed957")


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Label", 0)
	t.set_color("default_color", "RichTextLabel", CREAM)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "Button", button(state))
	t.set_color("font_color", "Button", Color("1f3a2e"))
	t.set_color("font_hover_color", "Button", Color("1f3a2e"))
	t.set_color("font_pressed_color", "Button", Color("1f3a2e"))
	t.set_color("font_focus_color", "Button", Color("1f3a2e"))
	t.set_color("font_disabled_color", "Button", Color(0.3, 0.3, 0.3))
	t.set_font_size("font_size", "Button", 20)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.35)
	bar_bg.set_corner_radius_all(6)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GREEN
	bar_fill.set_corner_radius_all(6)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 10)
	var tab := StyleBoxFlat.new()
	tab.bg_color = Color(1, 1, 1, 0.08)
	tab.set_corner_radius_all(8)
	tab.content_margin_left = 14
	tab.content_margin_right = 14
	tab.content_margin_top = 6
	tab.content_margin_bottom = 6
	var tab_sel := tab.duplicate() as StyleBoxFlat
	tab_sel.bg_color = ACCENT
	t.set_stylebox("tab_unselected", "TabBar", tab)
	t.set_stylebox("tab_hovered", "TabBar", tab)
	t.set_stylebox("tab_selected", "TabBar", tab_sel)
	t.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_unselected_color", "TabBar", CREAM)
	t.set_color("font_selected_color", "TabBar", Color("1f3a2e"))
	t.set_color("font_hovered_color", "TabBar", Color.WHITE)
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(0, 0, 0, 0.35)
	slider.set_corner_radius_all(4)
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider)
	return t


static func panel(color := BG, radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.border_color = Color(CREAM.r, CREAM.g, CREAM.b, 0.25)
	s.set_border_width_all(2)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 6
	return s


static func button(state: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = {"normal": CREAM, "hover": Color("ffe2b0"), "pressed": ACCENT, "focus": Color("ffe2b0"),
		"disabled": Color(0.6, 0.6, 0.55)}[state]
	s.set_corner_radius_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	if state == "focus":
		s.border_color = ACCENT
		s.set_border_width_all(3)
	return s


static func label(text: String, size := 20, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button_node(text: String, cb: Callable, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_ALL
	return b

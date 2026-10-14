class_name NeedBar
extends ProgressBar
## A need bar in the HUD: a rounded fill with a soft colour gradient (lighter at the top and
## towards the full end) and a gloss, in a dark inset track. While the need changes, the fill
## pulses and three arrowheads on the bar point the way it moves: green when the change is good
## (lower hunger / fatigue, higher joy), red otherwise.

const TREND_MIN := 0.25      # need points per second before a trend is shown
const RADIUS := 7.0

var color: Color
var good_up := false         # rising is good (joy)
var rate := 0.0              # smoothed change per second, set by the Hud
var anim := 0.0              # animation time, set by the Hud


func _init(col: Color, rising_is_good := false) -> void:
	color = col
	good_up = rising_is_good
	show_percentage = false
	add_theme_stylebox_override("background", StyleBoxEmpty.new())
	add_theme_stylebox_override("fill", StyleBoxEmpty.new())


## Whether a trend is shown now.
func trending() -> bool:
	return absf(rate) >= TREND_MIN


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Track: darker at the top, like a groove.
	var track := _rounded(Rect2(Vector2.ZERO, size), RADIUS)
	draw_polygon(track, _shade(track, func(p: Vector2) -> Color:
		return Color(0, 0, 0, lerpf(0.5, 0.3, p.y / h))))
	var full := w * clampf((value - min_value) / maxf(max_value - min_value, 0.001), 0.0, 1.0)
	var inner := Rect2(1.5, 1.5, full - 3.0, h - 3.0)
	if inner.size.x > 1.0:
		var glow := (0.08 + 0.08 * sin(anim * 8.0)) if trending() else 0.0
		var fill := _rounded(inner, RADIUS - 1.5)
		draw_polygon(fill, _shade(fill, func(p: Vector2) -> Color:
			# Linear in x and y, so the triangulation shows it exactly.
			var d := 0.16 * (1.0 - 2.0 * p.y / h) + 0.07 * (2.0 * p.x / w - 1.0) + glow
			return Color(color.r + d, color.g + d, color.b + d)))
		var gloss := _rounded(Rect2(inner.position + Vector2(2.0, 0.5), Vector2(inner.size.x - 4.0, inner.size.y * 0.42)), (RADIUS - 2.0) * 0.6)
		if inner.size.x > 6.0:
			draw_polygon(gloss, _shade(gloss, func(p: Vector2) -> Color:
				return Color(1, 1, 1, lerpf(0.38, 0.0, (p.y - 2.0) / (h * 0.42)))))
	if trending():
		_chevrons()


## Three arrowheads in the middle of the bar pointing the way the fill moves (right when the
## need rises, left when it falls), with a light running through them that way.
func _chevrons() -> void:
	var up := rate > 0.0
	var col := UiTheme.GREEN if up == good_up else Color("ff6a5c")
	var h := size.y
	var x0 := size.x * 0.5 - 17.0
	for i in 3:
		var x := x0 + i * 12.0
		var tip := x + 10.0 if up else x
		var back := x if up else x + 10.0
		var light := 0.5 + 0.5 * sin(anim * 7.0 - (i if up else 2 - i) * 1.4)
		var tri := PackedVector2Array([Vector2(back, 1.5), Vector2(tip, h * 0.5), Vector2(back, h - 1.5)])
		draw_colored_polygon(tri, col.lerp(Color.WHITE, 0.45 * light))
		tri.append(tri[0])
		draw_polyline(tri, Color(0.06, 0.08, 0.1, 0.9), 1.5, true)


## A rounded rectangle as a convex polygon.
static func _rounded(r: Rect2, radius: float, steps := 5) -> PackedVector2Array:
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var centres := [r.position + Vector2(r.size.x - rad, rad), r.end - Vector2(rad, rad),
		Vector2(r.position.x + rad, r.end.y - rad), r.position + Vector2(rad, rad)]
	for k in 4:
		for i in steps + 1:
			var a := -PI / 2 + (k + float(i) / steps) * PI / 2
			pts.append(centres[k] + Vector2(cos(a), sin(a)) * rad)
	return pts


static func _shade(pts: PackedVector2Array, f: Callable) -> PackedColorArray:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(f.call(p))
	return cols

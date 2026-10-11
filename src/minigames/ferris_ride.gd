class_name FerrisRide
extends Ride
## Riesenrad: the gondola goes up to the top, stops there with the view over the whole map
## (the park, the Nordwald, the Oststadt), and comes down again.

const UP := 16.0
const TOP := 7.0
var gondola := 0
var _start_angle := 0.0
var _top_said := false


func _init() -> void:
	title = "Riesenrad"
	host_id = "karl"
	cost = 300
	ride_id = "ferris"
	duration = 1.0 + UP + TOP + UP + 0.5
	joy = 35.0


func describe() -> String:
	return "Fahr mit dem Riesenrad bis ganz nach oben – von dort siehst du die ganze Karte. 3 €, bei Riesenrad-Karl im Westpark."


func ride_begin() -> void:
	var f := fair()
	f.ride_wheel = true
	gondola = f.lowest_gondola()
	# Turn the wheel so that the gondola hangs right at the bottom.
	_start_angle = -PI / 2 - TAU * gondola / f.gondolas.size()
	f.wheel_angle = _start_angle
	_top_said = false
	host_say("Einsteigen und gut festhalten! Ganz oben halten wir kurz an.")


## How far the wheel has turned since boarding: up to PI at the top, TAU back at the bottom.
func turned() -> float:
	if t < 1.0:
		return 0.0
	if t < 1.0 + UP:
		return PI * smoothstep(0.0, 1.0, (t - 1.0) / UP)
	if t < 1.0 + UP + TOP:
		return PI
	return PI + PI * smoothstep(0.0, 1.0, (t - 1.0 - UP - TOP) / UP)


func ride_update(_delta: float) -> void:
	fair().wheel_angle = _start_angle + turned()
	if not _top_said and t >= 1.0 + UP:
		_top_said = true
		set_info("Ganz oben! Da hinten der Stadtpark mit dem Teich, im Norden der Nordwald, ganz im Osten die Oststadt.")
		Sound.play("success", null, -10.0)


func ride_end() -> void:
	fair().ride_wheel = false


func at_top() -> bool:
	return t >= 1.0 + UP and t < 1.0 + UP + TOP


func _gondola() -> Node3D:
	return fair().gondolas[gondola]


## On the gondola's bench (1.9 m under the pivot), looking out of its open side.
func mount() -> Transform3D:
	return Transform3D(Basis(), _gondola().global_position + Vector3(0, -2.35, 0))


func camera_pose() -> Array:
	var g := _gondola().global_position
	var side := [g + Vector3(4.0, 1.8, 13.0), g + Vector3(0, -1.6, 0)]
	var view := [g + Vector3(-2.0, -0.4, 1.6), Vector3(-20, -6, -30)]
	# Near the top the camera turns from the gondola to the view over the map.
	var k := 0.0
	if t > UP - 3.0 and t < 1.0 + UP + TOP + 3.0:
		k = smoothstep(UP - 3.0, UP + 1.0, t) * (1.0 - smoothstep(UP + TOP, UP + TOP + 4.0, t))
	return [(side[0] as Vector3).lerp(view[0], k), (side[1] as Vector3).lerp(view[1], k)]


func info_text() -> String:
	return "Langsam geht es nach oben …"


func end_text() -> String:
	return "Was für eine Aussicht! Von ganz oben sah man die ganze Gegend."

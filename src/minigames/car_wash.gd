class_name CarWash
extends Minigame
## The car wash at Tankwart Toni's petrol station: drive up to the entrance, the belt pulls
## the car through. Press the right button in time: Schaum, Bürsten, Wachs (keys 1–3).

const PRICE := 300
const STEPS := ["Schaum", "Bürsten", "Wachs"]
const BEATS := 12
const BEAT := 1.5                 # seconds per beat; the window is the second half
const ENTRY := Vector2(195.0, -141.0)
const EXIT := Vector2(195.0, -113.0)

var rng := RandomNumberGenerator.new()
var car: Car
var beats: Array[int] = []
var beat := 0
var t := 0.0
var hits := 0
var answered := false
var brushes: Array[MeshInstance3D] = []
var _buttons_by_step: Array[Button] = []


func _init() -> void:
	title = "Waschstraße"
	host_id = "toni"
	cost = PRICE
	rng.randomize()


func describe() -> String:
	return "Waschstraße an Tonis Tankstelle: mit dem Auto an die Einfahrt, dann im Takt Schaum, Bürsten und Wachs drücken."


func can_start(a: Actor) -> bool:
	return not active and a.vehicle != null and a.vehicle.is_standing() and a.vehicle.length() < 5.5


func begin() -> void:
	car = actor.vehicle
	car.speed = 0.0
	car.place(ENTRY, 0.0)
	beats.clear()
	for i in BEATS:
		beats.append(rng.randi() % STEPS.size())
	beat = -1
	t = BEAT          # first beat right away
	hits = 0
	look(Vector3(199.5, 3.2, -128.0), Vector3(195.0, 0.8, -127.0))
	_buttons_by_step.clear()
	for i in STEPS.size():
		var b := add_button(STEPS[i], func() -> void: choose(i), 170)
		_buttons_by_step.append(b)
	set_info("Drück im richtigen Moment, was gerade leuchtet (oder 1, 2, 3).")
	for s: float in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 2.2
		mi.mesh = cyl
		mi.position = Vector3(195.0 + s * 1.9, 1.2, -127.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("2e86de")
		mi.material_override = mat
		world.add_child(mi)
		brushes.append(mi)


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	# The belt pulls the car through.
	var k := clampf((beat + t / BEAT) / BEATS, 0.0, 1.0)
	car.place(ENTRY.lerp(EXIT, k), 0.0)
	for b in brushes:
		b.rotate_y(delta * 8.0)
	if t >= BEAT:
		if beat >= 0 and not answered:
			_miss()
		beat += 1
		t = 0.0
		answered = false
		if beat >= BEATS:
			_finish()
			return
	_show_beat()


## The current beat's step, lit up while its window is open.
func current_step() -> int:
	return beats[beat] if beat >= 0 and beat < BEATS else -1


func window_open() -> bool:
	return t >= BEAT * 0.35 and not answered


func _show_beat() -> void:
	var step := current_step()
	for i in _buttons_by_step.size():
		var b := _buttons_by_step[i]
		if is_instance_valid(b):
			b.modulate = Color(1.0, 0.85, 0.3) if (i == step and window_open()) else Color(1, 1, 1, 0.55)
	set_score("%s! · Treffer %d / %d" % [STEPS[step] if step >= 0 else "…", hits, BEATS])


func choose(i: int) -> void:
	if not active or answered or beat < 0 or beat >= BEATS:
		return
	answered = true
	if i == current_step() and t >= BEAT * 0.35:
		hits += 1
		Sound.play("splash", car.global_position, -6.0)
	else:
		Sound.play("fail", car.global_position, -8.0)


func _miss() -> void:
	Sound.play("click")


func _finish() -> void:
	beat = BEATS
	GameState.set_stat_max("wash_best", hits)
	car.place(EXIT, 0.0)
	var won := hits >= 10
	end({"won": won, "money": PRICE if hits == BEATS else 0, "joy": 8.0 + hits,
		"text": "%d von %d Treffern. %s" % [hits, BEATS, "Blitzblank! Toni erlässt dir den Preis." if hits == BEATS else ("Das Auto glänzt!" if won else "Ein paar Streifen sind geblieben.")]})


func game_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_3:
			choose(k - KEY_1)


func cleanup() -> void:
	for b in brushes:
		b.queue_free()
	brushes.clear()
	_buttons_by_step.clear()
	if car and is_instance_valid(car):
		car.place(EXIT, 0.0)

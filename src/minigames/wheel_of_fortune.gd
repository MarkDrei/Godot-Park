class_name WheelOfFortune
extends BoothGame
## Glücksrad with Glücksrad-Gisela: pick a colour, the wheel spins and slows down. Your colour:
## six tickets; the golden field: twenty-five, whatever you picked.

const FIELDS := 12
const COLORS := {"Rot": Color("e8442e"), "Gelb": Color("f5e642"), "Blau": Color("2e86de"), "Grün": Color("27ae60")}
const GOLD := Color("c8962a")
var _wheel: Node3D
var _spin := 0.0                 # rad/s
var _angle := 0.0
var choice := ""
var result := ""


func _init() -> void:
	title = "Glücksrad"
	host_id = "gisela"
	booth = "wheel"
	cost = 50


func describe() -> String:
	return "Setz auf eine Farbe: Bleibt das Rad dort stehen, gibt es sechs Tickets, auf dem goldenen Feld fünfundzwanzig. 50 Cent bei Glücksrad-Gisela im Westpark."


## Colour name of field i (one golden field among them).
static func field(i: int) -> String:
	if i == 0:
		return "Gold"
	return COLORS.keys()[i % 4]


func booth_begin() -> void:
	var kit := MeshKit.new()
	for i in FIELDS:
		var a0 := TAU * i / FIELDS
		var a1 := TAU * (i + 1) / FIELDS
		var col: Color = GOLD if i == 0 else COLORS[field(i)]
		kit.tri(Vector3.ZERO, Vector3(sin(a1), cos(a1), 0) * 1.05, Vector3(sin(a0), cos(a0), 0) * 1.05, col)
		if i == 0:
			# Sparkles on the golden field.
			kit.use("glow")
			for k in 3:
				var a := lerpf(a0, a1, 0.3 + k * 0.2)
				kit.box(Vector3(sin(a), cos(a), 0) * (0.5 + k * 0.15) + Vector3(0, 0, 0.01), Vector3(0.05, 0.05, 0.01), Color("fff6c0"))
			kit.use("solid")
	kit.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	kit.cylinder(Vector3(0, -0.08, 0), 0.06, 1.12, 1.12, 24, Color("f1eee6"))
	kit.cylinder(Vector3(0, 0.0, 0), 0.05, 0.12, 0.12, 8, Color("e2c050"))
	kit.pop()
	_wheel = Node3D.new()
	_root.add_child(_wheel)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	_wheel.add_child(mi)
	_wheel.transform = Transform3D(basis(), lp(0, 1.8, -1.2))
	_angle = randf() * TAU
	_spin = 0.0
	choice = ""
	result = ""
	set_score("Wähle eine Farbe!")
	set_info("Rot, Gelb, Blau oder Grün? (Knöpfe oder Tasten 1–4)")
	for n: String in COLORS:
		add_button(n, func() -> void: pick(n), 120)
	host_say("Dreh am Glück!")


func _process(delta: float) -> void:
	if not active or _wheel == null:
		return
	if _spin > 0.0:
		_angle += _spin * delta
		_spin = maxf(0.0, _spin - delta * (1.6 + _spin * 0.25))
		if _spin <= 0.0:
			_stop()
	_wheel.transform.basis = basis() * Basis(Vector3.BACK, _angle)


## Field under the pointer at the top.
func field_at_top() -> int:
	var a := fposmod(_angle, TAU)
	return int(a / (TAU / FIELDS)) % FIELDS


func pick(color: String) -> void:
	if choice != "" or not active:
		return
	choice = color
	clear_buttons()
	_spin = randf_range(9.0, 13.0)
	set_score("Du setzt auf %s …" % color)
	Sound.play("click", lp(0, 1.8, -1.2), 0.0)


func _stop() -> void:
	result = field(field_at_top())
	if result == "Gold":
		tickets = 25
		host_say("GOLD! Das goldene Feld!", 3.0)
	elif result == choice:
		tickets = 6
		host_say("%s! Gewonnen!" % result, 2.5)
	else:
		host_say("%s. Schade! Nächstes Mal." % result, 2.5)
	finish_round("Das Rad bleibt auf %s stehen." % result, tickets > 0, 1.8)


func game_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k := [KEY_1, KEY_2, KEY_3, KEY_4].find((event as InputEventKey).keycode)
		if k >= 0:
			pick(COLORS.keys()[k])

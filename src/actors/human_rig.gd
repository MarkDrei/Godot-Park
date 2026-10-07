class_name HumanRig
extends Rig
## Procedurally modelled and animated person.
##
## Appearance keys (all optional):
##   height (m), girth, child, skin, hair, hair_color, beard, glasses, hat, hat_color,
##   top, top_color, top_color2, bottom, bottom_color, shoes, extras (Array of strings)

const SKIN_TONES := [Color("f5d0b5"), Color("eac09c"), Color("d9a77e"), Color("b47d57"), Color("8d5a3b"), Color("5e3a26")]
const HAIR_COLORS := [Color("2b1d14"), Color("4a2f1e"), Color("7a4a26"), Color("c9a25c"), Color("e8d39a"), Color("b0442a"), Color("9a9a9a"), Color("e8e8e8")]

var look := {}
var s := 1.0          # body scale (height / 1.75)
var head_s := 1.0     # extra head scale (children have big heads)
var _blink := 2.0
var _closed := false
var _mood_mouth := 1  # 1 happy, 0 neutral, -1 sad


func build(appearance: Dictionary) -> void:
	look = appearance
	var child: bool = look.get("child", false)
	var h: float = look.get("height", 1.15 if child else 1.75)
	s = h / 1.75
	head_s = 1.3 if child else 1.0
	height = h + 0.05
	var rb := RigBuilder.new()
	var hip_y := 0.93 * s
	rb.bone("root", "", Vector3.ZERO)
	rb.bone("hips", "root", Vector3(0, hip_y, 0))
	rb.bone("spine", "hips", Vector3(0, 1.08 * s, 0))
	rb.bone("chest", "spine", Vector3(0, 1.3 * s, 0))
	rb.bone("neck", "chest", Vector3(0, 1.52 * s, 0))
	rb.bone("head", "neck", Vector3(0, 1.6 * s, 0))
	var head_c := Vector3(0, 1.6 * s + 0.12 * head_s * s, 0)
	rb.bone("eyes", "head", head_c + Vector3(0, 0.02, 0.1) * head_s * s)
	rb.bone("mouth_happy", "head", head_c + Vector3(0, -0.055, 0.115) * head_s * s)
	rb.bone("mouth_sad", "head", head_c + Vector3(0, -0.06, 0.115) * head_s * s)
	for side: String in ["l", "r"]:
		var x := 1.0 if side == "l" else -1.0
		rb.bone("upper_arm_" + side, "chest", Vector3(0.2 * x, 1.46 * s, 0))
		rb.bone("forearm_" + side, "upper_arm_" + side, Vector3(0.23 * x, 1.18 * s, 0))
		rb.bone("hand_" + side, "forearm_" + side, Vector3(0.24 * x, 0.93 * s, 0.02))
		rb.bone("thigh_" + side, "hips", Vector3(0.095 * x, 0.9 * s, 0))
		rb.bone("shin_" + side, "thigh_" + side, Vector3(0.1 * x, 0.5 * s, 0))
	_body(rb, child)
	_head(rb, head_c)
	_init_skeleton(rb.finish())
	set_bone_scale("mouth_sad", Vector3.ZERO)


func _c(key: String, fallback: Color) -> Color:
	var v = look.get(key, fallback)
	return v if v is Color else Color(v)


func _body(rb: RigBuilder, child: bool) -> void:
	var skin := _c("skin", SKIN_TONES[1])
	var top := _c("top_color", Color("4a7ab8"))
	var top2 := _c("top_color2", top.darkened(0.25))
	var bottom := _c("bottom_color", Color("3a4a5e"))
	var shoes := _c("shoes", Color("3a2a20"))
	var girth: float = look.get("girth", 1.0)
	var top_kind: String = look.get("top", "tshirt")
	var bottom_kind: String = look.get("bottom", "pants")
	var extras: Array = look.get("extras", [])
	var g := girth
	var k := rb.on("hips")
	# Pelvis.
	k.sphere(Vector3(0, 0.95 * s, 0), Vector3(0.17 * g, 0.12, 0.12 * g) * s, bottom, 3, 8)
	if top_kind == "dress" or bottom_kind == "skirt":
		var skirt_col := top if top_kind == "dress" else bottom
		k.cylinder(Vector3(0, 0.52 * s, 0), 0.48 * s, 0.27 * g * s, 0.17 * g * s, 10, skirt_col, true)
	# Belly and torso.
	k = rb.on("spine")
	var striped := top_kind == "striped"
	k.lathe(PackedVector2Array([Vector2(0.165 * g, 1.0 * s), Vector2(0.17 * g, 1.12 * s), Vector2(0.165 * g, 1.28 * s)]),
		10, top2 if striped else top)
	if g > 1.15:
		k.sphere(Vector3(0, 1.1 * s, 0.07 * g), Vector3(0.17, 0.16, 0.14) * g * s, top, 4, 8)
	k = rb.on("chest")
	k.lathe(PackedVector2Array([Vector2(0.165 * g, 1.26 * s), Vector2(0.19 * g, 1.36 * s), Vector2(0.18 * g, 1.46 * s),
		Vector2(0.09, 1.53 * s), Vector2(0.0, 1.535 * s)]), 10, top, 0.0,
		[top, top2 if striped else top, top])
	if striped:
		for i in 3:
			k.torus(Vector3(0, (1.08 + i * 0.14) * s, 0), 0.172 * g, 0.012, 10, 3, Color("f4f4f4") if i % 2 == 0 else Color("1a1a1a"))
	match top_kind:
		"suit":
			k.box(Vector3(0, 1.4 * s, 0.17 * g), Vector3(0.1, 0.22 * s, 0.02), Color("f4f4f4"))
			k.box(Vector3(0, 1.36 * s, 0.185 * g), Vector3(0.045, 0.2 * s, 0.02), _c("tie", Color("a8322a")))
		"hoodie":
			k.sphere(Vector3(0, 1.48 * s, -0.12), Vector3(0.14, 0.09, 0.08) * s, top.darkened(0.12), 3, 6)
			k.box(Vector3(0, 1.18 * s, 0.17 * g), Vector3(0.2, 0.08, 0.02), top.darkened(0.15))
		"apron":
			k.box(Vector3(0, 1.2 * s, 0.17 * g), Vector3(0.26 * g, 0.42 * s, 0.02), Color("f4f4f4"))
		"jacket":
			k.box(Vector3(0, 1.32 * s, 0.18 * g), Vector3(0.025, 0.36 * s, 0.02), Color("cccccc"))
	if "tie" in extras:
		k.box(Vector3(0, 1.36 * s, 0.185 * g), Vector3(0.045, 0.2 * s, 0.02), Color("2a4a8a"))
	if "bowtie" in extras:
		k.box(Vector3(0, 1.49 * s, 0.13), Vector3(0.1, 0.035, 0.03), Color("a8322a"))
	if "scarf" in extras:
		k.torus(Vector3(0, 1.5 * s, 0), 0.1, 0.045, 10, 4, _c("scarf_color", Color("c0392b")))
		k.box(Vector3(0.05, 1.38 * s, 0.13), Vector3(0.07, 0.2 * s, 0.03), _c("scarf_color", Color("c0392b")))
	if "backpack" in extras:
		k.box(Vector3(0, 1.3 * s, -0.25 * g), Vector3(0.28, 0.36 * s, 0.14), _c("backpack_color", Color("e0752d")))
		k.box(Vector3(0, 1.18 * s, -0.33 * g), Vector3(0.22, 0.12 * s, 0.04), _c("backpack_color", Color("e0752d")).darkened(0.2))
	if "camera_strap" in extras:
		k.box(Vector3(0, 1.25 * s, 0.2 * g), Vector3(0.12, 0.08, 0.06), Color("2a2a2a"))
	if "necklace" in extras:
		k.torus(Vector3(0, 1.5 * s, 0.02), 0.09, 0.008, 10, 3, Color("e2c050"))
	if "vest" in extras:
		k.box(Vector3(0, 1.32 * s, 0.172 * g), Vector3(0.3 * g, 0.34 * s, 0.02), Color("e8f04a"))
	if "badge" in extras:
		k.box(Vector3(0.1, 1.4 * s, 0.19 * g), Vector3(0.05, 0.05, 0.01), Color("e2c050"))
	# Neck.
	k = rb.on("neck")
	k.cylinder(Vector3(0, 1.5 * s, 0), 0.12 * s, 0.055, 0.05, 7, skin)
	# Arms.
	var long_sleeves := top_kind in ["shirt", "suit", "hoodie", "striped", "jacket"]
	var sleeves := top_kind != "tank" and top_kind != "dress"
	for side: String in ["l", "r"]:
		var x := 1.0 if side == "l" else -1.0
		k = rb.on("upper_arm_" + side)
		var sh := Vector3(0.2 * x, 1.46 * s, 0)
		var el := Vector3(0.23 * x, 1.18 * s, 0)
		k.sphere(sh, Vector3(0.07, 0.07, 0.07) * g, top if sleeves else skin, 3, 6)
		if sleeves and not long_sleeves:
			k.rod(sh, sh.lerp(el, 0.55), 0.062 * g, 0.058 * g, 7, top)
			k.rod(sh.lerp(el, 0.5), el, 0.05, 0.045, 6, skin)
		else:
			k.rod(sh, el, 0.058 * g, 0.05 * g, 7, top if sleeves else skin)
		k = rb.on("forearm_" + side)
		var wr := Vector3(0.24 * x, 0.95 * s, 0.01)
		k.rod(el, wr, 0.048 * g if long_sleeves else 0.044, 0.04, 6, top if long_sleeves else skin)
		if long_sleeves and striped:
			k.torus(el.lerp(wr, 0.5), 0.047, 0.01, 6, 3, Color("1a1a1a"))
		k = rb.on("hand_" + side)
		var hand_col := Color("f4f4f4") if "gloves" in extras else skin
		k.sphere(Vector3(0.245 * x, 0.89 * s, 0.015), Vector3(0.045, 0.06, 0.035), hand_col, 3, 6)
		k.sphere(Vector3(0.22 * x, 0.9 * s, 0.05), Vector3(0.018, 0.03, 0.018), hand_col, 2, 4)
	# Legs.
	for side: String in ["l", "r"]:
		var x := 1.0 if side == "l" else -1.0
		var hip := Vector3(0.095 * x, 0.9 * s, 0)
		var knee := Vector3(0.1 * x, 0.5 * s, 0.01)
		var ankle := Vector3(0.1 * x, 0.08 * s, 0)
		k = rb.on("thigh_" + side)
		var thigh_col := bottom
		var shin_col := bottom
		match bottom_kind:
			"shorts":
				k.rod(hip, hip.lerp(knee, 0.6), 0.085 * g, 0.075 * g, 7, bottom)
				k.rod(hip.lerp(knee, 0.55), knee, 0.065, 0.058, 7, skin)
				shin_col = skin
			"skirt":
				k.rod(hip, knee, 0.07 * g, 0.058, 7, skin)
				shin_col = _c("socks", skin)
			_:
				if top_kind == "dress":
					k.rod(hip, knee, 0.07 * g, 0.058, 7, skin)
					shin_col = _c("socks", skin)
				else:
					k.rod(hip, knee, 0.085 * g, 0.068 * g, 7, thigh_col)
		k = rb.on("shin_" + side)
		k.rod(knee, ankle, 0.062 if shin_col == bottom else 0.052, 0.048, 7, shin_col)
		k.box(Vector3(0.1 * x, 0.045 * s, 0.05), Vector3(0.1, 0.09 * s, 0.24), shoes, shoes.lightened(0.1))


func _head(rb: RigBuilder, c: Vector3) -> void:
	var skin := _c("skin", SKIN_TONES[1])
	var hair_col := _c("hair_color", HAIR_COLORS[1])
	var hs := head_s * s
	var k := rb.on("head")
	var r := 0.125 * hs
	k.sphere(c, Vector3(r * 0.95, r * 1.05, r), skin, 5, 9)
	# Ears, nose, cheeks.
	for x: float in [-1.0, 1.0]:
		k.sphere(c + Vector3(x * r * 0.98, -0.01, -0.005), Vector3(0.022, 0.035, 0.02) * hs, skin.darkened(0.05), 2, 5)
	var nose_size: float = look.get("nose", 1.0)
	k.sphere(c + Vector3(0, -0.015 * hs, r * 0.98), Vector3(0.022, 0.03, 0.026) * hs * nose_size, skin.darkened(0.08), 3, 5)
	if look.get("blush", false):
		for x: float in [-1.0, 1.0]:
			k.sphere(c + Vector3(x * r * 0.55, -0.03 * hs, r * 0.8), Vector3(0.025, 0.015, 0.01) * hs, Color("f08a8a"), 2, 5)
	# Eyebrows.
	for x: float in [-1.0, 1.0]:
		k.box(c + Vector3(x * 0.042 * hs, 0.05 * hs, r * 0.93), Vector3(0.04, 0.009, 0.012) * hs, hair_col.darkened(0.2))
	_hair(k, c, r, hair_col)
	_beard(k, c, r, hair_col)
	_glasses(k, c, r)
	_hat(k, c, r)
	# Eyes (blink = scale bone).
	k = rb.on("eyes")
	for x: float in [-1.0, 1.0]:
		k.sphere(c + Vector3(x * 0.042 * hs, 0.018 * hs, r * 0.9), Vector3(0.022, 0.024, 0.012) * hs, Color("fbfbf8"), 2, 6)
		k.sphere(c + Vector3(x * 0.042 * hs, 0.016 * hs, r * 0.95), Vector3(0.012, 0.015, 0.008) * hs, _c("eye_color", Color("3a2a1a")), 2, 5)
	# Mouths.
	k = rb.on("mouth_happy")
	for i in 5:
		var t := (i - 2) / 2.0
		k.box(c + Vector3(t * 0.026 * hs, (-0.055 + absf(t) * 0.01) * hs, r * 0.93), Vector3(0.016, 0.008, 0.008) * hs, Color("8a3a32"))
	k = rb.on("mouth_sad")
	for i in 5:
		var t := (i - 2) / 2.0
		k.box(c + Vector3(t * 0.024 * hs, (-0.06 - absf(t) * 0.01) * hs, r * 0.93), Vector3(0.016, 0.008, 0.008) * hs, Color("6a2a22"))


func _hair(k: MeshKit, c: Vector3, r: float, col: Color) -> void:
	var hs := head_s * s
	match look.get("hair", "short"):
		"short":
			k.sphere(c + Vector3(0, 0.03 * hs, -0.012), Vector3(r * 1.02, r * 0.85, r * 1.0), col, 4, 9, 0.0, 0, Color(0, 0, 0, 0))
			k.box(c + Vector3(0, 0.08 * hs, 0.07 * hs), Vector3(0.17, 0.05, 0.06) * hs, col)
		"spiky":
			k.sphere(c + Vector3(0, 0.03 * hs, -0.012), Vector3(r * 1.02, r * 0.8, r * 1.0), col, 3, 8)
			for i in 7:
				var a := TAU * i / 7.0
				var p := c + Vector3(cos(a) * 0.06, 0.1, sin(a) * 0.06) * hs
				k.cylinder(p, 0.07 * hs, 0.03 * hs, 0.0, 4, col)
		"long":
			k.sphere(c + Vector3(0, 0.025 * hs, -0.01), Vector3(r * 1.06, r * 0.9, r * 1.04), col, 4, 9)
			k.box(c + Vector3(0, -0.09 * hs, -0.07 * hs), Vector3(0.24, 0.26, 0.1) * hs, col)
		"bob":
			k.sphere(c + Vector3(0, 0.0, -0.01), Vector3(r * 1.12, r * 1.05, r * 1.08), col, 4, 9)
			k.box(c + Vector3(0, 0.07 * hs, 0.085 * hs), Vector3(0.2, 0.06, 0.05) * hs, col)
		"ponytail":
			k.sphere(c + Vector3(0, 0.03 * hs, -0.012), Vector3(r * 1.03, r * 0.88, r * 1.02), col, 4, 9)
			k.rod(c + Vector3(0, 0.05, -0.12) * hs, c + Vector3(0, -0.15, -0.17) * hs, 0.04 * hs, 0.015 * hs, 5, col)
		"bun":
			k.sphere(c + Vector3(0, 0.03 * hs, -0.012), Vector3(r * 1.03, r * 0.88, r * 1.02), col, 4, 9)
			k.sphere(c + Vector3(0, 0.13, -0.06) * hs, Vector3(0.06, 0.055, 0.06) * hs, col, 3, 7)
		"curly":
			for i in 14:
				var a := TAU * i / 9.0
				var y := 0.04 + 0.05 * (i / 9)
				k.sphere(c + Vector3(cos(a) * 0.1, y, sin(a) * 0.1 - 0.01) * hs, Vector3(0.06, 0.06, 0.06) * hs, col, 2, 6)
			k.sphere(c + Vector3(0, 0.1, 0) * hs, Vector3(0.1, 0.07, 0.1) * hs, col, 3, 7)
		"pigtails":
			k.sphere(c + Vector3(0, 0.03 * hs, -0.012), Vector3(r * 1.03, r * 0.88, r * 1.02), col, 4, 9)
			for x: float in [-1.0, 1.0]:
				k.sphere(c + Vector3(x * 0.14, -0.02, -0.03) * hs, Vector3(0.05, 0.08, 0.05) * hs, col, 3, 6)
		"bald_ring":
			for i in 9:
				var a := PI * 0.15 + i * PI * 0.7 / 8.0
				k.sphere(c + Vector3(cos(a) * 0.115, -0.005, -sin(a) * 0.1) * hs, Vector3(0.035, 0.04, 0.035) * hs, col, 2, 5)
		"mohawk":
			for i in 6:
				k.cylinder(c + Vector3(0, 0.09, 0.07 - i * 0.035) * hs, 0.09 * hs, 0.025 * hs, 0.0, 4, col)
		_:
			pass


func _beard(k: MeshKit, c: Vector3, r: float, col: Color) -> void:
	var hs := head_s * s
	match look.get("beard", ""):
		"mustache":
			k.box(c + Vector3(0, -0.04, r / hs * 0.95) * hs, Vector3(0.07, 0.016, 0.02) * hs, col)
			for x: float in [-1.0, 1.0]:
				k.box(c + Vector3(x * 0.04, -0.048, r / hs * 0.92) * hs, Vector3(0.02, 0.025, 0.018) * hs, col)
		"full":
			k.sphere(c + Vector3(0, -0.07, 0.06) * hs, Vector3(0.1, 0.08, 0.07) * hs, col, 3, 8)
			k.box(c + Vector3(0, -0.04, r / hs * 0.96) * hs, Vector3(0.07, 0.016, 0.02) * hs, col)
		"long":
			k.sphere(c + Vector3(0, -0.11, 0.06) * hs, Vector3(0.1, 0.13, 0.07) * hs, col, 3, 8)
		"goatee":
			k.sphere(c + Vector3(0, -0.1, 0.1) * hs, Vector3(0.03, 0.035, 0.025) * hs, col, 2, 5)
		"stubble":
			k.sphere(c + Vector3(0, -0.06, 0.04) * hs, Vector3(0.105, 0.07, 0.085) * hs, col.lerp(_c("skin", SKIN_TONES[1]), 0.6), 3, 8)


func _glasses(k: MeshKit, c: Vector3, r: float) -> void:
	var hs := head_s * s
	match look.get("glasses", ""):
		"round":
			for x: float in [-1.0, 1.0]:
				k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), c + Vector3(x * 0.042, 0.018, r / hs * 1.02) * hs))
				k.torus(Vector3.ZERO, 0.026 * hs, 0.005 * hs, 8, 3, Color("2a2a2a"))
				k.pop()
			k.box(c + Vector3(0, 0.02, r / hs * 1.03) * hs, Vector3(0.03, 0.006, 0.006) * hs, Color("2a2a2a"))
		"sun":
			k.box(c + Vector3(0, 0.02, r / hs * 1.02) * hs, Vector3(0.16, 0.035, 0.015) * hs, Color("151515"))
		"square":
			for x: float in [-1.0, 1.0]:
				k.box(c + Vector3(x * 0.042, 0.018, r / hs * 1.02) * hs, Vector3(0.05, 0.035, 0.006) * hs, Color("6a3a20"))


func _hat(k: MeshKit, c: Vector3, r: float) -> void:
	var hs := head_s * s
	var col := _c("hat_color", Color("c0392b"))
	match look.get("hat", ""):
		"cap":
			k.sphere(c + Vector3(0, 0.05, 0) * hs, Vector3(r * 1.06, r * 0.75, r * 1.06), col, 3, 9, 0.0, 0, Color(0, 0, 0, 0))
			k.box(c + Vector3(0, 0.055, 0.15) * hs, Vector3(0.17, 0.015, 0.1) * hs, col.darkened(0.15))
		"beret":
			k.push(Transform3D(Basis(Vector3.BACK, 0.25), c + Vector3(0.02, 0.1, 0) * hs))
			k.cylinder(Vector3.ZERO, 0.04 * hs, 0.15 * hs, 0.12 * hs, 10, col)
			k.pop()
		"bowler":
			k.cylinder(c + Vector3(0, 0.07, 0) * hs, 0.015 * hs, 0.19 * hs, 0.19 * hs, 10, col)
			k.sphere(c + Vector3(0, 0.1, 0) * hs, Vector3(0.125, 0.1, 0.125) * hs, col, 3, 9)
		"sunhat":
			k.cylinder(c + Vector3(0, 0.07, 0) * hs, 0.012 * hs, 0.27 * hs, 0.26 * hs, 12, col)
			k.cylinder(c + Vector3(0, 0.08, 0) * hs, 0.08 * hs, 0.13 * hs, 0.11 * hs, 10, col)
			k.torus(c + Vector3(0, 0.09, 0) * hs, 0.125 * hs, 0.012 * hs, 10, 3, _c("hat_band", Color("e8574a")))
		"beanie":
			k.sphere(c + Vector3(0, 0.05, -0.005) * hs, Vector3(r * 1.08, r * 0.85, r * 1.08), col, 3, 9)
			k.sphere(c + Vector3(0, 0.17, 0) * hs, Vector3(0.04, 0.04, 0.04) * hs, Color("f4f4f4"), 2, 6)
		"headband":
			k.torus(c + Vector3(0, 0.05, 0) * hs, r * 1.0, 0.016 * hs, 10, 3, col)
		"chef":
			k.cylinder(c + Vector3(0, 0.07, 0) * hs, 0.08 * hs, 0.125 * hs, 0.13 * hs, 10, Color("f8f8f8"))
			k.sphere(c + Vector3(0, 0.2, 0) * hs, Vector3(0.15, 0.08, 0.15) * hs, Color("f8f8f8"), 3, 8)
		"flatcap":
			k.sphere(c + Vector3(0, 0.06, -0.01) * hs, Vector3(r * 1.06, r * 0.6, r * 1.08), col, 3, 9)
			k.box(c + Vector3(0, 0.07, 0.13) * hs, Vector3(0.16, 0.015, 0.06) * hs, col.darkened(0.1))
		"bucket":
			k.cylinder(c + Vector3(0, 0.05, 0) * hs, 0.11 * hs, 0.17 * hs, 0.12 * hs, 10, col)
			k.cylinder(c + Vector3(0, 0.16, 0) * hs, 0.01 * hs, 0.12 * hs, 0.0, 10, col)
		"tophat":
			k.cylinder(c + Vector3(0, 0.08, 0) * hs, 0.012 * hs, 0.19 * hs, 0.19 * hs, 10, Color("1a1a1a"))
			k.cylinder(c + Vector3(0, 0.09, 0) * hs, 0.2 * hs, 0.115 * hs, 0.12 * hs, 10, Color("1a1a1a"))
			k.torus(c + Vector3(0, 0.12, 0) * hs, 0.118 * hs, 0.012 * hs, 10, 3, Color("a8322a"))
		"duck":
			# Easter egg: everybody gets a little duck on the head.
			k.sphere(c + Vector3(0, 0.16, 0) * hs, Vector3(0.08, 0.06, 0.1) * hs, Color("f2c230"), 3, 7)
			k.sphere(c + Vector3(0, 0.23, 0.06) * hs, Vector3(0.05, 0.05, 0.05) * hs, Color("f2c230"), 3, 6)
			k.box(c + Vector3(0, 0.22, 0.12) * hs, Vector3(0.04, 0.015, 0.04) * hs, Color("f28a2a"))


# --- Animation -------------------------------------------------------------------------

func set_mood(joy: float) -> void:
	var m := 1 if joy >= 45.0 else (0 if joy >= 25.0 else -1)
	if m == _mood_mouth:
		return
	_mood_mouth = m
	set_bone_scale("mouth_happy", Vector3.ONE if m == 1 else (Vector3(0.8, 0.3, 1.0) if m == 0 else Vector3.ZERO))
	set_bone_scale("mouth_sad", Vector3.ONE if m == -1 else Vector3.ZERO)


func pose(delta: float, st: Dictionary) -> void:
	var anim: String = st.get("anim", "idle")
	var speed: float = st.get("speed", 0.0)
	var sad: bool = st.get("sad", false)
	var tired: bool = st.get("tired", false)
	# Blinking.
	_blink -= delta
	var asleep := anim == "sleep"
	if _blink <= 0.0 and not _closed:
		_closed = true
		_blink = 0.13
	elif _blink <= 0.0:
		_closed = false
		_blink = randf_range(2.0, 5.0)
	set_bone_scale("eyes", Vector3(1, 0.12, 1) if (_closed or asleep) else Vector3.ONE)

	var moving := speed > 0.15 and anim in ["idle", "walk", "run", "phone", "eat", "photo", "look_map", "sad", "mime", "hold", "dog_walk", "carry"]
	if moving:
		_walk(delta, speed, anim)
	else:
		_idle(delta)
	match anim:
		"sit", "sleep", "swing", "blanket", "chess", "read":
			_sit(st, anim)
		"eat":
			_arm_to_mouth("r", 1.6)
		"drink":
			_arm_to_mouth("r", 0.8)
		"phone":
			rot("upper_arm_r", Vector3(-0.35, 0, -0.55))
			rot("forearm_r", Vector3(-2.35, 0.3, 0))
			rot("head", Vector3(0.05, 0, -0.12))
			if not moving:
				rot("upper_arm_l", Vector3(-0.3 + sin(time * 2.0) * 0.3, 0, 0.2))
				rot("forearm_l", Vector3(-0.9, 0, 0))
		"photo":
			rot("upper_arm_r", Vector3(-1.15, 0, 0.35))
			rot("forearm_r", Vector3(-1.45, 0, 0))
			rot("upper_arm_l", Vector3(-1.15, 0, -0.35))
			rot("forearm_l", Vector3(-1.45, 0, 0))
			rot("head", Vector3(0.1, 0, 0))
		"look_map", "hold":
			rot("upper_arm_r", Vector3(-0.8, 0, 0.25))
			rot("forearm_r", Vector3(-1.2, 0, 0))
			rot("upper_arm_l", Vector3(-0.8, 0, -0.25))
			rot("forearm_l", Vector3(-1.2, 0, 0))
			rot("head", Vector3(0.35, sin(time * 0.7) * 0.3, 0))
		"wave":
			rot("upper_arm_r", Vector3(0, 0, -2.5))
			rot("forearm_r", Vector3(0, 0, -0.3 + sin(time * 9.0) * 0.45))
		"cheer":
			var j := absf(sin(time * 6.0))
			rot("upper_arm_r", Vector3(0, 0, -2.6 + j * 0.2))
			rot("upper_arm_l", Vector3(0, 0, 2.6 - j * 0.2))
			offset("hips", Vector3(0, j * 0.12, 0))
		"throw":
			var t := fmod(time * 1.3, 1.0)
			var swing := -2.4 * smoothstep(0.0, 0.4, t) + 2.6 * smoothstep(0.4, 0.55, t)
			rot("upper_arm_r", Vector3(swing, 0, -0.2))
			rot("forearm_r", Vector3(-0.4, 0, 0))
		"feed":
			var t2 := fmod(time * 0.8, 1.0)
			rot("upper_arm_r", Vector3(-0.6 - sin(t2 * PI) * 0.6, 0, -0.15))
			rot("forearm_r", Vector3(-0.6, 0, 0))
			rot("chest", Vector3(0.15, 0, 0))
		"dance":
			var b := sin(time * 7.0)
			offset("hips", Vector3(b * 0.05, absf(b) * 0.06, 0))
			rot("hips", Vector3(0, 0, b * 0.15))
			rot("chest", Vector3(0, b * 0.3, -b * 0.15))
			rot("upper_arm_r", Vector3(0, 0, -1.8 - b * 0.6))
			rot("upper_arm_l", Vector3(0, 0, 1.8 - b * 0.6))
			rot("forearm_r", Vector3(-0.8, 0, 0))
			rot("forearm_l", Vector3(-0.8, 0, 0))
			rot("head", Vector3(0, 0, b * 0.2))
		"clap":
			var cl := absf(sin(time * 8.0))
			rot("upper_arm_r", Vector3(-1.0, 0, 0.2 + cl * 0.25))
			rot("upper_arm_l", Vector3(-1.0, 0, -0.2 - cl * 0.25))
			rot("forearm_r", Vector3(-0.9, 0, 0))
			rot("forearm_l", Vector3(-0.9, 0, 0))
		"point":
			rot("upper_arm_r", Vector3(-1.5, 0, -0.1))
		"talk":
			var tk := sin(time * 3.0)
			rot("upper_arm_r", Vector3(-0.5 - tk * 0.25, 0, -0.2))
			rot("forearm_r", Vector3(-0.9 + tk * 0.3, 0, 0))
			rot("upper_arm_l", Vector3(-0.3, 0, 0.15))
			rot("forearm_l", Vector3(-0.6 - tk * 0.2, 0, 0))
			rot("head", Vector3(sin(time * 2.1) * 0.08, 0, 0))
		"guitar":
			rot("upper_arm_l", Vector3(-0.6, 0, -0.5))
			rot("forearm_l", Vector3(-1.2, 0.6, 0))
			rot("upper_arm_r", Vector3(-0.35, 0, 0.35))
			rot("forearm_r", Vector3(-1.3 + sin(time * 10.0) * 0.15, 0, 0))
			rot("head", Vector3(0.15 + sin(time * 2.0) * 0.08, 0, sin(time * 1.3) * 0.1))
		"trumpet":
			rot("upper_arm_r", Vector3(-1.0, 0, 0.45))
			rot("forearm_r", Vector3(-1.7, 0, 0))
			rot("upper_arm_l", Vector3(-1.0, 0, -0.45))
			rot("forearm_l", Vector3(-1.6, 0, 0))
			rot("chest", Vector3(-0.1 + sin(time * 1.5) * 0.05, 0, 0))
		"sweep":
			var sw := sin(time * 3.0)
			rot("chest", Vector3(0.2, sw * 0.3, 0))
			rot("upper_arm_r", Vector3(-0.7, 0, 0.3 + sw * 0.2))
			rot("forearm_r", Vector3(-0.5, 0, 0))
			rot("upper_arm_l", Vector3(-0.5, 0, -0.2 + sw * 0.2))
			rot("forearm_l", Vector3(-0.8, 0, 0))
		"mime":
			var m := sin(time * 1.6)
			rot("upper_arm_r", Vector3(-1.4, 0, 0.1 + m * 0.2))
			rot("forearm_r", Vector3(-0.4, 0, 0))
			rot("upper_arm_l", Vector3(-1.4, 0, -0.1 + m * 0.2))
			rot("forearm_l", Vector3(-0.4, 0, 0))
			rot("hand_r", Vector3(-1.4, 0, 0))
			rot("hand_l", Vector3(-1.4, 0, 0))
			rot("head", Vector3(0, m * 0.4, 0))
		"stuck":
			var p := sin(time * 4.0)
			rot("upper_arm_r", Vector3(-1.5, 0, 0.3))
			rot("upper_arm_l", Vector3(-1.5, 0, -0.3))
			rot("forearm_r", Vector3(-0.2 + p * 0.1, 0, 0))
			rot("forearm_l", Vector3(-0.2 - p * 0.1, 0, 0))
			rot("hand_r", Vector3(-1.5, 0, 0))
			rot("hand_l", Vector3(-1.5, 0, 0))
			rot("chest", Vector3(0, p * 0.15, 0))
		"stretch":
			rot("thigh_l", Vector3(-0.7, 0, 0))
			rot("shin_l", Vector3(0.3, 0, 0))
			rot("thigh_r", Vector3(0.3, 0, 0))
			rot("chest", Vector3(0.4 + sin(time * 1.5) * 0.1, 0, 0))
			rot("upper_arm_r", Vector3(-1.0, 0, 0))
			rot("upper_arm_l", Vector3(-1.0, 0, 0))
			offset("hips", Vector3(0, -0.12, 0))
		"squat", "dig":
			rot("thigh_l", Vector3(-1.9, 0, 0.25))
			rot("thigh_r", Vector3(-1.9, 0, -0.25))
			rot("shin_l", Vector3(2.3, 0, 0))
			rot("shin_r", Vector3(2.3, 0, 0))
			offset("hips", Vector3(0, -0.45 * s, -0.12 * s))
			rot("chest", Vector3(0.35, 0, 0))
			if anim == "dig":
				rot("upper_arm_r", Vector3(-1.0 + sin(time * 5.0) * 0.4, 0, 0))
				rot("forearm_r", Vector3(-0.6, 0, 0))
		"juggle":
			var jg := sin(time * 6.0)
			rot("upper_arm_r", Vector3(-0.8 - jg * 0.3, 0, 0.1))
			rot("upper_arm_l", Vector3(-0.8 + jg * 0.3, 0, -0.1))
			rot("forearm_r", Vector3(-1.0, 0, 0))
			rot("forearm_l", Vector3(-1.0, 0, 0))
			rot("head", Vector3(-0.35, 0, 0))
		"lie":
			rot("root", Vector3(-PI / 2, 0, 0))
			offset("hips", Vector3(0, -0.75 * s, 0.0))
			rot("upper_arm_r", Vector3(0, 0, -0.3))
			rot("upper_arm_l", Vector3(0, 0, 0.3))
		"kick":
			var kk := fmod(time * 1.5, 1.0)
			rot("thigh_r", Vector3(-1.4 * sin(kk * PI), 0, 0))
		"carry":
			rot("upper_arm_r", Vector3(-0.9, 0, 0.3))
			rot("upper_arm_l", Vector3(-0.9, 0, -0.3))
			rot("forearm_r", Vector3(-0.9, 0, 0))
			rot("forearm_l", Vector3(-0.9, 0, 0))
		"dog_walk":
			rot("upper_arm_r", Vector3(-0.55, 0, -0.1))
			rot("forearm_r", Vector3(-0.3, 0, 0))
	# Mood overlays.
	if sad and not asleep:
		add_rot("chest", Vector3(0.3, 0, 0))
		add_rot("neck", Vector3(0.25, 0, 0))
		add_rot("head", Vector3(0.2, 0, 0))
	elif tired and not asleep:
		add_rot("chest", Vector3(0.14, 0, 0))
		add_rot("head", Vector3(0.1, 0, 0))
	var look_yaw: float = st.get("look_yaw", 0.0)
	if look_yaw != 0.0:
		add_rot("head", Vector3(0, clampf(look_yaw, -1.0, 1.0), 0))


func _walk(delta: float, speed: float, anim: String) -> void:
	var running := speed > 3.0
	var stride := 1.0 if not running else 1.5
	phase += delta * speed * (4.4 if not running else 3.3) / maxf(s, 0.6)
	var sp := sin(phase)
	var amp := clampf(speed / 1.4, 0.3, 1.0) * (0.55 if not running else 0.85) * stride * 0.75
	rot("thigh_l", Vector3(sp * amp, 0, 0))
	rot("thigh_r", Vector3(-sp * amp, 0, 0))
	rot("shin_l", Vector3(maxf(0.0, -cos(phase)) * amp * 1.3 + 0.05, 0, 0))
	rot("shin_r", Vector3(maxf(0.0, cos(phase)) * amp * 1.3 + 0.05, 0, 0))
	var arm := amp * (0.7 if not running else 1.0)
	rot("upper_arm_l", Vector3(-sp * arm, 0, 0.08))
	rot("upper_arm_r", Vector3(sp * arm, 0, -0.08))
	rot("forearm_l", Vector3(-0.25 - (0.9 if running else 0.0), 0, 0))
	rot("forearm_r", Vector3(-0.25 - (0.9 if running else 0.0), 0, 0))
	offset("hips", Vector3(0, absf(sp) * 0.035 * stride - 0.015, 0))
	rot("hips", Vector3(0, sp * 0.08, 0))
	rot("chest", Vector3(0.22 if running else 0.03, -sp * 0.1, 0))
	if anim == "dog_walk":
		rot("upper_arm_r", Vector3(-0.55, 0, -0.1))


func _idle(_delta: float) -> void:
	var b := sin(time * 1.6)
	rot("chest", Vector3(b * 0.015, 0, 0))
	rot("upper_arm_l", Vector3(0.02, 0, 0.09 + b * 0.01))
	rot("upper_arm_r", Vector3(0.02, 0, -0.09 - b * 0.01))
	rot("forearm_l", Vector3(-0.12, 0, 0))
	rot("forearm_r", Vector3(-0.12, 0, 0))
	rot("hips", Vector3(0, 0, sin(time * 0.4) * 0.025))
	rot("head", Vector3(0, sin(time * 0.37) * 0.25, 0))


func _sit(st: Dictionary, anim: String) -> void:
	var seat_h: float = st.get("seat_height", 0.47)
	if anim == "blanket":
		rot("thigh_l", Vector3(-1.45, 0.3, 0.35))
		rot("thigh_r", Vector3(-1.45, -0.3, -0.35))
		rot("shin_l", Vector3(2.3, 0, 0))
		rot("shin_r", Vector3(2.3, 0, 0))
	else:
		rot("thigh_l", Vector3(-1.5, 0, 0.06))
		rot("thigh_r", Vector3(-1.5, 0, -0.06))
		rot("shin_l", Vector3(1.45, 0, 0))
		rot("shin_r", Vector3(1.45, 0, 0))
	offset("hips", Vector3(0, seat_h + 0.07 - 0.93 * s, -0.04))
	rot("upper_arm_l", Vector3(-0.35, 0, 0.1))
	rot("upper_arm_r", Vector3(-0.35, 0, -0.1))
	rot("forearm_l", Vector3(-0.85, 0, 0))
	rot("forearm_r", Vector3(-0.85, 0, 0))
	rot("chest", Vector3(-0.05, 0, 0))
	match anim:
		"sleep":
			rot("neck", Vector3(0.35, 0, 0.1))
			rot("head", Vector3(0.35, 0, 0.25))
			rot("chest", Vector3(0.12 + sin(time * 1.2) * 0.03, 0, 0))
		"swing":
			var sw := sin(time * 2.0)
			rot("shin_l", Vector3(1.45 - sw * 0.9, 0, 0))
			rot("shin_r", Vector3(1.45 - sw * 0.9, 0, 0))
			rot("upper_arm_l", Vector3(-2.6, 0, 0.1))
			rot("upper_arm_r", Vector3(-2.6, 0, -0.1))
			rot("forearm_l", Vector3(0.2, 0, 0))
			rot("forearm_r", Vector3(0.2, 0, 0))
			rot("chest", Vector3(sw * 0.2, 0, 0))
		"chess":
			rot("chest", Vector3(0.35, 0, 0))
			rot("head", Vector3(0.3, 0, 0))
			rot("upper_arm_r", Vector3(-0.9, 0, -0.1))
			rot("forearm_r", Vector3(-1.0 + sin(time * 0.5) * 0.3, 0, 0))
			rot("upper_arm_l", Vector3(-0.5, 0, 0.1))
			rot("forearm_l", Vector3(-1.9, 0, 0))
		"read":
			rot("upper_arm_r", Vector3(-0.75, 0, 0.3))
			rot("forearm_r", Vector3(-1.25, 0, 0))
			rot("upper_arm_l", Vector3(-0.75, 0, -0.3))
			rot("forearm_l", Vector3(-1.25, 0, 0))
			rot("head", Vector3(0.35, 0, 0))


func _arm_to_mouth(side: String, period: float) -> void:
	var t := fmod(time / period, 1.0)
	var lift := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.6, 0.85, t))
	var x := 1.0 if side == "l" else -1.0
	rot("upper_arm_" + side, Vector3(-0.35 - lift * 0.5, 0, x * 0.1))
	rot("forearm_" + side, Vector3(-0.9 - lift * 1.35, x * lift * 0.4, 0))
	if lift > 0.8:
		rot("head", Vector3(-0.05, 0, 0))

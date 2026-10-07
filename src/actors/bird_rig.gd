class_name BirdRig
extends Rig
## Ducks (drake, hen, duckling), the goose Gustav, pigeons, a heron and an owl.

const PRESETS := {
	"drake": {"size": 0.3, "neck": 0.1, "leg": 0.08, "body": "8f8f8a", "breast": "6b3a2a", "head": "1f6b3a",
		"beak": "e8c040", "wing": "a8a59c", "tail": "2a2a2a", "ring": true, "speculum": "3a5ad0"},
	"hen": {"size": 0.28, "neck": 0.09, "leg": 0.08, "body": "8a6a44", "breast": "9a7a54", "head": "7a5a3a",
		"beak": "d88a3a", "wing": "6a5034", "tail": "5a4030", "speckles": true, "speculum": "3a5ad0"},
	"duckling": {"size": 0.12, "neck": 0.04, "leg": 0.035, "body": "f2d44a", "breast": "f6e07a", "head": "f2d44a",
		"beak": "e88a2a", "wing": "e8c03a", "tail": "e8c03a"},
	"goose": {"size": 0.4, "neck": 0.28, "leg": 0.13, "body": "f4f4f0", "breast": "f8f8f4", "head": "f4f4f0",
		"beak": "f08a2a", "wing": "e4e4dc", "tail": "e4e4dc"},
	"pigeon": {"size": 0.17, "neck": 0.05, "leg": 0.05, "body": "8a8f98", "breast": "9a8a9a", "head": "6a7080",
		"beak": "3a3a3a", "wing": "a0a6ae", "tail": "4a4e58", "neck_shine": true},
	"heron": {"size": 0.38, "neck": 0.5, "leg": 0.75, "body": "9aa0a6", "breast": "dcdcd8", "head": "f2f2ee",
		"beak": "e0b040", "wing": "7a8088", "tail": "6a7078", "crest": true},
	"owl": {"size": 0.22, "neck": 0.02, "leg": 0.04, "body": "8a6a44", "breast": "c9a87a", "head": "8a6a44",
		"beak": "e0b040", "wing": "6a5034", "tail": "6a5034", "owl": true},
}

var p := {}
var kind := ""


func build(preset: String) -> void:
	kind = preset
	p = PRESETS[preset]
	var sz: float = p["size"]
	var leg: float = p["leg"]
	var nk: float = p["neck"]
	var body := Color(p["body"])
	var breast := Color(p["breast"])
	var head_c := Color(p["head"])
	var beak := Color(p["beak"])
	var wing := Color(p["wing"])
	var body_y := leg + sz * 0.45
	var owl: bool = p.get("owl", false)
	height = body_y + sz * 0.5 + nk + sz * 0.4
	var rb := RigBuilder.new()
	rb.bone("root", "", Vector3.ZERO)
	rb.bone("body", "root", Vector3(0, body_y, 0))
	var neck_p := Vector3(0, body_y + sz * 0.25, sz * 0.45) if not owl else Vector3(0, body_y + sz * 0.45, 0)
	rb.bone("neck", "body", neck_p)
	var head_p := neck_p + Vector3(0, nk + sz * 0.15, nk * 0.15)
	if kind == "heron":
		head_p = neck_p + Vector3(0, nk, nk * 0.25)
	rb.bone("head", "neck", head_p)
	rb.bone("eyes", "head", head_p + Vector3(0, sz * 0.05, sz * 0.12))
	rb.bone("wing_l", "body", Vector3(sz * 0.38, body_y + sz * 0.15, sz * 0.1))
	rb.bone("wing_r", "body", Vector3(-sz * 0.38, body_y + sz * 0.15, sz * 0.1))
	rb.bone("tail", "body", Vector3(0, body_y + sz * 0.1, -sz * 0.6))
	rb.bone("leg_l", "body", Vector3(sz * 0.15, leg, 0))
	rb.bone("leg_r", "body", Vector3(-sz * 0.15, leg, 0))
	var k := rb.on("body")
	if owl:
		k.sphere(Vector3(0, body_y, 0), Vector3(sz * 0.55, sz * 0.8, sz * 0.5), body, 4, 8, 0.0, 0, breast)
	else:
		k.sphere(Vector3(0, body_y, -sz * 0.05), Vector3(sz * 0.42, sz * 0.38, sz * 0.62), body, 4, 9, 0.0, 0, breast)
		k.sphere(Vector3(0, body_y + sz * 0.02, sz * 0.32), Vector3(sz * 0.36, sz * 0.36, sz * 0.32), breast, 3, 8)
	if p.get("speckles", false):
		for i in 10:
			var a := i * 0.7
			k.box(Vector3(cos(a) * sz * 0.35, body_y + sin(a * 1.7) * sz * 0.2, -sz * 0.1 + sin(a) * sz * 0.4), Vector3(0.025, 0.012, 0.03), body.darkened(0.35))
	k = rb.on("neck")
	if nk > 0.03:
		k.rod(neck_p - Vector3(0, sz * 0.15, 0), head_p, sz * 0.17, sz * 0.13, 7, head_c if kind != "heron" else Color("f2f2ee"))
	if p.get("ring", false):
		k.torus(neck_p + Vector3(0, nk * 0.3, 0), sz * 0.17, sz * 0.03, 8, 3, Color("f4f4f4"))
	if p.get("neck_shine", false):
		k.torus(neck_p + Vector3(0, nk * 0.4, 0), sz * 0.19, sz * 0.05, 8, 3, Color("4a8a7a"))
	k = rb.on("head")
	var hr := sz * (0.24 if not owl else 0.45)
	k.sphere(head_p, Vector3(hr, hr * 1.05, hr * 1.1), head_c, 4, 8)
	if owl:
		for x: float in [-1.0, 1.0]:
			k.sphere(head_p + Vector3(x * hr * 0.42, hr * 0.15, hr * 0.75), Vector3(hr * 0.42, hr * 0.42, hr * 0.15), breast, 3, 7)
			k.cylinder(head_p + Vector3(x * hr * 0.6, hr * 0.75, 0), hr * 0.5, hr * 0.2, 0.0, 4, body)
	var beak_len := sz * (0.3 if kind in ["drake", "hen", "duckling", "goose"] else (0.6 if kind == "heron" else 0.12))
	if kind in ["drake", "hen", "duckling", "goose"]:
		k.box(head_p + Vector3(0, -hr * 0.25, hr * 0.9 + beak_len * 0.5), Vector3(hr * 0.75, hr * 0.22, beak_len), beak)
	else:
		k.rod(head_p + Vector3(0, -hr * 0.1, hr * 0.8), head_p + Vector3(0, -hr * 0.25, hr * 0.8 + beak_len), hr * 0.25, 0.0, 5, beak)
	if p.get("crest", false):
		k.rod(head_p + Vector3(0, hr * 0.3, -hr * 0.5), head_p + Vector3(0, hr * 0.1, -hr * 2.4), 0.012, 0.004, 3, Color("2a2a2a"))
	k = rb.on("eyes")
	for x: float in [-1.0, 1.0]:
		var ep := head_p + Vector3(x * hr * (0.42 if owl else 0.7), hr * 0.2, hr * (0.85 if owl else 0.45))
		if owl:
			k.sphere(ep, Vector3(hr * 0.22, hr * 0.22, hr * 0.08), Color("f2c230"), 3, 7)
			k.sphere(ep + Vector3(0, 0, hr * 0.05), Vector3(hr * 0.11, hr * 0.11, hr * 0.05), Color("111111"), 2, 5)
		else:
			k.sphere(ep, Vector3(hr * 0.16, hr * 0.16, hr * 0.12), Color("111111"), 2, 5)
	for side: String in ["l", "r"]:
		var x := 1.0 if side == "l" else -1.0
		k = rb.on("wing_" + side)
		var w0 := Vector3(x * sz * 0.38, body_y + sz * 0.15, sz * 0.1)
		k.push(Transform3D(Basis(), w0))
		k.sphere(Vector3(x * sz * 0.02, -sz * 0.05, -sz * 0.3), Vector3(sz * 0.08, sz * 0.25, sz * 0.48), wing, 3, 6)
		if p.has("speculum"):
			k.box(Vector3(x * sz * 0.09, -sz * 0.05, -sz * 0.25), Vector3(0.01, sz * 0.1, sz * 0.2), Color(p["speculum"]))
		k.pop()
		k = rb.on("leg_" + side)
		var hip := Vector3(x * sz * 0.15, leg + sz * 0.1, 0)
		var foot := Vector3(x * sz * 0.15, 0.005, 0.0)
		var leg_col := Color("e88a2a") if kind in ["drake", "hen", "duckling", "goose"] else (Color("d0a080") if kind == "pigeon" else Color("4a4a40"))
		k.rod(hip, foot, sz * 0.04 + 0.006, sz * 0.03 + 0.004, 4, leg_col)
		if kind in ["drake", "hen", "duckling", "goose"]:
			k.prism(PackedVector2Array([Vector2(foot.x - sz * 0.1, foot.z + sz * 0.15), Vector2(foot.x + sz * 0.1, foot.z + sz * 0.15),
				Vector2(foot.x, foot.z - sz * 0.02)]), 0.0, 0.012, leg_col)
	k = rb.on("tail")
	k.cylinder(Vector3(0, body_y + sz * 0.1, -sz * 0.55), sz * 0.1, sz * 0.18, 0.0, 5, Color(p["tail"]))
	if kind == "drake":
		k.torus(Vector3(0, body_y + sz * 0.3, -sz * 0.55), sz * 0.05, sz * 0.015, 6, 3, Color("1a1a1a"))
	hand_bone = "head"
	_init_skeleton(rb.finish())


func pose(delta: float, st: Dictionary) -> void:
	var anim: String = st.get("anim", "idle")
	var speed: float = st.get("speed", 0.0)
	var swimming: bool = st.get("swimming", false)
	set_bone_scale("eyes", Vector3(1, 0.12, 1) if anim == "sleep" or fmod(time, 5.1) < 0.1 else Vector3.ONE)
	if anim == "fly":
		var f := sin(time * 16.0)
		rot("wing_l", Vector3(0, 0, -0.3 + f * 1.1))
		rot("wing_r", Vector3(0, 0, 0.3 - f * 1.1))
		rot("leg_l", Vector3(0.9, 0, 0))
		rot("leg_r", Vector3(0.9, 0, 0))
		rot("body", Vector3(-0.15, 0, 0))
		return
	if swimming:
		var bob := sin(time * 2.0) * 0.012
		offset("body", Vector3(0, -float(p["leg"]) - float(p["size"]) * 0.25 + bob, 0))
		rot("leg_l", Vector3(sin(time * 6.0) * 0.6 * minf(speed, 1.0), 0, 0))
		rot("leg_r", Vector3(-sin(time * 6.0) * 0.6 * minf(speed, 1.0), 0, 0))
		rot("tail", Vector3(0, sin(time * 3.0) * 0.2, 0))
	elif speed > 0.05:
		phase += delta * (8.0 + speed * 8.0)
		var sp := sin(phase)
		rot("leg_l", Vector3(sp * 0.6, 0, 0))
		rot("leg_r", Vector3(-sp * 0.6, 0, 0))
		rot("body", Vector3(0, 0, sp * (0.12 if kind in ["drake", "hen", "duckling", "goose"] else 0.04)))
		if kind == "pigeon":
			rot("neck", Vector3(sin(phase * 2.0) * 0.3, 0, 0))
	else:
		rot("head", Vector3(sin(time * 0.6) * 0.1, sin(time * 0.43) * 0.6, 0))
	match anim:
		"eat", "peck":
			var pk := absf(sin(time * 7.0))
			rot("neck", Vector3(0.9 * pk + 0.3, 0, 0))
			rot("head", Vector3(0.6 * pk, 0, 0))
		"quack":
			var q := absf(sin(time * 8.0))
			rot("neck", Vector3(-0.3 * q, 0, 0))
			rot("head", Vector3(-0.4 * q, 0, 0))
			rot("wing_l", Vector3(0, 0, -0.3 * q))
			rot("wing_r", Vector3(0, 0, 0.3 * q))
		"sleep":
			rot("neck", Vector3(-0.9, 0, 0))
			rot("head", Vector3(-0.3, 2.4, 0))
			offset("body", Vector3(0, -float(p["leg"]) * 0.8, 0) if not swimming else Vector3(0, -float(p["leg"]) - float(p["size"]) * 0.25, 0))
		"flap":
			var fl := sin(time * 14.0)
			rot("wing_l", Vector3(0, 0, -0.4 + fl * 0.8))
			rot("wing_r", Vector3(0, 0, 0.4 - fl * 0.8))
		"fish":
			# Heron strike.
			var t := fmod(time, 3.0)
			var strike := smoothstep(2.4, 2.55, t) * (1.0 - smoothstep(2.7, 2.95, t))
			rot("neck", Vector3(0.4 + strike * 1.2, 0, 0))
			rot("head", Vector3(0.5 + strike * 0.5, 0, 0))
		"hoot":
			rot("head", Vector3(-0.2, sin(time * 0.7) * 1.4, 0))
			offset("body", Vector3(0, sin(time * 3.0) * 0.01, 0))
		"preen":
			rot("neck", Vector3(0.6, 1.4, 0))
			rot("head", Vector3(0.4, 0.8, 0))
	var look_yaw: float = st.get("look_yaw", 0.0)
	if look_yaw != 0.0:
		add_rot("head", Vector3(0, clampf(look_yaw, -1.2, 1.2), 0))

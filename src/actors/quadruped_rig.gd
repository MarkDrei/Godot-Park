class_name QuadrupedRig
extends Rig
## Four-legged animals built from a parameter preset: dogs, cats, mice, squirrels,
## hedgehogs and foxes. Faces +Z.

const PRESETS := {
	"dachshund": {"length": 0.62, "leg": 0.13, "width": 0.17, "body_h": 0.2, "head": 0.11, "snout": 0.11,
		"ears": "floppy", "tail": "thin", "main": "8a4a22", "belly": "a8642e", "accent": "5a2e14"},
	"poodle": {"length": 0.42, "leg": 0.32, "width": 0.2, "body_h": 0.24, "head": 0.11, "snout": 0.09,
		"ears": "floppy", "tail": "pompom", "main": "f2efe8", "belly": "f2efe8", "accent": "e8e2d6", "fluffy": true},
	"shepherd": {"length": 0.72, "leg": 0.4, "width": 0.24, "body_h": 0.3, "head": 0.14, "snout": 0.15,
		"ears": "pointy", "tail": "bushy", "main": "3a2a1e", "belly": "b7854a", "accent": "b7854a"},
	"pug": {"length": 0.36, "leg": 0.17, "width": 0.22, "body_h": 0.24, "head": 0.13, "snout": 0.03,
		"ears": "small", "tail": "curly", "main": "d6b98a", "belly": "e2c9a0", "accent": "2a2420"},
	"labrador": {"length": 0.7, "leg": 0.38, "width": 0.26, "body_h": 0.3, "head": 0.14, "snout": 0.13,
		"ears": "floppy", "tail": "thin", "main": "e2b968", "belly": "ecc884", "accent": "c99a48"},
	"terrier": {"length": 0.45, "leg": 0.22, "width": 0.18, "body_h": 0.22, "head": 0.11, "snout": 0.1,
		"ears": "pointy", "tail": "short", "main": "f4f2ec", "belly": "f4f2ec", "accent": "9a6a3a"},
	"cat": {"length": 0.46, "leg": 0.23, "width": 0.15, "body_h": 0.19, "head": 0.1, "snout": 0.03,
		"ears": "cat", "tail": "long", "main": "d9822b", "belly": "f2d3a8", "accent": "a85a1a", "stripes": true},
	"cat_black": {"length": 0.46, "leg": 0.23, "width": 0.15, "body_h": 0.19, "head": 0.1, "snout": 0.03,
		"ears": "cat", "tail": "long", "main": "222226", "belly": "f4f4f4", "accent": "f4f4f4", "socks": true},
	"mouse": {"length": 0.08, "leg": 0.025, "width": 0.045, "body_h": 0.05, "head": 0.03, "snout": 0.03,
		"ears": "round", "tail": "thin_long", "main": "8a8580", "belly": "c9c2b8", "accent": "e8a8a8"},
	"squirrel": {"length": 0.2, "leg": 0.07, "width": 0.08, "body_h": 0.1, "head": 0.055, "snout": 0.03,
		"ears": "tufted", "tail": "squirrel", "main": "b5542a", "belly": "f2e2c8", "accent": "8a3a1a"},
	"hedgehog": {"length": 0.24, "leg": 0.04, "width": 0.14, "body_h": 0.13, "head": 0.05, "snout": 0.06,
		"ears": "round", "tail": "none", "main": "7a6048", "belly": "c9b08a", "accent": "4a3a2a", "spikes": true},
	"fox": {"length": 0.55, "leg": 0.3, "width": 0.17, "body_h": 0.22, "head": 0.11, "snout": 0.13,
		"ears": "pointy", "tail": "fox", "main": "d8642a", "belly": "f4ece0", "accent": "2a2420"},
}

var p := {}
var kind := ""
var _wag := 0.0


func build(preset: String, overrides := {}) -> void:
	kind = preset
	p = PRESETS[preset].duplicate()
	for k: String in overrides:
		p[k] = overrides[k]
	var L: float = p["length"]
	var leg: float = p["leg"]
	var W: float = p["width"]
	var bh: float = p["body_h"]
	var hr: float = p["head"]
	var main := Color(p["main"])
	var belly := Color(p["belly"])
	var accent := Color(p["accent"])
	var body_y := leg + bh * 0.5
	height = body_y + bh * 0.5 + hr * 2.0
	var rb := RigBuilder.new()
	rb.bone("root", "", Vector3.ZERO)
	rb.bone("body", "root", Vector3(0, body_y, -L * 0.15))
	rb.bone("chest", "body", Vector3(0, body_y, L * 0.2))
	var neck_p := Vector3(0, body_y + bh * 0.3, L * 0.45)
	rb.bone("neck", "chest", neck_p)
	var head_p := neck_p + Vector3(0, hr * 1.2, hr * 0.6)
	rb.bone("head", "neck", head_p)
	rb.bone("eyes", "head", head_p + Vector3(0, hr * 0.25, hr * 0.8))
	rb.bone("ear_l", "head", head_p + Vector3(hr * 0.6, hr * 0.7, 0))
	rb.bone("ear_r", "head", head_p + Vector3(-hr * 0.6, hr * 0.7, 0))
	var tail_p := Vector3(0, body_y + bh * 0.25, -L * 0.5)
	rb.bone("tail", "body", tail_p)
	rb.bone("tail2", "tail", tail_p + Vector3(0, 0.0, -L * 0.25))
	rb.bone("leg_fl", "chest", Vector3(W * 0.42, leg, L * 0.33))
	rb.bone("leg_fr", "chest", Vector3(-W * 0.42, leg, L * 0.33))
	rb.bone("leg_bl", "body", Vector3(W * 0.42, leg, -L * 0.33))
	rb.bone("leg_br", "body", Vector3(-W * 0.42, leg, -L * 0.33))

	var fluffy: bool = p.get("fluffy", false)
	var k := rb.on("body")
	if fluffy:
		k.sphere(Vector3(0, body_y, -L * 0.2), Vector3(W * 0.55, bh * 0.45, L * 0.32), main, 3, 8, 0.15, 3)
	else:
		k.sphere(Vector3(0, body_y, -L * 0.12), Vector3(W * 0.5, bh * 0.5, L * 0.42), main, 4, 9, 0.0, 0, belly)
	if p.get("spikes", false):
		for i in 26:
			var a := TAU * i / 13.0
			var row := i / 13
			var dir := Vector3(cos(a) * 0.8, 0.6 + row * 0.3, sin(a) * 0.9).normalized()
			var base := Vector3(0, body_y + bh * 0.1, -L * 0.05) + Vector3(dir.x * W * 0.45, dir.y * bh * 0.4, dir.z * L * 0.35)
			k.rod(base, base + dir * 0.06, 0.018, 0.0, 3, accent if i % 3 == 0 else main.darkened(0.2))
	if p.get("stripes", false):
		for i in 4:
			k.box(Vector3(0, body_y + bh * 0.42, -L * 0.3 + i * L * 0.16), Vector3(W * 0.7, 0.02, 0.035), accent)
	k = rb.on("chest")
	if fluffy:
		k.sphere(Vector3(0, body_y + 0.02, L * 0.18), Vector3(W * 0.6, bh * 0.55, L * 0.25), main, 3, 8, 0.15, 5)
	else:
		k.sphere(Vector3(0, body_y, L * 0.2), Vector3(W * 0.5, bh * 0.52, L * 0.3), main, 4, 9, 0.0, 0, belly)
	if p.has("collar"):
		k.torus(neck_p + Vector3(0, -0.01, -0.02), W * 0.33, 0.012, 10, 3, Color(p["collar"]))
	k = rb.on("neck")
	k.rod(neck_p - Vector3(0, bh * 0.15, 0.02), head_p, hr * 0.55, hr * 0.5, 7, main)
	# Head.
	k = rb.on("head")
	k.sphere(head_p, Vector3(hr * 0.9, hr * 0.85, hr * 0.95), main, 4, 8, 0.0, 0, belly if kind == "pug" else Color(0, 0, 0, 0))
	if fluffy:
		k.sphere(head_p + Vector3(0, hr * 0.8, -hr * 0.1), Vector3(hr * 0.75, hr * 0.6, hr * 0.75), main, 3, 7, 0.15, 7)
	var snout: float = p["snout"]
	var snout_col := accent if kind in ["pug", "fox"] else belly
	if kind == "fox":
		snout_col = belly
	k.rod(head_p + Vector3(0, -hr * 0.2, hr * 0.5), head_p + Vector3(0, -hr * 0.3, hr * 0.75 + snout), hr * 0.5, hr * 0.32, 7, snout_col if kind != "squirrel" else main)
	var nose_tip := head_p + Vector3(0, -hr * 0.25, hr * 0.78 + snout)
	k.sphere(nose_tip, Vector3(hr * 0.2, hr * 0.15, hr * 0.12), Color("1e1a18") if kind != "mouse" else Color("e8a8a8"), 2, 5)
	if kind == "pug":
		k.sphere(head_p + Vector3(0, -hr * 0.15, hr * 0.65), Vector3(hr * 0.6, hr * 0.45, hr * 0.3), accent, 3, 6)
	if kind in ["cat", "cat_black", "mouse"]:
		for x: float in [-1.0, 1.0]:
			for wy: float in [-0.02, 0.0]:
				k.beam(nose_tip + Vector3(x * hr * 0.15, wy * hr * 4, -hr * 0.05), nose_tip + Vector3(x * hr * 1.3, wy * hr * 6 + hr * 0.05, -hr * 0.2), Vector2(0.004, 0.004) * (hr / 0.1), Color("f4f4f4"))
	k = rb.on("eyes")
	var eye_col := Color("3fa04a") if kind in ["cat", "cat_black"] else Color("1a1410")
	for x: float in [-1.0, 1.0]:
		var ep := head_p + Vector3(x * hr * 0.45, hr * 0.25, hr * 0.72)
		k.sphere(ep, Vector3(hr * 0.17, hr * 0.19, hr * 0.12), Color("fbfbf8") if kind in ["cat", "cat_black", "pug"] else eye_col, 2, 5)
		if kind in ["cat", "cat_black", "pug"]:
			k.sphere(ep + Vector3(0, 0, hr * 0.06), Vector3(hr * 0.12, hr * 0.15, hr * 0.08), eye_col, 2, 5)
		k.sphere(ep + Vector3(x * -hr * 0.04, hr * 0.06, hr * 0.1), Vector3(hr * 0.04, hr * 0.04, hr * 0.03), Color.WHITE, 2, 4)
	for side: String in ["l", "r"]:
		var x := 1.0 if side == "l" else -1.0
		k = rb.on("ear_" + side)
		var eb := head_p + Vector3(x * hr * 0.6, hr * 0.7, 0)
		match p["ears"]:
			"floppy":
				k.sphere(eb + Vector3(x * hr * 0.25, -hr * 0.6, 0), Vector3(hr * 0.22, hr * 0.7, hr * 0.38), accent if kind != "poodle" else main, 3, 6)
			"pointy", "cat":
				k.cylinder(eb, hr * (0.95 if p["ears"] == "pointy" else 0.75), hr * 0.32, 0.0, 4, main, true, accent)
				if kind == "fox":
					k.cylinder(eb + Vector3(0, hr * 0.55, 0), hr * 0.35, hr * 0.14, 0.0, 4, accent)
			"tufted":
				k.cylinder(eb, hr * 0.8, hr * 0.28, 0.0, 4, main)
				k.cylinder(eb + Vector3(0, hr * 0.7, 0), hr * 0.35, hr * 0.12, 0.0, 4, accent)
			"round":
				k.sphere(eb + Vector3(0, hr * 0.2, 0), Vector3(hr * 0.45, hr * 0.45, hr * 0.12), accent if kind == "mouse" else main, 3, 7)
			"small":
				k.sphere(eb + Vector3(x * hr * 0.1, 0, 0), Vector3(hr * 0.3, hr * 0.25, hr * 0.12), accent, 2, 5)
	# Tail.
	k = rb.on("tail")
	var t2 := tail_p + Vector3(0, 0, -L * 0.25)
	match p["tail"]:
		"thin":
			k.rod(tail_p, t2, W * 0.12, W * 0.08, 5, main)
		"thin_long":
			k.rod(tail_p, t2 + Vector3(0, -0.01, -L * 0.2), 0.006, 0.004, 4, Color("e8a8a8"))
		"long":
			k.rod(tail_p, t2, W * 0.13, W * 0.11, 5, main)
		"bushy", "fox":
			k.rod(tail_p, t2, W * 0.16, W * 0.22, 6, main)
		"short":
			k.rod(tail_p, tail_p + Vector3(0, L * 0.1, -L * 0.06), W * 0.12, W * 0.08, 5, main)
		"curly":
			k.torus(tail_p + Vector3(0, W * 0.25, -W * 0.05), W * 0.15, W * 0.07, 8, 4, main)
		"pompom":
			k.rod(tail_p, tail_p + Vector3(0, L * 0.15, -L * 0.1), 0.015, 0.012, 4, main)
			k.sphere(tail_p + Vector3(0, L * 0.18, -L * 0.12), Vector3(0.05, 0.05, 0.05), main, 3, 6, 0.15, 9)
		"squirrel":
			k.sphere(tail_p + Vector3(0, L * 0.6, -L * 0.35), Vector3(W * 0.55, L * 0.8, W * 0.7), main, 4, 7, 0.12, 4)
	k = rb.on("tail2")
	match p["tail"]:
		"thin", "long":
			k.rod(t2, t2 + Vector3(0, 0, -L * 0.25), W * 0.08 if p["tail"] == "thin" else W * 0.11, W * 0.04, 5, main if kind != "cat_black" else main)
		"bushy":
			k.rod(t2, t2 + Vector3(0, 0, -L * 0.22), W * 0.22, W * 0.1, 6, main)
		"fox":
			k.rod(t2, t2 + Vector3(0, 0, -L * 0.25), W * 0.22, W * 0.06, 6, main)
			k.sphere(t2 + Vector3(0, 0, -L * 0.25), Vector3(W * 0.1, W * 0.1, W * 0.12), Color("f4ece0"), 3, 5)
	# Legs.
	for name: String in ["leg_fl", "leg_fr", "leg_bl", "leg_br"]:
		k = rb.on(name)
		var x := 1.0 if name.ends_with("l") else -1.0
		var front := name.begins_with("leg_f")
		var top := Vector3(x * W * 0.42, leg + bh * 0.2, L * (0.33 if front else -0.33))
		var foot := Vector3(top.x, 0.0, top.z + 0.01)
		var leg_col := main
		if p.get("socks", false):
			leg_col = belly
		var r := W * (0.16 if not fluffy else 0.2)
		k.rod(top, foot + Vector3(0, r * 0.4, 0), r, r * 0.8, 6, main)
		k.sphere(foot + Vector3(0, r * 0.45, r * 0.4), Vector3(r * 1.05, r * 0.55, r * 1.3), leg_col, 2, 6)
		if fluffy:
			k.sphere(foot + Vector3(0, leg * 0.35, 0), Vector3(r * 1.5, r * 1.6, r * 1.5), main, 3, 6, 0.15, 11)
	hand_bone = "head"
	_init_skeleton(rb.finish())


func pose(delta: float, st: Dictionary) -> void:
	var anim: String = st.get("anim", "idle")
	var speed: float = st.get("speed", 0.0)
	var L: float = p["length"]
	var leg_len: float = p["leg"]
	var happy: bool = st.get("happy", true)
	_wag += delta * (14.0 if happy else 5.0)
	var wag := sin(_wag) * (0.6 if happy else 0.15)
	set_bone_scale("eyes", Vector3(1, 0.12, 1) if anim in ["sleep"] or fmod(time, 4.3) < 0.12 else Vector3.ONE)
	if speed > 0.08 and anim in ["idle", "walk", "run", "crouch", "follow"]:
		var gait := clampf(speed / maxf(L * 3.5, 0.3), 0.2, 3.0)
		phase += delta * (5.0 + speed * 9.0 / maxf(leg_len * 4.0, 0.25))
		var sp := sin(phase)
		var a := clampf(0.25 + gait * 0.25, 0.25, 0.75)
		if speed > L * 6.0 and kind not in ["dachshund", "hedgehog"]:
			# Gallop / bound: front pair and back pair.
			rot("leg_fl", Vector3(sp * a * 1.1, 0, 0))
			rot("leg_fr", Vector3(sin(phase + 0.3) * a * 1.1, 0, 0))
			rot("leg_bl", Vector3(-sp * a * 1.1, 0, 0))
			rot("leg_br", Vector3(-sin(phase + 0.3) * a * 1.1, 0, 0))
			rot("body", Vector3(sp * 0.12, 0, 0))
			offset("body", Vector3(0, absf(sp) * leg_len * 0.25, 0))
		else:
			rot("leg_fl", Vector3(sp * a, 0, 0))
			rot("leg_br", Vector3(sp * a, 0, 0))
			rot("leg_fr", Vector3(-sp * a, 0, 0))
			rot("leg_bl", Vector3(-sp * a, 0, 0))
			offset("body", Vector3(0, absf(sp) * leg_len * 0.06, 0))
		rot("tail", Vector3(0.3, wag * 0.6, 0))
		rot("head", Vector3(0.05, sin(phase * 0.5) * 0.05, 0))
	else:
		rot("tail", Vector3(0.2, wag, 0))
		rot("head", Vector3(sin(time * 0.5) * 0.05, sin(time * 0.31) * 0.4, 0))
		rot("chest", Vector3(sin(time * 2.2) * 0.02, 0, 0))
	match anim:
		"sit":
			rot("body", Vector3(-0.55, 0, 0))
			offset("body", Vector3(0, -leg_len * 0.45, -L * 0.05))
			rot("leg_bl", Vector3(-1.0, 0, 0))
			rot("leg_br", Vector3(-1.0, 0, 0))
			rot("leg_fl", Vector3(0.5, 0, 0))
			rot("leg_fr", Vector3(0.5, 0, 0))
			rot("neck", Vector3(-0.1, 0, 0))
			rot("head", Vector3(0.45, sin(time * 0.4) * 0.3, 0))
		"lie", "sleep":
			offset("body", Vector3(0, -leg_len * 0.85, 0))
			for n: String in ["leg_fl", "leg_fr"]:
				rot(n, Vector3(-1.4, 0, 0))
			for n: String in ["leg_bl", "leg_br"]:
				rot(n, Vector3(1.3, 0, 0))
			rot("tail", Vector3(0.0, 0.8, 0))
			if anim == "sleep":
				rot("neck", Vector3(0.4, 0.3, 0))
				rot("head", Vector3(0.3, 0.2, 0.2))
				rot("chest", Vector3(sin(time * 1.4) * 0.03, 0, 0))
		"sniff":
			rot("neck", Vector3(0.7, 0, 0))
			rot("head", Vector3(0.4 + sin(time * 18.0) * 0.05, sin(time * 2.0) * 0.3, 0))
		"eat", "dig":
			rot("neck", Vector3(0.9, 0, 0))
			rot("head", Vector3(0.4 + sin(time * 10.0) * 0.12, 0, 0))
			if anim == "dig":
				rot("leg_fl", Vector3(-0.6 + sin(time * 14.0) * 0.6, 0, 0))
				rot("leg_fr", Vector3(-0.6 - sin(time * 14.0) * 0.6, 0, 0))
		"bark":
			var b := absf(sin(time * 9.0))
			rot("neck", Vector3(-0.3 - b * 0.15, 0, 0))
			rot("head", Vector3(-0.3 * b, 0, 0))
			offset("chest", Vector3(0, b * 0.02, 0))
		"crouch":
			offset("body", Vector3(0, -leg_len * 0.45, 0))
			offset("chest", Vector3(0, -leg_len * 0.1, 0))
			rot("neck", Vector3(0.2, 0, 0))
			rot("tail", Vector3(0.1, sin(time * 6.0) * 0.4, 0))
		"pounce":
			rot("body", Vector3(-0.3, 0, 0))
			for n: String in ["leg_fl", "leg_fr"]:
				rot(n, Vector3(-1.2, 0, 0))
			for n: String in ["leg_bl", "leg_br"]:
				rot(n, Vector3(0.9, 0, 0))
		"upright", "beg":
			rot("body", Vector3(-1.2, 0, 0))
			offset("body", Vector3(0, -leg_len * 0.3, 0))
			rot("neck", Vector3(-0.2, 0, 0))
			rot("head", Vector3(0.9, sin(time * 0.8) * 0.4, 0))
			rot("leg_fl", Vector3(-0.2 + sin(time * 8.0) * 0.2, 0, 0))
			rot("leg_fr", Vector3(-0.2 - sin(time * 8.0) * 0.2, 0, 0))
			rot("leg_bl", Vector3(-1.1, 0, 0))
			rot("leg_br", Vector3(-1.1, 0, 0))
		"climb":
			rot("root", Vector3(-PI / 2, 0, 0))
			var c := sin(time * 14.0)
			rot("leg_fl", Vector3(c * 0.6, 0, 0))
			rot("leg_br", Vector3(c * 0.6, 0, 0))
			rot("leg_fr", Vector3(-c * 0.6, 0, 0))
			rot("leg_bl", Vector3(-c * 0.6, 0, 0))
		"groom":
			rot("body", Vector3(-0.55, 0, 0))
			offset("body", Vector3(0, -leg_len * 0.45, 0))
			rot("leg_bl", Vector3(-1.0, 0, 0))
			rot("leg_br", Vector3(-1.0, 0, 0))
			rot("leg_fl", Vector3(-1.6 + sin(time * 6.0) * 0.2, 0, 0))
			rot("head", Vector3(0.6, 0.3, 0.3))
		"roll":
			rot("root", Vector3(0, 0, sin(time * 3.0) * 1.4))
			for n: String in ["leg_fl", "leg_fr", "leg_bl", "leg_br"]:
				rot(n, Vector3(sin(time * 9.0 + n.length()) * 0.6, 0, 0))
		"play":
			# Play bow.
			offset("chest", Vector3(0, -leg_len * 0.5, 0))
			rot("body", Vector3(0.35, 0, 0))
			rot("leg_fl", Vector3(-0.9, 0, 0))
			rot("leg_fr", Vector3(-0.9, 0, 0))
			rot("tail", Vector3(-0.3, sin(time * 16.0) * 0.7, 0))
		"hold":
			rot("neck", Vector3(-0.2, 0, 0))
	var ears_up := anim in ["bark", "crouch", "sniff"]
	rot("ear_l", Vector3(0, 0, -0.15 if ears_up else 0.1))
	rot("ear_r", Vector3(0, 0, 0.15 if ears_up else -0.1))
	var look_yaw: float = st.get("look_yaw", 0.0)
	if look_yaw != 0.0:
		add_rot("head", Vector3(0, clampf(look_yaw, -1.0, 1.0), 0))

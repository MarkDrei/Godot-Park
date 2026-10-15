class_name RingToss
extends BoothGame
## Ringwurf with Ring-Rita: fifteen bottles, five rings. The marker sweeps left and right –
## stop it – then back and forth – stop it – and the ring flies there. A ring round a bottle
## neck brings three tickets.

const RINGS := 5
const NECK := 0.12                # how close to a neck counts
const TABLE_Y := 1.12             # the bottles stand on a table above the counter
const NECK_Y := 1.56              # where a ring lands round a neck
const GLASS := [Color("4cc47a"), Color("d09040"), Color("62bde6")]
var bottles: Array[Vector3] = []  # neck positions (world)
var _ringed: Array[bool] = []
var _marker: MeshInstance3D
var _ring: MeshInstance3D
var rings := RINGS
var ringed := 0
var _stage := 0                   # 0 sweeping x, 1 sweeping z, 2 flying
var _x := 0.0
var _z := 0.0
var _t := 0.0
var _fly := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO


func _init() -> void:
	title = "Ringwurf"
	host_id = "rita"
	booth = "rings"
	cost = 100


func describe() -> String:
	return "Wirf Ringe über die Flaschenhälse: drei Tickets pro Treffer. Fünf Ringe, 1 € bei Ring-Rita im Westpark."


func booth_begin() -> void:
	bottles.clear()
	_ringed.clear()
	# A table full of bottles: fifteen in three rows, the back rows a step higher.
	add_prop(FairModels.ring_table(), lp(0, 0, 0))
	for k in 15:
		var row := k / 5
		var lift := row * 0.1
		var base := lp(-1.4 + (k % 5) * 0.7, TABLE_Y + lift, -0.2 - row * 0.45)
		add_prop(FairModels.bottle(GLASS[(k + row) % GLASS.size()]), base)
		bottles.append(base + Vector3.UP * (NECK_Y - TABLE_Y))
		_ringed.append(false)
	var mk := MeshKit.new()
	mk.use("unshaded")
	mk.torus(Vector3.ZERO, 0.12, 0.012, 16, 3, Color("ff3030"))
	_marker = add_prop(mk.commit(), Vector3.ZERO)
	var rk := MeshKit.new()
	rk.torus(Vector3.ZERO, 0.12, 0.02, 14, 4, Color("f2c230"))
	_ring = add_prop(rk.commit(), Vector3.ZERO)
	_ring.visible = false
	rings = RINGS
	ringed = 0
	_stage = 0
	_t = 0.0
	set_score("Ringe: %d · Treffer: 0" % rings)
	set_info("Stopp den Kreis zweimal: erst links-rechts, dann vor-zurück. (Leertaste, Klick oder „Stopp“)")
	add_button("Stopp", _press, 160)
	host_say("Locker aus dem Handgelenk!")


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta * pace * (1.0 + (RINGS - rings) * 0.1)
	if _stage == 0:
		_x = sin(_t * 0.9) * 1.6
	elif _stage == 1:
		_z = -0.65 + sin(_t * 1.1) * 0.65
	if _stage < 2:
		var lift := roundf(clampf(-(_z + 0.2) / 0.45, 0.0, 2.0)) * 0.1   # the back rows stand higher
		_marker.global_position = lp(_x, NECK_Y + 0.08 + lift, _z)
	else:
		_fly += delta / 0.55
		var k := minf(_fly, 1.0)
		_ring.global_position = _from.lerp(_to, k) + Vector3.UP * sin(k * PI) * 0.5
		_ring.rotation.y += delta * 8.0
		if _fly >= 1.0:
			_land()


func _press() -> void:
	if not active or rings <= 0:
		return
	if _stage == 0:
		_stage = 1
	elif _stage == 1:
		_stage = 2
		rings -= 1
		_fly = 0.0
		_from = actor.global_position + Vector3.UP * 1.4
		_to = _marker.global_position
		_ring.visible = true
		actor.play_anim("throw", 0.6)


## A glass bottle (origin at its foot): body, shoulder, a long neck the rings go over.
func camera() -> Array:
	return [lp(0.4, 2.05, 3.5), lp(0.0, 1.35, -0.7)]


func _land() -> void:
	var hit := -1
	for k in bottles.size():
		if not _ringed[k] and Vector2(bottles[k].x - _to.x, bottles[k].z - _to.z).length() < NECK:
			hit = k
	if hit >= 0:
		_ringed[hit] = true
		ringed += 1
		tickets += 3
		var keep := add_prop((_ring.mesh as Mesh), bottles[hit] - Vector3.UP * 0.18)
		keep.scale = Vector3.ONE * 0.9
		Sound.play("coin", _to, -4.0)
		host_say(["Treffer! Der sitzt!", "Wunderbar!", "Genau drüber!"][randi() % 3], 2.0)
	else:
		Sound.play("click", _to, -4.0)
		host_say(["Klirr … daneben.", "Fast! Nochmal?", "Der Ring hüpft weg."][randi() % 3], 2.0)
	_ring.visible = false
	_stage = 0
	set_score("Ringe: %d · Treffer: %d" % [rings, ringed])
	if rings == 0:
		finish_round("%d Ring%s sitzen auf den Flaschen." % [ringed, "" if ringed == 1 else "e"] if ringed > 0 else "Kein Ring hat gesessen.", ringed >= 2)


func game_input(event: InputEvent) -> void:
	if primary_pressed(event) or clicked(event):
		_press()

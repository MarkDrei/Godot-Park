class_name TowJob
extends DriveJob
## Tow truck for Meister Kurt: broken-down cars wait somewhere in town (hazard lights). Back
## the tow truck up to one, hook it on (Action), tow it carefully to the garage yard and
## unhook it there. Three cars per shift; every hard bump costs money.

const CARS := 3
const YARD := Rect2(252, -122, 17, 18)       # drop zone in the garage yard

var rng := RandomNumberGenerator.new()
var broken: Car
var towing := false
var done_count := 0
var earned := 0
var hook_spot: FunctionSpot
var _hazard := 0.0
var _hazard_mesh: MeshInstance3D


func _init() -> void:
	super()
	title = "Abschleppdienst"
	host_id = "kurt"
	vehicle_kind = "tow"
	rng.randomize()


func describe() -> String:
	return "Mit Meister Kurts Abschleppwagen (Werkstatt an der Nordstraße) liegengebliebene Autos holen: ankoppeln, vorsichtig zum Hof bringen, abkoppeln."


func begin() -> void:
	start_driving()
	done_count = 0
	earned = 0
	if hook_spot == null:
		hook_spot = FunctionSpot.new()
		hook_spot.name = "TowHook"
		hook_spot.from_car = true
		hook_spot.radius = 9.0
		hook_spot.prompt_fn = func(a: Actor) -> String: return _hook_prompt(a)
		hook_spot.available_fn = func(a: Actor) -> bool: return _can_hook(a) or _can_unhook(a)
		hook_spot.action_fn = func(_a: Actor) -> void: _hook_action()
		world.add_child(hook_spot)
	hook_spot.visible = true
	set_info("Fahr rückwärts an das Pannenauto heran und kopple es an (Aktion).")
	_next_car()


func _next_car() -> void:
	towing = false
	var bays := CityLayout.parking_bays()
	var here := car().pos2()
	for i in 80:
		var bay: Dictionary = bays[rng.randi() % bays.size()]
		var p: Vector2 = bay["pos"]
		if bay.get("tree", false) or p.distance_to(here) < 60.0 or p.distance_to(here) > 200.0 or YARD.grow(20.0).has_point(p):
			continue
		if world.city.car_at(p, 2.5) != null:
			continue
		broken = world.city.spawn_car(CarSpecs.ORDINARY[rng.randi() % 4], CarSpecs.COLORS[rng.randi() % CarSpecs.COLORS.size()], p, bay["yaw"])
		broken.locked = true
		broken.job = "broken"
		_add_hazard(broken)
		show_target(p, "Panne in der %s" % bay["street"], Color(1.0, 0.6, 0.1))
		hook_spot.position = Vector3(p.x, 0, p.y)
		return
	end({"won": done_count > 0, "text": "Keine Pannen mehr heute."})


func _add_hazard(c: Car) -> void:
	_hazard_mesh = MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.use("unshaded")
	for s: float in [-1.0, 1.0]:
		for e: float in [-1.0, 1.0]:
			kit.box(Vector3(s * (c.width() * 0.5 - 0.25), 0.72, e * (c.length() * 0.5 + 0.02)), Vector3(0.3, 0.14, 0.04), Color("ffa020"))
	_hazard_mesh.mesh = kit.commit()
	c.add_child(_hazard_mesh)


## The tow truck's hitch (behind it) and the broken car's nearer end.
func _hitch() -> Vector2:
	var c := car()
	return c.pos2() - c.forward2() * (c.length() * 0.5 + 0.4)


func _can_hook(a: Actor) -> bool:
	if towing or broken == null or a.vehicle == null or not a.vehicle.is_standing():
		return false
	var h := _hitch()
	var bf := broken.forward2()
	for end_pt: Vector2 in [broken.pos2() + bf * broken.length() * 0.5, broken.pos2() - bf * broken.length() * 0.5]:
		if h.distance_to(end_pt) < 2.6:
			return true
	return false


func _can_unhook(a: Actor) -> bool:
	return towing and a.vehicle != null and a.vehicle.is_standing() and YARD.has_point(broken.pos2())


func _hook_prompt(a: Actor) -> String:
	if _can_unhook(a):
		return "Abkoppeln"
	if towing:
		return ""
	if _can_hook(a):
		return "Ankoppeln"
	return "Rückwärts ans Pannenauto heranfahren" if broken and a.vehicle and a.vehicle.pos2().distance_to(broken.pos2()) < 9.0 else ""


func _hook_action() -> void:
	if _can_unhook(actor):
		_deliver()
	elif _can_hook(actor):
		towing = true
		bumps = 0
		car().ignore = broken
		Sound.play("click")
		show_target(YARD.get_center(), "Hof der Werkstatt", Color(0.5, 0.9, 1.0))
		set_info("Vorsichtig zum Hof der Werkstatt ziehen und dort abkoppeln.")


func job_tick(delta: float) -> void:
	set_score("Panne %d/%d · %s · %s" % [mini(done_count + 1, CARS), CARS, GameState.format_money(earned), way_text()])
	if broken:
		_hazard += delta
		if _hazard_mesh:
			_hazard_mesh.visible = fmod(_hazard, 0.8) < 0.4
	if towing:
		_pull()
		hook_spot.position = Vector3(broken.global_position.x, 0, broken.global_position.z)


## The towed car hangs at the hitch and swings in behind (a simple trailer).
func _pull() -> void:
	var h := _hitch()
	var back := broken.pos2() - h
	if back.length() < 0.01:
		return
	var dir := back.normalized()
	var p := h + dir * (broken.length() * 0.5 + 0.3)
	broken.place(p, atan2(-dir.x, -dir.y))


func _deliver() -> void:
	towing = false
	car().ignore = null
	var pay := maxi(300, 900 - bumps * 150)
	earned += pay
	done_count += 1
	GameState.add_stat("cars_towed")
	GameState.add_money(pay, "Abschleppen" + (" (ohne Kratzer)" if bumps == 0 else ""))
	var kurt := host()
	if kurt and not kurt.inside:
		kurt.say("Gut gemacht! Den krieg ich wieder hin.", 2.5)
	world.city.remove_car(broken)
	broken = null
	_hazard_mesh = null
	if done_count >= CARS:
		end({"won": true, "joy": 20.0, "text": "Drei Pannenautos abgeschleppt – %s verdient." % GameState.format_money(earned)})
	else:
		_next_car()


func cleanup() -> void:
	super()
	if actor and actor.vehicle:
		actor.vehicle.ignore = null
	if broken and is_instance_valid(broken):
		world.city.remove_car(broken)
	broken = null
	towing = false
	if hook_spot:
		hook_spot.visible = false

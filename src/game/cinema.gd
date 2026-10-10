class_name Cinema
extends Minigame
## The drive-in cinema (doc/oststadt.md): in the evening a short film runs on the big screen.
## Buy a ticket at the booth, park in a row facing the screen and watch from the car: the
## camera looks at the screen, joy rises; popcorn comes to the window.

const SHOW := [19.0, 26.0]          # film evenings: 19:00 to 02:00
const PRICE := 300
const SCENES := ["DER BANKRÄUBER VOM STADTPARK", "Kapitel 1: Die Ente, die zu viel wusste",
	"Kapitel 2: Verfolgungsjagd im Mondschein", "Kapitel 3: Rasante Fahrt durch die Oststadt", "ENDE – Bank frei!"]
const SCENE_SECONDS := 8.0

var screen: MeshInstance3D
var subtitle: Label3D
var material: ShaderMaterial
var ticket_day := -1                # the evening a ticket was bought for (Clock.day of 19:00)
var watching := false
var film_t := 0.0
var booth: FunctionSpot
var spot: FunctionSpot
var car: Car


func _init() -> void:
	title = "Autokino"


func describe() -> String:
	return "Abends ab 19 Uhr läuft im Autokino ein Film. Ticket an der Kasse, dann mit dem Auto vor die Leinwand."


## Screen, subtitles and the two spots (called when the Oststadt is loaded).
func build_city(parent: Node3D) -> void:
	var lot: Rect2 = CityLayout.LOTS["cinema"]["rect"]
	var cx := lot.get_center().x
	screen = MeshInstance3D.new()
	screen.mesh = CityModels.screen_quad()
	material = ShaderMaterial.new()
	material.shader = preload("res://src/shaders/film.gdshader")
	screen.material_override = material
	screen.position = Vector3(cx, 7.6, lot.position.y + 3.0 + 0.0)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(screen)
	subtitle = Label3D.new()
	subtitle.font_size = 120
	subtitle.pixel_size = 0.01
	subtitle.outline_size = 16
	subtitle.position = Vector3(cx, 4.2, lot.position.y + 3.15)
	subtitle.modulate = Color("f4f0e0")
	parent.add_child(subtitle)
	booth = FunctionSpot.new()
	booth.name = "CinemaBooth"
	booth.position = Vector3(179.5, 0.0, -172.0)
	booth.radius = 3.2
	booth.from_car = true
	booth.prompt_fn = func(_a: Actor) -> String:
		if not is_show_time():
			return "Kasse: heute ab 19 Uhr"
		if has_ticket():
			return "Ticket gekauft – vor die Leinwand fahren"
		if not karla_here():
			return "Kasse (Kino-Karla ist gerade nicht da)"
		return "Ticket kaufen (%s)" % GameState.format_money(PRICE)
	booth.available_fn = func(a: Actor) -> bool: return is_show_time() and not has_ticket() and karla_here() and a.vehicle != null and a.vehicle.is_standing()
	booth.action_fn = func(_a: Actor) -> void: buy_ticket()
	parent.add_child(booth)
	spot = FunctionSpot.new()
	spot.name = "CinemaRows"
	spot.position = Vector3(cx, 0.0, lot.position.y + 31.0)
	spot.radius = 24.0
	spot.from_car = true
	spot.prompt_fn = func(a: Actor) -> String:
		if not is_show_time() or a.vehicle == null:
			return ""
		if not has_ticket():
			return "Erst ein Ticket an der Kasse kaufen"
		return "Film schauen" if parked_well(a.vehicle) else "In eine Parkbucht vor der Leinwand stellen"
	spot.available_fn = func(a: Actor) -> bool: return a.vehicle != null and is_show_time() and has_ticket() and parked_well(a.vehicle) and not active
	spot.action_fn = func(a: Actor) -> void: try_start(a)
	parent.add_child(spot)


## Kino-Karla sells the tickets at the booth.
func karla_here() -> bool:
	var k := world.find_actor("karla")
	return k != null and not k.inside and k.visible and not k.controlled and k.distance_to(Vector3(185.3, 0, -173.5)) < 4.0


static func is_show_time() -> bool:
	var h := Clock.hour()
	return h >= SHOW[0] or h < SHOW[1] - 24.0


## The evening the current show belongs to (after midnight: the day before).
static func show_day() -> int:
	return Clock.day - (1 if Clock.hour() < 12.0 else 0)


func has_ticket() -> bool:
	return ticket_day == show_day()


func buy_ticket() -> void:
	if has_ticket() or not GameState.spend(PRICE):
		return
	ticket_day = show_day()
	Sound.play("coin")
	GameState.toast.emit("Ticket gekauft! Fahr in eine Reihe vor der Leinwand.", "info")


## Standing in one of the spots, facing the screen.
func parked_well(c: Car) -> bool:
	if not c.is_standing():
		return false
	for s: Dictionary in CityBuilder.cinema_spots():
		if c.pos2().distance_to(s["pos"]) < 2.6 and absf(angle_difference(c.yaw, s["yaw"])) < 0.5:
			return true
	return false


func can_start(a: Actor) -> bool:
	return a.vehicle != null and not active


func begin() -> void:
	car = actor.vehicle
	watching = true
	film_t = 0.0
	GameState.add_stat("films_watched")
	set_info("Lehn dich zurück und genieß den Film.")
	add_button("Popcorn (%s)" % GameState.format_money(Food.ITEMS["popcorn"]["price"]), func() -> void: _popcorn(), 260)
	_look_at_screen()


func _look_at_screen() -> void:
	var from := car.global_position + Vector3(0, 1.4, 0) + Vector3(car.forward2().x, 0, car.forward2().y) * -1.5
	look(from, screen.global_position + Vector3(0, -0.5, 0))


func _popcorn() -> void:
	if not GameState.spend(Food.ITEMS["popcorn"]["price"]):
		return
	Sound.play("coin")
	Food.apply(actor, "popcorn")
	set_info("Kino-Karla bringt Popcorn ans Autofenster. Mmh!")


func _process(delta: float) -> void:
	if screen == null:
		return
	var show := is_show_time()
	if watching and active:
		film_t += delta
		actor.needs.enjoy(delta * Clock.MINUTES_PER_SECOND, 60.0)
		set_score("Film läuft · %d / %d" % [mini(int(film_t / SCENE_SECONDS) + 1, SCENES.size()), SCENES.size()])
		if film_t >= SCENE_SECONDS * SCENES.size():
			watching = false
			end({"won": true, "joy": 20.0, "text": "Was für ein Film! Die Ente hat den Donut am Ende doch bekommen."})
	# The film loops all evening (also seen from afar); by day the screen announces it.
	var t := film_t if (active and watching) else fmod(Time.get_ticks_msec() / 1000.0, SCENE_SECONDS * SCENES.size())
	var scene := int(t / SCENE_SECONDS) if show else -1
	material.set_shader_parameter("scene", scene)
	material.set_shader_parameter("t", t)
	subtitle.text = SCENES[scene] if scene >= 0 else "Heute ab 19 Uhr: Der Bankräuber vom Stadtpark"


func cleanup() -> void:
	watching = false

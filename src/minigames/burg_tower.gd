class_name BurgTower
extends Minigame
## Up the lookout tower with castellan Ottilie (doc/burg.md): the camera climbs to the platform
## and turns once round the whole map (the park, the Nordwald, the Westpark with its Ferris wheel,
## the Oststadt). "Turmblick".

const DURATION := 18.0

var t := 0.0
var top := Vector3.ZERO
var _from := Vector3.ZERO


func _init() -> void:
	title = "Aussichtsturm"
	host_id = "ottilie"
	cost = 50


func describe() -> String:
	return "Hinauf auf den Aussichtsturm der Burg, mit Blick über die ganze Karte. 0,50 €."


func goal_done() -> bool:
	return GameState.stat("tower_view") > 0


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.burg != null


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Auf den Aussichtsturm (%s)" % GameState.format_money(cost)


func begin() -> void:
	var p := BurgLayout.place("tower")
	top = Vector3(p.x, world.map.height_at(p.x, p.y) + BurgModels.TOWER_TOP + 2.6, p.y)
	_from = actor.global_position
	actor.visible = false
	t = 0.0
	host_say("Hundertzwölf Stufen. Aber die Aussicht lohnt sich!", 3.0)
	set_info("Von hier oben siehst du die ganze Karte.")


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	var climb := clampf(t / 3.0, 0.0, 1.0)
	var eye := _from.lerp(top, smoothstep(0.0, 1.0, climb)) + Vector3(0, 1.6 * (1.0 - climb), 0)
	var a := PI + (t - 3.0) / (DURATION - 3.0) * TAU if t > 3.0 else PI
	var at := top + Vector3(sin(a), -0.35, cos(a)) * 60.0
	look(eye, at)
	show_power(clampf(t / DURATION, 0.0, 1.0))
	if t >= DURATION:
		GameState.add_stat("tower_view")
		end({"won": true, "joy": 20.0, "text": "Was für ein Blick! Bis zum Riesenrad der Kirmes und über die Dächer der Oststadt."})


func cleanup() -> void:
	actor.visible = true

class_name CoastLighthouse
extends Minigame
## Up the lighthouse with keeper Hinnerk (doc/moewenbucht.md): the camera climbs to the gallery
## and turns once round the bay (the pier, the beach, the sandbank with the seals, the open sea,
## the park behind the dunes). "Leuchtturmblick".

const DURATION := 18.0
const GALLERY := 16.4           # the gallery's floor above the mole
const RING := 2.0               # standing on the gallery, this far from the middle

var t := 0.0
var top := Vector3.ZERO
var _from := Vector3.ZERO


func _init() -> void:
	title = "Leuchtturm"
	host_id = "hinnerk"
	cost = 50


func describe() -> String:
	return "Hinauf auf den Leuchtturm der Möwenbucht, einmal rundherum über Bucht und Meer. 0,50 €."


func goal_done() -> bool:
	return GameState.stat("lighthouse_view") > 0


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.coast != null


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Auf den Leuchtturm (%s)" % GameState.format_money(cost)


func begin() -> void:
	var p := CoastLayout.place("lighthouse")
	top = Vector3(p.x, CoastLayout.MOLE_Y + GALLERY + 1.6, p.y)
	_from = actor.global_position
	actor.visible = false
	t = 0.0
	host_say("Hundertsechzehn Stufen. Halt dich am Geländer fest!", 3.0)
	set_info("Von hier oben siehst du die ganze Bucht.")


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	var climb := clampf(t / 3.0, 0.0, 1.0)
	# From looking at the bay (north-west) once round, walking round the gallery outside the lantern.
	var a := -PI * 0.75 + (t - 3.0) / (DURATION - 3.0) * TAU if t > 3.0 else -PI * 0.75
	var on_ring := top + Vector3(sin(a), 0, cos(a)) * RING
	var eye := _from.lerp(on_ring, smoothstep(0.0, 1.0, climb)) + Vector3(0, 1.6 * (1.0 - climb), 0)
	var at := on_ring + Vector3(sin(a), -0.3, cos(a)) * 60.0
	look(eye, at)
	show_power(clampf(t / DURATION, 0.0, 1.0))
	if t >= DURATION:
		GameState.add_stat("lighthouse_view")
		end({"won": true, "joy": 20.0, "text": "Was für ein Blick! Die Seebrücke, die Robben auf der Sandbank und hinter den Dünen der Stadtpark."})


func cleanup() -> void:
	actor.visible = true

class_name BurgTug
extends Minigame
## Tauziehen against Ritter Kunibert (doc/burg.md): a drum beats; "Ziehen!" (Aktion) on the beat
## pulls the rope your way, off the beat or not at all and Kunibert pulls it his. Over the line
## (the bar full) wins 3 €; empty or after 40 s on his side loses. "Stärker als ein Ritter".

const BEAT := 0.85              # seconds between beats
const WINDOW := 0.2             # seconds either side of a beat that count
const PULL := 0.075
const KNIGHT := 0.03            # Kunibert's pull per beat
const TIME := 40.0

var rope := 0.5                 # 0 Kunibert wins … 1 the player wins
var t := 0.0
var last_beat := -1
var pulled := false             # pulled on the current beat
var state := "pull"
var knight: Actor
var pitch := Vector3.ZERO
var rope_mesh: MeshInstance3D


func _init() -> void:
	title = "Tauziehen"
	host_id = "kunibert"


func describe() -> String:
	return "Zieh Ritter Kunibert über die Linie: im Takt der Trommel ziehen! 3 € für den Sieg."


func goal_done() -> bool:
	return GameState.stat("tug_wins") > 0


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.burg != null


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Tauziehen gegen Kunibert"


func begin() -> void:
	var p := BurgLayout.place("tug")
	pitch = Vector3(p.x, world.map.walk_height(p.x, p.y), p.y)
	knight = host()
	rope = 0.5
	t = 0.0
	last_beat = -1
	pulled = false
	state = "pull"
	rope_mesh = MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.rod(Vector3(-5, 1.0, 0), Vector3(5, 1.0, 0), 0.04, 0.04, 5, Color("c9a86a"))
	kit.box(Vector3(0, 1.0, 0), Vector3(0.1, 0.12, 0.16), BurgModels.RED)
	rope_mesh.mesh = kit.commit()
	add_child(rope_mesh)
	_place()
	look(pitch + Vector3(0, 3.0, 8.5), pitch + Vector3(0, 1.0, 0))
	host_say("Dann zieh mal, wenn du kannst!", 3.0)
	set_info("Zieh im Takt der Trommel: „Ziehen!“ (Aktion), wenn der Balken aufleuchtet. Daneben hilft nur Kunibert.")
	add_button("Ziehen!", func() -> void: pull(), 220)
	show_power(rope)


## The rope's middle moves with `rope`; the player stands east, Kunibert west.
func _place() -> void:
	var off := (rope - 0.5) * 6.0
	rope_mesh.global_position = pitch + Vector3(off, 0, 0)
	actor.teleport(pitch + Vector3(off + 3.6, 0, 0))
	actor.face(pitch + Vector3(-20, 0, 0), true)
	actor.anim = "tug"
	if knight:
		knight.teleport(pitch + Vector3(off - 3.6, 0, 0))
		knight.face(pitch + Vector3(20, 0, 0), true)
		knight.anim = "tug"


## Seconds to the nearest beat (negative before it).
func beat_offset() -> float:
	var n := roundf(t / BEAT)
	return t - n * BEAT


func pull() -> void:
	if state != "pull" or pulled:
		return
	pulled = true
	if absf(beat_offset()) <= WINDOW:
		rope = clampf(rope + PULL, 0.0, 1.0)
		Sound.play("hit", actor.global_position, -4.0)
	else:
		rope = clampf(rope - KNIGHT * 0.5, 0.0, 1.0)


func _process(delta: float) -> void:
	if not active or state != "pull":
		return
	t += delta
	# A new beat begins halfway between two: Kunibert pulls once per beat.
	var idx := int(floor((t + BEAT * 0.5) / BEAT))
	if idx != last_beat:
		last_beat = idx
		pulled = false
		rope = clampf(rope - KNIGHT, 0.0, 1.0)
	set_score("Noch %d s  ·  %s" % [maxi(0, int(ceil(TIME - t))), "Trommel!" if absf(beat_offset()) <= WINDOW else ""])
	show_power(rope)
	_place()
	if rope >= 1.0 or rope <= 0.0 or t >= TIME:
		state = "done"
		var won := rope >= 1.0 or (t >= TIME and rope > 0.5)
		if won:
			GameState.add_stat("tug_wins")
		end_after(0.8, {"won": won, "money": 300 if won else 0, "joy": 20.0 if won else 8.0,
			"text": "Kunibert landet im Sand! „Du bist stärker als ein Ritter!“" if won else "Kunibert zieht dich über die Linie. „Nicht schlecht für einen Bürger!“"})


func cleanup() -> void:
	actor.anim = "idle"
	if knight:
		knight.anim = "idle"
	if rope_mesh:
		rope_mesh.queue_free()
		rope_mesh = null


func game_input(event: InputEvent) -> void:
	if primary_pressed(event):
		pull()

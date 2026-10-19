class_name BurgRings
extends BurgHorseGame
## Ringstechen with squire Till (doc/burg.md): one ride on Wolke past five posts with a ring
## hanging from each; "Stechen!" (Aktion) when the lance's tip is at a ring takes it.
## 0,50 € per ring; all five in one ride: Ringmeister.

const POSTS := 5
const RIDE_TIME := 10.0
const WINDOW := 0.9            # metres either side of a ring where the lance takes it
const RING_Y := 2.15

var horse: Actor
var t := 0.0
var state := "ride"
var taken := 0
var tried := []                 # ring index -> true once tried
var rings: Array[MeshInstance3D] = []
var posts_x: Array[float] = []
var scenery: Node3D


func _init() -> void:
	title = "Ringstechen"
	host_id = "till"
	cost = 100


func describe() -> String:
	return "Reite an fünf Ringen vorbei und stich sie mit der Lanze. 0,50 € pro Ring. Einsatz 1 €."


func goal_done() -> bool:
	return GameState.stat("rings_all") > 0


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Ringstechen reiten (%s)" % GameState.format_money(cost)


func begin() -> void:
	horse = take_horse("wolke")
	actor.set_item("lance")
	scenery = Node3D.new()
	add_child(scenery)
	posts_x.clear()
	rings.clear()
	tried.clear()
	for i in POSTS:
		var x := lerpf(X0 + 14.0, X1 - 10.0, float(i) / (POSTS - 1))
		posts_x.append(x)
		tried.append(false)
		var base := lane(x, LANE_S + 1.6)
		var post := MeshInstance3D.new()
		var kit := MeshKit.new()
		kit.box(Vector3(0, 1.4, 0), Vector3(0.14, 2.8, 0.14), BurgModels.WOOD_DARK)
		kit.box(Vector3(0, 2.75, -0.7), Vector3(0.1, 0.1, 1.5), BurgModels.WOOD_DARK)
		post.mesh = kit.commit()
		post.position = base
		scenery.add_child(post)
		var ring := MeshInstance3D.new()
		var rk := MeshKit.new()
		rk.use("glow")
		rk.push(Transform3D(Basis(Vector3.UP, PI / 2).rotated(Vector3.RIGHT, 0.0), Vector3.ZERO))
		rk.push(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
		rk.torus(Vector3.ZERO, 0.16, 0.025, 12, 3, Color("e2c050"))
		rk.pop()
		rk.pop()
		ring.mesh = rk.commit()
		ring.position = lane(x, LANE_S) + Vector3(0, RING_Y, 0)
		scenery.add_child(ring)
		rings.append(ring)
	t = 0.0
	taken = 0
	state = "ride"
	host_say("Ruhige Hand, Lanze gerade!", 3.0)
	set_info("Wenn die Lanzenspitze an einem Ring ist: „Stechen!“ (Aktion). Jeder Ring zählt nur einmal.")
	add_button("Stechen!", func() -> void: stab(), 220)
	_update_score()


func _update_score() -> void:
	set_score("Ringe: %d von %d" % [taken, POSTS])


## The lance's tip (x along the lane): 2.8 m ahead of the rider.
func tip_x() -> float:
	return actor.global_position.x + 2.8


func _process(delta: float) -> void:
	if not active or state != "ride":
		return
	t += delta
	var k := clampf(t / RIDE_TIME, 0.0, 1.0)
	var p := lane(lerpf(X0, X1 + 4.0, k), LANE_S)
	ride(actor, horse, p, PI / 2, (X1 + 4.0 - X0) / RIDE_TIME)
	look(p + Vector3(-4.5, 2.6, 3.0), p + Vector3(6.0, 1.6, -0.5))
	for i in POSTS:
		if not tried[i] and tip_x() > posts_x[i] + WINDOW:
			tried[i] = true   # ridden past without stabbing
	if k >= 1.0:
		state = "done"
		var all := taken == POSTS
		if all:
			GameState.add_stat("rings_all")
		end_after(0.8, {"won": taken >= 3, "money": taken * 50, "joy": 10.0 + taken * 3.0,
			"text": "%d von %d Ringen! %s" % [taken, POSTS, "Till staunt: „Alle fünf! Du bist ein echter Ringmeister!“" if all
				else ("„Gar nicht schlecht!“, ruft Till." if taken >= 3 else "„Nächstes Mal triffst du mehr!“, meint Till.")]})


## Stabs at the next ring: it counts if the tip is within WINDOW of it.
func stab() -> void:
	if state != "ride":
		return
	actor.play_anim("throw", 0.4)
	for i in POSTS:
		if tried[i]:
			continue
		tried[i] = true
		if absf(tip_x() - posts_x[i]) <= WINDOW:
			taken += 1
			rings[i].visible = false
			Sound.play("coin", actor.global_position)
			host_say(["Getroffen!", "Sauber!", "Noch einer!"][taken % 3], 1.5)
		else:
			Sound.play("click", actor.global_position)
		break
	_update_score()


func cleanup() -> void:
	if scenery:
		scenery.queue_free()
		scenery = null
	dismount(actor, lane(X0 - 4.0, LANE_S + 4.0))
	release_horses()


func game_input(event: InputEvent) -> void:
	if primary_pressed(event):
		stab()

class_name BurgBet
extends Minigame
## Wetten at Wettmeister Gernot (doc/burg.md): bet 1, 2 or 5 € on Ritter Eckhard (the favourite,
## 1,5 ×) or Knappe Till (3 ×), then watch them fight in the sword ring: who first lands three
## hits wins. Three won bets: "Glückliches Händchen".

const ODDS := {"eckhard": 1.5, "till": 3.0}
const EXCHANGE := 1.6           # seconds per exchange
const WINS := 3

var pick := ""
var stake := 0
var hits := {"eckhard": 0, "till": 0}
var state := "pick"
var t := 0.0
var ring := Vector3.ZERO
var fighters := {}
var pace := 1.0


func _init() -> void:
	title = "Schwertkampf-Wette"
	host_id = "gernot"


func describe() -> String:
	return "Wette bei Gernot auf Eckhard oder Till und sieh dir den Kampf im Ring an."


func goal_done() -> bool:
	return GameState.stat("bets_won") >= 3


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.burg != null


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Auf den Schwertkampf wetten"


func begin() -> void:
	var p := BurgLayout.place("sword_ring")
	ring = Vector3(p.x, world.map.walk_height(p.x, p.y), p.y)
	pick = ""
	stake = 0
	hits = {"eckhard": 0, "till": 0}
	state = "pick"
	for id: String in ["eckhard", "till"]:
		var f := world.find_actor(id)
		f.inside = false
		f.visible = true
		if f.brain:
			f.brain.suspend()
		f.set_item("")
		fighters[id] = f
	actor.teleport(ring + Vector3(0, 0, 7.5))
	actor.face(ring, true)
	look(ring + Vector3(5.0, 4.0, 10.0), ring + Vector3(0, 1.0, 0))
	host_say("Wer gewinnt heute? Eckhard ist Favorit, aber Till hat Herz.", 3.5)
	set_info("Auf wen setzt du? Eckhard zahlt das 1,5-Fache, Till das 3-Fache.")
	add_button("Eckhard (1,5×)", func() -> void: choose("eckhard"), 200)
	add_button("Till (3×)", func() -> void: choose("till"), 200)
	_place_fighters(0.0)


func choose(id: String) -> void:
	if state != "pick":
		return
	pick = id
	state = "stake"
	clear_buttons()
	set_info("Wie viel setzt du auf %s?" % fighters[id].display_name)
	for cents: int in [100, 200, 500]:
		add_button(GameState.format_money(cents), func() -> void: bet(cents), 140)


func bet(cents: int) -> void:
	if state != "stake":
		return
	if not GameState.spend(cents):
		return
	stake = cents
	state = "fight"
	t = 0.0
	clear_buttons()
	set_info("%s auf %s. Der Kampf beginnt!" % [GameState.format_money(cents), fighters[pick].display_name])
	host_say("Die Wetten sind geschlossen!", 2.0)
	_update_score()


func _update_score() -> void:
	set_score("Eckhard %d : %d Till" % [hits["eckhard"], hits["till"]])


func _place_fighters(sway: float) -> void:
	var e: Actor = fighters["eckhard"]
	var tl: Actor = fighters["till"]
	e.teleport(ring + Vector3(-1.2 + sway, 0, 0))
	tl.teleport(ring + Vector3(1.2 + sway, 0, 0))
	e.face(tl.global_position, true)
	tl.face(e.global_position, true)


func _process(delta: float) -> void:
	if not active or state != "fight":
		return
	t += delta * pace
	_place_fighters(sin(t * 2.0) * 0.4)
	if t >= EXCHANGE:
		t = 0.0
		var winner := "eckhard" if rng.randf() < 0.62 else "till"
		var loser := "till" if winner == "eckhard" else "eckhard"
		hits[winner] += 1
		(fighters[winner] as Actor).play_anim("throw", 0.6)
		(fighters[loser] as Actor).play_anim("wave", 0.6)
		Sound.play("hit", ring, -2.0)
		_update_score()
		if hits[winner] >= WINS:
			state = "done"
			var won := winner == pick
			var pay := int(round(stake * float(ODDS[pick]))) if won else 0
			if won:
				GameState.add_stat("bets_won")
			end_after(1.2, {"won": won, "money": pay, "joy": 18.0 if won else 6.0,
				"text": "%s gewinnt %d : %d! %s" % [(fighters[winner] as Actor).display_name, WINS, hits[loser],
					("Gernot zahlt dir %s aus." % GameState.format_money(pay)) if won else "Dein Einsatz bleibt bei Gernot. „Beim nächsten Mal!“"]})


func cleanup() -> void:
	for id: String in fighters:
		var f: Actor = fighters[id]
		if is_instance_valid(f) and f.brain:
			f.brain.resume()
	fighters.clear()

class_name CoastFishingContest
extends Minigame
## Angelwettbewerb with Fischerin Gesche (doc/moewenbucht.md): 90 seconds on the pier head, who
## catches more? You fish as always (wait for "Biss!", then Aktion; the surf rod bites sooner);
## Gesche fishes beside you and her catches are counted in the panel. The player keeps moving
## (free roam); leaving the pier head ends it.

const DURATION := 90.0
const SPOT := Vector2(-7.6, 251.2)       # the player's place (a fishing place of CoastSpots)
const GESCHE_SPOT := Vector2(7.6, 251.2)

var t := 0.0
var duration := DURATION
var mine := 0
var hers := 0
var _start_count := 0
var _her_next := 0.0
var done := false


func _init() -> void:
	title = "Angelwettbewerb"
	host_id = "gesche"
	cost = 100
	free_roam = true


func describe() -> String:
	return "Wettangeln gegen Fischerin Gesche auf dem Brückenkopf: anderthalb Minuten, wer fängt mehr? Angel mitbringen, 1 €."


func goal_done() -> bool:
	return GameState.stat("fishing_contest_wins") > 0


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.coast != null


func blocked_text(a: Actor) -> String:
	if Items.tool_tier(a.inventory, "rod") == 0:
		return "erst eine Angel besorgen"
	return "" if host_available() else unavailable_text()


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Wettangeln auf der Seebrücke (%s)" % GameState.format_money(cost)


func begin() -> void:
	t = 0.0
	done = false
	duration = DURATION if duration <= 0.0 else duration
	hers = 0
	mine = 0
	_start_count = GameState.stat("fish_caught")
	_her_next = rng.randf_range(9.0, 15.0)
	var y := CoastLayout.PIER_Y
	actor.teleport(Vector3(SPOT.x, y, SPOT.y))
	actor.face(Vector3(SPOT.x - 2.0, 0, SPOT.y + 4.0), true)
	var h := host()
	if h:
		h.teleport(Vector3(GESCHE_SPOT.x, y, GESCHE_SPOT.y))
		h.face(Vector3(GESCHE_SPOT.x + 2.0, 0, GESCHE_SPOT.y + 4.0), true)
		h.set_item("rod")
		h.anim = "fish"
	host_say("Anderthalb Minuten! Wer mehr fängt, gewinnt. Los geht's!", 3.0)
	set_info("Angel wie immer: „Angeln“ (Aktion), warte auf „Biss!“, dann schnell Aktion. Bleib auf dem Brückenkopf. Gesches Fänge stehen hier oben.")
	_update_score()


func _update_score() -> void:
	set_score("Du %d : %d Gesche  ·  noch %d s" % [mine, hers, ceili(maxf(duration - t, 0.0))])


func _process(delta: float) -> void:
	if not active or done:
		return
	t += delta
	show_power(clampf(t / duration, 0.0, 1.0))
	mine = GameState.stat("fish_caught") - _start_count
	_her_next -= delta
	if _her_next <= 0.0:
		hers += 1
		_her_next = rng.randf_range(11.0, 18.0)
		var h := host()
		if h:
			h.play_anim("throw", 0.6)
			Sound.play("splash", h.global_position, -6.0)
		set_cue("Gesche: +1", UiTheme.GOLD)
		var s := session
		get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
			if still_running(s) and _cue.text.begins_with("Gesche"):
				set_cue(""))
	_update_score()
	var p := actor.ground_pos()
	if p.distance_to(CoastLayout.PIER_HEAD) > 12.0:
		done = true
		end({"won": false, "joy": 2.0, "text": "Du hast den Brückenkopf verlassen – das Wettangeln ist vorbei."})
		return
	if t >= duration:
		_finish()


func _finish() -> void:
	done = true
	var won := mine > hers
	if won:
		GameState.add_stat("fishing_contest_wins")
	end_after(0.5, {"won": won, "money": 300 if won else 0, "joy": 20.0 if won else 10.0,
		"text": "%d Fische gegen %d.\n\nGesche: „%s“" % [mine, hers, "Na sowas! Du angelst ja wie eine Fischerin." if won
			else ("Unentschieden – noch eine Runde?" if mine == hers else "Übung macht den Fischer. Komm wieder!")]})


func cleanup() -> void:
	set_cue("")
	var h := host()
	if h:
		h.set_item("")
		h.anim = "idle"

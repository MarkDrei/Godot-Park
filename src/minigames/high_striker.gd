class_name HighStriker
extends BoothGame
## Hau den Lukas with Muskel-Max: the power bar swings, strike at the top. The puck flies up
## the pole; at the very top the bell rings. Three strikes.

const POLE_LO := 0.6
const POLE_HI := 6.3
const BELL := 0.94             # power that rings the bell
var strikes := 3
var _puck: MeshInstance3D
var _bar_t := 0.0
var _fly := -1.0
var _target := 0.0
var _best := 0.0


func _init() -> void:
	title = "Hau den Lukas"
	host_id = "max"
	booth = "striker"
	cost = 100


func describe() -> String:
	return "Hau den Lukas: Schlag zu, wenn die Kraftanzeige ganz oben ist. Die Glocke bringt zwölf Tickets. 1 € bei Muskel-Max im Westpark."


## The striker is no booth: its own spot and frame.
func center() -> Vector3:
	var p := FairLayout.place("high_striker")
	return Vector3(p.x, 0, p.y)


func fwd() -> Vector3:
	return Vector3(0, 0, 1)


func right() -> Vector3:
	return Vector3(1, 0, 0)


func basis() -> Basis:
	return Basis()


func begin() -> void:
	tickets = 0
	actor.teleport(lp(-0.6, 0, 1.6))
	actor.face(lp(0.1, 0, 0.6), true)
	_root = Node3D.new()
	add_child(_root)
	move_host_aside()
	booth_begin()
	look(lp(3.2, 2.2, 6.5), lp(0, 3.0, 0))


func host_spot() -> Vector3:
	return lp(-2.8, 0, -0.6)


func booth_begin() -> void:
	var kit := MeshKit.new()
	kit.box(Vector3.ZERO, Vector3(0.22, 0.12, 0.1), Color("e8442e"))
	_puck = add_prop(kit.commit(), lp(0.12, POLE_LO, 0.18))
	strikes = 3
	_best = 0.0
	_fly = -1.0
	show_power(0.0)
	set_score("Schläge: 3")
	set_info("Schlag zu, wenn die Anzeige ganz oben ist! (Leertaste, Klick oder „Zuschlagen“)")
	add_button("Zuschlagen", _strike, 190)
	host_say("Nur die Starken läuten die Glocke!")


func _process(delta: float) -> void:
	if not active:
		return
	if _fly < 0.0:
		_bar_t += delta * pace * (1.1 + (3 - strikes) * 0.25)
		show_power(Minigame.pingpong(_bar_t, 1.0))
		return
	_fly += delta
	var up := minf(_fly / 0.6, 1.0)
	var h := lerpf(POLE_LO, lerpf(POLE_LO, POLE_HI, _target), sin(up * PI * 0.5)) if _fly < 0.6 \
		else lerpf(lerpf(POLE_LO, POLE_HI, _target), POLE_LO, clampf((_fly - 0.6) / 0.7, 0.0, 1.0))
	_puck.global_position = lp(0.12, h, 0.18)
	if _fly > 1.4:
		_fly = -1.0
		if strikes == 0:
			var bell := _best >= BELL
			finish_round("Die Glocke hat geläutet! Muskel-Max ist beeindruckt." if bell else "Bester Schlag: %d von 100." % int(_best * 100), bell)


func _strike() -> void:
	if _fly >= 0.0 or strikes <= 0 or not active:
		return
	strikes -= 1
	var p := Minigame.pingpong(_bar_t, 1.0)
	_target = clampf(p, 0.05, 1.0)
	_best = maxf(_best, _target)
	_fly = 0.0
	actor.play_anim("chop", 0.8)
	Sound.play("hit", lp(0, 0.5, 0.9), 0.0)
	var won := 12 if _target >= BELL else int(_target * 8.0)
	tickets += won
	if _target >= BELL:
		GameState.add_stat("bells_rung")
		get_tree().create_timer(0.55, false).timeout.connect(func() -> void: Sound.play("achievement", lp(0, 6.5, 0), -2.0))
		host_say("DING! Die Glocke!", 2.5)
	else:
		host_say(["Mehr Kraft!", "Nicht schlecht!", "Fast oben!"][mini(int(_target * 3.0), 2)], 2.0)
	set_score("Schläge: %d · Tickets: %d" % [strikes, tickets])


func game_input(event: InputEvent) -> void:
	if primary_pressed(event) or clicked(event):
		_strike()

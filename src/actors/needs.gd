class_name Needs
extends RefCounted
## Hunger, fatigue (0 = fine, 100 = desperate) and joy (100 = very happy).
## Rates are per game hour; profiles scale them per character.

## Fatigue recovered per game hour while sitting / sleeping.
const SIT_RECOVERY := 84.0
const SLEEP_RECOVERY := 200.0

var hunger := 20.0
var fatigue := 15.0
var joy := 70.0
var hunger_rate := 5.0
var fatigue_rate := 4.0
var joy_decay := 2.0


func update(game_minutes: float, state: String) -> void:
	var h := game_minutes / 60.0
	hunger += hunger_rate * h * (1.6 if state == "run" else 1.0)
	match state:
		"run":
			fatigue += fatigue_rate * 3.0 * h
		"sit":
			fatigue -= SIT_RECOVERY * h
		"sleep":
			fatigue -= SLEEP_RECOVERY * h
		"swim":
			fatigue += fatigue_rate * 0.6 * h
		"drive":
			pass   # nobody gets tired in a car (doc/oststadt.md)
		_:
			fatigue += fatigue_rate * h
	joy -= joy_decay * h
	if hunger > 80.0:
		joy -= 5.0 * h
	if fatigue > 80.0:
		joy -= 4.0 * h
	clamp_all()


## At home (off the map), and animals at midnight: fed, slept and cheered up at once.
## Better values are kept.
func rest_fully() -> void:
	hunger = minf(hunger, 20.0)
	fatigue = minf(fatigue, 10.0)
	joy = maxf(joy, 75.0)


## Doing something one enjoys (rate per game hour).
func enjoy(game_minutes: float, rate: float) -> void:
	joy = clampf(joy + rate * game_minutes / 60.0, 0.0, 100.0)


func clamp_all() -> void:
	hunger = clampf(hunger, 0.0, 100.0)
	fatigue = clampf(fatigue, 0.0, 100.0)
	joy = clampf(joy, 0.0, 100.0)


func eat(amount: float, joy_bonus := 6.0) -> void:
	hunger -= amount
	joy += joy_bonus
	clamp_all()


func cheer(amount: float) -> void:
	joy += amount
	clamp_all()


func speed_factor() -> float:
	if hunger > 85.0 or fatigue > 85.0:
		return 0.55
	if hunger > 70.0 or fatigue > 70.0:
		return 0.82
	return 1.0


func is_sad() -> bool:
	return joy < 25.0


func to_dict() -> Dictionary:
	return {"h": hunger, "f": fatigue, "j": joy}


func from_dict(d: Dictionary) -> void:
	hunger = d.get("h", hunger)
	fatigue = d.get("f", fatigue)
	joy = d.get("j", joy)

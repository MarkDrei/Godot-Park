class_name TestCase
extends RefCounted
## Minimal assertion helpers for the headless test runner.

var failures: Array[String] = []
var current := ""


func check(cond: bool, msg := "") -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg if msg != "" else "assertion failed"])


func check_eq(a, b, msg := "") -> void:
	if a != b:
		failures.append("%s: expected %s, got %s %s" % [current, str(b), str(a), msg])


func check_near(a: float, b: float, eps: float, msg := "") -> void:
	if absf(a - b) > eps:
		failures.append("%s: expected %f ± %f, got %f %s" % [current, b, eps, a, msg])


## Override for shared fixtures.
func before_all() -> void:
	pass

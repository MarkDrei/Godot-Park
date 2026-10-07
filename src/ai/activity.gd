class_name Activity
extends RefCounted
## A unit of NPC behaviour (walk somewhere and do something). Brains run one at a time.

var actor: Actor
var world: World
var done := false
var failed := false
var label := "schlendert herum"
var timeout := 300.0
var elapsed := 0.0
var kind := ""
var _walking := false


func begin(a: Actor) -> void:
	actor = a
	world = a.world
	start()


func start() -> void:
	pass


func tick(delta: float) -> void:
	elapsed += delta
	if elapsed > timeout:
		done = true
		return
	update(delta)


func update(_delta: float) -> void:
	pass


## Cleanup; always called once when the activity ends or is interrupted.
func end() -> void:
	pass


func walk_to(p: Vector3, run := false) -> bool:
	_walking = actor.go_to(p, run)
	if not _walking:
		failed = true
	return _walking


## True once the walk started with walk_to has finished.
func walked() -> bool:
	if _walking and not actor.is_moving():
		_walking = false
		return true
	return not _walking

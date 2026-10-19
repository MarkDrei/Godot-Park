class_name Burg
extends Node3D
## The Ritterburg at runtime (doc/burg.md): built when the player comes close
## (World.load_area). Keeps the posts of its people and the spots of its games, lights the
## torches at dusk.

var world: World
var rng := RandomNumberGenerator.new()
var time := 0.0

## Where the people of the castle work (id -> [position, yaw]; HumanBrain "burg:<id>" spots),
## where its games start (id -> position).
var posts := {}
var spots := {}
## All torch flames in one mesh (BurgBuilder), lit at dusk.
var flames: MeshInstance3D


func setup(w: World) -> void:
	world = w
	name = "Burg"
	rng.seed = 7272


func _process(delta: float) -> void:
	time += delta
	if flames:
		flames.visible = Clock.daylight() < 0.5

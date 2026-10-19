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


## The market's stands as shops (their vendors come with the castle's people) and the talk
## options for brewing and forging (BurgTrade).
const SHOPS := {"burg_witch": "herb_witch", "burg_alchemist": "alchemist", "burg_pig": "pig", "burg_honey": "honey",
	"burg_fish": "fish", "burg_tavern": "tavern"}


func setup_gameplay() -> void:
	for id: String in SHOPS:
		var stall: String = SHOPS[id]
		var vendor: Vector3 = posts[stall][0]
		var counter: Vector3 = spots.get(stall, vendor + Vector3(0, 0, -2.0))
		world.shop_spots[id] = {"pos": counter, "vendor": vendor}
		var shop := Shop.new()
		shop.setup(world, id, world.shop_spots[id])
		add_child(shop)
		world.shops[id] = shop


func _process(delta: float) -> void:
	time += delta
	if flames:
		flames.visible = Clock.daylight() < 0.5

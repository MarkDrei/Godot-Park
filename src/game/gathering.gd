class_name Gathering
extends Interactable
## Gathering in the Nordwald (doc/nordwald.md): felling trees, mining boulders, picking up
## twigs and stones, berries, ceps and apples, fishing, and the secret cherry trees in the
## city park. One Interactable for all spots: it follows the spot nearest to the player.
## Spots regrow after some game hours; their state is saved in GameState.gather.

## kind -> verb (prompt), tool (Items tool kind, "" = by hand), regrow (game hours),
## work: hits per tier [no tool/1, 2, 3], anim and held item.
const KINDS := {
	"tree": {"verb": "Baum fällen", "tool": "axe", "regrow": 48.0, "hits": [6, 6, 3, 2], "anim": "chop", "item": "axe", "radius": 2.4},
	"secret_tree": {"verb": "Kirschbaum fällen", "tool": "axe", "regrow": 72.0, "hits": [6, 6, 3, 2], "anim": "chop", "item": "axe", "radius": 2.4},
	"rock": {"verb": "Stein abbauen", "tool": "pickaxe", "regrow": 24.0, "hits": [6, 6, 3, 2], "anim": "chop", "item": "pickaxe", "radius": 2.3},
	"twigs": {"verb": "Äste aufsammeln", "tool": "", "regrow": 12.0, "hits": [2, 2, 2, 2], "anim": "dig", "item": "", "radius": 1.8},
	"pebbles": {"verb": "Feldsteine aufsammeln", "tool": "", "regrow": 24.0, "hits": [3, 3, 3, 3], "anim": "dig", "item": "", "radius": 1.8},
	"berries": {"verb": "Beeren pflücken", "tool": "", "regrow": 24.0, "hits": [3, 3, 3, 3], "anim": "feed", "item": "basket", "radius": 2.2},
	"mushroom": {"verb": "Steinpilze sammeln", "tool": "", "regrow": 24.0, "hits": [2, 2, 2, 2], "anim": "dig", "item": "basket", "radius": 1.8},
	"apple": {"verb": "Äpfel pflücken", "tool": "", "regrow": 24.0, "hits": [3, 3, 3, 3], "anim": "feed", "item": "basket", "radius": 2.6},
	"fishing": {"verb": "Angeln", "tool": "rod", "regrow": 0.0, "hits": [1, 1, 1, 1], "anim": "fish", "item": "rod", "radius": 2.6},
}
## Seconds per hit by tool tier (index = tier; hand work uses 1).
const HIT_TIME := [0.65, 0.65, 0.55, 0.45]
## Every finished job tires a bit.
const FATIGUE := 3.0
const HUNGER := 1.5

var game: Node
var world: World
var spots: Array[Dictionary] = []
var target: Dictionary = {}          # spot nearest to the player (prompt/anchor)
var job: Dictionary = {}             # {spot, actor, hits, done, t} while working
var fishing: Dictionary = {}         # {spot, actor, bite_in, bite_left}
var _stumps := {}                    # spot id -> stump MeshInstance3D
var rng := RandomNumberGenerator.new()


func setup(g: Node) -> void:
	game = g
	world = g.world
	name = "Gathering"
	users = "human"
	rng.randomize()
	for t: Dictionary in world.trees:
		if t["forest"]:
			spots.append({"id": "tree_%d" % t["index"], "kind": "tree", "pos": Vector3(t["pos"].x, t["ground"], t["pos"].y), "tree": t, "nodes": []})
	for t: Dictionary in secret_trees(world):
		spots.append({"id": "tree_%d" % t["index"], "kind": "secret_tree", "pos": Vector3(t["pos"].x, t["ground"], t["pos"].y), "tree": t, "nodes": []})
	for s: Dictionary in world.gather_spots:
		spots.append(s)
	world.add_child(self)
	refresh()
	Clock.hour_changed.connect(func(_h: int) -> void: refresh())


## Four cherry trees in the city park that can be felled with an axe. Nothing marks them.
static func secret_trees(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for anchor: Vector2 in [Vector2(-95, 60), Vector2(60, -72), Vector2(104, 34), Vector2(-50, -76)]:
		var best := {}
		var best_d := INF
		for t: Dictionary in w.trees:
			if t["forest"] or t["kind"] != "cherry" or out.has(t):
				continue
			var d := (t["pos"] as Vector2).distance_to(anchor)
			if d < best_d:
				best_d = d
				best = t
		if not best.is_empty():
			out.append(best)
	return out


static func now() -> float:
	return Clock.day * 24.0 + Clock.hour()


func is_ready(s: Dictionary) -> bool:
	return now() >= float(GameState.gather.get(s["id"], -1.0))


## Shows or hides every spot by its regrow state.
func refresh() -> void:
	for s: Dictionary in spots:
		_show(s, is_ready(s))


func _show(s: Dictionary, on: bool) -> void:
	for n: Node3D in s.get("nodes", []):
		n.visible = on
	if s.has("tree"):
		var t: Dictionary = s["tree"]
		world.tree_batch.set_instance_visible(t["inst"], on)
		if not on and not _stumps.has(s["id"]):
			var st := MeshInstance3D.new()
			st.mesh = NatureModels.stump()
			var sc := float(t["trunk"]) / 0.45 * 1.3
			st.transform = Transform3D(Basis().scaled(Vector3(sc, 0.8, sc)), s["pos"] + Vector3(0, -0.05, 0))
			world.add_child(st)
			_stumps[s["id"]] = st
		elif on and _stumps.has(s["id"]):
			(_stumps[s["id"]] as Node3D).queue_free()
			_stumps.erase(s["id"])


# --- Interactable: follows the nearest spot -------------------------------------------

func anchor() -> Vector3:
	var a := _player()
	if a == null:
		return Vector3(1e6, 0, 1e6)
	if not job.is_empty():
		return a.global_position
	if not fishing.is_empty():
		return a.global_position
	target = _nearest(a)
	if target.is_empty():
		radius = 0.0
		return Vector3(1e6, 0, 1e6)
	radius = KINDS[target["kind"]]["radius"]
	return target["pos"]


func _player() -> Actor:
	var pc: PlayerController = game.player if game else null
	return pc.actor if pc else null


func _nearest(a: Actor) -> Dictionary:
	var p := a.global_position
	var best := {}
	var best_d := 3.0
	for s: Dictionary in spots:
		var q: Vector3 = s["pos"]
		if absf(q.x - p.x) > 3.0 or absf(q.z - p.z) > 3.0:
			continue
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < best_d and d <= KINDS[s["kind"]]["radius"] and is_ready(s) and _visible_to(s, a):
			best_d = d
			best = s
	return best


## Secret trees only show up for someone carrying an axe.
func _visible_to(s: Dictionary, a: Actor) -> bool:
	return s["kind"] != "secret_tree" or Items.tool_tier(a.inventory, "axe") > 0


func get_prompt(a: Actor) -> String:
	if not job.is_empty():
		var k: Dictionary = KINDS[job["spot"]["kind"]]
		return "%s … %d / %d" % [k["verb"], job["done"], job["hits"]]
	if not fishing.is_empty():
		return "Biss! Schnell einholen!" if fishing["bite_left"] > 0.0 else "Angeln … warte auf einen Biss"
	if target.is_empty():
		return ""
	var k: Dictionary = KINDS[target["kind"]]
	if k["tool"] != "" and Items.tool_tier(a.inventory, k["tool"]) == 0:
		return "%s – dafür brauchst du %s" % [k["verb"], {"axe": "eine Axt", "pickaxe": "eine Spitzhacke", "rod": "eine Angel"}[k["tool"]]]
	return k["verb"]


func can_interact(a: Actor) -> bool:
	if not a.is_human():
		return false
	if not fishing.is_empty() or not job.is_empty():
		return true
	if target.is_empty():
		return false
	var k: Dictionary = KINDS[target["kind"]]
	return k["tool"] == "" or Items.tool_tier(a.inventory, k["tool"]) > 0


func interact(a: Actor) -> void:
	if not fishing.is_empty():
		_reel_in()
		return
	if not job.is_empty() or target.is_empty():
		return
	start(a, target)


## Starts working on a spot (also used by tests and NPCs).
func start(a: Actor, s: Dictionary) -> bool:
	var k: Dictionary = KINDS[s["kind"]]
	var tier := Items.tool_tier(a.inventory, k["tool"]) if k["tool"] != "" else 1
	if k["tool"] != "" and tier == 0:
		return false
	if a.needs.fatigue > 92.0:
		GameState.toast.emit("%s ist zu müde zum Arbeiten. Erst mal ausruhen!" % a.display_name, "warn")
		return false
	var main: String = _yields(s, tier).keys()[0] if s["kind"] != "fishing" else "fish"
	if not a.can_add(main):
		GameState.toast.emit("Der Rucksack ist voll! Bring etwas zur Lagerkiste oder verkauf es.", "warn")
		return false
	a.stop_moving()
	a.face(s.get("face", s["pos"]), true)
	a.set_item(k["item"])
	a.anim = k["anim"]
	if s["kind"] == "fishing":
		fishing = {"spot": s, "actor": a, "bite_in": rng.randf_range(3.0, 7.0), "bite_left": 0.0, "pos": a.global_position}
		return true
	job = {"spot": s, "actor": a, "hits": int(k["hits"][tier]), "done": 0, "t": 0.0, "step": HIT_TIME[tier],
		"tier": tier, "pos": a.global_position}
	return true


func _process(delta: float) -> void:
	if not job.is_empty():
		_work(delta)
	elif not fishing.is_empty():
		_fish(delta)


func _cancelled(a: Actor, start_pos: Vector3) -> bool:
	return not is_instance_valid(a) or not a.controlled or a.move_input.length() > 0.05 \
		or a.global_position.distance_to(start_pos) > 0.5 or a.seat != null


func _work(delta: float) -> void:
	var a: Actor = job["actor"]
	if _cancelled(a, job["pos"]):
		_stop(a)
		job = {}
		return
	job["t"] += delta
	if job["t"] >= job["step"]:
		job["t"] = 0.0
		job["done"] += 1
		Sound.play("hit", a.global_position)
		if job["done"] >= job["hits"]:
			var s: Dictionary = job["spot"]
			var tier: int = job["tier"]
			job = {}
			_finish(a, s, tier)


func _finish(a: Actor, s: Dictionary, tier: int) -> void:
	_stop(a)
	var got := []
	for id: String in _yields(s, tier):
		var n := a.add_item(id, _yields_cache[id])
		if n > 0:
			got.append("%d %s" % [n, Items.name_of(id)])
	var k: Dictionary = KINDS[s["kind"]]
	GameState.gather[s["id"]] = now() + float(k["regrow"])
	_show(s, false)
	a.needs.fatigue = clampf(a.needs.fatigue + FATIGUE, 0.0, 100.0)
	a.needs.hunger = clampf(a.needs.hunger + HUNGER, 0.0, 100.0)
	GameState.add_stat("gathered")
	if _yields_cache.has("gem"):
		GameState.add_stat("gems_found", int(_yields_cache["gem"]))
	if s["kind"] in ["tree", "secret_tree"]:
		GameState.add_stat("trees_felled")
		Sound.play("success", a.global_position)
	else:
		Sound.play("pickup", a.global_position)
	if not got.is_empty():
		GameState.toast.emit("+ " + ", ".join(got), "info")
		a.emote("happy")


var _yields_cache := {}


## What a spot gives (counts depend on the tool tier and some luck).
func _yields(s: Dictionary, tier: int) -> Dictionary:
	var y := {}
	match s["kind"]:
		"tree":
			y = {"log": 3 + (1 if tier >= 3 else 0), "twig": 2}
		"secret_tree":
			y = {"cherry_wood": 2, "twig": 1}
		"rock":
			y = {"stone": 2 + mini(tier, 2) - 1}
			if rng.randf() < [0.0, 0.15, 0.25, 0.35][tier]:
				y["ore"] = 1
			if rng.randf() < [0.0, 0.02, 0.05, 0.12][tier]:
				y["gem"] = 1
		"twigs":
			y = {"twig": 3}
		"pebbles":
			y = {"stone": 2}
		"berries":
			y = {"berries": 3}
		"mushroom":
			y = {"mushroom": 2 + (1 if Clock.is_raining() else 0)}
		"apple":
			y = {"apple": 3}
	_yields_cache = y
	return y


func _stop(a: Actor) -> void:
	if is_instance_valid(a):
		a.anim = "idle"
		a.set_item("")


# --- Fishing --------------------------------------------------------------------------

func _fish(delta: float) -> void:
	var a: Actor = fishing["actor"]
	if _cancelled(a, fishing["pos"]):
		_stop(a)
		fishing = {}
		return
	if fishing["bite_left"] > 0.0:
		fishing["bite_left"] -= delta
		if fishing["bite_left"] <= 0.0:
			GameState.toast.emit("Zu langsam – der Fisch ist weg.", "info")
			_stop(a)
			fishing = {}
		return
	fishing["bite_in"] -= delta
	if fishing["bite_in"] <= 0.0:
		fishing["bite_left"] = 1.6
		a.rig.emote_text("!", UiTheme.GOLD)
		Sound.play("splash", a.global_position)
		GameState.toast.emit("Es zappelt! Schnell Aktion drücken!", "info")


func _reel_in() -> void:
	var a: Actor = fishing["actor"]
	if fishing["bite_left"] <= 0.0:
		GameState.toast.emit("Zu früh – noch beißt keiner.", "info")
		_stop(a)
		fishing = {}
		return
	fishing = {}
	_stop(a)
	if a.add_item("fish") > 0:
		GameState.add_stat("fish_caught")
		GameState.toast.emit("Eine Forelle! (%d im Rucksack)" % int(a.inventory["fish"]), "info")
		Sound.play("success", a.global_position)
		a.emote("happy")
	a.needs.fatigue = clampf(a.needs.fatigue + 1.0, 0.0, 100.0)
	a.needs.cheer(4.0)

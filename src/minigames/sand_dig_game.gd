class_name SandDigGame
extends Minigame
## Schatzsuche im Sandkasten with Mika (doc/playground.md): three things are buried in the
## big sandbox. Walk about in it and dig (Aktion) where you stand; eight tries. Mika says how
## close you are: heiß (next to it), warm (two away), kalt. Until it has been found, one of
## the three is always the old rusty key with the troll's face (Bruno's chest,
## PlaygroundQuests).

const COLS := 5
const ROWS := 4
const TRIES := 8
## [what you found, toast]; the key comes first while it is still in the sand.
const FINDS := ["eine Glasmurmel", "einen Plastik-Dino", "einen Kronkorken", "einen Kaugummi-Ring", "eine alte 50-Cent-Münze"]

var hidden := {}               # Vector2i -> find (index into FINDS, or -1 for the key)
var dug := {}                  # Vector2i -> true
var found: Array[String] = []
var tries := TRIES
var spot: FunctionSpot
var marks: Array[Node3D] = []
var state := "play"


func _init() -> void:
	title = "Schatzsuche mit Mika"
	host_id = "mika"
	free_roam = true


func describe() -> String:
	return "Auf dem Spielplatz im Stadtpark: Grab im Sandkasten nach drei vergrabenen Schätzen. Mika sagt dir, ob es heiß oder kalt ist."


func goal_done() -> bool:
	return GameState.stat("dig_best") >= 3


func can_start(a: Actor) -> bool:
	return super(a) and world.playground != null


static func key_in_sand() -> bool:
	return PlaygroundQuests.troll_step() == 0 and GameState.stat("rusty_key_found") == 0


func cell_size() -> Vector2:
	return Vector2((Playground.SANDBOX_SIZE.x - 0.6) / COLS, (Playground.SANDBOX_SIZE.y - 0.6) / ROWS)


## The cell under `p` (world), or (-1, -1) outside the sand.
func cell_at(p: Vector3) -> Vector2i:
	var local := Vector2(p.x, p.z) - (Playground.SANDBOX - (Playground.SANDBOX_SIZE - Vector2(0.6, 0.6)) * 0.5)
	var c := Vector2i(floori(local.x / cell_size().x), floori(local.y / cell_size().y))
	if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= ROWS:
		return Vector2i(-1, -1)
	return c


func cell_center(c: Vector2i) -> Vector3:
	var o := Playground.SANDBOX - (Playground.SANDBOX_SIZE - Vector2(0.6, 0.6)) * 0.5
	return world.playground.ground(o + (Vector2(c) + Vector2(0.5, 0.5)) * cell_size())


func begin() -> void:
	hidden.clear()
	dug.clear()
	found.clear()
	tries = TRIES
	state = "play"
	var cells: Array[Vector2i] = []
	for x in COLS:
		for y in ROWS:
			cells.append(Vector2i(x, y))
	cells.shuffle()
	var pool := range(FINDS.size())
	pool.shuffle()
	for i in 3:
		hidden[cells[i]] = -1 if i == 0 and key_in_sand() else pool[i]
	actor.teleport(cell_center(Vector2i(COLS / 2, ROWS - 1)))
	spot = FunctionSpot.new()
	spot.name = "SandDigSpot"
	spot.position = world.playground.ground(Playground.SANDBOX)
	spot.radius = Playground.SANDBOX_SIZE.length() * 0.5
	spot.users = "human"
	spot.prompt_fn = func(a: Actor) -> String:
		if a != actor or state != "play":
			return ""
		var c := cell_at(a.global_position)
		if c.x < 0:
			return "Zurück in den Sandkasten"
		return "Hier graben (%d Versuche)" % tries if not dug.has(c) else "Hier hast du schon gegraben"
	spot.available_fn = func(a: Actor) -> bool: return a == actor and state == "play" and cell_at(a.global_position).x >= 0 and not dug.has(cell_at(a.global_position))
	spot.action_fn = func(_a: Actor) -> void: dig()
	world.add_child(spot)
	var h := host()
	if h:
		world.playground.stop(h)
		if h.seat:
			h.stand_up()
		h.teleport(world.playground.ground(Playground.SANDBOX + Vector2(-Playground.SANDBOX_SIZE.x * 0.5 - 0.8, 0.5)))
		h.face(spot.position, true)
		host_say("Drei Schätze sind hier drin. Ich sag dir, ob's heiß oder kalt ist!", 3.5)
	set_info("Lauf im Sandkasten herum und grab mit Aktion (E) oder „Graben!“, wo du stehst.")
	add_button("Graben!", func() -> void: dig(), 200)
	_update_score()


func _update_score() -> void:
	set_score("Gefunden: %d von 3  ·  Versuche: %d" % [found.size(), tries])


func dig() -> void:
	if not active or state != "play" or tries <= 0:
		return
	var c := cell_at(actor.global_position)
	if c.x < 0:
		set_info("Erst zurück in den Sandkasten!")
		return
	if dug.has(c):
		set_info("Hier hast du schon gegraben. Woanders!")
		return
	dug[c] = true
	tries -= 1
	actor.face(cell_center(c) + Vector3(0, 0, 1), true)
	actor.play_anim("dig", 1.2)
	Sound.play("click", actor.global_position)
	_mark(c)
	if hidden.has(c):
		var what: int = hidden[c]
		hidden.erase(c)
		if what < 0:
			found.append("einen rostigen Schlüssel mit Trollgesicht")
			GameState.set_stat("rusty_key_found", 1)
			if actor.can_add("rusty_key"):
				actor.add_item("rusty_key")
			GameState.toast.emit("Ein rostiger Schlüssel mit einem kleinen Trollgesicht! Wem der wohl gehört?", "info")
			host_say("Ein Trollschlüssel! Den kennt bestimmt Bruno unter der Steinbrücke!", 3.5)
		else:
			found.append(FINDS[what])
			if FINDS[what].ends_with("Münze"):
				GameState.add_money(50, "Schatzsuche")
			GameState.toast.emit("Gefunden: %s!" % FINDS[what], "info")
			host_say("Juhu, ein Schatz!", 2.0)
		actor.emote("happy")
	else:
		var d := 99
		for h: Vector2i in hidden:
			d = mini(d, maxi(absi(h.x - c.x), absi(h.y - c.y)))
		host_say("Heiß! Ganz nah!" if d <= 1 else ("Warm …" if d == 2 else "Kalt, eiskalt."), 2.5)
	_update_score()
	if hidden.is_empty() or tries <= 0:
		_finish()


## A little heap of dug sand where somebody dug.
func _mark(c: Vector2i) -> void:
	var kit := MeshKit.new()
	kit.sphere(Vector3(0.25, 0.1, 0.1), Vector3(0.3, 0.12, 0.25), Color("d9bf80"), 3, 7)
	kit.disc(Vector3(-0.1, 0.13, -0.05), 0.24, 8, Color("a8905a"))
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.position = cell_center(c)
	world.add_child(mi)
	marks.append(mi)


func _finish() -> void:
	state = "done"
	GameState.set_stat_max("dig_best", found.size())
	var won := found.size() >= 2
	var list := ", ".join(found) if not found.is_empty() else "nichts"
	end_after(1.8, {"won": won, "joy": 22.0 if won else 10.0,
		"text": "Du hast %s gefunden. %s" % [list, "Ein echter Schatzsucher!" if won else "Beim nächsten Mal klappt's!"]})


func cleanup() -> void:
	if is_instance_valid(spot):
		spot.queue_free()
	for m in marks:
		if is_instance_valid(m):
			m.queue_free()
	marks.clear()

class_name Scenario
extends Node
## Base class and runner for scenario tests (tests/scenarios/<file>.gd).
##
## A scenario file extends Scenario and has test_* methods. The runner starts the
## game once per file (dev option scenario=<file>[:<test>]), resets the state before
## every test and prints "SCENARIO ok|FAIL <file>::<test>". Catalogue and
## conventions: doc/test-scenarios.md. Run with scripts/scenario.sh.
##
## Tests drive the game like a player: real input actions (press/hold/move), touch
## taps on buttons, dialog choices. Start states (at_spot, in_minigame, on_bench …)
## skip the way to the interesting point; every shortcut needs a separate "reach"
## test that gets there by playing.

## Game time runs this much faster than real time in scenarios (fixed-fps runs
## are not bound to real time anyway; this only makes the steps coarser).
const TIME_SCALE := 3.0
## A test that runs longer (game seconds) fails. A script error aborts the test function,
## so without this limit the runner would wait forever.
const TEST_TIMEOUT := 900.0

var game: Node
var world: World
var failures: Array[String] = []
var current := ""
## Toast texts since the last reset (UI.toast_shown), newest last.
var toasts: Array[String] = []


# --- Runner ----------------------------------------------------------------------

## Entry point (called by DevOptions): runs all tests of one file, or one test.
func run_file(g: Node, spec: String) -> void:
	var parts := spec.split(":")
	var path := "res://tests/scenarios/%s.gd" % parts[0]
	if not ResourceLoader.exists(path):
		print("SCENARIO FAIL %s: file not found" % path)
		get_tree().quit(1)
		return
	var script: GDScript = load(path)
	if script == null or not script.can_instantiate():
		print("SCENARIO FAIL %s: script does not load (parse error, see above)" % path)
		get_tree().quit(1)
		return
	var s: Scenario = script.new()
	s.name = parts[0]
	g.add_child(s)
	s.game = g
	s.world = g.world
	UI.toast_shown.connect(func(text: String) -> void: s.toasts.append(text))
	# Headless windows are 64x64; give the UI a real layout for touch taps. The browser
	# run (scripts/web_test.sh scenario:<file>) keeps its real window.
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = SCREENS["desktop"]
	# The browser run renders slowly in software: real speed, so toasts don't fade before a shot.
	Engine.time_scale = TIME_SCALE if DisplayServer.get_name() == "headless" else 1.0
	await s.wait(1.0)
	var names: Array[String] = []
	for m in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not names.has(n) and (parts.size() < 2 or n == parts[1]):
			names.append(n)
	var failed := 0
	for n in names:
		s.current = "%s::%s" % [parts[0], n]
		var before := s.failures.size()
		var t0 := Time.get_ticks_msec()
		print("  > ", s.current)  # shows where a hanging run stopped (VERBOSE=1)
		await s.reset()
		var done := [false]
		var body := func() -> void:
			await s.call(n)
			done[0] = true
		body.call()
		if not await s.wait_until(func() -> bool: return done[0], TEST_TIMEOUT):
			s.failures.append("%s: did not finish (script error above, or timeout)" % s.current)
		await s.teardown()
		var ok := s.failures.size() == before
		if not ok:
			failed += 1
		print("SCENARIO %s %s (%.1f s)" % ["ok  " if ok else "FAIL", s.current, (Time.get_ticks_msec() - t0) / 1000.0])
		for f in s.failures.slice(before):
			print("    ", f)
	if names.is_empty():
		print("SCENARIO FAIL %s: no test_* method matches" % spec)
		failed = 1
	print("SCENARIO DONE %s: %d tests, %d failed" % [parts[0], names.size(), failed])
	Engine.time_scale = 1.0
	get_tree().quit(1 if failed > 0 else 0)


# --- Start states -------------------------------------------------------------------

## Default start: fresh game state, 11:00 sunny day, the player controls `who`, standing
## on the great meadow facing north, rested and fed, camera behind them at zoom 1.
## Called before every test; tests may call it again.
func reset(who := "jens", hour := 11.0) -> void:
	for m: Minigame in Gameplay.minigames.values():
		if m.active:
			m.quit()
	UI.close_dialog("")
	UI.close_screens()
	UI.close_pause()
	UI.hide_title()
	game.title_mode = false
	Controls.set_touch_mode(false)
	_release_all()
	if Gameplay.eggs.duck_hats:
		Gameplay.eggs.toggle_duck_hats()
	GameState.new_game()
	Gameplay.gathering.refresh()  # felled trees from earlier tests grow back with the new game
	toasts.clear()
	Clock.running = true
	Clock.set_time(hour)
	Clock.set_weather(Clock.Weather.SUNNY, 100000.0)
	var a := present(who)
	if game.player.actor and game.player.actor.seat:
		game.player.actor.stand_up()
	game.player.control(a, false)
	GameState.controlled_actor = who  # control() skips this when `who` was already played
	game.player.input_enabled = true
	if a.seat:
		a.stand_up()
	a.stop_moving()
	a.inventory.clear()
	a.set_item("")
	var start := place("great_meadow")
	a.teleport(start)
	a.face(start + Vector3(0, 0, -5), true)
	game.camera.end_override()
	game.camera.zoom = 1.0
	game.camera.follow(a, false)
	a.needs.hunger = 20.0
	a.needs.fatigue = 15.0
	a.needs.joy = 70.0
	UI.show_hud(true)
	await wait(0.3)


## Override for per-test cleanup.
func teardown() -> void:
	_release_all()
	await frames(1)


## Makes an actor present in the park (not at home, visible) and returns it.
func present(id: String) -> Actor:
	var a := world.find_actor(id)
	assert(a != null, "unknown actor " + id)
	a.inside = false
	a.visible = true
	return a


## Places the player next to an NPC, facing it, so "interact" talks to it.
func next_to(id: String, dist := 1.4) -> Actor:
	var npc := present(id)
	var p := npc.global_position
	var a := player()
	a.teleport(p + Vector3(dist, 0, 0))
	a.face(p, true)
	if npc.brain is HumanBrain:
		# Stays put for a few seconds (out of its hours it would go home at once).
		npc.brain.suspend()
		(npc.brain as HumanBrain).think = 5.0
	await wait(0.25)  # the player picks a new focus every 0.15 s
	return npc


## Sends NPCs and animals within `radius` of `p` to a path point far away, so "interact"
## does not pick a bystander. Where people stand changes with any change to the map.
func clear_around(p: Vector3, radius := 8.0, keep: Array[String] = []) -> void:
	for a in world.actors:
		if a.controlled or a.inside or a.actor_id in keep or a.global_position.distance_to(p) > radius:
			continue
		if a.brain:
			a.brain.suspend()
		if a.brain is HumanBrain:
			(a.brain as HumanBrain).think = 5.0
		for i in 20:
			var q := world.random_path_point(a)
			if q.distance_to(p) > 25.0:
				a.teleport(q)
				break


## Places the player at a position (y from the terrain), facing `look_at` if given.
func put_player(pos: Vector3, look_at := Vector3.INF) -> void:
	var a := player()
	a.teleport(Vector3(pos.x, world.map.walk_height(pos.x, pos.z), pos.z))
	if look_at != Vector3.INF:
		a.face(look_at, true)
	await frames(3)


## Player on the nearest free bench, with the given fatigue.
func on_bench(fatigue := 90.0) -> Seat:
	var a := player()
	a.needs.fatigue = fatigue
	var seat := world.find_free_seat(a.global_position, a, 300.0) as Seat
	assert(seat != null, "no free seat")
	a.teleport(seat.approach_point())
	a.sit_on(seat)
	await wait(0.5)
	return seat


## Starts a minigame directly (host present). The way there is tested by reach tests.
func in_minigame(id: String) -> Minigame:
	var m: Minigame = Gameplay.minigames[id]
	var h := m.host()
	if h:
		h.inside = false
		h.visible = true
	m.start(player())
	await wait(0.5)
	return m


## Makes a shop open: vendor present at the counter and working. Null if it doesn't open.
func open_shop(id: String) -> Shop:
	var shop: Shop = world.shops[id]
	if shop.is_machine():
		return shop
	var v := present(shop.vendor_id)
	v.needs.hunger = 30.0  # a hungry vendor goes eating first (e.g. after a long test)
	v.teleport(shop.vendor_spot)
	v.brain.suspend()  # restart the activity from here (a walk to work would go on from afar)
	if await wait_until(func() -> bool: return shop.is_open(), 60.0):
		return shop
	return null


## Places the player at a shop's customer spot facing the counter.
func at_shop(id: String) -> Shop:
	var shop: Shop = world.shops[id]
	await put_player(shop.customer_spot(), shop.counter)
	await wait(0.3)
	return shop


## True if a toast containing `text` appeared since the last reset.
func toasted(text: String) -> bool:
	for t in toasts:
		if t.contains(text):
			return true
	return false


## Calls step() every few frames until the minigame ends; returns its result ({} on timeout).
func play_until_done(m: Minigame, step: Callable, timeout: float) -> Dictionary:
	var result := {}
	var cb := func(r: Dictionary) -> void: result.merge(r)
	m.finished.connect(cb)
	await wait_until(func() -> bool:
		if m.active:
			step.call()
		return not m.active, timeout)
	m.finished.disconnect(cb)
	return result


## The world position of a minigame's start spot (FunctionSpot, INF if the game has none).
func minigame_spot(id: String) -> Vector3:
	var s := world.get_node_or_null("MinigameSpot_" + id) as Node3D
	return s.global_position if s else Vector3.INF


## A named place from ParkLayout.PLACES as a world position.
func place(id: String) -> Vector3:
	var p := ParkLayout.place(id)
	return Vector3(p.x, world.map.walk_height(p.x, p.y), p.y)


# --- Playing ------------------------------------------------------------------------

func player() -> Actor:
	return game.player.actor


## Presses and releases an input action (interact, special, switch, emote, map, tasks, pause …).
func press(action: String) -> void:
	_action(action, true)
	await frames(2)
	_action(action, false)
	await frames(2)


## Presses a keyboard key (for code that reads keys directly: 1-9 in minigames, "quak").
func key(code: Key, unicode := 0) -> void:
	for down: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = unicode
		ev.pressed = down
		Input.parse_input_event(ev)
		await frames(1)


## Types text as key presses (letters only).
func type_text(text: String) -> void:
	for c in text:
		await key(OS.find_keycode_from_string(c.to_upper()), c.unicode_at(0))


## Holds an action for `secs` game seconds (e.g. run, move_left in minigames).
func hold(action: String, secs: float) -> void:
	Input.action_press(action)
	await wait(secs)
	Input.action_release(action)


## Walks with the keyboard actions in camera-relative direction (x right, y forward).
func move(dir: Vector2, secs: float, run := false) -> void:
	var acts := {"move_right": maxf(dir.x, 0), "move_left": maxf(-dir.x, 0),
		"move_forward": maxf(dir.y, 0), "move_back": maxf(-dir.y, 0)}
	for k: String in acts:
		if acts[k] > 0:
			Input.action_press(k, acts[k])
	if run:
		Input.action_press("run")
	await wait(secs)
	_release_all()


## Walks the player to a target with pathfinding (like tap-to-walk). True if arrived.
func walk_to(target: Vector3, timeout := 120.0, run := true, near := 1.6) -> bool:
	var a := player()
	if not a.go_to(target, run):
		return false
	return await wait_until(func() -> bool: return a.distance_to(target) < near or not a.is_moving(), timeout) \
		and a.distance_to(target) < near + 1.0


## The action prompt the HUD shows right now ("Hinsetzen", "Kaufen …").
func prompt() -> String:
	return game.player._prompt


## Taps a visible button by its text with a real touch event (touch mode on).
func tap_button(text: String) -> bool:
	var b := find_button(text)
	if b == null:
		return false
	var p := get_tree().root.get_final_transform() * b.get_global_rect().get_center()
	for down: bool in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.position = p
		ev.pressed = down
		Input.parse_input_event(ev)
		await frames(2)
	return true


## Taps somewhere on the 3D view (screen coordinates in the 1280x720 window).
func tap_screen(p: Vector2) -> void:
	for down: bool in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.position = p
		ev.pressed = down
		Input.parse_input_event(ev)
		await frames(2)


## Left mouse click at a canvas position (scaled to window coordinates).
func click_at(p: Vector2) -> void:
	var wp := get_tree().root.get_final_transform() * p
	for down: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = wp
		ev.global_position = wp
		ev.pressed = down
		Input.parse_input_event(ev)
		await frames(2)


## Clicks a visible button by its text (emits "pressed", like a mouse click).
func click_button(text: String) -> bool:
	var b := find_button(text)
	if b == null:
		return false
	b.pressed.emit()
	await frames(2)
	return true


## Chooses a dialog option by (part of) its text. False if no dialog/option.
func choose(text: String) -> bool:
	for b: Button in UI._dialog_buttons:
		if is_instance_valid(b) and b.text.contains(text):
			b.pressed.emit()
			await frames(2)
			return true
	return false


## Title and body text of the open dialog ("" if none).
func dialog_text() -> String:
	if not UI.is_dialog_open():
		return ""
	var out := ""
	for l in UI._dialog.find_children("*", "Label", true, false):
		if not (l.get_parent() is Button):
			out += (l as Label).text + "\n"
	return out


## All interactables whose prompt for the player starts with `text`.
func spots_with_prompt(text: String) -> Array[Interactable]:
	var out: Array[Interactable] = []
	for n in get_tree().get_nodes_in_group("interactables"):
		var it := n as Interactable
		if it.get_prompt(player()).begins_with(text):
			out.append(it)
	return out


## Texts of the options in the open dialog.
func dialog_options() -> Array[String]:
	var out: Array[String] = []
	for b: Button in UI._dialog_buttons:
		if is_instance_valid(b):
			out.append(b.text)
	return out


func find_button(text: String, from: Node = null) -> Button:
	var n := from if from else UI.root
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text.contains(text):
		return n
	for c in n.get_children():
		var b := find_button(text, c)
		if b:
			return b
	return null


# --- Screen layout and screenshots -----------------------------------------------------

## Window sizes for layout checks in native runs: desktop, landscape phone (19.5:9),
## tablet (4:3). The browser run uses its real window (a phone-sized viewport).
const SCREENS := {"desktop": Vector2i(1280, 720), "phone": Vector2i(844, 390), "tablet": Vector2i(1024, 768)}


## The screens a layout test runs on: all SCREENS natively, only the real window in the browser.
func screens() -> Array:
	return SCREENS.keys() if DisplayServer.get_name() == "headless" else ["browser"]


## Resizes the (headless) window to one of SCREENS and lets the UI re-layout.
func set_screen(screen: String) -> void:
	if SCREENS.has(screen) and DisplayServer.get_name() == "headless":
		get_tree().root.size = SCREENS[screen]
	await frames(3)
	UI.hud.set_prompt(prompt())  # the prompt centres itself only when its text changes


## Checks the layout (check_layout) and, in the browser run, has the browser take a
## screenshot `<label>.png`: prints "SHOT <label>" and waits until the page sets
## window.__shot to the label. The game is paused meanwhile, so nothing moves.
func shot(label: String, targets := {}, allow: Array[String] = []) -> void:
	await frames(3)
	check_layout(label, targets, allow)
	if not OS.has_feature("web"):
		return
	get_tree().paused = true
	print("SHOT %s" % label)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		if str(JavaScriptBridge.eval("window.__shot || ''", true)) == label:
			break
		await get_tree().process_frame
	get_tree().paused = false


## Layout rules for what is on screen now:
## - every UI box (panel, button, label, bar) lies fully inside the visible screen,
## - no two boxes overlap (nested ones aside; `allow` lists box names that may overlap),
## - no target (name -> world position: the player, an NPC, a minigame object) lies
##   behind the camera, off screen or under a UI box.
func check_layout(label: String, targets := {}, allow: Array[String] = []) -> void:
	var view := get_viewport().get_visible_rect()
	var boxes := ui_boxes()
	for b: Dictionary in boxes:
		if not view.grow(1.0).encloses(b.rect):
			check(false, "%s: '%s' %s sticks out of the screen %s" % [label, b.name, _r(b.rect), _r(view)])
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: Dictionary = boxes[i]
			var b: Dictionary = boxes[j]
			if allow.has(a.name) or allow.has(b.name):
				continue
			if a.rect.grow(-1.0).intersects(b.rect.grow(-1.0)):
				check(false, "%s: '%s' %s overlaps '%s' %s" % [label, a.name, _r(a.rect), b.name, _r(b.rect)])
	var cam := get_viewport().get_camera_3d()
	# Speech bubbles of characters near the camera are targets too (they must stay readable).
	for a: Actor in world.actors:
		if a.rig and a.rig.is_speaking() and a.rig._speech and a.global_position.distance_to(cam.global_position) < 25.0:
			targets["speech of " + a.actor_id] = a.rig._speech.global_position
	for t: String in targets:
		var w: Vector3 = targets[t]
		if t.begins_with("speech of ") and (cam.is_position_behind(w) or not view.has_point(cam.unproject_position(w))):
			continue  # a speaker outside the picture is fine; only a covered bubble is not
		if cam.is_position_behind(w):
			check(false, "%s: %s is behind the camera" % [label, t])
			continue
		var p := cam.unproject_position(w)
		if not view.has_point(p):
			check(false, "%s: %s is off screen at %s" % [label, t, str(p.round())])
			continue
		for b: Dictionary in boxes:
			# A toast over a speech bubble is gone after 4 s; anything else covering it is not.
			var toast := (b.node as Node).get_parent() == UI._toasts and t.begins_with("speech of ")
			if b.rect.has_point(p) and not allow.has(b.name) and not toast:
				check(false, "%s: %s at %s is hidden under '%s' %s" % [label, t, str(p.round()), b.name, _r(b.rect)])


## The visible UI boxes: panels, buttons, labels and bars, without their children.
## Plain containers are looked through; scroll areas clip their content; a dark
## full-screen shade (a modal screen's background) hides all boxes drawn before it.
## Returns [{name, rect, node}].
func ui_boxes(from: Node = null, clip := Rect2(-1e6, -1e6, 2e6, 2e6), out: Array[Dictionary] = []) -> Array[Dictionary]:
	var view := get_viewport().get_visible_rect()
	for c in (from if from else UI.root).get_children():
		var ctl := c as Control
		if ctl == null or not ctl.visible or ctl.modulate.a < 0.05:
			continue
		var r := ctl.get_global_rect()
		if ctl is ColorRect and (ctl as ColorRect).color.a >= 0.7 and r.encloses(view):
			out.clear()
			ui_boxes(ctl, clip, out)
		elif ctl is PanelContainer or ctl is Panel or ctl is BaseButton or ctl is Label or ctl is ProgressBar:
			r = r.intersection(clip)
			if r.size.x > 1.0 and r.size.y > 1.0:
				out.append({"name": _box_name(ctl), "rect": r, "node": ctl})
		else:
			ui_boxes(ctl, clip.intersection(r) if ctl.clip_contents else clip, out)
	return out


## A readable name for a box: its first text, or its class.
func _box_name(c: Control) -> String:
	if c is Button and (c as Button).text != "":
		return (c as Button).text
	if c is Label:
		return (c as Label).text.left(30)
	for l in c.find_children("*", "Label", true, false):
		if (l as Label).text != "":
			return (l as Label).text.left(30)
	return c.get_class()


func _r(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [r.position.x, r.position.y, r.size.x, r.size.y]


## Screen-space target near a character's head (for check_layout).
func head(a: Actor) -> Vector3:
	return a.global_position + Vector3(0, a.rig.height * 0.8, 0)


# --- Waiting and checking ------------------------------------------------------------

## Waits `secs` of game time (scaled by Engine.time_scale).
func wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, false).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Waits until cond() is true or `timeout` game seconds passed. Returns cond().
func wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func check_eq(a: Variant, b: Variant, msg: String) -> void:
	if a != b:
		failures.append("%s: %s (expected %s, got %s)" % [current, msg, str(b), str(a)])


func _action(action: String, down: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = down
	ev.strength = 1.0 if down else 0.0
	Input.parse_input_event(ev)


func _release_all() -> void:
	for a: String in Controls.KEYS:
		if Input.is_action_pressed(a):
			Input.action_release(a)

class_name BurgDice
extends Minigame
## "Hoch hinaus" with Würfel-Fritz (doc/burg.md): roll three dice, keep any and roll the others
## once more; then Fritz rolls (he keeps fours and better). The higher sum wins 2 €, a tie gives
## the stake back. Five wins: "Würfelglück".

var dice := [1, 1, 1]
var keep := [false, false, false]
var fritz := [1, 1, 1]
var state := "roll"             # roll, keep, fritz, done
var table := Vector3.ZERO
var cubes: Array[MeshInstance3D] = []
var labels: Array[Label3D] = []
var _keep_buttons: Array[Button] = []


func _init() -> void:
	title = "Würfelspiel"
	host_id = "wuerfelfritz"
	cost = 100


func describe() -> String:
	return "„Hoch hinaus“ mit Würfel-Fritz: drei Würfel, einmal nachwürfeln, die höhere Summe gewinnt. Einsatz 1 €."


func goal_done() -> bool:
	return GameState.stat("dice_wins") >= 5


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.burg != null


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "„Hoch hinaus“ würfeln (%s)" % GameState.format_money(cost)


func begin() -> void:
	# The counter between Fritz (behind it) and the customer's spot in front.
	var customer: Vector3 = world.burg.spots.get("dice", Vector3.ZERO)
	var behind: Vector3 = world.burg.posts["dice"][0]
	var front := (customer - behind)
	front.y = 0.0
	front = front.normalized()
	var side := front.cross(Vector3.UP)
	table = behind + front * 1.0
	table.y = behind.y
	actor.teleport(customer + side * 1.3)
	actor.face(table, true)
	look(customer + front * 0.8 - side * 0.9 + Vector3(0, 1.9, 0), table + Vector3(0, 1.1, 0))
	cubes.clear()
	labels.clear()
	for i in 3:
		var c := MeshInstance3D.new()
		var kit := MeshKit.new()
		kit.box(Vector3.ZERO, Vector3(0.16, 0.16, 0.16), Color("f1eee6"))
		c.mesh = kit.commit()
		add_child(c)
		var customer2: Vector3 = world.burg.spots.get("dice", table)
		var front2: Vector3 = customer2 - table
		front2.y = 0.0
		var side2: Vector3 = front2.normalized().cross(Vector3.UP)
		c.global_position = table + side2 * (-0.35 + i * 0.35) + Vector3(0, 1.16, 0)
		cubes.append(c)
		var l := Label3D.new()
		l.font_size = 64
		l.pixel_size = 0.004
		l.outline_size = 10
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(l)
		l.global_position = c.global_position + Vector3(0, 0.22, 0)
		labels.append(l)
	state = "roll"
	keep = [false, false, false]
	host_say("Hoch hinaus! Drei Würfel, einmal nachwürfeln.", 3.0)
	set_info("Würfle! Dann behalte, was dir gefällt, und würfle den Rest noch einmal.")
	add_button("Würfeln", func() -> void: roll(), 200)
	_show()


func _show() -> void:
	for i in 3:
		labels[i].text = str(dice[i]) if state != "roll" else "?"
		labels[i].modulate = Color("e2c050") if keep[i] else Color.WHITE
	set_score("Deine Summe: %d" % (dice[0] + dice[1] + dice[2]) if state != "roll" else "")


func roll() -> void:
	if state == "roll":
		for i in 3:
			dice[i] = rng.randi_range(1, 6)
		state = "keep"
		Sound.play("click", table)
		clear_buttons()
		_keep_buttons.clear()
		for i in 3:
			var b := add_button("Würfel %d behalten" % (i + 1), func() -> void: toggle(i), 170)
			_keep_buttons.append(b)
		add_button("Nachwürfeln", func() -> void: reroll(), 170)
		add_button("Fertig", func() -> void: done(), 120)
		set_info("Tippe auf die Würfel, die du behalten willst, dann „Nachwürfeln“ – oder „Fertig“.")
		_show()


func toggle(i: int) -> void:
	if state != "keep":
		return
	keep[i] = not keep[i]
	_keep_buttons[i].text = ("Würfel %d bleibt" if keep[i] else "Würfel %d behalten") % (i + 1)
	_show()


func reroll() -> void:
	if state != "keep":
		return
	for i in 3:
		if not keep[i]:
			dice[i] = rng.randi_range(1, 6)
	Sound.play("click", table)
	done()


## The player's dice stand; Fritz rolls his.
func done() -> void:
	if state != "keep":
		return
	state = "fritz"
	clear_buttons()
	_show()
	for i in 3:
		fritz[i] = rng.randi_range(1, 6)
	for i in 3:
		if fritz[i] < 4:
			fritz[i] = rng.randi_range(1, 6)
	var mine: int = dice[0] + dice[1] + dice[2]
	var his: int = fritz[0] + fritz[1] + fritz[2]
	host_say("Ich hab %d, %d und %d – macht %d!" % [fritz[0], fritz[1], fritz[2], his], 3.0)
	state = "done"
	var won := mine > his
	if won:
		GameState.add_stat("dice_wins")
	var money := 200 if won else (100 if mine == his else 0)
	end_after(2.0, {"won": won, "money": money, "joy": 14.0 if won else 6.0,
		"text": "Du %d, Fritz %d. %s" % [mine, his, "Gewonnen! Fritz zahlt 2 €." if won else ("Gleichstand – den Einsatz bekommst du zurück." if mine == his else "Fritz gewinnt. „Das Glück ist ein Würfel!“")]})


func cleanup() -> void:
	for n in cubes:
		n.queue_free()
	for n in labels:
		n.queue_free()
	cubes.clear()
	labels.clear()

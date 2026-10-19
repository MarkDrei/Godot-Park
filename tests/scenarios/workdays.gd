extends Scenario
## Working days: every vendor, host and performer can walk to their post, comes by the gate
## nearest it early enough and goes straight to work (also when arriving in the lead time);
## NPCs keep their pace when hungry or tired and walk briskly on long ways.


## Vendors, hosts and performers with a fixed post (HumanBrain._has_post).
func _post_workers() -> Array[Actor]:
	var out: Array[Actor] = []
	for a in world.actors:
		if a.brain is HumanBrain and (a.brain as HumanBrain)._has_post():
			out.append(a)
	return out


func test_every_post_is_reachable() -> void:
	await city()
	await fair()
	for a in _post_workers():
		var b := a.brain as HumanBrain
		var post := b.work_pos()
		check(post != Vector3.INF, "%s: post known" % a.actor_id)
		if post == Vector3.INF:
			continue
		var from: Vector3 = world.home_of(a)[0] if a.home_region != "park" else world.gate_outside[0]
		var path := world.nav.find_path(from, post, a.nav_profile)
		var end := path[path.size() - 1] if not path.is_empty() else from
		# Behind a counter, inside a booth or at the chess table the post is solid: they walk up
		# and are put on it (Work.update, Perform.exact, the stool).
		var placed: bool = a.def["work"]["type"] in ["shop", "chess"] or (a.def["work"].get("spot", "") as String).begins_with("fair:")
		check(Vector2(end.x - post.x, end.z - post.z).length() < (3.0 if placed else 1.0),
			"%s reaches the post (%.1f, %.1f): path ends %.1f m away" % [a.actor_id, post.x, post.z,
			Vector2(end.x - post.x, end.z - post.z).length()])


## Arriving in the lead time before work, a worker goes straight to the post. The lead was
## measured anew after the teleport to the gate and could end it again (no routine, a script error).
func test_arriving_early_goes_straight_to_work() -> void:
	await city()
	await fair()
	for a in _post_workers():
		var b := a.brain as HumanBrain
		var start: float = b._work_window()[0]
		if start >= 24.0 or Clock.is_raining():
			continue
		b.suspend()
		a.inside = true
		a.visible = false
		Clock.set_time(fposmod(start - b.commute_hours() + 0.02, 24.0))
		b._arrive()
		check(b.current != null and b.current.kind in ["work", "perform", "sit"],
			"%s arrives at %s and goes to work (%s)" % [a.actor_id, Clock.time_string(), b.current.kind if b.current else "nothing"])
		b.suspend()
		a.inside = true
		a.visible = false


## Park performers come by the gate nearest their spot and are there when their day starts.
func test_hosts_are_at_their_posts_on_time() -> void:
	await reset("jens", 6.0)
	var ids := ["jacques", "pierre", "harry", "ricarda"]
	for id in ids:
		var a := world.find_actor(id)
		a.brain.suspend()
		a.inside = true
		a.visible = false
	var first := 24.0
	for id in ids:
		first = minf(first, ((world.find_actor(id).brain as HumanBrain)._work_window()[0]))
	Clock.set_time(first - 3.0)
	var at := {}
	var last := 0.0
	for id in ids:
		last = maxf(last, (world.find_actor(id).brain as HumanBrain)._work_window()[0])
	while Clock.hour() < last + 0.1:
		for id in ids:
			var a := world.find_actor(id)
			var b := a.brain as HumanBrain
			if not at.has(id) and not a.inside and a.distance_to(b.work_pos()) < 2.0:
				at[id] = Clock.hour()
		await wait(1.0)
	for id in ids:
		var b := world.find_actor(id).brain as HumanBrain
		var start: float = b._work_window()[0]
		check(at.get(id, 99.0) <= start + 0.1, "%s at the post by %.1f h (arrived %s; %s)" % [id, start,
			"%.2f h" % at[id] if at.has(id) else "not", b.doing()])


func test_npcs_keep_their_pace_when_hungry_or_tired() -> void:
	var herbert := hold_npc("herbert")
	herbert.teleport(player().global_position + Vector3(20, 0, 0))
	await frames(2)
	var normal := herbert.current_speed()
	herbert.needs.hunger = 95.0
	herbert.needs.fatigue = 95.0
	check_eq(herbert.current_speed(), normal, "a starving, tired NPC walks at its own pace")
	player().needs.hunger = 95.0
	check(player().needs.speed_factor() < 0.6, "the player still slows down when starving")


func test_long_walks_are_brisk() -> void:
	var herbert := hold_npc("herbert")
	var from := place("great_meadow") + Vector3(30, 0, 0)
	herbert.teleport(from)
	herbert.go_direct(from + Vector3(0, 0, 150))
	await frames(2)
	var far := herbert.current_speed()
	herbert.go_direct(from + Vector3(0, 0, 10))
	await frames(2)
	var near := herbert.current_speed()
	check_eq(near, herbert.walk_speed, "own pace on a short way")
	check(far > near * 1.3, "brisk on a long way (%.2f vs %.2f m/s)" % [far, near])
	herbert.stop_moving()

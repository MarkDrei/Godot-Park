class_name CityRoute
extends RefCounted
## The way through the Oststadt's streets (doc/oststadt.md): the crossings as a graph, the
## shortest route from a car to a target and the next turn on it. The driving jobs show it as
## the arrow over the player's car (RouteArrow).

const U_TURN := 35.0          # metres a route pays for turning round (start behind the car)
const LOOK := 9.0             # metres ahead on the route the arrow points to

static var _nodes: Array[Vector2] = []
static var _links: Array = []         # per node: [[other node, metres], …]


static func _graph() -> void:
	if not _nodes.is_empty():
		return
	var cs := CityLayout.crossings()
	for c: Dictionary in cs:
		_nodes.append(c["pos"])
	for i in cs.size():
		var p: Vector2 = cs[i]["pos"]
		var out := []
		for arm: Vector2 in cs[i]["arms"]:
			var best := -1
			var best_d := INF
			for j in _nodes.size():
				var d := _nodes[j] - p
				if j != i and d.normalized().dot(arm) > 0.999 and d.length() < best_d:
					best_d = d.length()
					best = j
			if best >= 0:
				out.append([best, best_d])
		_links.append(out)


static func nodes() -> Array[Vector2]:
	_graph()
	return _nodes


## Street segments as [node a, node b] (each once).
static func segments() -> Array:
	_graph()
	var out := []
	for i in _links.size():
		for l: Array in _links[i]:
			if l[0] > i:
				out.append([i, l[0]])
	return out


## Where p joins the streets: {pos (on the street axis), a, b (the segment's crossings),
## via (the lot's driveway on the way, or Vector2.INF)}. A point on a lot leaves through the
## lot's nearest driveway, so the route never ends at the wrong side of a fence.
static func snap(p: Vector2) -> Dictionary:
	_graph()
	var via := Vector2.INF
	var q := p
	var lot := CityLayout.lot_at(p)
	if lot != "" and CityLayout.LOTS[lot].has("drives"):
		var best := INF
		for d: Rect2 in CityLayout.LOTS[lot]["drives"]:
			var c := d.get_center()
			if c.distance_to(p) < best:
				best = c.distance_to(p)
				via = c
		q = via
	var out := {}
	var best_d := INF
	for s: Array in segments():
		var a := _nodes[s[0]]
		var b := _nodes[s[1]]
		var x := Geometry2D.get_closest_point_to_segment(q, a, b)
		var d := x.distance_to(q)
		if d < best_d:
			best_d = d
			out = {"pos": x, "a": s[0], "b": s[1], "via": via}
	return out


## Shortest way from p (heading fwd, may be zero) to t: the points to drive through, from the
## car's street point over the crossings to the target's street point and the target itself.
static func route(p: Vector2, fwd: Vector2, t: Vector2) -> PackedVector2Array:
	_graph()
	var s := snap(p)
	var e := snap(t)
	var sp: Vector2 = s["pos"]
	var ep: Vector2 = e["pos"]
	var turn := func(towards: Vector2) -> float:
		var d := towards - sp
		return U_TURN if fwd != Vector2.ZERO and d.length() > 0.5 and d.normalized().dot(fwd) < -0.3 else 0.0
	# Dijkstra from the two ends of the car's segment.
	var n := _nodes.size()
	var dist := []
	var prev := []
	dist.resize(n)
	prev.resize(n)
	dist.fill(INF)
	prev.fill(-1)
	for k: int in [s["a"], s["b"]]:
		dist[k] = sp.distance_to(_nodes[k]) + turn.call(_nodes[k])
	var done := []
	done.resize(n)
	done.fill(false)
	for _i in n:
		var u := -1
		for k in n:
			if not done[k] and (u < 0 or dist[k] < dist[u]):
				u = k
		if u < 0 or dist[u] == INF:
			break
		done[u] = true
		for l: Array in _links[u]:
			var v: int = l[0]
			if dist[u] + l[1] < dist[v]:
				dist[v] = dist[u] + l[1]
				prev[v] = u
	# Into the target's segment from either end, or straight along a shared segment.
	var best := INF
	var last := -1
	for k: int in [e["a"], e["b"]]:
		var c: float = dist[k] + _nodes[k].distance_to(ep)
		if c < best:
			best = c
			last = k
	var same: bool = s["a"] == e["a"] and s["b"] == e["b"]
	var pts := PackedVector2Array()
	var tail := PackedVector2Array([ep])
	if e["via"] != Vector2.INF:
		tail.append(e["via"])
	tail.append(t)
	# From the car itself: out of a lot by its driveway, on a street straight along it.
	pts.append(p)
	if s["via"] != Vector2.INF:
		pts.append(s["via"])
		pts.append(sp)
	if same and sp.distance_to(ep) + turn.call(ep) <= best:
		pts.append_array(tail)
		return pts
	var chain: Array[Vector2] = []
	var k := last
	while k >= 0:
		chain.push_front(_nodes[k])
		k = prev[k]
	for c in chain:
		pts.append(c)
	pts.append_array(tail)
	return pts


## Length of a route in metres.
static func length(pts: PackedVector2Array) -> float:
	var sum := 0.0
	for i in range(1, pts.size()):
		sum += pts[i - 1].distance_to(pts[i])
	return sum


## What the driver should do next: {aim (a point LOOK metres ahead on the route, to steer
## for), turn ("" straight on, "left", "right", "back", "there"), in (metres to that turn),
## left (metres to the target), at (metres along the route where the car is)}. The car is placed on the route where it is nearest to it; a
## turn is announced at the next corner where the way bends.
static func guide(p: Vector2, fwd: Vector2, pts: PackedVector2Array) -> Dictionary:
	if pts.size() < 2:
		return {"aim": pts[0] if pts.size() == 1 else p, "turn": "there", "in": 0.0, "left": 0.0, "at": 0.0}
	# Arc length at every point and the nearest spot on the route.
	var arc := PackedFloat32Array([0.0])
	for j in range(1, pts.size()):
		arc.append(arc[j - 1] + pts[j - 1].distance_to(pts[j]))
	var k := 0
	var at := 0.0
	var best := INF
	for j in range(pts.size() - 1):
		var q := Geometry2D.get_closest_point_to_segment(p, pts[j], pts[j + 1])
		var d := q.distance_to(p)
		if d < best - 0.01:
			best = d
			k = j
			at = arc[j] + pts[j].distance_to(q)
	var total := arc[arc.size() - 1]
	var aim := _point_at(pts, arc, minf(at + LOOK, total))
	var out := {"aim": aim, "turn": "", "in": 0.0, "left": total - at + best, "at": at}
	if total - at < LOOK:
		out["turn"] = "there"
		out["in"] = total - at
		return out
	if fwd != Vector2.ZERO and (aim - p).length() > 2.0 and (aim - p).normalized().dot(fwd) < -0.3:
		out["turn"] = "back"
		return out
	# The next corner ahead.
	for j in range(k + 1, pts.size() - 1):
		var d0 := pts[j] - pts[j - 1]
		var d1 := pts[j + 1] - pts[j]
		if d0.length() < 0.5 or d1.length() < 0.5:
			continue
		if j + 1 == pts.size() - 1 and d1.length() < 8.0:
			break   # the last step from the street to the kerb is no turn
		d0 = d0.normalized()
		d1 = d1.normalized()
		var cross := d0.x * d1.y - d0.y * d1.x
		if absf(cross) > 0.5:
			# +z is south, +x east: a positive cross product turns clockwise seen from above.
			out["turn"] = "right" if cross > 0.0 else "left"
			out["in"] = arc[j] - at
			return out
	return out


## The part of a route between s0 and s1 metres along it.
static func slice(pts: PackedVector2Array, s0: float, s1: float) -> PackedVector2Array:
	var arc := PackedFloat32Array([0.0])
	for j in range(1, pts.size()):
		arc.append(arc[j - 1] + pts[j - 1].distance_to(pts[j]))
	var out := PackedVector2Array([_point_at(pts, arc, s0)])
	for j in pts.size():
		if arc[j] > s0 + 0.05 and arc[j] < s1 - 0.05:
			out.append(pts[j])
	out.append(_point_at(pts, arc, s1))
	return out


static func _point_at(pts: PackedVector2Array, arc: PackedFloat32Array, s: float) -> Vector2:
	for j in range(1, pts.size()):
		if arc[j] >= s:
			var seg := arc[j] - arc[j - 1]
			return pts[j - 1].lerp(pts[j], (s - arc[j - 1]) / seg if seg > 0.0 else 1.0)
	return pts[pts.size() - 1]

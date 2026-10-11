class_name KartRace
extends DriveJob
## Kart race on the kart track: three laps against three karts. A countdown, then go; the
## laps count when you pass the far side of the track and cross the start line again.

const LAPS := 3
const GRID := [[Vector2(239.0, -186.4), PI / 2], [Vector2(239.0, -189.6), PI / 2], [Vector2(234.0, -186.4), PI / 2], [Vector2(234.0, -189.6), PI / 2]]
const PRICE := 200

var karts: Array[Car] = []          # the player's first, then the AI karts
var laps := {}                      # Car -> laps done
var progress := {}                  # Car -> arc position on the track (m)
var halfway := {}                   # Car -> passed the far side in this lap
var arrived_karts: Array[Car] = []
var countdown := 0.0
var race_time := 0.0
var lap_start := 0.0
var best_lap := INF
var tops := {}                      # AI kart -> top speed
var track_len := 0.0
var _pts: Array = []


func _init() -> void:
	super()
	title = "Kartrennen"
	host_id = ""
	cost = PRICE


func describe() -> String:
	return "Kartbahn neben dem Autokino: drei Runden gegen drei Karts (2,00 €). Am Startplatz bei der Boxengasse anmelden."


func can_start(a: Actor) -> bool:
	return a.is_human() and not active


func begin() -> void:
	_pts = CityLayout.TRACK
	track_len = 0.0
	for i in _pts.size():
		track_len += (_pts[i] as Vector2).distance_to(_pts[(i + 1) % _pts.size()])
	if actor.vehicle:
		game.player.exit_car(true)
	karts.clear()
	for i in 4:
		var k: Car = world.city.find_car("kart%d" % (i + 1))
		k.speed = 0.0
		k.place(GRID[i][0], GRID[i][1])
		k.locked = i > 0
		karts.append(k)
		laps[k] = 0
		halfway[k] = false
		progress[k] = arc_pos(k.pos2())
	game.player.enter_car(karts[0])
	start_driving()
	for i in range(1, 4):
		tops[karts[i]] = [12.2, 11.4, 10.6][i - 1]
		karts[i].activate()
	arrived_karts.clear()
	countdown = 3.0
	race_time = 0.0
	best_lap = INF
	for k in karts:
		k.max_speed_factor = 0.0
	set_info("Drei Runden! Gas: W / „Gas“, lenken mit A/D oder dem Joystick.")


## Arc length position of p along the closed track centre line.
func arc_pos(p: Vector2) -> float:
	var best := INF
	var best_s := 0.0
	var s := 0.0
	for i in _pts.size():
		var a: Vector2 = _pts[i]
		var b: Vector2 = _pts[(i + 1) % _pts.size()]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := q.distance_to(p)
		if d < best:
			best = d
			best_s = s + a.distance_to(q)
		s += a.distance_to(b)
	return best_s


## Point on the centre line at arc position s.
func point_at(s: float) -> Vector2:
	s = fposmod(s, track_len)
	for i in _pts.size():
		var a: Vector2 = _pts[i]
		var b: Vector2 = _pts[(i + 1) % _pts.size()]
		var l := a.distance_to(b)
		if s <= l:
			return a.lerp(b, s / l)
		s -= l
	return _pts[0]


func job_tick(delta: float) -> void:
	if countdown > 0.0:
		var before := ceili(countdown)
		countdown -= delta
		set_score("%d …" % maxi(1, ceili(countdown)) if countdown > 0.0 else "Los!")
		if ceili(countdown) != before:
			Sound.play("beep" if countdown > 0.0 else "whistle")
		if countdown <= 0.0:
			for k in karts:
				k.max_speed_factor = 1.0
			lap_start = 0.0
		return
	race_time += delta
	for k in karts:
		_track(k)
	for i in range(1, karts.size()):
		_ai(karts[i], delta)
	var me := karts[0]
	set_score("Runde %d/%d · Platz %d · %.1f s" % [mini(laps[me] + 1, LAPS), LAPS, place_of(me), race_time])
	if laps[me] >= LAPS:
		_finish()


func _track(k: Car) -> void:
	var s := arc_pos(k.pos2())
	var old: float = progress[k]
	if absf(s - track_len * 0.5) < track_len * 0.15:
		halfway[k] = true
	# Crossing the start (arc 0 lies in the middle of the start straight's first point).
	if old > track_len * 0.8 and s < track_len * 0.2 and halfway[k]:
		laps[k] += 1
		halfway[k] = false
		if k == karts[0]:
			best_lap = minf(best_lap, race_time - lap_start)
			lap_start = race_time
			if laps[k] < LAPS:
				Sound.play("click")
		if laps[k] >= LAPS and not arrived_karts.has(k):
			arrived_karts.append(k)
	progress[k] = s


## Place of a kart: arrived_karts ones by order, the others by laps and arc position.
func place_of(k: Car) -> int:
	if arrived_karts.has(k):
		return arrived_karts.find(k) + 1
	var mine: float = laps[k] * track_len + progress[k]
	var place := 1 + arrived_karts.size()
	for o in karts:
		if o != k and not arrived_karts.has(o) and laps[o] * track_len + progress[o] > mine:
			place += 1
	return place


## AI karts: pure pursuit on the centre line, slower in bends.
func _ai(k: Car, _delta: float) -> void:
	if arrived_karts.has(k):
		k.set_input(-0.5 if k.speed > 0.5 else 0.0, 0.0)
		return
	var s: float = progress[k]
	var look := clampf(absf(k.speed) * 0.5 + 3.0, 3.0, 7.0)
	var target := point_at(s + look)
	var f := k.forward2()
	var to := target - k.pos2()
	var alpha := atan2(f.x * to.y - f.y * to.x, f.dot(to))
	var wb: float = k.spec["wheelbase"]
	var want := atan(2.0 * wb * sin(alpha) / look)
	var max_eff: float = float(k.spec["steer"]) / (1.0 + absf(k.speed) / 11.0)
	var steer := clampf(want / maxf(max_eff, 0.05), -1.0, 1.0)
	# Bend ahead: the direction change over the next 10 m.
	var d1 := point_at(s + 2.0) - point_at(s)
	var d2 := point_at(s + 12.0) - point_at(s + 10.0)
	var bend := absf(d1.angle_to(d2))
	var v: float = maxf(5.5, float(tops[k]) - bend * 6.0)
	k.set_input(clampf((v - k.speed) * 0.8, -1.0, 1.0), steer)


func _finish() -> void:
	var place := place_of(karts[0])
	GameState.add_stat("kart_races")
	if place == 1:
		GameState.add_stat("kart_wins")
	if best_lap < INF:
		GameState.flags["kart_best_lap"] = minf(float(GameState.flags.get("kart_best_lap", INF)), best_lap)
	var money: int = [500, 300, 100, 0][place - 1]
	end({"won": place == 1, "money": money, "joy": [25.0, 18.0, 12.0, 8.0][place - 1],
		"text": "Platz %d! Beste Runde: %.1f s." % [place, best_lap]})


func job_left() -> void:
	end({"won": false, "joy": 2.0, "text": "Rennen abgebrochen."})


func cleanup() -> void:
	super()
	for i in karts.size():
		var k := karts[i]
		if not is_instance_valid(k):
			continue
		k.max_speed_factor = 1.0
		k.set_input(0.0, 0.0)
		if k.driver == null:
			k.speed = 0.0
			k.place(CityLayout.KART_PIT.position + Vector2(3.0 + (i % 3) * 4.0, 6.0 + (i / 3) * 5.0), PI)
	karts.clear()

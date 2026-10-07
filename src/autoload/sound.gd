extends Node
## Procedural sound: every effect is synthesised once (lazily) into an AudioStreamWAV.
## Ambient loops (birds, crickets, rain, wind) follow time of day and weather.

const RATE := 22050

var _cache := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _ui: AudioStreamPlayer
var _ambient := {}
var _volume := 0.8
var _ambient_volume := 0.6
var _listener_world: Node3D
var _rng := RandomNumberGenerator.new()
var _ambient_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 99
	_volume = GameState.settings.get("volume", 0.8)
	_ambient_volume = GameState.settings.get("music", 0.6)
	_ui = AudioStreamPlayer.new()
	add_child(_ui)


## Called once the 3D world exists.
func attach_world(w: Node3D) -> void:
	_listener_world = w
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		p.max_distance = 45.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		w.add_child(p)
		_pool.append(p)
	for id: String in ["birds", "crickets", "rain", "wind"]:
		var a := AudioStreamPlayer.new()
		a.stream = _stream(id)
		a.volume_db = -80.0
		a.autoplay = false
		add_child(a)
		a.play()
		_ambient[id] = a


func set_volume(v: float) -> void:
	_volume = v


func set_ambient_volume(v: float) -> void:
	_ambient_volume = v


func play(name: String, pos = null, volume_db := 0.0, pitch := 1.0) -> void:
	if _volume <= 0.01:
		return
	var stream := _stream(name)
	if stream == null:
		return
	var db := volume_db + linear_to_db(_volume)
	if pos == null or _pool.is_empty():
		_ui.stream = stream
		_ui.volume_db = db
		_ui.pitch_scale = pitch
		_ui.play()
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.global_position = pos
			p.volume_db = db
			p.pitch_scale = pitch * _rng.randf_range(0.94, 1.06)
			p.play()
			return


func _process(delta: float) -> void:
	if _ambient.is_empty():
		return
	_ambient_timer -= delta
	if _ambient_timer > 0.0:
		return
	_ambient_timer = 0.25
	var day := Clock.daylight()
	var raining := Clock.is_raining()
	var warm := Clock.season in [Clock.Season.SPRING, Clock.Season.SUMMER]
	var targets := {
		"birds": day * (0.35 if raining else 1.0) * (0.4 if Clock.season == Clock.Season.WINTER else 1.0),
		"crickets": (1.0 - day) * (1.0 if warm and not raining else 0.0),
		"rain": 1.0 if raining else 0.0,
		"wind": 0.8 if Clock.weather == Clock.Weather.STORM else (0.35 if Clock.weather in [Clock.Weather.SNOW, Clock.Weather.CLOUDY] else 0.12),
	}
	for id: String in _ambient:
		var a: AudioStreamPlayer = _ambient[id]
		var lin := db_to_linear(a.volume_db)
		var tgt: float = targets[id] * _ambient_volume * 0.6
		lin = move_toward(lin, tgt, 0.05)
		a.volume_db = linear_to_db(maxf(lin, 0.0001))


# --- Synthesis ------------------------------------------------------------------------

func _stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var data: PackedFloat32Array
	var loop := false
	match name:
		"quack": data = _quack()
		"bark": data = _bark()
		"meow": data = _meow()
		"purr": data = _purr()
		"coin": data = _tones([[988.0, 0.07], [1318.0, 0.22]], 0.35)
		"pickup": data = _sweep(500.0, 1100.0, 0.12, 0.35)
		"achievement": data = _tones([[523.0, 0.12], [659.0, 0.12], [784.0, 0.12], [1046.0, 0.45]], 0.3)
		"success": data = _tones([[659.0, 0.1], [784.0, 0.1], [988.0, 0.3]], 0.3)
		"fail": data = _tones([[392.0, 0.15], [330.0, 0.15], [262.0, 0.35]], 0.3)
		"click": data = _sweep(900.0, 700.0, 0.03, 0.25)
		"whistle": data = _sweep(1800.0, 2200.0, 0.35, 0.2)
		"thunder": data = _thunder()
		"owl": data = _owl()
		"flap": data = _flap()
		"splash": data = _noise_burst(0.35, 0.4, 0.6)
		"hit": data = _noise_burst(0.06, 0.5, 0.2)
		"music": data = _guitar_phrase()
		"birds":
			data = _birds(6.0)
			loop = true
		"crickets":
			data = _crickets(4.0)
			loop = true
		"rain":
			data = _rain(2.0)
			loop = true
		"wind":
			data = _wind(3.0)
			loop = true
		_:
			return null
	var s := _to_wav(data, loop)
	_cache[name] = s
	return s


func _to_wav(data: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = data.size()
	return s


func _env(t: float, length: float, attack := 0.01, release := 0.08) -> float:
	if t < attack:
		return t / attack
	if t > length - release:
		return maxf(0.0, (length - t) / release)
	return 1.0


func _tones(notes: Array, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for n: Array in notes:
		var f: float = n[0]
		var len: float = n[1]
		var count := int(len * RATE)
		for i in count:
			var t := float(i) / RATE
			var e := _env(t, len, 0.005, len * 0.7)
			out.append((sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * e * vol)
	return out


func _sweep(f0: float, f1: float, len: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var phase := 0.0
	for i in int(len * RATE):
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / len)
		phase += TAU * f / RATE
		out.append(sin(phase) * _env(t, len) * vol)
	return out


func _quack() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in 2:
		var len := 0.14
		var phase := 0.0
		for i in int(len * RATE):
			var t := float(i) / RATE
			var f := lerpf(520.0, 330.0, t / len)
			phase += f / RATE
			var saw: float = 2.0 * (phase - floor(phase)) - 1.0
			var buzz := saw * (0.6 + 0.4 * sin(TAU * 1200.0 * t)) + _rng.randf_range(-0.15, 0.15)
			out.append(buzz * _env(t, len, 0.01, 0.05) * 0.35)
		for i in int(0.06 * RATE):
			out.append(0.0)
	return out


func _bark() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in 2:
		var len := 0.13
		var phase := 0.0
		for i in int(len * RATE):
			var t := float(i) / RATE
			var f := lerpf(380.0, 180.0, t / len)
			phase += f / RATE
			var saw: float = 2.0 * (phase - floor(phase)) - 1.0
			out.append((saw * 0.7 + _rng.randf_range(-0.5, 0.5)) * _env(t, len, 0.005, 0.06) * 0.4)
		for i in int(0.1 * RATE):
			out.append(0.0)
	return out


func _meow() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var len := 0.6
	var phase := 0.0
	for i in int(len * RATE):
		var t := float(i) / RATE
		var x := t / len
		var f := 550.0 + 350.0 * sin(x * PI) + 15.0 * sin(TAU * 7.0 * t)
		phase += TAU * f / RATE
		var s := sin(phase) + 0.4 * sin(phase * 2.0) + 0.2 * sin(phase * 3.0)
		out.append(s * _env(t, len, 0.04, 0.2) * 0.25)
	return out


func _purr() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var len := 1.2
	for i in int(len * RATE):
		var t := float(i) / RATE
		var am := 0.5 + 0.5 * sin(TAU * 24.0 * t)
		out.append(_rng.randf_range(-1.0, 1.0) * am * am * _env(t, len, 0.1, 0.3) * 0.25)
	return _lowpass(out, 0.08)


func _thunder() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var len := 3.0
	var b := 0.0
	for i in int(len * RATE):
		var t := float(i) / RATE
		b = b * 0.985 + _rng.randf_range(-1.0, 1.0) * 0.15
		var e := exp(-t * 1.2) * (0.6 + 0.4 * sin(t * 13.0) * sin(t * 3.0))
		out.append(b * e * 1.4)
	return out


func _owl() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k: float in [0.35, 0.6]:
		var len: float = k
		for i in int(len * RATE):
			var t := float(i) / RATE
			out.append(sin(TAU * 370.0 * t + 0.4 * sin(TAU * 5.0 * t)) * _env(t, len, 0.08, 0.15) * 0.3)
		for i in int(0.15 * RATE):
			out.append(0.0)
	return out


func _flap() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in 4:
		for i in int(0.05 * RATE):
			out.append(_rng.randf_range(-1.0, 1.0) * (1.0 - float(i) / (0.05 * RATE)) * 0.3)
		for i in int(0.04 * RATE):
			out.append(0.0)
	return _lowpass(out, 0.3)


func _noise_burst(len: float, vol: float, cutoff: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in int(len * RATE):
		var t := float(i) / RATE
		out.append(_rng.randf_range(-1.0, 1.0) * exp(-t * 10.0 / len) * vol)
	return _lowpass(out, cutoff)


func _lowpass(data: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y := 0.0
	for i in data.size():
		y += (data[i] - y) * k
		data[i] = y
	return data


## Karplus-Strong plucked strings playing a little pentatonic phrase.
func _guitar_phrase() -> PackedFloat32Array:
	var notes := [261.6, 293.7, 329.6, 392.0, 440.0, 523.3]
	var out := PackedFloat32Array()
	out.resize(int(3.2 * RATE))
	out.fill(0.0)
	var start := 0
	for n in 8:
		var f: float = notes[_rng.randi() % notes.size()]
		var period := int(RATE / f)
		var buf := PackedFloat32Array()
		for i in period:
			buf.append(_rng.randf_range(-1.0, 1.0))
		var length := int(1.2 * RATE)
		for i in length:
			var idx := start + i
			if idx >= out.size():
				break
			var j := i % period
			var v := buf[j]
			buf[j] = (v + buf[(j + 1) % period]) * 0.497
			out[idx] += v * 0.25
		start += int(RATE * [0.25, 0.25, 0.5, 0.375][n % 4])
	return out


func _birds(len: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(len * RATE))
	out.fill(0.0)
	for c in 14:
		var t0 := _rng.randf_range(0.0, len - 0.6)
		var base := _rng.randf_range(2200.0, 4200.0)
		var notes := _rng.randi_range(2, 6)
		var t := t0
		for k in notes:
			var dur := _rng.randf_range(0.04, 0.12)
			var f0 := base * _rng.randf_range(0.85, 1.2)
			var f1 := f0 * _rng.randf_range(0.7, 1.4)
			var phase := 0.0
			for i in int(dur * RATE):
				var idx := int(t * RATE) + i
				if idx >= out.size():
					break
				var x := float(i) / (dur * RATE)
				phase += TAU * lerpf(f0, f1, x) / RATE
				out[idx] += sin(phase) * sin(x * PI) * 0.08
			t += dur + _rng.randf_range(0.02, 0.08)
	return out


func _crickets(len: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in int(len * RATE):
		var t := float(i) / RATE
		var chirp := maxf(0.0, sin(TAU * 3.0 * t)) * maxf(0.0, sin(TAU * 30.0 * t))
		out.append(sin(TAU * 4400.0 * t) * chirp * 0.05 + sin(TAU * 3900.0 * t + 1.0) * maxf(0.0, sin(TAU * 2.3 * t + 2.0)) * maxf(0.0, sin(TAU * 26.0 * t)) * 0.03)
	return out


func _rain(len: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in int(len * RATE):
		out.append(_rng.randf_range(-1.0, 1.0) * 0.18)
	out = _lowpass(out, 0.35)
	for d in 120:
		var idx := _rng.randi_range(0, out.size() - 200)
		for k in 120:
			out[idx + k] += _rng.randf_range(-1.0, 1.0) * exp(-k / 20.0) * 0.25
	return out


func _wind(len: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in int(len * RATE):
		var t := float(i) / RATE
		out.append(_rng.randf_range(-1.0, 1.0) * (0.5 + 0.5 * sin(TAU * t / len * 2.0)) * 0.35)
	return _lowpass(_lowpass(out, 0.05), 0.1)

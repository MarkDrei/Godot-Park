class_name DevOptions
extends RefCounted
## Startup options for testing and screenshots. Read from the command line
## (after "--") or, on the web, from the URL query (?time=14&season=1&cam=...).
##   time=H  season=0..3  weather=0..5  control=<actor id>  cam=x,y,z,tx,ty,tz
##   quality=low|medium|high  autotest=1 (prints a status line, used by tests)

var time := -1.0
var season := -1
var weather := -1
var control := ""
var cam := PackedFloat32Array()
var quality := ""
var autotest := false
var freeze_time := false


static func parse() -> DevOptions:
	var d := DevOptions.new()
	var pairs := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.substr(2).split("=", true, 1)
			pairs[kv[0]] = kv[1]
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if q is String and q.length() > 1:
			for part in (q as String).substr(1).split("&"):
				var kv := part.split("=", true, 1)
				if kv.size() == 2:
					pairs[kv[0]] = kv[1].uri_decode()
	d.time = float(pairs.get("time", "-1"))
	d.season = int(pairs.get("season", "-1"))
	d.weather = int(pairs.get("weather", "-1"))
	d.control = pairs.get("control", "")
	d.quality = pairs.get("quality", "")
	d.autotest = pairs.get("autotest", "0") == "1"
	d.freeze_time = pairs.get("freeze", "0") == "1"
	if pairs.has("cam"):
		for v in (pairs["cam"] as String).split(","):
			d.cam.append(float(v))
	return d


func apply_world(game: Node) -> void:
	if season >= 0:
		Clock.season_locked = true
		Clock.day = season * Clock.DAYS_PER_SEASON + 1
		Clock.set_season(season)
	if time >= 0.0:
		Clock.set_time(time)
	if weather >= 0:
		Clock.set_weather(weather, 100000.0)
	if freeze_time:
		Clock.running = false
	if quality != "":
		GameState.settings["quality"] = quality


func after_start(game: Node) -> void:
	if cam.size() == 6:
		var pos := Vector3(cam[0], cam[1], cam[2])
		var tgt := Vector3(cam[3], cam[4], cam[5])
		game.title_mode = false
		UI.hide_title()
		game.camera.set_override(Transform3D(Basis(), pos).looking_at(tgt, Vector3.UP))
		game.camera._override_blend = 1.0
		if game.camera.target == null:
			game.camera.target = game.world.actors[0]
	if autotest:
		await game.get_tree().create_timer(3.0).timeout
		print("AUTOTEST READY actors=%d fps=%d" % [game.world.actors.size(), Engine.get_frames_per_second()])

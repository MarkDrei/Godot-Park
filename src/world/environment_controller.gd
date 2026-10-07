class_name EnvironmentController
extends Node3D
## Sun, moon, sky, fog, weather particles, seasons and the night-time lamp light pool.
## Drives the global shader parameters every frame.

const SKY_SHADER := preload("res://src/shaders/sky.gdshader")
const LIGHT_POOL := 6

var world: World
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var rain: CPUParticles3D
var snow: CPUParticles3D
var leaves: CPUParticles3D
var fireflies: CPUParticles3D
var petals: CPUParticles3D
var lamp_lights: Array[OmniLight3D] = []
var follow_target: Node3D            # camera; particles follow it

# Smoothed weather state.
var _wet := 0.0
var _snow := 0.0
var _cloud := 0.3
var _fog := 0.0
var _storm_timer := 5.0
var _flash := 0.0
var _lamp_timer := 0.0
var quality := "high"


func setup(w: World) -> void:
	world = w
	name = "Environment"
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.002
	env.fog_sky_affect = 0.3
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.2
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.shadow_enabled = false
	add_child(moon)

	rain = _particles(900, 1.0, Vector3(30, 14, 30), Color(0.75, 0.82, 0.95, 0.55), Vector3(0.015, 0.5, 0.015), Vector3(0, -24, 0))
	snow = _particles(700, 6.0, Vector3(30, 14, 30), Color(1, 1, 1, 0.95), Vector3(0.06, 0.06, 0.06), Vector3(0, -1.2, 0))
	snow.initial_velocity_min = 0.2
	snow.initial_velocity_max = 0.6
	snow.spread = 60.0
	leaves = _particles(120, 7.0, Vector3(26, 10, 26), Color(0.85, 0.42, 0.12, 1.0), Vector3(0.12, 0.02, 0.09), Vector3(0.4, -0.7, 0.2))
	leaves.angular_velocity_min = -120
	leaves.angular_velocity_max = 120
	fireflies = _particles(80, 5.0, Vector3(24, 2.5, 24), Color(1.0, 0.95, 0.4, 1.0), Vector3(0.05, 0.05, 0.05), Vector3(0, 0.05, 0))
	fireflies.initial_velocity_min = 0.1
	fireflies.initial_velocity_max = 0.4
	fireflies.spread = 180.0
	(fireflies.mesh.surface_get_material(0) as StandardMaterial3D).emission_enabled = true
	(fireflies.mesh.surface_get_material(0) as StandardMaterial3D).emission = Color(1.0, 0.9, 0.3)
	petals = _particles(90, 7.0, Vector3(26, 10, 26), Color(1.0, 0.8, 0.88, 1.0), Vector3(0.06, 0.01, 0.05), Vector3(0.3, -0.5, 0.2))
	petals.angular_velocity_min = -90
	petals.angular_velocity_max = 90

	for i in LIGHT_POOL:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.55)
		l.omni_range = 11.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		lamp_lights.append(l)
	Clock.season_changed.connect(_on_season_changed)
	_on_season_changed(Clock.season)
	settle()


func _particles(amount: int, lifetime: float, box: Vector3, color: Color, size: Vector3, gravity: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = Vector3.DOWN
	p.gravity = gravity
	p.local_coords = false
	p.emitting = false
	p.preprocess = lifetime
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	add_child(p)
	return p


func set_quality(q: String) -> void:
	quality = q
	sun.shadow_enabled = q != "low"
	sun.directional_shadow_max_distance = 45.0 if q == "medium" else 70.0
	var scale := 0.4 if q == "low" else (0.7 if q == "medium" else 1.0)
	rain.amount = int(900 * scale)
	snow.amount = int(700 * scale)


func _process(delta: float) -> void:
	var h := Clock.hour()
	var day := Clock.daylight()
	var w := Clock.weather
	# --- Weather targets ---
	var rain_target := 1.0 if Clock.is_raining() else 0.0
	var snow_falling := w == Clock.Weather.SNOW
	var cloud_target: float = {Clock.Weather.SUNNY: 0.25, Clock.Weather.CLOUDY: 0.62, Clock.Weather.RAIN: 0.85,
		Clock.Weather.FOG: 0.5, Clock.Weather.SNOW: 0.8, Clock.Weather.STORM: 0.95}[w]
	var fog_target := 0.022 if w == Clock.Weather.FOG else (0.006 if rain_target > 0.0 or snow_falling else 0.0016)
	_cloud = move_toward(_cloud, cloud_target, delta * 0.05)
	_fog = move_toward(_fog, fog_target, delta * 0.004)
	_wet = move_toward(_wet, rain_target, delta * (0.03 if rain_target > _wet else 0.006))
	var winter := Clock.season == Clock.Season.WINTER
	if winter:
		_snow = move_toward(_snow, 1.0 if snow_falling else 0.7, delta * 0.01)
	else:
		_snow = move_toward(_snow, 0.0, delta * 0.05)
	# --- Sun & moon ---
	var sun_angle := (h - 6.0) / 12.0 * PI          # 0 at 6:00, PI at 18:00
	var elevation := sin(sun_angle)
	var sun_dir := Vector3(-cos(sun_angle), -maxf(elevation, -0.3), -0.35).normalized()
	_point_light(sun, sun_dir)
	var dim := 1.0 - _cloud * 0.55
	var warm := 1.0 - clampf(elevation * 2.5, 0.0, 1.0)
	sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.6, 0.35), warm)
	sun.light_energy = clampf(elevation * 3.0, 0.0, 1.0) * 1.25 * dim
	sun.visible = sun.light_energy > 0.01
	sun.shadow_enabled = quality != "low" and sun.light_energy > 0.15
	var moon_dir := Vector3(cos(sun_angle), -maxf(-elevation, 0.15), 0.3).normalized()
	_point_light(moon, moon_dir)
	moon.light_energy = clampf(-elevation * 2.0 + 0.2, 0.0, 1.0) * 0.32 * (1.0 - _cloud * 0.6)
	moon.visible = moon.light_energy > 0.01
	# --- Sky ---
	var day_top := Color(0.25, 0.48, 0.86).lerp(Color(0.45, 0.5, 0.58), _cloud)
	var day_hor := Color(0.72, 0.84, 0.94).lerp(Color(0.7, 0.73, 0.76), _cloud)
	var dusk_top := Color(0.24, 0.27, 0.52)
	var dusk_hor := Color(1.0, 0.56, 0.32).lerp(Color(0.6, 0.5, 0.5), _cloud)
	var night_top := Color(0.015, 0.025, 0.07)
	var night_hor := Color(0.06, 0.08, 0.15)
	var dusk := clampf(1.0 - absf(elevation) * 4.0, 0.0, 1.0)
	var top := night_top.lerp(day_top, day).lerp(dusk_top, dusk * 0.7)
	var hor := night_hor.lerp(day_hor, day).lerp(dusk_hor, dusk * 0.8)
	if _flash > 0.0:
		top = top.lerp(Color(0.9, 0.9, 1.0), _flash)
		hor = hor.lerp(Color(0.9, 0.9, 1.0), _flash)
	sky_mat.set_shader_parameter("top_color", Vector3(top.r, top.g, top.b))
	sky_mat.set_shader_parameter("horizon_color", Vector3(hor.r, hor.g, hor.b))
	sky_mat.set_shader_parameter("star_amount", (1.0 - day) * (1.0 - _cloud))
	sky_mat.set_shader_parameter("cloud_amount", _cloud)
	var cloud_col := Color(1, 1, 1).lerp(Color(0.55, 0.58, 0.62), clampf((_cloud - 0.5) * 2.0, 0.0, 1.0))
	cloud_col = cloud_col.lerp(Color(1.0, 0.7, 0.55), dusk * 0.6).lerp(Color(0.08, 0.09, 0.14), 1.0 - day)
	sky_mat.set_shader_parameter("cloud_color", Vector3(cloud_col.r, cloud_col.g, cloud_col.b))
	# --- Ambient & fog ---
	var amb := Color(0.2, 0.24, 0.4).lerp(Color(0.62, 0.66, 0.72), day).lerp(Color(0.6, 0.5, 0.5), dusk * 0.3)
	amb = amb.lerp(Color(1, 1, 1), _flash * 0.8)
	env.ambient_light_color = amb
	env.ambient_light_energy = lerpf(0.55, 0.75, day)
	env.fog_light_color = hor
	env.fog_density = _fog
	# --- Globals for shaders ---
	var night := 1.0 - day
	RenderingServer.global_shader_parameter_set("night_amount", night)
	RenderingServer.global_shader_parameter_set("wetness", _wet)
	RenderingServer.global_shader_parameter_set("snow_amount", _snow)
	var wind: float = {Clock.Weather.SUNNY: 0.3, Clock.Weather.CLOUDY: 0.6, Clock.Weather.RAIN: 0.9, Clock.Weather.FOG: 0.15,
		Clock.Weather.SNOW: 0.5, Clock.Weather.STORM: 1.8}[w]
	RenderingServer.global_shader_parameter_set("wind_strength", wind)
	_update_season_globals()
	# --- Particles around the camera ---
	if follow_target:
		var c := follow_target.global_position
		for p: CPUParticles3D in [rain, snow, leaves, petals]:
			p.global_position = c + Vector3(0, 9, 0)
		fireflies.global_position = Vector3(c.x, world.map.height_at(c.x, c.z) + 1.2, c.z)
	rain.emitting = rain_target > 0.0
	snow.emitting = snow_falling
	leaves.emitting = Clock.season == Clock.Season.AUTUMN and not snow_falling
	petals.emitting = Clock.season == Clock.Season.SPRING and Clock.season_progress() < 0.6 and day > 0.3
	fireflies.emitting = Clock.season == Clock.Season.SUMMER and night > 0.6 and rain_target == 0.0
	# --- Storm lightning ---
	_flash = maxf(0.0, _flash - delta * 3.0)
	if w == Clock.Weather.STORM:
		_storm_timer -= delta
		if _storm_timer <= 0.0:
			_storm_timer = randf_range(6.0, 16.0)
			_flash = 1.0
			Sound.play("thunder", null, -4.0)
	# --- Lamp light pool ---
	_lamp_timer -= delta
	if _lamp_timer <= 0.0:
		_lamp_timer = 0.5
		_update_lamps(night)


func _point_light(light: DirectionalLight3D, dir: Vector3) -> void:
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD
	light.global_transform = Transform3D(Basis.looking_at(dir, up), Vector3.ZERO)


func _update_lamps(night: float) -> void:
	var active := night > 0.35 and quality != "low"
	if not active or follow_target == null:
		for l in lamp_lights:
			l.visible = false
		return
	var c := follow_target.global_position
	var sorted := world.lamps.duplicate()
	sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(c) < b.distance_squared_to(c))
	var count := LIGHT_POOL if quality == "high" else 3
	for i in lamp_lights.size():
		var l := lamp_lights[i]
		if i < mini(count, sorted.size()):
			l.visible = true
			l.global_position = sorted[i] - Vector3(0, 0.3, 0)
			l.light_energy = 1.6 * clampf((night - 0.35) * 3.0, 0.0, 1.0)
		else:
			l.visible = false


# --- Seasons ---------------------------------------------------------------------

## Jump weather state to its target (after loading or when forcing a season).
func settle() -> void:
	_snow = 0.75 if Clock.season == Clock.Season.WINTER else 0.0
	_wet = 1.0 if Clock.is_raining() else 0.0
	_cloud = {Clock.Weather.SUNNY: 0.25, Clock.Weather.CLOUDY: 0.62, Clock.Weather.RAIN: 0.85,
		Clock.Weather.FOG: 0.5, Clock.Weather.SNOW: 0.8, Clock.Weather.STORM: 0.95}[Clock.weather]


func _on_season_changed(season: int) -> void:
	GameState.add_to_set("seasons", str(season))
	for s in 4:
		for n in get_tree().get_nodes_in_group("season_%d" % s):
			(n as Node3D).visible = s == season


func _update_season_globals() -> void:
	var s := Clock.season
	var t := Clock.season_progress()
	var tint := Color(1, 1, 1)
	var grass := Color(1, 1, 1)
	var foliage := 1.0
	var blossom := 0.0
	var ice := 0.0
	match s:
		Clock.Season.SPRING:
			tint = Color(0.95, 1.12, 0.88)
			grass = Color(0.95, 1.08, 0.9)
			foliage = lerpf(0.7, 1.0, smoothstep(0.0, 0.6, t))
			blossom = lerpf(0.85, 0.0, smoothstep(0.35, 0.95, t))
		Clock.Season.SUMMER:
			tint = Color(1, 1, 1).lerp(Color(1.06, 1.0, 0.82), t)
			grass = Color(1.02, 1.0, 0.92).lerp(Color(1.12, 1.0, 0.72), t)
		Clock.Season.AUTUMN:
			tint = Color(1.05, 1.0, 0.8).lerp(Color(1.75, 0.85, 0.32), smoothstep(0.0, 0.5, t))
			grass = Color(1.08, 0.98, 0.72)
			foliage = lerpf(1.0, 0.25, smoothstep(0.4, 1.0, t))
		Clock.Season.WINTER:
			tint = Color(1.4, 1.0, 0.5)
			grass = Color(0.9, 0.86, 0.68)
			foliage = lerpf(0.12, 0.0, smoothstep(0.0, 0.2, t)) + lerpf(0.0, 0.3, smoothstep(0.8, 1.0, t))
			ice = smoothstep(0.1, 0.35, t) * (1.0 - smoothstep(0.8, 1.0, t))
	RenderingServer.global_shader_parameter_set("season_tint", tint)
	RenderingServer.global_shader_parameter_set("grass_tint", grass)
	RenderingServer.global_shader_parameter_set("foliage_amount", foliage)
	RenderingServer.global_shader_parameter_set("blossom_amount", blossom)
	RenderingServer.global_shader_parameter_set("ice_amount", ice)
	world.ice = ice



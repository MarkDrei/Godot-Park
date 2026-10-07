extends Node
## Game clock: time of day, day counter, seasons and weather.
## One real second is one game minute (a day lasts 24 real minutes).

signal hour_changed(hour: int)
signal day_changed(day: int)
signal season_changed(season: int)
signal weather_changed(weather: int)

enum Season { SPRING, SUMMER, AUTUMN, WINTER }
enum Weather { SUNNY, CLOUDY, RAIN, FOG, SNOW, STORM }

const SEASON_NAMES := ["Frühling", "Sommer", "Herbst", "Winter"]
const WEATHER_NAMES := ["Sonnig", "Bewölkt", "Regen", "Nebel", "Schnee", "Gewitter"]
const MINUTES_PER_SECOND := 1.0
const DAYS_PER_SEASON := 3
const MINUTES_PER_DAY := 1440.0

## Weather probabilities per season: [sunny, cloudy, rain, fog, snow, storm].
const WEATHER_ODDS := [
	[45, 28, 18, 6, 0, 3],
	[58, 20, 10, 2, 0, 10],
	[24, 30, 28, 14, 0, 4],
	[26, 28, 4, 10, 32, 0],
]

var minutes := 9.0 * 60.0
var day := 0
var season := Season.SPRING
var weather := Weather.SUNNY
var time_scale := 1.0
var running := true
var weather_minutes_left := 180.0
var season_locked := false

var _rng := RandomNumberGenerator.new()
var _last_hour := -1


func _ready() -> void:
	_rng.randomize()
	_last_hour = int(hour())


func _process(delta: float) -> void:
	if running and not get_tree().paused:
		advance(delta * MINUTES_PER_SECOND * time_scale)


func advance(game_minutes: float) -> void:
	minutes += game_minutes
	while minutes >= MINUTES_PER_DAY:
		minutes -= MINUTES_PER_DAY
		day += 1
		day_changed.emit(day)
		if not season_locked:
			var s := (day / DAYS_PER_SEASON) % 4
			if s != season:
				set_season(s)
	var h := int(hour())
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)
	weather_minutes_left -= game_minutes
	if weather_minutes_left <= 0.0:
		roll_weather()


func hour() -> float:
	return minutes / 60.0


func set_time(h: float) -> void:
	minutes = fposmod(h, 24.0) * 60.0
	_last_hour = int(hour())
	hour_changed.emit(_last_hour)


func set_season(s: int) -> void:
	season = s
	season_changed.emit(season)
	roll_weather()


## Fraction (0..1) through the current season, used for gradual colour changes.
func season_progress() -> float:
	return (float(day % DAYS_PER_SEASON) + minutes / MINUTES_PER_DAY) / DAYS_PER_SEASON


func roll_weather() -> void:
	var odds: Array = WEATHER_ODDS[season]
	var total := 0
	for o: int in odds:
		total += o
	var pick := _rng.randi_range(0, total - 1)
	var w := 0
	for i in odds.size():
		pick -= odds[i]
		if pick < 0:
			w = i
			break
	set_weather(w)


func set_weather(w: int, duration := -1.0) -> void:
	weather = w
	weather_minutes_left = duration if duration > 0.0 else _rng.randf_range(90.0, 300.0)
	weather_changed.emit(weather)


func is_night() -> bool:
	var h := hour()
	return h < 6.0 or h >= 21.0


func is_raining() -> bool:
	return weather == Weather.RAIN or weather == Weather.STORM


## Daylight factor: 0 at night, 1 at noon-ish.
func daylight() -> float:
	var h := hour()
	return clampf(smoothstep(5.0, 8.0, h) - smoothstep(18.5, 21.5, h), 0.0, 1.0)


func time_string() -> String:
	var total := int(minutes)
	return "%02d:%02d" % [total / 60, total % 60]


func season_name() -> String:
	return SEASON_NAMES[season]


func weather_name() -> String:
	return WEATHER_NAMES[weather]


func to_dict() -> Dictionary:
	return {"minutes": minutes, "day": day, "season": season, "weather": weather}


func from_dict(d: Dictionary) -> void:
	minutes = d.get("minutes", minutes)
	day = d.get("day", day)
	season = d.get("season", season)
	_last_hour = int(hour())
	set_weather(d.get("weather", weather))
	season_changed.emit(season)

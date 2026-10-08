extends Node
## Persistent player progress: money, stats, achievements, discoveries, settings.
## Saved as JSON in user://save.json; settings in user://settings.cfg.

signal money_changed(cents: int)
signal achievement_unlocked(id: String)
signal stat_changed(key: String, value: int)
signal toast(text: String, kind: String)

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"
const VERSION := 1

var money := 500                       # cents
var stats := {}                        # key -> int
var sets := {}                         # key -> {item: true}
var unlocked := {}                     # achievement id -> unix time
var flags := {}                        # story flags (mime_freed, ...)
var actors := {}                       # actor id -> saved needs etc.
var storage := {}                      # storage chest at the lumber camp: item id -> count
var gather := {}                       # gathering spot id -> game hour it is ready again (Gathering)
var controlled_actor := ""
var bench_count := 0                   # set by the world (target of "bench_presser")
var save_path := SAVE_PATH             # tests use their own file (dev option save=<name>)

var settings := {
	"quality": "auto",       # auto | low | medium | high
	"volume": 0.8,
	"music": 0.6,
	"camera_sensitivity": 1.0,
	"show_fps": false,
}

var _autosave := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func _process(delta: float) -> void:
	_autosave += delta
	if _autosave > 60.0:
		_autosave = 0.0
		if controlled_actor != "":
			save_game()


# --- Money --------------------------------------------------------------------

func add_money(cents: int, reason := "") -> void:
	money += cents
	money_changed.emit(money)
	set_stat_max("money_max", money)
	if reason != "":
		toast.emit("+%s  %s" % [format_money(cents), reason], "money")


func spend(cents: int) -> bool:
	if money < cents:
		toast.emit("Nicht genug Geld (%s nötig)" % format_money(cents), "warn")
		return false
	money -= cents
	money_changed.emit(money)
	return true


static func format_money(cents: int) -> String:
	var sign_str := "-" if cents < 0 else ""
	var c := absi(cents)
	return "%s%d,%02d €" % [sign_str, c / 100, c % 100]


# --- Stats and achievements -------------------------------------------------

func stat(key: String) -> int:
	if sets.has(key):
		return sets[key].size()
	return stats.get(key, 0)


func add_stat(key: String, amount := 1) -> void:
	stats[key] = stats.get(key, 0) + amount
	_stat_updated(key)


func set_stat(key: String, value: int) -> void:
	stats[key] = value
	_stat_updated(key)


func set_stat_max(key: String, value: int) -> void:
	if value > stats.get(key, 0):
		stats[key] = value
		_stat_updated(key)


## Adds an item to a named set; returns true when it was new.
func add_to_set(key: String, item: String) -> bool:
	if not sets.has(key):
		sets[key] = {}
	if sets[key].has(item):
		return false
	sets[key][item] = true
	_stat_updated(key)
	return true


func has_in_set(key: String, item: String) -> bool:
	return sets.has(key) and sets[key].has(item)


func _stat_updated(key: String) -> void:
	var value := stat(key)
	stat_changed.emit(key, value)
	for def: Dictionary in Achievements.for_stat(key):
		var target: int = def["target"]
		if target < 0:
			target = bench_count if key == "benches" else 1
		if target > 0 and value >= target:
			unlock(def["id"])


func unlock(id: String) -> void:
	if unlocked.has(id):
		return
	var def := Achievements.get_def(id)
	if def.is_empty():
		return
	unlocked[id] = int(Time.get_unix_time_from_system())
	achievement_unlocked.emit(id)
	if def.get("reward", 0) > 0:
		add_money(def["reward"])
	save_game()


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


func flag(key: String) -> bool:
	return flags.get(key, false)


func set_flag(key: String, value := true) -> void:
	flags[key] = value


# --- Persistence ---------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func new_game() -> void:
	money = 500
	stats = {}
	sets = {}
	unlocked = {}
	flags = {}
	actors = {}
	storage = {}
	gather = {}
	controlled_actor = ""
	money_changed.emit(money)


func save_game() -> void:
	var tree := get_tree()
	if tree:
		tree.call_group("persistent", "save_state")
	var data := {
		"version": VERSION,
		"money": money,
		"stats": stats,
		"sets": sets,
		"unlocked": unlocked,
		"flags": flags,
		"actors": actors,
		"storage": storage,
		"gather": gather,
		"controlled": controlled_actor,
		"clock": Clock.to_dict(),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	money = int(data.get("money", 500))
	stats = {}
	for k: String in data.get("stats", {}):
		stats[k] = int(data["stats"][k])
	sets = data.get("sets", {})
	unlocked = data.get("unlocked", {})
	flags = data.get("flags", {})
	actors = data.get("actors", {})
	storage = {}
	gather = data.get("gather", {})
	var st: Dictionary = data.get("storage", {})
	for id: String in st:
		storage[id] = int(st[id])
	controlled_actor = data.get("controlled", "")
	Clock.from_dict(data.get("clock", {}))
	money_changed.emit(money)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for key: String in settings:
			settings[key] = cfg.get_value("settings", key, settings[key])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)

extends Node
## Persistent player progress: money, stats, achievements, discoveries, settings.
## Saved as JSON in user://save.json; settings in user://settings.cfg.
##
## All progress is numbers in `stats` (counters, bests, quest stages, days) or members of
## `sets`: an achievement can wait for any of them. Quest stages: `stage`/`set_stage`
## (QuestModule.ACTIVE, DONE for simple quests); once-a-day things: `done_today`/`mark_today`.
## A save from an older VERSION is migrated when it is loaded (`migrate`).

signal money_changed(cents: int)
signal achievement_unlocked(id: String)
signal stat_changed(key: String, value: int)
signal toast(text: String, kind: String)
signal tickets_changed(n: int)

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"
const VERSION := 3
const DEFAULT_SETTINGS := {
	"quality": "auto",       # auto | low | medium | high
	"volume": 0.8,
	"music": 0.6,
	"voice": 1.0,
	"camera_sensitivity": 1.0,
	"show_fps": false,
	"areas": "auto",         # auto | split | all (Game.split_areas)
}

var money := 500                       # cents
var tickets := 0                       # the Kirmes's second currency (doc/kirmes.md, FairTrade)
var stats := {}                        # key -> int
var sets := {}                         # key -> {item: true}
var unlocked := {}                     # achievement id -> unix time
var actors := {}                       # actor id -> saved needs etc.
var inventory := {}                    # the bag (item id -> count): the player's, it goes with every switch
var storage := {}                      # storage chest at the lumber camp: item id -> count
var gather := {}                       # gathering spot id -> game hour it is ready again (Gathering)
var controlled_actor := ""
var save_path := SAVE_PATH             # tests use their own file (dev option save=<name>)
var settings_path := SETTINGS_PATH     # and their own settings
var settings := DEFAULT_SETTINGS.duplicate()

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


# --- Tickets (Kirmes) -------------------------------------------------------------

func add_tickets(n: int, reason := "") -> void:
	tickets += n
	tickets_changed.emit(tickets)
	add_stat("tickets_won", n)
	if reason != "":
		toast.emit("+%d Ticket%s  %s" % [n, "" if n == 1 else "s", reason], "money")


func spend_tickets(n: int) -> bool:
	if tickets < n:
		toast.emit("Nicht genug Tickets (%d nötig)" % n, "warn")
		return false
	tickets -= n
	tickets_changed.emit(tickets)
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
		if value >= target:
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


# --- Quests and days --------------------------------------------------------------

## The stage a quest is in (0 = not started).
func stage(id: String) -> int:
	return stat(id)


func set_stage(id: String, n: int) -> void:
	set_stat(id, n)


## Once-a-day things: `key` keeps the day it was last done (+ 1, so 0 = never).
func done_today(key: String, day := Clock.day) -> bool:
	return stat(key) == day + 1


func mark_today(key: String, day := Clock.day) -> void:
	set_stat(key, day + 1)


# --- Persistence ---------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func new_game() -> void:
	money = 500
	tickets = 0
	stats = {}
	sets = {}
	unlocked = {}
	actors = {}
	inventory.clear()  # never replaced: the controlled actor's `inventory` is this dictionary
	storage = {}
	gather = {}
	controlled_actor = ""
	money_changed.emit(money)
	tickets_changed.emit(tickets)


func save_game() -> void:
	var tree := get_tree()
	if tree:
		tree.call_group("persistent", "save_state")
	var data := {
		"version": VERSION,
		"money": money,
		"tickets": tickets,
		"stats": stats,
		"sets": sets,
		"unlocked": unlocked,
		"actors": actors,
		"inventory": inventory,
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
	migrate(data)
	money = int(data.get("money", 500))
	tickets = int(data.get("tickets", 0))
	stats = {}
	for k: String in data.get("stats", {}):
		stats[k] = int(data["stats"][k])
	sets = data.get("sets", {})
	unlocked = data.get("unlocked", {})
	actors = data.get("actors", {})
	inventory.clear()
	var inv: Dictionary = data.get("inventory", {})
	for id: String in inv:
		inventory[id] = int(inv[id])  # JSON numbers load as floats
	storage = {}
	gather = data.get("gather", {})
	var st: Dictionary = data.get("storage", {})
	for id: String in st:
		storage[id] = int(st[id])
	controlled_actor = data.get("controlled", "")
	Clock.from_dict(data.get("clock", {}))
	money_changed.emit(money)
	return true


## Brings a save of an older version up to VERSION (in place).
static func migrate(data: Dictionary) -> void:
	var v := int(data.get("version", 1))
	var st: Dictionary = data.get("stats", {})
	if v < 2:
		# Version 1 kept quest states as flags ("" / "active" / "done", or true).
		var three := {"": 0, "active": 1, "done": 2}
		var flags: Dictionary = data.get("flags", {})
		for k: String in flags:
			var val: Variant = flags[k]
			if k.begins_with("dq_"):
				st[k] = three.get(str(val), 0)
			elif k == "fs_teddy":
				st["teddy"] = three.get(str(val), 0)
			elif k == "fs_ghost":
				st["ghost"] = three.get(str(val), 0)
			elif k == "fs_delivery":
				st["max_order"] = 1 if str(val) == "active" else 0
			elif k == "mime_stuck" and val == true:
				st["mime"] = maxi(int(st.get("mime", 0)), 1)
			elif k == "mime_freed" and val == true:
				st["mime"] = 2
			elif k == "rusty_key_found" and val == true:
				st["rusty_key_found"] = 1
		for k: String in ["mime_freed", "teddy_found", "ghost_helped", "assistant_found"]:
			st.erase(k)
		data.erase("flags")
	if v < 3:
		# Version 2 kept a bag per character. The bag of the character played last becomes the
		# player's; the others are dropped. Only for the two saves of October 2026: remove later.
		var acts: Dictionary = data.get("actors", {})
		var last: Dictionary = acts.get(str(data.get("controlled", "")), {})
		data["inventory"] = last.get("inv", {})
		for id: String in acts:
			if acts[id] is Dictionary:
				(acts[id] as Dictionary).erase("inv")
	data["stats"] = st
	data["version"] = VERSION


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		for key: String in settings:
			settings[key] = cfg.get_value("settings", key, settings[key])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(settings_path)

extends Node
## Recorded voice lines (doc/voices.md). scripts/voices.py makes them with ElevenLabs from
## tools/voices/voices.json: one clip per speaker and line, res://assets/voice/<speaker>/<key>.mp3,
## key = the first 12 hex digits of the md5 of the line without its „“ quotes. Lines without
## a clip stay silent, so voicing is per line and can grow character by character.
## - Dialogs (UI.dialog): the speaker is found by the dialog's title (the display name); every
##   quoted part („…“) of the text is played in turn, a text without quotes as a whole. Closing
##   the dialog stops it.
## - Speech bubbles (Actor.say): played at the speaker, quieter with distance.

const DIR := "res://assets/voice"
const QUOTES := "„“”\" \n\t"

var last_played := ""            # path of the last clip that started (tests)
var _player: AudioStreamPlayer   # dialog lines, one after the other
var _queue: Array[String] = []
var _speaker_ids := {}           # display name -> actor id
var _bubbles: Array = []         # AudioStreamPlayer3D, freed with their speaker


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.finished.connect(_next)
	add_child(_player)


## Clip path of a line (whether it exists or not).
static func path(speaker: String, text: String) -> String:
	return "%s/%s/%s.mp3" % [DIR, speaker, text.strip_edges().lstrip(QUOTES).rstrip(QUOTES).md5_text().substr(0, 12)]


static func has_clip(speaker: String, text: String) -> bool:
	return speaker != "" and ResourceLoader.exists(path(speaker, text))


func volume_db() -> float:
	var v: float = GameState.settings.get("volume", 0.8) * GameState.settings.get("voice", 1.0)
	return linear_to_db(maxf(v, 0.0001))


func apply_volume() -> void:
	_player.volume_db = volume_db()


func muted() -> bool:
	return GameState.settings.get("volume", 0.8) * GameState.settings.get("voice", 1.0) <= 0.01


func speaker_of(display_name: String) -> String:
	if _speaker_ids.is_empty():
		for list: Array in [Cast.PEOPLE, Cast.FOREST, Cast.CITY, Cast.FAIR]:
			for d: Dictionary in list:
				_speaker_ids[d["name"]] = d["id"]
	return _speaker_ids.get(display_name, "")


## A dialog opened: speak its lines if the speaker (the person named by the title, or
## `speaker`, e.g. a minigame's host) has clips for them.
func dialog(title: String, text: String, speaker := "") -> void:
	stop()
	if speaker == "":
		speaker = speaker_of(title)
	if OS.has_environment("VOICE_LOG"):  # scripts/voices.py quests collects dialog lines from this
		print("VOICE_DIALOG\t%s\t%s" % [speaker, JSON.stringify(text)])
	if speaker == "" or muted():
		return
	for p in VoiceLines.parts(text):
		if has_clip(speaker, p):
			_queue.append(path(speaker, p))
	if not _queue.is_empty():
		_stop_bubbles()
		_next()


func stop() -> void:
	_queue.clear()
	_player.stop()


func is_speaking() -> bool:
	return _player.playing or not _queue.is_empty()


func _next() -> void:
	if _queue.is_empty():
		return
	var p: String = _queue.pop_front()
	_player.stream = load(p)
	_player.volume_db = volume_db()
	_player.play()
	last_played = p


## A speech bubble: play the line at the speaker (not over a dialog that is speaking).
func say(actor: Node3D, speaker: String, text: String) -> void:
	if is_speaking() or muted() or not has_clip(speaker, text):
		return
	var p := path(speaker, text)
	var a := AudioStreamPlayer3D.new()
	a.stream = load(p)
	a.volume_db = volume_db()
	a.unit_size = 6.0
	a.max_distance = 30.0
	a.finished.connect(func() -> void:
		_bubbles.erase(a)
		a.queue_free())
	actor.add_child(a)
	a.play()
	_bubbles.append(a)
	last_played = p


func _stop_bubbles() -> void:
	for a in _bubbles:
		if is_instance_valid(a):
			a.queue_free()
	_bubbles.clear()

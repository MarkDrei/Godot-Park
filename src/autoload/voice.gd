extends Node
## Recorded voice lines (doc/voices.md). scripts/voices.py makes them with ElevenLabs from
## tools/voices/voices.json: one clip per speaker and line, res://assets/voice/<speaker>/<key>.mp3,
## key = the first 12 hex digits of the md5 of the line without its „“ quotes. Lines without
## a clip stay silent, so voicing is per line and can grow character by character.
## - Dialogs (UI.dialog): the speaker is found by the dialog's title (the display name); every
##   quoted part („…“) of the text is played in turn, a text without quotes as a whole. Closing
##   the dialog stops it.
## - Speech bubbles (Actor.say): played at the speaker, quieter with distance; beyond HEAR
##   from the camera there is no bubble either. Anonymous people speak with a crowd voice
##   (VoiceLines.crowd).
## - Radio (DriveJob.radio, passenger_line): a driving job's host or the passenger speaks
##   wherever they are, as loud as a dialog, one line after the other, after a bubble that is
##   speaking.

const DIR := "res://assets/voice"
const QUOTES := "„“”\" \n\t"
const HEAR := 40.0               # metres from the camera: farther, a bubble is neither shown nor heard

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


## Whether a speech bubble of `a` is in hearing (the player's own always is).
func in_hearing(a: Node3D) -> bool:
	var cam := a.get_viewport().get_camera_3d() if a.is_inside_tree() else null
	return cam == null or cam.global_position.distance_to(a.global_position) <= HEAR


func speaker_of(display_name: String) -> String:
	if _speaker_ids.is_empty():
		for list: Array in [Cast.PEOPLE, Cast.FOREST, Cast.CITY, Cast.FAIR, Cast.BURG, Cast.COAST]:
			for d: Dictionary in list:
				_speaker_ids[d["name"]] = d["id"]
	return _speaker_ids.get(display_name, "")


## A dialog opened: speak its lines if the speaker (the person named by the title, or
## `speaker`, e.g. a minigame's host) has clips for them. `quoted_only`: a narrated text
## (a minigame's result) speaks only the quoted words.
func dialog(title: String, text: String, speaker := "", quoted_only := false) -> void:
	stop()
	if speaker == "":
		speaker = speaker_of(title)
	if OS.has_environment("VOICE_LOG"):  # scripts/voices.py quests collects dialog lines from this
		print("VOICE_DIALOG\t%s\t%s" % [speaker, JSON.stringify(text if not quoted_only or "„" in text else "")])
	if speaker == "" or muted():
		return
	for p in VoiceLines.parts(text, quoted_only):
		if has_clip(speaker, p):
			_queue.append(path(speaker, p))
	if not _queue.is_empty():
		_stop_bubbles()
		_next()


## A radio line waits for a bubble that is speaking (the taxi passenger's goodbye).
func _process(_delta: float) -> void:
	if not _queue.is_empty() and not _player.playing and not _bubble_speaking():
		_next()


func _bubble_speaking() -> bool:
	_bubbles = _bubbles.filter(func(a: Variant) -> bool: return is_instance_valid(a) and (a as AudioStreamPlayer3D).playing)
	return not _bubbles.is_empty()


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


## A line over the radio (a driving job's host, DriveJob.radio): as loud as a dialog, after the
## line before it.
func radio(speaker: String, text: String) -> void:
	if OS.has_environment("VOICE_LOG"):
		print("VOICE_DIALOG\t%s\t%s" % [speaker, JSON.stringify("„%s“" % text)])
	if muted() or not has_clip(speaker, text):
		return
	_queue.append(path(speaker, text))
	if not _player.playing and not _bubble_speaking():
		_next()


## A speech bubble: play the line at the speaker (not over a dialog that is speaking).
func say(actor: Node3D, speaker: String, text: String) -> void:
	if OS.has_environment("VOICE_SAY_LOG"):   # every bubble: who, has a clip, a dialog speaking, metres, text
		var cam := actor.get_viewport().get_camera_3d()
		print("VOICE_SAY\t%s\t%s\t%s\t%.0f\t%s" % [speaker, has_clip(speaker, text), is_speaking(), cam.global_position.distance_to(actor.global_position) if cam else -1.0, text])
	if is_speaking() or muted() or not has_clip(speaker, text):
		return
	var p := path(speaker, text)
	var a := AudioStreamPlayer3D.new()
	a.stream = load(p)
	a.volume_db = volume_db()
	a.unit_size = 10.0
	a.max_distance = HEAR
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

extends Node
## Registers the input map at startup and tracks whether touch controls are in use.

signal touch_mode_changed(enabled: bool)

var touch_mode := false

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"run": [KEY_SHIFT],
	"interact": [KEY_E, KEY_ENTER],
	"special": [KEY_F],
	"switch": [KEY_Q, KEY_TAB],
	"map": [KEY_M],
	"tasks": [KEY_J],
	"bag": [KEY_I],
	"pause": [KEY_ESCAPE, KEY_P],
	"cam_left": [KEY_COMMA],
	"cam_right": [KEY_PERIOD],
	"emote": [KEY_R],
	"brake": [KEY_SPACE],
}

const PAD_BUTTONS := {
	"interact": [JOY_BUTTON_A],
	"special": [JOY_BUTTON_X],
	"switch": [JOY_BUTTON_Y],
	"run": [JOY_BUTTON_LEFT_SHOULDER],
	"map": [JOY_BUTTON_BACK],
	"pause": [JOY_BUTTON_START],
	"emote": [JOY_BUTTON_B],
	"tasks": [JOY_BUTTON_RIGHT_SHOULDER],
}

const PAD_AXES := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"cam_left": [JOY_AXIS_RIGHT_X, -1.0],
	"cam_right": [JOY_AXIS_RIGHT_X, 1.0],
	"accelerate": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"brake": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: String in KEYS:
		_ensure(action)
		for key: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action: String in PAD_BUTTONS:
		_ensure(action)
		for button: int in PAD_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
	for action: String in PAD_AXES:
		_ensure(action)
		var ev := InputEventJoypadMotion.new()
		ev.axis = PAD_AXES[action][0]
		ev.axis_value = PAD_AXES[action][1]
		InputMap.action_add_event(action, ev)
	touch_mode = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not touch_mode:
		set_touch_mode(true)
	elif (event is InputEventKey or event is InputEventJoypadButton) and touch_mode and event.is_pressed():
		set_touch_mode(false)


func set_touch_mode(enabled: bool) -> void:
	touch_mode = enabled
	touch_mode_changed.emit(enabled)

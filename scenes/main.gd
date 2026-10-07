extends Control

var _taps := 0

@onready var _counter: Label = %Counter
@onready var _info: Label = %Info


func _ready() -> void:
	_info.text = "Godot %s · %s" % [Engine.get_version_info().string, OS.get_name()]


func _on_tap_button_pressed() -> void:
	_taps += 1
	_counter.text = str(_taps)

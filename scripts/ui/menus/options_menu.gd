extends Control

signal open_main_menu

@onready var mute_button : Button = $Button
@onready var back_button : Button = $Button2

func _ready() -> void:
	if OptionsManager:
		OptionsManager.master_volume_changed.connect(_on_master_volume_changed)
		_on_master_volume_changed(OptionsManager.get_master_volume_normalized())
	mute_button.pressed.connect(_on_mute_button_pressed)
	back_button.pressed.connect(open_main_menu.emit)

func _on_master_volume_changed(new_value: float) -> void:
	mute_button.text = "MUTE" if new_value == 1.0 else "UN_MUTE"

func _on_mute_button_pressed() -> void:
	var new_value = 1.0 if OptionsManager.get_master_volume_normalized() == 0.0 else 0.0
	OptionsManager.set_master_volume_normalized(new_value)

extends Panel

signal start_run_requested

@onready var button : Button = $MarginContainer/Button

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void: 
	start_run_requested.emit()

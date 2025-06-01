extends Node

signal continue_game
signal start_newgame
signal options_menu

@onready var continue_button : Button = %ContinueButton
@onready var newgame_button : Button = %NewgameButton
@onready var quit_button : Button = %QuitButton
@onready var options_button : Button = %OptionsButton

func _ready() -> void:
	if PersistenceManager:
		continue_button.disabled = PersistenceManager.is_base_game_save()
		
	continue_button.pressed.connect(_on_continue_button_pressed)
	newgame_button.pressed.connect(_on_newgame_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_continue_button_pressed() -> void:
	continue_game.emit()
	
func _on_newgame_button_pressed() -> void:
	start_newgame.emit()

func _on_options_button_pressed() -> void:
	options_menu.emit()

extends Node

signal continue_game
signal newgame_game

@onready var continue_button : Button = %ContinueButton
@onready var newgame_button : Button = %NewgameButton
@onready var quit_button : Button = %QuitButton

func _ready() -> void:
	if PersistenceManager:
		continue_button.disabled = PersistenceManager.is_base_game_save()
		
	continue_button.pressed.connect(_on_continue_button_pressed)
	newgame_button.pressed.connect(_on_newgame_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_continue_button_pressed() -> void:
	continue_game.emit()
	
func _on_newgame_button_pressed() -> void:
	newgame_game.emit()
	

extends Node

var save_game_data : SaveGameData

const SAVE_PATH : String = "user://save.tres"

func _ready() -> void:
	load_data()

func save_data() -> void : 
	ResourceSaver.save(save_game_data, SAVE_PATH)

func load_data() -> void :
	if not ResourceLoader.exists(SAVE_PATH) : 
		save_game_data = SaveGameData.new()
		save_data()
		print("PersistenceManager: No save file found. Initialized with default SaveGameData.")
	save_game_data = ResourceLoader.load(SAVE_PATH)

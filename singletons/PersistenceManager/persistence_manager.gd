extends Node

signal save_data_reset

var save_game_data : SaveGameData

const SAVE_PATH : String = "user://save.tres"

func _ready() -> void:
	load_data()

func load_new_save_data() -> void:
	save_game_data.reset_state()
	if save_data() != Error.OK:
		print("PersistenceManager: Error saving data.")
	save_data_reset.emit()

func save_data() -> Error :
	return ResourceSaver.save(save_game_data, SAVE_PATH)

func load_data() -> void :
	if not ResourceLoader.exists(SAVE_PATH) : 
		save_game_data = SaveGameData.new()
		save_data()
		print("PersistenceManager: No save file found. Initialized with default SaveGameData.")
	save_game_data = ResourceLoader.load(SAVE_PATH)

func is_base_game_save() -> bool:
	var _base_game_save = SaveGameData.new()
	for property in  _base_game_save.get_property_list():
		if property["name"] == "resource_path":
			continue
		if _base_game_save.get(property["name"]) != save_game_data.get(property["name"]):
			return false
	
	return true

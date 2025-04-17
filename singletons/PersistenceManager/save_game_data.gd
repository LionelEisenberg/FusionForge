class_name SaveGameData
extends Resource

@export var money : int = 3

@export var fusion_cores: int = 0

@export var discovered_fusions: Dictionary = {} 

@export var purchased_upgrades: Dictionary = {}

func _to_string() -> String:
	return "SaveGameData(Money: %d, Cores: %d, Discoveries: %s, Purchased Upgrades: %s)" % \
			[money, fusion_cores, str(discovered_fusions.keys()), str(purchased_upgrades)]

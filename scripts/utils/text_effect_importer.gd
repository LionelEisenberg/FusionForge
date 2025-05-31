extends Node

@export var _text_effect_scripts: Array[Script]

func _ready():
	pass

func get_text_effect_instances() -> Array[RichTextEffect]:
	var _rich_text_effects : Array[RichTextEffect] = []
	
	for script in _text_effect_scripts:
		var instance = script.new()
		_rich_text_effects.append(instance)
		
	return _rich_text_effects

# MyHoverButton.gd
extends Button # Or whatever your button's root node type is

@onready var rich_text_label: RichTextLabel = $RichTextLabel # Path to your RichTextLabel child
@export var button_text: String = "START RUN"

## Assign the RichTextEffect script (e.g., WaveTextEffect.gd) to use for hover.
@export var hover_effect_script: Script = null
@export var hover_effect_parameters: Dictionary = {}

var _active_hover_effect_instance: RichTextEffect = null
var _active_hover_bbcode_tag: String = ""

func _ready() -> void:
	# Load and instance your custom RichTextEffect script
	if hover_effect_script:
		_active_hover_effect_instance = hover_effect_script.new()
		rich_text_label.custom_effects = [_active_hover_effect_instance]

		if _active_hover_effect_instance.has_method("_get_bbcode"):
			_active_hover_bbcode_tag = _active_hover_effect_instance.call("_get_bbcode")
			if _active_hover_bbcode_tag.is_empty():
				push_warning("MyHoverButton: Hover effect script's _get_bbcode() returned an empty tag.")
				_active_hover_effect_instance = null # Invalidate if tag is bad
		else:
			push_error("MyHoverButton: Assigned hover_effect_script does not implement _get_bbcode().")
			_active_hover_effect_instance = null # Invalidate
	else:
		push_error("Failed to load WaveTextEffect script!")
		return
	
	# Set initial text without the wave effect
	rich_text_label.bbcode_enabled = true # Ensure BBCode is enabled on the RichTextLabel
	rich_text_label.text = button_text
	
	if disabled:
		rich_text_label.text = "[color=gray]%s[/color]" % rich_text_label.text 
	
	# Connect hover signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if disabled or not is_instance_valid(rich_text_label) or not is_instance_valid(_active_hover_effect_instance) or _active_hover_bbcode_tag.is_empty():
		return # No effect to apply or label missing

	var params_string: String = ""
	if not hover_effect_parameters.is_empty():
		for key in hover_effect_parameters:
			var value = hover_effect_parameters[key]
			# Basic string conversion. More complex values might need specific formatting.
			# Ensure keys are valid BBCode parameter names (usually lowercase, no spaces).
			params_string += " %s=%s" % [key, str(value)] # Add leading space

	rich_text_label.bbcode_text = "[%s%s]%s[/%s]" % [_active_hover_bbcode_tag, params_string, button_text, _active_hover_bbcode_tag]

func _on_mouse_exited() -> void:
	if disabled or not is_instance_valid(rich_text_label): return
	# Remove the hover effect by setting plain text (or text without the specific hover tag)
	rich_text_label.text = button_text

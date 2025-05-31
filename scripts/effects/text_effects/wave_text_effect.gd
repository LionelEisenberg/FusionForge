# WaveTextEffect.gd
@tool # Allows effect to preview in the editor if BBCode is used there
extends RichTextEffect

# This is the BBCode tag name for your effect
var bbcode = "waving" # Will be returned by _get_bbcode()

# Exportable properties (uniforms) for customization via BBCode or directly
@export var wave_amplitude: float = 3.0  # How high/low characters bounce (pixels)
@export var wave_frequency: float = 0.5 # Spatial frequency (how many waves across text)
@export var wave_speed: float = 10.0     # Temporal speed (how fast the wave animates)
@export var wave_color: Color = Color.DARK_TURQUOISE

# This method tells RichTextLabel what BBCode tag this effect corresponds to.
func _get_bbcode() -> String:
	return bbcode

# This method is called by RichTextLabel for each character within your BBCode tag.
# char_fx: A CharFXTransform object that holds the state of the current character (glyph).
# You modify char_fx.transform, char_fx.offset, char_fx.color, char_fx.visible.
func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# Get parameters from the BBCode tag environment (e.g., [wave amp=5 freq=0.3 speed=6])
	# or use the default @export values if not provided in the tag.
	var amp = char_fx.env.get("amp", wave_amplitude)
	var freq = char_fx.env.get("freq", wave_frequency)
	var speed = char_fx.env.get("speed", wave_speed)
	var color = char_fx.env.get("color", wave_color)

	# elapsed_time is the time since the effect was applied to this specific character or text block
	var time = char_fx.elapsed_time
	# relative_index is the index of the character within the [wave]...[/wave] block
	var index = float(char_fx.relative_index)

	var y_offset = sin(index * freq - time * speed) * amp 
	
	char_fx.offset.y = y_offset
	char_fx.color = color
	
	return true # Return true to indicate that char_fx was modified and needs an update.

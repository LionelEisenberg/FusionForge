extends ColorRect

@onready var animation_player: AnimationPlayer = $AnimationPlayer # Assuming child is named AnimationPlayer

func _ready() -> void:
	size = get_viewport_rect().size
	global_position = Vector2.ZERO # Ensure it's at the top-left for screen shader

	if not material is ShaderMaterial:
		push_error("FusionShockwaveVFX: ShaderMaterial not assigned to ColorRect!")
		queue_free()
		return

	# Initialize screen_size uniform once
	material.set_shader_parameter("screen_size", size)

# Call this from VFXManager after instancing
func init_and_play(epicenter_world_pos: Vector2, _intensity_factor: float = 1.0) -> void:
	if not material is ShaderMaterial:
		push_warning("FusionShockwaveVFX: Cannot play, ShaderMaterial missing.")
		queue_free()
		return

	if not is_instance_valid(animation_player):
		push_warning("FusionShockwaveVFX: AnimationPlayer not found.")
		queue_free()
		return

	# The shader takes 'global_position' which it then normalizes using screen_size.
	# If this ColorRect is at (0,0) and covers the screen, epicenter_world_pos can be used directly.
	material.set_shader_parameter("global_position", epicenter_world_pos)

	animation_player.play("play_shockwave")
	
	await animation_player.animation_finished # Wait for the animation to complete
	
	queue_free() # Self-destruct

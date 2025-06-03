extends Node

var _fusion_shockwave_shader_scene: PackedScene = preload("res://scenes/effects/vfx/fusion_shockwave_vfx.tscn")
var _element_collision_spark_scene: PackedScene = preload("res://scenes/effects/vfx/element_collision_spark_vfx.tscn")

func _ready() -> void:
	if CollisionManager:
		CollisionManager.fusion_event_vfx_requested.connect(_on_fusion_vfx_requested)
		CollisionManager.element_element_vfx_requested.connect(_on_element_element_vfx_requested)
	else:
		push_warning("VFXManager: Unable to connect to CollisionManager.")
	

# Ensure this matches the signal from CollisionManager (position and intensity_factor)
func _on_fusion_vfx_requested(position: Vector2, intensity_factor: float = 1.0) -> void:
	if not is_instance_valid(_fusion_shockwave_shader_scene): # Use the new shader scene
		push_warning("VFXManager: FusionShockwaveVFX scene is not loaded. Cannot play fusion VFX.")
		return

	var vfx_instance := _fusion_shockwave_shader_scene.instantiate() as ColorRect # Cast to root type
	
	if not is_instance_valid(vfx_instance):
		push_error("VFXManager: Failed to instance FusionShockwaveVFX scene.")
		return

	get_tree().current_scene.add_child(vfx_instance) # Fallback

	if vfx_instance.has_method("init_and_play"):
		vfx_instance.call("init_and_play", position, intensity_factor)
	else:
		push_warning("VFXManager: FusionShockwaveVFX instance does not have 'init_and_play' method.")
		vfx_instance.queue_free() # Clean up if it can't be played

func _on_element_element_vfx_requested(position: Vector2, intensity_factor: float = 1.0) -> void:
	if not is_instance_valid(_element_collision_spark_scene):
		push_warning("VFXManager: ElementCollisionSparkVFX scene not loaded.")
		return

	var vfx_instance := _element_collision_spark_scene.instantiate() as Node2D
	if not is_instance_valid(vfx_instance):
		push_error("VFXManager: Failed to instance ElementCollisionSparkVFX scene.")
		return

	# Add to a suitable parent, e.g., current scene or a dedicated VFX layer
	get_tree().current_scene.add_child(vfx_instance)
	vfx_instance.global_position = position

	if vfx_instance.has_method("init_effect"):
		vfx_instance.call("init_effect", intensity_factor)
	if vfx_instance.has_method("play"):
		vfx_instance.call("play")

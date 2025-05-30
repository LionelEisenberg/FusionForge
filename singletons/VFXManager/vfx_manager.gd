# VFXManager.gd
# Autoload singleton responsible for instancing and managing visual effects.
extends Node

var _fusion_halo_wave_scene: PackedScene =  preload("res://scenes/vfx/fusion_shockwave_vfx.tscn")

func _ready() -> void:
	# Connect to signals from other managers
	if CollisionManager:
		CollisionManager.fusion_event_vfx_requested.connect(_on_fusion_event_vfx_requested)
	else:
		push_warning("VFXManager: CollisionManager not found. Cannot connect VFX signals.")


# --- Signal Handlers ---

# Called when CollisionManager emits the fusion_vfx_requested signal.
# Ensure CollisionManager emits both position and intensity_factor.
func _on_fusion_event_vfx_requested(position: Vector2, intensity_factor: float = 1.0) -> void:
	if not is_instance_valid(_fusion_halo_wave_scene):
		push_warning("VFXManager: FusionHaloWaveVFX scene is not loaded. Cannot play fusion VFX.")
		return

	var vfx_instance: Node2D = _fusion_halo_wave_scene.instantiate() as Node2D
	
	if not is_instance_valid(vfx_instance):
		push_error("VFXManager: Failed to instance FusionHaloWaveVFX scene.")
		return

	# Add the VFX instance to the current scene tree.
	# Adding it as a child of the VFXManager itself is one option,
	# or you can add it to the main game scene or a dedicated VFX layer.
	# For simplicity, let's add to the current scene's root or the VFXManager itself.
	# get_tree().current_scene.add_child(vfx_instance) # Option 1: Add to current scene root
	add_child(vfx_instance) # Option 2: Add as child of VFXManager (ensure VFXManager is in the tree appropriately)

	vfx_instance.global_position = position
	vfx_instance.position = position

	# Call methods on the VFX instance's script (assuming it has them)
	if vfx_instance.has_method("init_effect"):
		vfx_instance.call("init_effect", intensity_factor)
	else:
		push_warning("VFXManager: FusionHaloWaveVFX instance does not have 'init_effect' method.")
		
	if vfx_instance.has_method("play"):
		vfx_instance.call("play")
	else:
		push_warning("VFXManager: FusionHaloWaveVFX instance does not have 'play' method.")

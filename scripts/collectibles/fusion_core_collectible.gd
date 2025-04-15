class_name FusionCoreCollectible
extends Collectible

@export var core_amount : int = 1

## This function defines WHAT happens when the collectible is picked up.
func apply_pickup_effect() -> void:
	if GameManager:
		GameManager.award_fusion_core(core_amount)

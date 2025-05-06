class_name EnergyCollectible
extends Collectible

@export var energy_amount : int = 10

## This function defines WHAT happens when the collectible is picked up.
func apply_pickup_effect() -> void:
	if RunManager: # Ensure RunManager (autoload) exists
		RunManager.register_energy_collected_from_pickup(energy_amount)

	if GameManager:
		GameManager.add_energy(energy_amount)

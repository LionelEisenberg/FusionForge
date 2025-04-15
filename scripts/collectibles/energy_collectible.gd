class_name EnergyCollectible
extends Collectible

@export var energy_amount : int = 10

## This function defines WHAT happens when the collectible is picked up.
func apply_pickup_effect() -> void:
	print(energy_amount)	
	if GameManager:
		GameManager.add_energy(energy_amount)

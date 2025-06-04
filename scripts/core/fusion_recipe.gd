# scripts/core/FusionRecipe.gd
class_name FusionRecipe
extends Resource

## Type name of the first reactant (matches Element.element_type).
@export var reactant_1_type: String = ""
## Type name of the second reactant.
@export var reactant_2_type: String = ""

## Type name of the resulting element (must match an Element type).
@export var result_type: String = ""
## Mass of the resulting element in AMU (used by CollisionManager/ElementSpawner).
@export var result_mass: float = 0.0
## Base energy released by this specific fusion reaction (in abstract units).
@export var energy_yield: float = 100.0
## Minimum combined momentum energy the two reactants need to fuse.
@export var min_momentum: float = 50.0
## Chance (from 0.0 to 1.0) that this specific recipe will spawn a Fusion Core.
@export var fusion_core_spawn_chance: float = 0.0 
## Number of Fusion Cores to spawn if the chance is successful.
@export var fusion_core_yield: int = 1
## How much this fusion recipe contributes to increasing the fusion combo meter.
@export var combo_increase_value: int = 1

## Helper function to check if two element types match this recipe's reactants,
## regardless of order. Returns true if they match, false otherwise.
func reactants_match(type1: String, type2: String) -> bool:
	# Check both A+B and B+A combinations
	return (reactant_1_type == type1 and reactant_2_type == type2) or \
		   (reactant_1_type == type2 and reactant_2_type == type1)

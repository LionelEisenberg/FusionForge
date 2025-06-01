# scripts/core/UpgradeEffects.gd
# Resource holding the CUMULATIVE effects of all currently purchased upgrades.
# An instance of this is created and emitted by UpgradeManager via the 'upgrades_applied' signal.
# Other managers listen for this signal and use the data in this resource to modify their behavior.
class_name UpgradeEffects
extends Resource

# --- Additive Effects (Start from base value, then add these) ---
@export var max_energy_add: float = 0.0
@export var max_stability_add: float = 0.0
@export var base_wall_collision_energy_add: float = 0.0
@export var base_element_collision_energy_add: float = 0.0
@export var max_elements_add: int = 0
@export var initial_speed_add: float = 0.0
@export var base_accel_magnitude_add: float = 0.0
@export var base_money_per_collision_add: float = 0.0
@export var combo_decay_time_add: float = 0.0
@export var max_combo_cap_add: float = 0.0 # Changed to float
@export var spawn_timer_wait_time_remove: float = 0.0 # Negative value speeds up spawn
@export var spawn_chance_deuterium: float = 0.0
@export var spawn_chance_helium3: float = 0.0

# --- Multiplicative Effects (Start from base value, then multiply by these) ---
# Default to 1.0, values are multiplied together (e.g., 1.1 * 1.1 for two levels of +10%)
@export var momentum_energy_factor_mult: float = 1.0
@export var base_stability_damage_mult: float = 1.0 # Value < 1.0 reduces damage
@export var momentum_stability_factor_mult: float = 1.0 # Value < 1.0 reduces scaling
@export var wall_collision_slowing_factor_mult: float = 1.0 # Value < 1.0 reduces slowdown
@export var force_to_energy_conversion_factor_mult: float = 1.0 # Value < 1.0 improves efficiency
@export var collectible_lifespan_mult: float = 1.0 
@export var collection_radius_mult: float = 1.0

# --- Unlocks ---
# List of unlocked fusion recipe resource FILENAMES (e.g., ["H_H_He.tres", "He_He_Be.tres"])
# CollisionManager will need to load recipes based on this list.
@export var unlocked_fusion_recipes: Array[String] = []

# Optional: Override _to_string for debugging
func _to_string() -> String:
	# Basic implementation, could be more detailed
	return "UpgradeEffects(MaxEnergyAdd: %.1f, MaxStabAdd: %.1f, Unlocks: %s, ...)" % \
			[max_energy_add, max_stability_add, str(unlocked_fusion_recipes)]

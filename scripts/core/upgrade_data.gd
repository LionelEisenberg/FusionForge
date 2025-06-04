# scripts/core/UpgradeData.gd
# Resource defining the static data for a single upgrade type.
# Create .tres files using this script for each upgrade in the game.
class_name UpgradeData
extends Resource

## Core Upgrade Information
@export var id: String = "" # Unique identifier (e.g., "increase_spawn_rate_1"). Used for tracking purchases and prerequisites. MUST BE UNIQUE.
@export var display_name: String = "Unnamed Upgrade" # Name shown to the player in the UI.
@export_multiline var description: String = "" # Description shown to the player in the UI.
@export var max_purchase_level: int = 1 # Maximum number of times this upgrade can be purchased. 1 means it's a one-time purchase.
@export var prerequisites: Array[String] = [] # Array of 'id' strings of upgrades that must be purchased (level 1+) before this one is available.
@export var sprite_svg: Image = null
@export var effect_string: String = "10%"

@export_category("Cost")
@export_group("Money Costs")
@export var money_cost_per_level: Array[float] = []
@export_group("Fusion Core Costs")
@export var fusion_core_cost_per_level: Array[float] = []

@export_category("Upgrade Effects")
## Requirements

## Upgrade Effects (Per Level)
# Set the relevant variables below for the specific effect(s) this upgrade provides PER LEVEL.
# Default values (0 for additive, 1.0 for multiplicative, "" for unlocks) mean the effect is inactive.
# UpgradeManager applies the effect * purchased_level.

## --- Collision Effects ---
@export_group("Collision Effects")
@export var base_wall_collision_energy_add: float = 0.0 # Affects CollisionManager.base_wall_collision_energy
@export var base_element_collision_energy_add: float = 0.0 # Affects CollisionManager.base_element_collision_energy
@export var momentum_energy_factor_mult: float = 1.0 # Affects CollisionManager.momentum_energy_factor (Multiplicative)
@export var base_stability_damage_mult: float = 1.0 # Affects CollisionManager.base_stability_damage (Multiplicative)
@export var momentum_stability_factor_mult: float = 1.0 # Affects CollisionManager.momentum_stability_factor (Multiplicative)
@export var wall_collision_slowing_factor_remove: float = 0.0

## --- Reactor Effects ---
@export_group("Reactor Effects")
@export var spawn_timer_wait_time_remove: float = 0.0 # Affects ElementSpawner._spawn_timer.wait_time (Negative value speeds up)
@export var max_elements_add: int = 0 # Affects GameManager.max_element_capacity
@export var initial_speed_add: float = 0.0 # Affects ElementSpawner.initial_speed
@export var base_accel_magnitude_mult: float = 0.0 # Affects GameManager.base_acceleration_magnitude
@export var force_to_energy_conversion_factor_mult: float = 1.0 # Affects GameManager.force_to_energy_factor (Multiplicative, < 1.0 = more efficient)
@export var spawn_chance_deuterium_add: float = 0.0
@export var spawn_chance_helium3_add: float = 0.0

## --- Fusion Effects ---
@export_group("Fusion Effects")
# Adds the specified FusionRecipe resource filename (e.g., "H_H_He.tres") to the list of available recipes in CollisionManager.
@export var fusion_recipe_to_unlock: String = ""
# TODO: Add effects for min_kinetic_energy reduction, fusion energy yield increase?

## --- Collectible Effects ---
@export_group("Collectible Effects")
@export var collection_radius_mult: float = 1.0 # Affects Collectible.gd attraction Area2D size
@export var collectible_lifespan_mult: float = 1.0 # Affects Collectible.lifespan (Multiplicative)

## --- Game State Effects ---
@export_group("Game State Effects")
@export var max_stability_add: float = 0.0 # Affects GameManager.max_stability
@export var max_energy_add: float = 0.0 # Affects GameManager.max_energy

## --- Run Stats & Money Effects ---
@export_group("Run Stats & Money Effects")
# Affects base value used in GameManager's end-of-run money calculation
@export var base_money_per_collision_add: float = 0.0 # TODO: Needs integration in GameManager calc
# Affects RunManager.combo_decay_time
@export var combo_decay_time_add: float = 0.0
# Affects RunManager.max_combo_cap
@export var max_combo_cap_add: float = 0.0 # Changed to float

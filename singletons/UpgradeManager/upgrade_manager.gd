# scripts/managers/UpgradeManager.gd
# Autoload Singleton responsible for managing game upgrades.
# Loads upgrade data, handles purchase logic, calculates cumulative effects,
# and emits a signal (`upgrades_applied`) with the calculated effects data (UpgradeEffects resource).
extends Node

#-----------------------------------------------------------------------------
# Signals
#-----------------------------------------------------------------------------
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal upgrades_applied(effects_data: UpgradeEffects)

#-----------------------------------------------------------------------------
# Constants
#-----------------------------------------------------------------------------
const UPGRADE_RESOURCE_DIR := "res://resources/upgrades/" # Example path, adjust as needed

#-----------------------------------------------------------------------------
# State Variables
#-----------------------------------------------------------------------------
var _all_upgrades: Dictionary[String, UpgradeData] = {}
var _live_save_data: SaveGameData = null
var _cached_upgrade_effects: UpgradeEffects = UpgradeEffects.new()

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------
func _ready() -> void:
	# Ensure required GameManager singleton exists.
	if not GameManager:
		printerr("UpgradeManager CRITICAL ERROR: Requires GameManager singleton!")
		return

	if PersistenceManager:
		_live_save_data = PersistenceManager.save_game_data
	else:
		printerr("UpgradeManager CRITICAL ERROR: Could not get SaveGameData from PersistenceManager!")
		return # Cannot proceed without SaveGameData.

	if _live_save_data.purchased_upgrades == null or typeof(_live_save_data.purchased_upgrades) != TYPE_DICTIONARY:
		_live_save_data.purchased_upgrades = {}
		printerr("UpgradeManager CRITICAL ERROR: Could not get PurchasedUpgrades field in SaveGameData!")


	_load_all_upgrade_resources()
	calculate_and_emit_effects()

#-----------------------------------------------------------------------------
# Core Public Functions (Purchase & Querying)
#-----------------------------------------------------------------------------

## Attempts to purchase the next level of the specified upgrade.
func purchase_upgrade(upgrade_id: String) -> bool:
	if not _all_upgrades.has(upgrade_id):
		printerr("Attempted to purchase unknown upgrade ID: ", upgrade_id)
		return false

	if not can_purchase(upgrade_id):
		return false

	var data: UpgradeData = _all_upgrades[upgrade_id]
	var current_level: int = get_purchased_level(upgrade_id)
	var cost: float = get_upgrade_cost(upgrade_id)

	if not GameManager.spend_money(cost):
		printerr("Purchase failed: Could not spend money (%.2f) for upgrade '%s'" % [cost, upgrade_id])
		return false

	var new_level = current_level + 1
	_live_save_data.purchased_upgrades[upgrade_id] = new_level

	calculate_and_emit_effects()

	upgrade_purchased.emit(upgrade_id, new_level)

	return true

## Checks if the next level of an upgrade can currently be purchased.
func can_purchase(upgrade_id: String) -> bool:
	if not _all_upgrades.has(upgrade_id): return false # Unknown upgrade

	var data: UpgradeData = _all_upgrades[upgrade_id]
	var current_level: int = get_purchased_level(upgrade_id)

	# Check max level
	if current_level >= data.max_purchase_level: return false

	# Check prerequisites
	if not _are_prerequisites_met(upgrade_id): return false

	# Check cost TODO: Implement Fusion Core Costs logic
	var cost: float = get_upgrade_cost(upgrade_id)
	if cost < 0: return false # Invalid cost (already max level)

	if not GameManager.can_spend_money(cost): return false

	return true

## Calculates the cost for purchasing the *next* available level of the upgrade.
# TODO: Implement Fusion Core Costs logic
func get_upgrade_cost(upgrade_id: String) -> float:
	if not _all_upgrades.has(upgrade_id): return -1.0

	var data: UpgradeData = _all_upgrades[upgrade_id]
	var current_level: int = get_purchased_level(upgrade_id)

	if current_level >= data.max_purchase_level: return -1.0 # Max level reached

	var next_level_index = current_level
	var cost = data.money_cost * pow(data.money_cost_scaling_factor, next_level_index)
	return cost

## Gets the currently purchased level for a given upgrade ID.
func get_purchased_level(upgrade_id: String) -> int:
	if _live_save_data and _live_save_data.purchased_upgrades:
		return _live_save_data.purchased_upgrades.get(upgrade_id, 0) # Return 0 if key not found
	return 0 # Return 0 if save data invalid

## Retrieves the loaded UpgradeData resource object for a given ID.
func get_upgrade_data(upgrade_id: String) -> UpgradeData:
	return _all_upgrades.get(upgrade_id, null) # Use .get() for safe access

## Returns an array containing all loaded UpgradeData resources.
func get_all_upgrade_data() -> Array[UpgradeData]:
	return _all_upgrades.values()

## Returns the cached upgrade effects
func get_upgrade_effects() -> UpgradeEffects:
	return _cached_upgrade_effects

#-----------------------------------------------------------------------------
# Effect Calculation and Emission Function
#-----------------------------------------------------------------------------

## Recalculates the cumulative effects of ALL purchased upgrades and emits them.
func calculate_and_emit_effects() -> void:
	var effects_data := UpgradeEffects.new()

	# Iterate through purchased upgrades {id: level} dictionary
	for upgrade_id in _live_save_data.purchased_upgrades:
		var level: int = _live_save_data.purchased_upgrades[upgrade_id]
		if level <= 0: continue
		
		var data: UpgradeData = get_upgrade_data(upgrade_id)
		if data == null:
			printerr("Calculate Effects: Could not find UpgradeData for purchased ID: ", upgrade_id)
			continue

		# --- Accumulate Additive Effects ---
		# Multiply effect per level by the number of levels purchased
		effects_data.max_energy_add += data.max_energy_add * level
		effects_data.max_stability_add += data.max_stability_add * level
		effects_data.base_wall_collision_energy_add += data.base_wall_collision_energy_add * level
		effects_data.base_element_collision_energy_add += data.base_element_collision_energy_add * level
		effects_data.max_elements_add += data.max_elements_add * level
		effects_data.initial_speed_add += data.initial_speed_add * level
		effects_data.base_accel_magnitude_add += data.base_accel_magnitude_add * level
		effects_data.collection_radius_add += data.collection_radius_add * level
		effects_data.base_money_per_collision_add += data.base_money_per_collision_add * level
		effects_data.combo_decay_time_add += data.combo_decay_time_add * level
		effects_data.max_combo_cap_add += data.max_combo_cap_add * level
		effects_data.spawn_timer_wait_time_add += data.spawn_timer_wait_time_add * level

		# --- Accumulate Multiplicative Effects ---
		# Apply multiplier for each level purchased (base * mult^level)
		effects_data.momentum_energy_factor_mult *= pow(data.momentum_energy_factor_mult, level)
		effects_data.base_stability_damage_mult *= pow(data.base_stability_damage_mult, level)
		effects_data.momentum_stability_factor_mult *= pow(data.momentum_stability_factor_mult, level)
		effects_data.wall_collision_slowing_factor_mult *= pow(data.wall_collision_slowing_factor_mult, level)
		effects_data.force_to_energy_conversion_factor_mult *= pow(data.force_to_energy_conversion_factor_mult, level)
		effects_data.collectible_lifespan_mult *= pow(data.collectible_lifespan_mult, level)

		# --- Handle Unlocks ---
		# Add recipe filename if level >= 1 and not already present
		if level >= 1 and not data.fusion_recipe_to_unlock.is_empty():
			if not effects_data.unlocked_fusion_recipes.has(data.fusion_recipe_to_unlock):
				effects_data.unlocked_fusion_recipes.append(data.fusion_recipe_to_unlock)

	upgrades_applied.emit(effects_data)
	_cached_upgrade_effects = effects_data


#-----------------------------------------------------------------------------
# Private Helper Functions
#-----------------------------------------------------------------------------

## Loads all UpgradeData resource (.tres) files from the UPGRADE_RESOURCE_DIR.
func _load_all_upgrade_resources() -> void:
	_all_upgrades.clear()
	var dir = DirAccess.open(UPGRADE_RESOURCE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var file_path = UPGRADE_RESOURCE_DIR.path_join(file_name)
				var upgrade_res = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
				if upgrade_res is UpgradeData:
					if upgrade_res.id.is_empty():
						printerr("Upgrade resource file has empty ID: ", file_path)
					elif _all_upgrades.has(upgrade_res.id):
						printerr("Duplicate upgrade ID found: '%s' in file %s" % [upgrade_res.id, file_path])
					else:
						_all_upgrades[upgrade_res.id] = upgrade_res
				else:
					printerr("Resource file is not of type UpgradeData: ", file_path)
			file_name = dir.get_next()
	else:
		printerr("Could not open upgrade resource directory: ", UPGRADE_RESOURCE_DIR)


## Checks if all prerequisite upgrades for a given upgrade ID have been met.
func _are_prerequisites_met(upgrade_id: String) -> bool:
	var data: UpgradeData = get_upgrade_data(upgrade_id)
	if data == null or data.prerequisites.is_empty(): return true # No data or no prereqs

	for prereq_id in data.prerequisites:
		if get_purchased_level(prereq_id) < 1: # Check if prereq is purchased at least once
			return false
	return true # All prerequisites met

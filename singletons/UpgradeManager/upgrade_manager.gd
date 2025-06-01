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
const UPGRADE_LIST_PATH := "res://resources/upgrades/upgrade_list.tres"

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
		PersistenceManager.save_data_reset.connect(calculate_and_emit_effects)
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

	var current_level: int = get_current_upgrade_level(upgrade_id)
	var costs: Vector2i = get_upgrade_costs(upgrade_id)
	var money_cost: int = costs.x
	var fusion_core_cost: int = costs.y
	
	if not GameManager.spend_money(money_cost):
		printerr("Purchase failed: Could not spend money (%.2f) for upgrade '%s'" % [int(money_cost), upgrade_id])
		return false
	if not GameManager.spend_fusion_cores(fusion_core_cost):
		printerr("Purchase failed: Could not spend fusion cores (%.2f) for upgrade '%s'" % [int(fusion_core_cost), upgrade_id])
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
	var current_level: int = get_current_upgrade_level(upgrade_id)

	# Check max level
	if current_level >= data.max_purchase_level: return false

	# Check prerequisites
	if not _are_all_prerequisites_met(upgrade_id): return false

	# Check cost TODO: Implement Fusion Core Costs logic
	var costs: Vector2i = get_upgrade_costs(upgrade_id)
	var money_cost: int = costs.x
	var fusion_core_cost: int = costs.y
	if money_cost < 0: return false # Invalid cost (already max level)
	if fusion_core_cost < 0: return false # Invalid cost (already max level)

	if not GameManager.can_spend_money(money_cost): return false
	if not GameManager.can_spend_fusion_cores(fusion_core_cost): return false

	return true

## Calculates the cost for purchasing the *next* available level of the upgrade.
# returns a Vector2i(money_cost, fusion_core_cost)
# returns (-1, -1) if an error takes place
func get_upgrade_costs(upgrade_id: String) -> Vector2i:
	if not _all_upgrades.has(upgrade_id): return Vector2i(-1, -1)

	var data: UpgradeData = _all_upgrades[upgrade_id]
	var current_level: int = get_current_upgrade_level(upgrade_id)

	if current_level >= data.max_purchase_level: return Vector2i(-1, -1) # Max level reached
	if data.max_purchase_level != len(data.money_cost_per_level) or data.max_purchase_level != len(data.fusion_core_cost_per_level):
		push_warning("UpgradeManager: Poorly Formatted Data: %s" % upgrade_id)
		return Vector2i(-1, -1)

	var next_level_index = current_level
	var cost = Vector2i(data.money_cost_per_level[next_level_index], data.fusion_core_cost_per_level[next_level_index])
	return cost

## Gets the currently purchased level for a given upgrade ID.
func get_current_upgrade_level(upgrade_id: String) -> int:
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
		effects_data.base_money_per_collision_add += data.base_money_per_collision_add * level
		effects_data.combo_decay_time_add += data.combo_decay_time_add * level
		effects_data.max_combo_cap_add += data.max_combo_cap_add * level
		effects_data.spawn_timer_wait_time_remove += data.spawn_timer_wait_time_remove * level
		effects_data.spawn_chance_deuterium += data.spawn_chance_deuterium_add * level
		effects_data.spawn_chance_helium3 += data.spawn_chance_helium3_add * level

		# --- Accumulate Multiplicative Effects ---
		# Apply multiplier for each level purchased (base * mult^level)
		effects_data.momentum_energy_factor_mult *= pow(data.momentum_energy_factor_mult, level)
		effects_data.base_stability_damage_mult *= pow(data.base_stability_damage_mult, level)
		effects_data.momentum_stability_factor_mult *= pow(data.momentum_stability_factor_mult, level)
		effects_data.wall_collision_slowing_factor_mult *= pow(data.wall_collision_slowing_factor_mult, level)
		effects_data.force_to_energy_conversion_factor_mult *= pow(data.force_to_energy_conversion_factor_mult, level)
		effects_data.collectible_lifespan_mult *= pow(data.collectible_lifespan_mult, level)
		effects_data.collection_radius_mult *= pow(data.collection_radius_mult, level)

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

func _load_all_upgrade_resources() -> void:
	_all_upgrades.clear()

	if not ResourceLoader.exists(UPGRADE_LIST_PATH):
		printerr("UpgradeManager: Upgrade list resource not found at: ", UPGRADE_LIST_PATH)
		return

	var upgrade_list = ResourceLoader.load(UPGRADE_LIST_PATH)
	if upgrade_list is UpgradeList:
		for upgrade_data_instance in upgrade_list.upgrades:
			if upgrade_data_instance is UpgradeData: # Double check type
				if upgrade_data_instance.id.is_empty():
					printerr("Upgrade resource (from list) has empty ID: ", upgrade_data_instance.resource_path)
				elif _all_upgrades.has(upgrade_data_instance.id):
					printerr("Duplicate upgrade ID found: '%s' from list." % upgrade_data_instance.id)
				else:
					_all_upgrades[upgrade_data_instance.id] = upgrade_data_instance
			else:
				printerr("Item in upgrade list is not of type UpgradeData: ", upgrade_data_instance)
	else:
		printerr("Failed to load UpgradeListResource or it's the wrong type from: ", UPGRADE_LIST_PATH)

	if _all_upgrades.is_empty():
		printerr("UpgradeManager: No upgrade data loaded from UpgradeListResource!")


## Checks if all prerequisite upgrades for a given upgrade ID have been met.
func _are_all_prerequisites_met(upgrade_id: String) -> bool:
	var data: UpgradeData = get_upgrade_data(upgrade_id)
	if data == null or data.prerequisites.is_empty(): return true # No data or no prereqs

	for prereq_id in data.prerequisites:
		if get_current_upgrade_level(prereq_id) < 1: # Check if prereq is purchased at least once
			return false
	return true # All prerequisites met

func _at_least_one_prerequisite_met(upgrade_id: String) -> bool:
	var data: UpgradeData = get_upgrade_data(upgrade_id)
	if data == null or data.prerequisites.is_empty(): return true # No data or no prereqs

	for prereq_id in data.prerequisites:
		if get_current_upgrade_level(prereq_id) >= 1: # Check if prereq is purchased at least once
			return true
	return false

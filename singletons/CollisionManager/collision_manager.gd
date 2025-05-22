extends Node

#-----------------------------------------------------------------------------
# Signals Emitted
#-----------------------------------------------------------------------------
signal stability_decreased(amount: float) # To GameManager
signal fusion_core_awarded() # To GameManager

signal wall_collision_processed() # To RunManager
signal element_collision_processed() # To RunManager
signal fusion_processed(element_a: Element, element_b: Element, result_element_data: Dictionary) # To RunManager
signal element_collision_data_calculated(element_a: Element, element_b: Element, combined_momentum: float) # To RunManager

signal request_element_spawn(element_type: String, position: Vector2, velocity: Vector2) # To ElementSpawner/Reactor
signal request_element_destroy(element: Element) # To Reactor/RunScene

signal spawn_energy_collectible(position: Vector2, value: float) # To CollectibleSpawner
signal spawn_fusion_core_collectible(position: Vector2, value: float) # To CollectibleSpawner

#-----------------------------------------------------------------------------
# Constant Variables
#-----------------------------------------------------------------------------
# Base values before upgrades are applied.
const BASE_COLLISION_ENERGY: float = 5.0
const BASE_WALL_COLLISION_ENERGY: float = 2.0
const BASE_STABILITY_DAMAGE: float = 1.0
const BASE_MOMENTUM_ENERGY_FACTOR: float = 0.025
const BASE_MOMENTUM_STABILITY_FACTOR: float = 0.005
const BASE_WALL_COLLISION_SLOWING_FACTOR: float = 1.5 # Note: Value > 1 slows more

const FUSION_RECIPE_LIST_PATH: String = "res://resources/recipes/fusion_recipe_list.tres"

#-----------------------------------------------------------------------------
# State Variables (Upgradeable)
#-----------------------------------------------------------------------------
# Current values used during gameplay, potentially modified by upgrades.
var base_collision_energy: float = BASE_COLLISION_ENERGY
var base_wall_collision_energy: float = BASE_WALL_COLLISION_ENERGY
var base_stability_damage: float = BASE_STABILITY_DAMAGE
var momentum_energy_factor: float = BASE_MOMENTUM_ENERGY_FACTOR
var momentum_stability_factor: float = BASE_MOMENTUM_STABILITY_FACTOR
var wall_collision_slowing_factor: float = BASE_WALL_COLLISION_SLOWING_FACTOR

#-----------------------------------------------------------------------------
# Other Variables
#-----------------------------------------------------------------------------
# Path to the folder containing FusionRecipe .tres files (Not typically upgraded)
@export var recipe_folder_path: String = "res://resources/recipes/"

var fusion_recipes: Array[FusionRecipe] = [] # Currently available recipes based on unlocks
var unlocked_fusion_recipes: Array[String] = [] # List of unlocked recipe FILENAMES from UpgradeManager
var _live_save_data: SaveGameData = null
var _all_loaded_recipes: Array[FusionRecipe] = [] # Cache all loaded recipes once


#-----------------------------------------------------------------------------
# Initialization
#-----------------------------------------------------------------------------
func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		_live_save_data = PersistenceManager.save_game_data
	else:
		printerr("CollisionManager: Cannot get SaveGameData from PersistenceManager!")
		_live_save_data = SaveGameData.new() # Use default if needed

	# --- Load fusion recipes from directory ---
	_load_fusion_recipes()
	
	if UpgradeManager:
		UpgradeManager.upgrades_applied.connect(_on_upgrades_applied)
	else:
		printerr("CollisionManager: WARNING - Could not connect to UpgradeManager! Using default values.")


#-----------------------------------------------------------------------------
# Signal Handlers (Connected by ElementSpawner)
#-----------------------------------------------------------------------------

## Handles collision between two elements.
func _on_element_pair_collided(element_a: Element, element_b: Element) -> void:
	# Ensure both instances are still valid before processing
	if not is_instance_valid(element_a) or not is_instance_valid(element_b):
		return

	var combined_momentum = element_a.get_momentum() + element_b.get_momentum()
	element_collision_data_calculated.emit(element_a, element_b, combined_momentum)

	var recipe: FusionRecipe = _check_fusion_conditions(element_a, element_b, combined_momentum)

	if recipe:
		_handle_fusion(element_a, element_b, recipe)
	else:
		_handle_element_collision(element_a, element_b)

## Handles collision between an element and a wall.
func _on_element_hit_wall(element: Element) -> void:
	if not is_instance_valid(element):
		return

	# Calculate energy yield (base + bonus for momentum)
	var energy = base_wall_collision_energy + (element.get_momentum() * momentum_energy_factor)
	spawn_energy_collectible.emit(element.global_position, energy)

	# Calculate stability damage (base + bonus for momentum)
	var damage = base_stability_damage + (element.get_momentum() * momentum_stability_factor)
	stability_decreased.emit(damage)
	
	# Dampen element velocity when hitting walls
	element.linear_velocity = element.linear_velocity / wall_collision_slowing_factor

	# Notify RunManager
	wall_collision_processed.emit()

	# TODO: Incorporate active click bonus check here?


#-----------------------------------------------------------------------------
# Upgrade Handling
#-----------------------------------------------------------------------------

## Signal handler connected to UpgradeManager.upgrades_applied.
func _on_upgrades_applied(effects_data: UpgradeEffects) -> void:
	# Apply additive effects
	base_collision_energy = BASE_COLLISION_ENERGY + effects_data.base_element_collision_energy_add
	base_wall_collision_energy = BASE_WALL_COLLISION_ENERGY + effects_data.base_wall_collision_energy_add

	# Apply multiplicative effects
	momentum_energy_factor = BASE_MOMENTUM_ENERGY_FACTOR * effects_data.momentum_energy_factor_mult
	base_stability_damage = BASE_STABILITY_DAMAGE * effects_data.base_stability_damage_mult # Lower multiplier = less damage
	momentum_stability_factor = BASE_MOMENTUM_STABILITY_FACTOR * effects_data.momentum_stability_factor_mult # Lower multiplier = less scaling
	wall_collision_slowing_factor = BASE_WALL_COLLISION_SLOWING_FACTOR * effects_data.wall_collision_slowing_factor_mult # Lower multiplier = less slowdown

	# Clamp / Validate values
	base_collision_energy = max(0.0, base_collision_energy)
	base_wall_collision_energy = max(0.0, base_wall_collision_energy)
	momentum_energy_factor = max(0.0, momentum_energy_factor)
	base_stability_damage = max(0.0, base_stability_damage)
	momentum_stability_factor = max(0.0, momentum_stability_factor)
	wall_collision_slowing_factor = max(1.0, wall_collision_slowing_factor) # Ensure slowing factor is at least 1 (no speed up)

	unlocked_fusion_recipes = effects_data.unlocked_fusion_recipes
	_filter_available_recipes()

#-----------------------------------------------------------------------------
# Internal Helper Functions
#-----------------------------------------------------------------------------

## Checks if conditions for fusion are met for two elements. Returns recipe if true, null otherwise.
func _check_fusion_conditions(e1: Element, e2: Element, combined_momentum: float) -> FusionRecipe:
	_filter_available_recipes()
	for recipe in fusion_recipes:
		if recipe.reactants_match(e1.element_type, e2.element_type):
			if combined_momentum >= recipe.min_momentum:
				return recipe

	return null


## Handles the outcome of a successful fusion.
func _handle_fusion(e1: Element, e2: Element, recipe: FusionRecipe) -> void:
	if recipe.energy_yield > 0:
		spawn_energy_collectible.emit(_find_collision_position(e1, e2), recipe.energy_yield)

	# Check if this fusion product is newly discovered (using SaveGameData)
	if _live_save_data and not _live_save_data.discovered_fusions.has(recipe.result_type):
		_live_save_data.discovered_fusions[recipe.result_type] = true
		spawn_fusion_core_collectible.emit(_find_collision_position(e1, e2), 1)
		PersistenceManager.save_data()

	# Notify RunManager about the fusion event
	var result_data = { "type": recipe.result_type, "mass": recipe.result_mass }
	fusion_processed.emit(e1, e2, result_data)

	# --- Trigger Spawning/Destruction ---
	var collision_pos = _find_collision_position(e1, e2)
	var result_velocity = Vector2.ONE # Placeholder - simple stop

	request_element_spawn.emit(recipe.result_type, collision_pos, result_velocity)
	request_element_destroy.emit(e1)
	request_element_destroy.emit(e2)

	# TODO: Incorporate active click bonus check here?

## Handles the outcome of a non-fusion element-element collision.
func _handle_element_collision(e1: Element, e2: Element) -> void:
	var relative_velocity: float = (e1.linear_velocity - e2.linear_velocity).length()
	var effective_momentum: float = (e1.mass + e2.mass) * 0.5 * relative_velocity
	
	var energy = base_collision_energy + (effective_momentum * momentum_energy_factor)
	spawn_energy_collectible.emit(_find_collision_position(e1, e2), energy)

	# Notify RunManager
	element_collision_processed.emit()

	# TODO: Incorporate active click bonus check here?


func _load_fusion_recipes() -> void:
	_all_loaded_recipes.clear()
	
	if not ResourceLoader.exists(FUSION_RECIPE_LIST_PATH):
		printerr("CollisionManager: Fusion Recipe list resource not found at: ", FUSION_RECIPE_LIST_PATH)
		return
		
	var recipe_list = ResourceLoader.load(FUSION_RECIPE_LIST_PATH)
	if recipe_list is FusionRecipeList:
		for recipe in recipe_list.fusion_recipes:
			if recipe is FusionRecipe:
				_all_loaded_recipes.append(recipe)
			else:
				printerr("Item in fusion recipe list is not of type FusionRecipe: ", recipe)
	else:
		printerr("Failed to load FusionRecipeList or it's the wrong type from: ", FUSION_RECIPE_LIST_PATH)

	if _all_loaded_recipes.is_empty():
		printerr("UpgradeManager: No upgrade data loaded from UpgradeListResource!")

## Filters the loaded recipes based on the currently unlocked recipe list.
func _filter_available_recipes() -> void:
	fusion_recipes.clear() # Clear the list used for checks
	
	for recipe in _all_loaded_recipes:
		var recipe_filename = recipe.resource_path.get_file().get_basename()
		if unlocked_fusion_recipes.has(recipe_filename):
			fusion_recipes.append(recipe)

func _find_collision_position(e1 : Element, e2 : Element) -> Vector2:
	return (e1.global_position + e2.global_position) / 2

extends Node

#-----------------------------------------------------------------------------
# Signals Emitted
#-----------------------------------------------------------------------------
signal stability_decreased(amount: float) # To GameManager
signal fusion_core_awarded() # To GameManager

signal wall_collision_processed() # To RunManager
signal element_collision_processed() # To RunManager
signal fusion_processed(element_a: Element, element_b: Element, result_element_data: Dictionary) # To RunManager

signal request_element_spawn(element_type: String, position: Vector2, velocity: Vector2) # To ElementSpawner/Reactor
signal request_element_destroy(element: Element) # To Reactor/RunScene

signal spawn_energy_collectible(position: Vector2, value: float) # To CollectibleSpawner
signal spawn_fusion_core_collectible(position: Vector2, value: float) # To CollectibleSpawner

#-----------------------------------------------------------------------------
# Exports
#-----------------------------------------------------------------------------
# Base values for calculations
@export var base_collision_energy: float = 5.0
@export var base_wall_collision_energy: float = 2.0
@export var base_stability_damage: float = 1.0

# Factors modifying yields based on physics state
@export var momentum_energy_factor: float = 0.05 # Energy yield from collision scales slightly with momentum
@export var momentum_stability_factor: float = 0.005 # Stability damage from collision scales slightly with momentum

# Factors modifying speed after collision
@export var wall_collision_slowing_factor: float = 1.0

# Path to the folder containing FusionRecipe .tres files
@export var recipe_folder_path: String = "res://resources/recipes/"

#-----------------------------------------------------------------------------
# Variables
#-----------------------------------------------------------------------------
var fusion_recipes: Array[FusionRecipe] = []
var _live_save_data: SaveGameData = null

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


#-----------------------------------------------------------------------------
# Signal Handlers (Connected by ElementSpawner)
#-----------------------------------------------------------------------------

## Handles collision between two elements.
func _on_element_pair_collided(element_a: Element, element_b: Element) -> void:
	# Ensure both instances are still valid before processing
	if not is_instance_valid(element_a) or not is_instance_valid(element_b):
		return

	var recipe: FusionRecipe = _check_fusion_conditions(element_a, element_b)

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
# Internal Helper Functions
#-----------------------------------------------------------------------------

## Checks if conditions for fusion are met for two elements. Returns recipe if true, null otherwise.
func _check_fusion_conditions(e1: Element, e2: Element) -> FusionRecipe:
	var combined_momentum = e1.get_momentum() + e2.get_momentum()

	for recipe in fusion_recipes:
		if recipe.reactants_match(e1.element_type, e2.element_type):
			if combined_momentum >= recipe.min_momentum:
				return recipe

	return null


## Handles the outcome of a successful fusion.
func _handle_fusion(e1: Element, e2: Element, recipe: FusionRecipe) -> void:
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
	fusion_recipes.clear()
	var dir = DirAccess.open(recipe_folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				pass 
			elif file_name.ends_with(".tres"): # Load only .tres files
				var file_path = recipe_folder_path.path_join(file_name)
				var loaded_resource = ResourceLoader.load(file_path)
				if loaded_resource is FusionRecipe:
					fusion_recipes.append(loaded_resource)
				else:
					printerr("CollisionManager: File is not a FusionRecipe: ", file_path)

			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		printerr("CollisionManager: Could not open recipe directory: ", recipe_folder_path)


#-----------------------------------------------------------------------------
# Helper Functions
#-----------------------------------------------------------------------------

# TODO: Move these to a common library? 

func _find_collision_position(e1 : Element, e2 : Element) -> Vector2:
	return (e1.global_position + e2.global_position) / 2

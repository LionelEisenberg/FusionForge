extends Node

#-----------------------------------------------------------------------------
# Signals Emitted
#-----------------------------------------------------------------------------
signal energy_yielded(amount: float) # To GameManager
signal stability_decreased(amount: float) # To GameManager
signal fusion_core_awarded() # To GameManager
signal wall_collision_processed() # To RunManager
signal element_collision_processed() # To RunManager
signal fusion_processed(element_a: Element, element_b: Element, result_element_data: Dictionary) # To RunManager
signal request_element_spawn(element_type: String, position: Vector2, velocity: Vector2) # To ElementSpawner/Reactor
signal request_element_destroy(element: Element) # To Reactor/RunScene
#signal spawn_energy_collectible(position: Vector2, value: float) # TODO: Future enhancement

#-----------------------------------------------------------------------------
# Exports
#-----------------------------------------------------------------------------
# Base values for calculations
@export var base_collision_energy: float = 5.0
@export var base_wall_collision_energy: float = 2.0
@export var base_stability_damage: float = 1.0

# Factors modifying yields based on physics state
@export var speed_energy_factor: float = 0.01 # Energy scales slightly with speed
@export var mass_stability_factor: float = 0.2 # Stability damage scales slightly with mass

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

	# Note: Connections from Element signals (pair_collided, hit_wall) to the
	# _on_... handlers below must be made by ElementSpawner when elements are created.


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

	# Calculate energy yield (base + bonus for speed)
	var speed = element.linear_velocity.length()
	var energy = base_wall_collision_energy + (speed * speed_energy_factor)
	energy_yielded.emit(energy)

	# Calculate stability damage (base + bonus for mass)
	var damage = base_stability_damage + (element.element_mass_amu * mass_stability_factor)
	stability_decreased.emit(damage)

	# Notify RunManager
	wall_collision_processed.emit()

	# TODO: Incorporate active click bonus check here?


#-----------------------------------------------------------------------------
# Internal Helper Functions
#-----------------------------------------------------------------------------

## Checks if conditions for fusion are met for two elements. Returns recipe if true, null otherwise.
func _check_fusion_conditions(e1: Element, e2: Element) -> FusionRecipe:
	# Calculate combined kinetic energy (0.5 * m * v^2)
	var ke1 = 0.5 * e1.mass * e1.linear_velocity.length_squared()
	var ke2 = 0.5 * e2.mass * e2.linear_velocity.length_squared()
	var combined_ke = ke1 + ke2
	
	print(e1.mass, e1.linear_velocity.length_squared(), e2.mass, e2.linear_velocity.length_squared())

	for recipe in fusion_recipes:
		if recipe.reactants_match(e1.element_type, e2.element_type):
			if combined_ke >= recipe.min_kinetic_energy:
				return recipe

	return null


## Handles the outcome of a successful fusion.
func _handle_fusion(e1: Element, e2: Element, recipe: FusionRecipe) -> void:
	energy_yielded.emit(recipe.energy_yield)

	# Check if this fusion product is newly discovered (using SaveGameData)
	if _live_save_data and not _live_save_data.discovered_fusions.has(recipe.result_type):
		_live_save_data.discovered_fusions[recipe.result_type] = true
		fusion_core_awarded.emit()
		PersistenceManager.save_data()

	# Notify RunManager about the fusion event
	var result_data = { "type": recipe.result_type, "mass": recipe.result_mass }
	fusion_processed.emit(e1, e2, result_data)

	# --- Trigger Spawning/Destruction ---
	# TODO: Calculate accurate position (e.g., midpoint) and resulting velocity (conserve momentum?)
	var collision_pos = (e1.global_position + e2.global_position) / 2.0
	var result_velocity = Vector2.ONE # Placeholder - simple stop

	request_element_spawn.emit(recipe.result_type, collision_pos, result_velocity)
	request_element_destroy.emit(e1)
	request_element_destroy.emit(e2)

	# TODO: Incorporate active click bonus check here?


## Handles the outcome of a non-fusion element-element collision.
func _handle_element_collision(e1: Element, e2: Element) -> void:
	# Calculate energy yield (base + bonus for relative speed?)
	var relative_velocity = (e1.linear_velocity - e2.linear_velocity).length()
	var energy = base_collision_energy + (relative_velocity * speed_energy_factor)
	energy_yielded.emit(energy)

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
					print("CollisionManager: Loaded recipe: ", file_path)
				else:
					printerr("CollisionManager: File is not a FusionRecipe: ", file_path)

			file_name = dir.get_next()
		dir.list_dir_end()
		print("CollisionManager: Loaded %d fusion recipes." % fusion_recipes.size())
	else:
		printerr("CollisionManager: Could not open recipe directory: ", recipe_folder_path)

# scripts/reactor/element_spawner.gd
# Responsible for spawning different element types into the reactor at a defined rate.
extends Node2D

#-----------------------------------------------------------------------------
# Constant Variables
#-----------------------------------------------------------------------------
# Base values before upgrades are applied.
const BASE_INITIAL_SPEED: float = 100.0
# Default timer wait time (5.0s in the scene file) corresponds to 0.2 spawns/sec
const BASE_SPAWN_WAIT_TIME: float = 5.0
const BASE_MAX_ELEMENT_CAPACITY: int = 10 # Base capacity

#-----------------------------------------------------------------------------
# State Variables (Upgradeable)
#-----------------------------------------------------------------------------
# Current values used during gameplay, potentially modified by upgrades.
# Initialized by apply_upgrade_effects() called from _ready().
var initial_speed: float = BASE_INITIAL_SPEED
var spawn_wait_time: float = BASE_SPAWN_WAIT_TIME
var max_element_capacity: int = BASE_MAX_ELEMENT_CAPACITY

#-----------------------------------------------------------------------------
# Exports
#-----------------------------------------------------------------------------

## Dictionary mapping element type names (String) to their PackedScene files.
@export var element_scenes: Dictionary = {
	"Hydrogen": preload("res://scenes/elements/hydrogen.tscn"),
	"Helium": preload("res://scenes/elements/helium.tscn")
}

## The node where spawned elements should be added as children.
@export var element_container: Node = null

## Assign the instanced ReactorWalls node here in the Inspector.
@export var reactor_walls: StaticBody2D = null

## Padding inside the boundary shape to avoid spawning exactly on the wall.
@export var spawn_padding: float = 20.0

#-----------------------------------------------------------------------------
# Node References
#-----------------------------------------------------------------------------

# Requires a child Timer node named "SpawnTimer"
@onready var _spawn_timer: Timer = $SpawnTimer

#-----------------------------------------------------------------------------
# Internal Variables
#-----------------------------------------------------------------------------

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _is_spawning: bool = false
var _spawn_rect: Rect2 # Calculated spawn area based on boundary shape

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------

func _ready() -> void:
	_rng.randomize() # Initialize random number generator
	
	# --- Validate Exports ---
	if reactor_walls == null:
		printerr("ElementSpawner: Reactor Walls node not assigned in Inspector!")
	if element_container == null:
		printerr("ElementSpawner: Element Container node not assigned in Inspector!")
	if _spawn_timer == null:
		printerr("ElementSpawner: Child node 'SpawnTimer' of type Timer is required!")
		return # Cannot proceed without timer
	
	if CollisionManager:
		CollisionManager.request_element_spawn.connect(_spawn_element)

	if UpgradeManager:
		var initial_effects = UpgradeManager.get_upgrade_effects()
		if initial_effects:
			apply_upgrade_effects(initial_effects)
		else:
			printerr("ElementSpawner: Failed to get initial effects from UpgradeManager cache.")
	else:
		printerr("ElementSpawner: UpgradeManager not found during _ready().")
		
	# Calculate the spawn area based on the boundary shape
	_calculate_spawn_rect()

	# Connect the timer's timeout signal
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)

#-----------------------------------------------------------------------------
# Upgrade Handling
#-----------------------------------------------------------------------------

## Called by _ready() to apply effects data to this node's parameters.
func apply_upgrade_effects(effects_data: UpgradeEffects) -> void:
	initial_speed = BASE_INITIAL_SPEED + effects_data.initial_speed_add
	spawn_wait_time = BASE_SPAWN_WAIT_TIME - effects_data.spawn_timer_wait_time_remove
	print(spawn_wait_time)
	max_element_capacity = BASE_MAX_ELEMENT_CAPACITY + effects_data.max_elements_add

	# Clamp / Validate values
	initial_speed = max(0.0, initial_speed)
	spawn_wait_time = max(0.05, spawn_wait_time) # Ensure wait time is positive and reasonably small
	max_element_capacity = max(1, max_element_capacity) # Ensure at least 1 element can spawn
	
	if _spawn_timer:
		_spawn_timer.wait_time = spawn_wait_time

#-----------------------------------------------------------------------------
# Public Control Functions (Called by RunScene/ReactorChamber)
#-----------------------------------------------------------------------------

## Starts the spawning process.
func start_spawning() -> void:
	if _spawn_timer == null: return

	print("ElementSpawner: Starting spawning...")
	_is_spawning = true

	update_spawn_rate(spawn_wait_time)
	_spawn_timer.start()
	_on_spawn_timer_timeout() # Spawn an element at the beginning

## Stops the spawning process.
func stop_spawning() -> void:
	if _spawn_timer == null: return

	print("ElementSpawner: Stopping spawning...")
	_is_spawning = false
	_spawn_timer.stop()

## Updates the spawn timer based on a new rate (elements per second).
func update_spawn_rate(new_rate_per_sec: float) -> void:
	if _spawn_timer == null: return

	if new_rate_per_sec > 0:
		_spawn_timer.wait_time = new_rate_per_sec
	else:
		# If rate is zero or negative, stop the timer
		_spawn_timer.wait_time = 9999 # Effectively stops it until rate increases
		if _is_spawning:
			_spawn_timer.stop() # Ensure it's stopped if rate becomes non-positive


#-----------------------------------------------------------------------------
# Internal Logic & Signal Handlers
#-----------------------------------------------------------------------------

## Called when the SpawnTimer times out. Handles spawning a single element.
func _on_spawn_timer_timeout() -> void:
	if not _is_spawning or element_container == null:
		return

	# --- Check Element Capacity ---
	var current_element_count: int = 0
	
	for child in element_container.get_children():
		if child.is_in_group("elements"):
			current_element_count += 1

	if current_element_count >= max_element_capacity:
		print("ElementSpawner: Max capacity reached, skipping spawn.")
		return

	_spawn_element()

## Calculates the valid spawn area based on the reactor boundary.
func _calculate_spawn_rect() -> void:
	if reactor_walls == null:
		printerr("ElementSpawner: Cannot calculate spawn rect - Reactor Walls Node not assigned.")
		return
	
	var collision_polygon = reactor_walls.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	
	if collision_polygon and collision_polygon.polygon.size() > 2: # Need at least 3 points for an area
		# Get the bounding box of the polygon points in the polygon's local coordinates
		var local_bounds := Rect2(collision_polygon.polygon[0], Vector2.ZERO)
		for i in range(1, collision_polygon.polygon.size()):
			local_bounds = local_bounds.expand(collision_polygon.polygon[i])

		# Transform this local bounding box to global coordinates
		var global_bounds: Rect2 = collision_polygon.get_global_transform() * local_bounds

		# Inflate slightly inwards using the padding
		_spawn_rect = global_bounds.grow(-spawn_padding)

		if _spawn_rect.size.x <= 0 or _spawn_rect.size.y <= 0:
			printerr("ElementSpawner: Spawn padding (", spawn_padding, ") is too large for the calculated reactor boundary! ", global_bounds)
			_spawn_rect = global_bounds # Fallback to exact global bounds
	else:
		if not collision_polygon:
			printerr("ElementSpawner: Cannot calculate spawn rect - Child 'CollisionPolygon2D' not found in ReactorWalls node.")
		else: # Polygon has too few points
			printerr("ElementSpawner: Cannot calculate spawn rect - boundary polygon node has too few points.")
		# Fallback to a default rect around the spawner's global position? Or disable spawning?
		_spawn_rect = Rect2(global_position - Vector2(100, 100), Vector2(200, 200)) # Example fallback


## Gets a random position within the calculated spawn rectangle.
func _get_random_spawn_position() -> Vector2:
	if _spawn_rect.size.x <= 0 or _spawn_rect.size.y <= 0:
		return global_position # Fallback to spawner's own position if rect is invalid

	var random_x: float = _rng.randf_range(_spawn_rect.position.x, _spawn_rect.end.x)
	var random_y: float = _rng.randf_range(_spawn_rect.position.y, _spawn_rect.end.y)
	return Vector2(random_x, random_y)

func _spawn_element(element_type_to_spawn : String = "", spawn_position : Vector2 = _get_random_spawn_position(), spawn_velocity : Vector2 = Vector2.from_angle(_rng.randf_range(0, TAU)) * initial_speed) -> void:	
	# --- Select Element Type ---
	# TODO: Implement weighted random selection based on unlocked elements/probabilities
	#       Get this data from UpgradeManager/RunManager/GameManager.
	# For MVP, always spawn the first element type available (e.g., Hydrogen)
	if element_scenes.is_empty():
		printerr("ElementSpawner: No element scenes defined in element_scenes dictionary!")
		return
	if element_type_to_spawn == "":
		element_type_to_spawn = element_scenes.keys()[0] # Just spawn the first one for now

	var packed_element_scene = element_scenes.get(element_type_to_spawn) as PackedScene
	if packed_element_scene == null:
		printerr("ElementSpawner: PackedScene not found for type: ", element_type_to_spawn)
		return

	# --- Instantiate ---
	var new_element = packed_element_scene.instantiate() as Element # Cast to Element type
	if new_element == null:
		printerr("ElementSpawner: Failed to instantiate or cast element scene for type: ", element_type_to_spawn)
		return

	# --- Initialize & Add ---
	element_container.call_deferred("add_child", new_element) # Add before initialize? Or after? Usually add first.
	new_element.initialize(spawn_position, spawn_velocity)

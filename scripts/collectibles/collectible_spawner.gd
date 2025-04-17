class_name CollectibleSpawner
extends Node

#-----------------------------------------------------------------------------
# Exports
#-----------------------------------------------------------------------------
@export var energy_collectible_scene: PackedScene
@export var fusion_core_collectible_scene: PackedScene

@export var collectible_container: Node = null

## Maximum random offset distance from the original collision point.
@export var spawn_position_offset: float = 15.0

#-----------------------------------------------------------------------------
# Tier Definitions
#-----------------------------------------------------------------------------

const ENERGY_VALUE_TIERS = [250.0, 100.0, 50.0, 10.0, 1.0] # Highest to lowest

#-----------------------------------------------------------------------------
# Internal Variables
#-----------------------------------------------------------------------------
var _rng := RandomNumberGenerator.new()

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------
func _ready() -> void:
	_rng.randomize()
	# Validate exports
	if collectible_container == null: printerr("CollectibleSpawner: Collectible Container node not assigned!")
	if energy_collectible_scene == null: printerr("CollectibleSpawner: Energy Collectible Scene not assigned!")
	if fusion_core_collectible_scene == null: printerr("CollectibleSpawner: Fusion Core Collectible Scene not assigned!")

	if CollisionManager:
		CollisionManager.spawn_energy_collectible.connect(_on_spawn_energy_value)
		CollisionManager.spawn_fusion_core_collectible.connect(_on_spawn_fusion_core)
	else:
		printerr("CollectibleSpawner: CollisionManager not found!")


#-----------------------------------------------------------------------------
# Signal Handlers
#-----------------------------------------------------------------------------

## Handles spawning energy collectibles based on total value.
func _on_spawn_energy_value(spawn_pos: Vector2, total_value: float) -> void:
	if energy_collectible_scene == null or collectible_container == null: return
	if total_value <= 0: return # Don't spawn if no energy yielded

	var remaining_value = total_value
	
	print("Requested to spawn Energy, for an amount of %.02f" % total_value)

	# Greedy algorithm: Spawn highest tier possible first
	for tier_value in ENERGY_VALUE_TIERS:
		if remaining_value < tier_value:
			continue # Move to next smaller tier

		var num_to_spawn = floori(remaining_value / tier_value)
		for i in range(num_to_spawn):
			_spawn_single_collectible(energy_collectible_scene, spawn_pos, tier_value)

		remaining_value = fmod(remaining_value, tier_value)

## Handles spawning fusion core collectibles.
func _on_spawn_fusion_core(spawn_pos: Vector2, count: int) -> void:
	if fusion_core_collectible_scene == null or collectible_container == null: return
	if count <= 0: return

	for i in range(count):
		_spawn_single_collectible(fusion_core_collectible_scene, spawn_pos, 1)


#-----------------------------------------------------------------------------
# Internal Spawning Logic
#-----------------------------------------------------------------------------

## Instantiates and sets up a single collectible instance.
func _spawn_single_collectible(scene: PackedScene, base_pos: Vector2, value) -> void:
	var instance = scene.instantiate()
	if not instance is Collectible:
		printerr("CollectibleSpawner: Instantiated scene is not a Collectible type!")
		if instance: instance.queue_free()
		return

	var collectible = instance as Collectible
	collectible_container.call_deferred("add_child", collectible)

	# Calculate spawn position with slight random offset
	var offset = Vector2(_rng.randf_range(-spawn_position_offset, spawn_position_offset),
						 _rng.randf_range(-spawn_position_offset, spawn_position_offset))
	collectible.global_position = base_pos + offset

	# Set specific value based on type (requires type checking)
	if collectible is EnergyCollectible:
		collectible.energy_amount = value as float
	elif collectible is FusionCoreCollectible:
		collectible.core_amount = value as int

	# Calculate random initial direction
	var direction = Vector2.from_angle(_rng.randf_range(0, TAU))
	if value == 10:
		collectible.modulate = Color(Color.RED, 1.0)
	collectible.initialize(direction) # Call base setup for movement/lifespan

extends Node2D

#-----------------------------------------------------------------------------
# Constant Variables
#-----------------------------------------------------------------------------
# Base values for upgradeable parameters *before* upgrades are applied.
const BASE_ACCELERATION_MAGNITUDE: float = 20.0
const BASE_FORCE_TO_ENERGY_CONVERSION_FACTOR: float = 0.5

#-----------------------------------------------------------------------------
# Export Variables
#-----------------------------------------------------------------------------

@export var max_shake_offset: float = 12.0  # Max pixels the chamber can offset during a strong shake
@export var base_shake_duration: float = 0.2 # Base duration of a shake in seconds
@export var max_shake_duration_bonus: float = 0.3 # Max additional duration for strongest shake
@export var shake_jiggles: int = 8 # Number of "jiggles" (back and forth movements) in one shake

#-----------------------------------------------------------------------------
# State Variables
#-----------------------------------------------------------------------------
# Current values used during gameplay, potentially modified by upgrades.
var acceleration_magnitude: float = BASE_ACCELERATION_MAGNITUDE
var force_to_energy_conversion_factor: float = BASE_FORCE_TO_ENERGY_CONVERSION_FACTOR

# VFX Variables
var _original_position: Vector2
var _current_shake_tween: Tween

# Last calculated energy cost
var _latest_energy_cost_per_second: float = 0.0

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------

func _ready() -> void:
	_original_position = global_position
	
	if CollisionManager:
		CollisionManager.element_wall_vfx_requested.connect(trigger_shake)
	else:
		push_warning("ReactorChamber: CollisionManager not found. Cannot connect reactor_shake_requested signal.")
	
	if UpgradeManager:
		var initial_effects = UpgradeManager.get_upgrade_effects()
		if initial_effects:
			apply_upgrade_effects(initial_effects)
		else:
			printerr("ReactorChamber: Failed to get initial effects from UpgradeManager cache.")
	else:
		printerr("ReactorChamber: UpgradeManager not found during _ready().")

# Note: Connection to UpgradeManager.upgrades_applied happens externally
# (e.g., in Run.gd) after this node is instantiated.
func _physics_process(delta: float) -> void:
	var total_force_applied_magnitude: float = 0.0
	for element_node in get_tree().get_nodes_in_group("elements"):
		if not element_node is Element or not is_instance_valid(element_node):
			continue

		var element := element_node as Element

		# Calculate force using the reactor's current acceleration magnitude
		var force_to_apply : Vector2 = calculate_acceleration_force(element)
		element.apply_central_force(force_to_apply)

		total_force_applied_magnitude += force_to_apply.length()

	if GameManager and total_force_applied_magnitude > 0:
		var energy_cost = total_force_applied_magnitude * force_to_energy_conversion_factor * delta
		var energy_cost_per_second = snappedf(energy_cost * (1 / delta), 0.01)
		if _latest_energy_cost_per_second != energy_cost_per_second:
			_latest_energy_cost_per_second = energy_cost_per_second
			if RunManager:
				RunManager.energy_cost_per_second_calculated.emit(_latest_energy_cost_per_second)
		GameManager.spend_energy(energy_cost)

func _exit_tree() -> void:
	# Clean up tween if the node is removed from the scene
	if is_instance_valid(_current_shake_tween):
		_current_shake_tween.kill()

#-----------------------------------------------------------------------------
# VFX Handling
#-----------------------------------------------------------------------------

# Public method to initiate a shake
func trigger_shake(intensity: float) -> void:
	# If a shake is already in progress, you might choose to:
	# 1. Ignore the new shake (current implementation if tween is valid)
	# 2. Kill the old tween and start a new one (can feel more responsive)
	# 3. Add to the intensity/duration of the current shake (more complex)

	if is_instance_valid(_current_shake_tween) and _current_shake_tween.is_running():
		_current_shake_tween.kill()
		global_position = _original_position # Reset position before starting new shake

	_current_shake_tween = create_tween()
	_current_shake_tween.set_parallel(false) # Run shake steps sequentially

	# --- Calculate shake parameters based on intensity ---
	var normalized_intensity: float = clampf(intensity / 2000.0, 0.0, 1.0) # Example normalization

	var shake_magnitude: float = max_shake_offset * normalized_intensity
	var shake_duration_total: float = base_shake_duration + (max_shake_duration_bonus * normalized_intensity)
	var duration_per_jiggle: float = shake_duration_total / float(shake_jiggles + 1)

	# Perform a series of jiggles
	for i in range(shake_jiggles):
		var random_offset_x = randf_range(-shake_magnitude, shake_magnitude)
		var random_offset_y = randf_range(-shake_magnitude, shake_magnitude)
		var target_pos = _original_position + Vector2(random_offset_x, random_offset_y)
		
		_current_shake_tween.tween_property(self, "global_position", target_pos, duration_per_jiggle)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Finally, tween back to the original position
	_current_shake_tween.tween_property(self, "global_position", _original_position, duration_per_jiggle)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT) # Elastic for a nice settle

	_current_shake_tween.play()

#-----------------------------------------------------------------------------
# Upgrade Handling
#-----------------------------------------------------------------------------

func apply_upgrade_effects(effects_data: UpgradeEffects) -> void:
	# Apply additive effects
	acceleration_magnitude = BASE_ACCELERATION_MAGNITUDE + effects_data.base_accel_magnitude_add

	# Apply multiplicative effects
	force_to_energy_conversion_factor = BASE_FORCE_TO_ENERGY_CONVERSION_FACTOR * effects_data.force_to_energy_conversion_factor_mult

	# Clamp or validate values if needed
	force_to_energy_conversion_factor = max(0.0, force_to_energy_conversion_factor)
	acceleration_magnitude = max(0.0, acceleration_magnitude) # Prevent negative acceleration

#-----------------------------------------------------------------------------
# Internal Helper Functions
#-----------------------------------------------------------------------------

## Calculates the acceleration force vector for a given element.
## Uses the reactor's current acceleration_magnitude.
func calculate_acceleration_force(e: Element) -> Vector2:
	var current_accel_magnitude: float = acceleration_magnitude

	var current_direction: Vector2 = Vector2.ZERO
	if e.linear_velocity.length_squared() > Element.ZERO_VELOCITY_THRESHOLD_SQ: # Access constant via class
		current_direction = e.linear_velocity.normalized()

	return current_direction * current_accel_magnitude * e.mass

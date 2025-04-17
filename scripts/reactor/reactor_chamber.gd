extends Node2D

#-----------------------------------------------------------------------------
# Constant Variables
#-----------------------------------------------------------------------------
# Base values for upgradeable parameters *before* upgrades are applied.
const BASE_ACCELERATION_MAGNITUDE: float = 25.0
const BASE_FORCE_TO_ENERGY_CONVERSION_FACTOR: float = 0.5

#-----------------------------------------------------------------------------
# State Variables
#-----------------------------------------------------------------------------
# Current values used during gameplay, potentially modified by upgrades.
var acceleration_magnitude: float = BASE_ACCELERATION_MAGNITUDE
var force_to_energy_conversion_factor: float = BASE_FORCE_TO_ENERGY_CONVERSION_FACTOR

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------

func _ready() -> void:
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
		var energy_cost = total_force_applied_magnitude * force_to_energy_conversion_factor * delta # Scale cost by delta
		GameManager.spend_energy(energy_cost)

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

	return current_direction * current_accel_magnitude

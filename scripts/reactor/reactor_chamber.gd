extends Node2D

func _physics_process(delta: float) -> void:
	var total_force_applied_magnitude: float = 0.0

	# Get acceleration parameters from GameManager (assuming these properties exist)
	var accel_factor = 1.0
	var base_accel_magnitude = 25.0
	var force_to_energy_conversion_factor = 0.5
	if GameManager:
		accel_factor = GameManager.acceleration_factor
		base_accel_magnitude = GameManager.acceleration_magnitude
		force_to_energy_conversion_factor = GameManager.force_to_energy_conversion_factor
	else:
		printerr("ReactorChamber: GameManager not found for acceleration params!")

	for element_node in get_tree().get_nodes_in_group("elements"):
		if not element_node is Element: continue
		if not is_instance_valid(element_node): continue

		var element := element_node as Element

		var force_to_apply : Vector2 = calculate_acceleration_force(element, accel_factor, base_accel_magnitude)

		element.apply_central_force(force_to_apply)

		total_force_applied_magnitude += force_to_apply.length()

	# Deduct energy once per frame based on total force applied
	if GameManager and total_force_applied_magnitude > 0:
		var energy_cost = total_force_applied_magnitude * force_to_energy_conversion_factor * delta # Scale cost by delta
		GameManager.spend_energy(energy_cost)


## Calculates the acceleration force vector for a given element
func calculate_acceleration_force(e: Element, factor: float, magnitude: float) -> Vector2:
	# Use factor and magnitude passed in (fetched from GameManager)
	var acceleration_force_magnitude: float = magnitude * factor

	# Calculate Direction based on Current Velocity
	var current_direction: Vector2 = Vector2.ZERO
	# Check if velocity is significant enough to have a direction
	if e.linear_velocity.length_squared() > Element.ZERO_VELOCITY_THRESHOLD_SQ: # Access constant via class
		current_direction = e.linear_velocity.normalized()

	return current_direction * acceleration_force_magnitude

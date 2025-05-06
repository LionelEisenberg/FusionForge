class_name RunStats
extends Resource

## Collision counts. x: Wall hits, y: Element hits
@export var collision_counts: Vector2i = Vector2i.ZERO
## The highest combo multiplier reached during the run.
@export var max_fusion_combo: float = 1.0
## Total duration of the run in seconds.
@export var run_time: float = 0.0
## Highest Collision Momentum for a given Run
@export var highest_combined_collision_momentum: float = 0.0
## Total energy collected by the player from energy collectibles during the run.
@export var total_energy_collected_from_pickups: float = 0.0


#-----------------------------------------------------------------------------
# Helper methods for calculations (used by GameManager or potentially UI)
#-----------------------------------------------------------------------------

## Returns the total number of collisions (wall + element).
func get_total_collisions() -> int:
	return collision_counts.x + collision_counts.y

#-----------------------------------------------------------------------------
# Debugging
#-----------------------------------------------------------------------------

func _to_string() -> String:
	var wall_collisions_str: String = "  Wall Collisions: %d" % collision_counts.x
	var element_collisions_str: String = "  Element Collisions: %d" % collision_counts.y
	var run_time_str: String = "  Run Time: %.1fs" % run_time
	var max_combo_str: String = "  Max Fusion Combo: x%.1f" % max_fusion_combo
	var highest_momentum_str: String = "  Highest Combined Collision Momentum: %.2f" % highest_combined_collision_momentum
	var energy_collected_str: String = "  Energy Collected (Pickups): %.2f eV" % total_energy_collected_from_pickups

	# Join all parts with newline characters
	return "RunStats:\n%s\n%s\n%s\n%s\n%s\n%s" % [
		run_time_str,
		wall_collisions_str,
		element_collisions_str,
		max_combo_str,
		highest_momentum_str,
		energy_collected_str
	]

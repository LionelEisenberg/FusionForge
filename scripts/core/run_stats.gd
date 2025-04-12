class_name RunStats
extends Resource

## Collision counts. x: Wall hits, y: Element hits
@export var collision_counts: Vector2i = Vector2i.ZERO
## The highest combo multiplier reached during the run.
@export var max_fusion_combo: float = 1.0
## Total duration of the run in seconds.
@export var run_time: float = 0.0

#-----------------------------------------------------------------------------
# Helper methods for calculations (used by GameManager or potentially UI)
#-----------------------------------------------------------------------------

## Returns the total number of collisions (wall + element).
func get_total_collisions() -> int:
	return collision_counts.x + collision_counts.y

#-----------------------------------------------------------------------------
# Debugging
#-----------------------------------------------------------------------------

## Override the default _to_string method for better debugging output.
func _to_string() -> String:
	# Format the key data into a readable string.
	return "RunStats(Time: %.1fs, Collisions: %s, MaxCombo: x%.1f)" % \
			[run_time, str(collision_counts), max_fusion_combo]

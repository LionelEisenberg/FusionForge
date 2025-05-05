# upgrade_tree_layout.gd
# Defines a custom resource to store the visual layout positions for the upgrade tree.
class_name UpgradeTreeLayout
extends Resource

## Dictionary mapping upgrade IDs (String) to their UI positions (Vector2).
## Populate this dictionary in the Inspector when creating a .tres file from this script.
@export var node_positions: Dictionary[String, Vector2] = {}

# Example structure within the .tres file's Inspector:
# node_positions = {
#	"increase_max_energy_1": Vector2(100, 50),
#	"increase_max_stability_1": Vector2(100, 150),
#	"increase_base_collision_energy_1": Vector2(250, 50),
#	# ... etc for all upgrades
# }

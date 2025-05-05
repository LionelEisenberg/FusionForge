# --- upgrade_node_container.gd ---
# Manages the display of the upgrade tree.
# Instantiates, positions, connects, and updates UpgradeNode instances.
class_name UpgradeNodeContainer
extends Panel

## Scene for the individual upgrade nodes (assign UpgradeNode.tscn in Inspector)
@export var upgrade_node_scene: PackedScene
## Resource file containing the layout positions (assign upgrade_layout.tres in Inspector)
@export var layout_resource: UpgradeTreeLayout # Assumes UpgradeTreeLayout.gd exists

# Node References (None needed if adding directly to self)
@onready var node_container: Control = self

const UPGRADE_NODE_SIZE := Vector2(64, 64)

# Panning state
var _dragging: bool = false
var _drag_start_mouse_pos: Vector2 = Vector2.ZERO
# Store initial positions when drag starts to avoid drift
var _drag_start_node_positions: Dictionary = {}

# Internal state
var _upgrade_nodes: Dictionary = {} # { "upgrade_id": UpgradeNode_instance }
var _layout_data: Dictionary = {} # { "upgrade_id": Vector2 }

func _ready() -> void:
	# Validate required exported scenes/resources
	if upgrade_node_scene == null:
		printerr("UpgradeView: Upgrade Node Scene not assigned in Inspector!")
		return
	if layout_resource == null:
		printerr("UpgradeView: Layout Resource not assigned in Inspector!")
	else:
		_layout_data = layout_resource.node_positions

	# Connect to UpgradeManager signal to refresh UI after purchase
	if UpgradeManager:
		UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)
	else:
		printerr("UpgradeView: UpgradeManager not found!")

	# Build the graph display on ready
	_build_upgrade_graph()
	# Set initial display state for all nodes
	_update_all_node_displays()
	# Trigger initial draw for connection lines
	queue_redraw()

# --- Input Handling for Panning ---
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_start_mouse_pos = get_global_mouse_position()
				_drag_start_node_positions.clear()
				for id in _upgrade_nodes:
					_drag_start_node_positions[id] = _upgrade_nodes[id].position
				accept_event()
			elif _dragging: # Button released
				_dragging = false
				_drag_start_node_positions.clear()
				accept_event()

	elif event is InputEventMouseMotion and _dragging:
		var current_mouse_pos = get_global_mouse_position()
		var mouse_delta = current_mouse_pos - _drag_start_mouse_pos

		# Apply the mouse delta to the stored start positions of each node
		for id in _upgrade_nodes:
			if _drag_start_node_positions.has(id):
				# Check if node instance still exists (might be removed/hidden)
				var node_instance = _upgrade_nodes[id] as UpgradeNode
				if is_instance_valid(node_instance):
					node_instance.position = _drag_start_node_positions[id] + mouse_delta

		# Redraw connection lines after panning
		queue_redraw()
		accept_event()

	# TODO: Add InputEventMouseButton with WHEEL_UP/WHEEL_DOWN for zoom


## Clears and rebuilds the entire upgrade graph display.
func _build_upgrade_graph() -> void:
	# Clear existing nodes first
	for node in get_children():
		if node is UpgradeNode: # Check type before queueing free
			node.queue_free()
	_upgrade_nodes.clear()

	if not UpgradeManager: return # Cannot proceed without manager

	var all_upgrades: Array[UpgradeData] = UpgradeManager.get_all_upgrade_data()
	if all_upgrades.is_empty():
		print("UpgradeView: No upgrade data found in UpgradeManager.")
		return

	# --- 1. Instantiate and Place Nodes ---
	for upgrade_data in all_upgrades:
		if upgrade_data == null or upgrade_data.id.is_empty():
			printerr("UpgradeView: Encountered invalid UpgradeData.")
			continue

		var node_instance = upgrade_node_scene.instantiate() as UpgradeNode
		if node_instance == null:
			printerr("UpgradeView: Failed to instantiate UpgradeGraphNode scene.")
			continue

		node_instance.upgrade_id = upgrade_data.id
		node_instance.name = upgrade_data.id # Set node name for easy lookup via get_node()

		# Get position from layout data, default to ZERO if not found
		var node_pos = Vector2.ZERO
		if _layout_data.has(upgrade_data.id):
			node_pos = _layout_data.get(upgrade_data.id) - UPGRADE_NODE_SIZE / 2
		else:
			printerr("UpgradeView: Position not found in layout data for upgrade: ", upgrade_data.id)
			node_instance.visible = false
		node_instance.position = node_pos

		# Store instance and add to graph (directly to self, or a child container)
		_upgrade_nodes[upgrade_data.id] = node_instance
		node_container.add_child(node_instance)


## Updates the display state of all nodes based on current game state.
## Also handles node visibility based on prerequisites/purchase status.
func _update_all_node_displays() -> void:
	if not UpgradeManager: return

	for upgrade_id in _upgrade_nodes:
		var node_instance = _upgrade_nodes[upgrade_id] as UpgradeNode
		var data: UpgradeData = UpgradeManager.get_upgrade_data(upgrade_id)
		if data == null:
			node_instance.visible = false # Hide if data is somehow missing
			continue

		# Get current state for this upgrade
		var purchased_level: int = UpgradeManager.get_purchased_level(upgrade_id)
		var cost_money: float = UpgradeManager.get_upgrade_cost(upgrade_id) # Use float version
		var can_afford: bool = UpgradeManager.can_purchase(upgrade_id) # Checks everything needed for purchase button state
		var prereqs_met: bool = UpgradeManager._at_least_one_prerequisite_met(upgrade_id) # Check at least one prereq separately for visibility

		# --- Visibility Logic ---
		node_instance.visible = prereqs_met

		# --- Update Display (if visible) ---
		if node_instance.visible:
			# Pass only the data needed by the simplified update_display
			node_instance.update_display(data, purchased_level, cost_money, can_afford)

	# Request redraw to update connection lines after visibility/state changes
	queue_redraw()


## Called when UpgradeManager signals that any upgrade was purchased.
func _on_upgrade_purchased(_upgrade_id: String, _new_level: int) -> void:
	_update_all_node_displays()


## Draw connection lines between nodes.
func _draw() -> void:
	if not UpgradeManager: return

	# Define line appearance
	var line_color = Color.GRAY
	var purchased_line_color = Color.YELLOW
	var line_width = 2.0
	var antialiased = true

	# Iterate through nodes that *have* prerequisites
	for upgrade_id in _upgrade_nodes:
		var node_instance = _upgrade_nodes[upgrade_id] as UpgradeNode
		if not node_instance or not node_instance.visible: continue # Skip hidden nodes

		var data: UpgradeData = UpgradeManager.get_upgrade_data(upgrade_id)
		if data == null or data.prerequisites.is_empty(): continue # Skip nodes without prereqs

		var current_level = UpgradeManager.get_purchased_level(upgrade_id)

		# Define connection points (e.g., center, top-middle, bottom-middle)
		# Using center for simplicity here
		var end_pos = node_instance.position + node_instance.size / 2.0
		# TODO: Define better connection points (e.g., top center: node_instance.position + Vector2(node_instance.size.x / 2.0, 0))

		for prereq_id in data.prerequisites:
			if _upgrade_nodes.has(prereq_id):
				var prereq_node = _upgrade_nodes[prereq_id] as UpgradeNode
				if prereq_node and prereq_node.visible: # Only draw if prereq node is also visible
					var prereq_level = UpgradeManager.get_purchased_level(prereq_id)

					# Determine start position on prerequisite node
					var start_pos = prereq_node.position + prereq_node.size / 2.0
					# TODO: Define better connection points (e.g., bottom center: prereq_node.position + Vector2(prereq_node.size.x / 2.0, prereq_node.size.y))

					# Determine line color based on whether prerequisite is met (purchased)
					var color_to_use = purchased_line_color if prereq_level > 0 else line_color

					# Draw the line
					draw_line(start_pos, end_pos, color_to_use, line_width, antialiased)
			else:
				# This shouldn't happen if all nodes are created correctly
				printerr("UpgradeView _draw: Prerequisite node not found: ", prereq_id)

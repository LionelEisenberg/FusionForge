extends Node2D

#-----------------------------------------------------------------------------
# Exports - Assign in Godot Editor Inspector
#-----------------------------------------------------------------------------
@export var run_scene: PackedScene
@export var upgrade_menu_scene: PackedScene

@export var subviewport_path: NodePath = NodePath("")
@export var top_level_run_scene_container_path: NodePath = NodePath("")
@export var upgrade_canvas_layer_path: NodePath = NodePath("")

#-----------------------------------------------------------------------------
# Override exports
#-----------------------------------------------------------------------------

@export var override_save_file: bool = false
@export var invincible_mode: bool = false

#-----------------------------------------------------------------------------
# Variables
#-----------------------------------------------------------------------------
var run_scene_instance: Node = null
var upgrade_menu_instance: Control = null

var subviewport_node: SubViewport = null
var top_level_run_scene_container_node: HBoxContainer = null
var upgrade_canvas_layer_node: CanvasLayer = null


# Game State Machine
enum GameState {
	INITIALIZING,
	UPGRADING,
	STARTING_RUN,
	RUNNING
}
var current_state: GameState = GameState.INITIALIZING

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------
func _ready() -> void:
	# Override Logic for Invincible Mode:
	if GameManager:
		GameManager.invincible_mode = invincible_mode
	
	# Load persistent data first (ensure PersistenceManager loads before MainGame in Autoload)
	if PersistenceManager:
		if override_save_file:
			PersistenceManager.delete_data()
	else:
		printerr("MainGame: PersistenceManager not found!")

	# Get node references from paths
	if subviewport_path.is_empty():
		printerr("MainGame: SubViewport Path not assigned in Inspector!")
	else:
		subviewport_node = get_node_or_null(subviewport_path) as SubViewport
		if subviewport_node == null:
			printerr("MainGame: Failed to get SubViewport node from path: ", subviewport_path)

	if top_level_run_scene_container_path.is_empty():
		printerr("MainGame: TopLevelRunSceneContainer Path not assigned in Inspector!")
	else:
		top_level_run_scene_container_node = get_node_or_null(top_level_run_scene_container_path) as HBoxContainer
		if top_level_run_scene_container_node == null:
			printerr("MainGame: Failed to get TopLevelRunSceneContainer node from path: ", top_level_run_scene_container_path)
	
	if upgrade_canvas_layer_path.is_empty():
		printerr("MainGame: UpgradeCanvasLayer Path not assigned in Inspector!")
	else:
		upgrade_canvas_layer_node = get_node_or_null(upgrade_canvas_layer_path) as CanvasLayer
		if upgrade_canvas_layer_node == null:
			printerr("MainGame: Failed to get UpgradeCanvasLayerNode node from path: ", upgrade_canvas_layer_path)


	# --- Upgrade Menu Instantiation ---
	if upgrade_menu_scene:
		upgrade_menu_instance = upgrade_menu_scene.instantiate()
		upgrade_canvas_layer_node.add_child(upgrade_menu_instance) # Add as direct child, or to a specific UI layer
		# Connect its signal to start a run
		if upgrade_menu_instance.has_signal("start_run_requested"):
			upgrade_menu_instance.start_run_requested.connect(start_new_run)
		else:
			printerr("MainGame: Upgrade Menu scene missing 'start_run_requested' signal!")
	else:
		printerr("MainGame: Upgrade Menu Scene not assigned in Inspector!")

	# Start in the upgrading state
	set_game_state(GameState.UPGRADING)


func _notification(what):
	# Handle save on quit
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if PersistenceManager:
			print("MainGame: Close request received, saving game...") # Keep this print
			PersistenceManager.save_data()
		get_tree().quit() # Quit after attempting save


#-----------------------------------------------------------------------------
# State Management
#-----------------------------------------------------------------------------

func set_game_state(new_state: GameState) -> void:
	if new_state == current_state:
		return

	current_state = new_state

	match current_state:
		GameState.INITIALIZING:
			pass # Should only happen briefly

		GameState.UPGRADING:
			# Clean up previous run scene if it exists
			if is_instance_valid(run_scene_instance):
				run_scene_instance.queue_free()
				run_scene_instance = null

			# Show upgrade menu, hide run view container
			if is_instance_valid(upgrade_menu_instance): upgrade_menu_instance.visible = true
			if top_level_run_scene_container_node: top_level_run_scene_container_node.visible = false

		GameState.STARTING_RUN:
			# Hide upgrade menu, show run view container
			if is_instance_valid(upgrade_menu_instance): upgrade_menu_instance.visible = false
			if top_level_run_scene_container_node: top_level_run_scene_container_node.visible = true

			# Clean up just in case (should already be null from UPGRADING state)
			if is_instance_valid(run_scene_instance):
				run_scene_instance.queue_free()

			# Validate nodes needed for starting
			if run_scene == null:
				printerr("MainGame: Run Scene not assigned in Inspector!")
				set_game_state(GameState.UPGRADING) # Go back if scene missing
				return
			if subviewport_node == null:
				printerr("MainGame: SubViewport node is invalid!")
				set_game_state(GameState.UPGRADING) # Go back if viewport missing
				return

			# Instance and setup the new run scene
			run_scene_instance = run_scene.instantiate()
			subviewport_node.add_child(run_scene_instance)

			# --- Defer RunScene Interaction ---
			run_scene_instance.run_conclusion_finished.connect(_on_run_conclusion_finished, CONNECT_ONE_SHOT)

			# Reset managers
			if GameManager: GameManager.reset_for_new_run()
			if RunManager: RunManager.reset_stats()
			
			# Start run
			run_scene_instance.start_run()

			set_game_state(GameState.RUNNING)

		GameState.RUNNING:
			# Main gameplay happens within RunScene instance
			pass

#-----------------------------------------------------------------------------
# Public Functions / Triggers
#-----------------------------------------------------------------------------

## Triggered by Upgrade Menu signal (when connected)
func start_new_run() -> void:
	if current_state == GameState.UPGRADING:
		set_game_state(GameState.STARTING_RUN)

#-----------------------------------------------------------------------------
# Signal Handlers
#-----------------------------------------------------------------------------

## Called by RunScene signal when its conclusion sequence (results popup) is done.
func _on_run_conclusion_finished() -> void:
	if current_state == GameState.RUNNING:
		set_game_state(GameState.UPGRADING)

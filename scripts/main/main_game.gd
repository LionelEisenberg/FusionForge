extends Node2D

#-----------------------------------------------------------------------------
# Exports - Assign in Godot Editor Inspector
#-----------------------------------------------------------------------------
@export var run_scene: PackedScene
@export var upgrade_menu_scene: PackedScene

@export var subviewport_path: NodePath = NodePath("")
@export var top_level_run_scene_container_path: NodePath = NodePath("")
@export var upgrade_canvas_layer_path: NodePath = NodePath("")

@onready var main_menu: Control = %MainMenu
@onready var options_menu: Control = %OptionsMenu

#-----------------------------------------------------------------------------
# Override exports
#-----------------------------------------------------------------------------

@export var override_save_file: bool = false
@export var invincible_mode: bool = false
@export var infinite_resources: bool = false

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
	MAIN_MENU,
	OPTIONS_MENU,
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
		GameManager.infinite_resources = infinite_resources
	
	# Load persistent data first (ensure PersistenceManager loads before MainGame in Autoload)
	if PersistenceManager:
		if override_save_file:
			PersistenceManager.load_new_save_data()
	else:
		printerr("MainGame: PersistenceManager not found!")

	# Connect MainMenu signals
	if main_menu:
		main_menu.continue_game.connect(continue_game)
		main_menu.start_newgame.connect(start_newgame)
		main_menu.options_menu.connect(open_options_menu)

	if options_menu:
		options_menu.open_main_menu.connect(open_main_menu)

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

	# Start in the upgrading state
	_set_game_state(GameState.MAIN_MENU)


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

func _set_game_state(new_state: GameState) -> void:
	if new_state == current_state:
		return

	current_state = new_state
	_reset_subcomponents()
	
	match current_state:
		GameState.MAIN_MENU:
			main_menu.visible = true

		GameState.OPTIONS_MENU:
			options_menu.visible = true

		GameState.UPGRADING:
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

			if is_instance_valid(upgrade_menu_instance): upgrade_menu_instance.visible = true

		GameState.RUNNING:
			# show run view container
			if top_level_run_scene_container_node: 
				top_level_run_scene_container_node.visible = true

			# Validate nodes needed for starting
			if run_scene == null:
				printerr("MainGame: Run Scene not assigned in Inspector!")
				_set_game_state(GameState.UPGRADING) # Go back if scene missing
				return
			if subviewport_node == null:
				printerr("MainGame: SubViewport node is invalid!")
				_set_game_state(GameState.UPGRADING) # Go back if viewport missing
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

func _reset_subcomponents():
	# Clean up instances
	if is_instance_valid(run_scene_instance): run_scene_instance.queue_free()
	
	if is_instance_valid(upgrade_menu_instance): upgrade_menu_instance.queue_free()
		
	# Reset visibility
	if is_instance_valid(upgrade_menu_instance): upgrade_menu_instance.visible = false
	
	if top_level_run_scene_container_node: top_level_run_scene_container_node.visible = false
	
	if main_menu: main_menu.visible = false
	
	if options_menu: options_menu.visible = false

#-----------------------------------------------------------------------------
# Public Functions / Triggers
#-----------------------------------------------------------------------------

## Triggered by Upgrade Menu signal (when connected)
func start_new_run() -> void:
	if current_state == GameState.UPGRADING:
		_set_game_state(GameState.RUNNING)

## Triggered by the Main Menu signal
func start_newgame() -> void:
	PersistenceManager.load_new_save_data()
	_set_game_state(GameState.UPGRADING)

func continue_game() -> void:
	PersistenceManager.load_data()
	_set_game_state(GameState.UPGRADING)

func open_options_menu() -> void:
	_set_game_state(GameState.OPTIONS_MENU)

func open_main_menu() -> void:
	_set_game_state(GameState.MAIN_MENU)

#-----------------------------------------------------------------------------
# Signal Handlers
#-----------------------------------------------------------------------------

## Called by RunScene signal when its conclusion sequence (results popup) is done.
func _on_run_conclusion_finished() -> void:
	if current_state == GameState.RUNNING:
		_set_game_state(GameState.UPGRADING)

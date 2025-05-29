# Manages the lifecycle of a single gameplay run session.
class_name Run
extends Node2D

#-----------------------------------------------------------------------------
# Signals
#-----------------------------------------------------------------------------
## Emitted when the run conclusion sequence (results popup) is finished.
signal run_conclusion_finished

#-----------------------------------------------------------------------------
# Exports - Assign in Godot Editor Inspector
#-----------------------------------------------------------------------------
## The scene for the reactor chamber environment.
@export var reactor_chamber_scene: PackedScene
## The scene for the end-of-run results popup UI.
@export var run_results_popup_scene: PackedScene

#-----------------------------------------------------------------------------
# Variables / Node References
#-----------------------------------------------------------------------------

var reactor_chamber_instance: Node2D = null
var run_results_popup_instance: Control = null
var _element_spawner_ref: Node = null

@onready var combo_display: MarginContainer = %ComboDisplay

func _ready() -> void:	
	if GameManager:
		GameManager.energy_depleted.connect(conclude_run)
		GameManager.stability_depleted.connect(conclude_run)
	
	if CollisionManager:
		CollisionManager.request_element_destroy.connect(destroy_element)

#-----------------------------------------------------------------------------
# Public Methods (Called by MainGame)
#-----------------------------------------------------------------------------

## Sets up and starts the gameplay run.
func start_run() -> void:
	print("RunScene: Starting run...")

	if is_instance_valid(reactor_chamber_instance):
		reactor_chamber_instance.queue_free()
	if is_instance_valid(run_results_popup_instance):
		run_results_popup_instance.queue_free()

	reactor_chamber_instance = reactor_chamber_scene.instantiate()
	reactor_chamber_instance.modulate = Color.WHITE
	add_child(reactor_chamber_instance)

	_element_spawner_ref = reactor_chamber_instance.get_node_or_null("ElementSpawner")
	if not is_instance_valid(_element_spawner_ref):
		printerr("RunScene: ElementSpawner node not found within ReactorChamber instance!")
		return
	_element_spawner_ref.start_spawning()
	
	if RunManager: RunManager.start_run_stats()

## Initiates the end-of-run sequence. Called by MainGame on failure signals.
func conclude_run() -> void:
	print("RunScene: Concluding run...")
	if RunManager: RunManager.finalize_run_stats()

	if is_instance_valid(_element_spawner_ref):
		_element_spawner_ref.stop_spawning()
	
	if is_instance_valid(reactor_chamber_instance):
		reactor_chamber_instance.modulate = Color("3d3636")

		for child in reactor_chamber_instance.get_children():
			if child is Element: # Check if the child uses the Element class_name
				child.linear_velocity = Vector2.ZERO
				child.angular_velocity = 0.0
				child.call_deferred("set_freeze_enabled", true)
				var collision_shape = child.get_node_or_null("CollisionShape2D") # Assumes this name
				if collision_shape is CollisionShape2D:
					collision_shape.call_deferred("set_disabled", true)
				else:
					printerr("RunScene: Could not find CollisionShape2D child in Element ", child.name, " to disable.")
				child.set_physics_process(false)
			if child is Collectible:
				child.apply_pickup_effect()
				child.call_deferred("queue_free")

	else:
		printerr("RunScene: Reactor chamber instance invalid during conclude_run!")

	if combo_display:
		combo_display.visible = false

	var run_stats : RunStats = RunManager.get_run_stats()
	var money_earned = GameManager.calculate_and_award_money(run_stats)

	run_results_popup_instance = run_results_popup_scene.instantiate()
	add_child(run_results_popup_instance) # Add popup to this scene

	# Use CONNECT_ONE_SHOT to auto-disconnect after firing once
	run_results_popup_instance.dismissed.connect(_on_results_popup_closed, CONNECT_ONE_SHOT)

	# Populate and show the popup (Assumes method exists)
	run_results_popup_instance.show_results(run_stats, money_earned)

func destroy_element(element : Element) -> void:
	for child in reactor_chamber_instance.get_children():
		if child is Element and child == element:
			child.queue_free()
			reactor_chamber_instance.call_deferred("remove_child", child)

#-----------------------------------------------------------------------------
# Signal Handlers
#-----------------------------------------------------------------------------

## Called when the RunResultsPopup signals it has been dismissed by the user.
func _on_results_popup_closed() -> void:
	run_conclusion_finished.emit()

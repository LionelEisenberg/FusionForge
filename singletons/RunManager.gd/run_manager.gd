extends Node

#-----------------------------------------------------------------------------
# Signals
#-----------------------------------------------------------------------------

signal run_stats_updated(run_stats: Dictionary)
signal run_time_sec_updated(run_time_sec: float)
signal fusion_combo_updated(multiplier: float)

#-----------------------------------------------------------------------------
# Exports
#-----------------------------------------------------------------------------
## Time in seconds before the fusion combo multiplier resets if no fusion occurs.
@export var combo_decay_time: float = 3.0
## Maximum combo multiplier allowed.
@export var max_combo_cap: float = 10.0

#-----------------------------------------------------------------------------
# State Variables
#-----------------------------------------------------------------------------

# --- Run State (Reset every run) ---
var collision_counts: Vector2i = Vector2i.ZERO # x: Wall hits, y: Element hits
var current_fusion_combo_multiplier: float = 1.0
var max_fusion_combo_multiplier_this_run: float = 1.0
var heaviest_element_fused_mass: float = 0.0
var run_time_sec: float = 0.0

var _is_run_active : bool = false

# Internal timer for combo decay
var _combo_timer: Timer

func _ready() -> void:
	_combo_timer = Timer.new()
	_combo_timer.name = "ComboDecayTimer"
	_combo_timer.wait_time = combo_decay_time
	_combo_timer.one_shot = true # Only fire once per start()
	_combo_timer.timeout.connect(_on_combo_timer_timeout)
	add_child(_combo_timer)
	
	if CollisionManager:
		CollisionManager.wall_collision_processed.connect(_on_increment_wall_collision)
		CollisionManager.element_collision_processed.connect(_on_increment_element_collision)
		CollisionManager.fusion_processed.connect(_on_fusion_processed)
	else:
		printerr("RunManager: CRITICAL - Could not get save_game_data from PersistenceManager on ready!")

	
	reset_stats()

func _process(delta: float) -> void:
	if not _is_run_active:
		return
	run_time_sec += delta
	run_time_sec_updated.emit(run_time_sec)

func start_run_stats() -> void:
	_is_run_active = true
	reset_stats()

func finalize_run_stats() -> void:
	_is_run_active = false

func reset_stats() -> void:
	collision_counts = Vector2i.ZERO
	current_fusion_combo_multiplier = 1.0
	max_fusion_combo_multiplier_this_run = 1.0
	heaviest_element_fused_mass = 0.0
	run_time_sec = 0.0
	_combo_timer.stop() # Ensure timer is stopped

	run_stats_updated.emit(get_run_stats()) # Direct emit
	fusion_combo_updated.emit(current_fusion_combo_multiplier)

func _on_fusion_processed(_e1 : Element, _e2 : Element, result_element_data : Dictionary) -> void:
	_register_fusion_for_combo()
	_update_heaviest_element(result_element_data.mass)

## Registers a fusion event, updating combo logic. Called by CollisionManager.
# TODO: Potentially accept fused element data here to determine increment amount later.
func _register_fusion_for_combo() -> void:
	current_fusion_combo_multiplier = min(current_fusion_combo_multiplier + 1.0, max_combo_cap)
	max_fusion_combo_multiplier_this_run = max(max_fusion_combo_multiplier_this_run, current_fusion_combo_multiplier)

	# Restart the decay timer
	_combo_timer.start()

	# Emit signals
	fusion_combo_updated.emit(current_fusion_combo_multiplier)
	run_stats_updated.emit(get_run_stats()) # Direct emit

## Updates the heaviest element fused this run. Called by CollisionManager.
func _update_heaviest_element(fused_element_mass: float) -> void:
	if fused_element_mass > heaviest_element_fused_mass:
		heaviest_element_fused_mass = fused_element_mass
		run_stats_updated.emit(get_run_stats()) # Direct emit

func _on_combo_timer_timeout() -> void:
	current_fusion_combo_multiplier = 1

## Increments the wall collision counter. Called by CollisionManager.
func _on_increment_wall_collision() -> void:
	collision_counts.x += 1
	run_stats_updated.emit(get_run_stats()) # Direct emit

## Increments the element-element collision counter. Called by CollisionManager.
func _on_increment_element_collision() -> void:
	collision_counts.y += 1
	run_stats_updated.emit(get_run_stats()) # Direct emit

## Returns a dictionary containing the current run statistics.
func get_run_stats() -> Dictionary:
	return {
		"collision_count_wall": collision_counts.x,
		"collision_count_element": collision_counts.y,
		"max_fusion_combo": max_fusion_combo_multiplier_this_run,
		"run_time": run_time_sec,
		"heaviest_element_mass": heaviest_element_fused_mass,
	}
	

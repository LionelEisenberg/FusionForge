extends Node

#-----------------------------------------------------------------------------
# Signals
#-----------------------------------------------------------------------------

signal run_stats_updated(run_stats: RunStats)
signal run_time_sec_updated(run_time_sec: float)
signal fusion_combo_updated(multiplier: float)

#-----------------------------------------------------------------------------
# Exports
#-----------------------------------------------------------------------------
@export var combo_decay_time: float = 3.0
@export var max_combo_cap: float = 10.0

#-----------------------------------------------------------------------------
# State Variables
#-----------------------------------------------------------------------------

## Holds the stats object for the currently active run. Initialized in reset_stats.
var current_stats: RunStats = null

#-----------------------------------------------------------------------------
# Internal Variables
#-----------------------------------------------------------------------------

## Internal variable for the currently decaying combo multiplier.
var _current_fusion_combo_multiplier: float = 1.0
var _is_run_active: bool = false
# Internal timer for combo decay
var _combo_timer: Timer

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------


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
	if not _is_run_active or current_stats == null:
		return
	current_stats.run_time += delta
	run_time_sec_updated.emit(current_stats.run_time)

#-----------------------------------------------------------------------------
# Stat Functions
#-----------------------------------------------------------------------------

func start_run_stats() -> void:
	_is_run_active = true
	reset_stats()

func finalize_run_stats() -> void:
	_is_run_active = false

func get_run_stats() -> RunStats:
	return current_stats

func reset_stats() -> void:
	current_stats = RunStats.new()
	_current_fusion_combo_multiplier = 1.0
	_combo_timer.stop()

	if current_stats:
		run_stats_updated.emit(current_stats)
		fusion_combo_updated.emit(_current_fusion_combo_multiplier)
		run_time_sec_updated.emit(current_stats.run_time)

#-----------------------------------------------------------------------------
# Timer Functions
#-----------------------------------------------------------------------------

func get_combo_timer_time_left() -> float:
	return _combo_timer.time_left

func get_combo_timer_wait_time() -> float:
	return _combo_timer.wait_time

func is_combo_timer_active() -> float:
	return not _combo_timer.is_stopped()

func _on_combo_timer_timeout() -> void:
	_current_fusion_combo_multiplier = 1.0
	fusion_combo_updated.emit(_current_fusion_combo_multiplier)

func _on_fusion_processed(_e1 : Element, _e2 : Element, _result_element_data : Dictionary) -> void:
	_register_fusion_for_combo()
	#_update_heaviest_element(result_element_data.mass)

## Registers a fusion event, updating combo logic. Called by CollisionManager.
# TODO: Potentially accept fused element data here to determine increment amount later.
func _register_fusion_for_combo() -> void:
	_current_fusion_combo_multiplier = min(_current_fusion_combo_multiplier + 1.0, max_combo_cap)
	current_stats.max_fusion_combo = max(current_stats.max_fusion_combo, _current_fusion_combo_multiplier)

	# Restart the decay timer
	_combo_timer.start()

	# Emit signals
	fusion_combo_updated.emit(_current_fusion_combo_multiplier)
	run_stats_updated.emit(current_stats)

## Updates the heaviest element fused this run. Called by CollisionManager.
#func _update_heaviest_element(fused_element_mass: float) -> void:
	#if fused_element_mass > current_stats.heav:
		#heaviest_element_fused_mass = fused_element_mass
		#run_stats_updated.emit(get_run_stats()) # Direct emit

## Increments the wall collision counter. Called by CollisionManager.
func _on_increment_wall_collision() -> void:
	current_stats.collision_counts.x += 1
	run_stats_updated.emit(current_stats) # Direct emit

## Increments the element-element collision counter. Called by CollisionManager.
func _on_increment_element_collision() -> void:
	current_stats.collision_counts.y += 1
	run_stats_updated.emit(current_stats) # Direct emit

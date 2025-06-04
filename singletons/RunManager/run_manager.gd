extends Node

#-----------------------------------------------------------------------------
# Signals
#-----------------------------------------------------------------------------

signal run_stats_updated(run_stats: RunStats)
signal run_time_sec_updated(run_time_sec: float)
signal fusion_combo_updated(multiplier: float)

signal element_count_updated(current_count: int, max_count: int)
signal next_spawn_time_updated(time_left: float)

signal energy_cost_per_second_calculated(cost_per_second: float)

#-----------------------------------------------------------------------------
# Constant Variables
#-----------------------------------------------------------------------------
const BASE_COMBO_DECAY_TIME: float = 3.0
const BASE_MAX_COMBO_CAP: float = 3.0

#-----------------------------------------------------------------------------
# State Variables
#-----------------------------------------------------------------------------
var current_stats: RunStats = null

# --- Upgradeable Properties ---
var combo_decay_time: float = BASE_COMBO_DECAY_TIME
var max_combo_cap: float = BASE_MAX_COMBO_CAP

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
		CollisionManager.element_collision_data_calculated.connect(_on_element_collision_data_calculated)
	else:
		push_warning("RunManager: Could not connect signals from CollisionManager!")

	# Connect to UpgradeManager to receive effect updates
	if UpgradeManager:
		UpgradeManager.upgrades_applied.connect(_on_upgrades_applied)
	else:
		push_warning("RunManager: Could not connect to UpgradeManager! Applying default effects.")
	
	if GameManager:
		GameManager.fusion_cores_updated.connect(_on_fusion_cores_updated)
	
	energy_cost_per_second_calculated.connect(_on_energy_cost_per_second_calculated)
	
	reset_stats()


func _process(delta: float) -> void:
	if not _is_run_active or current_stats == null:
		return
	current_stats.run_time += delta
	run_time_sec_updated.emit(current_stats.run_time)


#-----------------------------------------------------------------------------
# Upgrade Handling
#-----------------------------------------------------------------------------

## Signal handler connected to UpgradeManager.upgrades_applied.
func _on_upgrades_applied(effects_data: UpgradeEffects) -> void:
	combo_decay_time = BASE_COMBO_DECAY_TIME + effects_data.combo_decay_time_add
	max_combo_cap = BASE_MAX_COMBO_CAP + effects_data.max_combo_cap_add

	combo_decay_time = max(0.1, combo_decay_time) # Ensure decay time is positive
	max_combo_cap = max(1.0, max_combo_cap) # Ensure max combo is at least 1

	if _combo_timer:
		_combo_timer.wait_time = combo_decay_time

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


#-----------------------------------------------------------------------------
# ---  Update Functions ElementSpawner ---
#-----------------------------------------------------------------------------

## Called by ElementSpawner whenever the count or max capacity changes.
func update_element_stats(current_count: int, max_count: int) -> void:
	element_count_updated.emit(current_count, max_count)

## Called by ElementSpawner every frame (or periodically) to update the timer display.
func update_next_spawn_time(time_left: float) -> void:
	next_spawn_time_updated.emit(time_left)


#-----------------------------------------------------------------------------
# Stat Changing Functions
#-----------------------------------------------------------------------------

## Called by EnergyCollectible when it's picked up.
func register_energy_collected_from_pickup(amount: float) -> void:
	if current_stats and _is_run_active: # Only track if a run is active and stats object exists
		current_stats.total_energy_collected_from_pickups += amount

func _on_fusion_processed(_e1 : Element, _e2 : Element, fusion_recipe : FusionRecipe) -> void:
	current_stats.collision_counts.z += 1
	_register_fusion_for_combo(fusion_recipe)
	run_stats_updated.emit(current_stats) # Direct emit
	
func _on_element_collision_data_calculated(_e_a: Element, _e_b: Element, combined_momentum: float) -> void:
	if current_stats and combined_momentum > current_stats.highest_combined_collision_momentum:
		current_stats.highest_combined_collision_momentum = combined_momentum

## Registers a fusion event, updating combo logic. Called by CollisionManager.
func _register_fusion_for_combo(fusion_recipe: FusionRecipe) -> void:
	var combo_increase_value = fusion_recipe.combo_increase_value
	_current_fusion_combo_multiplier = min(_current_fusion_combo_multiplier + combo_increase_value, max_combo_cap)
	current_stats.max_fusion_combo = max(current_stats.max_fusion_combo, _current_fusion_combo_multiplier)

	# Restart the decay timer
	_combo_timer.start()

	# Emit signals
	fusion_combo_updated.emit(_current_fusion_combo_multiplier)
	run_stats_updated.emit(current_stats)

## Increments the wall collision counter. Called by CollisionManager.
func _on_increment_wall_collision() -> void:
	current_stats.collision_counts.x += 1
	run_stats_updated.emit(current_stats) # Direct emit

## Increments the element-element collision counter. Called by CollisionManager.
func _on_increment_element_collision() -> void:
	current_stats.collision_counts.y += 1
	run_stats_updated.emit(current_stats) # Direct emit

func _on_energy_cost_per_second_calculated(cost_per_second: float) -> void:
	current_stats.latest_energy_cost_per_second = cost_per_second
	run_stats_updated.emit(current_stats)

func _on_fusion_cores_updated(_current_cores, amount : int) -> void:
	current_stats.fusion_cores_earned += amount
	run_stats_updated.emit(current_stats)
	

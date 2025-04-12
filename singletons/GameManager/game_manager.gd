extends Node

#-----------------------------------------------------------------------------
# Signals
#-----------------------------------------------------------------------------
signal energy_updated(current_energy: float, max_energy: float)
signal stability_updated(current_stability: float, max_stability: float)
signal money_updated(current_money: int)
signal fusion_cores_updated(current_cores: int)
signal energy_depleted # Emitted when energy <= 0
signal reactor_destroyed # Emitted when stability <= 0
signal run_results_calculated(money_earned: int) # Emitted after calculating end-of-run money

#-----------------------------------------------------------------------------
# State Variables
#-----------------------------------------------------------------------------

# --- Persistent State (via shared SaveGameData) ---
var live_save_data: SaveGameData = null # Reference set in _ready

# --- Run State (Reset every run) ---
var current_energy: float = 0.0
var current_stability: float = 0.0

# --- Global Parameters / Upgradeable Properties ---
# These should be initialized based on loaded save data (via UpgradeManager applying effects)
var max_energy: float = 1000.0
var max_stability: float = 100.0
var max_element_capacity: int = 50
var acceleration_factor: float = 1.0
var acceleration_magnitude: float = 25.0
var force_to_energy_conversion_factor: float = 0.5

#-----------------------------------------------------------------------------
# Initialization
#-----------------------------------------------------------------------------

func _ready() -> void:
	

	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data

		money_updated.emit(live_save_data.money)
		fusion_cores_updated.emit(live_save_data.fusion_cores)
	else:
		printerr("GameManager: CRITICAL - Could not get save_game_data from PersistenceManager on ready!")
	
	if CollisionManager:
		CollisionManager.energy_yielded.connect(add_energy)
		CollisionManager.stability_decreased.connect(decrease_stability)
		CollisionManager.fusion_core_awarded.connect(award_fusion_core)
	else:
		printerr("GameManager: CRITICAL - Could not connect signals from CollisionManager!")

	# TODO: UpdateValues from the UpgradeManager

	current_energy = max_energy
	current_stability = max_stability


## Called by UpgradeManager after applying loaded/default upgrades
func set_upgradeable_parameters(params: Dictionary) -> void:
	max_energy = params.get("max_energy", max_energy)
	max_stability = params.get("max_stability", max_stability)
	max_element_capacity = params.get("max_element_capacity", max_element_capacity)
	acceleration_factor = params.get("acceleration_factor", acceleration_factor)
	acceleration_magnitude = params.get("acceleration_magnitude", acceleration_magnitude)
	force_to_energy_conversion_factor = params.get("force_to_energy_conversion_factor", force_to_energy_conversion_factor)
	reset_for_new_run()


## Called by RunScene/MainGame at the start of a new run
func reset_for_new_run() -> void:
	current_energy = max_energy
	current_stability = max_stability

	energy_updated.emit(current_energy, max_energy)
	stability_updated.emit(current_stability, max_stability)


#-----------------------------------------------------------------------------
# Resource Management Functions
# 	Assumes live_save_data is valid after _ready
#-----------------------------------------------------------------------------

# --- Money ---
func get_money() -> int:
	return live_save_data.money

func add_money(amount: int) -> void:
	if amount <= 0: return
	live_save_data.money += amount
	money_updated.emit(live_save_data.money)

func can_spend_money(amount: int) -> bool:
	return live_save_data.money >= amount

func spend_money(amount: int) -> bool:
	if amount <= 0: return false
	if can_spend_money(amount): # Use helper function
		live_save_data.money -= amount
		money_updated.emit(live_save_data.money)
		return true
	return false

# --- Fusion Cores ---
func get_fusion_cores() -> int:
	return live_save_data.fusion_cores

func award_fusion_core(amount: int = 1) -> void:
	if amount <= 0: return
	live_save_data.fusion_cores += amount
	fusion_cores_updated.emit(live_save_data.fusion_cores)

func can_spend_fusion_cores(amount: int) -> bool:
	return live_save_data.fusion_cores >= amount

func spend_fusion_cores(amount: int) -> bool:
	if amount <= 0: return false
	if can_spend_fusion_cores(amount):
		live_save_data.fusion_cores -= amount
		fusion_cores_updated.emit(live_save_data.fusion_cores)
		return true
	return false

# --- Energy ---
func get_current_energy() -> float:
	return current_energy

func get_max_energy() -> float:
	return max_energy

func add_energy(amount: float) -> void:
	if amount <= 0: return
	current_energy = clampf(current_energy + amount, 0.0, max_energy)
	energy_updated.emit(current_energy, max_energy)

func spend_energy(amount: float) -> void:
	if amount <= 0: return
	current_energy -= amount
	energy_updated.emit(current_energy, max_energy)
	# Check for depletion AFTER spending
	if current_energy <= 0.0:
		current_energy = 0.0 # Clamp to zero
		energy_depleted.emit()
		print("GameManager: Energy depleted!") # Keep critical event print

# --- Stability ---
func get_current_stability() -> float:
	return current_stability

func get_max_stability() -> float:
	return max_stability

func add_stability(amount: float) -> void: # Less common
	if amount <= 0: return
	current_stability = clampf(current_stability + amount, 0.0, max_stability)
	stability_updated.emit(current_stability, max_stability)

func decrease_stability(amount: float) -> void:
	if amount <= 0: return
	current_stability -= amount
	stability_updated.emit(current_stability, max_stability)
	# Check for destruction AFTER decreasing
	if current_stability <= 0.0:
		current_stability = 0.0 # Clamp to zero
		stability_updated.emit(current_stability, max_stability)
		reactor_destroyed.emit()
		print("GameManager: Reactor destroyed!") # Keep critical event print

#-----------------------------------------------------------------------------
# End-of-Run Functions
#-----------------------------------------------------------------------------

## Called by RunScene/MainGame when run ends. Calculates and awards money.
func calculate_and_award_money(run_stats: RunStats) -> int:
	# TODO: Implement actual calculation based on GDD rules
	var collisions = run_stats.get_total_collisions()
	var max_fusion_combo = run_stats.max_fusion_combo

	# Example calculation (Replace with actual formula from GDD)
	var money_earned: int = int(collisions * max_fusion_combo)

	print("GameManager: Run ended. Stats: ", run_stats, " Money Earned: ", money_earned) # Removed status print

	if money_earned > 0:
		add_money(money_earned)

	run_results_calculated.emit(money_earned)
	return money_earned

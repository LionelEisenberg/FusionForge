extends Node

#-----------------------------------------------------------------------------
# Signals
#-----------------------------------------------------------------------------
signal energy_updated(current_energy: float, max_energy: float)
signal stability_updated(current_stability: float, max_stability: float)
signal money_updated(current_money: int)
signal fusion_cores_updated(current_cores: int, diff: int)
signal energy_depleted # Emitted when energy <= 0
signal stability_depleted # Emitted when stability <= 0
signal run_results_calculated(money_earned: int) # Emitted after calculating end-of-run money

## SFX & VFX
signal energy_depleted_sfx_required()
signal stability_depleted_sfx_required()

#-----------------------------------------------------------------------------
# Constant Variables
#-----------------------------------------------------------------------------
# These represent the base values *before* any upgrades are applied.
const BASE_MAX_ENERGY: float = 1000.0
const BASE_MAX_STABILITY: float = 100.0
const BASE_MONEY_PER_COLLISION: float = 1.0
const BASE_ELEMENT_COLLISION_FACTOR: float = 2.0

#-----------------------------------------------------------------------------
# State Variables
#-----------------------------------------------------------------------------

# --- Persistent State (via shared SaveGameData) ---
var live_save_data: SaveGameData = null # Reference set in _ready

# --- Run State (Reset every run) ---
var current_energy: float = 0.0
var current_stability: float = 0.0

# --- Upgradeable Properties ---
# They are initialized with the base constants and updated by _on_upgrades_applied.
var max_energy: float = BASE_MAX_ENERGY
var max_stability: float = BASE_MAX_STABILITY
var money_per_collision: float = BASE_MONEY_PER_COLLISION
var money_per_element_collision_factor: float = BASE_ELEMENT_COLLISION_FACTOR

# --- Parameters linked with Override / Testing ---
var invincible_mode = false
var infinite_resources: bool = false

#-----------------------------------------------------------------------------
# Initialization
#-----------------------------------------------------------------------------

func _ready() -> void:
	
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_update_resources)
		_update_resources()
	else:
		printerr("GameManager: CRITICAL - Could not get save_game_data from PersistenceManager on ready!")

	if CollisionManager:
		CollisionManager.stability_decreased.connect(decrease_stability)
	else:
		printerr("GameManager: CRITICAL - Could not connect signals from CollisionManager!")

	if UpgradeManager:
		UpgradeManager.upgrades_applied.connect(_on_upgrades_applied)
	else:
		printerr("GameManager: CRITICAL - Could not connect signals from UpgradeManager!")

func _update_resources() -> void:
	money_updated.emit(live_save_data.money)
	fusion_cores_updated.emit(live_save_data.fusion_cores, 0)


## Called by RunScene/MainGame at the start of a new run
func reset_for_new_run() -> void:
	current_energy = max_energy
	current_stability = max_stability

	energy_updated.emit(current_energy, max_energy)
	stability_updated.emit(current_stability, max_stability)

func _on_upgrades_applied(effects_data: UpgradeEffects) -> void:
	max_energy = BASE_MAX_ENERGY + effects_data.max_energy_add
	max_stability = BASE_MAX_STABILITY + effects_data.max_stability_add
	money_per_collision = BASE_MONEY_PER_COLLISION + effects_data.base_money_per_collision_add

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
	if infinite_resources: return true
	return live_save_data.money >= amount

func spend_money(amount: int) -> bool:
	if amount < 0: return false
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
	fusion_cores_updated.emit(live_save_data.fusion_cores, amount)

func can_spend_fusion_cores(amount: int) -> bool:
	if infinite_resources: return true
	return live_save_data.fusion_cores >= amount

func spend_fusion_cores(amount: int) -> bool:
	if amount < 0: return false
	if can_spend_fusion_cores(amount):
		live_save_data.fusion_cores -= amount
		fusion_cores_updated.emit(live_save_data.fusion_cores, amount)
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
		if not invincible_mode:
			energy_depleted.emit()
			energy_depleted_sfx_required.emit()
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
		if not invincible_mode:
			stability_depleted.emit()
			stability_depleted_sfx_required.emit()
			print("GameManager: Reactor destroyed!") 

#-----------------------------------------------------------------------------
# End-of-Run Functions
#-----------------------------------------------------------------------------

## Called by RunScene/MainGame when run ends. Calculates and awards money.
func calculate_and_award_money(run_stats: RunStats) -> int:
	var collisions = run_stats.collision_counts
	var max_fusion_combo = run_stats.max_fusion_combo

	# Example calculation (Replace with actual formula from GDD)
	var money_earned: int = int((collisions.x + collisions.y * money_per_element_collision_factor) * money_per_collision * max_fusion_combo)

	print("GameManager: Run ended. Stats: ", run_stats, "\n Money Earned: ", money_earned) # Removed status print

	if money_earned > 0:
		add_money(money_earned)

	run_results_calculated.emit(money_earned)
	return money_earned

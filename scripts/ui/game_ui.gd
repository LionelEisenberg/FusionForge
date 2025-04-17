class_name GameUI
extends PanelContainer # Or MarginContainer if that was the final root

#-----------------------------------------------------------------------------
# Node References (Using Scene Unique Names)
#-----------------------------------------------------------------------------
# Run Stats Section
@onready var run_time_value: Label = %RunTimeValue
@onready var total_collisions_value: Label = %TotalCollisionsValue
@onready var max_combo_value: Label = %MaxFusionComboValue

# Run Resources Section
@onready var energy_meter: ProgressBar = %EnergyProgressBar
@onready var durability_meter: ProgressBar = %DurabilityProgressBar

# Permanent Resources Section
@onready var money_value: Label = %MoneyValue
@onready var fusion_core_value: Label = %FusionCoreValue

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------

func _ready() -> void:
	if GameManager:
		GameManager.money_updated.connect(_on_money_updated)
		GameManager.fusion_cores_updated.connect(_on_fusion_cores_updated)
		GameManager.energy_updated.connect(_on_energy_updated)
		GameManager.stability_updated.connect(_on_stability_updated)
	else:
		printerr("GameUI: GameManager not found!")

	if RunManager:
		RunManager.run_stats_updated.connect(_on_run_stats_updated)
		RunManager.run_time_sec_updated.connect(_on_run_time_sec_updated)
	else:
		printerr("GameUI: RunManager not found!")

	# Populate UI with initial values on load
	call_deferred("_update_all_ui") # Use call_deferred ensure managers are ready


#-----------------------------------------------------------------------------
# Signal Handlers
#-----------------------------------------------------------------------------

func _on_money_updated(new_money: int) -> void:
	if money_value:
		money_value.text = "%d" % new_money # Format as integer

func _on_fusion_cores_updated(new_cores: int) -> void:
	if fusion_core_value:
		fusion_core_value.text = str(new_cores)

func _on_energy_updated(current: float, max_val: float) -> void:
	if energy_meter:
		energy_meter.max_value = max_val
		energy_meter.value = current
		energy_meter.tooltip_text = "Energy: %d / %d eV" % [int(current), int(max_val)]
		(energy_meter.get_child(0) as Label).text = "Energy: %d / %d eV" % [int(current), int(max_val)]

func _on_stability_updated(current: float, max_val: float) -> void:
	if durability_meter:
		durability_meter.max_value = max_val
		durability_meter.value = current
		durability_meter.tooltip_text = "Durability: %d / %d" % [int(current), int(max_val)]
		(durability_meter.get_child(0) as Label).text = "Durability: %d / %d" % [int(current), int(max_val)]


func _on_run_stats_updated(run_stats: RunStats) -> void:	
	if total_collisions_value:
		total_collisions_value.text = str(run_stats.get_total_collisions())

	if max_combo_value:
		max_combo_value.text = "x %.1f" % run_stats.max_fusion_combo

func _on_run_time_sec_updated(run_time : float) -> void:
	if run_time_value:
		run_time_value.text = _format_time(run_time as float)

#-----------------------------------------------------------------------------
# Helper Functions
#-----------------------------------------------------------------------------

## Updates all UI elements with current manager values. Useful for initialization.
func _update_all_ui() -> void:
	if GameManager:
		_on_money_updated(GameManager.get_money())
		_on_fusion_cores_updated(GameManager.get_fusion_cores())
		_on_energy_updated(GameManager.get_current_energy(), GameManager.get_max_energy())
		_on_stability_updated(GameManager.get_current_stability(), GameManager.get_max_stability())
	if RunManager:
		_on_run_stats_updated(RunManager.get_run_stats())


## Formats total seconds into a string like "Xm Ys".
func _format_time(total_seconds: float) -> String:
	var minutes: int = int(total_seconds / 60)
	var seconds: int = int(total_seconds) % 60
	# Format with leading zero for seconds
	return "%dm %02ds" % [minutes, seconds]

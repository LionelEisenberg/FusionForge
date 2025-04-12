extends Panel

signal dismissed()

@onready var run_time_value: Label = %RunTimeValue
@onready var wall_collisions_value: Label = %WallCollisionsValue
@onready var elements_collisions_value: Label = %ElementCollisionsValue
@onready var max_fusion_combo_value: Label = %MaxFusionComboValue
@onready var heaviest_element_mass_value: Label = %HeaviestElementMassValue
@onready var money_earned_value: Label = %MoneyEarnedValue
@onready var continue_button: Button = %ContinueButton

func _ready() -> void:
	#visible = false

	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)
	else:
		printerr("RunResultsPopup: ContinueButton node not found!")


func show_results(run_stats: RunStats, money_earned: int) -> void:
	run_time_value.text = _format_time(run_stats.run_time)
	wall_collisions_value.text = str(run_stats.collision_counts.x)
	elements_collisions_value.text = str(run_stats.collision_counts.y)
	max_fusion_combo_value.text = "x %.1f" % ((run_stats.max_fusion_combo) as float)

	money_earned_value.text = "$ %d" % money_earned
	
	call_deferred("_center_popup")


func _on_continue_button_pressed() -> void:
	visible = false
	dismissed.emit()

## Centers the popup within its viewport AFTER its size has been calculated.
func _center_popup() -> void:
	# Ensure size is calculated after potential text changes
	await get_tree().process_frame # Wait one frame for layout updates
	
	var viewport_size: Vector2 = get_viewport_rect().size
	# Use global_position if the parent (RunScene) might not be at (0,0) relative to viewport
	# But assuming RunScene is at viewport origin, setting local position is fine.
	position = (viewport_size - size) / 2.0
	
	# --- Make Popup Visible ---
	visible = true


## Formats total seconds into a string like "Xm Ys".
func _format_time(total_seconds: float) -> String:
	var minutes: int = int(total_seconds / 60)
	var seconds: int = int(total_seconds) % 60
	# Format with leading zero for seconds if needed (e.g., 1m 05s)
	return "%dm %02ds" % [minutes, seconds]

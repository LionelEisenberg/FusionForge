extends MarginContainer

#-----------------------------------------------------------------------------
# Node References
#-----------------------------------------------------------------------------
## Reference to the TextureProgressBar used for the timer visual.
@onready var combo_timer_bar: TextureProgressBar = %ComboTimerBar
## Reference to the Label displaying the combo multiplier text.
@onready var combo_label: Label = %ComboLabel

#-----------------------------------------------------------------------------
# Variables
#-----------------------------------------------------------------------------
var _current_multiplier: float = 1.0
# Optional: Tween for animation
var _tween: Tween

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------

func _ready() -> void:
	# Validate node references
	if not combo_timer_bar: printerr("ComboDisplay: %ComboTimerBar node not found!")
	if not combo_label: printerr("ComboDisplay: %ComboLabel node not found!")

	# Connect to RunManager signal if available
	if RunManager:
		RunManager.fusion_combo_updated.connect(_on_run_manager_combo_updated)
		var initial_combo = RunManager._current_fusion_combo_multiplier if RunManager else 1.0
		_on_run_manager_combo_updated(initial_combo)
		_update_timer_visual() # Update timer visual initially
	else:
		printerr("ComboDisplay: RunManager not found!")
		visible = false

	# Ensure initial visibility is set correctly
	visible = _current_multiplier > 1.0


func _process(_delta: float) -> void:
	if visible:
		_update_timer_visual()


#-----------------------------------------------------------------------------
# Internal Methods & Signal Handlers
#-----------------------------------------------------------------------------

## Updates the visual representation of the combo timer bar.
func _update_timer_visual() -> void:
	if not combo_timer_bar or not RunManager: return

	if RunManager.is_combo_timer_active():
		var time_left = RunManager.get_combo_timer_time_left()
		var wait_time = RunManager.get_combo_timer_wait_time()

		if wait_time > 0: # Avoid division by zero
			var progress = clampf(time_left / wait_time, 0.0, 1.0) * 100.0
			#print("%.02f, %.02f, %.02f" % time_left, wait_time, progress)
			combo_timer_bar.value = progress
		else:
			combo_timer_bar.value = 0.0 
	else:
		combo_timer_bar.value = 0.0


## Handles updates to the combo multiplier from RunManager.
func _on_run_manager_combo_updated(multiplier: float) -> void:
	if combo_label:
		combo_label.text = "x %.1f" % multiplier

	visible = multiplier > 1.0

	# Optional: Add tween animation for feedback only if visible and increasing
	if visible and multiplier > _current_multiplier:
		_play_combo_increase_anim()

	_current_multiplier = multiplier


## Simple scale animation for the label when combo increases.
func _play_combo_increase_anim() -> void:
	if not combo_label: return

	if _tween and _tween.is_running():
		_tween.kill() # Stop existing animation

	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Target property, final value, duration
	_tween.tween_property(combo_label, "scale", Vector2(1.5, 1.5), 0.1)
	# Chain the return scale animation
	_tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE)

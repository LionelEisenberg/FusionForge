# upgrade_node.gd
class_name UpgradeNode
extends TextureButton

const hover_scale_factor: float = 1.2 # How much to scale up on hover
const hover_tween_duration: float = 0.15 # Duration of scale/shadow animation

@export var upgrade_id: String = ""

@onready var overlay: Panel = %PurchasedOverlay
@onready var level_label: Label = %LevelLabel
@onready var upgrade_completed_border: Panel = %UpgradeCompletedBorder
@onready var upgrade_tooltip: Control = %UpgradeTooltip 

var _upgrade_data: UpgradeData = null
var _current_level: int = 0


var _current_hover_tween: Tween
var _original_scale: Vector2
var _is_mouse_over: bool = false

func _ready() -> void:
	_original_scale = self.scale
	self.pivot_offset = self.size / 2.0
	
	assert(overlay != null, "UpgradeNode requires a child Panel named Overlay.")
	assert(level_label != null, "UpgradeNode requires a child Label named LevelLabel (possibly nested).")
	assert(upgrade_completed_border != null, "UpgradeNode requires a child Panel named 'UpgradeCompletedBorder'.")
	assert(upgrade_tooltip != null, "UpgradeNode requires a child Control named 'UpgradeTooltip'.")
	
	if is_instance_valid(upgrade_tooltip):
		upgrade_tooltip.visible = false

	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# For keyboard/controller accessibility
	focus_entered.connect(_on_mouse_entered) 
	focus_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	_is_mouse_over = true
	_animate_hover_effect(true)

	if is_instance_valid(upgrade_tooltip) and is_instance_valid(_upgrade_data):
		var costs = UpgradeManager.get_upgrade_costs(_upgrade_data.id)
		
		var tooltip_data = {
			"name": _upgrade_data.display_name, # Assuming UpgradeData has display_name
			"current_level": _current_level,
			"max_level": _upgrade_data.max_purchase_level,
			"description": _upgrade_data.description, # Assuming UpgradeData has description
			"effect_string": _upgrade_data.effect_string, # Effect of the next level (or current if maxed)
			"money_cost": costs.x,
			"fc_cost": costs.y,
		}
		# Ensure the tooltip script has an update_content method
		if upgrade_tooltip.has_method("update_content"):
			upgrade_tooltip.update_content(tooltip_data)
		else:
			push_warning("UpgradeTooltip on '%s' does not have 'update_content' method." % name)
			
		# Ensure the tooltip script has a show_animated method
		if upgrade_tooltip.has_method("show_animated"):
			upgrade_tooltip.show_animated()
		else:
			push_warning("UpgradeTooltip on '%s' does not have 'show_animated' method." % name)
			upgrade_tooltip.visible = true # Fallback to just making it visible


func _on_mouse_exited() -> void:
	_is_mouse_over = false
	_animate_hover_effect(false) # Animate the node itself

	if is_instance_valid(upgrade_tooltip):
		# Ensure the tooltip script has a hide_animated method
		if upgrade_tooltip.has_method("hide_animated"):
			upgrade_tooltip.hide_animated()
		else:
			push_warning("UpgradeTooltip on '%s' does not have 'hide_animated' method." % name)
			upgrade_tooltip.visible = false # Fallback to just making it invisible


func _animate_hover_effect(is_hovering: bool) -> void:
	if is_instance_valid(_current_hover_tween):
		_current_hover_tween.kill() # Stop any previous animation

	_current_hover_tween = create_tween()
	_current_hover_tween.set_parallel(true) # Scale and shadow animate together
	_current_hover_tween.set_trans(Tween.TRANS_SINE) # Smooth transition
	_current_hover_tween.set_ease(Tween.EASE_OUT if is_hovering else Tween.EASE_IN)

	# --- Scale Animation ---
	var target_scale = _original_scale * hover_scale_factor if is_hovering else _original_scale
	_current_hover_tween.tween_property(self, "scale", target_scale, hover_tween_duration)

func update_display(data: UpgradeData, current_level: int, can_afford: bool) -> void:
	_upgrade_data = data
	_current_level = current_level
	if _upgrade_data == null:
		printerr("UpgradeNode: update_display called with null data for id: ", upgrade_id)
		visible = false
		return

	visible = true

	# --- Update Visuals ---
	var icon_path = "res://assets/icons/upgrades/%s.svg" % upgrade_id # Placeholder convention
	if ResourceLoader.exists(icon_path):
		texture_normal = ResourceLoader.load(icon_path)
	else:
		printerr("UpgradeNode: Icon not found for %s at %s" % [upgrade_id, icon_path])
		icon_path = "res://icon.svg"

	level_label.text = "%d / %d" % [_current_level, _upgrade_data.max_purchase_level]
	if data.max_purchase_level == 1:
		level_label.visible = false

	# --- Update State ---
	overlay.visible = (_current_level == 0)
	upgrade_completed_border.visible = (_current_level == _upgrade_data.max_purchase_level)

func _on_pressed() -> void:
	if UpgradeManager:
		UpgradeManager.purchase_upgrade(upgrade_id)
	else:
		printerr("UpgradeNode: UpgradeManager not found! Cannot purchase.")

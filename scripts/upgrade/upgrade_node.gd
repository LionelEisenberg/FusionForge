# upgrade_node.gd
class_name UpgradeNode
extends TextureButton

@export var upgrade_id: String = ""

@onready var overlay: Panel = %PurchasedOverlay
@onready var level_label: Label = %LevelLabel
@onready var upgrade_completed_border: Panel = %UpgradeCompletedBorder

var _upgrade_data: UpgradeData = null

func _ready() -> void:
	assert(overlay != null, "UpgradeNode requires a child Panel named Overlay.")
	assert(level_label != null, "UpgradeNode requires a child Label named LevelLabel (possibly nested).")

	pressed.connect(_on_pressed)


func update_display(data: UpgradeData, purchased_level: int, money_cost: int, fusion_core_cost: int, can_afford: bool) -> void:
	_upgrade_data = data
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

	level_label.text = "%d / %d" % [purchased_level, data.max_purchase_level]
	if data.max_purchase_level == 1:
		level_label.visible = false

	# --- Update State ---
	overlay.visible = (purchased_level == 0)
	upgrade_completed_border.visible = (purchased_level == data.max_purchase_level)

	# --- Update Tooltip ---
	tooltip_text = _create_tooltip_text(data, purchased_level, money_cost, fusion_core_cost, can_afford)

func _create_tooltip_text(data: UpgradeData, purchased_level: int, money_cost: int, fusion_core_cost: int, can_afford: bool) -> String:
	var tooltip_lines: Array[String] = []

	# Name and Level
	tooltip_lines.append("%s (Level %d / %d)" % [data.display_name, purchased_level, data.max_purchase_level])
	# Static Description from UpgradeData
	tooltip_lines.append(data.description)
	tooltip_lines.append("") # Spacer

	if purchased_level < data.max_purchase_level:
		var cost_string_parts = []
		if money_cost > 0:
			cost_string_parts.append("%d $" % int(ceil(money_cost)))
		if fusion_core_cost > 0:
			cost_string_parts.append("%d FC" % fusion_core_cost)
		
		if cost_string_parts.is_empty(): # Should not happen if purchasable unless cost is 0 for both
			tooltip_lines.append("Cost: Free")
		else:
			tooltip_lines.append("Cost: " + " and ".join(cost_string_parts))

	# Removed dynamic effect description lines

	return "\n".join(tooltip_lines)


func _on_pressed() -> void:
	if UpgradeManager:
		UpgradeManager.purchase_upgrade(upgrade_id)
	else:
		printerr("UpgradeNode: UpgradeManager not found! Cannot purchase.")

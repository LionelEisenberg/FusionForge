extends Panel

signal start_run_requested

@onready var money_value_label: Label = %MoneyValue
@onready var fusion_core_value_label: Label = %FusionCoreValue
@onready var button : Button = %StartRunButton

func _ready() -> void:
	if GameManager:
		GameManager.money_updated.connect(_on_money_updated)
		GameManager.fusion_cores_updated.connect(_on_fusion_cores_updated)
		# Set initial values
		_on_money_updated(GameManager.get_money())
		_on_fusion_cores_updated(GameManager.get_fusion_cores())
	else:
		printerr("UpgradeView: GameManager not found! Cannot display resources.")
		money_value_label.text = "N/A"
		fusion_core_value_label.text = "N/A"
	button.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void: 
	start_run_requested.emit()

## Updates the money display label.
func _on_money_updated(new_money: int) -> void:
	if money_value_label:
		# Format the number if desired (e.g., with commas)
		money_value_label.text = "%d" % new_money # Simple integer format

## Updates the fusion core display label.
func _on_fusion_cores_updated(new_cores: int, _diff = 0) -> void:
	if fusion_core_value_label:
		fusion_core_value_label.text = "%d" % new_cores

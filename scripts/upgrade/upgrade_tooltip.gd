# UpgradeTooltip.gd
extends Control

# --- Node Path References (using Unique Name Access - %NodeName) ---
# Textual Information
@onready var title_label: RichTextLabel = %TitleLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var effect_container: PanelContainer = %EffectContainer
@onready var effect_label: RichTextLabel = %EffectLabel

# Cost Boxes & Components
@onready var money_cost_container: Control = %MoneyCost 
@onready var money_icon: TextureRect = %MoneyIcon
@onready var money_value_label: RichTextLabel = %MoneyValue

@onready var fusion_core_cost_container: Control = %FusionCoreCost
@onready var fusion_core_icon: TextureRect = %FusionCoreIcon
@onready var fusion_core_value_label: RichTextLabel = %FusionCoreValue

# TextEffectImporter
@onready var text_effect_importer: Node = %TextEffectImporter
# --- End Node Path References ---

var _current_animation_tween: Tween
var _latest_data: Dictionary

# StyleBoxes for cost display (create these as .tres resources in the Godot Editor)
@export var stylebox_affordable: StyleBoxFlat # Green and shiny style
@export var stylebox_unaffordable: StyleBoxFlat # Red and grayed out style

# Animation properties
@export var animation_duration: float = 0.15
@export var initial_scale_for_bloom: Vector2 = Vector2(1.0, 0.2)

func _ready() -> void:
	scale = initial_scale_for_bloom 
	visible = false
	call_deferred("_update_pivot_for_bloom")
	
	if GameManager:
		GameManager.money_updated.connect(_on_money_changed)
		GameManager.fusion_cores_updated.connect(_on_fusion_cores_updated)
	
	for rich_text_label in [title_label, description_label, effect_label, money_value_label, fusion_core_value_label]:
		rich_text_label.custom_effects = text_effect_importer.get_text_effect_instances()
		rich_text_label.bbcode_enabled = true

# Call this from UpgradeNode.gd to populate and style the tooltip
func update_content(data: Dictionary) -> void:
	_latest_data = data
	# Update Text Labels
	var upgrade_name = data.get("name", "N/A")
	var current_lvl = data.get("current_level", 0)
	var max_lvl = data.get("max_level", 0)
	var lvl_text = "(%s/%s)" % [current_lvl, max_lvl]
	
	if is_instance_valid(title_label):
		if current_lvl == max_lvl:
			title_label.text = "%s [jit][color=lightgreen]%s[/color][/jit]" % [upgrade_name, lvl_text] # Combined name and level
		else:
			title_label.text = "%s %s" % [upgrade_name, lvl_text] # Combined name and level
	
	if is_instance_valid(description_label): description_label.text = data.get("description", "")
	if is_instance_valid(effect_label):
		var effect_text = data.get("effect_string", "")
		if effect_text != "":
			effect_container.visible = true
			effect_label.text = "[color=green]%s[/color]" % [effect_text]
		else: effect_container.visible = false
	
	var money_cost_val = data.get("money_cost", 0)
	var fc_cost_val = data.get("fc_cost", 0)
	_update_money_cost_container(money_cost_val)
	_update_fusion_cost_container(fc_cost_val)
	
	call_deferred("_update_pivot_for_bloom")

func _on_money_changed(_current_money: int) -> void:
	update_content(_latest_data)
	
func _on_fusion_cores_updated(_current_fusion_core: int) -> void:
	update_content(_latest_data)

func _update_money_cost_container(money_cost_val: int) -> void:
	# Update Money Cost Display
	if is_instance_valid(money_cost_container):
		if money_cost_val > 0:
			money_cost_container.modulate.a = 1.0
			if is_instance_valid(money_value_label): money_value_label.text = str(money_cost_val)
			
			var can_afford = GameManager.can_spend_money(money_cost_val)
			_style_cost_box(money_cost_container, money_icon, money_value_label, can_afford)
		else:
			money_cost_container.modulate.a = 0.0

func _update_fusion_cost_container(fc_cost_val: int) -> void:
	# Update Fusion Core Cost Display
	if is_instance_valid(fusion_core_cost_container):
		if fc_cost_val > 0:
			fusion_core_cost_container.modulate.a = 1.0
			if is_instance_valid(fusion_core_value_label): fusion_core_value_label.text = str(fc_cost_val)

			var can_afford = GameManager.can_spend_fusion_cores(fc_cost_val)
			_style_cost_box(fusion_core_cost_container, fusion_core_icon, fusion_core_value_label, can_afford)
		else:
			fusion_core_cost_container.modulate.a = 0.0

func _update_pivot_for_bloom() -> void:
	pivot_offset = Vector2(size.x / 2.0, size.y) # Blooms upwards from bottom-center
	# For center bloom: pivot_offset = size / 2.0

func _style_cost_box(cost_box_node: Control, icon_node: TextureRect, label_node: RichTextLabel, can_afford: bool) -> void:
	if not is_instance_valid(cost_box_node): return

	if can_afford:
		if is_instance_valid(stylebox_affordable): cost_box_node.add_theme_stylebox_override("panel", stylebox_affordable)
		if is_instance_valid(icon_node): icon_node.modulate = Color.WHITE 
		if is_instance_valid(label_node): label_node.modulate = Color.WHITE
	else:
		if is_instance_valid(stylebox_unaffordable): cost_box_node.add_theme_stylebox_override("panel", stylebox_unaffordable)
		if is_instance_valid(icon_node): icon_node.modulate = Color(0.6, 0.6, 0.6) 
		if is_instance_valid(label_node): label_node.modulate = Color(0.7, 0.7, 0.7)

func show_animated() -> void:
	if is_instance_valid(_current_animation_tween):
		_current_animation_tween.kill()

	_update_pivot_for_bloom()

	visible = true
	scale = initial_scale_for_bloom 

	_current_animation_tween = create_tween()
	_current_animation_tween.set_parallel(true) 
	_current_animation_tween.set_trans(Tween.TRANS_BACK) 
	_current_animation_tween.set_ease(Tween.EASE_OUT) 

	_current_animation_tween.tween_property(self, "scale", Vector2.ONE, animation_duration)
	_current_animation_tween.tween_property(self, "modulate:a", 1.0, animation_duration)
	_current_animation_tween.play()

func hide_animated() -> void:
	if is_instance_valid(_current_animation_tween):
		_current_animation_tween.kill()

	_current_animation_tween = create_tween()
	_current_animation_tween.set_parallel(true)
	_current_animation_tween.set_trans(Tween.TRANS_SINE) 
	_current_animation_tween.set_ease(Tween.EASE_IN) 

	_current_animation_tween.tween_property(self, "scale", initial_scale_for_bloom, animation_duration)
	_current_animation_tween.tween_property(self, "modulate:a", 0.0, animation_duration)
	
	_current_animation_tween.tween_callback(func(): self.visible = false)
	_current_animation_tween.play()

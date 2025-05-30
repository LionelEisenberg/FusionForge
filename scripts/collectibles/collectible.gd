class_name Collectible
extends Area2D

#-----------------------------------------------------------------------------
# Exports (Non-Upgradeable Physics/Visual Parameters)
#-----------------------------------------------------------------------------
@export var scaling_factor: float = 1.0

@export_category("Movement")
@export var initial_speed: float = 150.0
@export var initial_deceleration: float = 300.0
@export var attraction_deceleration: float = 600.0
@export var attraction_acceleration = 1200.0
@export var max_scale_age: float = 2.0 # e.g., effect ramps up over 2 seconds
@export var age_scaling_factor: float = 1.5 # e.g., 150% increase = 2.5x strength at max age


@export_category("Despawn")
@export var lifespan: float = 1.5
@export var attraction_radius: float = 80.0
## At what percentage of lifespan lived should blinking start (e.g., 0.6 means blinking starts when 60% of life is used, so last 40% of life).
@export var blink_start_ratio: float = 0.6
## The minimum alpha value during a blink (e.g., 0.2 for mostly transparent).
@export var blink_min_alpha: float = 0.1
## The maximum alpha value during a blink (e.g., 1.0 for fully visible).
@export var blink_max_alpha: float = 1.0
#-----------------------------------------------------------------------------
# Variables
#-----------------------------------------------------------------------------
# Internal velocity for movement calculation
var _velocity: Vector2 = Vector2.ZERO
var _is_attracted: bool = false
var _time_attracted: float = 0.0
var _lifespan_timer: Timer = null

# Internal Despawn Settings
var _is_blinking_phase_active: bool = false # True if we are in the time window where blinking should occur.
var _current_despawn_blink_tween: Tween

#-----------------------------------------------------------------------------
# Node References
#-----------------------------------------------------------------------------
@onready var sprite: Sprite2D = %Sprite
@onready var attraction_area: Area2D = %AttractionArea
@onready var attraction_shape: CollisionShape2D = %AttractionArea/AttractionShape

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------

func _ready() -> void:
	
	
	# Ensure the sprite node exists
	if sprite == null:
		printerr("Collectible: %Sprite node not found!")

	mouse_entered.connect(_on_mouse_entered_pickup_area)
	attraction_area.mouse_entered.connect(_on_mouse_entered_attraction_area)
	
	self.scale *= scaling_factor


func _physics_process(delta: float) -> void:	
	# Apply attraction force if mouse is in the outer radius
	if _is_attracted:
		_time_attracted += delta
		if _time_attracted >= max_scale_age:
			_on_mouse_entered_pickup_area()
		var age_t = clampf(_time_attracted / max_scale_age, 0.0, 1.0) # Normalized age (0 to 1)
		var current_scale = 1.0 + (age_t * age_scaling_factor)
		
		var acceleration_vec: Vector2 = Vector2.ZERO
		var mouse_pos = get_viewport().get_mouse_position()
		var direction_to_mouse = (mouse_pos - global_position).normalized()
		acceleration_vec = direction_to_mouse * (attraction_acceleration * current_scale)
		_velocity += acceleration_vec * delta
		_velocity = _velocity.move_toward(Vector2.ZERO, attraction_deceleration * current_scale * delta)
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, initial_deceleration * delta)

	# Apply final movement based on the calculated velocity
	global_position += _velocity * delta

#-----------------------------------------------------------------------------
# Despawn Logic
#-----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var time_lived = _lifespan_timer.wait_time - _lifespan_timer.time_left
	
	if not is_instance_valid(sprite):
		return

	# Determine if we should be in the blinking phase
	var blink_trigger_time: float = lifespan * blink_start_ratio
	var should_be_blinking_now: bool = time_lived >= blink_trigger_time

	if should_be_blinking_now:
		_is_blinking_phase_active = true
		if not is_instance_valid(_current_despawn_blink_tween) or not _current_despawn_blink_tween.is_running():
			_start_or_update_despawn_blink_animation()

func _start_or_update_despawn_blink_animation() -> void:
	if not is_instance_valid(sprite): return

	if is_instance_valid(_current_despawn_blink_tween):
		_current_despawn_blink_tween.kill() 

	_current_despawn_blink_tween = create_tween()
	
	# Calculate blink cycle duration: make it shorter as remaining_lifespan decreases.
	# Example: A full blink cycle (fade out + fade in) takes 30% of the remaining life,
	# clamped between a minimum of 0.08s (very fast) and a maximum of 0.5s (slower initial blink).
	# Adjust these values (0.30, 0.08, 0.5) to get the desired visual pacing.
	var time_lived = _lifespan_timer.wait_time - _lifespan_timer.time_left
	var remaining_lifespan_for_vfx: float = max(0.01, lifespan - time_lived)
	var blink_cycle_duration: float = clampf(remaining_lifespan_for_vfx * 0.60, 0.125, 0.5)
	var half_cycle_duration: float = blink_cycle_duration / 2.0
	
	# Ensure the visual node starts from the "visible" (max alpha) state for a clean animation start
	sprite.self_modulate.a = blink_max_alpha

	# --- Tween Sequence for Alpha Only ---
	# 1. Fade out alpha
	_current_despawn_blink_tween.tween_property(
		sprite, "self_modulate:a", # Target only the alpha component
		blink_min_alpha, 
		half_cycle_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 2. Fade back in alpha
	_current_despawn_blink_tween.tween_property(
		sprite, "self_modulate:a", # Target only the alpha component
		blink_max_alpha, 
		half_cycle_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	_current_despawn_blink_tween.play()

#-----------------------------------------------------------------------------
# Public Setup Method (Called by Spawner)
#-----------------------------------------------------------------------------

func initialize(direction: Vector2) -> void:
	# Apply initial velocity
	_velocity = direction.normalized() * initial_speed
	
	# Apply initial upgrade effects by pulling from UpgradeManager
	if UpgradeManager:
		var initial_effects = UpgradeManager.get_upgrade_effects()
		if initial_effects:
			apply_upgrade_effects(initial_effects)
		else:
			printerr("Collectible (%s): Failed to get initial effects from UpgradeManager cache." % self.name)
	else:
		printerr("Collectible (%s): UpgradeManager not found. Applying default effects." % self.name)

	if is_instance_valid(_lifespan_timer):
		_lifespan_timer.stop()
		_lifespan_timer.queue_free()
		_lifespan_timer = null

	if lifespan >= 0.0: # Use the (potentially upgraded) lifespan variable
		_lifespan_timer = Timer.new()
		_lifespan_timer.wait_time = lifespan
		_lifespan_timer.one_shot = true
		_lifespan_timer.timeout.connect(_on_lifespan_timeout)
		_lifespan_timer.autostart = true
		add_child(_lifespan_timer) # Add timer as child

	add_to_group("collectibles")

#-----------------------------------------------------------------------------
# Upgrade Handling
#-----------------------------------------------------------------------------

## Applies effects data to this node's parameters. Called during initialization.
func apply_upgrade_effects(effects_data: UpgradeEffects) -> void:
	lifespan = lifespan * effects_data.collectible_lifespan_mult

	attraction_radius = attraction_radius * effects_data.collection_radius_mult

	lifespan = max(0.1, lifespan) # Ensure lifespan is positive
	attraction_radius = max(0.0, attraction_radius) # Ensure radius isn't negative

	# Update the actual collision shape radius if the node is ready
	if is_node_ready() and attraction_shape and attraction_shape.shape:
		attraction_shape.shape.radius = attraction_radius
	elif attraction_shape and attraction_shape.shape:
		attraction_shape.shape.radius = attraction_radius

#-----------------------------------------------------------------------------
# Signal Handlers & Pickup Logic
#-----------------------------------------------------------------------------

## Called when the mouse pointer enters the pickup Area's collision shape.
func _on_mouse_entered_pickup_area() -> void:	
	apply_pickup_effect()

	# TODO: Play generic pickup sound/VFX here?

	queue_free()

func _on_mouse_entered_attraction_area() -> void:
	_is_attracted = true
	
	attraction_area.mouse_entered.disconnect(_on_mouse_entered_attraction_area)

## Called by the SceneTreeTimer when the lifespan expires.
func _on_lifespan_timeout() -> void:
	if _is_attracted:
		return
	# TODO: Play fade-out animation/VFX before freeing?
	queue_free() # Destroy the collectible if not picked up in time


#-----------------------------------------------------------------------------
# Virtual Method (to be overridden by inherited scripts)
#-----------------------------------------------------------------------------

## This function defines WHAT happens when the collectible is picked up.
## Inherited scripts (EnergyCollectible, FusionCoreCollectible) MUST override this.
func apply_pickup_effect() -> void:
	# Base implementation does nothing or warns.
	push_warning("apply_pickup_effect() not implemented in inherited script for %s!" % self.name)
	# Alternatively: pass

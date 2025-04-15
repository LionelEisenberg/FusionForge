class_name Collectible
extends Area2D

#-----------------------------------------------------------------------------
# Exports
#-----------------------------------------------------------------------------
@export var lifespan: float = 4.0
@export var initial_speed: float = 150.0
@export var initial_deceleration: float = 300.0
@export var attraction_deceleration: float = 1000.0
@export var attraction_acceleration = 2500.0

#-----------------------------------------------------------------------------
# Variables
#-----------------------------------------------------------------------------
# Internal velocity for movement calculation
var _velocity: Vector2 = Vector2.ZERO
var _is_attracted: bool = false

#-----------------------------------------------------------------------------
# Node References
#-----------------------------------------------------------------------------
@onready var sprite: Sprite2D = %Sprite
@onready var attraction_area: Area2D = %AttractionArea

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------

func _ready() -> void:
	# Ensure the sprite node exists
	if sprite == null:
		printerr("Collectible: %Sprite node not found!")

	mouse_entered.connect(_on_mouse_entered_pickup_area)
	attraction_area.mouse_entered.connect(_on_mouse_entered_attraction_area)

	get_tree().create_timer(lifespan).timeout.connect(_on_lifespan_timeout)


func _physics_process(delta: float) -> void:
	# Apply attraction force if mouse is in the outer radius
	if _is_attracted:
		var acceleration: Vector2 = Vector2.ZERO
		var mouse_pos = get_viewport().get_mouse_position()
		var direction_to_mouse = (mouse_pos - global_position).normalized()
		acceleration = direction_to_mouse * attraction_acceleration
		_velocity += acceleration * delta
		_velocity = _velocity.move_toward(Vector2.ZERO, attraction_deceleration * delta)
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, initial_deceleration * delta)

	# Apply final movement based on the calculated velocity
	global_position += _velocity * delta



#-----------------------------------------------------------------------------
# Public Setup Method (Called by Spawner)
#-----------------------------------------------------------------------------

## Initializes the collectible's starting state.
func setup(direction: Vector2) -> void:
	_velocity = direction.normalized() * initial_speed


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

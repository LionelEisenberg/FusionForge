class_name Collectible
extends Area2D

#-----------------------------------------------------------------------------
# Exports
#-----------------------------------------------------------------------------
@export var lifespan: float = 4.0
@export var initial_speed: float = 150.0
@export var deceleration: float = 300.0

#-----------------------------------------------------------------------------
# Variables
#-----------------------------------------------------------------------------
# Internal velocity for movement calculation
var _velocity: Vector2 = Vector2.ZERO

#-----------------------------------------------------------------------------
# Node References
#-----------------------------------------------------------------------------
@onready var sprite: Sprite2D = %Sprite2D

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------

func _ready() -> void:
	# Ensure the sprite node exists
	if sprite == null:
		printerr("Collectible: %Sprite node not found!")

	mouse_entered.connect(_on_mouse_entered)

	get_tree().create_timer(lifespan).timeout.connect(_on_lifespan_timeout)


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta

	if _velocity != Vector2.ZERO:
		_velocity = _velocity.move_toward(Vector2.ZERO, deceleration * delta)


#-----------------------------------------------------------------------------
# Public Setup Method (Called by Spawner)
#-----------------------------------------------------------------------------

## Initializes the collectible's starting state.
func setup(direction: Vector2) -> void:
	_velocity = direction.normalized() * initial_speed


#-----------------------------------------------------------------------------
# Signal Handlers & Pickup Logic
#-----------------------------------------------------------------------------

## Called when the mouse pointer enters the Area2D's collision shape.
func _on_mouse_entered() -> void:	
	apply_pickup_effect()

	# TODO: Play generic pickup sound/VFX here?

	queue_free()


## Called by the SceneTreeTimer when the lifespan expires.
func _on_lifespan_timeout() -> void:
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

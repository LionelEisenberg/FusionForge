# Base script for all elements in the reactor.
# Attached to BaseElement.tscn (Root: RigidBody2D).
# Handles physics, collision detection reporting, initialization,
# and holds common properties. Inherited by specific element scenes.
class_name Element
extends RigidBody2D

#-----------------------------------------------------------------------------
# Signals
#-----------------------------------------------------------------------------

signal pair_collided(element_a: Element, element_b: Element)

signal hit_wall(element: Element)

#-----------------------------------------------------------------------------
# Exports (Properties configurable per element type in inherited scenes)
#-----------------------------------------------------------------------------

@export var element_type: String = "Hydrogen"
@export var element_symbol: String = "H"
@export var element_mass_amu: float = 1.0 : set = set_element_mass_amu
@export var element_base_color: Color = Color.CYAN
@export var element_size: float = 32.0
@export var override_velocity: Vector2 = Vector2(0, 0)

#-----------------------------------------------------------------------------
# Node References (Using Scene Unique Names)
#-----------------------------------------------------------------------------

@onready var _sprite : Sprite2D = %Sprite2D
@onready var _collision_shape : CollisionShape2D = %CollisionShape2D

#-----------------------------------------------------------------------------
# Constants
#-----------------------------------------------------------------------------

# Arbitrary conversion factor to relate AMU to Godot's physics mass.
# Adjust this value based on desired physics feel.
const MASS_UNIT_CONVERSION: float = 1.0
const ZERO_VELOCITY_THRESHOLD_SQ: float = 0.01

#-----------------------------------------------------------------------------
# Godot Lifecycle Functions
#-----------------------------------------------------------------------------

func _ready() -> void:	
	# Ensure physics properties are set correctly based on exports
	if not contact_monitor:
		printerr("Element %s: Contact Monitor is not enabled!" % element_type)
	if max_contacts_reported <= 0:
		printerr("Element %s: Max Contacts Reported is not > 0!" % element_type)

	# Set physics mass based on AMU
	set_element_mass_amu(element_mass_amu)

	# Update visuals based on initial properties
	_update_visuals()

	# Connect the collision signal
	body_entered.connect(_on_body_entered)
	
	# Connect the CollisionManager signals
	if CollisionManager:
		pair_collided.connect(CollisionManager._on_element_pair_collided)
		hit_wall.connect(CollisionManager._on_element_hit_wall)
	
	#Override Logic
	if (override_velocity != Vector2(0, 0)):
		linear_velocity = override_velocity
	
	modulate = element_base_color


#-----------------------------------------------------------------------------
# Initialization
#-----------------------------------------------------------------------------

## Initializes the element's state. Called by the ElementSpawner.
func initialize(start_position: Vector2, initial_velocity: Vector2) -> void:
	global_position = start_position
	linear_velocity = initial_velocity
	
	add_to_group("elements")
	
	# Ensure visuals are up-to-date if properties were changed before ready
	if is_node_ready():
		_update_visuals()

#-----------------------------------------------------------------------------
# Public functions
#-----------------------------------------------------------------------------

func get_momentum() -> float:
	return mass * linear_velocity.length()

#-----------------------------------------------------------------------------
# Property Setters (for updating physics properties when exports change)
#-----------------------------------------------------------------------------

func set_element_mass_amu(value: float) -> void:
	element_mass_amu = value
	# Update the actual physics mass when AMU changes
	mass = max(0.1, element_mass_amu * MASS_UNIT_CONVERSION) # Ensure mass is never zero

#-----------------------------------------------------------------------------
# Collision Handling (Following the chosen strategy)
#-----------------------------------------------------------------------------

func _on_body_entered(body: Node) -> void:
	# --- Wall Collision ---
	if body.is_in_group("walls"):
		hit_wall.emit(self)

	# --- Element Collision ---
	elif body.is_in_group("elements"):
		# --- Double Detection Prevention ---
		if self.get_instance_id() < body.get_instance_id():
			var element_b := body as Element # Cast to Element type
			if element_b:
				# Emit signal for managers (RunManager/FusionHandler) to check interaction
				pair_collided.emit(self, element_b)
			else:
				printerr("Collision body in 'elements' group was not an Element script?")

#-----------------------------------------------------------------------------
# Internal Helper Functions
#-----------------------------------------------------------------------------

func _apply_element_size() -> void:
	if _sprite and _sprite.texture:
		var texture_size: Vector2 = _sprite.texture.get_size()
		if texture_size.x > 0 and texture_size.y > 0: # Avoid division by zero
			_sprite.scale = Vector2(element_size, element_size) / texture_size
	
	if _collision_shape and _collision_shape.shape:
		var shape : CircleShape2D = _collision_shape.shape
		shape.radius = element_size / 2.0

func _update_visuals() -> void:
	_apply_element_size()

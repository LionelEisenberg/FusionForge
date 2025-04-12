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
@export var element_mass_amu: float = 1.008 : set = set_element_mass_amu
@export var element_base_color: Color = Color.CYAN
@export var override_velocity: Vector2 = Vector2(0, 0)

#-----------------------------------------------------------------------------
# Constants
#-----------------------------------------------------------------------------

# Arbitrary conversion factor to relate AMU to Godot's physics mass.
# Adjust this value based on desired physics feel.
const MASS_UNIT_CONVERSION: float = 10.0
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

func _physics_process(_delta: float) -> void:
	var current_acceleration_factor: float = 1.0 # Get this from GameManager/RunManager/UpgradeManager
	var base_acceleration_magnitude: float = 500.0 # Base value, maybe also from config/manager

	var acceleration_force_magnitude: float = base_acceleration_magnitude * current_acceleration_factor

	# --- Calculate Direction based on Current Velocity ---
	var current_direction: Vector2 = Vector2.ZERO
	
	# Check if velocity is significant enough to have a direction
	if linear_velocity.length_squared() > ZERO_VELOCITY_THRESHOLD_SQ:
		current_direction = linear_velocity.normalized()
	# else: If velocity is near zero, apply no acceleration force this frame.
	#      Alternatively, could apply force towards center or outwards here if desired.

	# --- Apply Force ---
	if current_direction != Vector2.ZERO:
		# Apply force in the current direction of movement
		var force: Vector2 = current_direction * acceleration_force_magnitude
		apply_central_force(force)
		# Note: We apply force, not directly add to velocity, to work with the physics engine.
		# The magnitude represents the force strength. F=ma is handled by the engine.


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
		print(element_type, " hit wall")

	# --- Element Collision ---
	elif body.is_in_group("elements"):
		# --- Double Detection Prevention ---
		if self.get_instance_id() < body.get_instance_id():
			var element_b := body as Element # Cast to Element type
			if element_b:
				# Emit signal for managers (RunManager/FusionHandler) to check interaction
				pair_collided.emit(self, element_b)
				print(element_type, " collided with ", element_b.element_type, " - signaling")
			else:
				printerr("Collision body in 'elements' group was not an Element script?")

#-----------------------------------------------------------------------------
# Internal Helper Functions
#-----------------------------------------------------------------------------

func _update_visuals() -> void:
	pass

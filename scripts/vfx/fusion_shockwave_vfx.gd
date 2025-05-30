# FusionHaloWaveVFX.gd
extends Node2D

@onready var particles: GPUParticles2D = %GPUParticles2D

# Default values, can be overridden by init()
var base_initial_velocity: float = 300.0
var base_lifetime: float = 0.8
var base_scale: float = 1.0

func _ready() -> void:
	# Ensure particles are ready but not emitting until play() is called
	if not is_instance_valid(particles):
		push_error("FusionHaloWaveVFX: GPUParticles2D node 'HaloParticles' not found!")
		queue_free() # Can't function without particles
		return
	particles.emitting = false
	
	position = Vector2(600, 600)
	print("HI")
	play()

# Call this from VFXManager after instancing the scene
func init_effect(intensity_factor: float = 1.0) -> void:
	if not is_instance_valid(particles): return

	# Scale effect parameters based on intensity_factor (0.0 to 1.0+)
	# Adjust these multipliers and properties as needed.
	var mat = particles.process_material as ParticleProcessMaterial
	if mat:
		mat.initial_velocity_min = base_initial_velocity * lerpf(0.8, 1.5, intensity_factor) # Example scaling
		mat.initial_velocity_max = mat.initial_velocity_min 
	
	particles.lifetime = base_lifetime * lerpf(0.7, 1.3, intensity_factor)
	particles.speed_scale = lerpf(0.9, 1.2, intensity_factor) # Overall speed adjustment
	
	# You could also scale the particle amount if desired, but do it before 'emitting'
	# particles.amount = int(base_particle_amount * lerpf(0.5, 1.5, intensity_factor))
	
	# Scale the entire node for a larger or smaller overall effect
	self.scale = Vector2.ONE * lerpf(0.8, 1.5, intensity_factor)


func play() -> void:
	if not is_instance_valid(particles): return
	
	particles.restart() # Resets particle simulation time and emits
	particles.emitting = true
	
	# Self-destruct after particles are likely done
	# Create a timer that waits for slightly longer than the particle lifetime + processing
	#var self_destruct_delay = particles.lifetime + particles.preprocess + 0.5 # Add a small buffer
	#var timer = get_tree().create_timer(self_destruct_delay)
	#timer.timeout.connect(queue_free)
	

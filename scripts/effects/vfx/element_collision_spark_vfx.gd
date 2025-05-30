# ElementCollisionSparkVFX.gd
extends Node2D

@onready var particles: GPUParticles2D = $GPUParticles2D # Make sure your child node is named "GPUParticles2D"

func _ready() -> void:
	if not is_instance_valid(particles):
		push_error("ElementCollisionSparkVFX: GPUParticles2D node not found!")
		queue_free()
		return

	particles.emitting = false # Ensure it doesn't emit on its own initially

# Call this from VFXManager to start the effect
func play() -> void:
	if not is_instance_valid(particles): return

	particles.restart() # This also sets emitting = true for one-shot particles

	# Self-destruct after the particles have finished
	# Wait for lifetime + a small buffer.
	# If lifetime_randomness is high, you might need a more robust check or longer buffer.
	var max_lifetime = particles.lifetime * (1.0 + (particles.process_material as ParticleProcessMaterial).lifetime_randomness if particles.process_material is ParticleProcessMaterial else 1.0)
	var self_destruct_delay = max_lifetime + 0.2 # Small buffer

	var timer = get_tree().create_timer(self_destruct_delay)
	timer.timeout.connect(queue_free)

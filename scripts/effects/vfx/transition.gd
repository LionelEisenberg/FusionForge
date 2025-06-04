extends CanvasLayer

@onready var animation_player: AnimationPlayer = $ColorRect/AnimationPlayer # Assuming child is named AnimationPlayer

func _ready():
	pass

func play_animation() -> void:
	animation_player.play("transition")

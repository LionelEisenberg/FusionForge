extends Node

var sfx_dict: Dictionary = {
	"element_element_collision": [preload("res://assets/audio/sfx/collisions/element_element.wav")]
}

# --- Consts ---
const BASE_SFX_VOLUME_LINEAR: float = 0.1
const BASE_SFX_PITCH: float = 1.0


# --- Node Pools ---
# This pool will be populated from nodes in the "audiostreamplayer2d_sfx_pool" group
@onready var sfx_player_pool: Array[AudioStreamPlayer2D] = []

#-----------------------------------------------------------------------------
# Initialization
#-----------------------------------------------------------------------------

func _ready() -> void:
	_populate_audio_player_pool()
		
	if CollisionManager:
		CollisionManager.element_element_sfx_requested.connect(_on_element_element_sfx_requested)
	else:
		push_warning("AudioManager: CollisionManager not found. SFX signals will not be connected.")


#-----------------------------------------------------------------------------
# Signal Handlers
#-----------------------------------------------------------------------------

func _on_element_element_sfx_requested(position: Vector2, intensity: float) -> void:
	_play_sfx("element_element_collision", position, intensity)

#-----------------------------------------------------------------------------
# Core Playback Logic
#-----------------------------------------------------------------------------
func _play_sfx(sfx_key: String, position: Vector2, _intensity: float = -1.0) -> void:
	if not sfx_dict.has(sfx_key):
		push_warning("AudioManager: SFX key not found in sfx_dict: " + sfx_key)
		return

	var sound_streams: Array = sfx_dict[sfx_key]
	if sound_streams.is_empty():
		push_warning("AudioManager: No sound streams defined for SFX key: " + sfx_key)
		return

	var player: AudioStreamPlayer2D = _get_next_available_player_from_pool(sfx_player_pool)
	if player == null: 
		push_warning("AudioManager: No Stream Player available for SFX: " + sfx_key) # Can be spammy
		return
	
	player.stream = sound_streams.pick_random()
	player.global_position = position
	
	# Apply intensity modifications (volume and pitch)
	# Reset to defaults first
	player.volume_linear = BASE_SFX_VOLUME_LINEAR
	player.pitch_scale = BASE_SFX_PITCH
	player.play()

#-----------------------------------------------------------------------------
# Helper Functions
#-----------------------------------------------------------------------------
func _populate_audio_player_pool() -> void:
	sfx_player_pool.clear() # Clear in case _ready is called multiple times (though unlikely for autoload)
	for node in get_tree().get_nodes_in_group("audiostreamplayer2d"):
		if node is AudioStreamPlayer2D:
			sfx_player_pool.append(node)
		else:
			push_warning("AudioManager: Node in 'audiostreamplayer2d_sfx_pool' group is not an AudioStreamPlayer2D: " + str(node))
	
	if sfx_player_pool.is_empty():
		push_warning("AudioManager: SFX player pool is empty. No nodes found in group 'audiostreamplayer2d_sfx_pool'.")

func _get_next_available_player_from_pool(pool: Array) -> AudioStreamPlayer2D:
	for player_node in pool:
		if player_node is AudioStreamPlayer2D and not player_node.playing:
			return player_node

	return null

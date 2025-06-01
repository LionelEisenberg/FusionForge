extends Node

var sfx_dict: Dictionary = {
	"element_element_collision": [preload("res://assets/audio/sfx/collisions/element_element.wav")],
	"element_wall_collision": [preload("res://assets/audio/sfx/collisions/element_wall.wav")],
	"fusion_event": [preload("res://assets/audio/sfx/collisions/fusion_event.wav")],
	"energy_depleted": [preload("res://assets/audio/sfx/run/energy_depleted.wav")],
	"stability_depleted": [preload("res://assets/audio/sfx/run/stability_depleted.wav")]
}

var music_array: Array = [preload("res://assets/audio/music/background_music_1.wav")]

# --- Consts ---
const BASE_SFX_VOLUME_LINEAR: float = 0.1
const BASE_SFX_PITCH: float = 1.0

const BASE_MUSIC_VOLUME_LINEAR: float = 0.1
const base_MUSIC_PITCH: float = 1.0

# --- Node Pools ---
# This pool will be populated from nodes in the "sfx_players_2d_pool" group
@onready var sfx_player_2d_pool: Array[AudioStreamPlayer2D] = []
# This pool will be populated from nodes in the "sfx_players_pool" group
@onready var sfx_player_pool: Array[AudioStreamPlayer] = []
@onready var music_player: AudioStreamPlayer = %"Music Player"

# --- Volume Control ---
var master_bus_idx: int = -1
const MASTER_BUS_NAME: String = "Master"

#-----------------------------------------------------------------------------
# Initialization
#-----------------------------------------------------------------------------

func _ready() -> void:
	_populate_audio_player_pool()
	
	master_bus_idx = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if master_bus_idx == -1:
		push_error("AudioManager: 'Master' audio bus not found!")

	if OptionsManager:
		if OptionsManager.has_signal("master_volume_changed"):
			OptionsManager.master_volume_changed.connect(_on_master_volume_setting_changed)
			_on_master_volume_setting_changed(OptionsManager.get_master_volume_normalized())
		else:
			push_warning("AudioManager: OptionsManager does not have 'master_volume_changed' signal.")
	else:
		push_warning("AudioManager: OptionsManager not found. Master volume will use AudioServer default.")

	
	if CollisionManager:
		CollisionManager.element_element_sfx_requested.connect(_on_element_element_sfx_requested)
		CollisionManager.element_wall_sfx_requested.connect(_on_element_wall_sfx_requested)
		CollisionManager.fusion_event_sfx_requested.connect(_on_fusion_event_sfx_requested)
	else:
		push_warning("AudioManager: CollisionManager not found. SFX signals will not be connected.")
	
	if GameManager:
		GameManager.energy_depleted_sfx_required.connect(_on_energy_depleted_sfx_requested)
		GameManager.stability_depleted_sfx_required.connect(_on_stability_depleted_sfx_request)
	else:
		push_warning("AudioManager: GameManager not found. SFX signals will not be connected.")
	
	if music_player and not music_player.playing:
		music_player.volume_linear = BASE_MUSIC_VOLUME_LINEAR
		music_player.autoplay = true
		music_player.stream = music_array.pick_random()
		
		music_player.play()
	else:
		push_warning("AudioManager: Unable to start music, no AudioStreamPlayer found.")

#-----------------------------------------------------------------------------
# Volume Signal Handler
#-----------------------------------------------------------------------------

func _on_master_volume_setting_changed(new_value_normalized: float) -> void:
	if master_bus_idx != -1:
		AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(new_value_normalized))
	else:
		push_warning("AudioManager: Master bus not found, cannot update volume via signal.")

#-----------------------------------------------------------------------------
# Signal Handlers
#-----------------------------------------------------------------------------

func _on_element_element_sfx_requested(position: Vector2, _intensity: float) -> void:
	_play_2d_sfx("element_element_collision", position)

func _on_element_wall_sfx_requested(position: Vector2, _intensity: float) -> void:
	_play_2d_sfx("element_wall_collision", position)

func _on_fusion_event_sfx_requested(position: Vector2, _intensity: float) -> void:
	_play_2d_sfx("fusion_event", position)

func _on_energy_depleted_sfx_requested() -> void:
	_play_sfx("energy_depleted")

func _on_stability_depleted_sfx_request() -> void:
	_play_sfx("stability_depleted")

#-----------------------------------------------------------------------------
# Core Playback Logic
#-----------------------------------------------------------------------------
func _play_2d_sfx(sfx_key: String, position: Vector2, _intensity: float = -1.0) -> void:
	if not sfx_dict.has(sfx_key):
		push_warning("AudioManager: SFX key not found in sfx_dict: " + sfx_key)
		return

	var sound_streams: Array = sfx_dict[sfx_key]
	if sound_streams.is_empty():
		push_warning("AudioManager: No sound streams defined for SFX key: " + sfx_key)
		return

	var player: AudioStreamPlayer2D = _get_next_available_player_from_pool(sfx_player_2d_pool) as AudioStreamPlayer2D
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

func _play_sfx(sfx_key: String) -> void:
	var sound_streams: Array = _get_sound_streams_from_dict(sfx_key)
	if sound_streams.is_empty(): return

	var player: Node = _get_next_available_player_from_pool(sfx_player_pool) as AudioStreamPlayer
	if not player:
		return
		
	player.stream = sound_streams.pick_random()
	player.volume_linear = BASE_SFX_VOLUME_LINEAR
	player.pitch_scale = BASE_SFX_PITCH
	
	player.play()

#-----------------------------------------------------------------------------
# Helper Functions
#-----------------------------------------------------------------------------
func _populate_audio_player_pool() -> void:
	sfx_player_2d_pool.clear() # Clear in case _ready is called multiple times (though unlikely for autoload)
	sfx_player_pool.clear() # Clear in case _ready is called multiple times (though unlikely for autoload)
	
	for node in get_tree().get_nodes_in_group("sfx_players_2d_pool"):
		if node is AudioStreamPlayer2D:
			sfx_player_2d_pool.append(node)
		else:
			push_warning("AudioManager: Node in 'sfx_players_2d_pool' group is not an AudioStreamPlayer2D: " + str(node))
	
	if sfx_player_2d_pool.is_empty():
		push_warning("AudioManager: SFX player pool is empty. No nodes found in group 'sfx_players_2d_pool'.")

	for node in get_tree().get_nodes_in_group("sfx_players_pool"):
		if node is AudioStreamPlayer:
			sfx_player_pool.append(node)
		else:
			push_warning("AudioManager: Node in 'sfx_players_pool' group is not an AudioStreamPlayer: " + str(node))
	
	if sfx_player_pool.is_empty():
		push_warning("AudioManager: SFX player pool is empty. No nodes found in group 'sfx_players_pool'.")


func _get_next_available_player_from_pool(pool: Array) -> Node:
	for player_node in pool:
		if not player_node.playing:
			return player_node
	return null


func _get_sound_streams_from_dict(sfx_key: String) -> Array:
	if not sfx_dict.has(sfx_key):
		push_warning("AudioManager: SFX key not found in sfx_dict: " + sfx_key)
		return []
	var streams = sfx_dict[sfx_key]
	if not streams is Array or streams.is_empty():
		push_warning("AudioManager: No sound streams defined or not an array for SFX key: " + sfx_key)
		return []
	return streams

# OptionsManager.gd
# Autoload Singleton
# Manages game settings like audio volumes and persists them using ConfigFile.
extends Node

# --- Signals ---
signal master_volume_changed(new_value_normalized: float)
signal sfx_volume_changed(new_value_normalized: float)
signal music_volume_changed(new_value_normalized: float)
# Add more signals here for other options as needed

# --- Constants ---
const OPTIONS_FILE_PATH: String = "user://options.cfg"

const AUDIO_SECTION: String = "audio"
const MASTER_VOLUME_KEY: String = "master_volume"
const SFX_VOLUME_KEY: String = "sfx_volume"
const MUSIC_VOLUME_KEY: String = "music_volume"

# --- Option Variables with Defaults ---
# These store the current values. They are normalized (0.0 to 1.0).
var master_volume: float = 1.0:
	set(value):
		var clamped_value = clampf(value, 0.0, 1.0)
		if not is_equal_approx(master_volume, clamped_value):
			master_volume = clamped_value
			emit_signal("master_volume_changed", master_volume)
			save_options()
	get:
		return master_volume

var sfx_volume: float = 1.0:
	set(value):
		var clamped_value = clampf(value, 0.0, 1.0)
		if not is_equal_approx(sfx_volume, clamped_value):
			sfx_volume = clamped_value
			emit_signal("sfx_volume_changed", sfx_volume)
			save_options()
	get:
		return sfx_volume

var music_volume: float = 1.0:
	set(value):
		var clamped_value = clampf(value, 0.0, 1.0)
		if not is_equal_approx(music_volume, clamped_value):
			music_volume = clamped_value
			emit_signal("music_volume_changed", music_volume)
			save_options()
	get:
		return music_volume

# --- Initialization ---
func _ready() -> void:
	load_options()
	# Emit initial signals after loading so other systems can get the loaded values
	emit_signal("master_volume_changed", master_volume)
	emit_signal("sfx_volume_changed", sfx_volume)
	emit_signal("music_volume_changed", music_volume)

# --- Public Methods for Setting Options ---
# Setters are now directly on the properties using setget, but you can keep these
# explicit methods if you prefer or need more complex logic before setting.

func set_master_volume_normalized(value: float) -> void:
	self.master_volume = value # This will use the custom setter

func set_sfx_volume_normalized(value: float) -> void:
	self.sfx_volume = value # This will use the custom setter

func set_music_volume_normalized(value: float) -> void:
	self.music_volume = value # This will use the custom setter

# --- Public Methods for Getting Options ---
# Getters are directly on the properties using setget. These are convenience wrappers.

func get_master_volume_normalized() -> float:
	return master_volume

func get_sfx_volume_normalized() -> float:
	return sfx_volume

func get_music_volume_normalized() -> float:
	return music_volume

# --- File Operations ---
func load_options() -> void:
	var config = ConfigFile.new()
	var err = config.load(OPTIONS_FILE_PATH)

	if err == OK:
		master_volume = config.get_value(AUDIO_SECTION, MASTER_VOLUME_KEY, master_volume)
		sfx_volume = config.get_value(AUDIO_SECTION, SFX_VOLUME_KEY, sfx_volume)
		music_volume = config.get_value(AUDIO_SECTION, MUSIC_VOLUME_KEY, music_volume)
	else:
		if err == ERR_FILE_NOT_FOUND:
			print_debug("OptionsManager: Options file not found at %s. Creating with defaults." % OPTIONS_FILE_PATH)
			# File doesn't exist, so save current defaults to create it.
			save_options()
		else:
			printerr("OptionsManager: Error loading options file %s. Error code: %s" % [OPTIONS_FILE_PATH, err])

func save_options() -> void:
	var config = ConfigFile.new()

	# Set values
	config.set_value(AUDIO_SECTION, MASTER_VOLUME_KEY, master_volume)
	config.set_value(AUDIO_SECTION, SFX_VOLUME_KEY, sfx_volume)
	config.set_value(AUDIO_SECTION, MUSIC_VOLUME_KEY, music_volume)

	var err = config.save(OPTIONS_FILE_PATH)
	if err != OK:
		push_error("OptionsManager: Error saving options file %s. Error code: %s" % [OPTIONS_FILE_PATH, err])

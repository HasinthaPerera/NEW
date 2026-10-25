extends Node

# Persistent Game Manager and Settings
# Handles player car customization, difficulty, local save/load, and scene transitions.

const SAVE_PATH := "user://settings.json"

const COLOR_PRESETS: Dictionary = {
	"Orange": Color("#FF791B"),
	"Blue": Color("#1685E8"),
	"Red": Color("#E63B43"),
	"Green": Color("#30AD78")
}

const COLOR_NAMES: Array[String] = ["Orange", "Blue", "Red", "Green"]

const DIFFICULTY_CONFIG: Dictionary = {
	"Easy": {
		"target_speed": 78.0,
		"wpm": 25.0,
		"error_chance": 0.15,
		"accel_rate": 26.0,
		"min_error_pause": 0.45,
		"max_error_pause": 0.75,
		"nitro_boost": 20.0,
		"description": "Casual AI opponents (~25 WPM, 85% accuracy).\nSlower acceleration and frequent typing pauses. Great for beginners."
	},
	"Medium": {
		"target_speed": 104.0,
		"wpm": 45.0,
		"error_chance": 0.07,
		"accel_rate": 42.0,
		"min_error_pause": 0.30,
		"max_error_pause": 0.50,
		"nitro_boost": 26.0,
		"description": "Balanced AI opponents (~45 WPM, 93% accuracy).\nModerate acceleration and occasional typos. A fun, standard racing challenge."
	},
	"Hard": {
		"target_speed": 126.0,
		"wpm": 65.0,
		"error_chance": 0.02,
		"accel_rate": 58.0,
		"min_error_pause": 0.18,
		"max_error_pause": 0.32,
		"nitro_boost": 32.0,
		"description": "Expert AI opponents (~65 WPM, 98% accuracy).\nFast acceleration and rare typos. Demands high typing speed and nitro combos!"
	}
}

var selected_color_name: String = "Orange"
var player_car_color: Color = Color("#FF791B")
var ai_difficulty: String = "Medium"
var music_volume: float = 0.8
var sound_enabled: bool = true

func _ready() -> void:
	load_settings()

func set_car_color_by_name(color_name: String) -> void:
	if COLOR_PRESETS.has(color_name):
		selected_color_name = color_name
		player_car_color = COLOR_PRESETS[color_name]
		save_settings()

func get_color_for_name(color_name: String) -> Color:
	return COLOR_PRESETS.get(color_name, Color("#FF791B"))

func set_difficulty(diff: String) -> void:
	if diff in ["Easy", "Medium", "Hard"]:
		ai_difficulty = diff
		save_settings()

func set_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	save_settings()

func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	save_settings()

# Returns distinct colors for the 3 AI racers excluding player's selected color
func get_ai_colors() -> Array[Dictionary]:
	var available_names: Array[String] = []
	for c_name in COLOR_NAMES:
		if c_name != selected_color_name:
			available_names.append(c_name)

	# Safety fallback in case list is short
	while available_names.size() < 3:
		available_names.append("Blue")

	return [
		{"name": available_names[0] + " Comet", "color": COLOR_PRESETS[available_names[0]]},
		{"name": available_names[1] + " Fury", "color": COLOR_PRESETS[available_names[1]]},
		{"name": available_names[2] + " Viper", "color": COLOR_PRESETS[available_names[2]]}
	]

# Save player preferences safely to user:// directory
func save_settings() -> void:
	var data: Dictionary = {
		"selected_color_name": selected_color_name,
		"ai_difficulty": ai_difficulty,
		"music_volume": music_volume,
		"sound_enabled": sound_enabled
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

# Load player preferences with robust fallback against missing or corrupted files
func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return # Use defaults safely

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var text := file.get_as_text()
	file.close()

	if text.strip_edges().is_empty():
		return

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK or not (json.data is Dictionary):
		push_warning("Failed to parse settings.json or format is invalid. Using defaults.")
		return

	var d: Dictionary = json.data

	if d.has("selected_color_name") and d["selected_color_name"] is String:
		var c_name: String = d["selected_color_name"]
		if COLOR_PRESETS.has(c_name):
			selected_color_name = c_name
			player_car_color = COLOR_PRESETS[c_name]

	if d.has("ai_difficulty") and d["ai_difficulty"] is String:
		var diff: String = d["ai_difficulty"]
		if diff in ["Easy", "Medium", "Hard"]:
			ai_difficulty = diff

	if d.has("music_volume") and (d["music_volume"] is float or d["music_volume"] is int):
		music_volume = clampf(float(d["music_volume"]), 0.0, 1.0)

	if d.has("sound_enabled") and d["sound_enabled"] is bool:
		sound_enabled = bool(d["sound_enabled"])

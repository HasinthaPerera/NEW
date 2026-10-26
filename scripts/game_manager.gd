extends Node

# Persistent Game Manager and Settings
# Handles player car customization, difficulty, local save/load, and scene transitions.

const SAVE_PATH := "user://settings.json"
const STATS_PATH := "user://stats.json"

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

# Career Statistics
var stats_races_played: int = 0
var stats_race_wins: int = 0
var stats_best_wpm: float = 0.0
var stats_best_race_time: float = 0.0
var stats_total_correct_keystrokes: int = 0
var stats_total_incorrect_keystrokes: int = 0
var stats_total_completed_phrases: int = 0
var recent_races: Array[Dictionary] = []

# Player Level & Experience Points (XP)
const XP_COMPLETION: int = 100
const XP_POSITION: Dictionary = {
	1: 150,
	2: 100,
	3: 50,
	4: 0
}

var total_xp: int = 0
var last_race_xp: Dictionary = {}

func _ready() -> void:
	load_settings()
	load_stats()

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

func calculate_race_xp(pos: int, acc: float, diff: String) -> Dictionary:
	var completion_xp := XP_COMPLETION
	var pos_xp: int = XP_POSITION.get(pos, 0)
	var acc_xp := 0
	if acc >= 100.0 or is_equal_approx(acc, 100.0):
		acc_xp = 100
	elif acc >= 95.0:
		acc_xp = 50
	elif acc >= 90.0:
		acc_xp = 25
	else:
		acc_xp = 0

	var diff_xp := 50 if diff == "Hard" else 0
	var total := completion_xp + pos_xp + acc_xp + diff_xp

	return {
		"completion_xp": completion_xp,
		"position_xp": pos_xp,
		"accuracy_xp": acc_xp,
		"difficulty_xp": diff_xp,
		"total_xp": total
	}

func get_player_title(lvl: int) -> String:
	if lvl >= 20:
		return "Racing Legend"
	elif lvl >= 10:
		return "Pro Racer"
	elif lvl >= 5:
		return "Street Racer"
	else:
		return "Rookie Racer"

func get_level_info(xp: int) -> Dictionary:
	var remaining: int = maxi(0, xp)
	var current_lvl: int = 1
	while true:
		var cost_for_next: int = 100 * current_lvl
		if remaining >= cost_for_next:
			remaining -= cost_for_next
			current_lvl += 1
		else:
			break

	var cost_for_next: int = 100 * current_lvl
	var progress_ratio: float = float(remaining) / float(cost_for_next)
	var title: String = get_player_title(current_lvl)

	return {
		"level": current_lvl,
		"current_level_xp": remaining,
		"next_level_cost": cost_for_next,
		"xp_needed": cost_for_next - remaining,
		"progress_ratio": clampf(progress_ratio, 0.0, 1.0),
		"title": title,
		"total_xp": maxi(0, xp)
	}

func get_career_stats() -> Dictionary:
	var total_keys := stats_total_correct_keystrokes + stats_total_incorrect_keystrokes
	var avg_acc: float = 0.0
	if total_keys > 0:
		avg_acc = (float(stats_total_correct_keystrokes) / float(total_keys)) * 100.0
	var win_rate: float = 0.0
	if stats_races_played > 0:
		win_rate = (float(stats_race_wins) / float(stats_races_played)) * 100.0

	var lvl_info := get_level_info(total_xp)

	return {
		"races_played": stats_races_played,
		"race_wins": stats_race_wins,
		"win_rate": win_rate,
		"best_wpm": stats_best_wpm,
		"average_accuracy": avg_acc,
		"best_race_time": stats_best_race_time,
		"total_correct_keystrokes": stats_total_correct_keystrokes,
		"total_incorrect_keystrokes": stats_total_incorrect_keystrokes,
		"total_completed_phrases": stats_total_completed_phrases,
		"total_xp": total_xp,
		"level": lvl_info["level"],
		"title": lvl_info["title"],
		"current_level_xp": lvl_info["current_level_xp"],
		"next_level_cost": lvl_info["next_level_cost"],
		"xp_needed": lvl_info["xp_needed"],
		"progress_ratio": lvl_info["progress_ratio"]
	}

func get_recent_races() -> Array[Dictionary]:
	return recent_races.duplicate()

func record_race_result(result: Dictionary) -> Dictionary:
	var date_str: String = result.get("date", "")
	if date_str.is_empty():
		var dt := Time.get_datetime_dict_from_system()
		date_str = "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

	var diff: String = result.get("difficulty", ai_difficulty)
	var pos: int = int(result.get("position", 1))
	var r_time: float = float(result.get("race_time", 0.0))
	var wpm_val: float = float(result.get("wpm", 0.0))
	var acc_val: float = float(result.get("accuracy", 100.0))
	var corr: int = int(result.get("correct_keystrokes", 0))
	var errs: int = int(result.get("incorrect_keystrokes", 0))
	var phrases: int = int(result.get("completed_phrases", 0))
	var c_color: String = result.get("car_color", selected_color_name)

	# Calculate XP and Leveling
	var prev_lvl_info: Dictionary = get_level_info(total_xp)
	var xp_breakdown: Dictionary = calculate_race_xp(pos, acc_val, diff)
	var earned_xp: int = int(xp_breakdown["total_xp"])
	total_xp += earned_xp
	var new_lvl_info: Dictionary = get_level_info(total_xp)
	var leveled_up: bool = (int(new_lvl_info["level"]) > int(prev_lvl_info["level"]))
	var levels_gained: int = int(new_lvl_info["level"]) - int(prev_lvl_info["level"])

	last_race_xp = {
		"completion_xp": xp_breakdown["completion_xp"],
		"position_xp": xp_breakdown["position_xp"],
		"accuracy_xp": xp_breakdown["accuracy_xp"],
		"difficulty_xp": xp_breakdown["difficulty_xp"],
		"total_xp_earned": earned_xp,
		"prev_level": prev_lvl_info["level"],
		"current_level": new_lvl_info["level"],
		"leveled_up": leveled_up,
		"levels_gained": levels_gained,
		"title": new_lvl_info["title"],
		"total_xp": total_xp,
		"current_level_xp": new_lvl_info["current_level_xp"],
		"next_level_cost": new_lvl_info["next_level_cost"],
		"xp_needed": new_lvl_info["xp_needed"],
		"progress_ratio": new_lvl_info["progress_ratio"]
	}

	var entry: Dictionary = {
		"date": date_str,
		"timestamp": int(Time.get_unix_time_from_system()),
		"difficulty": diff,
		"position": pos,
		"race_time": r_time,
		"wpm": wpm_val,
		"accuracy": acc_val,
		"correct_keystrokes": corr,
		"incorrect_keystrokes": errs,
		"completed_phrases": phrases,
		"car_color": c_color,
		"xp_earned": earned_xp
	}

	# Update Career Cumulative Stats
	stats_races_played += 1
	if pos == 1:
		stats_race_wins += 1

	if wpm_val > stats_best_wpm:
		stats_best_wpm = wpm_val

	if r_time > 0.0:
		if stats_best_race_time <= 0.0 or r_time < stats_best_race_time:
			stats_best_race_time = r_time

	stats_total_correct_keystrokes += corr
	stats_total_incorrect_keystrokes += errs
	stats_total_completed_phrases += phrases

	# Prepend to recent races (newest first, keep max 20)
	recent_races.push_front(entry)
	if recent_races.size() > 20:
		recent_races.resize(20)

	save_stats()
	return last_race_xp

func save_stats() -> void:
	var total_keys := stats_total_correct_keystrokes + stats_total_incorrect_keystrokes
	var avg_acc: float = 0.0
	if total_keys > 0:
		avg_acc = (float(stats_total_correct_keystrokes) / float(total_keys)) * 100.0

	var lvl_info := get_level_info(total_xp)

	var data: Dictionary = {
		"version": 1,
		"career": {
			"races_played": stats_races_played,
			"race_wins": stats_race_wins,
			"best_wpm": stats_best_wpm,
			"best_race_time": stats_best_race_time,
			"total_correct_keystrokes": stats_total_correct_keystrokes,
			"total_incorrect_keystrokes": stats_total_incorrect_keystrokes,
			"total_completed_phrases": stats_total_completed_phrases,
			"average_accuracy": avg_acc
		},
		"history": recent_races,
		"progression": {
			"total_xp": total_xp,
			"level": lvl_info["level"],
			"title": lvl_info["title"]
		},
		"achievements": {}
	}

	var file := FileAccess.open(STATS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_stats() -> void:
	if not FileAccess.file_exists(STATS_PATH):
		total_xp = 0
		return # Use defaults safely

	var file := FileAccess.open(STATS_PATH, FileAccess.READ)
	if not file:
		total_xp = 0
		return

	var text := file.get_as_text()
	file.close()

	if text.strip_edges().is_empty():
		total_xp = 0
		return

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK or not (json.data is Dictionary):
		push_warning("Failed to parse stats.json or format is invalid. Using default statistics.")
		total_xp = 0
		return

	var d: Dictionary = json.data

	if d.has("progression") and d["progression"] is Dictionary:
		var p: Dictionary = d["progression"]
		if p.has("total_xp") and (p["total_xp"] is int or p["total_xp"] is float):
			total_xp = maxi(0, int(p["total_xp"]))
		elif p.has("xp") and (p["xp"] is int or p["xp"] is float):
			total_xp = maxi(0, int(p["xp"]))
		else:
			total_xp = 0
	else:
		total_xp = 0

	if d.has("career") and d["career"] is Dictionary:
		var c: Dictionary = d["career"]
		if c.has("races_played") and (c["races_played"] is int or c["races_played"] is float):
			stats_races_played = max(0, int(c["races_played"]))
		if c.has("race_wins") and (c["race_wins"] is int or c["race_wins"] is float):
			stats_race_wins = clamp(int(c["race_wins"]), 0, stats_races_played)
		if c.has("best_wpm") and (c["best_wpm"] is float or c["best_wpm"] is int):
			stats_best_wpm = maxf(0.0, float(c["best_wpm"]))
		if c.has("best_race_time") and (c["best_race_time"] is float or c["best_race_time"] is int):
			stats_best_race_time = maxf(0.0, float(c["best_race_time"]))
		if c.has("total_correct_keystrokes") and (c["total_correct_keystrokes"] is int or c["total_correct_keystrokes"] is float):
			stats_total_correct_keystrokes = max(0, int(c["total_correct_keystrokes"]))
		if c.has("total_incorrect_keystrokes") and (c["total_incorrect_keystrokes"] is int or c["total_incorrect_keystrokes"] is float):
			stats_total_incorrect_keystrokes = max(0, int(c["total_incorrect_keystrokes"]))
		if c.has("total_completed_phrases") and (c["total_completed_phrases"] is int or c["total_completed_phrases"] is float):
			stats_total_completed_phrases = max(0, int(c["total_completed_phrases"]))

	if d.has("history") and d["history"] is Array:
		recent_races.clear()
		for item in d["history"]:
			if not (item is Dictionary):
				continue
			var valid_entry: Dictionary = {
				"date": str(item.get("date", "")),
				"timestamp": int(item.get("timestamp", 0)),
				"difficulty": str(item.get("difficulty", "Medium")),
				"position": int(item.get("position", 1)),
				"race_time": float(item.get("race_time", 0.0)),
				"wpm": float(item.get("wpm", 0.0)),
				"accuracy": float(item.get("accuracy", 100.0)),
				"correct_keystrokes": int(item.get("correct_keystrokes", 0)),
				"incorrect_keystrokes": int(item.get("incorrect_keystrokes", 0)),
				"completed_phrases": int(item.get("completed_phrases", 0)),
				"car_color": str(item.get("car_color", "Orange")),
				"xp_earned": int(item.get("xp_earned", 0))
			}
			recent_races.append(valid_entry)
			if recent_races.size() >= 20:
				break

func clear_stats() -> void:
	stats_races_played = 0
	stats_race_wins = 0
	stats_best_wpm = 0.0
	stats_best_race_time = 0.0
	stats_total_correct_keystrokes = 0
	stats_total_incorrect_keystrokes = 0
	stats_total_completed_phrases = 0
	total_xp = 0
	last_race_xp.clear()
	recent_races.clear()
	save_stats()

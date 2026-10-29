extends Node

signal achievement_unlocked(id: String, achievement_data: Dictionary)

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

# Centralized Achievement Definitions Catalog
const ACHIEVEMENTS_CATALOG: Dictionary = {
	"first_race": {
		"id": "first_race",
		"name": "First Race",
		"description": "Complete 1 race",
		"requirement": "Complete 1 race",
		"reward_xp": 50,
		"icon": "🏁",
		"target": 1
	},
	"first_victory": {
		"id": "first_victory",
		"name": "First Victory",
		"description": "Win 1 race",
		"requirement": "Win 1 race",
		"reward_xp": 100,
		"icon": "🏆",
		"target": 1
	},
	"speed_typist": {
		"id": "speed_typist",
		"name": "Speed Typist",
		"description": "Finish a race with at least 60 WPM",
		"requirement": "Finish a race with at least 60 WPM",
		"reward_xp": 100,
		"icon": "⚡",
		"target": 60
	},
	"perfect_accuracy": {
		"id": "perfect_accuracy",
		"name": "Perfect Accuracy",
		"description": "Finish a race with 100% accuracy",
		"requirement": "Finish a race with 100% accuracy",
		"reward_xp": 150,
		"icon": "🎯",
		"target": 100
	},
	"nitro_master": {
		"id": "nitro_master",
		"name": "Nitro Master",
		"description": "Activate nitro 10 times across completed and active races",
		"requirement": "Activate nitro 10 times across completed and active races",
		"reward_xp": 100,
		"icon": "🔥",
		"target": 10
	},
	"consistent_racer": {
		"id": "consistent_racer",
		"name": "Consistent Racer",
		"description": "Complete 10 races",
		"requirement": "Complete 10 races",
		"reward_xp": 150,
		"icon": "🏎",
		"target": 10
	},
	"champion": {
		"id": "champion",
		"name": "Champion",
		"description": "Win 10 races",
		"requirement": "Win 10 races",
		"reward_xp": 250,
		"icon": "👑",
		"target": 10
	},
	"racing_legend": {
		"id": "racing_legend",
		"name": "Racing Legend",
		"description": "Reach Level 20",
		"requirement": "Reach Level 20",
		"reward_xp": 500,
		"icon": "⭐",
		"target": 20
	}
}

const ACHIEVEMENT_ORDER: Array[String] = [
	"first_race",
	"first_victory",
	"speed_typist",
	"perfect_accuracy",
	"nitro_master",
	"consistent_racer",
	"champion",
	"racing_legend"
]

# Centralized Track Definitions Catalog
const TRACKS_CATALOG: Dictionary = {
	"metro_sprint": {
		"id": "metro_sprint",
		"name": "Metro Sprint",
		"display_name": "Metro Sprint",
		"environment": "City",
		"race_length": "Short",
		"description": "Fast urban racing through a modern city.",
		"status": "Playable",
		"is_playable": true,
		"scene_path": "res://main.tscn"
	},
	"desert_dash": {
		"id": "desert_dash",
		"name": "Desert Dash",
		"display_name": "Desert Dash",
		"environment": "Desert",
		"race_length": "Medium",
		"description": "Race across a sunlit desert highway.",
		"status": "Coming Soon",
		"is_playable": false,
		"scene_path": ""
	},
	"forest_run": {
		"id": "forest_run",
		"name": "Forest Run",
		"display_name": "Forest Run",
		"environment": "Forest",
		"race_length": "Long",
		"description": "Race through a scenic forest environment.",
		"status": "Coming Soon",
		"is_playable": false,
		"scene_path": ""
	}
}

const TRACK_ORDER: Array[String] = [
	"metro_sprint",
	"desert_dash",
	"forest_run"
]

var selected_color_name: String = "Orange"
var player_car_color: Color = Color("#FF791B")
var ai_difficulty: String = "Medium"
var selected_track_id: String = "metro_sprint"
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

# Achievement Tracking & Persistence
var unlocked_achievements: Dictionary = {}
var stats_nitro_activations: int = 0
var _is_evaluating_achievements: bool = false

# Subscreen Navigation Tracking
var return_screen_path: String = "res://scenes/main_menu.tscn"

# Toast Notification System
var notification_queue: Array[Dictionary] = []
var toast_canvas: CanvasLayer = null
var toast_panel: PanelContainer = null
var toast_icon_label: Label = null
var toast_title_label: Label = null
var toast_name_label: Label = null
var toast_reward_label: Label = null
var toast_timer: float = 0.0
var is_toast_active: bool = false
const TOAST_DURATION: float = 3.5

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
	_setup_notification_system()

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

func set_return_screen(path: String) -> void:
	return_screen_path = path

func get_return_screen(fallback: String = "res://scenes/main_menu.tscn") -> String:
	return return_screen_path if not return_screen_path.is_empty() else fallback

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

# Track Selection Management
func set_track(track_id: String) -> bool:
	if TRACKS_CATALOG.has(track_id) and bool(TRACKS_CATALOG[track_id].get("is_playable", false)):
		selected_track_id = track_id
		save_settings()
		return true
	return false

func get_selected_track() -> Dictionary:
	return TRACKS_CATALOG.get(selected_track_id, TRACKS_CATALOG["metro_sprint"])

func get_track(track_id: String) -> Dictionary:
	return TRACKS_CATALOG.get(track_id, {})

func is_track_playable(track_id: String) -> bool:
	return TRACKS_CATALOG.has(track_id) and bool(TRACKS_CATALOG[track_id].get("is_playable", false))

func get_all_tracks() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for id in TRACK_ORDER:
		list.append(TRACKS_CATALOG[id])
	return list

func get_track_scene_path(track_id: String = "") -> String:
	var t_id := track_id if not track_id.is_empty() else selected_track_id
	if is_track_playable(t_id):
		var p: String = str(TRACKS_CATALOG[t_id].get("scene_path", ""))
		if not p.is_empty() and ResourceLoader.exists(p):
			return p
	return "res://main.tscn"

# Save player preferences safely to user:// directory
func save_settings() -> void:
	var data: Dictionary = {
		"selected_color_name": selected_color_name,
		"ai_difficulty": ai_difficulty,
		"selected_track_id": selected_track_id,
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

	if d.has("selected_track_id") and d["selected_track_id"] is String:
		var t_id: String = d["selected_track_id"]
		if TRACKS_CATALOG.has(t_id) and bool(TRACKS_CATALOG[t_id].get("is_playable", false)):
			selected_track_id = t_id
		else:
			selected_track_id = "metro_sprint"
	else:
		selected_track_id = "metro_sprint"

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

	# Evaluate race-based achievements
	evaluate_achievements(entry)

	save_stats()
	return last_race_xp

# --- Achievement Tracking & Rewards ---

func is_achievement_unlocked(id: String) -> bool:
	return unlocked_achievements.has(id)

func get_unlocked_achievements_count() -> int:
	return unlocked_achievements.size()

func record_nitro_activation() -> void:
	stats_nitro_activations += 1
	save_stats()
	evaluate_achievements()

func unlock_achievement(id: String) -> bool:
	if is_achievement_unlocked(id) or not ACHIEVEMENTS_CATALOG.has(id):
		return false
	_unlock_achievement_internal(id)
	evaluate_achievements()
	save_stats()
	return true

func _unlock_achievement_internal(id: String) -> void:
	if is_achievement_unlocked(id) or not ACHIEVEMENTS_CATALOG.has(id):
		return

	var ach: Dictionary = ACHIEVEMENTS_CATALOG[id]
	var dt := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
	var unix_ts: int = int(Time.get_unix_time_from_system())

	unlocked_achievements[id] = {
		"unlocked_at": date_str,
		"timestamp": unix_ts
	}

	var reward_xp: int = int(ach.get("reward_xp", 0))
	if reward_xp > 0:
		total_xp += reward_xp

	show_achievement_notification(str(ach.get("name", "Achievement")), reward_xp, str(ach.get("icon", "🏆")))
	achievement_unlocked.emit(id, ach)

func evaluate_achievements(race_data: Dictionary = {}) -> Array[String]:
	if _is_evaluating_achievements:
		return []
	_is_evaluating_achievements = true

	var newly_unlocked: Array[String] = []
	var pass_count: int = 0
	var something_unlocked: bool = true

	while something_unlocked and pass_count < 10:
		pass_count += 1
		something_unlocked = false

		for id in ACHIEVEMENT_ORDER:
			if is_achievement_unlocked(id):
				continue

			var can_unlock: bool = false
			match id:
				"first_race":
					if stats_races_played >= 1:
						can_unlock = true
				"first_victory":
					if stats_race_wins >= 1:
						can_unlock = true
				"speed_typist":
					if (race_data.has("wpm") and float(race_data["wpm"]) >= 60.0) or stats_best_wpm >= 60.0:
						can_unlock = true
				"perfect_accuracy":
					if race_data.has("accuracy") and (float(race_data["accuracy"]) >= 100.0 or is_equal_approx(float(race_data["accuracy"]), 100.0)):
						can_unlock = true
				"nitro_master":
					if stats_nitro_activations >= 10:
						can_unlock = true
				"consistent_racer":
					if stats_races_played >= 10:
						can_unlock = true
				"champion":
					if stats_race_wins >= 10:
						can_unlock = true
				"racing_legend":
					var lvl_info := get_level_info(total_xp)
					if int(lvl_info.get("level", 1)) >= 20:
						can_unlock = true

			if can_unlock:
				_unlock_achievement_internal(id)
				newly_unlocked.append(id)
				something_unlocked = true

	_is_evaluating_achievements = false
	if not newly_unlocked.is_empty():
		save_stats()
	return newly_unlocked

func get_achievement_progress(id: String) -> Dictionary:
	if not ACHIEVEMENTS_CATALOG.has(id):
		return {}

	var ach: Dictionary = ACHIEVEMENTS_CATALOG[id]
	var is_unlocked: bool = is_achievement_unlocked(id)
	var unlock_data: Dictionary = unlocked_achievements.get(id, {})
	var unlocked_at: String = str(unlock_data.get("unlocked_at", ""))
	var timestamp: int = int(unlock_data.get("timestamp", 0))

	var current_val: float = 0.0
	var target_val: float = float(ach.get("target", 1))
	var progress_text: String = ""

	match id:
		"first_race":
			current_val = float(stats_races_played)
			progress_text = "%d / %d" % [mini(stats_races_played, 1), 1]
		"first_victory":
			current_val = float(stats_race_wins)
			progress_text = "%d / %d" % [mini(stats_race_wins, 1), 1]
		"speed_typist":
			current_val = float(stats_best_wpm)
			progress_text = "%.0f / 60 WPM" % minf(stats_best_wpm, 60.0)
		"perfect_accuracy":
			current_val = 1.0 if is_unlocked else 0.0
			progress_text = "100% Accuracy" if is_unlocked else "In a single race"
		"nitro_master":
			current_val = float(stats_nitro_activations)
			progress_text = "%d / 10" % mini(stats_nitro_activations, 10)
		"consistent_racer":
			current_val = float(stats_races_played)
			progress_text = "%d / 10" % mini(stats_races_played, 10)
		"champion":
			current_val = float(stats_race_wins)
			progress_text = "%d / 10" % mini(stats_race_wins, 10)
		"racing_legend":
			var lvl_info := get_level_info(total_xp)
			var current_lvl: int = int(lvl_info.get("level", 1))
			current_val = float(current_lvl)
			progress_text = "Level %d / 20" % mini(current_lvl, 20)

	var ratio: float = 1.0 if is_unlocked else clampf(current_val / target_val, 0.0, 1.0)

	return {
		"id": id,
		"name": ach.get("name", ""),
		"description": ach.get("description", ""),
		"requirement": ach.get("requirement", ""),
		"reward_xp": int(ach.get("reward_xp", 0)),
		"icon": ach.get("icon", "🏆"),
		"is_unlocked": is_unlocked,
		"unlocked_at": unlocked_at,
		"timestamp": timestamp,
		"current_value": current_val,
		"target_value": target_val,
		"progress_ratio": ratio,
		"progress_text": progress_text
	}

func get_all_achievements_progress() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for id in ACHIEVEMENT_ORDER:
		list.append(get_achievement_progress(id))
	return list

# --- Unlock Notifications Overlay ---

func show_achievement_notification(ach_name: String, reward_xp: int, icon: String = "🏆") -> void:
	notification_queue.append({
		"name": ach_name,
		"reward_xp": reward_xp,
		"icon": icon
	})

func _setup_notification_system() -> void:
	if toast_canvas:
		return

	toast_canvas = CanvasLayer.new()
	toast_canvas.name = "AchievementToastLayer"
	toast_canvas.layer = 128
	add_child(toast_canvas)

	var screen_ctrl := Control.new()
	screen_ctrl.name = "ToastRoot"
	screen_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_canvas.add_child(screen_ctrl)

	toast_panel = PanelContainer.new()
	toast_panel.name = "AchievementToastPanel"
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.custom_minimum_size = Vector2(380, 70)
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.anchor_top = 0.0
	toast_panel.anchor_bottom = 0.0
	toast_panel.offset_left = -190.0
	toast_panel.offset_right = 190.0
	toast_panel.offset_top = -100.0
	toast_panel.offset_bottom = -30.0
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_panel.visible = false

	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	toast_style.border_color = Color(1.0, 0.75, 0.1, 1.0) # Gold
	toast_style.border_width_left = 2
	toast_style.border_width_top = 2
	toast_style.border_width_right = 2
	toast_style.border_width_bottom = 2
	toast_style.corner_radius_top_left = 10
	toast_style.corner_radius_top_right = 10
	toast_style.corner_radius_bottom_left = 10
	toast_style.corner_radius_bottom_right = 10
	toast_style.shadow_color = Color(1.0, 0.6, 0.0, 0.45)
	toast_style.shadow_size = 12
	toast_style.content_margin_left = 16
	toast_style.content_margin_right = 16
	toast_style.content_margin_top = 8
	toast_style.content_margin_bottom = 8
	toast_panel.add_theme_stylebox_override("panel", toast_style)
	screen_ctrl.add_child(toast_panel)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 14)
	toast_panel.add_child(hbox)

	toast_icon_label = Label.new()
	toast_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_icon_label.custom_minimum_size = Vector2(40, 40)
	toast_icon_label.add_theme_font_size_override("font_size", 28)
	toast_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_icon_label.text = "🏆"
	hbox.add_child(toast_icon_label)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(vbox)

	toast_title_label = Label.new()
	toast_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_title_label.text = "ACHIEVEMENT UNLOCKED!"
	toast_title_label.add_theme_font_size_override("font_size", 11)
	toast_title_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.15))
	vbox.add_child(toast_title_label)

	toast_name_label = Label.new()
	toast_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_name_label.text = "Achievement Name"
	toast_name_label.add_theme_font_size_override("font_size", 16)
	toast_name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(toast_name_label)

	toast_reward_label = Label.new()
	toast_reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_reward_label.text = "+100 XP"
	toast_reward_label.add_theme_font_size_override("font_size", 12)
	toast_reward_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.45))
	vbox.add_child(toast_reward_label)

func _process(delta: float) -> void:
	if is_toast_active:
		toast_timer -= delta
		if toast_panel:
			if toast_timer > TOAST_DURATION - 0.35:
				var t: float = (TOAST_DURATION - toast_timer) / 0.35
				var eased: float = ease(clampf(t, 0.0, 1.0), -2.0)
				toast_panel.position.y = lerpf(-100.0, 20.0, eased)
				toast_panel.modulate.a = clampf(t, 0.0, 1.0)
			elif toast_timer < 0.35:
				var t: float = toast_timer / 0.35
				var eased: float = ease(clampf(t, 0.0, 1.0), -2.0)
				toast_panel.position.y = lerpf(-100.0, 20.0, eased)
				toast_panel.modulate.a = clampf(t, 0.0, 1.0)
			else:
				toast_panel.position.y = 20.0
				toast_panel.modulate.a = 1.0

		if toast_timer <= 0.0:
			is_toast_active = false
			if toast_panel:
				toast_panel.visible = false
	elif not notification_queue.is_empty():
		var next_item: Dictionary = notification_queue.pop_front()
		_show_toast_item(next_item)

func _show_toast_item(item: Dictionary) -> void:
	if not toast_panel:
		return
	if toast_icon_label:
		toast_icon_label.text = str(item.get("icon", "🏆"))
	if toast_name_label:
		toast_name_label.text = str(item.get("name", "Achievement"))
	if toast_reward_label:
		var xp_amt: int = int(item.get("reward_xp", 0))
		toast_reward_label.text = "+%d XP" % xp_amt
	toast_timer = TOAST_DURATION
	is_toast_active = true
	toast_panel.visible = true
	toast_panel.position.y = -100.0
	toast_panel.modulate.a = 0.0

# --- Persistence ---

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
		"achievements": unlocked_achievements,
		"custom_stats": {
			"nitro_activations": stats_nitro_activations
		}
	}

	var file := FileAccess.open(STATS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_stats() -> void:
	if not FileAccess.file_exists(STATS_PATH):
		total_xp = 0
		unlocked_achievements.clear()
		stats_nitro_activations = 0
		return # Use defaults safely

	var file := FileAccess.open(STATS_PATH, FileAccess.READ)
	if not file:
		total_xp = 0
		unlocked_achievements.clear()
		stats_nitro_activations = 0
		return

	var text := file.get_as_text()
	file.close()

	if text.strip_edges().is_empty():
		total_xp = 0
		unlocked_achievements.clear()
		stats_nitro_activations = 0
		return

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK or not (json.data is Dictionary):
		push_warning("Failed to parse stats.json or format is invalid. Using default statistics.")
		total_xp = 0
		unlocked_achievements.clear()
		stats_nitro_activations = 0
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

	# Load Achievements (Safe backwards compatibility with older formats)
	unlocked_achievements.clear()
	if d.has("achievements"):
		if d["achievements"] is Dictionary:
			for k in d["achievements"].keys():
				var ach_entry = d["achievements"][k]
				if ach_entry is Dictionary:
					unlocked_achievements[str(k)] = {
						"unlocked_at": str(ach_entry.get("unlocked_at", "")),
						"timestamp": int(ach_entry.get("timestamp", 0))
					}
				else:
					unlocked_achievements[str(k)] = {
						"unlocked_at": "Unlocked",
						"timestamp": 0
					}
		elif d["achievements"] is Array:
			for item in d["achievements"]:
				unlocked_achievements[str(item)] = {
					"unlocked_at": "Unlocked",
					"timestamp": 0
				}

	# Load Nitro Activations Count
	stats_nitro_activations = 0
	if d.has("custom_stats") and d["custom_stats"] is Dictionary:
		stats_nitro_activations = maxi(0, int(d["custom_stats"].get("nitro_activations", 0)))
	elif d.has("nitro_activations"):
		stats_nitro_activations = maxi(0, int(d["nitro_activations"]))
	elif d.has("career") and d["career"] is Dictionary and d["career"].has("nitro_activations"):
		stats_nitro_activations = maxi(0, int(d["career"]["nitro_activations"]))

func clear_stats() -> void:
	stats_races_played = 0
	stats_race_wins = 0
	stats_best_wpm = 0.0
	stats_best_race_time = 0.0
	stats_total_correct_keystrokes = 0
	stats_total_incorrect_keystrokes = 0
	stats_total_completed_phrases = 0
	total_xp = 0
	unlocked_achievements.clear()
	stats_nitro_activations = 0
	last_race_xp.clear()
	recent_races.clear()
	save_stats()

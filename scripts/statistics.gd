extends Control

@onready var races_played_val: Label = %RacesPlayedVal
@onready var race_wins_val: Label = %RaceWinsVal
@onready var win_rate_val: Label = %WinRateVal
@onready var best_wpm_val: Label = %BestWpmVal
@onready var avg_acc_val: Label = %AvgAccVal
@onready var best_time_val: Label = %BestTimeVal

@onready var recent_races_list: VBoxContainer = %RecentRacesList
@onready var empty_state: Control = %EmptyState
@onready var back_button: Button = %BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()
	_populate_stats()

func _populate_stats() -> void:
	if not is_instance_valid(GameManager):
		return

	var stats := GameManager.get_career_stats()
	var played: int = stats.get("races_played", 0)
	var wins: int = stats.get("race_wins", 0)
	var win_rate: float = stats.get("win_rate", 0.0)
	var best_wpm: float = stats.get("best_wpm", 0.0)
	var avg_acc: float = stats.get("average_accuracy", 0.0)
	var best_time: float = stats.get("best_race_time", 0.0)

	races_played_val.text = str(played)
	race_wins_val.text = str(wins)
	win_rate_val.text = "%.1f%%" % win_rate
	best_wpm_val.text = "%d WPM" % int(round(best_wpm)) if best_wpm > 0.0 else "--"
	avg_acc_val.text = "%.1f%%" % avg_acc if played > 0 else "--"
	best_time_val.text = "%.2fs" % best_time if best_time > 0.0 else "--"

	# Populate Recent Races
	for child in recent_races_list.get_children():
		child.queue_free()

	var recent := GameManager.get_recent_races()
	if recent.is_empty():
		empty_state.visible = true
		recent_races_list.visible = false
	else:
		empty_state.visible = false
		recent_races_list.visible = true
		for race in recent:
			_create_race_row(race)

func _create_race_row(race: Dictionary) -> void:
	var row := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.11, 0.16, 0.9)
	row_style.corner_radius_top_left = 6
	row_style.corner_radius_top_right = 6
	row_style.corner_radius_bottom_left = 6
	row_style.corner_radius_bottom_right = 6
	row_style.content_margin_left = 14
	row_style.content_margin_right = 14
	row_style.content_margin_top = 8
	row_style.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	# Date
	var date_lbl := Label.new()
	date_lbl.custom_minimum_size = Vector2(150, 0)
	date_lbl.text = str(race.get("date", "--"))
	date_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	date_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(date_lbl)

	# Difficulty
	var diff_lbl := Label.new()
	diff_lbl.custom_minimum_size = Vector2(110, 0)
	var diff_str: String = str(race.get("difficulty", "Medium"))
	diff_lbl.text = diff_str.to_upper()
	match diff_str:
		"Easy": diff_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 0.45))
		"Hard": diff_lbl.add_theme_color_override("font_color", Color(0.95, 0.4, 0.3))
		_: diff_lbl.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0))
	diff_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(diff_lbl)

	# Finishing Position
	var pos_lbl := Label.new()
	pos_lbl.custom_minimum_size = Vector2(120, 0)
	var pos: int = int(race.get("position", 1))
	match pos:
		1:
			pos_lbl.text = "🥇 1st Place"
			pos_lbl.add_theme_color_override("font_color", Color(0.98, 0.8, 0.2))
		2:
			pos_lbl.text = "🥈 2nd Place"
			pos_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		3:
			pos_lbl.text = "🥉 3rd Place"
			pos_lbl.add_theme_color_override("font_color", Color(0.85, 0.6, 0.3))
		_:
			pos_lbl.text = "🏁 4th Place"
			pos_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	pos_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(pos_lbl)

	# WPM
	var wpm_lbl := Label.new()
	wpm_lbl.custom_minimum_size = Vector2(90, 0)
	var wpm: float = float(race.get("wpm", 0.0))
	wpm_lbl.text = "%d WPM" % int(round(wpm))
	wpm_lbl.add_theme_color_override("font_color", Color(0.25, 0.85, 0.95))
	wpm_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(wpm_lbl)

	# Accuracy
	var acc_lbl := Label.new()
	acc_lbl.custom_minimum_size = Vector2(90, 0)
	var acc: float = float(race.get("accuracy", 100.0))
	acc_lbl.text = "%.1f%%" % acc
	acc_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	acc_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(acc_lbl)

	# Race Time
	var time_lbl := Label.new()
	time_lbl.custom_minimum_size = Vector2(90, 0)
	time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var r_time: float = float(race.get("race_time", 0.0))
	time_lbl.text = "%.2fs" % r_time
	time_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	time_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(time_lbl)

	recent_races_list.add_child(row)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

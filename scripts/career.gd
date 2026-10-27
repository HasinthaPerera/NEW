extends Control

# Career Dashboard Controller
# Displays comprehensive driver stats, XP progression, performance charts,
# achievement showcase, and recent race history in a read-only dashboard.

# Driver Profile & Level Nodes
@onready var driver_level_val: Label = %DriverLevelVal
@onready var driver_title_val: Label = %DriverTitleVal
@onready var total_xp_val: Label = %TotalXpVal
@onready var xp_progress_bar: ProgressBar = %XpProgressBar
@onready var xp_progress_text: Label = %XpProgressText

# Vital Stats Grid Nodes
@onready var stat_races_val: Label = %StatRacesVal
@onready var stat_wins_val: Label = %StatWinsVal
@onready var stat_win_rate_val: Label = %StatWinRateVal
@onready var stat_best_wpm_val: Label = %StatBestWpmVal
@onready var stat_avg_acc_val: Label = %StatAvgAccVal
@onready var stat_best_time_val: Label = %StatBestTimeVal
@onready var stat_achievements_val: Label = %StatAchievementsVal

# Performance Charts Container & Nodes
@onready var chart_wpm_node: Control = %WpmChartNode
@onready var chart_acc_node: Control = %AccChartNode
@onready var charts_empty_box: Control = %ChartsEmptyBox

# Achievement Showcase Nodes
@onready var ach_summary_label: Label = %AchSummaryLabel
@onready var ach_showcase_container: HBoxContainer = %AchShowcaseContainer
@onready var ach_empty_box: Control = %AchEmptyBox
@onready var view_all_ach_button: Button = %ViewAllAchButton

# Recent Race History Nodes
@onready var recent_races_list: VBoxContainer = %RecentRacesList
@onready var races_empty_box: Control = %RacesEmptyBox
@onready var view_full_history_button: Button = %ViewFullHistoryButton

# Navigation Buttons
@onready var header_back_button: Button = %HeaderBackButton
@onready var footer_back_button: Button = %FooterBackButton
@onready var footer_ach_button: Button = %FooterAchButton
@onready var footer_history_button: Button = %FooterHistoryButton

func _ready() -> void:
	_connect_buttons()
	if header_back_button:
		header_back_button.grab_focus()

	# Custom drawing hooks for charts
	if chart_wpm_node:
		chart_wpm_node.draw.connect(_on_wpm_chart_draw)
	if chart_acc_node:
		chart_acc_node.draw.connect(_on_acc_chart_draw)

	_populate_dashboard()

func _connect_buttons() -> void:
	if header_back_button:
		header_back_button.pressed.connect(_on_back_pressed)
	if footer_back_button:
		footer_back_button.pressed.connect(_on_back_pressed)
	if view_all_ach_button:
		view_all_ach_button.pressed.connect(_on_achievements_pressed)
	if footer_ach_button:
		footer_ach_button.pressed.connect(_on_achievements_pressed)
	if view_full_history_button:
		view_full_history_button.pressed.connect(_on_full_history_pressed)
	if footer_history_button:
		footer_history_button.pressed.connect(_on_full_history_pressed)

func _populate_dashboard() -> void:
	if not is_instance_valid(GameManager):
		return

	var career: Dictionary = GameManager.get_career_stats()
	var recent_races: Array[Dictionary] = GameManager.get_recent_races()
	var all_ach_progress: Array[Dictionary] = GameManager.get_all_achievements_progress()

	_populate_driver_profile(career)
	_populate_vitals_grid(career)
	_populate_charts(recent_races)
	_populate_achievement_showcase(all_ach_progress)
	_populate_recent_races(recent_races)

# --- 1. Driver Profile & XP Progression ---

func _populate_driver_profile(career: Dictionary) -> void:
	var lvl: int = int(career.get("level", 1))
	var title: String = str(career.get("title", "Rookie Racer"))
	var total_xp: int = int(career.get("total_xp", 0))
	var cur_lvl_xp: int = int(career.get("current_level_xp", 0))
	var next_cost: int = int(career.get("next_level_cost", 100))
	var xp_needed: int = int(career.get("xp_needed", 100))

	if driver_level_val:
		driver_level_val.text = "LEVEL %d" % lvl
	if driver_title_val:
		driver_title_val.text = title.to_upper()
	if total_xp_val:
		total_xp_val.text = "%d TOTAL XP" % total_xp
	if xp_progress_bar:
		xp_progress_bar.max_value = next_cost
		xp_progress_bar.value = cur_lvl_xp
	if xp_progress_text:
		xp_progress_text.text = "%d / %d XP  (%d XP to Level %d)" % [cur_lvl_xp, next_cost, xp_needed, lvl + 1]

# --- 2. Vital Career Statistics Grid ---

func _populate_vitals_grid(career: Dictionary) -> void:
	var played: int = int(career.get("races_played", 0))
	var wins: int = int(career.get("race_wins", 0))
	var win_rate: float = float(career.get("win_rate", 0.0))
	var best_wpm: float = float(career.get("best_wpm", 0.0))
	var avg_acc: float = float(career.get("average_accuracy", 0.0))
	var best_time: float = float(career.get("best_race_time", 0.0))

	var total_achs: int = GameManager.ACHIEVEMENTS_CATALOG.size()
	var unlocked_achs: int = GameManager.get_unlocked_achievements_count()
	var ach_pct: int = int((float(unlocked_achs) / float(maxi(1, total_achs))) * 100.0)

	if stat_races_val:
		stat_races_val.text = str(played)
	if stat_wins_val:
		stat_wins_val.text = str(wins)
	if stat_win_rate_val:
		stat_win_rate_val.text = "%.1f%%" % win_rate if played > 0 else "0.0%"
	if stat_best_wpm_val:
		stat_best_wpm_val.text = "%d WPM" % int(round(best_wpm)) if best_wpm > 0.0 else "--"
	if stat_avg_acc_val:
		stat_avg_acc_val.text = "%.1f%%" % avg_acc if played > 0 else "--"
	if stat_best_time_val:
		stat_best_time_val.text = "%.2fs" % best_time if best_time > 0.0 else "--"
	if stat_achievements_val:
		stat_achievements_val.text = "%d / %d  (%d%%)" % [unlocked_achs, total_achs, ach_pct]

# --- 3. Performance Charts (Last 10 Races Chronological) ---

var _chart_wpm_data: Array[float] = []
var _chart_acc_data: Array[float] = []

func _populate_charts(recent_races: Array[Dictionary]) -> void:
	_chart_wpm_data.clear()
	_chart_acc_data.clear()

	if recent_races.is_empty():
		if charts_empty_box:
			charts_empty_box.visible = true
		if chart_wpm_node and chart_wpm_node.get_parent():
			chart_wpm_node.get_parent().visible = false
		if chart_acc_node and chart_acc_node.get_parent():
			chart_acc_node.get_parent().visible = false
		return

	if charts_empty_box:
		charts_empty_box.visible = false
	if chart_wpm_node and chart_wpm_node.get_parent():
		chart_wpm_node.get_parent().visible = true
	if chart_acc_node and chart_acc_node.get_parent():
		chart_acc_node.get_parent().visible = true

	# Take up to 10 races and reverse to chronological order (oldest to newest)
	var slice_count: int = mini(10, recent_races.size())
	var races_chronological: Array[Dictionary] = recent_races.slice(0, slice_count)
	races_chronological.reverse()

	for r in races_chronological:
		_chart_wpm_data.append(float(r.get("wpm", 0.0)))
		_chart_acc_data.append(float(r.get("accuracy", 100.0)))

	if chart_wpm_node:
		chart_wpm_node.queue_redraw()
	if chart_acc_node:
		chart_acc_node.queue_redraw()

func _on_wpm_chart_draw() -> void:
	if not chart_wpm_node:
		return
	_draw_line_chart(
		chart_wpm_node,
		_chart_wpm_data,
		"WPM",
		Color(1.0, 0.48, 0.1, 1.0), # Racing Orange
		false
	)

func _on_acc_chart_draw() -> void:
	if not chart_acc_node:
		return
	_draw_line_chart(
		chart_acc_node,
		_chart_acc_data,
		"%",
		Color(0.12, 0.85, 0.72, 1.0), # Cyan / Emerald
		true
	)

func _draw_line_chart(ctrl: Control, data: Array[float], suffix: String, line_col: Color, is_percentage: bool) -> void:
	var w: float = ctrl.size.x
	var h: float = ctrl.size.y
	if w <= 10.0 or h <= 10.0:
		return

	var margin_left: float = 44.0
	var margin_right: float = 24.0
	var margin_top: float = 22.0
	var margin_bottom: float = 28.0

	var chart_w: float = maxf(10.0, w - margin_left - margin_right)
	var chart_h: float = maxf(10.0, h - margin_top - margin_bottom)

	# Chart Background Box
	ctrl.draw_rect(Rect2(margin_left, margin_top, chart_w, chart_h), Color(0.05, 0.07, 0.11, 0.95), true)
	ctrl.draw_rect(Rect2(margin_left, margin_top, chart_w, chart_h), Color(0.18, 0.25, 0.38, 0.7), false, 1.0)

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 11

	if data.is_empty():
		ctrl.draw_string(font, Vector2(margin_left + chart_w * 0.5 - 60.0, margin_top + chart_h * 0.5 + 4.0), "No race data recorded", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.5, 0.6, 0.75))
		return

	var min_val: float = 0.0
	var max_val: float = 100.0

	if is_percentage:
		min_val = 60.0
		max_val = 100.0
		for pt in data:
			if pt < min_val:
				min_val = maxf(0.0, floorf(pt / 10.0) * 10.0)
	else:
		min_val = 0.0
		var max_data: float = 0.0
		for pt in data:
			if pt > max_data:
				max_data = pt
		max_val = maxf(80.0, ceilf((max_data + 10.0) / 20.0) * 20.0)

	var range_val: float = maxf(1.0, max_val - min_val)

	# Draw 4 horizontal gridlines
	for i in range(5):
		var ratio: float = float(i) / 4.0
		var val: float = min_val + (ratio * range_val)
		var y_pos: float = margin_top + chart_h - (ratio * chart_h)

		# Horizontal Gridline
		ctrl.draw_line(Vector2(margin_left, y_pos), Vector2(margin_left + chart_w, y_pos), Color(0.14, 0.20, 0.30, 0.6), 1.0)

		# Left Axis Value Label
		var label_str: String = "%d%s" % [int(round(val)), suffix]
		ctrl.draw_string(font, Vector2(4.0, y_pos + 4.0), label_str, HORIZONTAL_ALIGNMENT_RIGHT, 36, font_size, Color(0.55, 0.65, 0.78))

	# Single point handling
	if data.size() == 1:
		var pt_val: float = data[0]
		var norm_y: float = clampf((pt_val - min_val) / range_val, 0.0, 1.0)
		var pt_pos := Vector2(margin_left + (chart_w * 0.5), margin_top + chart_h - (norm_y * chart_h))

		ctrl.draw_circle(pt_pos, 6.0, line_col)
		ctrl.draw_circle(pt_pos, 3.0, Color.WHITE)

		var val_str: String = "%.1f%s" % [pt_val, suffix] if is_percentage else "%d%s" % [int(round(pt_val)), suffix]
		ctrl.draw_string(font, Vector2(pt_pos.x - 30.0, pt_pos.y - 10.0), val_str, HORIZONTAL_ALIGNMENT_CENTER, 60, font_size, Color.WHITE)
		ctrl.draw_string(font, Vector2(margin_left + 10.0, margin_top + chart_h - 10.0), "(1 race recorded — complete more races to view trend)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.45, 0.55, 0.68))
		return

	# Multiple points
	var points_pos: PackedVector2Array = []
	var n: int = data.size()
	for i in range(n):
		var x_ratio: float = float(i) / float(n - 1)
		var x_pos: float = margin_left + (x_ratio * chart_w)
		var norm_y: float = clampf((data[i] - min_val) / range_val, 0.0, 1.0)
		var y_pos: float = margin_top + chart_h - (norm_y * chart_h)
		points_pos.append(Vector2(x_pos, y_pos))

		# Bottom X-Axis Race label
		var x_lbl: String = "R%d" % (i + 1)
		ctrl.draw_string(font, Vector2(x_pos - 15.0, margin_top + chart_h + 18.0), x_lbl, HORIZONTAL_ALIGNMENT_CENTER, 30, 10, Color(0.55, 0.65, 0.78))

	# Connect with antialiased line
	for i in range(points_pos.size() - 1):
		ctrl.draw_line(points_pos[i], points_pos[i + 1], line_col, 2.5, true)

	# Dots & values
	for i in range(points_pos.size()):
		var p := points_pos[i]
		# Outer glowing halo
		ctrl.draw_circle(p, 5.0, line_col)
		# Inner white core
		ctrl.draw_circle(p, 2.5, Color.WHITE)

		# Text value above point
		var v: float = data[i]
		var val_str: String = "%.0f%s" % [v, suffix] if is_percentage else "%d" % int(round(v))
		ctrl.draw_string(font, Vector2(p.x - 20.0, p.y - 8.0), val_str, HORIZONTAL_ALIGNMENT_CENTER, 40, 10, Color(0.92, 0.96, 1.0))

# --- 4. Achievement Showcase ---

func _populate_achievement_showcase(all_progress: Array[Dictionary]) -> void:
	if not ach_showcase_container:
		return

	for child in ach_showcase_container.get_children():
		child.queue_free()

	var total_count: int = all_progress.size()
	var unlocked_list: Array[Dictionary] = []

	for ach in all_progress:
		if ach.get("is_unlocked", false):
			unlocked_list.append(ach)

	var unlocked_count: int = unlocked_list.size()
	var pct: int = int((float(unlocked_count) / float(maxi(1, total_count))) * 100.0)

	if ach_summary_label:
		ach_summary_label.text = "UNLOCKED: %d / %d  (%d%% COMPLETE)" % [unlocked_count, total_count, pct]

	if unlocked_count == 0:
		if ach_empty_box:
			ach_empty_box.visible = true
		ach_showcase_container.visible = false
		return

	if ach_empty_box:
		ach_empty_box.visible = false
	ach_showcase_container.visible = true

	# Sort unlocked achievements by timestamp descending (most recently unlocked first)
	unlocked_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("timestamp", 0)) > int(b.get("timestamp", 0))
	)

	# Display up to 4 featured/recent achievements
	var display_count: int = mini(4, unlocked_list.size())
	for i in range(display_count):
		var ach: Dictionary = unlocked_list[i]
		_create_showcase_card(ach)

func _create_showcase_card(ach: Dictionary) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(180, 80)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	style.border_color = Color(1.0, 0.74, 0.15, 0.8) # Gold
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = str(ach.get("icon", "🏆"))
	icon_lbl.add_theme_font_size_override("font_size", 26)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = str(ach.get("name", "Achievement"))
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	vbox.add_child(name_lbl)

	var rew_lbl := Label.new()
	rew_lbl.text = "+%d XP" % int(ach.get("reward_xp", 0))
	rew_lbl.add_theme_font_size_override("font_size", 11)
	rew_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.45))
	vbox.add_child(rew_lbl)

	var date_lbl := Label.new()
	var d_str: String = str(ach.get("unlocked_at", ""))
	date_lbl.text = d_str if not d_str.is_empty() else "Unlocked"
	date_lbl.add_theme_font_size_override("font_size", 10)
	date_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.82))
	vbox.add_child(date_lbl)

	ach_showcase_container.add_child(card)

# --- 5. Recent Race History (Last 5 Races) ---

func _populate_recent_races(recent_races: Array[Dictionary]) -> void:
	if not recent_races_list:
		return

	for child in recent_races_list.get_children():
		child.queue_free()

	if recent_races.is_empty():
		if races_empty_box:
			races_empty_box.visible = true
		recent_races_list.visible = false
		return

	if races_empty_box:
		races_empty_box.visible = false
	recent_races_list.visible = true

	# Display up to 5 most recent races
	var count: int = mini(5, recent_races.size())
	for i in range(count):
		_create_race_history_row(recent_races[i])

func _create_race_history_row(race: Dictionary) -> void:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.10, 0.15, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	# Date
	var date_lbl := Label.new()
	date_lbl.custom_minimum_size = Vector2(130, 0)
	date_lbl.text = str(race.get("date", "--"))
	date_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.88))
	date_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(date_lbl)

	# Difficulty
	var diff_lbl := Label.new()
	diff_lbl.custom_minimum_size = Vector2(80, 0)
	var diff_str: String = str(race.get("difficulty", "Medium"))
	diff_lbl.text = diff_str
	diff_lbl.add_theme_font_size_override("font_size", 13)
	match diff_str:
		"Easy": diff_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 0.4))
		"Medium": diff_lbl.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		"Hard": diff_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		_: diff_lbl.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(diff_lbl)

	# Position / Rank
	var pos_lbl := Label.new()
	pos_lbl.custom_minimum_size = Vector2(80, 0)
	var pos: int = int(race.get("position", 1))
	match pos:
		1:
			pos_lbl.text = "🥇 1st Place"
			pos_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.1))
		2:
			pos_lbl.text = "🥈 2nd Place"
			pos_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		3:
			pos_lbl.text = "🥉 3rd Place"
			pos_lbl.add_theme_color_override("font_color", Color(0.85, 0.6, 0.4))
		_:
			pos_lbl.text = "🏁 4th Place"
			pos_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	pos_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(pos_lbl)

	# WPM
	var wpm_lbl := Label.new()
	wpm_lbl.custom_minimum_size = Vector2(85, 0)
	wpm_lbl.text = "%d WPM" % int(round(float(race.get("wpm", 0.0))))
	wpm_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	wpm_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(wpm_lbl)

	# Accuracy
	var acc_lbl := Label.new()
	acc_lbl.custom_minimum_size = Vector2(75, 0)
	acc_lbl.text = "%.1f%%" % float(race.get("accuracy", 100.0))
	acc_lbl.add_theme_color_override("font_color", Color(0.35, 0.9, 0.45))
	acc_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(acc_lbl)

	# Time
	var time_lbl := Label.new()
	time_lbl.custom_minimum_size = Vector2(80, 0)
	time_lbl.text = "%.2fs" % float(race.get("race_time", 0.0))
	time_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	time_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(time_lbl)

	# XP Earned
	var xp_lbl := Label.new()
	xp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var earned: int = int(race.get("xp_earned", 0))
	xp_lbl.text = "+%d XP" % earned if earned > 0 else ""
	xp_lbl.add_theme_color_override("font_color", Color(0.98, 0.55, 0.15))
	xp_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(xp_lbl)

	recent_races_list.add_child(row)

# --- 6. Navigation Actions ---

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")

func _on_achievements_pressed() -> void:
	if is_instance_valid(GameManager):
		GameManager.set_return_screen("res://scenes/career.tscn")
	get_tree().change_scene_to_file.call_deferred("res://scenes/achievements.tscn")

func _on_full_history_pressed() -> void:
	if is_instance_valid(GameManager):
		GameManager.set_return_screen("res://scenes/career.tscn")
	get_tree().change_scene_to_file.call_deferred("res://scenes/statistics.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

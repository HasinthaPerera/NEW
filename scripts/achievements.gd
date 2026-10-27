extends Control

@onready var unlocked_counter_label: Label = %UnlockedCounterLabel
@onready var total_xp_badge: Label = %TotalXpBadge
@onready var achievements_list: VBoxContainer = %AchievementsList
@onready var back_button: Button = %BackButton
@onready var stats_button: Button = %StatsButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	if stats_button:
		stats_button.pressed.connect(_on_stats_pressed)
	back_button.grab_focus()

	# Listen for any live achievement unlocks while screen is open
	if is_instance_valid(GameManager):
		if not GameManager.achievement_unlocked.is_connected(_on_achievement_unlocked):
			GameManager.achievement_unlocked.connect(_on_achievement_unlocked)

	_populate_achievements()

func _populate_achievements() -> void:
	if not is_instance_valid(GameManager):
		return

	# Clear previous items
	for child in achievements_list.get_children():
		child.queue_free()

	var all_progress: Array[Dictionary] = GameManager.get_all_achievements_progress()
	var total_count: int = all_progress.size()
	var unlocked_count: int = 0
	var total_earned_ach_xp: int = 0

	for item in all_progress:
		if item.get("is_unlocked", false):
			unlocked_count += 1
			total_earned_ach_xp += int(item.get("reward_xp", 0))

	# Update Top Stats
	var pct: int = int((float(unlocked_count) / float(maxi(1, total_count))) * 100.0)
	if unlocked_counter_label:
		unlocked_counter_label.text = "UNLOCKED: %d / %d  (%d%%)" % [unlocked_count, total_count, pct]

	if total_xp_badge:
		var career := GameManager.get_career_stats()
		total_xp_badge.text = "LEVEL %d  •  %d TOTAL XP  •  +%d XP FROM ACHIEVEMENTS" % [
			career.get("level", 1),
			career.get("total_xp", 0),
			total_earned_ach_xp
		]

	# Build Achievement Cards
	for item in all_progress:
		_create_achievement_card(item)

func _create_achievement_card(ach: Dictionary) -> void:
	var is_unlocked: bool = ach.get("is_unlocked", false)
	var ach_id: String = ach.get("id", "")
	var ach_name: String = ach.get("name", "Achievement")
	var ach_desc: String = ach.get("description", "")
	var ach_icon: String = ach.get("icon", "🏆")
	var reward_xp: int = int(ach.get("reward_xp", 0))
	var unlocked_at: String = ach.get("unlocked_at", "")
	var progress_ratio: float = float(ach.get("progress_ratio", 0.0))
	var progress_text: String = ach.get("progress_text", "")

	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.content_margin_left = 16
	card_style.content_margin_right = 16
	card_style.content_margin_top = 12
	card_style.content_margin_bottom = 12

	if is_unlocked:
		card_style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
		card_style.border_color = Color(1.0, 0.74, 0.15, 0.85) # Gold
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.shadow_color = Color(1.0, 0.65, 0.1, 0.25)
		card_style.shadow_size = 6
	else:
		card_style.bg_color = Color(0.06, 0.08, 0.11, 0.75)
		card_style.border_color = Color(0.18, 0.24, 0.35, 0.6)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1

	card.add_theme_stylebox_override("panel", card_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)

	# 1. Left Icon Badge
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(56, 56)
	var icon_style := StyleBoxFlat.new()
	icon_style.corner_radius_top_left = 8
	icon_style.corner_radius_top_right = 8
	icon_style.corner_radius_bottom_left = 8
	icon_style.corner_radius_bottom_right = 8

	if is_unlocked:
		icon_style.bg_color = Color(0.22, 0.18, 0.05, 0.9)
		icon_style.border_color = Color(1.0, 0.8, 0.2, 0.8)
		icon_style.border_width_left = 1
		icon_style.border_width_top = 1
		icon_style.border_width_right = 1
		icon_style.border_width_bottom = 1
	else:
		icon_style.bg_color = Color(0.1, 0.12, 0.16, 0.9)
		icon_style.border_color = Color(0.22, 0.28, 0.38, 0.6)
		icon_style.border_width_left = 1
		icon_style.border_width_top = 1
		icon_style.border_width_right = 1
		icon_style.border_width_bottom = 1

	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var icon_lbl := Label.new()
	icon_lbl.text = ach_icon if is_unlocked else "🔒"
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_panel.add_child(icon_lbl)
	hbox.add_child(icon_panel)

	# 2. Middle Content (Name, Description, Progress/Unlock Date)
	var mid_vbox := VBoxContainer.new()
	mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(mid_vbox)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	mid_vbox.add_child(title_row)

	var name_lbl := Label.new()
	name_lbl.text = ach_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	if is_unlocked:
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	title_row.add_child(name_lbl)

	# Status tag
	var status_tag := Label.new()
	status_tag.add_theme_font_size_override("font_size", 11)
	if is_unlocked:
		status_tag.text = "✔ UNLOCKED"
		status_tag.add_theme_color_override("font_color", Color(0.25, 0.9, 0.45))
	else:
		status_tag.text = "LOCKED"
		status_tag.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	title_row.add_child(status_tag)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = ach_desc
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.88))
	mid_vbox.add_child(desc_lbl)

	# Bottom progress or unlock date
	if is_unlocked:
		var date_lbl := Label.new()
		var date_text := "Unlocked: " + unlocked_at if not unlocked_at.is_empty() else "Unlocked"
		date_lbl.text = date_text
		date_lbl.add_theme_font_size_override("font_size", 12)
		date_lbl.add_theme_color_override("font_color", Color(0.35, 0.8, 0.55))
		mid_vbox.add_child(date_lbl)
	else:
		var progress_row := HBoxContainer.new()
		progress_row.add_theme_constant_override("separation", 10)
		mid_vbox.add_child(progress_row)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(180, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 100.0
		bar.value = progress_ratio * 100.0
		bar.show_percentage = false

		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.12, 0.16, 0.22, 1.0)
		bar_bg.corner_radius_top_left = 4
		bar_bg.corner_radius_top_right = 4
		bar_bg.corner_radius_bottom_left = 4
		bar_bg.corner_radius_bottom_right = 4
		bar.add_theme_stylebox_override("background", bar_bg)

		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.18, 0.65, 0.95, 1.0)
		bar_fill.corner_radius_top_left = 4
		bar_fill.corner_radius_top_right = 4
		bar_fill.corner_radius_bottom_left = 4
		bar_fill.corner_radius_bottom_right = 4
		bar.add_theme_stylebox_override("fill", bar_fill)
		progress_row.add_child(bar)

		var prog_lbl := Label.new()
		prog_lbl.text = progress_text
		prog_lbl.add_theme_font_size_override("font_size", 12)
		prog_lbl.add_theme_color_override("font_color", Color(0.55, 0.68, 0.82))
		progress_row.add_child(prog_lbl)

	# 3. Right XP Reward Badge
	var reward_panel := PanelContainer.new()
	reward_panel.custom_minimum_size = Vector2(110, 42)
	reward_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rew_style := StyleBoxFlat.new()
	rew_style.corner_radius_top_left = 8
	rew_style.corner_radius_top_right = 8
	rew_style.corner_radius_bottom_left = 8
	rew_style.corner_radius_bottom_right = 8
	rew_style.content_margin_left = 12
	rew_style.content_margin_right = 12
	rew_style.content_margin_top = 6
	rew_style.content_margin_bottom = 6

	if is_unlocked:
		rew_style.bg_color = Color(0.08, 0.22, 0.12, 0.9)
		rew_style.border_color = Color(0.25, 0.9, 0.45, 0.8)
		rew_style.border_width_left = 1
		rew_style.border_width_top = 1
		rew_style.border_width_right = 1
		rew_style.border_width_bottom = 1
	else:
		rew_style.bg_color = Color(0.12, 0.16, 0.24, 0.9)
		rew_style.border_color = Color(0.25, 0.35, 0.5, 0.7)
		rew_style.border_width_left = 1
		rew_style.border_width_top = 1
		rew_style.border_width_right = 1
		rew_style.border_width_bottom = 1

	reward_panel.add_theme_stylebox_override("panel", rew_style)

	var rew_lbl := Label.new()
	rew_lbl.text = "+%d XP" % reward_xp
	rew_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rew_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rew_lbl.add_theme_font_size_override("font_size", 14)
	if is_unlocked:
		rew_lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5))
	else:
		rew_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2))
	reward_panel.add_child(rew_lbl)
	hbox.add_child(reward_panel)

	achievements_list.add_child(card)

func _on_achievement_unlocked(_id: String, _data: Dictionary) -> void:
	_populate_achievements()

func _on_back_pressed() -> void:
	var target: String = GameManager.get_return_screen("res://scenes/main_menu.tscn") if is_instance_valid(GameManager) else "res://scenes/main_menu.tscn"
	get_tree().change_scene_to_file.call_deferred(target)

func _on_stats_pressed() -> void:
	if ResourceLoader.exists("res://scenes/statistics.tscn"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/statistics.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

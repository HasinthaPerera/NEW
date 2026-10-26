extends CanvasLayer
class_name RacingHUD

signal input_text_changed(new_text: String)
signal restart_requested
signal menu_requested
signal difficulty_changed(new_difficulty: String)

@onready var sentence_display: RichTextLabel = $RootControl/TypingPanel/VBox/SentenceDisplay
@onready var input_line: LineEdit = $RootControl/TypingPanel/VBox/InputLine
@onready var speed_label: Label = $RootControl/TopPanel/HBox/SpeedBox/SpeedLabel
@onready var speed_bar: ProgressBar = $RootControl/TopPanel/HBox/SpeedBox/SpeedBar
@onready var distance_label: Label = $RootControl/TopPanel/HBox/DistanceBox/DistanceLabel
@onready var distance_bar: ProgressBar = $RootControl/TopPanel/HBox/DistanceBox/DistanceBar
@onready var pos_label: Label = $RootControl/TopPanel/HBox/PositionBox/PosLabel
@onready var diff_option: OptionButton = $RootControl/TopPanel/HBox/DifficultyBox/DiffOption
@onready var nitro_badge: PanelContainer = $RootControl/NitroBadge
@onready var nitro_timer_label: Label = $RootControl/NitroBadge/NitroTimerLabel
@onready var typing_panel: PanelContainer = $RootControl/TypingPanel

# Countdown
@onready var countdown_label: Label = $RootControl/CountdownOverlay/CountdownLabel
@onready var countdown_overlay: Control = $RootControl/CountdownOverlay

# Results Modal
@onready var results_modal: PanelContainer = $RootControl/ResultsModal
@onready var results_title: Label = $RootControl/ResultsModal/Margin/VBox/ResultsTitle
@onready var standings_container: VBoxContainer = $RootControl/ResultsModal/Margin/VBox/StandingsContainer
@onready var player_stats_label: Label = $RootControl/ResultsModal/Margin/VBox/PlayerStatsLabel
@onready var level_up_banner: PanelContainer = $RootControl/ResultsModal/Margin/VBox/LevelUpBanner
@onready var level_up_label: Label = $RootControl/ResultsModal/Margin/VBox/LevelUpBanner/LevelUpLabel
@onready var xp_rewards_box: PanelContainer = $RootControl/ResultsModal/Margin/VBox/XpRewardsBox
@onready var total_xp_earned_label: Label = $RootControl/ResultsModal/Margin/VBox/XpRewardsBox/VBox/HeaderHBox/TotalXpEarnedLabel
@onready var xp_breakdown_label: Label = $RootControl/ResultsModal/Margin/VBox/XpRewardsBox/VBox/XpBreakdownLabel
@onready var player_level_label: Label = $RootControl/ResultsModal/Margin/VBox/XpRewardsBox/VBox/PlayerLevelLabel
@onready var restart_button: Button = $RootControl/ResultsModal/Margin/VBox/ButtonBox/RestartButton
@onready var menu_button: Button = $RootControl/ResultsModal/Margin/VBox/ButtonBox/MenuButton

var is_race_ended: bool = false
var is_counting_down: bool = false
var input_shake_timer: float = 0.0

func _ready() -> void:
	results_modal.visible = false
	nitro_badge.visible = false
	countdown_overlay.visible = false
	input_line.text_changed.connect(_on_line_edit_text_changed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)

	_setup_difficulty_options()
	_ensure_input_focus()

func _setup_difficulty_options() -> void:
	if not diff_option:
		return
	diff_option.clear()
	diff_option.add_item("Easy (Casual)")
	diff_option.add_item("Medium (Normal)")
	diff_option.add_item("Hard (Expert)")
	diff_option.selected = 1 # Default to Medium
	diff_option.item_selected.connect(_on_difficulty_selected)

func _on_difficulty_selected(index: int) -> void:
	var diff_name := "Medium"
	match index:
		0: diff_name = "Easy"
		1: diff_name = "Medium"
		2: diff_name = "Hard"
	difficulty_changed.emit(diff_name)
	_ensure_input_focus()

func _process(delta: float) -> void:
	if not is_race_ended and not is_counting_down:
		if not input_line.has_focus():
			input_line.grab_focus()

		# Shake input panel if error was made
		if input_shake_timer > 0.0:
			input_shake_timer -= delta
			var shake_offset := sin(Time.get_ticks_msec() * 0.08) * 6.0
			typing_panel.position.x = (typing_panel.get_parent_control().size.x - typing_panel.size.x) * 0.5 + shake_offset
		else:
			typing_panel.position.x = (typing_panel.get_parent_control().size.x - typing_panel.size.x) * 0.5

func _ensure_input_focus() -> void:
	if not is_counting_down and not is_race_ended:
		input_line.grab_focus()

func _on_line_edit_text_changed(new_text: String) -> void:
	if is_counting_down or is_race_ended:
		input_line.text = ""
		return
	input_text_changed.emit(new_text)

func clear_input() -> void:
	input_line.text = ""

func set_countdown(countdown_text: String, is_go: bool = false) -> void:
	is_counting_down = not is_go
	countdown_overlay.visible = true
	countdown_label.text = countdown_text

	if is_go:
		countdown_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.35))
	else:
		countdown_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.2))

func hide_countdown() -> void:
	is_counting_down = false
	countdown_overlay.visible = false
	_ensure_input_focus()

func update_sentence_display(target: String, typed: String, has_error: bool) -> void:
	var bb := ""
	var target_len := target.length()
	var typed_len := typed.length()

	# Visual color indicator in the input field
	if has_error:
		input_line.add_theme_color_override("font_color", Color(0.96, 0.28, 0.28))
	else:
		input_line.add_theme_color_override("font_color", Color(0.25, 0.90, 0.45))

	var typed_matching := true

	for i in range(target_len):
		var target_char := target.substr(i, 1)
		var escaped_char := target_char
		if target_char == "[":
			escaped_char = "[lb]"
		elif target_char == "]":
			escaped_char = "[rb]"

		if i < typed_len:
			var typed_char := typed.substr(i, 1)
			if typed_matching and typed_char == target_char:
				# Correct character: green
				bb += "[color=#22c55e]" + escaped_char + "[/color]"
			else:
				# Incorrect character: red
				typed_matching = false
				var display_symbol := escaped_char if target_char != " " else "_"
				bb += "[color=#ffffff][bgcolor=#dc2626]" + display_symbol + "[/bgcolor][/color]"
		elif i == typed_len:
			# Cursor character to type next
			if typed_matching:
				bb += "[color=#f59e0b][u]" + escaped_char + "[/u][/color]"
			else:
				bb += "[color=#64748b]" + escaped_char + "[/color]"
		else:
			# Remaining untyped text
			bb += "[color=#94a3b8]" + escaped_char + "[/color]"

	if typed_len > target_len:
		var extra := typed.substr(target_len)
		bb += " [color=#ffffff][bgcolor=#b91c1c][i]+" + extra + "[/i][/bgcolor][/color]"

	sentence_display.text = bb

func show_typing_error_effect() -> void:
	input_shake_timer = 0.22

func update_player_position(rank: int, total_cars: int = 4) -> void:
	var suffix := "th"
	match rank:
		1: suffix = "st"
		2: suffix = "nd"
		3: suffix = "rd"

	pos_label.text = "%d%s / %d" % [rank, suffix, total_cars]

	match rank:
		1:
			pos_label.add_theme_color_override("font_color", Color(0.98, 0.78, 0.15)) # Gold
		2:
			pos_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.96)) # Silver
		3:
			pos_label.add_theme_color_override("font_color", Color(0.85, 0.55, 0.25)) # Bronze
		_:
			pos_label.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78)) # 4th

func update_speed(current_kmh: float, max_kmh: float, is_nitro: bool) -> void:
	speed_label.text = "%d KM/H" % int(round(current_kmh))
	speed_bar.max_value = max_kmh
	speed_bar.value = current_kmh

	if is_nitro:
		speed_label.add_theme_color_override("font_color", Color(0.96, 0.72, 0.15))
	else:
		speed_label.add_theme_color_override("font_color", Color(0.22, 0.75, 0.98))

func update_distance(current_distance: float, total_distance: float) -> void:
	var clamped := clampf(current_distance, 0.0, total_distance)
	var remaining := maxf(0.0, total_distance - clamped)
	distance_label.text = "TRACK: %dm / %dm  (REMAINING: %dm)" % [int(clamped), int(total_distance), int(remaining)]
	distance_bar.max_value = total_distance
	distance_bar.value = clamped

func set_nitro_active(active: bool, time_left: float) -> void:
	nitro_badge.visible = active
	if active:
		nitro_timer_label.text = "NITRO BOOST: %.1fs" % time_left

func show_race_results(standings: Array, player_stats: Dictionary, xp_info: Dictionary = {}) -> void:
	is_race_ended = true
	input_line.editable = false
	results_modal.visible = true

	# Clear previous standing rows
	for child in standings_container.get_children():
		child.queue_free()

	var player_rank: int = player_stats.get("rank", 1)
	match player_rank:
		1: results_title.text = "🏆 VICTORY! 1st PLACE! 🏆"
		2: results_title.text = "🥈 2nd PLACE FINISH! 🥈"
		3: results_title.text = "🥉 3rd PLACE FINISH! 🥉"
		_: results_title.text = "🏁 4th PLACE FINISH 🏁"

	# Build Standings Table
	for entry in standings:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)

		var rank_lbl := Label.new()
		rank_lbl.custom_minimum_size = Vector2(50, 0)
		var rank_num: int = entry.get("rank", 0)
		var medal := "🏁"
		match rank_num:
			1: medal = "🥇 1st"
			2: medal = "🥈 2nd"
			3: medal = "🥉 3rd"
			_: medal = "   4th"
		rank_lbl.text = medal
		rank_lbl.add_theme_font_size_override("font_size", 18)

		var name_lbl := Label.new()
		name_lbl.custom_minimum_size = Vector2(200, 0)
		var is_player: bool = entry.get("is_player", false)
		name_lbl.text = entry.get("name", "Racer")
		name_lbl.add_theme_font_size_override("font_size", 18)
		if is_player:
			name_lbl.add_theme_color_override("font_color", Color(0.3, 0.75, 1.0))
		else:
			name_lbl.add_theme_color_override("font_color", entry.get("color", Color.WHITE))

		var time_lbl := Label.new()
		time_lbl.custom_minimum_size = Vector2(100, 0)
		var r_time: float = entry.get("time", 0.0)
		time_lbl.text = "%.2fs" % r_time if r_time > 0.0 else "Finished"
		time_lbl.add_theme_font_size_override("font_size", 18)
		time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		row.add_child(rank_lbl)
		row.add_child(name_lbl)
		row.add_child(time_lbl)
		standings_container.add_child(row)

	# Player Typing Summary
	var rank_val: int = player_stats.get("rank", 1)
	var time_val: float = player_stats.get("time", 0.0)
	var speed_val: float = player_stats.get("top_speed", 0.0)
	var wpm_val: float = player_stats.get("wpm", 0.0)
	var acc_val: float = player_stats.get("accuracy", 100.0)

	var rank_str := "4th Place"
	match rank_val:
		1: rank_str = "1st Place 🏆"
		2: rank_str = "2nd Place 🥈"
		3: rank_str = "3rd Place 🥉"

	player_stats_label.text = "FINAL POSITION: %s   |   RACE TIME: %.2fs\nTYPING SPEED: %d WPM   |   ACCURACY: %.1f%%" % [
		rank_str, time_val, int(round(wpm_val)), acc_val
	]

	# XP Rewards Breakdown & Leveling
	if xp_info.is_empty() and is_instance_valid(GameManager):
		xp_info = GameManager.last_race_xp

	if xp_rewards_box:
		if xp_info.is_empty():
			xp_rewards_box.visible = false
			if level_up_banner:
				level_up_banner.visible = false
		else:
			xp_rewards_box.visible = true
			var comp_xp: int = xp_info.get("completion_xp", 100)
			var pos_xp: int = xp_info.get("position_xp", 0)
			var acc_xp: int = xp_info.get("accuracy_xp", 0)
			var diff_xp: int = xp_info.get("difficulty_xp", 0)
			var total_earned: int = xp_info.get("total_xp_earned", 0)
			var cur_lvl: int = xp_info.get("current_level", 1)
			var title_str: String = xp_info.get("title", "Rookie Racer")
			var leveled_up: bool = xp_info.get("leveled_up", false)
			var levels_gained: int = xp_info.get("levels_gained", 0)
			var prev_lvl: int = xp_info.get("prev_level", 1)

			if total_xp_earned_label:
				total_xp_earned_label.text = "+%d XP EARNED" % total_earned

			if xp_breakdown_label:
				xp_breakdown_label.text = "Finish: +%d XP  •  Position: +%d XP  •  Accuracy: +%d XP  •  Difficulty: +%d XP" % [
					comp_xp, pos_xp, acc_xp, diff_xp
				]

			if player_level_label:
				var cur_xp: int = xp_info.get("current_level_xp", 0)
				var next_cost: int = xp_info.get("next_level_cost", 100)
				var xp_needed: int = xp_info.get("xp_needed", 100)
				player_level_label.text = "CURRENT RANK: Level %d — %s  (%d / %d XP, %d XP to Level %d)" % [
					cur_lvl, title_str, cur_xp, next_cost, xp_needed, cur_lvl + 1
				]

			if level_up_banner and level_up_label:
				if leveled_up:
					level_up_banner.visible = true
					if levels_gained > 1:
						level_up_label.text = "🎉 MULTI-LEVEL UP! Level %d ➔ Level %d — %s! 🎉" % [
							prev_lvl, cur_lvl, title_str
						]
					else:
						level_up_label.text = "🎉 LEVEL UP! You reached Level %d — %s! 🎉" % [
							cur_lvl, title_str
						]
				else:
					level_up_banner.visible = false

	restart_button.grab_focus()

func reset_hud() -> void:
	is_race_ended = false
	results_modal.visible = false
	if level_up_banner:
		level_up_banner.visible = false
	if xp_rewards_box:
		xp_rewards_box.visible = false
	nitro_badge.visible = false
	input_line.editable = true
	input_line.text = ""
	_ensure_input_focus()

func _on_restart_button_pressed() -> void:
	restart_requested.emit()

func _on_menu_button_pressed() -> void:
	menu_requested.emit()

func set_difficulty_display(diff_name: String) -> void:
	if not diff_option:
		return
	match diff_name:
		"Easy": diff_option.selected = 0
		"Medium": diff_option.selected = 1
		"Hard": diff_option.selected = 2

func _unhandled_input(event: InputEvent) -> void:
	if is_race_ended:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			restart_requested.emit()
		elif event.is_action_pressed("ui_cancel"):
			menu_requested.emit()

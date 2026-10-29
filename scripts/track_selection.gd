extends Control

# Track Selection Controller
# Allows players to select a track circuit before racing, displaying track details,
# environment types, race length, and coming-soon statuses.

@onready var title_label: Label = %ScreenTitle
@onready var car_badge_label: Label = %CarBadgeLabel
@onready var diff_badge_label: Label = %DiffBadgeLabel

# Track Card Elements
@onready var card_metro: PanelContainer = %CardMetro
@onready var btn_metro: Button = %BtnSelectMetro

@onready var card_desert: PanelContainer = %CardDesert
@onready var btn_desert: Button = %BtnSelectDesert

@onready var card_forest: PanelContainer = %CardForest
@onready var btn_forest: Button = %BtnSelectForest

# Detail & Action Controls
@onready var selected_track_title: Label = %SelectedTrackTitle
@onready var selected_track_meta: Label = %SelectedTrackMeta
@onready var selected_track_desc: Label = %SelectedTrackDesc

@onready var start_race_button: Button = %StartRaceButton
@onready var back_button: Button = %BackButton

var selected_track_id: String = "metro_sprint"

func _get_gm() -> Node:
	return get_node_or_null("/root/GameManager")

func _ready() -> void:
	var gm = _get_gm()
	if is_instance_valid(gm):
		selected_track_id = gm.selected_track_id
		# Ensure selected track is valid and playable; fallback to metro_sprint
		if not gm.is_track_playable(selected_track_id):
			selected_track_id = "metro_sprint"
			gm.set_track(selected_track_id)
	else:
		selected_track_id = "metro_sprint"

	_update_context_badges()
	_update_track_cards_ui()
	_connect_signals()

	if start_race_button:
		start_race_button.grab_focus()

func _update_context_badges() -> void:
	var gm = _get_gm()
	if not is_instance_valid(gm):
		return

	if car_badge_label:
		car_badge_label.text = "CAR: %s" % gm.selected_color_name.to_upper()
		car_badge_label.add_theme_color_override("font_color", gm.player_car_color)

	if diff_badge_label:
		var diff: String = gm.ai_difficulty.to_upper()
		diff_badge_label.text = "DIFFICULTY: %s" % diff
		match diff:
			"EASY": diff_badge_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
			"HARD": diff_badge_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
			_: diff_badge_label.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0))

func _connect_signals() -> void:
	if btn_metro:
		btn_metro.pressed.connect(func(): _on_track_card_selected("metro_sprint"))
	if btn_desert:
		btn_desert.pressed.connect(func(): _on_track_card_selected("desert_dash"))
	if btn_forest:
		btn_forest.pressed.connect(func(): _on_track_card_selected("forest_run"))
	if start_race_button:
		start_race_button.pressed.connect(_on_start_race_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _on_track_card_selected(track_id: String) -> void:
	var gm = _get_gm()
	if is_instance_valid(gm):
		if gm.is_track_playable(track_id):
			selected_track_id = track_id
			gm.set_track(track_id)
			_update_track_cards_ui()
		else:
			push_warning("Track '%s' is not playable yet." % track_id)
	else:
		if track_id in ["metro_sprint", "desert_dash"]:
			selected_track_id = track_id
			_update_track_cards_ui()

func _update_track_cards_ui() -> void:
	var gm = _get_gm()

	# Card styling borders for selection highlight
	var selected_border_color := Color(1.0, 0.48, 0.1, 1.0) # Racing Orange
	var normal_border_color := Color(0.18, 0.25, 0.38, 0.7)
	var disabled_border_color := Color(0.14, 0.18, 0.26, 0.5)

	# 1. Metro Sprint
	if card_metro:
		var style: StyleBoxFlat = card_metro.get_theme_stylebox("panel").duplicate()
		if selected_track_id == "metro_sprint":
			style.border_color = selected_border_color
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.shadow_color = Color(1.0, 0.45, 0.1, 0.35)
			style.shadow_size = 12
			if btn_metro:
				btn_metro.text = "✓ SELECTED"
				btn_metro.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			style.border_color = normal_border_color
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.shadow_size = 0
			if btn_metro:
				btn_metro.text = "SELECT TRACK"
				btn_metro.modulate = Color(1.0, 1.0, 1.0, 1.0)
		card_metro.add_theme_stylebox_override("panel", style)

	# 2. Desert Dash
	if card_desert:
		var is_desert_playable: bool = gm.is_track_playable("desert_dash") if is_instance_valid(gm) else true
		var style_desert: StyleBoxFlat = card_desert.get_theme_stylebox("panel").duplicate()
		if is_desert_playable:
			if selected_track_id == "desert_dash":
				style_desert.border_color = selected_border_color
				style_desert.border_width_left = 2
				style_desert.border_width_top = 2
				style_desert.border_width_right = 2
				style_desert.border_width_bottom = 2
				style_desert.shadow_color = Color(1.0, 0.45, 0.1, 0.35)
				style_desert.shadow_size = 12
				if btn_desert:
					btn_desert.disabled = false
					btn_desert.text = "✓ SELECTED"
					btn_desert.modulate = Color(1.2, 1.2, 1.2, 1.0)
			else:
				style_desert.border_color = normal_border_color
				style_desert.border_width_left = 1
				style_desert.border_width_top = 1
				style_desert.border_width_right = 1
				style_desert.border_width_bottom = 1
				style_desert.shadow_size = 0
				if btn_desert:
					btn_desert.disabled = false
					btn_desert.text = "SELECT TRACK"
					btn_desert.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			style_desert.border_color = disabled_border_color
			if btn_desert:
				btn_desert.disabled = true
				btn_desert.text = "🔒 COMING SOON"
				btn_desert.modulate = Color(0.65, 0.65, 0.7, 0.7)
		card_desert.add_theme_stylebox_override("panel", style_desert)

	# 3. Forest Run (Coming Soon)
	if card_forest:
		var style_forest: StyleBoxFlat = card_forest.get_theme_stylebox("panel").duplicate()
		style_forest.border_color = disabled_border_color
		card_forest.add_theme_stylebox_override("panel", style_forest)
		if btn_forest:
			btn_forest.disabled = true
			btn_forest.text = "🔒 COMING SOON"
			btn_forest.modulate = Color(0.65, 0.65, 0.7, 0.7)

	# Update Selected Track Details box
	if is_instance_valid(gm):
		var track_info: Dictionary = gm.get_selected_track()
		var len_disp: String = str(track_info.get("length_display", "500m"))
		if selected_track_title:
			selected_track_title.text = "SELECTED: %s" % str(track_info.get("name", "Metro Sprint")).to_upper()
		if selected_track_meta:
			selected_track_meta.text = "ENVIRONMENT: %s   •   LENGTH: %s (%s)   •   STATUS: %s" % [
				str(track_info.get("environment", "City")).to_upper(),
				str(track_info.get("race_length", "Short")).to_upper(),
				len_disp,
				str(track_info.get("status", "Playable")).to_upper()
			]
		if selected_track_desc:
			selected_track_desc.text = str(track_info.get("description", "Fast urban racing through a modern city."))

	# Enable / disable Start Race button based on track playability
	if start_race_button:
		var can_play := false
		if is_instance_valid(gm):
			can_play = gm.is_track_playable(selected_track_id)
		else:
			can_play = (selected_track_id in ["metro_sprint", "desert_dash"])

		start_race_button.disabled = not can_play
		if can_play:
			start_race_button.text = "🏁  START RACE"
			start_race_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			start_race_button.text = "TRACK NOT AVAILABLE"
			start_race_button.modulate = Color(0.6, 0.6, 0.6, 0.7)

func _on_start_race_pressed() -> void:
	var gm = _get_gm()
	if is_instance_valid(gm):
		if not gm.is_track_playable(selected_track_id):
			push_warning("Selected track '%s' is not playable." % selected_track_id)
			return
		var scene_path: String = gm.get_track_scene_path(selected_track_id)
		get_tree().change_scene_to_file.call_deferred(scene_path)
	else:
		get_tree().change_scene_to_file.call_deferred("res://main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/race_setup.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

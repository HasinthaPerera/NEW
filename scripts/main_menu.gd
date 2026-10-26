extends Node3D

@onready var turntable: Node3D = $Turntable
@onready var car_visuals: SportsCarVisuals = $Turntable/SportsCarVisuals
@onready var play_race_button: Button = $UI/MainMenuPanel/Margin/VBox/MenuButtons/PlayRaceButton
@onready var garage_button: Button = $UI/MainMenuPanel/Margin/VBox/MenuButtons/GarageButton
@onready var stats_button: Button = $UI/MainMenuPanel/Margin/VBox/MenuButtons/StatsButton
@onready var settings_button: Button = $UI/MainMenuPanel/Margin/VBox/MenuButtons/SettingsButton
@onready var exit_button: Button = $UI/MainMenuPanel/Margin/VBox/MenuButtons/ExitButton

@onready var status_badge: Label = $UI/MainMenuPanel/Margin/VBox/StatusBadge

# Settings Modal
@onready var settings_modal: PanelContainer = $UI/SettingsModal
@onready var volume_slider: HSlider = $UI/SettingsModal/Margin/VBox/VolumeRow/VolumeSlider
@onready var volume_value_label: Label = $UI/SettingsModal/Margin/VBox/VolumeRow/VolumeValLabel
@onready var diff_option: OptionButton = $UI/SettingsModal/Margin/VBox/DiffRow/DiffOption
@onready var sound_toggle: CheckButton = $UI/SettingsModal/Margin/VBox/SoundRow/SoundToggle
@onready var close_settings_button: Button = $UI/SettingsModal/Margin/VBox/CloseSettingsButton

var auto_rotate_speed: float = 0.4

func _ready() -> void:
	# Configure car appearance to match saved player choice
	_update_car_display()
	_update_status_badge()

	# Connect main buttons
	play_race_button.pressed.connect(_on_play_race_pressed)
	garage_button.pressed.connect(_on_garage_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Setup settings modal
	_setup_settings_modal()

	# Focus play button by default
	play_race_button.grab_focus()

func _process(delta: float) -> void:
	if turntable:
		turntable.rotate_y(auto_rotate_speed * delta)

func _update_car_display() -> void:
	if car_visuals:
		car_visuals.set_paint_color(GameManager.player_car_color)

func _update_status_badge() -> void:
	if status_badge:
		status_badge.text = "CAR: %s  |  DIFFICULTY: %s" % [
			GameManager.selected_color_name.to_upper(),
			GameManager.ai_difficulty.to_upper()
		]

func _on_play_race_pressed() -> void:
	# Check if Race Setup scene exists, otherwise start Race directly
	if ResourceLoader.exists("res://scenes/race_setup.tscn"):
		get_tree().change_scene_to_file("res://scenes/race_setup.tscn")
	else:
		get_tree().change_scene_to_file("res://main.tscn")

func _on_garage_pressed() -> void:
	if ResourceLoader.exists("res://scenes/garage.tscn"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/garage.tscn")
	else:
		push_warning("Garage scene not yet available.")

func _on_stats_pressed() -> void:
	if ResourceLoader.exists("res://scenes/statistics.tscn"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/statistics.tscn")
	else:
		push_warning("Statistics scene not yet available.")

func _on_settings_pressed() -> void:
	settings_modal.visible = true
	close_settings_button.grab_focus()

func _setup_settings_modal() -> void:
	settings_modal.visible = false

	# Volume
	volume_slider.value = GameManager.music_volume * 100.0
	volume_value_label.text = "%d%%" % int(volume_slider.value)
	volume_slider.value_changed.connect(_on_volume_changed)

	# Sound toggle
	sound_toggle.button_pressed = GameManager.sound_enabled
	sound_toggle.toggled.connect(_on_sound_toggled)

	# Difficulty
	diff_option.clear()
	diff_option.add_item("Easy (Casual)")
	diff_option.add_item("Medium (Normal)")
	diff_option.add_item("Hard (Expert)")
	match GameManager.ai_difficulty:
		"Easy": diff_option.selected = 0
		"Medium": diff_option.selected = 1
		"Hard": diff_option.selected = 2
		_: diff_option.selected = 1
	diff_option.item_selected.connect(_on_difficulty_selected)

	# Close button
	close_settings_button.pressed.connect(_on_close_settings_pressed)

func _on_volume_changed(val: float) -> void:
	volume_value_label.text = "%d%%" % int(val)
	GameManager.set_volume(val / 100.0)

func _on_sound_toggled(toggled_on: bool) -> void:
	GameManager.set_sound_enabled(toggled_on)

func _on_difficulty_selected(idx: int) -> void:
	match idx:
		0: GameManager.set_difficulty("Easy")
		1: GameManager.set_difficulty("Medium")
		2: GameManager.set_difficulty("Hard")
	_update_status_badge()

func _on_close_settings_pressed() -> void:
	settings_modal.visible = false
	settings_button.grab_focus()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_modal.visible:
			_on_close_settings_pressed()

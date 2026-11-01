extends Node3D

@onready var turntable: Node3D = $Turntable
@onready var car_visuals: SportsCarVisuals = $Turntable/SportsCarVisuals
@onready var play_race_button: Button = $UI/MainMenuPanel/Margin/VBox/MenuButtons/PlayRaceButton
@onready var garage_button: Button = $UI/MainMenuPanel/Margin/VBox/MenuButtons/GarageButton
@onready var stats_button: Button = $UI/MainMenuPanel/Margin/VBox/MenuButtons/StatsButton
@onready var achievements_button: Button = $UI/MainMenuPanel/Margin/VBox/MenuButtons/AchievementsButton
@onready var settings_button: Button = $UI/MainMenuPanel/Margin/VBox/MenuButtons/SettingsButton
@onready var exit_button: Button = $UI/MainMenuPanel/Margin/VBox/MenuButtons/ExitButton

@onready var status_badge: Label = $UI/MainMenuPanel/Margin/VBox/StatusBadge

# Settings Modal
@onready var settings_modal: PanelContainer = $UI/SettingsModal
@onready var master_slider: HSlider = $UI/SettingsModal/Margin/VBox/MasterRow/MasterSlider
@onready var master_val_label: Label = $UI/SettingsModal/Margin/VBox/MasterRow/MasterValLabel
@onready var music_slider: HSlider = $UI/SettingsModal/Margin/VBox/MusicRow/MusicSlider
@onready var music_val_label: Label = $UI/SettingsModal/Margin/VBox/MusicRow/MusicValLabel
@onready var sfx_slider: HSlider = $UI/SettingsModal/Margin/VBox/SFXRow/SFXSlider
@onready var sfx_val_label: Label = $UI/SettingsModal/Margin/VBox/SFXRow/SFXValLabel
@onready var music_mute_toggle: CheckButton = $UI/SettingsModal/Margin/VBox/MuteRow/MusicMuteToggle
@onready var sfx_mute_toggle: CheckButton = $UI/SettingsModal/Margin/VBox/MuteRow/SFXMuteToggle
@onready var diff_option: OptionButton = $UI/SettingsModal/Margin/VBox/DiffRow/DiffOption
@onready var close_settings_button: Button = $UI/SettingsModal/Margin/VBox/CloseSettingsButton

# Backward compatibility references
@onready var volume_slider: HSlider = master_slider
@onready var volume_value_label: Label = master_val_label
@onready var sound_toggle: CheckButton = sfx_mute_toggle

var auto_rotate_speed: float = 0.4

func _ready() -> void:
	# Start menu background music
	var am = get_node_or_null("/root/AudioManager")
	if is_instance_valid(am):
		am.play_menu_music()
		am.attach_ui_sounds($UI)

	# Configure car appearance to match saved player choice
	_update_car_display()
	_update_status_badge()

	# Connect main buttons
	play_race_button.pressed.connect(_on_play_race_pressed)
	garage_button.pressed.connect(_on_garage_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
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
	if is_instance_valid(GameManager):
		GameManager.set_return_screen("res://scenes/main_menu.tscn")
	if ResourceLoader.exists("res://scenes/career.tscn"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/career.tscn")
	elif ResourceLoader.exists("res://scenes/statistics.tscn"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/statistics.tscn")
	else:
		push_warning("Career scene not yet available.")

func _on_achievements_pressed() -> void:
	if is_instance_valid(GameManager):
		GameManager.set_return_screen("res://scenes/main_menu.tscn")
	if ResourceLoader.exists("res://scenes/achievements.tscn"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/achievements.tscn")
	else:
		push_warning("Achievements scene not yet available.")

func _on_settings_pressed() -> void:
	settings_modal.visible = true
	close_settings_button.grab_focus()

func _setup_settings_modal() -> void:
	settings_modal.visible = false

	# Master Volume
	master_slider.value = GameManager.master_volume * 100.0
	master_val_label.text = "%d%%" % int(master_slider.value)
	master_slider.value_changed.connect(_on_master_volume_changed)

	# Music Volume
	music_slider.value = GameManager.music_volume * 100.0
	music_val_label.text = "%d%%" % int(music_slider.value)
	music_slider.value_changed.connect(_on_music_volume_changed)

	# SFX Volume
	sfx_slider.value = GameManager.sfx_volume * 100.0
	sfx_val_label.text = "%d%%" % int(sfx_slider.value)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	# Mutes
	music_mute_toggle.button_pressed = GameManager.music_muted
	music_mute_toggle.toggled.connect(_on_music_mute_toggled)

	sfx_mute_toggle.button_pressed = GameManager.sfx_muted
	sfx_mute_toggle.toggled.connect(_on_sfx_mute_toggled)

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

func _on_master_volume_changed(val: float) -> void:
	master_val_label.text = "%d%%" % int(val)
	GameManager.set_master_volume(val / 100.0)

func _on_music_volume_changed(val: float) -> void:
	music_val_label.text = "%d%%" % int(val)
	GameManager.set_music_volume(val / 100.0)

func _on_sfx_volume_changed(val: float) -> void:
	sfx_val_label.text = "%d%%" % int(val)
	GameManager.set_sfx_volume(val / 100.0)

func _on_music_mute_toggled(toggled_on: bool) -> void:
	GameManager.set_music_muted(toggled_on)

func _on_sfx_mute_toggled(toggled_on: bool) -> void:
	GameManager.set_sfx_muted(toggled_on)

func _on_volume_changed(val: float) -> void:
	_on_master_volume_changed(val)

func _on_sound_toggled(toggled_on: bool) -> void:
	_on_sfx_mute_toggled(not toggled_on)

func _on_difficulty_selected(idx: int) -> void:
	match idx:
		0: GameManager.set_difficulty("Easy")
		1: GameManager.set_difficulty("Medium")
		2: GameManager.set_difficulty("Hard")
	var am = get_node_or_null("/root/AudioManager")
	if is_instance_valid(am):
		am.play_ui_click()
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

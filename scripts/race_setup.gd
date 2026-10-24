extends Node3D

@onready var car_pivot: Node3D = $CarPivot
@onready var car_visuals: SportsCarVisuals = $CarPivot/SportsCarVisuals

# Difficulty buttons
@onready var btn_easy: Button = $UI/Panel/Margin/VBox/DiffContainer/DiffGrid/BtnEasy
@onready var btn_medium: Button = $UI/Panel/Margin/VBox/DiffContainer/DiffGrid/BtnMedium
@onready var btn_hard: Button = $UI/Panel/Margin/VBox/DiffContainer/DiffGrid/BtnHard

# Action buttons
@onready var start_race_button: Button = $UI/Panel/Margin/VBox/ActionButtons/StartRaceButton
@onready var customize_button: Button = $UI/Panel/Margin/VBox/ActionButtons/CustomizeButton
@onready var back_button: Button = $UI/Panel/Margin/VBox/ActionButtons/BackButton

# Labels
@onready var car_info_label: Label = $UI/Panel/Margin/VBox/CarInfoLabel
@onready var diff_desc_label: Label = $UI/Panel/Margin/VBox/DiffContainer/DiffDescLabel

var selected_difficulty: String = "Medium"
var auto_rotate_speed: float = 0.35

func _ready() -> void:
	# Setup car visuals based on player choice
	if car_visuals:
		car_visuals.set_paint_color(GameManager.player_car_color)

	if car_info_label:
		car_info_label.text = "SELECTED CAR: %s MUSCLE COUPE" % GameManager.selected_color_name.to_upper()

	selected_difficulty = GameManager.ai_difficulty
	_update_difficulty_ui()

	# Connect buttons
	btn_easy.pressed.connect(func(): _on_difficulty_selected("Easy"))
	btn_medium.pressed.connect(func(): _on_difficulty_selected("Medium"))
	btn_hard.pressed.connect(func(): _on_difficulty_selected("Hard"))

	start_race_button.pressed.connect(_on_start_race_pressed)
	customize_button.pressed.connect(_on_customize_pressed)
	back_button.pressed.connect(_on_back_pressed)

	start_race_button.grab_focus()

func _process(delta: float) -> void:
	if car_pivot:
		car_pivot.rotate_y(auto_rotate_speed * delta)

func _on_difficulty_selected(diff: String) -> void:
	selected_difficulty = diff
	GameManager.set_difficulty(diff)
	_update_difficulty_ui()

func _update_difficulty_ui() -> void:
	var buttons := {"Easy": btn_easy, "Medium": btn_medium, "Hard": btn_hard}
	for d in buttons.keys():
		var btn: Button = buttons[d]
		if not btn:
			continue
		if d == selected_difficulty:
			btn.text = "✓ " + d.to_upper()
			btn.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			btn.text = d.to_upper()
			btn.modulate = Color(0.85, 0.85, 0.85, 0.9)

	if diff_desc_label:
		match selected_difficulty:
			"Easy":
				diff_desc_label.text = "AI Opponents: Casual speed (~40 WPM) • Higher typo rate • Great for beginners"
			"Hard":
				diff_desc_label.text = "AI Opponents: Expert speed (~78 WPM) • Rare typos • Fast acceleration • Real challenge"
			_:
				diff_desc_label.text = "AI Opponents: Balanced speed (~58 WPM) • Standard racing challenge"

func _on_start_race_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _on_customize_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/garage.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

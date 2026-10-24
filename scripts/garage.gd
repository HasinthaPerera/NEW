extends Node3D

@onready var car_pivot: Node3D = $CarPivot
@onready var car_visuals: SportsCarVisuals = $CarPivot/SportsCarVisuals

# UI elements
@onready var color_btn_orange: Button = $UI/Panel/Margin/VBox/ColorSelection/ColorGrid/BtnOrange
@onready var color_btn_blue: Button = $UI/Panel/Margin/VBox/ColorSelection/ColorGrid/BtnBlue
@onready var color_btn_red: Button = $UI/Panel/Margin/VBox/ColorSelection/ColorGrid/BtnRed
@onready var color_btn_green: Button = $UI/Panel/Margin/VBox/ColorSelection/ColorGrid/BtnGreen

@onready var select_button: Button = $UI/Panel/Margin/VBox/ActionButtons/SelectButton
@onready var back_button: Button = $UI/Panel/Margin/VBox/ActionButtons/BackButton
@onready var current_color_label: Label = $UI/Panel/Margin/VBox/CurrentColorLabel
@onready var save_toast: Label = $UI/Panel/Margin/VBox/SaveToast

var preview_color_name: String = "Orange"
var is_dragging: bool = false
var auto_rotate_speed: float = 0.35
var idle_timer: float = 0.0

var color_buttons: Dictionary = {}

func _ready() -> void:
	color_buttons = {
		"Orange": color_btn_orange,
		"Blue": color_btn_blue,
		"Red": color_btn_red,
		"Green": color_btn_green
	}

	# Initialize with current saved color
	preview_color_name = GameManager.selected_color_name
	_apply_color_to_car(preview_color_name)
	_update_button_highlights()

	# Connect color buttons
	color_btn_orange.pressed.connect(func(): _on_color_selected("Orange"))
	color_btn_blue.pressed.connect(func(): _on_color_selected("Blue"))
	color_btn_red.pressed.connect(func(): _on_color_selected("Red"))
	color_btn_green.pressed.connect(func(): _on_color_selected("Green"))

	# Connect actions
	select_button.pressed.connect(_on_select_pressed)
	back_button.pressed.connect(_on_back_pressed)

	save_toast.visible = false
	select_button.grab_focus()

func _process(delta: float) -> void:
	if not is_dragging:
		idle_timer += delta
		# Resume smooth auto-rotation after a short idle delay
		if idle_timer > 0.4 and car_pivot:
			car_pivot.rotate_y(auto_rotate_speed * delta)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse drag rotation
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			if is_dragging:
				idle_timer = 0.0
	elif event is InputEventMouseMotion and is_dragging:
		idle_timer = 0.0
		if car_pivot:
			car_pivot.rotate_y(event.relative.x * 0.008)

	# Keyboard ESC to go back
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

func _on_color_selected(color_name: String) -> void:
	preview_color_name = color_name
	_apply_color_to_car(color_name)
	_update_button_highlights()
	save_toast.visible = false

func _apply_color_to_car(color_name: String) -> void:
	var color: Color = GameManager.get_color_for_name(color_name)
	if car_visuals:
		car_visuals.set_paint_color(color)
	if current_color_label:
		current_color_label.text = "PAINT: %s" % color_name.to_upper()

func _update_button_highlights() -> void:
	for c_name in color_buttons.keys():
		var btn: Button = color_buttons[c_name]
		if not btn:
			continue
		if c_name == preview_color_name:
			btn.text = "✓ " + c_name.to_upper()
			btn.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			btn.text = c_name.to_upper()
			btn.modulate = Color(0.85, 0.85, 0.85, 0.9)

func _on_select_pressed() -> void:
	GameManager.set_car_color_by_name(preview_color_name)
	if save_toast:
		save_toast.text = "✓ %s PAINT SELECTED!" % preview_color_name.to_upper()
		save_toast.visible = true

func _on_back_pressed() -> void:
	# Ensure the previewed color is confirmed if user leaves
	GameManager.set_car_color_by_name(preview_color_name)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

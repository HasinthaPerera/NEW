extends Node3D

@onready var car_pivot: Node3D = $CarPivot
@onready var car_visuals: SportsCarVisuals = $CarPivot/SportsCarVisuals
@onready var neon_ring: MeshInstance3D = $CarPivot/NeonRing

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
var idle_timer: float = 1.0
var drag_angular_velocity: float = 0.0

var color_buttons: Dictionary = {}
var neon_material: StandardMaterial3D

func _ready() -> void:
	color_buttons = {
		"Orange": color_btn_orange,
		"Blue": color_btn_blue,
		"Red": color_btn_red,
		"Green": color_btn_green
	}

	# Setup dynamic neon ring material
	if neon_ring:
		neon_material = StandardMaterial3D.new()
		neon_material.emission_enabled = true
		neon_material.emission_energy_multiplier = 3.5
		neon_ring.material_override = neon_material

	# Restore saved car color from GameManager (defaults to Orange)
	preview_color_name = GameManager.selected_color_name if is_instance_valid(GameManager) else "Orange"
	_apply_color_to_car(preview_color_name)
	_update_button_highlights()

	# Connect color selection buttons
	color_btn_orange.pressed.connect(func(): _on_color_selected("Orange"))
	color_btn_blue.pressed.connect(func(): _on_color_selected("Blue"))
	color_btn_red.pressed.connect(func(): _on_color_selected("Red"))
	color_btn_green.pressed.connect(func(): _on_color_selected("Green"))

	# Connect action buttons
	select_button.pressed.connect(_on_select_pressed)
	back_button.pressed.connect(_on_back_pressed)

	save_toast.visible = false
	select_button.grab_focus()

func _process(delta: float) -> void:
	if not car_pivot:
		return

	if is_dragging:
		idle_timer = 0.0
	else:
		# Apply smooth glide momentum from mouse drag
		if abs(drag_angular_velocity) > 0.0001:
			car_pivot.rotate_y(drag_angular_velocity)
			drag_angular_velocity = lerpf(drag_angular_velocity, 0.0, 7.0 * delta)
		else:
			idle_timer += delta
			# Resume smooth frame-rate independent auto-rotation when idle
			if idle_timer > 0.6:
				car_pivot.rotate_y(auto_rotate_speed * delta)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse drag rotation
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			if is_dragging:
				idle_timer = 0.0
				drag_angular_velocity = 0.0
	elif event is InputEventMouseMotion and is_dragging:
		idle_timer = 0.0
		var rotation_delta: float = event.relative.x * 0.007
		drag_angular_velocity = rotation_delta
		if car_pivot:
			car_pivot.rotate_y(rotation_delta)

	# Keyboard ESC to go back to Main Menu
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

func _on_color_selected(color_name: String) -> void:
	preview_color_name = color_name
	_apply_color_to_car(color_name)
	_update_button_highlights()
	save_toast.visible = false

func _apply_color_to_car(color_name: String) -> void:
	var color: Color = GameManager.get_color_for_name(color_name) if is_instance_valid(GameManager) else Color("#FF791B")
	
	# Update car body paint immediately (leaves black hood, windows, spoiler, tires unchanged)
	if car_visuals:
		car_visuals.set_paint_color(color)
	
	# Update pedestal neon ring to match
	if neon_material:
		neon_material.albedo_color = color
		neon_material.emission = color

	if current_color_label:
		current_color_label.text = "ACTIVE PAINT: %s" % color_name.to_upper()

func _update_button_highlights() -> void:
	for c_name in color_buttons.keys():
		var btn: Button = color_buttons[c_name]
		if not btn:
			continue
		if c_name == preview_color_name:
			btn.text = "✓ " + c_name.to_upper()
			btn.modulate = Color(1.25, 1.25, 1.25, 1.0)
		else:
			btn.text = c_name.to_upper()
			btn.modulate = Color(0.85, 0.85, 0.85, 0.9)

func _on_select_pressed() -> void:
	if is_instance_valid(GameManager):
		GameManager.set_car_color_by_name(preview_color_name)
	if save_toast:
		save_toast.text = "✓ %s CAR SELECTED & SAVED!" % preview_color_name.to_upper()
		save_toast.visible = true

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")

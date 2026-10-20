extends CharacterBody3D
class_name PlayerCar

signal speed_changed(current_kmh: float, max_kmh: float)
signal nitro_status_changed(is_active: bool, time_remaining: float)

@export var max_normal_speed_kmh: float = 125.0
@export var max_nitro_speed_kmh: float = 185.0
@export var acceleration_kmh_per_char: float = 5.5
@export var mistake_penalty_kmh: float = 5.0
@export var natural_drag_kmh: float = 14.0 # Speed loss per second when player stops typing
@export var nitro_duration: float = 3.5
@export var nitro_boost_amount_kmh: float = 40.0

var current_speed_kmh: float = 0.0
var target_speed_kmh: float = 0.0
var is_nitro_active: bool = false
var nitro_timer: float = 0.0
var is_race_finished: bool = false
var start_z: float = 0.0
var distance_traveled: float = 0.0
var time_since_last_keystroke: float = 0.0

@onready var wheels: Node3D = $Visuals/Wheels
@onready var nitro_flame: Node3D = $Visuals/NitroFlame
@onready var camera_3d: Camera3D = $CameraPivot/Camera3D

func _ready() -> void:
	start_z = global_position.z
	if nitro_flame:
		nitro_flame.visible = false

func _physics_process(delta: float) -> void:
	if is_race_finished:
		# Gradually slow down to a stop upon winning
		target_speed_kmh = move_toward(target_speed_kmh, 0.0, 35.0 * delta)
		current_speed_kmh = move_toward(current_speed_kmh, target_speed_kmh, 25.0 * delta)
	else:
		# Update nitro state
		if is_nitro_active:
			nitro_timer -= delta
			if nitro_timer <= 0.0:
				end_nitro()

		time_since_last_keystroke += delta

		# Coasting drag: when player stops typing (> 0.35s since last keystroke) and nitro is not active
		if not is_nitro_active and time_since_last_keystroke > 0.35:
			target_speed_kmh = move_toward(target_speed_kmh, 0.0, natural_drag_kmh * delta)

		# Smooth speed interpolation toward target speed
		var accel_rate: float = 60.0 if target_speed_kmh > current_speed_kmh else 40.0
		current_speed_kmh = move_toward(current_speed_kmh, target_speed_kmh, accel_rate * delta)

	# Godot 3D: forward along -Z
	var speed_mps: float = current_speed_kmh / 3.6
	velocity = Vector3(0.0, 0.0, -speed_mps)
	move_and_slide()

	# Compute total forward distance traveled
	distance_traveled = maxf(0.0, start_z - global_position.z)

	# Spin wheels proportionally to ground speed
	if wheels:
		var wheel_spin: float = speed_mps * delta * 5.0
		for wheel in wheels.get_children():
			wheel.rotate_x(wheel_spin)

	# Dynamic camera FOV for speed sensation
	if camera_3d:
		var target_fov: float = 85.0 if is_nitro_active else 74.0
		camera_3d.fov = lerpf(camera_3d.fov, target_fov, 4.5 * delta)

	# Nitro exhaust flame animation
	if is_nitro_active and nitro_flame:
		var pulse: float = 1.0 + 0.3 * sin(Time.get_ticks_msec() * 0.035)
		nitro_flame.scale = Vector3(pulse, pulse, pulse * 1.4)

	var active_max: float = max_nitro_speed_kmh if is_nitro_active else max_normal_speed_kmh
	speed_changed.emit(current_speed_kmh, active_max)
	nitro_status_changed.emit(is_nitro_active, maxf(0.0, nitro_timer))

func accelerate_from_keystroke() -> void:
	if is_race_finished:
		return
	time_since_last_keystroke = 0.0
	var cap: float = max_nitro_speed_kmh if is_nitro_active else max_normal_speed_kmh
	target_speed_kmh = clampf(target_speed_kmh + acceleration_kmh_per_char, 0.0, cap)

func apply_typing_mistake_penalty() -> void:
	if is_race_finished:
		return
	target_speed_kmh = maxf(0.0, target_speed_kmh - mistake_penalty_kmh)
	current_speed_kmh = maxf(0.0, current_speed_kmh - (mistake_penalty_kmh * 0.6))

func activate_nitro() -> void:
	if is_race_finished:
		return
	is_nitro_active = true
	nitro_timer = nitro_duration
	time_since_last_keystroke = 0.0
	if nitro_flame:
		nitro_flame.visible = true
	target_speed_kmh = clampf(target_speed_kmh + nitro_boost_amount_kmh, 45.0, max_nitro_speed_kmh)

func end_nitro() -> void:
	is_nitro_active = false
	nitro_timer = 0.0
	if nitro_flame:
		nitro_flame.visible = false
	if target_speed_kmh > max_normal_speed_kmh:
		target_speed_kmh = max_normal_speed_kmh

func finish_race() -> void:
	is_race_finished = true
	end_nitro()

func reset_car() -> void:
	global_position.z = start_z
	current_speed_kmh = 0.0
	target_speed_kmh = 0.0
	distance_traveled = 0.0
	time_since_last_keystroke = 0.0
	is_race_finished = false
	end_nitro()
	if camera_3d:
		camera_3d.fov = 74.0

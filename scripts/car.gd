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
var is_race_started: bool = false
var is_race_finished: bool = false
var start_z: float = 0.0
var distance_traveled: float = 0.0
var time_since_last_keystroke: float = 0.0
var car_name: String = "Player (You)"
var car_color: Color = Color(0.98, 0.44, 0.05, 1.0) # Modern Metallic Muscle Orange
var finish_rank: int = 0
var finish_time: float = 0.0

@export var camera_follow_speed: float = 14.0
var camera_offset: Vector3 = Vector3(0.0, 1.2, 0.0)

var track_node: Node3D = null
var assigned_lane_offset: float = -1.5

@onready var car_visuals: SportsCarVisuals = $SportsCarVisuals
@onready var visuals: SportsCarVisuals = $SportsCarVisuals
@onready var wheels: Node3D = $SportsCarVisuals/Wheels
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_3d: Camera3D = $CameraPivot/Camera3D

func get_car_visuals() -> SportsCarVisuals:
	if not car_visuals:
		car_visuals = get_node_or_null(^"SportsCarVisuals") as SportsCarVisuals
	return car_visuals

func _ready() -> void:
	start_z = global_position.z
	assigned_lane_offset = global_position.x
	track_node = get_node_or_null(^"../Track")
	var v := get_car_visuals()
	if v:
		v.set_paint_color(car_color)
		v.set_nitro_active(false)
	if camera_pivot:
		camera_pivot.top_level = true
		camera_pivot.global_position = global_position + camera_offset

func _physics_process(delta: float) -> void:
	if is_race_finished:
		# Gradually slow down to a stop upon finishing
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

	var speed_mps: float = current_speed_kmh / 3.6
	if track_node != null and track_node.has_method("get_route_transform"):
		if is_race_started:
			distance_traveled += speed_mps * delta
		var route_tf: Transform3D = track_node.get_route_transform(distance_traveled, assigned_lane_offset)
		global_position = route_tf.origin
		global_rotation.y = route_tf.basis.get_euler().y
	else:
		# Godot 3D: forward along -Z
		velocity = Vector3(0.0, 0.0, -speed_mps)
		move_and_slide()
		# Compute total forward distance traveled
		distance_traveled = maxf(0.0, start_z - global_position.z)

	# Spin alloy wheels proportionally to ground speed
	if car_visuals:
		var wheel_spin: float = speed_mps * delta * 5.0
		car_visuals.spin_wheels(wheel_spin)

	# Smooth frame-rate-independent third-person camera following
	if camera_pivot:
		var target_pos: Vector3 = global_position + camera_offset
		var t: float = 1.0 - exp(-camera_follow_speed * delta)
		camera_pivot.global_position = camera_pivot.global_position.lerp(target_pos, t)
		var target_rot_y := global_rotation.y
		camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, target_rot_y, 6.0 * delta)

	# Dynamic camera FOV for speed sensation
	if camera_3d:
		var target_fov: float = 85.0 if is_nitro_active else 74.0
		camera_3d.fov = lerpf(camera_3d.fov, target_fov, 4.5 * delta)

	var active_max: float = max_nitro_speed_kmh if is_nitro_active else max_normal_speed_kmh
	speed_changed.emit(current_speed_kmh, active_max)
	nitro_status_changed.emit(is_nitro_active, maxf(0.0, nitro_timer))

func start_race() -> void:
	is_race_started = true
	is_race_finished = false
	finish_rank = 0
	finish_time = 0.0
	time_since_last_keystroke = 0.0

func accelerate_from_keystroke() -> void:
	if not is_race_started or is_race_finished:
		return
	time_since_last_keystroke = 0.0
	var cap: float = max_nitro_speed_kmh if is_nitro_active else max_normal_speed_kmh
	target_speed_kmh = clampf(target_speed_kmh + acceleration_kmh_per_char, 0.0, cap)

func apply_typing_mistake_penalty() -> void:
	if not is_race_started or is_race_finished:
		return
	target_speed_kmh = maxf(0.0, target_speed_kmh - mistake_penalty_kmh)
	current_speed_kmh = maxf(0.0, current_speed_kmh - (mistake_penalty_kmh * 0.6))

func activate_nitro() -> void:
	if not is_race_started or is_race_finished:
		return
	is_nitro_active = true
	nitro_timer = nitro_duration
	time_since_last_keystroke = 0.0
	if car_visuals:
		car_visuals.set_nitro_active(true)
	target_speed_kmh = clampf(target_speed_kmh + nitro_boost_amount_kmh, 45.0, max_nitro_speed_kmh)
	var gm = get_node_or_null("/root/GameManager")
	if is_instance_valid(gm):
		gm.record_nitro_activation()

func end_nitro() -> void:
	is_nitro_active = false
	nitro_timer = 0.0
	if car_visuals:
		car_visuals.set_nitro_active(false)
	if target_speed_kmh > max_normal_speed_kmh:
		target_speed_kmh = max_normal_speed_kmh

func finish_race(rank: int = 0, race_time: float = 0.0) -> void:
	if is_race_finished:
		return
	is_race_finished = true
	finish_rank = rank
	finish_time = race_time
	end_nitro()

func reset_car(pos: Vector3 = Vector3.ZERO) -> void:
	if pos != Vector3.ZERO:
		if is_inside_tree():
			global_position = pos
		else:
			position = pos
		start_z = pos.z
		assigned_lane_offset = pos.x
	else:
		if is_inside_tree():
			global_position.z = start_z
		else:
			position.z = start_z
	current_speed_kmh = 0.0
	target_speed_kmh = 0.0
	distance_traveled = 0.0
	time_since_last_keystroke = 0.0
	is_race_started = false
	is_race_finished = false
	finish_rank = 0
	finish_time = 0.0
	global_rotation = Vector3.ZERO
	end_nitro()
	var v := get_car_visuals()
	if v:
		v.set_paint_color(car_color)
		v.set_nitro_active(false)
	if camera_pivot:
		camera_pivot.global_position = global_position + camera_offset
		camera_pivot.rotation = Vector3.ZERO
	if camera_3d:
		camera_3d.fov = 74.0

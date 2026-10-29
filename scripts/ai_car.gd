extends CharacterBody3D
class_name AICar

@export var car_name: String = "AI Racer"
@export var car_color: Color = Color(0.9, 0.2, 0.2)
@export var difficulty: String = "Medium"

var current_speed_kmh: float = 0.0
var target_speed_kmh: float = 0.0
var distance_traveled: float = 0.0
var start_z: float = 0.0
var start_x: float = 0.0
var track_node: Node3D = null
var assigned_lane_offset: float = 0.0

var is_race_started: bool = false
var is_race_finished: bool = false
var finish_time: float = 0.0
var finish_rank: int = 0

# AI Tuning Parameters
var base_target_speed: float = 104.0
var simulated_wpm: float = 45.0
var error_chance: float = 0.07
var accel_rate: float = 42.0
var speed_variance: float = 0.0
var min_error_pause: float = 0.30
var max_error_pause: float = 0.50
var nitro_boost_amount: float = 26.0

# Keystroke simulation timers
var keystroke_timer: float = 0.0
var error_pause_timer: float = 0.0
var sentence_char_counter: int = 0
var sentence_length_target: int = 35

# Nitro simulation
var is_nitro_active: bool = false
var nitro_timer: float = 0.0

@onready var car_visuals: SportsCarVisuals = $SportsCarVisuals
@onready var visuals: SportsCarVisuals = $SportsCarVisuals
@onready var wheels: Node3D = $SportsCarVisuals/Wheels

func get_car_visuals() -> SportsCarVisuals:
	if not car_visuals:
		car_visuals = get_node_or_null(^"SportsCarVisuals") as SportsCarVisuals
	return car_visuals

func _ready() -> void:
	start_z = global_position.z
	start_x = global_position.x
	assigned_lane_offset = global_position.x
	track_node = get_node_or_null(^"../Track")
	_apply_car_material()
	apply_difficulty(difficulty)
	var v := get_car_visuals()
	if v:
		v.set_nitro_active(false)

func _apply_car_material() -> void:
	var v := get_car_visuals()
	if v:
		v.set_paint_color(car_color)

func apply_difficulty(diff: String) -> void:
	if diff in ["Easy", "Medium", "Hard"]:
		difficulty = diff
	else:
		difficulty = "Medium"

	# Personality offset based on car hash/name so the 3 AI cars have slight natural speed differences
	var personality_offset := float((car_name.hash() % 7) - 3)

	var config: Dictionary = {}
	var gm = get_node_or_null("/root/GameManager")
	if is_instance_valid(gm) and gm.DIFFICULTY_CONFIG.has(difficulty):
		config = gm.DIFFICULTY_CONFIG[difficulty]
	else:
		match difficulty:
			"Easy":
				config = {
					"target_speed": 78.0, "wpm": 25.0, "error_chance": 0.15,
					"accel_rate": 26.0, "min_error_pause": 0.45, "max_error_pause": 0.75, "nitro_boost": 20.0
				}
			"Hard":
				config = {
					"target_speed": 126.0, "wpm": 65.0, "error_chance": 0.02,
					"accel_rate": 58.0, "min_error_pause": 0.18, "max_error_pause": 0.32, "nitro_boost": 32.0
				}
			_: # "Medium"
				config = {
					"target_speed": 104.0, "wpm": 45.0, "error_chance": 0.07,
					"accel_rate": 42.0, "min_error_pause": 0.30, "max_error_pause": 0.50, "nitro_boost": 26.0
				}

	base_target_speed = config["target_speed"] + (personality_offset * 1.5)
	simulated_wpm = config["wpm"] + (personality_offset * 0.8)
	error_chance = config["error_chance"]
	accel_rate = config["accel_rate"] + (personality_offset * 1.0)
	min_error_pause = config["min_error_pause"]
	max_error_pause = config["max_error_pause"]
	nitro_boost_amount = config["nitro_boost"]

func start_race() -> void:
	is_race_started = true
	is_race_finished = false
	finish_rank = 0
	finish_time = 0.0
	sentence_char_counter = 0
	sentence_length_target = randi_range(30, 45)

func _physics_process(delta: float) -> void:
	if not is_race_started:
		return

	if is_race_finished:
		# Slow down after crossing the finish line
		target_speed_kmh = move_toward(target_speed_kmh, 0.0, 35.0 * delta)
		current_speed_kmh = move_toward(current_speed_kmh, target_speed_kmh, 25.0 * delta)
	else:
		_process_ai_typing(delta)
		_process_nitro(delta)
		current_speed_kmh = move_toward(current_speed_kmh, target_speed_kmh, accel_rate * delta)

	var speed_mps: float = current_speed_kmh / 3.6
	if track_node != null and track_node.has_method("get_route_transform"):
		if is_race_started:
			distance_traveled += speed_mps * delta
		var route_tf: Transform3D = track_node.get_route_transform(distance_traveled, assigned_lane_offset)
		global_position = route_tf.origin
		global_rotation.y = route_tf.basis.get_euler().y
	else:
		# Movement along negative Z
		velocity = Vector3(0.0, 0.0, -speed_mps)
		move_and_slide()
		# Keep car locked to its assigned lane
		global_position.x = start_x
		distance_traveled = maxf(0.0, start_z - global_position.z)

	# Spin wheels
	if car_visuals:
		var wheel_spin: float = speed_mps * delta * 5.0
		car_visuals.spin_wheels(wheel_spin)

func _process_ai_typing(delta: float) -> void:
	if error_pause_timer > 0.0:
		error_pause_timer -= delta
		# Slight deceleration during typo correction
		target_speed_kmh = move_toward(target_speed_kmh, base_target_speed * 0.6, 18.0 * delta)
		return

	# Seconds per simulated keystroke
	var seconds_per_char: float = 60.0 / maxf(10.0, simulated_wpm * 5.0)
	keystroke_timer += delta

	while keystroke_timer >= seconds_per_char:
		keystroke_timer -= seconds_per_char
		_simulate_keystroke()

func _simulate_keystroke() -> void:
	if randf() < error_chance:
		# AI made a simulated typo
		error_pause_timer = randf_range(min_error_pause, max_error_pause)
		target_speed_kmh = maxf(0.0, target_speed_kmh - 6.0)
		return

	# Correct simulated keystroke
	sentence_char_counter += 1
	var cap: float = (base_target_speed + 35.0) if is_nitro_active else base_target_speed
	target_speed_kmh = clampf(target_speed_kmh + 4.5, 0.0, cap)

	# Check simulated sentence completion
	if sentence_char_counter >= sentence_length_target:
		sentence_char_counter = 0
		sentence_length_target = randi_range(30, 45)
		_activate_ai_nitro()

func _activate_ai_nitro() -> void:
	is_nitro_active = true
	nitro_timer = 2.8
	if car_visuals:
		car_visuals.set_nitro_active(true)
	target_speed_kmh = clampf(target_speed_kmh + nitro_boost_amount, 40.0, base_target_speed + 35.0)

func _process_nitro(delta: float) -> void:
	if is_nitro_active:
		nitro_timer -= delta
		if nitro_timer <= 0.0:
			is_nitro_active = false
			if car_visuals:
				car_visuals.set_nitro_active(false)
			if target_speed_kmh > base_target_speed:
				target_speed_kmh = base_target_speed

func finish_race(rank: int, race_time: float) -> void:
	if is_race_finished:
		return
	is_race_finished = true
	finish_rank = rank
	finish_time = race_time
	is_nitro_active = false
	if car_visuals:
		car_visuals.set_nitro_active(false)

func reset_car(pos: Vector3) -> void:
	if is_inside_tree():
		global_position = pos
	else:
		position = pos
	start_z = pos.z
	start_x = pos.x
	assigned_lane_offset = pos.x
	current_speed_kmh = 0.0
	target_speed_kmh = 0.0
	distance_traveled = 0.0
	is_race_started = false
	is_race_finished = false
	finish_time = 0.0
	finish_rank = 0
	keystroke_timer = 0.0
	error_pause_timer = 0.0
	is_nitro_active = false
	global_rotation = Vector3.ZERO
	var v := get_car_visuals()
	if v:
		v.set_nitro_active(false)
		v.set_paint_color(car_color)

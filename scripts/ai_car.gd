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

var is_race_started: bool = false
var is_race_finished: bool = false
var finish_time: float = 0.0
var finish_rank: int = 0

# AI Tuning Parameters
var base_target_speed: float = 110.0
var simulated_wpm: float = 58.0
var error_chance: float = 0.06
var accel_rate: float = 48.0
var speed_variance: float = 0.0

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
	difficulty = diff
	# Personality offset based on car hash/name so the 3 AI cars have slight natural speed differences
	var personality_offset := float((car_name.hash() % 9) - 4)

	match diff:
		"Easy":
			base_target_speed = 88.0 + personality_offset
			simulated_wpm = 40.0 + (personality_offset * 1.5)
			error_chance = 0.10
			accel_rate = 35.0
		"Hard":
			base_target_speed = 126.0 + personality_offset
			simulated_wpm = 78.0 + (personality_offset * 1.5)
			error_chance = 0.02
			accel_rate = 60.0
		_: # "Medium"
			base_target_speed = 108.0 + personality_offset
			simulated_wpm = 58.0 + (personality_offset * 1.5)
			error_chance = 0.05
			accel_rate = 48.0

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

	# Movement along negative Z
	var speed_mps: float = current_speed_kmh / 3.6
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
		error_pause_timer = randf_range(0.3, 0.65)
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
	target_speed_kmh = clampf(target_speed_kmh + 28.0, 40.0, base_target_speed + 35.0)

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
	var v := get_car_visuals()
	if v:
		v.set_nitro_active(false)
		v.set_paint_color(car_color)

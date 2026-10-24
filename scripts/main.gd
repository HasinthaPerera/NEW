extends Node3D

@onready var car: CharacterBody3D = $Car
@onready var ai_car_1: CharacterBody3D = $AICar1
@onready var ai_car_2: CharacterBody3D = $AICar2
@onready var ai_car_3: CharacterBody3D = $AICar3
@onready var track: Node3D = $Track
@onready var typing_manager: Node = $TypingManager
@onready var hud: CanvasLayer = $HUD

var all_cars: Array[CharacterBody3D] = []
var starting_grid_positions: Dictionary = {}

var is_countdown_active: bool = true
var countdown_timer: float = 3.6
var last_countdown_sec: int = -1

var race_start_msec: int = 0
var top_speed_achieved: float = 0.0
var current_difficulty: String = "Medium"

var finished_cars: Array[CharacterBody3D] = []
var is_game_over: bool = false

func _ready() -> void:
	all_cars = [car, ai_car_1, ai_car_2, ai_car_3]

	# Store starting grid coordinates
	starting_grid_positions[car] = Vector3(-1.5, 0.0, 0.0)
	starting_grid_positions[ai_car_1] = Vector3(-4.5, 0.0, 0.0)
	starting_grid_positions[ai_car_2] = Vector3(1.5, 0.0, 0.0)
	starting_grid_positions[ai_car_3] = Vector3(4.5, 0.0, 0.0)

	# Position cars on starting grid
	for c in all_cars:
		if starting_grid_positions.has(c):
			c.global_position = starting_grid_positions[c]

	# Apply customizations from GameManager if available
	if is_instance_valid(GameManager):
		car.car_color = GameManager.player_car_color
		var p_vis = car.get_car_visuals()
		if p_vis:
			p_vis.set_paint_color(GameManager.player_car_color)

		var ai_configs: Array[Dictionary] = GameManager.get_ai_colors()
		var ai_cars_list: Array[CharacterBody3D] = [ai_car_1, ai_car_2, ai_car_3]
		for i in range(3):
			var ai: CharacterBody3D = ai_cars_list[i]
			var cfg: Dictionary = ai_configs[i]
			ai.car_name = cfg["name"]
			ai.car_color = cfg["color"]
			var ai_vis = ai.get_car_visuals()
			if ai_vis:
				ai_vis.set_paint_color(cfg["color"])

		current_difficulty = GameManager.ai_difficulty
		for c in all_cars:
			if c != car and c.has_method("apply_difficulty"):
				c.apply_difficulty(current_difficulty)
		hud.set_difficulty_display(current_difficulty)

	# Connect TypingManager signals
	typing_manager.correct_character_typed.connect(_on_correct_character)
	typing_manager.incorrect_character_typed.connect(_on_incorrect_character)
	typing_manager.sentence_completed.connect(_on_sentence_completed)
	typing_manager.sentence_updated.connect(_on_sentence_updated)

	# Connect HUD signals
	hud.input_text_changed.connect(_on_hud_input_changed)
	hud.restart_requested.connect(restart_race)
	hud.menu_requested.connect(_on_hud_menu_requested)
	hud.difficulty_changed.connect(_on_difficulty_changed)

	# Connect Car signals
	car.speed_changed.connect(_on_car_speed_changed)
	car.nitro_status_changed.connect(_on_car_nitro_status_changed)

	# Connect Track signals
	track.car_crossed_finish_line.connect(_on_car_crossed_finish_line)

	# Initialize race setup
	_start_countdown_sequence()

func _start_countdown_sequence() -> void:
	is_countdown_active = true
	countdown_timer = 3.6
	last_countdown_sec = -1
	is_game_over = false
	top_speed_achieved = 0.0
	finished_cars.clear()

	# Reset cars to grid slots
	for c in all_cars:
		if c.has_method("reset_car") and starting_grid_positions.has(c):
			c.reset_car(starting_grid_positions[c])

	track.reset_finish()
	typing_manager.reset_sentences()
	hud.reset_hud()
	hud.update_sentence_display(typing_manager.current_target_sentence, "", false)
	hud.update_distance(0.0, track.track_length)
	hud.update_speed(0.0, car.max_normal_speed_kmh, false)
	hud.update_player_position(1, all_cars.size())
	hud.set_countdown("3", false)

func _process(delta: float) -> void:
	if is_countdown_active:
		_process_countdown(delta)
		return

	if not is_game_over:
		_process_live_race()

func _process_countdown(delta: float) -> void:
	countdown_timer -= delta

	if countdown_timer > 2.0:
		if last_countdown_sec != 3:
			last_countdown_sec = 3
			hud.set_countdown("3", false)
	elif countdown_timer > 1.0:
		if last_countdown_sec != 2:
			last_countdown_sec = 2
			hud.set_countdown("2", false)
	elif countdown_timer > 0.0:
		if last_countdown_sec != 1:
			last_countdown_sec = 1
			hud.set_countdown("1", false)
	elif countdown_timer > -0.65:
		if last_countdown_sec != 0:
			last_countdown_sec = 0
			hud.set_countdown("GO!", true)
			_launch_race()
	else:
		is_countdown_active = false
		hud.hide_countdown()

func _launch_race() -> void:
	race_start_msec = Time.get_ticks_msec()
	for c in all_cars:
		if c.has_method("start_race"):
			c.start_race()

func _process_live_race() -> void:
	# Track distance & speed for player
	hud.update_distance(car.distance_traveled, track.track_length)
	top_speed_achieved = maxf(top_speed_achieved, car.current_speed_kmh)

	# Check finish condition for all cars based on track distance
	for c in all_cars:
		if c not in finished_cars and c.distance_traveled >= track.track_length:
			_on_car_finished(c)

	# Calculate and update live positions
	var current_player_rank := _calculate_player_live_rank()
	hud.update_player_position(current_player_rank, all_cars.size())

func _calculate_player_live_rank() -> int:
	var rank := 1
	var player_finished := (car in finished_cars)
	var player_distance: float = car.distance_traveled

	for other in all_cars:
		if other == car:
			continue
		var other_finished := (other in finished_cars)

		if player_finished and other_finished:
			# If both finished, compare their finish ranks
			if other.finish_rank < car.finish_rank:
				rank += 1
		elif not player_finished and other_finished:
			# Other finished before player
			rank += 1
		elif not player_finished and not other_finished:
			# Both still racing: compare distance traveled
			if other.distance_traveled > player_distance:
				rank += 1

	return rank

func _on_car_crossed_finish_line(car_node: Node3D) -> void:
	if car_node is CharacterBody3D:
		_on_car_finished(car_node)

func _on_car_finished(car_node: CharacterBody3D) -> void:
	if car_node in finished_cars:
		return

	finished_cars.append(car_node)
	var rank := finished_cars.size()
	var elapsed_sec: float = float(Time.get_ticks_msec() - race_start_msec) / 1000.0

	if car_node.has_method("finish_race"):
		car_node.finish_race(rank, elapsed_sec)

	# If the player crossed the finish line
	if car_node == car and not is_game_over:
		is_game_over = true
		typing_manager.stop_racing()
		_show_race_results()

func _show_race_results() -> void:
	var standings: Array[Dictionary] = []

	# Sort all cars by finishing rank, then by distance traveled
	var sorted_cars: Array[CharacterBody3D] = []
	sorted_cars.assign(all_cars.duplicate())
	sorted_cars.sort_custom(func(a: CharacterBody3D, b: CharacterBody3D) -> bool:
		var a_fin: bool = (a in finished_cars)
		var b_fin: bool = (b in finished_cars)
		if a_fin and b_fin:
			return a.finish_rank < b.finish_rank
		elif a_fin and not b_fin:
			return true
		elif not a_fin and b_fin:
			return false
		else:
			return a.distance_traveled > b.distance_traveled
	)

	for i in range(sorted_cars.size()):
		var c: CharacterBody3D = sorted_cars[i]
		var rank_val: int = c.finish_rank if (c in finished_cars) else (i + 1)
		var time_val: float = c.finish_time if (c in finished_cars) else 0.0

		standings.append({
			"rank": rank_val,
			"name": c.car_name,
			"color": c.car_color,
			"time": time_val,
			"is_player": (c == car)
		})

	var player_stats: Dictionary = {
		"rank": car.finish_rank if car.finish_rank > 0 else _calculate_player_live_rank(),
		"time": car.finish_time,
		"top_speed": top_speed_achieved,
		"wpm": typing_manager.get_current_wpm(),
		"accuracy": typing_manager.get_current_accuracy()
	}

	hud.show_race_results(standings, player_stats)

func _on_difficulty_changed(new_difficulty: String) -> void:
	current_difficulty = new_difficulty
	for c in all_cars:
		if c != car and c.has_method("apply_difficulty"):
			c.apply_difficulty(new_difficulty)

func _on_hud_input_changed(new_text: String) -> void:
	if is_countdown_active or is_game_over:
		return
	var should_clear: bool = typing_manager.on_input_changed(new_text)
	if should_clear:
		hud.clear_input()

func _on_correct_character(_char_typed: String) -> void:
	if not is_countdown_active:
		car.accelerate_from_keystroke()

func _on_incorrect_character() -> void:
	if not is_countdown_active:
		car.apply_typing_mistake_penalty()
		hud.show_typing_error_effect()

func _on_sentence_completed(_sentence: String) -> void:
	if not is_countdown_active:
		car.activate_nitro()

func _on_sentence_updated(target: String, typed: String, is_error: bool) -> void:
	hud.update_sentence_display(target, typed, is_error)

func _on_car_speed_changed(current_kmh: float, max_kmh: float) -> void:
	hud.update_speed(current_kmh, max_kmh, car.is_nitro_active)

func _on_car_nitro_status_changed(is_active: bool, time_remaining: float) -> void:
	hud.set_nitro_active(is_active, time_remaining)

func restart_race() -> void:
	_start_countdown_sequence()

func _on_hud_menu_requested() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")

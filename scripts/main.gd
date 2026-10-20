extends Node3D

@onready var car: CharacterBody3D = $Car
@onready var track: Node3D = $Track
@onready var typing_manager: Node = $TypingManager
@onready var hud: CanvasLayer = $HUD

var top_speed_achieved: float = 0.0
var is_game_over: bool = false

func _ready() -> void:
	# Connect TypingManager signals
	typing_manager.correct_character_typed.connect(_on_correct_character)
	typing_manager.incorrect_character_typed.connect(_on_incorrect_character)
	typing_manager.sentence_completed.connect(_on_sentence_completed)
	typing_manager.sentence_updated.connect(_on_sentence_updated)

	# Connect HUD signals
	hud.input_text_changed.connect(_on_hud_input_changed)
	hud.restart_requested.connect(restart_race)

	# Connect Car signals
	car.speed_changed.connect(_on_car_speed_changed)
	car.nitro_status_changed.connect(_on_car_nitro_status_changed)

	# Connect Track signals
	track.player_crossed_finish_line.connect(_on_player_won)

	# Initial UI state & display first random sentence
	typing_manager.reset_sentences()
	hud.update_sentence_display(typing_manager.current_target_sentence, "", false)
	hud.update_distance(0.0, track.track_length)
	hud.update_speed(0.0, car.max_normal_speed_kmh, false)

func _process(_delta: float) -> void:
	if not is_game_over:
		hud.update_distance(car.distance_traveled, track.track_length)
		top_speed_achieved = maxf(top_speed_achieved, car.current_speed_kmh)

		# Backup check in case car moves past finish line
		if car.distance_traveled >= track.track_length and not is_game_over:
			_on_player_won()

func _on_hud_input_changed(new_text: String) -> void:
	if is_game_over:
		return
	var should_clear: bool = typing_manager.on_input_changed(new_text)
	if should_clear:
		hud.clear_input()

func _on_correct_character(_char_typed: String) -> void:
	car.accelerate_from_keystroke()

func _on_incorrect_character() -> void:
	car.apply_typing_mistake_penalty()
	hud.show_typing_error_effect()

func _on_sentence_completed(_sentence: String) -> void:
	car.activate_nitro()

func _on_sentence_updated(target: String, typed: String, is_error: bool) -> void:
	hud.update_sentence_display(target, typed, is_error)

func _on_car_speed_changed(current_kmh: float, max_kmh: float) -> void:
	hud.update_speed(current_kmh, max_kmh, car.is_nitro_active)

func _on_car_nitro_status_changed(is_active: bool, time_remaining: float) -> void:
	hud.set_nitro_active(is_active, time_remaining)

func _on_player_won() -> void:
	if is_game_over:
		return
	is_game_over = true
	typing_manager.stop_racing()
	car.finish_race()

	var elapsed_sec: float = typing_manager.get_elapsed_seconds()
	var wpm: float = typing_manager.get_current_wpm()
	var accuracy: float = typing_manager.get_current_accuracy()
	hud.show_win_screen(elapsed_sec, top_speed_achieved, wpm, accuracy)

func restart_race() -> void:
	is_game_over = false
	top_speed_achieved = 0.0
	car.reset_car()
	track.reset_finish()
	typing_manager.reset_sentences()
	hud.reset_hud()
	hud.update_sentence_display(typing_manager.current_target_sentence, "", false)
	hud.update_distance(0.0, track.track_length)
	hud.update_speed(0.0, car.max_normal_speed_kmh, false)

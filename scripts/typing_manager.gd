extends Node
class_name TypingManager

signal correct_character_typed(char_typed: String)
signal incorrect_character_typed()
signal sentence_completed(sentence: String)
signal sentence_updated(target_sentence: String, typed_text: String, is_error: bool)
signal stats_updated(wpm: float, accuracy: float)

const SENTENCES: Array[String] = [
	"Fast fingers burn clean rubber on the open track.",
	"Shift gears into maximum overdrive and take the lead.",
	"Precision and steady rhythm will carry you across the line.",
	"Every keystroke injects high octane fuel into the engine.",
	"Keep your eyes locked forward on the checkered flag.",
	"Hit the apex and accelerate with pure confidence.",
	"Nitro is ready to ignite the straightaway now.",
	"Feel the thunderous roar of the turbocharged engine.",
	"Speed is a craft honed by quick and accurate hands.",
	"Push beyond every limit to claim first place today."
]

var sentence_list: Array[String] = []
var sentence_index: int = 0
var current_target_sentence: String = ""
var last_input_text: String = ""

var total_keystrokes: int = 0
var correct_keystrokes: int = 0
var error_keystrokes: int = 0
var start_time_msec: int = 0
var is_racing: bool = false

func _ready() -> void:
	reset_sentences()

func reset_sentences() -> void:
	sentence_list = SENTENCES.duplicate()
	sentence_list.shuffle()
	sentence_index = 0
	total_keystrokes = 0
	correct_keystrokes = 0
	error_keystrokes = 0
	start_time_msec = 0
	is_racing = false
	last_input_text = ""
	_load_current_sentence()

func _load_current_sentence() -> void:
	if sentence_index >= sentence_list.size():
		sentence_index = 0
		sentence_list.shuffle()
	current_target_sentence = sentence_list[sentence_index]
	last_input_text = ""
	sentence_updated.emit(current_target_sentence, "", false)

func on_input_changed(new_text: String) -> bool:
	if not is_racing:
		is_racing = true
		start_time_msec = Time.get_ticks_msec()

	var target_len := current_target_sentence.length()
	var input_len := new_text.length()
	var was_backspace := input_len < last_input_text.length()

	# Check if current input strictly matches the prefix of target sentence
	var target_prefix := current_target_sentence.left(input_len)
	var is_match := (new_text == target_prefix)

	if not was_backspace and input_len > 0:
		total_keystrokes += 1
		if is_match:
			correct_keystrokes += 1
			var last_char := new_text.right(1)
			correct_character_typed.emit(last_char)
		else:
			error_keystrokes += 1
			incorrect_character_typed.emit()

	last_input_text = new_text
	_emit_stats()

	# Sentence completion
	if new_text == current_target_sentence:
		sentence_completed.emit(current_target_sentence)
		sentence_index += 1
		_load_current_sentence()
		return true # signal to clear the input field

	sentence_updated.emit(current_target_sentence, new_text, not is_match)
	return false

func _emit_stats() -> void:
	var wpm := get_current_wpm()
	var accuracy := get_current_accuracy()
	stats_updated.emit(wpm, accuracy)

func get_current_wpm() -> float:
	if start_time_msec == 0:
		return 0.0
	var elapsed_sec: float = float(Time.get_ticks_msec() - start_time_msec) / 1000.0
	if elapsed_sec < 0.5:
		return 0.0
	var words: float = float(correct_keystrokes) / 5.0
	var minutes: float = elapsed_sec / 60.0
	return words / minutes

func get_current_accuracy() -> float:
	if total_keystrokes == 0:
		return 100.0
	return (float(correct_keystrokes) / float(total_keystrokes)) * 100.0

func get_elapsed_seconds() -> float:
	if start_time_msec == 0:
		return 0.0
	return float(Time.get_ticks_msec() - start_time_msec) / 1000.0

func stop_racing() -> void:
	is_racing = false

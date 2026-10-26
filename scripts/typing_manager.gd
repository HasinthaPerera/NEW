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
	"Push beyond every limit to claim first place today.",
	"Smooth acceleration wins the race on every straight.",
	"Full throttle ahead as the tires grip the asphalt.",
	"Master the keyboard and leave the competition behind.",
	"Lightning fast reflexes pave the way to victory.",
	"Feel the rush of wind as your speed climbs higher."
]

var sentence_pool: Array[String] = []
var current_target_sentence: String = ""
var last_input_text: String = ""

var total_keystrokes: int = 0
var correct_keystrokes: int = 0
var error_keystrokes: int = 0
var completed_phrases: int = 0
var start_time_msec: int = 0
var end_time_msec: int = 0
var is_racing: bool = false
var final_wpm: float = 0.0
var final_accuracy: float = 100.0

func _ready() -> void:
	reset_sentences()

func reset_sentences() -> void:
	sentence_pool = SENTENCES.duplicate()
	sentence_pool.shuffle()
	total_keystrokes = 0
	correct_keystrokes = 0
	error_keystrokes = 0
	completed_phrases = 0
	start_time_msec = 0
	end_time_msec = 0
	is_racing = false
	final_wpm = 0.0
	final_accuracy = 100.0
	last_input_text = ""
	_load_next_sentence()

func start_racing() -> void:
	is_racing = true
	start_time_msec = Time.get_ticks_msec()
	end_time_msec = 0
	final_wpm = 0.0
	final_accuracy = 100.0

func _load_next_sentence() -> void:
	if sentence_pool.is_empty():
		sentence_pool = SENTENCES.duplicate()
		sentence_pool.shuffle()
		# Avoid picking the exact same sentence consecutively if possible
		if sentence_pool.size() > 1 and sentence_pool[0] == current_target_sentence:
			var swapped: String = sentence_pool.pop_front()
			sentence_pool.push_back(swapped)

	current_target_sentence = sentence_pool.pop_front()
	last_input_text = ""
	sentence_updated.emit(current_target_sentence, "", false)

func on_input_changed(new_text: String) -> bool:
	if new_text == last_input_text:
		return false

	if not is_racing and new_text.length() > 0:
		is_racing = true
		if start_time_msec == 0:
			start_time_msec = Time.get_ticks_msec()

	var input_len := new_text.length()
	var last_len := last_input_text.length()
	var was_backspace := input_len < last_len

	# Check if current input strictly matches the prefix of target sentence
	var target_prefix := current_target_sentence.left(input_len)
	var is_match := (new_text == target_prefix)

	if not was_backspace and input_len > last_len:
		var chars_added := input_len - last_len
		total_keystrokes += chars_added
		if is_match:
			correct_keystrokes += chars_added
			var last_char := new_text.right(1)
			correct_character_typed.emit(last_char)
		else:
			error_keystrokes += chars_added
			incorrect_character_typed.emit()

	last_input_text = new_text
	_emit_stats()

	# Sentence completion check
	if new_text == current_target_sentence:
		completed_phrases += 1
		sentence_completed.emit(current_target_sentence)
		_load_next_sentence()
		return true # Signal to clear the input field

	sentence_updated.emit(current_target_sentence, new_text, not is_match)
	return false

func _emit_stats() -> void:
	var wpm := get_current_wpm()
	var accuracy := get_current_accuracy()
	stats_updated.emit(wpm, accuracy)

func get_active_typing_time() -> float:
	if start_time_msec == 0:
		return 0.0
	if end_time_msec > 0:
		return float(end_time_msec - start_time_msec) / 1000.0
	return float(Time.get_ticks_msec() - start_time_msec) / 1000.0

func get_current_wpm() -> float:
	var active_sec := get_active_typing_time()
	if active_sec < 0.2 or correct_keystrokes == 0:
		return 0.0
	var active_minutes := active_sec / 60.0
	if active_minutes <= 0.0001:
		return 0.0
	var words: float = float(correct_keystrokes) / 5.0
	return words / active_minutes

func get_current_accuracy() -> float:
	var total_keys := correct_keystrokes + error_keystrokes
	if total_keys == 0:
		return 100.0
	return (float(correct_keystrokes) / float(total_keys)) * 100.0

func get_final_wpm() -> float:
	if end_time_msec > 0:
		return final_wpm
	return get_current_wpm()

func get_final_accuracy() -> float:
	if end_time_msec > 0:
		return final_accuracy
	return get_current_accuracy()

func get_elapsed_seconds() -> float:
	return get_active_typing_time()

func stop_racing() -> void:
	if is_racing:
		is_racing = false
		end_time_msec = Time.get_ticks_msec()
		final_wpm = get_current_wpm()
		final_accuracy = get_current_accuracy()

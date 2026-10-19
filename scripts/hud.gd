extends CanvasLayer
class_name RacingHUD

signal input_text_changed(new_text: String)
signal restart_requested

@onready var sentence_display: RichTextLabel = $RootControl/TypingPanel/VBox/SentenceDisplay
@onready var input_line: LineEdit = $RootControl/TypingPanel/VBox/InputLine
@onready var speed_label: Label = $RootControl/TopPanel/HBox/SpeedBox/SpeedLabel
@onready var speed_bar: ProgressBar = $RootControl/TopPanel/HBox/SpeedBox/SpeedBar
@onready var distance_label: Label = $RootControl/TopPanel/HBox/DistanceBox/DistanceLabel
@onready var distance_bar: ProgressBar = $RootControl/TopPanel/HBox/DistanceBox/DistanceBar
@onready var nitro_badge: PanelContainer = $RootControl/NitroBadge
@onready var nitro_timer_label: Label = $RootControl/NitroBadge/NitroTimerLabel
@onready var win_modal: PanelContainer = $RootControl/WinModal
@onready var win_stats_label: Label = $RootControl/WinModal/Margin/VBox/WinStatsLabel
@onready var restart_button: Button = $RootControl/WinModal/Margin/VBox/RestartButton
@onready var typing_panel: PanelContainer = $RootControl/TypingPanel

var is_race_ended: bool = false
var input_shake_timer: float = 0.0

func _ready() -> void:
	win_modal.visible = false
	nitro_badge.visible = false
	input_line.text_changed.connect(_on_line_edit_text_changed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	_ensure_input_focus()

func _process(delta: float) -> void:
	if not is_race_ended:
		if not input_line.has_focus():
			input_line.grab_focus()
		
		# Shake input panel if error was made
		if input_shake_timer > 0.0:
			input_shake_timer -= delta
			var shake_offset := sin(Time.get_ticks_msec() * 0.08) * 6.0
			typing_panel.position.x = (typing_panel.get_parent_control().size.x - typing_panel.size.x) * 0.5 + shake_offset
		else:
			typing_panel.position.x = (typing_panel.get_parent_control().size.x - typing_panel.size.x) * 0.5

func _ensure_input_focus() -> void:
	input_line.grab_focus()

func _on_line_edit_text_changed(new_text: String) -> void:
	input_text_changed.emit(new_text)

func clear_input() -> void:
	input_line.text = ""

func update_sentence_display(target: String, typed: String, has_error: bool) -> void:
	var bb := ""
	var target_len := target.length()
	var typed_len := typed.length()

	if has_error:
		# Find the common prefix
		var common_len := 0
		while common_len < typed_len and common_len < target_len:
			if typed[common_len] == target[common_len]:
				common_len += 1
			else:
				break

		var correct_part := target.substr(0, common_len)
		var error_target_char := target.substr(common_len, 1)
		var remaining := target.substr(common_len + 1)

		bb += "[color=#22c55e]" + correct_part + "[/color]"
		bb += "[color=#ffffff][bgcolor=#dc2626][u]" + (error_target_char if error_target_char != "" else " ") + "[/u][/bgcolor][/color]"
		bb += "[color=#94a3b8]" + remaining + "[/color]"
	else:
		var matched := target.substr(0, typed_len)
		var next_char := target.substr(typed_len, 1)
		var remaining := target.substr(typed_len + 1)

		bb += "[color=#22c55e]" + matched + "[/color]"
		if next_char != "":
			bb += "[color=#f59e0b][u]" + next_char + "[/u][/color]"
		bb += "[color=#e2e8f0]" + remaining + "[/color]"

	sentence_display.text = bb

func show_typing_error_effect() -> void:
	input_shake_timer = 0.22

func update_speed(current_kmh: float, max_kmh: float, is_nitro: bool) -> void:
	speed_label.text = "%d KM/H" % int(round(current_kmh))
	speed_bar.max_value = max_kmh
	speed_bar.value = current_kmh
	
	if is_nitro:
		speed_label.add_theme_color_override("font_color", Color(0.96, 0.72, 0.15))
	else:
		speed_label.add_theme_color_override("font_color", Color(0.22, 0.75, 0.98))

func update_distance(current_distance: float, total_distance: float) -> void:
	var clamped := clampf(current_distance, 0.0, total_distance)
	var remaining := maxf(0.0, total_distance - clamped)
	distance_label.text = "TRACK: %dm / %dm  (REMAINING: %dm)" % [int(clamped), int(total_distance), int(remaining)]
	distance_bar.max_value = total_distance
	distance_bar.value = clamped

func set_nitro_active(active: bool, time_left: float) -> void:
	nitro_badge.visible = active
	if active:
		nitro_timer_label.text = "NITRO BOOST: %.1fs" % time_left

func show_win_screen(final_time: float, top_speed: float, wpm: float, accuracy: float) -> void:
	is_race_ended = true
	input_line.editable = false
	win_modal.visible = true
	
	var time_str := "%.2f s" % final_time
	var speed_str := "%d KM/H" % int(top_speed)
	var wpm_str := "%d WPM" % int(wpm)
	var acc_str := "%.1f %%" % accuracy
	
	win_stats_label.text = "TIME: %s   |   TOP SPEED: %s\nTYPING SPEED: %s   |   ACCURACY: %s" % [
		time_str, speed_str, wpm_str, acc_str
	]
	restart_button.grab_focus()

func reset_hud() -> void:
	is_race_ended = false
	win_modal.visible = false
	nitro_badge.visible = false
	input_line.editable = true
	input_line.text = ""
	_ensure_input_focus()

func _on_restart_button_pressed() -> void:
	restart_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if is_race_ended:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			restart_requested.emit()

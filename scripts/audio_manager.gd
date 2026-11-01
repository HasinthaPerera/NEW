extends Node

# Centralized AudioManager System for TypingRacerGame
# Milestone 8, Task 1: Complete Sound and Music System
# Manages background music, 3D engine audio, typing SFX, nitro sounds,
# countdown/race events, finish/victory/defeat feedback, and UI sounds.

# Preloaded Audio Assets (16-bit 44.1kHz PCM WAVs)
var MUSIC_MENU: AudioStream = preload("res://audio/music/menu_theme.wav")
var MUSIC_RACE: AudioStream = preload("res://audio/music/race_theme.wav")

var SFX_ENGINE_LOOP: AudioStream = preload("res://audio/sfx/engine_loop.wav")
var SFX_NITRO_BOOST: AudioStream = preload("res://audio/sfx/nitro_boost.wav")
var SFX_NITRO_LOOP: AudioStream = preload("res://audio/sfx/nitro_loop.wav")

var SFX_TYPE_CLICK: AudioStream = preload("res://audio/sfx/type_click.wav")
var SFX_TYPE_ERROR: AudioStream = preload("res://audio/sfx/type_error.wav")
var SFX_PHRASE_COMPLETE: AudioStream = preload("res://audio/sfx/phrase_complete.wav")

var SFX_COUNTDOWN_BEEP: AudioStream = preload("res://audio/sfx/countdown_beep.wav")
var SFX_RACE_START: AudioStream = preload("res://audio/sfx/race_start.wav")
var SFX_FINISH_LINE: AudioStream = preload("res://audio/sfx/finish_line.wav")
var SFX_VICTORY: AudioStream = preload("res://audio/sfx/victory.wav")
var SFX_DEFEAT: AudioStream = preload("res://audio/sfx/defeat.wav")

var SFX_UI_HOVER: AudioStream = preload("res://audio/sfx/ui_hover.wav")
var SFX_UI_CLICK: AudioStream = preload("res://audio/sfx/ui_click.wav")
var SFX_TRACK_SELECT: AudioStream = preload("res://audio/sfx/ui_track_select.wav")
var SFX_ACHIEVEMENT: AudioStream = preload("res://audio/sfx/achievement_unlock.wav")
var SFX_LEVEL_UP: AudioStream = preload("res://audio/sfx/level_up.wav")

# Audio Bus Names
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

# Volume state (linear 0.0 to 1.0)
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.85

var is_music_muted: bool = false
var is_sfx_muted: bool = false

# Music System
var music_player_a: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var active_music_player: AudioStreamPlayer = null
var current_music_id: String = "" # "none", "menu", "race"
var music_tween: Tween = null

# SFX Polyphonic Pool
const SFX_POOL_SIZE := 12
var sfx_players: Array[AudioStreamPlayer] = []
var next_sfx_idx: int = 0

# Sustained Nitro Player
var nitro_player: AudioStreamPlayer

# Car Engine Audio System
var player_engine_player: AudioStreamPlayer
var ai_engine_players: Dictionary = {} # Node3D (AICar) -> AudioStreamPlayer3D

# Audio Throttling Timers
var last_type_click_time: float = -1.0
var last_ui_hover_time: float = -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_configure_loop_modes()
	_setup_music_players()
	_setup_sfx_pool()
	_setup_nitro_player()
	_setup_engine_player()
	_sync_from_game_manager()

# --- 1. Audio Buses Setup & Volume Control ---
func _setup_audio_buses() -> void:
	# Verify and create buses if missing
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, BUS_MUSIC)
		AudioServer.set_bus_send(idx, BUS_MASTER)

	if AudioServer.get_bus_index(BUS_SFX) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, BUS_MASTER)

func _configure_loop_modes() -> void:
	# Configure seamless loop points on streaming WAV resources
	if MUSIC_MENU is AudioStreamWAV:
		(MUSIC_MENU as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	if MUSIC_RACE is AudioStreamWAV:
		(MUSIC_RACE as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	if SFX_ENGINE_LOOP is AudioStreamWAV:
		(SFX_ENGINE_LOOP as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	if SFX_NITRO_LOOP is AudioStreamWAV:
		(SFX_NITRO_LOOP as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

func _sync_from_game_manager() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if is_instance_valid(gm):
		if "master_volume" in gm:
			master_volume = clampf(float(gm.get("master_volume")), 0.0, 1.0)
		if "music_volume" in gm:
			music_volume = clampf(float(gm.get("music_volume")), 0.0, 1.0)
		if "sfx_volume" in gm:
			sfx_volume = clampf(float(gm.get("sfx_volume")), 0.0, 1.0)
		if "music_muted" in gm:
			is_music_muted = bool(gm.get("music_muted"))
		if "sfx_muted" in gm:
			is_sfx_muted = bool(gm.get("sfx_muted"))
		elif "sound_enabled" in gm:
			is_sfx_muted = not bool(gm.get("sound_enabled"))

	apply_all_audio_settings()

func _vol_to_db(linear: float) -> float:
	if linear <= 0.001:
		return -80.0
	return linear_to_db(clampf(linear, 0.001, 1.0))

func apply_all_audio_settings() -> void:
	var master_idx := AudioServer.get_bus_index(BUS_MASTER)
	var music_idx := AudioServer.get_bus_index(BUS_MUSIC)
	var sfx_idx := AudioServer.get_bus_index(BUS_SFX)

	if master_idx != -1:
		AudioServer.set_bus_volume_db(master_idx, _vol_to_db(master_volume))

	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, _vol_to_db(music_volume))
		AudioServer.set_bus_mute(music_idx, is_music_muted)

	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, _vol_to_db(sfx_volume))
		AudioServer.set_bus_mute(sfx_idx, is_sfx_muted)

func set_master_volume(vol: float) -> void:
	master_volume = clampf(vol, 0.0, 1.0)
	var idx := AudioServer.get_bus_index(BUS_MASTER)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, _vol_to_db(master_volume))
	_persist_settings()

func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	var idx := AudioServer.get_bus_index(BUS_MUSIC)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, _vol_to_db(music_volume))
	_persist_settings()

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
	var idx := AudioServer.get_bus_index(BUS_SFX)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, _vol_to_db(sfx_volume))
	_persist_settings()

func set_music_muted(muted: bool) -> void:
	is_music_muted = muted
	var idx := AudioServer.get_bus_index(BUS_MUSIC)
	if idx != -1:
		AudioServer.set_bus_mute(idx, is_music_muted)
	_persist_settings()

func set_sfx_muted(muted: bool) -> void:
	is_sfx_muted = muted
	var idx := AudioServer.get_bus_index(BUS_SFX)
	if idx != -1:
		AudioServer.set_bus_mute(idx, is_sfx_muted)
	_persist_settings()

func _persist_settings() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if is_instance_valid(gm) and gm.has_method("update_audio_settings"):
		gm.update_audio_settings(master_volume, music_volume, sfx_volume, is_music_muted, is_sfx_muted)

# --- 2. Music Management (Crossfading & Seamless Transitions) ---
func _setup_music_players() -> void:
	music_player_a = AudioStreamPlayer.new()
	music_player_a.name = "MusicPlayerA"
	music_player_a.bus = BUS_MUSIC
	add_child(music_player_a)

	music_player_b = AudioStreamPlayer.new()
	music_player_b.name = "MusicPlayerB"
	music_player_b.bus = BUS_MUSIC
	add_child(music_player_b)

	active_music_player = music_player_a

func play_menu_music(fade_sec: float = 0.35) -> void:
	if current_music_id == "menu" and active_music_player != null and active_music_player.playing:
		return # Already playing menu music; avoid restarting during menu scene navigation
	_transition_to_music("menu", MUSIC_MENU, fade_sec)

func play_race_music(fade_sec: float = 0.35) -> void:
	if current_music_id == "race" and active_music_player != null and active_music_player.playing:
		return
	_transition_to_music("race", MUSIC_RACE, fade_sec)

func stop_music(fade_sec: float = 0.35) -> void:
	if current_music_id.is_empty():
		return
	current_music_id = ""
	if music_tween and music_tween.is_valid():
		music_tween.kill()

	if active_music_player != null and active_music_player.playing:
		music_tween = create_tween()
		music_tween.tween_property(active_music_player, "volume_db", -40.0, fade_sec)
		music_tween.tween_callback(func(): active_music_player.stop())

func _transition_to_music(new_id: String, stream: AudioStream, fade_sec: float) -> void:
	current_music_id = new_id

	var next_player: AudioStreamPlayer = music_player_b if active_music_player == music_player_a else music_player_a
	var old_player: AudioStreamPlayer = active_music_player

	next_player.stream = stream
	next_player.volume_db = -30.0
	next_player.play()

	if music_tween and music_tween.is_valid():
		music_tween.kill()

	music_tween = create_tween()
	music_tween.set_parallel(true)
	music_tween.tween_property(next_player, "volume_db", 0.0, fade_sec)
	if old_player != null and old_player.playing:
		music_tween.tween_property(old_player, "volume_db", -40.0, fade_sec)

	music_tween.chain().tween_callback(func():
		if old_player != null:
			old_player.stop()
	)

	active_music_player = next_player

# --- 3. SFX Polyphonic Pool & UI Audio ---
func _setup_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = BUS_SFX
		add_child(p)
		sfx_players.append(p)

func play_sfx(stream: AudioStream, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _get_available_sfx_player()
	player.stream = stream
	player.volume_db = vol_db
	player.pitch_scale = pitch
	player.play()

func _get_available_sfx_player() -> AudioStreamPlayer:
	# First try to find an idle player
	for p in sfx_players:
		if not p.playing:
			return p
	# Otherwise reuse in round-robin fashion
	var chosen := sfx_players[next_sfx_idx]
	next_sfx_idx = (next_sfx_idx + 1) % sfx_players.size()
	return chosen

func play_ui_hover() -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - last_ui_hover_time < 0.045:
		return # Throttle micro-hovers
	last_ui_hover_time = now
	play_sfx(SFX_UI_HOVER, -6.0, randf_range(0.97, 1.03))

func play_ui_click() -> void:
	play_sfx(SFX_UI_CLICK, -2.0, randf_range(0.98, 1.02))

func play_track_select() -> void:
	play_sfx(SFX_TRACK_SELECT, 0.0, 1.0)

func play_achievement_unlock() -> void:
	play_sfx(SFX_ACHIEVEMENT, 2.0, 1.0)

func play_level_up() -> void:
	play_sfx(SFX_LEVEL_UP, 2.5, 1.0)

# Recursively connect UI sound feedback to all buttons in a scene
func attach_ui_sounds(node: Node) -> void:
	if node is BaseButton:
		if not node.mouse_entered.is_connected(play_ui_hover):
			node.mouse_entered.connect(play_ui_hover)
		if not node.pressed.is_connected(play_ui_click):
			node.pressed.connect(play_ui_click)

	for child in node.get_children():
		attach_ui_sounds(child)

# --- 4. Typing Feedback Audio ---
func play_type_click() -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - last_type_click_time < 0.032:
		return # Subtle throttle for fast typists
	last_type_click_time = now
	# Gentle random pitch variance simulates mechanical switch keystrokes
	play_sfx(SFX_TYPE_CLICK, -4.0, randf_range(0.96, 1.06))

func play_type_error() -> void:
	play_sfx(SFX_TYPE_ERROR, -1.0, 1.0)

func play_phrase_complete() -> void:
	play_sfx(SFX_PHRASE_COMPLETE, 0.0, 1.0)

# --- 5. Countdown & Race Events ---
func play_countdown_beep() -> void:
	play_sfx(SFX_COUNTDOWN_BEEP, 0.0, 1.0)

func play_race_start() -> void:
	play_sfx(SFX_RACE_START, 2.0, 1.0)

func play_finish_line() -> void:
	play_sfx(SFX_FINISH_LINE, 2.0, 1.0)

func play_victory() -> void:
	play_sfx(SFX_VICTORY, 2.5, 1.0)

func play_defeat() -> void:
	play_sfx(SFX_DEFEAT, 1.0, 1.0)

# --- 6. Sustained Nitro Audio ---
func _setup_nitro_player() -> void:
	nitro_player = AudioStreamPlayer.new()
	nitro_player.name = "NitroPlayer"
	nitro_player.bus = BUS_SFX
	nitro_player.stream = SFX_NITRO_LOOP
	add_child(nitro_player)

func play_nitro_boost() -> void:
	play_sfx(SFX_NITRO_BOOST, 1.5, 1.0)

func start_nitro_loop() -> void:
	if not nitro_player.playing:
		nitro_player.volume_db = -8.0
		nitro_player.play()
		var tw := create_tween()
		tw.tween_property(nitro_player, "volume_db", -1.0, 0.15)

func stop_nitro_loop() -> void:
	if nitro_player.playing:
		var tw := create_tween()
		tw.tween_property(nitro_player, "volume_db", -30.0, 0.2)
		tw.tween_callback(func(): nitro_player.stop())

# --- 7. Car Engine Sound System (Player 2D + AI 3D) ---
func _setup_engine_player() -> void:
	player_engine_player = AudioStreamPlayer.new()
	player_engine_player.name = "PlayerEnginePlayer"
	player_engine_player.bus = BUS_SFX
	player_engine_player.stream = SFX_ENGINE_LOOP
	player_engine_player.volume_db = -6.0
	add_child(player_engine_player)

func start_engine_sounds(player_car: Node3D, ai_cars: Array = []) -> void:
	# 1. Start Player Engine Player
	if player_engine_player:
		player_engine_player.volume_db = -6.0
		player_engine_player.pitch_scale = 0.85
		if not player_engine_player.playing:
			player_engine_player.play()

	# 2. Attach and start 3D engine players for AI opponents
	_cleanup_ai_engines()
	for ai_node in ai_cars:
		if is_instance_valid(ai_node):
			var ai_p := AudioStreamPlayer3D.new()
			ai_p.name = "AIEngine3D"
			ai_p.bus = BUS_SFX
			ai_p.stream = SFX_ENGINE_LOOP
			ai_p.max_distance = 65.0
			ai_p.unit_size = 10.0
			ai_p.volume_db = -12.0 # Attenuated so AI cars don't overpower player
			ai_p.pitch_scale = 0.85
			ai_p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			ai_node.add_child(ai_p)
			ai_p.play()
			ai_engine_players[ai_node] = ai_p

func update_engine_sounds(player_speed_kmh: float, ai_speeds: Dictionary = {}) -> void:
	# Calculate pitch based on vehicle speed (0 to ~160 km/h maps from 0.80 to 2.25)
	if player_engine_player and player_engine_player.playing:
		var target_pitch: float = clampf(0.80 + (player_speed_kmh / 150.0) * 1.35, 0.75, 2.30)
		player_engine_player.pitch_scale = move_toward(player_engine_player.pitch_scale, target_pitch, 0.08)

	for ai_node in ai_engine_players.keys():
		var ai_p: AudioStreamPlayer3D = ai_engine_players[ai_node]
		if is_instance_valid(ai_p) and ai_p.playing:
			var spd: float = float(ai_speeds.get(ai_node, 0.0))
			var ai_target_pitch: float = clampf(0.80 + (spd / 150.0) * 1.30, 0.75, 2.25)
			ai_p.pitch_scale = move_toward(ai_p.pitch_scale, ai_target_pitch, 0.08)

func stop_engine_sounds() -> void:
	if player_engine_player and player_engine_player.playing:
		player_engine_player.stop()
	_cleanup_ai_engines()

func _cleanup_ai_engines() -> void:
	for ai_node in ai_engine_players.keys():
		var ai_p: AudioStreamPlayer3D = ai_engine_players[ai_node]
		if is_instance_valid(ai_p):
			ai_p.stop()
			ai_p.queue_free()
	ai_engine_players.clear()

func stop_all_race_audio() -> void:
	stop_engine_sounds()
	stop_nitro_loop()
	stop_music(0.25)

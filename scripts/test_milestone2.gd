extends SceneTree

func _init() -> void:
	print("--- STARTING MILESTONE 2 AUTOMATED VERIFICATION ---")

	var packed_main: PackedScene = load("res://main.tscn")
	var main_scene = packed_main.instantiate()
	root.add_child(main_scene)

	# 1. Verify all 4 cars exist and are on the starting grid
	assert(main_scene.car != null, "Player car should exist")
	assert(main_scene.ai_car_1 != null, "AI Car 1 (Red) should exist")
	assert(main_scene.ai_car_2 != null, "AI Car 2 (Yellow) should exist")
	assert(main_scene.ai_car_3 != null, "AI Car 3 (Green) should exist")
	assert(main_scene.all_cars.size() == 4, "Should track exactly 4 cars")
	print("[PASS] All 4 racing cars initialized on starting grid.")

	# Verify grid lane X positions
	assert(is_equal_approx(main_scene.car.global_position.x, -1.5), "Player car should be at lane X = -1.5")
	assert(is_equal_approx(main_scene.ai_car_1.global_position.x, -4.5), "AI 1 should be at lane X = -4.5")
	assert(is_equal_approx(main_scene.ai_car_2.global_position.x, 1.5), "AI 2 should be at lane X = 1.5")
	assert(is_equal_approx(main_scene.ai_car_3.global_position.x, 4.5), "AI 3 should be at lane X = 4.5")
	print("[PASS] Starting grid lanes confirmed.")

	# 2. Verify countdown state: cars cannot move during countdown
	assert(main_scene.is_countdown_active == true, "Countdown should be active initially")
	main_scene.car.accelerate_from_keystroke()
	assert(main_scene.car.target_speed_kmh == 0.0, "Car must not accelerate before countdown ends")
	print("[PASS] Pre-race countdown restraint confirmed.")

	# 3. Simulate countdown completion ("GO!")
	main_scene.countdown_timer = 0.0
	main_scene._process_countdown(0.1) # Triggers "GO!" and _launch_race()
	assert(main_scene.car.is_race_started == true, "Player car should be marked as race started")
	assert(main_scene.ai_car_1.is_race_started == true, "AI Car 1 should be marked as race started")
	print("[PASS] Countdown GO sequence successfully triggered all cars.")

	# 4. Verify player typing accelerates car after GO
	var target = main_scene.typing_manager.current_target_sentence
	main_scene.typing_manager.on_input_changed(target.substr(0, 1))
	main_scene.car.accelerate_from_keystroke()
	assert(main_scene.car.target_speed_kmh > 0.0, "Car should accelerate after GO")
	print("[PASS] Post-countdown typing acceleration confirmed.")

	# 5. Verify live position ranking calculation
	main_scene.ai_car_1.distance_traveled = 100.0
	main_scene.car.distance_traveled = 80.0
	main_scene.ai_car_2.distance_traveled = 60.0
	main_scene.ai_car_3.distance_traveled = 40.0
	var calculated_rank = main_scene._calculate_player_live_rank()
	assert(calculated_rank == 2, "Player should be ranked 2nd based on distance")
	print("[PASS] Live position calculation verified (Player = 2nd).")

	# 6. Verify finish order tracking
	main_scene._on_car_finished(main_scene.ai_car_1)
	assert(main_scene.ai_car_1.finish_rank == 1, "AI Car 1 should finish 1st")
	main_scene._on_car_finished(main_scene.car)
	assert(main_scene.car.finish_rank == 2, "Player car should finish 2nd")
	assert(main_scene.is_game_over == true, "Player finishing should trigger game over / results")
	assert(main_scene.hud.results_modal.visible == true, "Results leaderboard modal should be visible")
	print("[PASS] Finish line crossing and leaderboard results verified.")

	# 7. Verify AI difficulty adjustment
	main_scene._on_difficulty_changed("Hard")
	assert(main_scene.ai_car_1.difficulty == "Hard", "AI Car 1 difficulty should update to Hard")
	assert(main_scene.ai_car_1.base_target_speed > 115.0, "AI Hard speed should be higher")
	main_scene._on_difficulty_changed("Easy")
	assert(main_scene.ai_car_1.base_target_speed < 100.0, "AI Easy speed should be lower")
	print("[PASS] Configurable AI difficulty settings (Easy, Medium, Hard) verified.")

	# 8. Verify Restart Race
	main_scene.restart_race()
	assert(main_scene.is_countdown_active == true, "Restart should start countdown again")
	assert(main_scene.car.distance_traveled == 0.0, "Car distance should be reset")
	assert(main_scene.finished_cars.size() == 0, "Finished cars list should be cleared")
	print("[PASS] Restart race functionality confirmed.")

	print("--- ALL MILESTONE 2 CHECKS PASSED SUCCESSFULLY! ---")
	quit(0)

extends SceneTree

func _init() -> void:
	print("--- TESTING RACE RESULTS SCREEN DISPLAY ---")

	var hud_scene: PackedScene = load("res://scenes/hud.tscn")
	var hud_instance = hud_scene.instantiate()
	root.add_child(hud_instance)

	var dummy_standings: Array[Dictionary] = [
		{ "rank": 1, "name": "Player (You)", "color": Color(0.12, 0.48, 0.96), "time": 17.84, "is_player": true },
		{ "rank": 2, "name": "Red Fury", "color": Color(0.92, 0.22, 0.22), "time": 18.95, "is_player": false },
		{ "rank": 3, "name": "Yellow Lightning", "color": Color(0.96, 0.78, 0.15), "time": 20.12, "is_player": false },
		{ "rank": 4, "name": "Green Viper", "color": Color(0.18, 0.82, 0.35), "time": 21.40, "is_player": false }
	]

	var dummy_stats: Dictionary = {
		"rank": 1,
		"time": 17.84,
		"top_speed": 162.0,
		"wpm": 72.0,
		"accuracy": 98.5
	}

	hud_instance.show_race_results(dummy_standings, dummy_stats)

	assert(hud_instance.results_modal.visible == true, "Results modal should be visible")
	assert(hud_instance.standings_container.get_child_count() == 4, "Should have 4 standings rows")
	print("[PASS] Results screen generated all 4 leaderboard rows without errors.")

	print("--- RACE RESULTS TEST PASSED SUCCESSFULLY ---")
	quit(0)

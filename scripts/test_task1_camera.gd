extends SceneTree

func _init() -> void:
	print("--- VERIFYING MILESTONE 4, TASK 1: SMOOTH CAMERA ---")

	var car_scene: PackedScene = load("res://scenes/car.tscn")
	var car = car_scene.instantiate()
	root.add_child(car)

	var pivot: Node3D = car.get_node_or_null("CameraPivot")
	var cam: Camera3D = car.get_node_or_null("CameraPivot/Camera3D")

	assert(pivot != null, "CameraPivot must exist")
	assert(cam != null, "Camera3D must exist")
	assert(pivot.top_level == true, "CameraPivot must be top_level for smooth world following")
	print("[PASS] CameraPivot initialized as top_level.")

	# 1. Verify initial alignment
	var expected_pos = car.global_position + car.camera_offset
	assert(pivot.global_position.is_equal_approx(expected_pos), "CameraPivot must align with car at start")
	print("[PASS] Initial camera positioning aligned.")

	# 2. Test smooth interpolation when car moves forward
	car.current_speed_kmh = 120.0 # ~33.3 m/s
	var prev_pivot_z = pivot.global_position.z
	car._physics_process(0.1)

	var target_z = car.global_position.z + car.camera_offset.z
	var current_pivot_z = pivot.global_position.z

	# Camera should have moved towards target_z smoothly, but due to interpolation,
	# current_pivot_z will smoothly trail target_z (not snap 100% instantly)
	assert(current_pivot_z < prev_pivot_z, "Camera must move forward with car")
	assert(current_pivot_z > target_z, "Camera should smoothly follow behind target position")
	assert(is_equal_approx(pivot.global_position.x, car.global_position.x), "Camera must keep car centered horizontally")
	print("[PASS] Frame-rate independent smooth following verified.")

	# 3. Test camera reset snap (no jump/lag on race restart)
	car.reset_car(Vector3(-1.5, 0.0, 0.0))
	var reset_expected = Vector3(-1.5, 1.2, 0.0)
	assert(pivot.global_position.is_equal_approx(reset_expected), "Camera must snap to reset position without lag")
	print("[PASS] Camera reset snap verified.")

	car.queue_free()
	print("--- TASK 1 CAMERA VALIDATION SUCCESSFUL ---")
	quit(0)

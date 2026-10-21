extends SceneTree

func _init() -> void:
	print("--- VERIFYING TASK 1: CAR GRAPHICS AND VISUALS ---")

	var player_car_scene: PackedScene = load("res://scenes/car.tscn")
	var player_car = player_car_scene.instantiate()
	root.add_child(player_car)

	assert(player_car.get_node_or_null("Visuals/BodyGroup/MainBody") != null, "Player car must have MainBody")
	assert(player_car.get_node_or_null("Visuals/BodyGroup/FrontSplitter") != null, "Player car must have FrontSplitter")
	assert(player_car.get_node_or_null("Visuals/BodyGroup/RearDiffuser") != null, "Player car must have RearDiffuser")
	assert(player_car.get_node_or_null("Visuals/CabinGroup/Windshield") != null, "Player car must have Windshield")
	assert(player_car.get_node_or_null("Visuals/SpoilerGroup/WingBlade") != null, "Player car must have WingBlade")
	assert(player_car.get_node_or_null("Visuals/LightsGroup/HeadlightL") != null, "Player car must have HeadlightL")
	assert(player_car.get_node_or_null("Visuals/LightsGroup/TaillightBar") != null, "Player car must have TaillightBar")

	# Check wheels
	var wheels_node = player_car.get_node_or_null("Visuals/Wheels")
	assert(wheels_node != null, "Wheels container must exist")
	assert(wheels_node.get_child_count() == 4, "Must have 4 wheels")
	for wheel in wheels_node.get_children():
		assert(wheel.get_node_or_null("Tire") != null, "Each wheel must have a Tire mesh")
		assert(wheel.get_node_or_null("Rim") != null, "Each wheel must have a Rim mesh")
		assert(wheel.get_node_or_null("Hub") != null, "Each wheel must have a Hub mesh")

	# Test wheel rotation on motion
	var initial_rot_x = wheels_node.get_child(0).rotation.x
	player_car.current_speed_kmh = 100.0
	player_car._physics_process(0.1)
	var new_rot_x = wheels_node.get_child(0).rotation.x
	assert(new_rot_x != initial_rot_x, "Wheels must rotate when car is moving")
	print("[PASS] Player sports car visual hierarchy and wheel rotation verified.")

	# Check AI Car
	var ai_car_scene: PackedScene = load("res://scenes/ai_car.tscn")
	var ai_car = ai_car_scene.instantiate()
	ai_car.car_color = Color(0.92, 0.22, 0.22, 1)
	root.add_child(ai_car)

	assert(ai_car.get_node_or_null("Visuals/BodyGroup/MainBody") != null, "AI car must have MainBody")
	var main_body_mesh: MeshInstance3D = ai_car.get_node("Visuals/BodyGroup/MainBody")
	assert(main_body_mesh.material_override != null, "AI car must have distinct material applied")
	assert(main_body_mesh.material_override.albedo_color == Color(0.92, 0.22, 0.22, 1), "AI car color must match")
	print("[PASS] AI sports car visual hierarchy and color assignment verified.")

	player_car.queue_free()
	ai_car.queue_free()
	print("--- TASK 1 VALIDATION SUCCESSFUL ---")
	quit(0)

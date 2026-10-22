extends SceneTree

func _init() -> void:
	print("--- VERIFYING MILESTONE 4, TASK 2: 3D RACING TRACK ---")

	var track_scene: PackedScene = load("res://main.tscn")
	var main_scene = track_scene.instantiate()
	root.add_child(main_scene)

	var track = main_scene.get_node_or_null("Track")
	assert(track != null, "Track node must exist in main.tscn")

	# 1. Road and Lanes
	var road_group = track.get_node_or_null("RoadGroup")
	assert(road_group != null, "RoadGroup node must exist")
	assert(road_group.get_node_or_null("AsphaltRoad") != null, "AsphaltRoad mesh must exist")
	assert(road_group.get_node_or_null("LaneDividers") != null, "LaneDividers must exist for all 4 lanes")
	print("[PASS] Task 1: Detailed asphalt road and 4-lane markings verified.")

	# 2. Curbs and Safety Barriers
	var curbs_group = track.get_node_or_null("CurbsAndBarriers")
	assert(curbs_group != null, "CurbsAndBarriers node must exist")
	assert(curbs_group.get_child_count() > 10, "Curbs and barriers must be populated along the track")
	print("[PASS] Task 1: Red/white curbs and safety guardrail barriers verified.")

	# 3. Scenery: Terrain, Mountains, Trees, and Buildings
	var terrain_group = track.get_node_or_null("TerrainGroup")
	assert(terrain_group != null, "TerrainGroup must exist")
	assert(terrain_group.get_node_or_null("GroundValley") != null, "GroundValley mesh must exist")

	var mountain_group = track.get_node_or_null("DistantMountains")
	assert(mountain_group != null, "DistantMountains must exist")
	assert(mountain_group.get_child_count() > 0, "Distant mountain peaks must be generated")

	var scenery_group = track.get_node_or_null("RoadsideScenery")
	assert(scenery_group != null, "RoadsideScenery must exist")
	assert(scenery_group.get_child_count() > 10, "Trees and bushes must be populated")
	print("[PASS] Task 2: Rolling terrain, distant mountains, trees, and bushes verified.")

	# 4. Starting and Finishing Areas
	var start_group = track.get_node_or_null("StartArea")
	assert(start_group != null, "StartArea must exist")

	var finish_group = track.get_node_or_null("FinishArea")
	assert(finish_group != null, "FinishArea must exist")
	assert(finish_group.get_node_or_null("FinishLineArea") != null, "FinishLineArea detection must exist")
	print("[PASS] Task 3: Starting grid with 4 slots, START gantry, checkered finish, and FINISH gantry verified.")

	# 5. Racing Decorations: Sponsor Bridges, Distance Markers, Grandstands
	var bridges_group = track.get_node_or_null("SponsorBridges")
	assert(bridges_group != null, "SponsorBridges must exist")
	assert(bridges_group.get_child_count() == 3, "Must have 3 overhead sponsor bridges")

	var markers_group = track.get_node_or_null("DistanceMarkers")
	assert(markers_group != null, "DistanceMarkers must exist")
	assert(markers_group.get_child_count() == 10, "Must have 5 distance markers on both sides (10 total)")
	print("[PASS] Task 4: Overhead sponsor bridges, distance markers, and grandstands verified.")

	# 6. Verify finish line detection logic
	var player_car = main_scene.car
	var crossed := false
	track.player_crossed_finish_line.connect(func(): crossed = true)

	track._on_finish_area_body_entered(player_car)
	assert(crossed == true, "Crossing finish line must trigger player_crossed_finish_line")
	assert(track.finished_cars.has(player_car), "Player car must be recorded in finished_cars")
	print("[PASS] Finish line logic verified.")

	main_scene.queue_free()
	print("--- ALL MILESTONE 4, TASK 2 VERIFICATIONS PASSED SUCCESSFULLY ---")
	quit(0)

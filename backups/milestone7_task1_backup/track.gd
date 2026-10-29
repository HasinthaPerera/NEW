extends Node3D
class_name RacingTrack

signal car_crossed_finish_line(car_node: Node3D)
signal player_crossed_finish_line

@export var track_length: float = 500.0 # From Z = 0 to Z = -500.0
@export var road_width: float = 14.0

var finish_line_z: float = -500.0
var finished_cars: Array[Node3D] = []

func _ready() -> void:
	finish_line_z = -track_length
	_generate_track_environment()
	_setup_start_area()
	_setup_finish_line()

func _generate_track_environment() -> void:
	_build_materials()
	_build_ground_and_terrain()
	_build_distant_mountains()
	_build_road_and_lanes()
	_build_curbs_and_barriers()
	_build_scenery_trees()
	_build_overhead_sponsor_bridges()
	_build_distance_markers()

# --- Cached Materials ---
var mat_grass: StandardMaterial3D
var mat_asphalt: StandardMaterial3D
var mat_stripe: StandardMaterial3D
var mat_red_curb: StandardMaterial3D
var mat_white_curb: StandardMaterial3D
var mat_metal_barrier: StandardMaterial3D
var mat_barrier_post: StandardMaterial3D
var mat_trunk: StandardMaterial3D
var mat_leaves_pine: StandardMaterial3D
var mat_leaves_oak: StandardMaterial3D
var mat_building_wall: StandardMaterial3D
var mat_building_roof: StandardMaterial3D
var mat_building_glass: StandardMaterial3D
var mat_mountain: StandardMaterial3D
var mat_snow: StandardMaterial3D
var mat_gantry: StandardMaterial3D
var mat_stand: StandardMaterial3D
var mat_crowd: StandardMaterial3D

func _build_materials() -> void:
	mat_grass = StandardMaterial3D.new()
	mat_grass.albedo_color = Color(0.24, 0.52, 0.22)
	mat_grass.roughness = 0.9

	mat_asphalt = StandardMaterial3D.new()
	mat_asphalt.albedo_color = Color(0.14, 0.15, 0.17)
	mat_asphalt.roughness = 0.85
	mat_asphalt.metallic = 0.1

	mat_stripe = StandardMaterial3D.new()
	mat_stripe.albedo_color = Color(0.96, 0.96, 0.96)
	mat_stripe.emission_enabled = true
	mat_stripe.emission = Color(0.92, 0.92, 0.92)
	mat_stripe.emission_energy_multiplier = 0.25

	mat_red_curb = StandardMaterial3D.new()
	mat_red_curb.albedo_color = Color(0.86, 0.16, 0.16)
	mat_red_curb.roughness = 0.7

	mat_white_curb = StandardMaterial3D.new()
	mat_white_curb.albedo_color = Color(0.94, 0.94, 0.96)
	mat_white_curb.roughness = 0.7

	mat_metal_barrier = StandardMaterial3D.new()
	mat_metal_barrier.albedo_color = Color(0.78, 0.82, 0.86)
	mat_metal_barrier.metallic = 0.85
	mat_metal_barrier.roughness = 0.35

	mat_barrier_post = StandardMaterial3D.new()
	mat_barrier_post.albedo_color = Color(0.3, 0.32, 0.35)
	mat_barrier_post.metallic = 0.7

	mat_trunk = StandardMaterial3D.new()
	mat_trunk.albedo_color = Color(0.35, 0.24, 0.15)
	mat_trunk.roughness = 0.9

	mat_leaves_pine = StandardMaterial3D.new()
	mat_leaves_pine.albedo_color = Color(0.12, 0.42, 0.18)
	mat_leaves_pine.roughness = 0.85

	mat_leaves_oak = StandardMaterial3D.new()
	mat_leaves_oak.albedo_color = Color(0.18, 0.54, 0.22)
	mat_leaves_oak.roughness = 0.85

	mat_building_wall = StandardMaterial3D.new()
	mat_building_wall.albedo_color = Color(0.88, 0.90, 0.92)
	mat_building_wall.roughness = 0.6

	mat_building_roof = StandardMaterial3D.new()
	mat_building_roof.albedo_color = Color(0.18, 0.20, 0.24)
	mat_building_roof.roughness = 0.5

	mat_building_glass = StandardMaterial3D.new()
	mat_building_glass.albedo_color = Color(0.12, 0.22, 0.35)
	mat_building_glass.metallic = 0.9
	mat_building_glass.roughness = 0.1

	mat_mountain = StandardMaterial3D.new()
	mat_mountain.albedo_color = Color(0.32, 0.36, 0.42)
	mat_mountain.roughness = 0.95

	mat_snow = StandardMaterial3D.new()
	mat_snow.albedo_color = Color(0.92, 0.95, 0.98)
	mat_snow.roughness = 0.8

	mat_gantry = StandardMaterial3D.new()
	mat_gantry.albedo_color = Color(0.85, 0.88, 0.92)
	mat_gantry.metallic = 0.8
	mat_gantry.roughness = 0.25

	mat_stand = StandardMaterial3D.new()
	mat_stand.albedo_color = Color(0.72, 0.75, 0.78)
	mat_stand.roughness = 0.7

	mat_crowd = StandardMaterial3D.new()
	mat_crowd.albedo_color = Color(0.85, 0.35, 0.25)
	mat_crowd.roughness = 0.9

# --- 1. Ground and Terrain ---
func _build_ground_and_terrain() -> void:
	var terrain_group := Node3D.new()
	terrain_group.name = "TerrainGroup"
	add_child(terrain_group)

	# Main flat green valley ground
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(320.0, 0.2, track_length + 300.0)
	ground_mesh.material = mat_grass

	var ground_node := MeshInstance3D.new()
	ground_node.name = "GroundValley"
	ground_node.mesh = ground_mesh
	ground_node.position = Vector3(0.0, -0.15, -(track_length / 2.0))
	terrain_group.add_child(ground_node)

	# Rolling terrain berms / side hills on left and right
	var hill_mesh := BoxMesh.new()
	hill_mesh.size = Vector3(40.0, 4.5, 45.0)
	hill_mesh.material = mat_grass

	var z_hill: float = 60.0
	while z_hill > -(track_length + 120.0):
		for side in [-1.0, 1.0]:
			var hill := MeshInstance3D.new()
			hill.mesh = hill_mesh
			var offset_x: float = side * (42.0 + sin(z_hill * 0.05) * 6.0)
			hill.position = Vector3(offset_x, 1.2, z_hill)
			hill.rotation_degrees = Vector3(0.0, sin(z_hill) * 20.0, side * 6.0)
			terrain_group.add_child(hill)
		z_hill -= 40.0

# --- 2. Distant Mountains ---
func _build_distant_mountains() -> void:
	var mountain_group := Node3D.new()
	mountain_group.name = "DistantMountains"
	add_child(mountain_group)

	# High background peaks along the horizon
	var peak_coords: Array[Vector3] = [
		Vector3(-140.0, 45.0, -(track_length + 220.0)),
		Vector3(-80.0, 65.0, -(track_length + 260.0)),
		Vector3(-15.0, 75.0, -(track_length + 290.0)),
		Vector3(50.0, 80.0, -(track_length + 270.0)),
		Vector3(120.0, 60.0, -(track_length + 240.0)),
		Vector3(180.0, 50.0, -(track_length + 210.0)),
		# Flank mountains
		Vector3(-180.0, 40.0, -200.0),
		Vector3(180.0, 42.0, -220.0),
		Vector3(-170.0, 38.0, 40.0),
		Vector3(175.0, 38.0, 20.0)
	]

	for i in range(peak_coords.size()):
		var coord := peak_coords[i]
		var radius_base := 50.0 + (i % 3) * 15.0
		var height_val := coord.y

		# Mountain body
		var m_mesh := CylinderMesh.new()
		m_mesh.top_radius = 0.0
		m_mesh.bottom_radius = radius_base
		m_mesh.height = height_val
		m_mesh.radial_segments = 6
		m_mesh.material = mat_mountain

		var mountain_inst := MeshInstance3D.new()
		mountain_inst.mesh = m_mesh
		mountain_inst.position = Vector3(coord.x, height_val / 2.0, coord.z)
		mountain_group.add_child(mountain_inst)

		# Snow cap peak
		var snow_mesh := CylinderMesh.new()
		snow_mesh.top_radius = 0.0
		snow_mesh.bottom_radius = radius_base * 0.32
		snow_mesh.height = height_val * 0.32
		snow_mesh.radial_segments = 6
		snow_mesh.material = mat_snow

		var snow_inst := MeshInstance3D.new()
		snow_inst.mesh = snow_mesh
		snow_inst.position = Vector3(coord.x, height_val - (height_val * 0.16), coord.z)
		mountain_group.add_child(snow_inst)

# --- 3. Road Surface and Lane Markings ---
func _build_road_and_lanes() -> void:
	var road_group := Node3D.new()
	road_group.name = "RoadGroup"
	add_child(road_group)

	# Main asphalt road surface
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(road_width, 0.1, track_length + 200.0)
	road_mesh.material = mat_asphalt

	var road_node := MeshInstance3D.new()
	road_node.name = "AsphaltRoad"
	road_node.mesh = road_mesh
	road_node.position = Vector3(0.0, -0.05, -(track_length / 2.0))
	road_group.add_child(road_node)

	# Outer solid white boundary lines
	var solid_line_mesh := BoxMesh.new()
	solid_line_mesh.size = Vector3(0.24, 0.015, track_length + 200.0)
	solid_line_mesh.material = mat_stripe

	var bound_left := MeshInstance3D.new()
	bound_left.mesh = solid_line_mesh
	bound_left.position = Vector3(-6.2, 0.012, -(track_length / 2.0))
	road_group.add_child(bound_left)

	var bound_right := MeshInstance3D.new()
	bound_right.mesh = solid_line_mesh
	bound_right.position = Vector3(6.2, 0.012, -(track_length / 2.0))
	road_group.add_child(bound_right)

	# Lane Dividers for 4 racing lanes:
	# Lane centers: -4.5 (Lane 1), -1.5 (Lane 2 - Player), +1.5 (Lane 3), +4.5 (Lane 4)
	# Dividing lines at: X = -3.0, X = 0.0 (center), X = +3.0
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.22, 0.015, 3.5)
	dash_mesh.material = mat_stripe

	var center_dash_mesh := BoxMesh.new()
	center_dash_mesh.size = Vector3(0.35, 0.016, 4.0)
	center_dash_mesh.material = mat_stripe

	var dashes_container := Node3D.new()
	dashes_container.name = "LaneDividers"
	road_group.add_child(dashes_container)

	var z_cursor: float = 40.0
	while z_cursor > -(track_length + 90.0):
		# Line between Lane 1 and Lane 2
		var d1 := MeshInstance3D.new()
		d1.mesh = dash_mesh
		d1.position = Vector3(-3.0, 0.012, z_cursor)
		dashes_container.add_child(d1)

		# Center dashed line between Lane 2 and Lane 3
		var d_center := MeshInstance3D.new()
		d_center.mesh = center_dash_mesh
		d_center.position = Vector3(0.0, 0.013, z_cursor)
		dashes_container.add_child(d_center)

		# Line between Lane 3 and Lane 4
		var d2 := MeshInstance3D.new()
		d2.mesh = dash_mesh
		d2.position = Vector3(3.0, 0.012, z_cursor)
		dashes_container.add_child(d2)

		z_cursor -= 7.5

# --- 4. Curbs and Safety Barriers ---
func _build_curbs_and_barriers() -> void:
	var curbs_group := Node3D.new()
	curbs_group.name = "CurbsAndBarriers"
	add_child(curbs_group)

	# Alternating Red/White Kerbs
	var curb_box := BoxMesh.new()
	curb_box.size = Vector3(0.55, 0.14, 1.8)

	var curb_z: float = 40.0
	var is_red: bool = false
	while curb_z > -(track_length + 90.0):
		is_red = not is_red
		var mat_use: StandardMaterial3D = mat_red_curb if is_red else mat_white_curb

		var left_curb := MeshInstance3D.new()
		left_curb.mesh = curb_box
		left_curb.material_override = mat_use
		left_curb.position = Vector3(-7.25, 0.06, curb_z)
		curbs_group.add_child(left_curb)

		var right_curb := MeshInstance3D.new()
		right_curb.mesh = curb_box
		right_curb.material_override = mat_use
		right_curb.position = Vector3(7.25, 0.06, curb_z)
		curbs_group.add_child(right_curb)

		curb_z -= 2.0

	# Continuous Armco Safety Guardrail Barriers
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.12, 0.45, track_length + 220.0)
	rail_mesh.material = mat_metal_barrier

	var rail_l := MeshInstance3D.new()
	rail_l.mesh = rail_mesh
	rail_l.position = Vector3(-8.2, 0.55, -(track_length / 2.0))
	curbs_group.add_child(rail_l)

	var rail_r := MeshInstance3D.new()
	rail_r.mesh = rail_mesh
	rail_r.position = Vector3(8.2, 0.55, -(track_length / 2.0))
	curbs_group.add_child(rail_r)

	# Barrier support posts with safety reflectors
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.16, 0.85, 0.16)
	post_mesh.material = mat_barrier_post

	var post_z: float = 40.0
	while post_z > -(track_length + 90.0):
		var pl := MeshInstance3D.new()
		pl.mesh = post_mesh
		pl.position = Vector3(-8.2, 0.42, post_z)
		curbs_group.add_child(pl)

		var pr := MeshInstance3D.new()
		pr.mesh = post_mesh
		pr.position = Vector3(8.2, 0.42, post_z)
		curbs_group.add_child(pr)

		post_z -= 8.0

# --- 5. Trees, Bushes, and Scenery ---
func _build_scenery_trees() -> void:
	var scenery_group := Node3D.new()
	scenery_group.name = "RoadsideScenery"
	add_child(scenery_group)

	# Pine tree parts
	var pine_trunk := CylinderMesh.new()
	pine_trunk.top_radius = 0.22
	pine_trunk.bottom_radius = 0.35
	pine_trunk.height = 2.4
	pine_trunk.material = mat_trunk

	var pine_cone := CylinderMesh.new()
	pine_cone.top_radius = 0.0
	pine_cone.bottom_radius = 1.9
	pine_cone.height = 3.6
	pine_cone.material = mat_leaves_pine

	# Oak tree parts
	var oak_crown := SphereMesh.new()
	oak_crown.radius = 2.1
	oak_crown.height = 3.8
	oak_crown.material = mat_leaves_oak

	# Low roadside bush
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 0.9
	bush_mesh.height = 1.4
	bush_mesh.material = mat_leaves_oak

	var z_pos: float = 30.0
	var counter: int = 0
	while z_pos > -(track_length + 80.0):
		counter += 1
		for side in [-1.0, 1.0]:
			var tree_root := Node3D.new()
			var dist_x: float = side * (11.5 + (counter % 4) * 2.5)
			tree_root.position = Vector3(dist_x, 0.0, z_pos)

			var trunk := MeshInstance3D.new()
			trunk.mesh = pine_trunk
			trunk.position = Vector3(0.0, 1.2, 0.0)
			tree_root.add_child(trunk)

			if counter % 2 == 0:
				# Pine Tree (2 tiered foliage)
				var cone1 := MeshInstance3D.new()
				cone1.mesh = pine_cone
				cone1.position = Vector3(0.0, 3.2, 0.0)
				tree_root.add_child(cone1)

				var cone2 := MeshInstance3D.new()
				cone2.mesh = pine_cone
				cone2.scale = Vector3(0.72, 0.72, 0.72)
				cone2.position = Vector3(0.0, 4.8, 0.0)
				tree_root.add_child(cone2)
			else:
				# Oak Tree
				var crown := MeshInstance3D.new()
				crown.mesh = oak_crown
				crown.position = Vector3(0.0, 3.6, 0.0)
				tree_root.add_child(crown)

			scenery_group.add_child(tree_root)

			# Roadside bush near barrier
			var bush := MeshInstance3D.new()
			bush.mesh = bush_mesh
			bush.position = Vector3(side * 9.2, 0.5, z_pos + 6.0)
			scenery_group.add_child(bush)

		z_pos -= 18.0

# --- 6. Starting Area ---
func _setup_start_area() -> void:
	var start_group := Node3D.new()
	start_group.name = "StartArea"
	start_group.position = Vector3(0.0, 0.0, 0.0)
	add_child(start_group)

	# 1. Starting Line strip on the road
	var start_line_mesh := BoxMesh.new()
	start_line_mesh.size = Vector3(road_width - 1.0, 0.02, 0.7)
	start_line_mesh.material = mat_stripe

	var start_line_inst := MeshInstance3D.new()
	start_line_inst.mesh = start_line_mesh
	start_line_inst.position = Vector3(0.0, 0.015, -2.5)
	start_group.add_child(start_line_inst)

	# 2. 4 Starting Grid Boxes for the cars (X = -4.5, -1.5, +1.5, +4.5)
	var grid_box_mesh := BoxMesh.new()
	grid_box_mesh.size = Vector3(2.2, 0.02, 4.4)
	grid_box_mesh.material = mat_stripe

	for lane_x in [-4.5, -1.5, 1.5, 4.5]:
		var gbox := MeshInstance3D.new()
		gbox.mesh = grid_box_mesh
		gbox.position = Vector3(lane_x, 0.012, 0.0)
		start_group.add_child(gbox)

	# 3. Overhead START Truss Gantry
	var p_mesh := BoxMesh.new()
	p_mesh.size = Vector3(0.8, 7.5, 0.8)
	p_mesh.material = mat_gantry

	var pl := MeshInstance3D.new()
	pl.mesh = p_mesh
	pl.position = Vector3(-(road_width / 2.0 + 1.2), 3.75, 4.0)
	start_group.add_child(pl)

	var pr := MeshInstance3D.new()
	pr.mesh = p_mesh
	pr.position = Vector3((road_width / 2.0 + 1.2), 3.75, 4.0)
	start_group.add_child(pr)

	var cross_mesh := BoxMesh.new()
	cross_mesh.size = Vector3(road_width + 3.2, 1.2, 0.9)
	cross_mesh.material = mat_gantry

	var crossbar := MeshInstance3D.new()
	crossbar.mesh = cross_mesh
	crossbar.position = Vector3(0.0, 7.0, 4.0)
	start_group.add_child(crossbar)

	# START Banner Sign
	var banner_mat := StandardMaterial3D.new()
	banner_mat.albedo_color = Color(0.1, 0.65, 0.3)
	banner_mat.emission_enabled = true
	banner_mat.emission = Color(0.15, 0.8, 0.35)
	banner_mat.emission_energy_multiplier = 1.0

	var s_banner_mesh := BoxMesh.new()
	s_banner_mesh.size = Vector3(10.0, 1.1, 0.95)
	s_banner_mesh.material = banner_mat

	var start_banner := MeshInstance3D.new()
	start_banner.mesh = s_banner_mesh
	start_banner.position = Vector3(0.0, 7.0, 4.0)
	start_group.add_child(start_banner)

	# Starter Light Pods
	var light_mesh := SphereMesh.new()
	light_mesh.radius = 0.22
	light_mesh.height = 0.44
	var light_mat := StandardMaterial3D.new()
	light_mat.albedo_color = Color(1.0, 0.2, 0.2)
	light_mat.emission_enabled = true
	light_mat.emission = Color(1.0, 0.2, 0.2)
	light_mat.emission_energy_multiplier = 3.0
	light_mesh.material = light_mat

	for lx in [-2.5, -1.25, 0.0, 1.25, 2.5]:
		var l_inst := MeshInstance3D.new()
		l_inst.mesh = light_mesh
		l_inst.position = Vector3(lx, 6.1, 3.9)
		start_group.add_child(l_inst)

	# 4. Pit-Lane Garages / Paddock Building on the Right
	var paddock_mesh := BoxMesh.new()
	paddock_mesh.size = Vector3(7.0, 4.5, 60.0)
	paddock_mesh.material = mat_building_wall

	var paddock := MeshInstance3D.new()
	paddock.mesh = paddock_mesh
	paddock.position = Vector3(13.8, 2.25, -15.0)
	start_group.add_child(paddock)

	var paddock_roof_mesh := BoxMesh.new()
	paddock_roof_mesh.size = Vector3(7.4, 0.5, 61.0)
	paddock_roof_mesh.material = mat_building_roof

	var paddock_roof := MeshInstance3D.new()
	paddock_roof.mesh = paddock_roof_mesh
	paddock_roof.position = Vector3(13.8, 4.6, -15.0)
	start_group.add_child(paddock_roof)

	# 5. Spectator Grandstand on the Left
	_create_grandstand(start_group, Vector3(-14.5, 0.0, -10.0), 50.0)

# --- 7. Finishing Area ---
func _setup_finish_line() -> void:
	var finish_group := Node3D.new()
	finish_group.name = "FinishArea"
	finish_group.position = Vector3(0.0, 0.0, finish_line_z)
	add_child(finish_group)

	# Checkered road line at finish
	var check_mat_b := StandardMaterial3D.new()
	check_mat_b.albedo_color = Color(0.05, 0.05, 0.05)
	check_mat_b.roughness = 0.8

	var check_mat_w := StandardMaterial3D.new()
	check_mat_w.albedo_color = Color(1.0, 1.0, 1.0)
	check_mat_w.emission_enabled = true
	check_mat_w.emission = Color(1.0, 1.0, 1.0)
	check_mat_w.emission_energy_multiplier = 0.5

	var check_box := BoxMesh.new()
	check_box.size = Vector3(1.0, 0.03, 1.0)

	for row in range(2):
		for col in range(-7, 8):
			var tile := MeshInstance3D.new()
			tile.mesh = check_box
			var is_white := (row + col) % 2 == 0
			tile.material_override = check_mat_w if is_white else check_mat_b
			tile.position = Vector3(float(col) * 1.0, 0.02, float(row) * 1.0 - 0.5)
			finish_group.add_child(tile)

	# Finish Line Overhead Gantry Pillars
	var p_mesh := BoxMesh.new()
	p_mesh.size = Vector3(0.8, 7.5, 0.8)
	p_mesh.material = mat_gantry

	var left_pillar := MeshInstance3D.new()
	left_pillar.mesh = p_mesh
	left_pillar.position = Vector3(-(road_width / 2.0 + 1.2), 3.75, 0.0)
	finish_group.add_child(left_pillar)

	var right_pillar := MeshInstance3D.new()
	right_pillar.mesh = p_mesh
	right_pillar.position = Vector3((road_width / 2.0 + 1.2), 3.75, 0.0)
	finish_group.add_child(right_pillar)

	# Crossbeam
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(road_width + 3.2, 1.4, 1.0)
	beam_mesh.material = mat_gantry

	var crossbeam := MeshInstance3D.new()
	crossbeam.mesh = beam_mesh
	crossbeam.position = Vector3(0.0, 7.0, 0.0)
	finish_group.add_child(crossbeam)

	# FINISH Banner
	var finish_banner_mat := StandardMaterial3D.new()
	finish_banner_mat.albedo_color = Color(0.95, 0.78, 0.05)
	finish_banner_mat.emission_enabled = true
	finish_banner_mat.emission = Color(0.95, 0.78, 0.05)
	finish_banner_mat.emission_energy_multiplier = 1.0

	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(11.0, 1.2, 1.05)
	banner_mesh.material = finish_banner_mat

	var banner := MeshInstance3D.new()
	banner.mesh = banner_mesh
	banner.position = Vector3(0.0, 7.0, 0.0)
	finish_group.add_child(banner)

	# Finish Area Grandstand on Left
	_create_grandstand(finish_group, Vector3(-14.5, 0.0, -10.0), 55.0)

	# Race Control / Timing Tower on Right
	var tower_base := BoxMesh.new()
	tower_base.size = Vector3(6.5, 12.0, 6.5)
	tower_base.material = mat_building_wall

	var tower := MeshInstance3D.new()
	tower.mesh = tower_base
	tower.position = Vector3(14.0, 6.0, 0.0)
	finish_group.add_child(tower)

	var tower_glass := BoxMesh.new()
	tower_glass.size = Vector3(6.8, 3.0, 6.8)
	tower_glass.material = mat_building_glass

	var glass_deck := MeshInstance3D.new()
	glass_deck.mesh = tower_glass
	glass_deck.position = Vector3(14.0, 9.5, 0.0)
	finish_group.add_child(glass_deck)

	# Finish Line Area3D Detection
	var area := Area3D.new()
	area.name = "FinishLineArea"
	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(road_width + 4.0, 6.0, 4.0)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 3.0, 0.0)
	area.add_child(col_shape)
	finish_group.add_child(area)

	area.body_entered.connect(_on_finish_area_body_entered)

# --- Helper: Create Tiered Grandstand with Crowd ---
func _create_grandstand(parent_node: Node3D, pos: Vector3, length_val: float) -> void:
	var gstand_root := Node3D.new()
	gstand_root.position = pos
	parent_node.add_child(gstand_root)

	# 4 Stepped tiers
	for tier in range(4):
		var tier_mesh := BoxMesh.new()
		tier_mesh.size = Vector3(1.4, 0.6 * (tier + 1), length_val)
		tier_mesh.material = mat_stand

		var tier_inst := MeshInstance3D.new()
		tier_inst.mesh = tier_mesh
		tier_inst.position = Vector3(-float(tier) * 1.2, (0.6 * (tier + 1)) / 2.0, 0.0)
		gstand_root.add_child(tier_inst)

		# Crowd blocks on tier
		var crowd_mesh := BoxMesh.new()
		crowd_mesh.size = Vector3(0.8, 0.7, length_val - 2.0)
		crowd_mesh.material = mat_crowd

		var crowd_inst := MeshInstance3D.new()
		crowd_inst.mesh = crowd_mesh
		crowd_inst.position = Vector3(-float(tier) * 1.2, 0.6 * (tier + 1) + 0.35, 0.0)
		gstand_root.add_child(crowd_inst)

# --- 8. Overhead Sponsor Bridges & Distance Markers ---
func _build_overhead_sponsor_bridges() -> void:
	var bridges_group := Node3D.new()
	bridges_group.name = "SponsorBridges"
	add_child(bridges_group)

	var bridge_positions: Array[float] = [-150.0, -300.0, -420.0]
	var bridge_colors: Array[Color] = [
		Color(0.12, 0.45, 0.95), # APEX Blue
		Color(0.95, 0.35, 0.1),  # OCTANE Orange
		Color(0.85, 0.15, 0.2)   # HYPERDRIVE Crimson
	]

	for i in range(bridge_positions.size()):
		var b_z: float = bridge_positions[i]
		var b_col: Color = bridge_colors[i]

		var b_root := Node3D.new()
		b_root.position = Vector3(0.0, 0.0, b_z)
		bridges_group.add_child(b_root)

		# Side pillars
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.7, 7.0, 0.7)
		pillar_mesh.material = mat_gantry

		var pl := MeshInstance3D.new()
		pl.mesh = pillar_mesh
		pl.position = Vector3(-(road_width / 2.0 + 1.2), 3.5, 0.0)
		b_root.add_child(pl)

		var pr := MeshInstance3D.new()
		pr.mesh = pillar_mesh
		pr.position = Vector3((road_width / 2.0 + 1.2), 3.5, 0.0)
		b_root.add_child(pr)

		# Crossbar
		var c_mesh := BoxMesh.new()
		c_mesh.size = Vector3(road_width + 3.0, 1.2, 0.8)
		c_mesh.material = mat_gantry

		var crossbar := MeshInstance3D.new()
		crossbar.mesh = c_mesh
		crossbar.position = Vector3(0.0, 6.5, 0.0)
		b_root.add_child(crossbar)

		# Illuminated Sponsor Banner
		var s_mat := StandardMaterial3D.new()
		s_mat.albedo_color = b_col
		s_mat.emission_enabled = true
		s_mat.emission = b_col
		s_mat.emission_energy_multiplier = 0.85

		var s_mesh := BoxMesh.new()
		s_mesh.size = Vector3(10.5, 1.0, 0.85)
		s_mesh.material = s_mat

		var banner := MeshInstance3D.new()
		banner.mesh = s_mesh
		banner.position = Vector3(0.0, 6.5, 0.0)
		b_root.add_child(banner)

func _build_distance_markers() -> void:
	var markers_group := Node3D.new()
	markers_group.name = "DistanceMarkers"
	add_child(markers_group)

	# Distance boards at remaining distances:
	# At Z = -100: 400M remaining
	# At Z = -200: 300M remaining
	# At Z = -300: 200M remaining
	# At Z = -400: 100M remaining
	# At Z = -450: 50M remaining
	var marker_z_list: Array[float] = [-100.0, -200.0, -300.0, -400.0, -450.0]

	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(0.2, 1.4, 2.0)
	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.96, 0.85, 0.15)
	sign_mat.emission_enabled = true
	sign_mat.emission = Color(0.96, 0.85, 0.15)
	sign_mat.emission_energy_multiplier = 0.4
	sign_mesh.material = sign_mat

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.08
	post_mesh.bottom_radius = 0.08
	post_mesh.height = 2.4
	post_mesh.material = mat_barrier_post

	for m_z: float in marker_z_list:
		for side in [-1.0, 1.0]:
			var m_root := Node3D.new()
			m_root.position = Vector3(side * 8.8, 0.0, m_z)

			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.position = Vector3(0.0, 1.2, 0.0)
			m_root.add_child(post)

			var board := MeshInstance3D.new()
			board.mesh = sign_mesh
			board.position = Vector3(0.0, 2.1, 0.0)
			m_root.add_child(board)

			markers_group.add_child(m_root)

# --- Finish Line Collision & Trigger Logic ---
func _on_finish_area_body_entered(body: Node3D) -> void:
	if body in finished_cars:
		return
	if body.has_method("finish_race") or body.name.to_lower().contains("car"):
		finished_cars.append(body)
		car_crossed_finish_line.emit(body)
		if body is PlayerCar or body.name == "Car":
			player_crossed_finish_line.emit()

func reset_finish() -> void:
	finished_cars.clear()

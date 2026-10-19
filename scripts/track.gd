extends Node3D
class_name RacingTrack

signal player_crossed_finish_line

@export var track_length: float = 500.0 # From Z = 0 to Z = -500.0
@export var road_width: float = 14.0

var finish_line_z: float = -500.0
var finish_triggered: bool = false

func _ready() -> void:
	finish_line_z = -track_length
	_generate_track_environment()
	_setup_finish_line()

func _generate_track_environment() -> void:
	# Materials
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.22, 0.55, 0.24)
	grass_mat.roughness = 0.9

	var asphalt_mat := StandardMaterial3D.new()
	asphalt_mat.albedo_color = Color(0.18, 0.19, 0.22)
	asphalt_mat.roughness = 0.8

	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.95, 0.95, 0.95)
	stripe_mat.emission_enabled = true
	stripe_mat.emission = Color(0.9, 0.9, 0.9)
	stripe_mat.emission_energy_multiplier = 0.2

	var red_curb_mat := StandardMaterial3D.new()
	red_curb_mat.albedo_color = Color(0.85, 0.18, 0.18)

	var white_curb_mat := StandardMaterial3D.new()
	white_curb_mat.albedo_color = Color(0.92, 0.92, 0.95)

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.38, 0.25, 0.15)

	var leaves_mat := StandardMaterial3D.new()
	leaves_mat.albedo_color = Color(0.15, 0.50, 0.20)

	# 1. Grass Ground
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(250.0, 0.2, track_length + 200.0)
	ground_mesh.material = grass_mat

	var ground_node := MeshInstance3D.new()
	ground_node.name = "GroundGrass"
	ground_node.mesh = ground_mesh
	ground_node.position = Vector3(0.0, -0.15, -(track_length / 2.0))
	add_child(ground_node)

	# 2. Asphalt Road
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(road_width, 0.1, track_length + 150.0)
	road_mesh.material = asphalt_mat

	var road_node := MeshInstance3D.new()
	road_node.name = "AsphaltRoad"
	road_node.mesh = road_mesh
	road_node.position = Vector3(0.0, -0.05, -(track_length / 2.0))
	add_child(road_node)

	# 3. Shoulder Lines (Solid white)
	var shoulder_mesh := BoxMesh.new()
	shoulder_mesh.size = Vector3(0.25, 0.02, track_length + 150.0)
	shoulder_mesh.material = stripe_mat

	var shoulder_left := MeshInstance3D.new()
	shoulder_left.mesh = shoulder_mesh
	shoulder_left.position = Vector3(-(road_width / 2.0 - 0.7), 0.01, -(track_length / 2.0))
	add_child(shoulder_left)

	var shoulder_right := MeshInstance3D.new()
	shoulder_right.mesh = shoulder_mesh
	shoulder_right.position = Vector3((road_width / 2.0 - 0.7), 0.01, -(track_length / 2.0))
	add_child(shoulder_right)

	# 4. Center Dashed Line
	var center_dash_mesh := BoxMesh.new()
	center_dash_mesh.size = Vector3(0.35, 0.02, 3.5)
	center_dash_mesh.material = stripe_mat

	var dashes_container := Node3D.new()
	dashes_container.name = "CenterDashes"
	add_child(dashes_container)

	var z_cursor: float = 30.0
	while z_cursor > -(track_length + 80.0):
		var dash := MeshInstance3D.new()
		dash.mesh = center_dash_mesh
		dash.position = Vector3(0.0, 0.01, z_cursor)
		dashes_container.add_child(dash)
		z_cursor -= 7.0

	# 5. Red & White Curbs
	var curb_box := BoxMesh.new()
	curb_box.size = Vector3(0.5, 0.12, 1.8)

	var curbs_container := Node3D.new()
	curbs_container.name = "RoadsideCurbs"
	add_child(curbs_container)

	var curb_z: float = 30.0
	var is_red: bool = false
	while curb_z > -(track_length + 80.0):
		is_red = not is_red
		var mat_to_use: StandardMaterial3D = red_curb_mat if is_red else white_curb_mat

		var left_curb := MeshInstance3D.new()
		left_curb.mesh = curb_box
		left_curb.material_override = mat_to_use
		left_curb.position = Vector3(-(road_width / 2.0 + 0.25), 0.05, curb_z)
		curbs_container.add_child(left_curb)

		var right_curb := MeshInstance3D.new()
		right_curb.mesh = curb_box
		right_curb.material_override = mat_to_use
		right_curb.position = Vector3((road_width / 2.0 + 0.25), 0.05, curb_z)
		curbs_container.add_child(right_curb)

		curb_z -= 2.0

	# 6. Roadside Trees / Posts for motion parallax & speed perception
	var tree_trunk_mesh := CylinderMesh.new()
	tree_trunk_mesh.top_radius = 0.25
	tree_trunk_mesh.bottom_radius = 0.35
	tree_trunk_mesh.height = 2.0
	tree_trunk_mesh.material = trunk_mat

	var tree_crown_mesh := SphereMesh.new()
	tree_crown_mesh.radius = 1.6
	tree_crown_mesh.height = 3.2
	tree_crown_mesh.material = leaves_mat

	var scenery_container := Node3D.new()
	scenery_container.name = "RoadsideScenery"
	add_child(scenery_container)

	var scenery_z: float = 20.0
	while scenery_z > -(track_length + 70.0):
		for side in [-1.0, 1.0]:
			var tree_root := Node3D.new()
			tree_root.position = Vector3(side * (road_width / 2.0 + 3.5), 0.0, scenery_z)

			var trunk := MeshInstance3D.new()
			trunk.mesh = tree_trunk_mesh
			trunk.position = Vector3(0.0, 1.0, 0.0)
			tree_root.add_child(trunk)

			var crown := MeshInstance3D.new()
			crown.mesh = tree_crown_mesh
			crown.position = Vector3(0.0, 3.0, 0.0)
			tree_root.add_child(crown)

			scenery_container.add_child(tree_root)

		scenery_z -= 24.0

func _setup_finish_line() -> void:
	var finish_group := Node3D.new()
	finish_group.name = "FinishLineStructure"
	finish_group.position = Vector3(0.0, 0.0, finish_line_z)
	add_child(finish_group)

	# Checkered road line at finish
	var checker_mat_black := StandardMaterial3D.new()
	checker_mat_black.albedo_color = Color(0.05, 0.05, 0.05)

	var checker_mat_white := StandardMaterial3D.new()
	checker_mat_white.albedo_color = Color(1.0, 1.0, 1.0)
	checker_mat_white.emission_enabled = true
	checker_mat_white.emission = Color(1.0, 1.0, 1.0)
	checker_mat_white.emission_energy_multiplier = 0.5

	var check_box := BoxMesh.new()
	check_box.size = Vector3(1.0, 0.03, 1.0)

	for row in range(2):
		for col in range(-7, 8):
			var tile := MeshInstance3D.new()
			tile.mesh = check_box
			var is_white := (row + col) % 2 == 0
			tile.material_override = checker_mat_white if is_white else checker_mat_black
			tile.position = Vector3(float(col) * 1.0, 0.02, float(row) * 1.0 - 0.5)
			finish_group.add_child(tile)

	# Arch Pillars
	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = Color(0.85, 0.85, 0.9)
	arch_mat.metallic = 0.7
	arch_mat.roughness = 0.2

	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.8, 6.5, 0.8)
	pillar_mesh.material = arch_mat

	var left_pillar := MeshInstance3D.new()
	left_pillar.mesh = pillar_mesh
	left_pillar.position = Vector3(-(road_width / 2.0 + 1.0), 3.25, 0.0)
	finish_group.add_child(left_pillar)

	var right_pillar := MeshInstance3D.new()
	right_pillar.mesh = pillar_mesh
	right_pillar.position = Vector3((road_width / 2.0 + 1.0), 3.25, 0.0)
	finish_group.add_child(right_pillar)

	# Crossbeam
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(road_width + 3.0, 1.4, 1.0)
	beam_mesh.material = arch_mat

	var crossbeam := MeshInstance3D.new()
	crossbeam.mesh = beam_mesh
	crossbeam.position = Vector3(0.0, 6.0, 0.0)
	finish_group.add_child(crossbeam)

	# Finish Banner text
	var banner_mat := StandardMaterial3D.new()
	banner_mat.albedo_color = Color(0.9, 0.75, 0.05)
	banner_mat.emission_enabled = true
	banner_mat.emission = Color(0.9, 0.75, 0.05)
	banner_mat.emission_energy_multiplier = 0.8

	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(10.0, 1.0, 1.05)
	banner_mesh.material = banner_mat

	var banner := MeshInstance3D.new()
	banner.mesh = banner_mesh
	banner.position = Vector3(0.0, 6.0, 0.0)
	finish_group.add_child(banner)

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

func _on_finish_area_body_entered(body: Node3D) -> void:
	if finish_triggered:
		return
	if body.has_method("finish_race") or body.name.to_lower().contains("car"):
		finish_triggered = true
		player_crossed_finish_line.emit()

func reset_finish() -> void:
	finish_triggered = false

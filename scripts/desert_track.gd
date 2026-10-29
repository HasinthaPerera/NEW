extends Node3D
class_name DesertRacingTrack

# Desert Dash — 3D Desert Racing Circuit
# Milestone 7, Task 2: Stylized arcade desert highway featuring smooth curves,
# sandstone mesas, sand dunes, saguaro cacti, rock formations, and checkered finish gantry.

signal car_crossed_finish_line(car_node: Node3D)
signal player_crossed_finish_line

@export var track_length: float = 750.0 # From Z = 0.0 to Z = -750.0
@export var road_width: float = 14.0

var finish_line_z: float = -750.0
var finished_cars: Array[Node3D] = []

# Cached Materials
var mat_sand: StandardMaterial3D
var mat_red_rock: StandardMaterial3D
var mat_mesa_top: StandardMaterial3D
var mat_dune: StandardMaterial3D
var mat_asphalt: StandardMaterial3D
var mat_yellow_line: StandardMaterial3D
var mat_white_line: StandardMaterial3D
var mat_curb_yellow: StandardMaterial3D
var mat_curb_black: StandardMaterial3D
var mat_guardrail: StandardMaterial3D
var mat_guardrail_post: StandardMaterial3D
var mat_cactus: StandardMaterial3D
var mat_shrub: StandardMaterial3D
var mat_gantry_steel: StandardMaterial3D
var mat_checkered: StandardMaterial3D
var mat_sign_post: StandardMaterial3D
var mat_sign_yellow: StandardMaterial3D
var mat_sign_green: StandardMaterial3D

func _ready() -> void:
	finish_line_z = -track_length
	_build_materials()
	_build_desert_terrain()
	_build_distant_mesas()
	_build_rock_formations()
	_build_cacti_and_vegetation()
	_build_curved_road_and_lanes()
	_build_curbs_and_guardrails()
	_build_road_signs()
	_build_start_gantry()
	_build_finish_gantry_and_trigger()

# --- 1. Route Geometry & Spline Mathematics ---
# Returns the horizontal X offset of the road center at a given negative Z coordinate.
# Z goes from 0.0 down to -750.0.
# Transitions are C1/C2 smooth cosine ease bends with zero slope at the boundaries.
func get_road_center_x(z: float) -> float:
	if z > -120.0:
		# Initial straight start / acceleration stretch
		return 0.0
	elif z > -280.0:
		# Gentle sweeping right bend drifting to +20.0m
		var u: float = (z - (-120.0)) / (-280.0 - (-120.0))
		return 20.0 * 0.5 * (1.0 - cos(PI * u))
	elif z > -460.0:
		# Sweeping S-curve from +20.0m through center to -20.0m
		var u: float = (z - (-280.0)) / (-460.0 - (-280.0))
		return 20.0 - 40.0 * 0.5 * (1.0 - cos(PI * u))
	elif z > -620.0:
		# Sweeping left bend returning smoothly from -20.0m to 0.0m
		var u: float = (z - (-460.0)) / (-620.0 - (-460.0))
		return -20.0 + 20.0 * 0.5 * (1.0 - cos(PI * u))
	else:
		# Final straight sprint to the finish line at Z = -750.0
		return 0.0

# Derivative dX/dz for tangent computation
func get_road_dx_dz(z: float) -> float:
	if z > -120.0:
		return 0.0
	elif z > -280.0:
		var u: float = (z - (-120.0)) / (-280.0 - (-120.0))
		var dz: float = -280.0 - (-120.0) # -160.0
		return (20.0 * 0.5 * PI * sin(PI * u)) / dz
	elif z > -460.0:
		var u: float = (z - (-280.0)) / (-460.0 - (-280.0))
		var dz: float = -460.0 - (-280.0) # -180.0
		return (-40.0 * 0.5 * PI * sin(PI * u)) / dz
	elif z > -620.0:
		var u: float = (z - (-460.0)) / (-620.0 - (-460.0))
		var dz: float = -620.0 - (-460.0) # -160.0
		return (20.0 * 0.5 * PI * sin(PI * u)) / dz
	else:
		return 0.0

# Returns center position of the road at distance along track
func get_road_center(distance: float) -> Vector3:
	var z: float = -clampf(distance, 0.0, track_length + 60.0)
	var x: float = get_road_center_x(z)
	return Vector3(x, 0.0, z)

# Returns unit forward tangent vector along the road at distance
func get_road_forward(distance: float) -> Vector3:
	var z: float = -clampf(distance, 0.0, track_length + 60.0)
	var dx_dz: float = get_road_dx_dz(z)
	# With increasing distance, dz/dd = -1, dx/dd = -dx_dz
	var tangent := Vector3(-dx_dz, 0.0, -1.0).normalized()
	return tangent

# Returns unit right normal vector perpendicular to road forward
func get_road_right(distance: float) -> Vector3:
	var f: Vector3 = get_road_forward(distance)
	return f.cross(Vector3.UP).normalized()

# Authoritative transform for any car at distance traveled and lane offset
func get_route_transform(distance: float, lane_offset: float) -> Transform3D:
	var center: Vector3 = get_road_center(distance)
	var f: Vector3 = get_road_forward(distance)
	var r: Vector3 = get_road_right(distance)
	var car_origin: Vector3 = center + (r * lane_offset)
	var heading: float = atan2(-f.x, -f.z)
	var basis: Basis = Basis(Vector3.UP, heading)
	return Transform3D(basis, car_origin)

# Helper for starting grid initialization
func get_car_start_position(lane_offset: float) -> Vector3:
	return get_route_transform(0.0, lane_offset).origin

# --- 2. Materials Setup ---
func _build_materials() -> void:
	# Warm Desert Sand
	mat_sand = StandardMaterial3D.new()
	mat_sand.albedo_color = Color(0.88, 0.64, 0.38)
	mat_sand.roughness = 0.95

	# Dune Sand
	mat_dune = StandardMaterial3D.new()
	mat_dune.albedo_color = Color(0.92, 0.70, 0.44)
	mat_dune.roughness = 0.92

	# Red Sandstone Mesa / Canyon Rock
	mat_red_rock = StandardMaterial3D.new()
	mat_red_rock.albedo_color = Color(0.74, 0.32, 0.18)
	mat_red_rock.roughness = 0.88

	# Sunbaked Mesa Capstone
	mat_mesa_top = StandardMaterial3D.new()
	mat_mesa_top.albedo_color = Color(0.60, 0.38, 0.24)
	mat_mesa_top.roughness = 0.9

	# Dark Highway Asphalt
	mat_asphalt = StandardMaterial3D.new()
	mat_asphalt.albedo_color = Color(0.14, 0.14, 0.16)
	mat_asphalt.roughness = 0.85
	mat_asphalt.metallic = 0.08

	# Highway Yellow Centerlines
	mat_yellow_line = StandardMaterial3D.new()
	mat_yellow_line.albedo_color = Color(0.98, 0.82, 0.12)
	mat_yellow_line.emission_enabled = true
	mat_yellow_line.emission = Color(0.98, 0.82, 0.12)
	mat_yellow_line.emission_energy_multiplier = 0.3

	# Crisp White Lane & Boundary Lines
	mat_white_line = StandardMaterial3D.new()
	mat_white_line.albedo_color = Color(0.95, 0.95, 0.96)
	mat_white_line.emission_enabled = true
	mat_white_line.emission = Color(0.95, 0.95, 0.96)
	mat_white_line.emission_energy_multiplier = 0.25

	# Alternating Yellow / Black Rumble Curbs
	mat_curb_yellow = StandardMaterial3D.new()
	mat_curb_yellow.albedo_color = Color(0.96, 0.82, 0.14)
	mat_curb_yellow.roughness = 0.7

	mat_curb_black = StandardMaterial3D.new()
	mat_curb_black.albedo_color = Color(0.12, 0.12, 0.14)
	mat_curb_black.roughness = 0.7

	# Armco Galvanized Steel Crash Barrier
	mat_guardrail = StandardMaterial3D.new()
	mat_guardrail.albedo_color = Color(0.78, 0.82, 0.86)
	mat_guardrail.metallic = 0.85
	mat_guardrail.roughness = 0.3

	mat_guardrail_post = StandardMaterial3D.new()
	mat_guardrail_post.albedo_color = Color(0.38, 0.28, 0.18)
	mat_guardrail_post.roughness = 0.9

	# Saguaro Cactus Green
	mat_cactus = StandardMaterial3D.new()
	mat_cactus.albedo_color = Color(0.22, 0.46, 0.20)
	mat_cactus.roughness = 0.82

	# Dry Desert Shrubs & Tumbleweed
	mat_shrub = StandardMaterial3D.new()
	mat_shrub.albedo_color = Color(0.56, 0.50, 0.28)
	mat_shrub.roughness = 0.95

	# Industrial Steel Truss Gantry
	mat_gantry_steel = StandardMaterial3D.new()
	mat_gantry_steel.albedo_color = Color(0.22, 0.24, 0.28)
	mat_gantry_steel.metallic = 0.8
	mat_gantry_steel.roughness = 0.3

	# Checkered Racing Flags / Banner
	mat_checkered = StandardMaterial3D.new()
	mat_checkered.albedo_color = Color(0.96, 0.96, 0.96)
	mat_checkered.roughness = 0.4

	# Highway Signs
	mat_sign_post = StandardMaterial3D.new()
	mat_sign_post.albedo_color = Color(0.4, 0.42, 0.45)
	mat_sign_post.metallic = 0.6

	mat_sign_yellow = StandardMaterial3D.new()
	mat_sign_yellow.albedo_color = Color(0.96, 0.82, 0.12)
	mat_sign_yellow.emission_enabled = true
	mat_sign_yellow.emission = Color(0.96, 0.82, 0.12)
	mat_sign_yellow.emission_energy_multiplier = 0.35

	mat_sign_green = StandardMaterial3D.new()
	mat_sign_green.albedo_color = Color(0.12, 0.52, 0.24)
	mat_sign_green.emission_enabled = true
	mat_sign_green.emission = Color(0.12, 0.52, 0.24)
	mat_sign_green.emission_energy_multiplier = 0.3

# --- 3. Desert Terrain & Rolling Dunes ---
func _build_desert_terrain() -> void:
	var terrain_group := Node3D.new()
	terrain_group.name = "DesertTerrainGroup"
	add_child(terrain_group)

	# Main Desert Floor (Large expansive plain)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(500.0, 0.4, track_length + 400.0)
	floor_mesh.material = mat_sand

	var floor_inst := MeshInstance3D.new()
	floor_inst.name = "DesertFloor"
	floor_inst.mesh = floor_mesh
	floor_inst.position = Vector3(0.0, -0.25, -(track_length / 2.0))
	terrain_group.add_child(floor_inst)

	# Static collision body for entire road & surroundings
	var static_body := StaticBody3D.new()
	static_body.name = "GroundStaticBody"
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300.0, 0.5, track_length + 300.0)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, -0.25, -(track_length / 2.0))
	static_body.add_child(col_shape)
	terrain_group.add_child(static_body)

	# Rolling Sand Dunes on left and right flanks
	var dune_mesh := CylinderMesh.new()
	dune_mesh.top_radius = 18.0
	dune_mesh.bottom_radius = 35.0
	dune_mesh.height = 6.5
	dune_mesh.radial_segments = 8
	dune_mesh.material = mat_dune

	var z_dune: float = 60.0
	while z_dune > -(track_length + 150.0):
		var center_x: float = get_road_center_x(z_dune)
		for side in [-1.0, 1.0]:
			var dune := MeshInstance3D.new()
			dune.mesh = dune_mesh
			var dist_x: float = side * (46.0 + sin(z_dune * 0.04) * 8.0)
			dune.position = Vector3(center_x + dist_x, 1.8, z_dune)
			dune.scale = Vector3(1.2 + sin(z_dune) * 0.2, 0.9, 1.8 + cos(z_dune) * 0.3)
			dune.rotation_degrees = Vector3(0.0, sin(z_dune * 0.08) * 35.0, side * 5.0)
			terrain_group.add_child(dune)
		z_dune -= 45.0

# --- 4. Distant Mesas & Canyon Horizons ---
func _build_distant_mesas() -> void:
	var mesa_group := Node3D.new()
	mesa_group.name = "DistantMesasGroup"
	add_child(mesa_group)

	# Prominent flat-topped red sandstone mesas
	var mesa_specs: Array[Dictionary] = [
		{"pos": Vector3(-160.0, 0.0, -(track_length + 180.0)), "rad": 70.0, "h": 55.0},
		{"pos": Vector3(-80.0, 0.0, -(track_length + 220.0)), "rad": 85.0, "h": 68.0},
		{"pos": Vector3(45.0, 0.0, -(track_length + 240.0)), "rad": 95.0, "h": 74.0},
		{"pos": Vector3(160.0, 0.0, -(track_length + 190.0)), "rad": 75.0, "h": 58.0},
		# Flanking canyon mesas
		{"pos": Vector3(-190.0, 0.0, -180.0), "rad": 65.0, "h": 46.0},
		{"pos": Vector3(185.0, 0.0, -220.0), "rad": 70.0, "h": 50.0},
		{"pos": Vector3(-200.0, 0.0, -420.0), "rad": 80.0, "h": 60.0},
		{"pos": Vector3(195.0, 0.0, -480.0), "rad": 85.0, "h": 64.0},
		{"pos": Vector3(-180.0, 0.0, 50.0), "rad": 60.0, "h": 42.0},
		{"pos": Vector3(175.0, 0.0, 30.0), "rad": 65.0, "h": 45.0}
	]

	for spec in mesa_specs:
		var p: Vector3 = spec["pos"]
		var r: float = spec["rad"]
		var h: float = spec["h"]

		var m_root := Node3D.new()
		m_root.position = p
		mesa_group.add_child(m_root)

		# Stepped tapered sandstone base
		var base_mesh := CylinderMesh.new()
		base_mesh.top_radius = r * 0.75
		base_mesh.bottom_radius = r
		base_mesh.height = h * 0.85
		base_mesh.radial_segments = 8
		base_mesh.material = mat_red_rock

		var b_inst := MeshInstance3D.new()
		b_inst.mesh = base_mesh
		b_inst.position = Vector3(0.0, (h * 0.85) / 2.0, 0.0)
		m_root.add_child(b_inst)

		# Flat capstone slab on top
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = r * 0.78
		cap_mesh.bottom_radius = r * 0.78
		cap_mesh.height = h * 0.15
		cap_mesh.radial_segments = 8
		cap_mesh.material = mat_mesa_top

		var c_inst := MeshInstance3D.new()
		c_inst.mesh = cap_mesh
		c_inst.position = Vector3(0.0, h * 0.85 + (h * 0.15) / 2.0, 0.0)
		m_root.add_child(c_inst)

# --- 5. Sandstone Rock Formations / Spires ---
func _build_rock_formations() -> void:
	var rock_group := Node3D.new()
	rock_group.name = "SandstoneRockFormations"
	add_child(rock_group)

	# Stylized natural spires & monoliths placed at safe distances along the road
	var rock_spires_z: Array[float] = [
		-80.0, -160.0, -240.0, -320.0, -400.0, -480.0, -560.0, -640.0
	]

	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 1.8
	spire_mesh.bottom_radius = 5.2
	spire_mesh.height = 14.0
	spire_mesh.radial_segments = 6
	spire_mesh.material = mat_red_rock

	var boulder_mesh := BoxMesh.new()
	boulder_mesh.size = Vector3(6.0, 4.5, 6.0)
	boulder_mesh.material = mat_red_rock

	for z_val in rock_spires_z:
		var center_x: float = get_road_center_x(z_val)
		for side in [-1.0, 1.0]:
			var r_root := Node3D.new()
			var offset_x: float = center_x + side * (26.0 + (int(abs(z_val)) % 15))
			r_root.position = Vector3(offset_x, 0.0, z_val + (side * 6.0))
			rock_group.add_child(r_root)

			# Tall sandstone spire
			var spire := MeshInstance3D.new()
			spire.mesh = spire_mesh
			spire.position = Vector3(0.0, 7.0, 0.0)
			spire.rotation_degrees = Vector3(sin(z_val) * 6.0, (int(z_val) % 45), cos(z_val) * 6.0)
			r_root.add_child(spire)

			# Base boulders
			var boulder := MeshInstance3D.new()
			boulder.mesh = boulder_mesh
			boulder.position = Vector3(side * 2.2, 2.0, 1.5)
			boulder.rotation_degrees = Vector3(12.0, (int(abs(z_val)) % 90), -8.0)
			r_root.add_child(boulder)

# --- 6. Cacti & Desert Vegetation ---
func _build_cacti_and_vegetation() -> void:
	var veg_group := Node3D.new()
	veg_group.name = "DesertVegetationGroup"
	add_child(veg_group)

	# Saguaro Cactus Procedural Meshes
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.38
	trunk_mesh.bottom_radius = 0.45
	trunk_mesh.height = 5.4
	trunk_mesh.radial_segments = 6
	trunk_mesh.material = mat_cactus

	var arm_v_mesh := CylinderMesh.new()
	arm_v_mesh.top_radius = 0.28
	arm_v_mesh.bottom_radius = 0.30
	arm_v_mesh.height = 2.4
	arm_v_mesh.radial_segments = 6
	arm_v_mesh.material = mat_cactus

	var arm_h_mesh := CylinderMesh.new()
	arm_h_mesh.top_radius = 0.28
	arm_h_mesh.bottom_radius = 0.28
	arm_h_mesh.height = 1.3
	arm_h_mesh.radial_segments = 6
	arm_h_mesh.material = mat_cactus

	# Dry Shrub Mesh
	var shrub_mesh := SphereMesh.new()
	shrub_mesh.radius = 0.8
	shrub_mesh.height = 1.3
	shrub_mesh.radial_segments = 5
	shrub_mesh.rings = 3
	shrub_mesh.material = mat_shrub

	var z_veg: float = 30.0
	while z_veg > -(track_length + 40.0):
		var center_x: float = get_road_center_x(z_veg)
		for side in [-1.0, 1.0]:
			var cluster_root := Node3D.new()
			var offset_x: float = center_x + side * (14.5 + (int(abs(z_veg)) % 12))
			cluster_root.position = Vector3(offset_x, 0.0, z_veg)
			veg_group.add_child(cluster_root)

			# Saguaro Cactus
			var c_root := Node3D.new()
			cluster_root.add_child(c_root)

			var trunk := MeshInstance3D.new()
			trunk.mesh = trunk_mesh
			trunk.position = Vector3(0.0, 2.7, 0.0)
			c_root.add_child(trunk)

			# Left arm
			var h_arm_l := MeshInstance3D.new()
			h_arm_l.mesh = arm_h_mesh
			h_arm_l.position = Vector3(-0.75, 2.8, 0.0)
			h_arm_l.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			c_root.add_child(h_arm_l)

			var v_arm_l := MeshInstance3D.new()
			v_arm_l.mesh = arm_v_mesh
			v_arm_l.position = Vector3(-1.3, 3.8, 0.0)
			c_root.add_child(v_arm_l)

			# Right arm (staggered height)
			var h_arm_r := MeshInstance3D.new()
			h_arm_r.mesh = arm_h_mesh
			h_arm_r.position = Vector3(0.75, 2.2, 0.0)
			h_arm_r.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			c_root.add_child(h_arm_r)

			var v_arm_r := MeshInstance3D.new()
			v_arm_r.mesh = arm_v_mesh
			v_arm_r.position = Vector3(1.3, 3.2, 0.0)
			c_root.add_child(v_arm_r)

			# Desert scrub nearby
			var shrub := MeshInstance3D.new()
			shrub.mesh = shrub_mesh
			shrub.position = Vector3(side * 2.5, 0.55, 1.8)
			cluster_root.add_child(shrub)

		z_veg -= 28.0

# --- 7. Curved Road Surface & Lane Markings ---
func _build_curved_road_and_lanes() -> void:
	var road_group := Node3D.new()
	road_group.name = "CurvedRoadGroup"
	add_child(road_group)

	# SurfaceTool for unified smooth road mesh ribbon
	var st_road := SurfaceTool.new()
	st_road.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_road.set_material(mat_asphalt)

	var st_white_l := SurfaceTool.new()
	st_white_l.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_white_l.set_material(mat_white_line)

	var st_white_r := SurfaceTool.new()
	st_white_r.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_white_r.set_material(mat_white_line)

	var st_yellow_c := SurfaceTool.new()
	st_yellow_c.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_yellow_c.set_material(mat_yellow_line)

	# Generate road quad strips along distance
	var step_size: float = 3.0
	var current_d: float = -40.0
	var max_d: float = track_length + 60.0

	while current_d < max_d:
		var d0: float = current_d
		var d1: float = current_d + step_size

		var c0: Vector3 = get_road_center(d0)
		var c1: Vector3 = get_road_center(d1)

		var r0: Vector3 = get_road_right(d0)
		var r1: Vector3 = get_road_right(d1)

		var half_w: float = road_width / 2.0

		# 1. Main Asphalt Surface
		var road_l0: Vector3 = c0 - r0 * half_w
		var road_r0: Vector3 = c0 + r0 * half_w
		var road_l1: Vector3 = c1 - r1 * half_w
		var road_r1: Vector3 = c1 + r1 * half_w

		_add_quad_to_st(st_road, road_l0, road_r0, road_r1, road_l1, Vector3.UP)

		# 2. Outer White Boundary Lines (Width = 0.28m, Y = 0.012)
		var bound_dist: float = 6.2
		var bound_w: float = 0.24
		_add_ribbon_segment(st_white_l, c0, c1, r0, r1, -bound_dist - bound_w / 2.0, -bound_dist + bound_w / 2.0, 0.012)
		_add_ribbon_segment(st_white_r, c0, c1, r0, r1, bound_dist - bound_w / 2.0, bound_dist + bound_w / 2.0, 0.012)

		# 3. Center Double Yellow Lines
		_add_ribbon_segment(st_yellow_c, c0, c1, r0, r1, -0.25, -0.07, 0.014)
		_add_ribbon_segment(st_yellow_c, c0, c1, r0, r1, 0.07, 0.25, 0.014)

		current_d += step_size

	var road_mesh: ArrayMesh = st_road.commit()
	var road_inst := MeshInstance3D.new()
	road_inst.name = "AsphaltHighway"
	road_inst.mesh = road_mesh
	road_group.add_child(road_inst)

	var wl_mesh: ArrayMesh = st_white_l.commit()
	var wl_inst := MeshInstance3D.new()
	wl_inst.name = "WhiteBorderLeft"
	wl_inst.mesh = wl_mesh
	road_group.add_child(wl_inst)

	var wr_mesh: ArrayMesh = st_white_r.commit()
	var wr_inst := MeshInstance3D.new()
	wr_inst.name = "WhiteBorderRight"
	wr_inst.mesh = wr_mesh
	road_group.add_child(wr_inst)

	var yel_mesh: ArrayMesh = st_yellow_c.commit()
	var yel_inst := MeshInstance3D.new()
	yel_inst.name = "CenterYellowDividers"
	yel_inst.mesh = yel_mesh
	road_group.add_child(yel_inst)

	# 4. Dashed White Lane Dividers:
	# Lane 1 (-4.5), Lane 2 (-1.5), Lane 3 (+1.5), Lane 4 (+4.5)
	# Dividing dashed lines at X_offset = -3.0m and +3.0m
	var st_dashes := SurfaceTool.new()
	st_dashes.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_dashes.set_material(mat_white_line)

	var dash_d: float = -30.0
	var dash_len: float = 4.0
	var dash_gap: float = 6.0
	while dash_d < track_length + 50.0:
		var d_start: float = dash_d
		var d_end: float = dash_d + dash_len

		var c0_d: Vector3 = get_road_center(d_start)
		var c1_d: Vector3 = get_road_center(d_end)
		var r0_d: Vector3 = get_road_right(d_start)
		var r1_d: Vector3 = get_road_right(d_end)

		for lane_div in [-3.0, 3.0]:
			_add_ribbon_segment(st_dashes, c0_d, c1_d, r0_d, r1_d, lane_div - 0.12, lane_div + 0.12, 0.013)

		dash_d += (dash_len + dash_gap)

	var dashes_mesh: ArrayMesh = st_dashes.commit()
	var dashes_inst := MeshInstance3D.new()
	dashes_inst.name = "LaneDashes"
	dashes_inst.mesh = dashes_mesh
	road_group.add_child(dashes_inst)

# Helper to build ribbon quads between two distance points
func _add_ribbon_segment(st: SurfaceTool, c0: Vector3, c1: Vector3, r0: Vector3, r1: Vector3, off_a: float, off_b: float, y_elev: float) -> void:
	var v0 := c0 + r0 * off_a + Vector3(0.0, y_elev, 0.0)
	var v1 := c0 + r0 * off_b + Vector3(0.0, y_elev, 0.0)
	var v2 := c1 + r1 * off_b + Vector3(0.0, y_elev, 0.0)
	var v3 := c1 + r1 * off_a + Vector3(0.0, y_elev, 0.0)
	_add_quad_to_st(st, v0, v1, v2, v3, Vector3.UP)

func _add_quad_to_st(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3) -> void:
	st.set_normal(normal)
	st.add_vertex(v0)
	st.set_normal(normal)
	st.add_vertex(v1)
	st.set_normal(normal)
	st.add_vertex(v2)

	st.set_normal(normal)
	st.add_vertex(v0)
	st.set_normal(normal)
	st.add_vertex(v2)
	st.set_normal(normal)
	st.add_vertex(v3)

# --- 8. Rumble Curbs & Armco Guardrails ---
func _build_curbs_and_guardrails() -> void:
	var curbs_group := Node3D.new()
	curbs_group.name = "CurbsAndGuardrails"
	add_child(curbs_group)

	# Rumble Curbs: Yellow / Black alternating blocks along road edge
	var curb_box := BoxMesh.new()
	curb_box.size = Vector3(0.55, 0.14, 2.0)

	var curb_d: float = -30.0
	var is_yellow: bool = false
	while curb_d < track_length + 50.0:
		is_yellow = not is_yellow
		var mat_use: StandardMaterial3D = mat_curb_yellow if is_yellow else mat_curb_black

		var center: Vector3 = get_road_center(curb_d)
		var right: Vector3 = get_road_right(curb_d)
		var forward: Vector3 = get_road_forward(curb_d)
		var heading: float = atan2(-forward.x, -forward.z)

		for side in [-1.0, 1.0]:
			var curb := MeshInstance3D.new()
			curb.mesh = curb_box
			curb.material_override = mat_use
			curb.position = center + right * (side * 7.25) + Vector3(0.0, 0.06, 0.0)
			curb.rotation = Vector3(0.0, heading, 0.0)
			curbs_group.add_child(curb)

		curb_d += 2.2

	# Armco Guardrails & Timber Posts on Outer Curves
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.12, 0.45, 5.2)
	rail_mesh.material = mat_guardrail

	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.18, 0.85, 0.18)
	post_mesh.material = mat_guardrail_post

	var rail_d: float = -20.0
	while rail_d < track_length + 40.0:
		var center: Vector3 = get_road_center(rail_d)
		var right: Vector3 = get_road_right(rail_d)
		var forward: Vector3 = get_road_forward(rail_d)
		var heading: float = atan2(-forward.x, -forward.z)

		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			rail.mesh = rail_mesh
			rail.position = center + right * (side * 8.2) + Vector3(0.0, 0.55, 0.0)
			rail.rotation = Vector3(0.0, heading, 0.0)
			curbs_group.add_child(rail)

			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.position = center + right * (side * 8.2) + Vector3(0.0, 0.42, 0.0)
			curbs_group.add_child(post)

		rail_d += 5.0

# --- 9. Desert Road Signs & Distance Markers ---
func _build_road_signs() -> void:
	var signs_group := Node3D.new()
	signs_group.name = "DesertRoadSigns"
	add_child(signs_group)

	# Distance boards at remaining distances along the 750m course
	var marker_distances: Array[float] = [150.0, 300.0, 450.0, 600.0, 700.0]
	var marker_labels: Array[String] = ["600M", "450M", "300M", "150M", "50M"]

	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(0.2, 1.4, 2.2)
	board_mesh.material = mat_sign_yellow

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.08
	post_mesh.bottom_radius = 0.08
	post_mesh.height = 2.4
	post_mesh.material = mat_sign_post

	for i in range(marker_distances.size()):
		var d: float = marker_distances[i]
		var center: Vector3 = get_road_center(d)
		var right: Vector3 = get_road_right(d)
		var forward: Vector3 = get_road_forward(d)
		var heading: float = atan2(-forward.x, -forward.z)

		for side in [-1.0, 1.0]:
			var sign_root := Node3D.new()
			sign_root.position = center + right * (side * 9.2)
			sign_root.rotation = Vector3(0.0, heading, 0.0)

			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.position = Vector3(0.0, 1.2, 0.0)
			sign_root.add_child(post)

			var board := MeshInstance3D.new()
			board.mesh = board_mesh
			board.position = Vector3(0.0, 2.1, 0.0)
			sign_root.add_child(board)

			signs_group.add_child(sign_root)

	# Curve Warning Chevron Signs before the major bends
	var curve_sign_distances: Array[float] = [100.0, 260.0, 440.0]
	for d_curve in curve_sign_distances:
		var center: Vector3 = get_road_center(d_curve)
		var right: Vector3 = get_road_right(d_curve)
		var forward: Vector3 = get_road_forward(d_curve)
		var heading: float = atan2(-forward.x, -forward.z)

		var c_sign := Node3D.new()
		c_sign.position = center + right * 9.4
		c_sign.rotation = Vector3(0.0, heading, 0.0)

		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.position = Vector3(0.0, 1.2, 0.0)
		c_sign.add_child(post)

		var board := MeshInstance3D.new()
		board.mesh = board_mesh
		board.position = Vector3(0.0, 2.1, 0.0)
		board.material_override = mat_sign_yellow
		c_sign.add_child(board)

		signs_group.add_child(c_sign)

# --- 10. Checkered Start Gantry ---
func _build_start_gantry() -> void:
	var start_group := Node3D.new()
	start_group.name = "StartGantryGroup"
	start_group.position = Vector3(0.0, 0.0, 0.0)
	add_child(start_group)

	# Left & Right Steel Pillars
	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.9, 7.5, 0.9)
	pillar_mesh.material = mat_gantry_steel

	var pl := MeshInstance3D.new()
	pl.mesh = pillar_mesh
	pl.position = Vector3(-(road_width / 2.0 + 1.4), 3.75, 0.0)
	start_group.add_child(pl)

	var pr := MeshInstance3D.new()
	pr.mesh = pillar_mesh
	pr.position = Vector3(road_width / 2.0 + 1.4, 3.75, 0.0)
	start_group.add_child(pr)

	# Crossbar Truss
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(road_width + 3.8, 1.4, 1.0)
	bar_mesh.material = mat_gantry_steel

	var bar := MeshInstance3D.new()
	bar.mesh = bar_mesh
	bar.position = Vector3(0.0, 7.0, 0.0)
	start_group.add_child(bar)

	# Checkered Start Banner
	var banner_mat := StandardMaterial3D.new()
	banner_mat.albedo_color = Color(0.96, 0.48, 0.1) # Racing Orange Accent
	banner_mat.emission_enabled = true
	banner_mat.emission = Color(0.96, 0.48, 0.1)
	banner_mat.emission_energy_multiplier = 0.5

	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(12.0, 1.2, 1.05)
	banner_mesh.material = banner_mat

	var banner := MeshInstance3D.new()
	banner.mesh = banner_mesh
	banner.position = Vector3(0.0, 7.0, 0.0)
	start_group.add_child(banner)

	# Start Grid Line on Asphalt
	var start_line_mesh := BoxMesh.new()
	start_line_mesh.size = Vector3(road_width, 0.02, 1.2)
	start_line_mesh.material = mat_white_line

	var s_line := MeshInstance3D.new()
	s_line.mesh = start_line_mesh
	s_line.position = Vector3(0.0, 0.015, 0.0)
	start_group.add_child(s_line)

# --- 11. Checkered Finish Gantry & Trigger Area ---
func _build_finish_gantry_and_trigger() -> void:
	var finish_group := Node3D.new()
	finish_group.name = "FinishGantryGroup"
	finish_group.position = Vector3(0.0, 0.0, -track_length)
	add_child(finish_group)

	# Steel Side Towers
	var tower_mesh := BoxMesh.new()
	tower_mesh.size = Vector3(1.2, 8.5, 1.2)
	tower_mesh.material = mat_gantry_steel

	var tl := MeshInstance3D.new()
	tl.mesh = tower_mesh
	tl.position = Vector3(-(road_width / 2.0 + 1.6), 4.25, 0.0)
	finish_group.add_child(tl)

	var tr := MeshInstance3D.new()
	tr.mesh = tower_mesh
	tr.position = Vector3(road_width / 2.0 + 1.6, 4.25, 0.0)
	finish_group.add_child(tr)

	# Heavy Overhead Arch
	var fbar_mesh := BoxMesh.new()
	fbar_mesh.size = Vector3(road_width + 4.2, 1.8, 1.2)
	fbar_mesh.material = mat_gantry_steel

	var fbar := MeshInstance3D.new()
	fbar.mesh = fbar_mesh
	fbar.position = Vector3(0.0, 7.8, 0.0)
	finish_group.add_child(fbar)

	# Illuminated Finish Line Banner
	var f_banner_mat := StandardMaterial3D.new()
	f_banner_mat.albedo_color = Color(0.96, 0.15, 0.15) # Checkered Red
	f_banner_mat.emission_enabled = true
	f_banner_mat.emission = Color(0.96, 0.15, 0.15)
	f_banner_mat.emission_energy_multiplier = 0.8

	var f_banner_mesh := BoxMesh.new()
	f_banner_mesh.size = Vector3(13.0, 1.4, 1.25)
	f_banner_mesh.material = f_banner_mat

	var f_banner := MeshInstance3D.new()
	f_banner.mesh = f_banner_mesh
	f_banner.position = Vector3(0.0, 7.8, 0.0)
	finish_group.add_child(f_banner)

	# Checkered Finish Strip on Ground
	var f_strip_mesh := BoxMesh.new()
	f_strip_mesh.size = Vector3(road_width, 0.02, 2.5)
	f_strip_mesh.material = mat_white_line

	var f_strip := MeshInstance3D.new()
	f_strip.mesh = f_strip_mesh
	f_strip.position = Vector3(0.0, 0.016, 0.0)
	finish_group.add_child(f_strip)

	# Race Timing Tower on right side
	var tower_base_mesh := BoxMesh.new()
	tower_base_mesh.size = Vector3(5.5, 11.0, 5.5)
	tower_base_mesh.material = mat_red_rock

	var timing_tower := MeshInstance3D.new()
	timing_tower.mesh = tower_base_mesh
	timing_tower.position = Vector3(14.0, 5.5, 0.0)
	finish_group.add_child(timing_tower)

	# Finish Line Area3D Detection
	var area := Area3D.new()
	area.name = "FinishLineArea"
	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(road_width + 6.0, 7.0, 6.0)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 3.5, 0.0)
	area.add_child(col_shape)
	finish_group.add_child(area)

	area.body_entered.connect(_on_finish_area_body_entered)

# --- 12. Finish Line Collision & Trigger Logic ---
func _on_finish_area_body_entered(body: Node3D) -> void:
	if body in finished_cars:
		return

	# Prevent trigger when starting or halfway through
	if "distance_traveled" in body:
		var d_val: float = float(body.get("distance_traveled"))
		if d_val < (track_length * 0.85):
			return

	if body.has_method("finish_race") or body.name.to_lower().contains("car"):
		finished_cars.append(body)
		car_crossed_finish_line.emit(body)
		if body is PlayerCar or body.name == "Car":
			player_crossed_finish_line.emit()

func reset_finish() -> void:
	finished_cars.clear()

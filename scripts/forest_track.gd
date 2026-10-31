extends Node3D
class_name ForestRacingTrack

# Forest Run — 3D Alpine Forest Racing Circuit
# Milestone 7, Task 3: Stylized arcade forest highway featuring smooth scenic curves,
# towering alpine pines, lush deciduous oaks, mossy boulders, fallen timber logs,
# rustic wooden guardrails, distance signs, and a grand timber finish gantry.

signal car_crossed_finish_line(car_node: Node3D)
signal player_crossed_finish_line

@export var track_length: float = 1000.0 # From Z = 0.0 to Z = -1000.0
@export var road_width: float = 14.0

var finish_line_z: float = -1000.0
var finished_cars: Array[Node3D] = []

# Cached Materials
var mat_forest_floor: StandardMaterial3D
var mat_moss: StandardMaterial3D
var mat_dirt_path: StandardMaterial3D
var mat_asphalt: StandardMaterial3D
var mat_white_line: StandardMaterial3D
var mat_center_line: StandardMaterial3D
var mat_curb_white: StandardMaterial3D
var mat_curb_green: StandardMaterial3D
var mat_timber_rail: StandardMaterial3D
var mat_timber_post: StandardMaterial3D
var mat_bark_dark: StandardMaterial3D
var mat_bark_birch: StandardMaterial3D
var mat_needles_dark: StandardMaterial3D
var mat_needles_light: StandardMaterial3D
var mat_leaves_oak: StandardMaterial3D
var mat_shrub: StandardMaterial3D
var mat_boulder: StandardMaterial3D
var mat_wood_sign: StandardMaterial3D
var mat_sign_gold: StandardMaterial3D
var mat_gantry_timber: StandardMaterial3D
var mat_finish_banner: StandardMaterial3D

func _ready() -> void:
	finish_line_z = -track_length
	_build_materials()
	_build_forest_terrain()
	_build_distant_mountains()
	_build_curved_road_and_lanes()
	_build_curbs_and_guardrails()
	_build_vegetation_trees()
	_build_natural_props()
	_build_overhead_timber_bridges()
	_build_forest_signs()
	_build_start_gantry()
	_build_finish_gantry_and_trigger()

# --- 1. Route Geometry & Spline Mathematics ---
# Returns the horizontal X offset of the road center at a given negative Z coordinate.
# Z goes from 0.0 down to -1000.0.
# Transitions use C1 smooth cosine ease bends with zero slope at the boundaries.
func get_road_center_x(z: float) -> float:
	if z > -120.0:
		# Initial straight start through pine clearing
		return 0.0
	elif z > -320.0:
		# Sweeping left curve winding into deep woods (0.0 to -24.0m)
		var u: float = (z - (-120.0)) / (-320.0 - (-120.0))
		return -24.0 * 0.5 * (1.0 - cos(PI * u))
	elif z > -540.0:
		# Sweeping S-curve across valley (-24.0m to +22.0m)
		var u: float = (z - (-320.0)) / (-540.0 - (-320.0))
		return -24.0 + 46.0 * 0.5 * (1.0 - cos(PI * u))
	elif z > -740.0:
		# Gentle winding curve through oak ridge (+22.0m to -14.0m)
		var u: float = (z - (-540.0)) / (-740.0 - (-540.0))
		return 22.0 - 36.0 * 0.5 * (1.0 - cos(PI * u))
	elif z > -880.0:
		# Recovery bend straightening back to center (-14.0m to 0.0m)
		var u: float = (z - (-740.0)) / (-880.0 - (-740.0))
		return -14.0 + 14.0 * 0.5 * (1.0 - cos(PI * u))
	else:
		# Long final straight sprint under forest canopy to finish line (Z = -1000.0)
		return 0.0

# Derivative dX/dz for tangent computation
func get_road_dx_dz(z: float) -> float:
	if z > -120.0:
		return 0.0
	elif z > -320.0:
		var u: float = (z - (-120.0)) / (-320.0 - (-120.0))
		var dz: float = -320.0 - (-120.0) # -200.0
		return (-24.0 * 0.5 * PI * sin(PI * u)) / dz
	elif z > -540.0:
		var u: float = (z - (-320.0)) / (-540.0 - (-320.0))
		var dz: float = -540.0 - (-320.0) # -220.0
		return (46.0 * 0.5 * PI * sin(PI * u)) / dz
	elif z > -740.0:
		var u: float = (z - (-540.0)) / (-740.0 - (-540.0))
		var dz: float = -740.0 - (-540.0) # -200.0
		return (-36.0 * 0.5 * PI * sin(PI * u)) / dz
	elif z > -880.0:
		var u: float = (z - (-740.0)) / (-880.0 - (-740.0))
		var dz: float = -880.0 - (-740.0) # -140.0
		return (14.0 * 0.5 * PI * sin(PI * u)) / dz
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
	# Deep Mossy Forest Floor
	mat_forest_floor = StandardMaterial3D.new()
	mat_forest_floor.albedo_color = Color(0.18, 0.36, 0.16)
	mat_forest_floor.roughness = 0.95

	# Vibrant Forest Moss
	mat_moss = StandardMaterial3D.new()
	mat_moss.albedo_color = Color(0.24, 0.48, 0.18)
	mat_moss.roughness = 0.9

	# Forest Dirt / Pine Needle Embankment
	mat_dirt_path = StandardMaterial3D.new()
	mat_dirt_path.albedo_color = Color(0.32, 0.22, 0.14)
	mat_dirt_path.roughness = 0.92

	# Dark Alpine Asphalt
	mat_asphalt = StandardMaterial3D.new()
	mat_asphalt.albedo_color = Color(0.13, 0.14, 0.16)
	mat_asphalt.roughness = 0.85
	mat_asphalt.metallic = 0.08

	# Bright White Road Lines
	mat_white_line = StandardMaterial3D.new()
	mat_white_line.albedo_color = Color(0.95, 0.96, 0.96)
	mat_white_line.emission_enabled = true
	mat_white_line.emission = Color(0.95, 0.96, 0.96)
	mat_white_line.emission_energy_multiplier = 0.25

	# Crisp Centerline
	mat_center_line = StandardMaterial3D.new()
	mat_center_line.albedo_color = Color(0.96, 0.88, 0.2)
	mat_center_line.emission_enabled = true
	mat_center_line.emission = Color(0.96, 0.88, 0.2)
	mat_center_line.emission_energy_multiplier = 0.3

	# Alternating Forest Curbs: Forest Green & Pure White
	mat_curb_green = StandardMaterial3D.new()
	mat_curb_green.albedo_color = Color(0.12, 0.45, 0.22)
	mat_curb_green.roughness = 0.65

	mat_curb_white = StandardMaterial3D.new()
	mat_curb_white.albedo_color = Color(0.94, 0.95, 0.96)
	mat_curb_white.roughness = 0.65

	# Heavy Rustic Timber Guardrails
	mat_timber_rail = StandardMaterial3D.new()
	mat_timber_rail.albedo_color = Color(0.42, 0.28, 0.18)
	mat_timber_rail.roughness = 0.8

	mat_timber_post = StandardMaterial3D.new()
	mat_timber_post.albedo_color = Color(0.30, 0.20, 0.12)
	mat_timber_post.roughness = 0.88

	# Tree Barks
	mat_bark_dark = StandardMaterial3D.new()
	mat_bark_dark.albedo_color = Color(0.28, 0.19, 0.13)
	mat_bark_dark.roughness = 0.92

	mat_bark_birch = StandardMaterial3D.new()
	mat_bark_birch.albedo_color = Color(0.72, 0.70, 0.65)
	mat_bark_birch.roughness = 0.85

	# Pine Needles (Evergreen)
	mat_needles_dark = StandardMaterial3D.new()
	mat_needles_dark.albedo_color = Color(0.11, 0.32, 0.16)
	mat_needles_dark.roughness = 0.85

	mat_needles_light = StandardMaterial3D.new()
	mat_needles_light.albedo_color = Color(0.16, 0.42, 0.22)
	mat_needles_light.roughness = 0.85

	# Deciduous Oak Leaves
	mat_leaves_oak = StandardMaterial3D.new()
	mat_leaves_oak.albedo_color = Color(0.25, 0.52, 0.20)
	mat_leaves_oak.roughness = 0.82

	# Undergrowth Shrubs
	mat_shrub = StandardMaterial3D.new()
	mat_shrub.albedo_color = Color(0.20, 0.48, 0.22)
	mat_shrub.roughness = 0.9

	# Mossy Forest Boulders
	mat_boulder = StandardMaterial3D.new()
	mat_boulder.albedo_color = Color(0.36, 0.38, 0.35)
	mat_boulder.roughness = 0.92

	# Wooden Signs & Posts
	mat_wood_sign = StandardMaterial3D.new()
	mat_wood_sign.albedo_color = Color(0.48, 0.34, 0.22)
	mat_wood_sign.roughness = 0.85

	mat_sign_gold = StandardMaterial3D.new()
	mat_sign_gold.albedo_color = Color(0.96, 0.82, 0.18)
	mat_sign_gold.emission_enabled = true
	mat_sign_gold.emission = Color(0.96, 0.82, 0.18)
	mat_sign_gold.emission_energy_multiplier = 0.4

	# Gantry Timber
	mat_gantry_timber = StandardMaterial3D.new()
	mat_gantry_timber.albedo_color = Color(0.36, 0.24, 0.15)
	mat_gantry_timber.roughness = 0.8

	# Checkered Finish Banner
	mat_finish_banner = StandardMaterial3D.new()
	mat_finish_banner.albedo_color = Color(0.14, 0.65, 0.28) # Emerald racing green
	mat_finish_banner.emission_enabled = true
	mat_finish_banner.emission = Color(0.14, 0.65, 0.28)
	mat_finish_banner.emission_energy_multiplier = 0.8

# --- 3. Forest Terrain & Valley Berms ---
func _build_forest_terrain() -> void:
	var terrain_group := Node3D.new()
	terrain_group.name = "ForestTerrainGroup"
	add_child(terrain_group)

	# Main Forest Ground Plane (Wide valley floor)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(550.0, 0.4, track_length + 400.0)
	floor_mesh.material = mat_forest_floor

	var floor_inst := MeshInstance3D.new()
	floor_inst.name = "ForestFloor"
	floor_inst.mesh = floor_mesh
	floor_inst.position = Vector3(0.0, -0.25, -(track_length / 2.0))
	terrain_group.add_child(floor_inst)

	# Static collision body for road and surrounding terrain
	var static_body := StaticBody3D.new()
	static_body.name = "ForestGroundStaticBody"
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(360.0, 0.5, track_length + 300.0)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, -0.25, -(track_length / 2.0))
	static_body.add_child(col_shape)
	terrain_group.add_child(static_body)

	# Rolling Hills and Grassy Ridges flanking the track
	var hill_mesh := CylinderMesh.new()
	hill_mesh.top_radius = 16.0
	hill_mesh.bottom_radius = 32.0
	hill_mesh.height = 7.0
	hill_mesh.radial_segments = 8
	hill_mesh.material = mat_moss

	var z_hill: float = 60.0
	while z_hill > -(track_length + 150.0):
		var center_x: float = get_road_center_x(z_hill)
		for side in [-1.0, 1.0]:
			var hill := MeshInstance3D.new()
			hill.mesh = hill_mesh
			var dist_x: float = side * (44.0 + sin(z_hill * 0.03) * 8.0)
			hill.position = Vector3(center_x + dist_x, 2.0, z_hill)
			hill.scale = Vector3(1.3 + sin(z_hill * 0.05) * 0.2, 0.95, 1.6 + cos(z_hill * 0.05) * 0.3)
			hill.rotation_degrees = Vector3(0.0, sin(z_hill * 0.06) * 30.0, side * 6.0)
			terrain_group.add_child(hill)
		z_hill -= 50.0

# --- 4. Distant Alpine Mountain Peaks ---
func _build_distant_mountains() -> void:
	var mountain_group := Node3D.new()
	mountain_group.name = "AlpineMountainsGroup"
	add_child(mountain_group)

	var mountain_mat := StandardMaterial3D.new()
	mountain_mat.albedo_color = Color(0.26, 0.34, 0.30)
	mountain_mat.roughness = 0.95

	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.92, 0.95, 0.98)
	snow_mat.roughness = 0.85

	# Majestic alpine background peaks along the horizon
	var peaks: Array[Dictionary] = [
		{"pos": Vector3(-200.0, 0.0, -(track_length + 260.0)), "rad": 85.0, "h": 75.0},
		{"pos": Vector3(-100.0, 0.0, -(track_length + 300.0)), "rad": 100.0, "h": 92.0},
		{"pos": Vector3(30.0, 0.0, -(track_length + 320.0)), "rad": 115.0, "h": 105.0},
		{"pos": Vector3(160.0, 0.0, -(track_length + 280.0)), "rad": 95.0, "h": 82.0},
		{"pos": Vector3(-240.0, 0.0, -450.0), "rad": 90.0, "h": 68.0},
		{"pos": Vector3(230.0, 0.0, -520.0), "rad": 95.0, "h": 72.0},
		{"pos": Vector3(-220.0, 0.0, 60.0), "rad": 80.0, "h": 58.0},
		{"pos": Vector3(210.0, 0.0, 40.0), "rad": 85.0, "h": 62.0}
	]

	for spec in peaks:
		var p: Vector3 = spec["pos"]
		var r: float = spec["rad"]
		var h: float = spec["h"]

		var m_root := Node3D.new()
		m_root.position = p
		mountain_group.add_child(m_root)

		# Mountain cone base
		var cone_mesh := CylinderMesh.new()
		cone_mesh.top_radius = 0.0
		cone_mesh.bottom_radius = r
		cone_mesh.height = h
		cone_mesh.radial_segments = 7
		cone_mesh.material = mountain_mat

		var m_inst := MeshInstance3D.new()
		m_inst.mesh = cone_mesh
		m_inst.position = Vector3(0.0, h / 2.0, 0.0)
		m_root.add_child(m_inst)

		# Snowcap top
		var snow_cone := CylinderMesh.new()
		snow_cone.top_radius = 0.0
		snow_cone.bottom_radius = r * 0.32
		snow_cone.height = h * 0.32
		snow_cone.radial_segments = 7
		snow_cone.material = snow_mat

		var s_inst := MeshInstance3D.new()
		s_inst.mesh = snow_cone
		s_inst.position = Vector3(0.0, h - (h * 0.16), 0.0)
		m_root.add_child(s_inst)

# --- 5. Curved Road Surface & Lane Markings ---
func _build_curved_road_and_lanes() -> void:
	var road_group := Node3D.new()
	road_group.name = "CurvedForestRoadGroup"
	add_child(road_group)

	# SurfaceTool for continuous smooth road ribbons
	var st_road := SurfaceTool.new()
	st_road.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_road.set_material(mat_asphalt)

	var st_white_l := SurfaceTool.new()
	st_white_l.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_white_l.set_material(mat_white_line)

	var st_white_r := SurfaceTool.new()
	st_white_r.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_white_r.set_material(mat_white_line)

	var st_center := SurfaceTool.new()
	st_center.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_center.set_material(mat_center_line)

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

		# 2. Outer White Boundary Lines (Width = 0.24m)
		var bound_dist: float = 6.2
		var bound_w: float = 0.24
		_add_ribbon_segment(st_white_l, c0, c1, r0, r1, -bound_dist - bound_w / 2.0, -bound_dist + bound_w / 2.0, 0.012)
		_add_ribbon_segment(st_white_r, c0, c1, r0, r1, bound_dist - bound_w / 2.0, bound_dist + bound_w / 2.0, 0.012)

		# 3. Center Solid Line (Gold/Yellow)
		_add_ribbon_segment(st_center, c0, c1, r0, r1, -0.15, 0.15, 0.014)

		current_d += step_size

	var road_mesh: ArrayMesh = st_road.commit()
	var road_inst := MeshInstance3D.new()
	road_inst.name = "AsphaltForestRoad"
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

	var cent_mesh: ArrayMesh = st_center.commit()
	var cent_inst := MeshInstance3D.new()
	cent_inst.name = "CenterRoadLine"
	cent_inst.mesh = cent_mesh
	road_group.add_child(cent_inst)

	# 4. Dashed White Lane Dividers:
	# Lane 1 (-4.5), Lane 2 (-1.5), Lane 3 (+1.5), Lane 4 (+4.5)
	# Dividing dashes at -3.0m and +3.0m
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

# Ribbon segment helper
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

# --- 6. Curbs and Rustic Timber Guardrails ---
func _build_curbs_and_guardrails() -> void:
	var curbs_group := Node3D.new()
	curbs_group.name = "ForestCurbsAndGuardrails"
	add_child(curbs_group)

	# Alternating Green & White Rumble Curbs
	var curb_box := BoxMesh.new()
	curb_box.size = Vector3(0.55, 0.14, 2.0)

	var curb_d: float = -30.0
	var is_green: bool = false
	while curb_d < track_length + 50.0:
		is_green = not is_green
		var mat_use: StandardMaterial3D = mat_curb_green if is_green else mat_curb_white

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

	# Heavy Rustic Timber Guardrails along outer road margins
	var timber_rail_mesh := BoxMesh.new()
	timber_rail_mesh.size = Vector3(0.18, 0.40, 5.2)
	timber_rail_mesh.material = mat_timber_rail

	var timber_post_mesh := CylinderMesh.new()
	timber_post_mesh.top_radius = 0.14
	timber_post_mesh.bottom_radius = 0.16
	timber_post_mesh.height = 0.95
	timber_post_mesh.material = mat_timber_post

	var rail_d: float = -20.0
	while rail_d < track_length + 40.0:
		var center: Vector3 = get_road_center(rail_d)
		var right: Vector3 = get_road_right(rail_d)
		var forward: Vector3 = get_road_forward(rail_d)
		var heading: float = atan2(-forward.x, -forward.z)

		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			rail.mesh = timber_rail_mesh
			rail.position = center + right * (side * 8.3) + Vector3(0.0, 0.58, 0.0)
			rail.rotation = Vector3(0.0, heading, 0.0)
			curbs_group.add_child(rail)

			var post := MeshInstance3D.new()
			post.mesh = timber_post_mesh
			post.position = center + right * (side * 8.3) + Vector3(0.0, 0.45, 0.0)
			curbs_group.add_child(post)

		rail_d += 5.0

# --- 7. Dense Forest Vegetation (Pines & Oaks) ---
func _build_vegetation_trees() -> void:
	var veg_group := Node3D.new()
	veg_group.name = "ForestVegetationGroup"
	add_child(veg_group)

	# Shared meshes for Alpine Conifer Pines
	var pine_trunk_mesh := CylinderMesh.new()
	pine_trunk_mesh.top_radius = 0.35
	pine_trunk_mesh.bottom_radius = 0.55
	pine_trunk_mesh.height = 7.0
	pine_trunk_mesh.radial_segments = 6
	pine_trunk_mesh.material = mat_bark_dark

	# 3 Conical foliage tiers
	var tier1_mesh := CylinderMesh.new()
	tier1_mesh.top_radius = 0.0
	tier1_mesh.bottom_radius = 3.6
	tier1_mesh.height = 4.2
	tier1_mesh.radial_segments = 7
	tier1_mesh.material = mat_needles_dark

	var tier2_mesh := CylinderMesh.new()
	tier2_mesh.top_radius = 0.0
	tier2_mesh.bottom_radius = 2.8
	tier2_mesh.height = 3.8
	tier2_mesh.radial_segments = 7
	tier2_mesh.material = mat_needles_light

	var tier3_mesh := CylinderMesh.new()
	tier3_mesh.top_radius = 0.0
	tier3_mesh.bottom_radius = 1.9
	tier3_mesh.height = 3.2
	tier3_mesh.radial_segments = 7
	tier3_mesh.material = mat_needles_dark

	# Shared meshes for Deciduous Oaks
	var oak_trunk_mesh := CylinderMesh.new()
	oak_trunk_mesh.top_radius = 0.45
	oak_trunk_mesh.bottom_radius = 0.65
	oak_trunk_mesh.height = 6.0
	oak_trunk_mesh.radial_segments = 6
	oak_trunk_mesh.material = mat_bark_birch

	var oak_canopy_mesh := SphereMesh.new()
	oak_canopy_mesh.radius = 3.2
	oak_canopy_mesh.height = 5.2
	oak_canopy_mesh.radial_segments = 7
	oak_canopy_mesh.rings = 5
	oak_canopy_mesh.material = mat_leaves_oak

	var z_tree: float = 30.0
	var tree_idx: int = 0
	while z_tree > -(track_length + 60.0):
		tree_idx += 1
		var center: Vector3 = get_road_center(absf(z_tree))
		var right: Vector3 = get_road_right(absf(z_tree))

		for side in [-1.0, 1.0]:
			# Inner tree line (at 12.0m to 18.0m from center)
			var offset_x1: float = side * (12.5 + (int(absf(z_tree)) % 6) * 1.0)
			var p1 := center + right * offset_x1

			if tree_idx % 3 != 0:
				# Alpine Pine
				_create_pine_tree(veg_group, p1, pine_trunk_mesh, tier1_mesh, tier2_mesh, tier3_mesh, 1.0 + sin(z_tree) * 0.15)
			else:
				# Deciduous Oak
				_create_oak_tree(veg_group, p1, oak_trunk_mesh, oak_canopy_mesh, 1.0 + cos(z_tree) * 0.15)

			# Outer dense tree line (at 22.0m to 32.0m from center for forest depth)
			var offset_x2: float = side * (24.0 + (int(absf(z_tree * 2.0)) % 10) * 1.0)
			var p2 := center + right * offset_x2 + Vector3(0.0, 0.5, 5.0 * side)
			_create_pine_tree(veg_group, p2, pine_trunk_mesh, tier1_mesh, tier2_mesh, tier3_mesh, 1.2 + sin(z_tree * 0.5) * 0.25)

		z_tree -= 20.0

func _create_pine_tree(parent: Node3D, pos: Vector3, trunk_m: Mesh, t1_m: Mesh, t2_m: Mesh, t3_m: Mesh, scale_f: float) -> void:
	var root_t := Node3D.new()
	root_t.position = pos
	root_t.scale = Vector3(scale_f, scale_f, scale_f)
	parent.add_child(root_t)

	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_m
	trunk.position = Vector3(0.0, 3.5, 0.0)
	root_t.add_child(trunk)

	var t1 := MeshInstance3D.new()
	t1.mesh = t1_m
	t1.position = Vector3(0.0, 4.5, 0.0)
	root_t.add_child(t1)

	var t2 := MeshInstance3D.new()
	t2.mesh = t2_m
	t2.position = Vector3(0.0, 6.5, 0.0)
	root_t.add_child(t2)

	var t3 := MeshInstance3D.new()
	t3.mesh = t3_m
	t3.position = Vector3(0.0, 8.2, 0.0)
	root_t.add_child(t3)

func _create_oak_tree(parent: Node3D, pos: Vector3, trunk_m: Mesh, canopy_m: Mesh, scale_f: float) -> void:
	var root_t := Node3D.new()
	root_t.position = pos
	root_t.scale = Vector3(scale_f, scale_f, scale_f)
	parent.add_child(root_t)

	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_m
	trunk.position = Vector3(0.0, 3.0, 0.0)
	root_t.add_child(trunk)

	var canopy := MeshInstance3D.new()
	canopy.mesh = canopy_m
	canopy.position = Vector3(0.0, 5.8, 0.0)
	root_t.add_child(canopy)

# --- 8. Natural Scenery: Logs, Tree Stumps, Boulders & Shrubs ---
func _build_natural_props() -> void:
	var props_group := Node3D.new()
	props_group.name = "NaturalForestProps"
	add_child(props_group)

	# Fallen Timber Logs
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.38
	log_mesh.bottom_radius = 0.42
	log_mesh.height = 4.8
	log_mesh.radial_segments = 6
	log_mesh.material = mat_bark_dark

	# Tree Stumps
	var stump_mesh := CylinderMesh.new()
	stump_mesh.top_radius = 0.55
	stump_mesh.bottom_radius = 0.65
	stump_mesh.height = 0.9
	stump_mesh.radial_segments = 6
	stump_mesh.material = mat_bark_dark

	# Forest Boulders
	var boulder_mesh := SphereMesh.new()
	boulder_mesh.radius = 1.4
	boulder_mesh.height = 2.2
	boulder_mesh.radial_segments = 6
	boulder_mesh.rings = 4
	boulder_mesh.material = mat_boulder

	# Bush / Shrub clumps
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 0.95
	bush_mesh.height = 1.4
	bush_mesh.radial_segments = 5
	bush_mesh.rings = 3
	bush_mesh.material = mat_shrub

	var z_prop: float = -40.0
	while z_prop > -(track_length + 20.0):
		var center: Vector3 = get_road_center(absf(z_prop))
		var right: Vector3 = get_road_right(absf(z_prop))

		for side in [-1.0, 1.0]:
			# Mossy Boulder
			var b_pos: Vector3 = center + (right * (side * (10.4 + float(int(absf(z_prop)) % 5))))
			var boulder := MeshInstance3D.new()
			boulder.mesh = boulder_mesh
			boulder.position = b_pos + Vector3(0.0, 0.8, 0.0)
			boulder.scale = Vector3(1.2, 0.8, 1.4)
			props_group.add_child(boulder)

			# Forest Shrub next to boulder
			var shrub := MeshInstance3D.new()
			shrub.mesh = bush_mesh
			shrub.position = b_pos + Vector3(side * 1.6, 0.6, 1.2)
			props_group.add_child(shrub)

			# Occasional fallen log or tree stump
			if int(absf(z_prop)) % 120 < 40:
				var log_pos: Vector3 = center + (right * (side * 14.0))
				var log_inst := MeshInstance3D.new()
				log_inst.mesh = log_mesh
				log_inst.position = log_pos + Vector3(0.0, 0.35, 0.0)
				log_inst.rotation_degrees = Vector3(0.0, (int(absf(z_prop)) % 60) - 30.0, 90.0)
				props_group.add_child(log_inst)
			elif int(absf(z_prop)) % 120 < 80:
				var stump_pos: Vector3 = center + (right * (side * 12.0))
				var stump_inst := MeshInstance3D.new()
				stump_inst.mesh = stump_mesh
				stump_inst.position = stump_pos + Vector3(0.0, 0.45, 0.0)
				props_group.add_child(stump_inst)

		z_prop -= 45.0

# --- 9. Overhead Timber Canopy Bridges ---
func _build_overhead_timber_bridges() -> void:
	var bridges_group := Node3D.new()
	bridges_group.name = "OverheadTimberBridges"
	add_child(bridges_group)

	var bridge_distances: Array[float] = [320.0, 680.0]
	for d in bridge_distances:
		var center: Vector3 = get_road_center(d)
		var right: Vector3 = get_road_right(d)
		var forward: Vector3 = get_road_forward(d)
		var heading: float = atan2(-forward.x, -forward.z)

		var b_root := Node3D.new()
		b_root.position = center
		b_root.rotation = Vector3(0.0, heading, 0.0)
		bridges_group.add_child(b_root)

		# Side Timber Support Towers
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.4
		pole_mesh.bottom_radius = 0.45
		pole_mesh.height = 7.5
		pole_mesh.material = mat_timber_post

		var pl := MeshInstance3D.new()
		pl.mesh = pole_mesh
		pl.position = Vector3(-(road_width / 2.0 + 1.4), 3.75, 0.0)
		b_root.add_child(pl)

		var pr := MeshInstance3D.new()
		pr.mesh = pole_mesh
		pr.position = Vector3((road_width / 2.0 + 1.4), 3.75, 0.0)
		b_root.add_child(pr)

		# Overhead Log Beam
		var beam_mesh := BoxMesh.new()
		beam_mesh.size = Vector3(road_width + 3.8, 1.2, 1.4)
		beam_mesh.material = mat_timber_rail

		var beam := MeshInstance3D.new()
		beam.mesh = beam_mesh
		beam.position = Vector3(0.0, 6.8, 0.0)
		b_root.add_child(beam)

		# Decorative Timber Roof Shingles
		var roof_mesh := BoxMesh.new()
		roof_mesh.size = Vector3(road_width + 4.2, 0.3, 2.2)
		roof_mesh.material = mat_bark_dark

		var roof := MeshInstance3D.new()
		roof.mesh = roof_mesh
		roof.position = Vector3(0.0, 7.5, 0.0)
		b_root.add_child(roof)

# --- 10. Forest Road Signs & Distance Markers ---
func _build_forest_signs() -> void:
	var signs_group := Node3D.new()
	signs_group.name = "ForestRoadSigns"
	add_child(signs_group)

	# Distance boards at remaining distances along the 1000m course
	var marker_distances: Array[float] = [200.0, 400.0, 600.0, 800.0, 920.0]
	var marker_labels: Array[String] = ["800M", "600M", "400M", "200M", "80M"]

	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(0.2, 1.4, 2.2)
	board_mesh.material = mat_wood_sign

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.10
	post_mesh.bottom_radius = 0.12
	post_mesh.height = 2.4
	post_mesh.material = mat_timber_post

	for i in range(marker_distances.size()):
		var d: float = marker_distances[i]
		var center: Vector3 = get_road_center(d)
		var right: Vector3 = get_road_right(d)
		var forward: Vector3 = get_road_forward(d)
		var heading: float = atan2(-forward.x, -forward.z)

		for side in [-1.0, 1.0]:
			var sign_root := Node3D.new()
			sign_root.position = center + right * (side * 9.4)
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
	var curve_sign_distances: Array[float] = [100.0, 300.0, 520.0, 720.0]
	for d_curve in curve_sign_distances:
		var center: Vector3 = get_road_center(d_curve)
		var right: Vector3 = get_road_right(d_curve)
		var forward: Vector3 = get_road_forward(d_curve)
		var heading: float = atan2(-forward.x, -forward.z)

		var c_sign := Node3D.new()
		c_sign.position = center + right * 9.5
		c_sign.rotation = Vector3(0.0, heading, 0.0)

		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.position = Vector3(0.0, 1.2, 0.0)
		c_sign.add_child(post)

		var board := MeshInstance3D.new()
		board.mesh = board_mesh
		board.position = Vector3(0.0, 2.1, 0.0)
		board.material_override = mat_sign_gold
		c_sign.add_child(board)

		signs_group.add_child(c_sign)

# --- 11. Checkered Timber Start Gantry ---
func _build_start_gantry() -> void:
	var start_group := Node3D.new()
	start_group.name = "ForestStartGantryGroup"
	start_group.position = Vector3(0.0, 0.0, 0.0)
	add_child(start_group)

	# Heavy Log Side Pillars
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.5
	pillar_mesh.bottom_radius = 0.6
	pillar_mesh.height = 7.5
	pillar_mesh.material = mat_gantry_timber

	var pl := MeshInstance3D.new()
	pl.mesh = pillar_mesh
	pl.position = Vector3(-(road_width / 2.0 + 1.5), 3.75, 0.0)
	start_group.add_child(pl)

	var pr := MeshInstance3D.new()
	pr.mesh = pillar_mesh
	pr.position = Vector3(road_width / 2.0 + 1.5, 3.75, 0.0)
	start_group.add_child(pr)

	# Overhead Truss
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(road_width + 4.0, 1.4, 1.2)
	bar_mesh.material = mat_gantry_timber

	var bar := MeshInstance3D.new()
	bar.mesh = bar_mesh
	bar.position = Vector3(0.0, 7.0, 0.0)
	start_group.add_child(bar)

	# Emerald Green Start Banner
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(12.0, 1.2, 1.25)
	banner_mesh.material = mat_finish_banner

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

# --- 12. Grand Timber Finish Gantry & Trigger Area ---
func _build_finish_gantry_and_trigger() -> void:
	var finish_group := Node3D.new()
	finish_group.name = "ForestFinishGantryGroup"
	finish_group.position = Vector3(0.0, 0.0, -track_length)
	add_child(finish_group)

	# Heavy Log Side Towers
	var tower_mesh := CylinderMesh.new()
	tower_mesh.top_radius = 0.65
	tower_mesh.bottom_radius = 0.75
	tower_mesh.height = 8.5
	tower_mesh.material = mat_gantry_timber

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
	fbar_mesh.size = Vector3(road_width + 4.5, 1.8, 1.4)
	fbar_mesh.material = mat_gantry_timber

	var fbar := MeshInstance3D.new()
	fbar.mesh = fbar_mesh
	fbar.position = Vector3(0.0, 7.8, 0.0)
	finish_group.add_child(fbar)

	# Illuminated Finish Line Banner
	var f_banner_mesh := BoxMesh.new()
	f_banner_mesh.size = Vector3(13.2, 1.4, 1.45)
	f_banner_mesh.material = mat_finish_banner

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

	# Forest Ranger Watchtower / Race Control on right side
	var lodge_mesh := BoxMesh.new()
	lodge_mesh.size = Vector3(6.0, 11.0, 6.0)
	lodge_mesh.material = mat_timber_rail

	var timing_lodge := MeshInstance3D.new()
	timing_lodge.mesh = lodge_mesh
	timing_lodge.position = Vector3(14.5, 5.5, 0.0)
	finish_group.add_child(timing_lodge)

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

# --- 13. Finish Line Collision & Trigger Logic ---
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

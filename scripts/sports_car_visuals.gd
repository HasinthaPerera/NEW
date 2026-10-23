extends Node3D
class_name SportsCarVisuals

@export var body_paint_color: Color = Color(0.98, 0.44, 0.05, 1.0) # Default: Metallic Muscle Orange

var paint_material: StandardMaterial3D

@onready var wheels: Node3D = $Wheels
@onready var nitro_flame_left: MeshInstance3D = $NitroFlameL
@onready var nitro_flame_right: MeshInstance3D = $NitroFlameR

func _ready() -> void:
	_init_paint_material()
	set_paint_color(body_paint_color)
	set_nitro_active(false)

func _init_paint_material() -> void:
	if not paint_material:
		paint_material = StandardMaterial3D.new()
	paint_material.albedo_color = body_paint_color
	paint_material.metallic = 0.75
	paint_material.roughness = 0.22

func set_paint_color(color: Color) -> void:
	body_paint_color = color
	if not paint_material:
		_init_paint_material()
	paint_material.albedo_color = color

	# Painted body panels: lower nose, doors/midbody, flared fenders, rear deck
	var painted_paths: Array[NodePath] = [
		^"Body/MainBody",
		^"Body/FrontBumperUpper",
		^"Body/FenderFL",
		^"Body/FenderFR",
		^"Body/FenderRL",
		^"Body/FenderRR",
		^"Body/RearDeck",
		^"Body/DoorSills"
	]

	for path in painted_paths:
		var node := get_node_or_null(path)
		if node is MeshInstance3D:
			node.material_override = paint_material

func spin_wheels(rotation_amount: float) -> void:
	if not wheels:
		wheels = get_node_or_null(^"Wheels")
	if not wheels:
		return
	for wheel in wheels.get_children():
		wheel.rotate_x(rotation_amount)

func set_nitro_active(active: bool) -> void:
	if not nitro_flame_left:
		nitro_flame_left = get_node_or_null(^"NitroFlameL") as MeshInstance3D
	if not nitro_flame_right:
		nitro_flame_right = get_node_or_null(^"NitroFlameR") as MeshInstance3D
	if nitro_flame_left:
		nitro_flame_left.visible = active
	if nitro_flame_right:
		nitro_flame_right.visible = active

func _process(_delta: float) -> void:
	# Subtle nitro flame pulse when active
	if nitro_flame_left and nitro_flame_left.visible:
		var pulse: float = 1.0 + 0.35 * sin(Time.get_ticks_msec() * 0.04)
		var flame_scale := Vector3(pulse, pulse, pulse * 1.5)
		nitro_flame_left.scale = flame_scale
		if nitro_flame_right:
			nitro_flame_right.scale = flame_scale

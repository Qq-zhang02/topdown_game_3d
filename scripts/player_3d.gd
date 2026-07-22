extends CharacterBody3D
class_name Player3D
## 3D 俯视角玩家

const EquipmentClass := preload("res://scripts/equipment.gd")

var _model_path: String = "res://models/animals/animal-fox.glb"

@export var speed: float = 9.0
@export var jump_velocity: float = 15.0
@export var gravity: float = 35.0
@export var vision_range: float = 5.0  # 视力属性，瞄准时摄像机最大偏移距离

var _equipment_mgr: Node
var _model_root: Node3D


func set_model_path(path: String) -> void:
	_model_path = path


func _ready() -> void:
	_create_model()
	_create_collision()
	_create_lights_and_equipment()


# ═══════════════════════════════════════════
# 模型
# ═══════════════════════════════════════════

func _create_model() -> void:
	if not ResourceLoader.exists(_model_path):
		return

	var scene: PackedScene = load(_model_path)
	if not scene:
		return

	_model_root = scene.instantiate()
	_model_root.name = "CharacterModel"
	add_child(_model_root)

	_set_shadow_recursive(_model_root)

	var aabb := _get_model_aabb(_model_root)
	if aabb.size.y > 0.01:
		var target_height := 1.5
		var scale_factor: float = target_height / aabb.size.y
		_model_root.scale = Vector3(scale_factor, scale_factor, scale_factor)

	_model_root.rotation.y = PI


func _get_model_aabb(node: Node3D) -> AABB:
	if not node:
		return AABB()
	var aabb: AABB = AABB()
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child
		var local_aabb := mesh.get_aabb()
		if local_aabb.size.length_squared() > 0.001:
			var global_aabb := mesh.global_transform * local_aabb
			if aabb.size.length_squared() < 0.001:
				aabb = global_aabb
			else:
				aabb = aabb.merge(global_aabb)
	return aabb


func _set_shadow_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_shadow_recursive(child)


func _create_collision() -> void:
	if not _model_root:
		var col := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.6
		col.shape = shape
		add_child(col)
		return

	var aabb := _get_model_aabb(_model_root)
	if aabb.size.length_squared() < 0.1:
		var col := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.6
		col.shape = shape
		add_child(col)
		return

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = max(aabb.size.x, aabb.size.z) * 0.45
	shape.height = aabb.size.y * 0.85
	col.shape = shape
	# AABB.position 是最小角而非中心，必须用 get_center() 或 position + size/2
	# to_local 确保在世界坐标->本地坐标正确转换
	col.position = to_local(aabb.position + aabb.size * 0.5)
	add_child(col)


# ═══════════════════════════════════════════
# 装备系统
# ═══════════════════════════════════════════

func _create_lights_and_equipment() -> void:
	var spot := SpotLight3D.new()
	spot.name = "SpotLight"
	spot.visible = false
	add_child(spot)

	var omni := OmniLight3D.new()
	omni.name = "OmniLight"
	omni.visible = false
	add_child(omni)

	var MgrScript := load("res://scripts/equipment_manager.gd")
	_equipment_mgr = Node.new()
	_equipment_mgr.set_script(MgrScript)
	_equipment_mgr.name = "EquipmentManager"
	_equipment_mgr.setup(spot, omni)
	add_child(_equipment_mgr)

	_equipment_mgr.add_equipment(_make_flashlight())
	_equipment_mgr.add_equipment(_make_torch())


func _make_flashlight() -> Resource:
	var eq := EquipmentClass.new()
	eq.set("id", "flashlight")
	eq.set("display_name", "手电筒")
	eq.set("light_type", EquipmentClass.LightType.SPOT)
	eq.set("position_offset", Vector3(0, 1.0, -0.4))
	eq.set("rotation_offset", Vector3(deg_to_rad(-20), 0, 0))
	eq.set("spot_range", 50.0)
	eq.set("spot_attenuation", 0.6)
	eq.set("spot_angle", 40.0)
	eq.set("light_color", Color(1.0, 0.95, 0.8))
	eq.set("light_energy", 8.0)
	eq.set("light_indirect_energy", 1.5)
	eq.set("shadow_enabled", true)
	eq.set("equipped", true)
	return eq


func _make_torch() -> Resource:
	var eq := EquipmentClass.new()
	eq.set("id", "torch")
	eq.set("display_name", "火把")
	eq.set("light_type", EquipmentClass.LightType.OMNI)
	eq.set("position_offset", Vector3(0, 1.6, 0.3))
	eq.set("omni_range", 12.0)
	eq.set("omni_attenuation", 0.8)
	eq.set("light_color", Color(1.0, 0.55, 0.15))
	eq.set("light_energy", 5.0)
	eq.set("light_indirect_energy", 1.0)
	eq.set("shadow_enabled", false)
	eq.set("equipped", true)
	return eq


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_equipment"):
		_equipment_mgr.cycle_next()


# ═══════════════════════════════════════════
# 移动 + 跳跃 + 朝向
# ═══════════════════════════════════════════

## 获取鼠标指向的地面世界坐标（XZ 平面）
func get_mouse_ground_position() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return global_position

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_pos)

	var ground_plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = ground_plane.intersects_ray(from, ray_dir)

	if hit is Vector3:
		return hit
	return global_position


## 是否处于瞄准状态（按住鼠标右键）
func is_aiming() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var current_speed: float = speed * 0.5 if is_aiming() else speed
	velocity.x = input_dir.x * current_speed
	velocity.z = input_dir.y * current_speed
	move_and_slide()

	_face_mouse()


func _face_mouse() -> void:
	var hit := get_mouse_ground_position()
	var look_target := Vector3(hit.x, global_position.y, hit.z)
	if look_target.distance_squared_to(global_position) > 0.001:
		look_at(look_target, Vector3.UP)

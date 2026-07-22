extends CharacterBody3D
class_name Player3D
## 3D 俯视角玩家

const EquipmentClass := preload("res://scripts/equipment.gd")

# 动画状态
enum AnimState { IDLE, RUN, JUMP }

var _model_path: String = "res://models/survivor/characterMedium.fbx"
var _skin_path: String = "res://models/survivor/survivorMaleB.png"

@export var speed: float = 9.0
@export var jump_velocity: float = 15.0
@export var gravity: float = 35.0
@export var vision_range: float = 5.0  # 视力属性，瞄准时摄像机最大偏移距离

var _equipment_mgr: Node
var _model_root: Node3D
var _anim_player: AnimationPlayer
var _anim_state: AnimState = AnimState.IDLE


func set_model_path(path: String) -> void:
	_model_path = path


func set_skin_path(path: String) -> void:
	_skin_path = path


func _ready() -> void:
	_create_model()
	_create_collision()
	_create_lights_and_equipment()
	_setup_animations()


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
	_apply_skin(_model_path)

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


## 为 FBX 模型（无内嵌贴图）应用皮肤纹理
func _apply_skin(model_path: String) -> void:
	if _skin_path.is_empty() or not ResourceLoader.exists(_skin_path):
		return
	var tex: Texture2D = load(_skin_path)
	if not tex:
		return
	for mesh: MeshInstance3D in _model_root.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mesh.mesh
		if not m:
			continue
		for i in m.get_surface_count():
			var mat := mesh.get_active_material(i)
			if not mat:
				continue
			mat = mat.duplicate()
			mat.albedo_texture = tex
			mesh.set_surface_override_material(i, mat)


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
# 动画系统
# ═══════════════════════════════════════════

func _setup_animations() -> void:
	if not _model_root:
		print("[Player3D] _setup_animations: _model_root 为空，跳过")
		return

	print("[Player3D] _setup_animations: 开始加载动画...")
	# 尝试从导入的 FBX 场景中找 AnimationPlayer
	_anim_player = _model_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not _anim_player:
		_anim_player = AnimationPlayer.new()
		_anim_player.name = "AnimationPlayer"
		_model_root.add_child(_anim_player)
		print("[Player3D] _setup_animations: 创建新的 AnimationPlayer")
	else:
		print("[Player3D] _setup_animations: 使用 FBX 自带的 AnimationPlayer")

	# 加载动画（从 FBX 场景中提取 AnimationPlayer 的动画数据）
	_try_load_anim("idle", "res://models/survivor/animations/idle.fbx")
	_try_load_anim("run", "res://models/survivor/animations/run.fbx")
	_try_load_anim("jump", "res://models/survivor/animations/jump.fbx")

	# 有动画就播 idle
	if _anim_player.has_animation("idle"):
		_anim_player.play("idle")


func _try_load_anim(anim_name: String, path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("[Player3D] 动画文件不存在: " + path)
		return

	var anim_scene: PackedScene = load(path)
	if not anim_scene:
		push_warning("[Player3D] 动画场景加载失败: " + path)
		return

	# 实例化动画场景（不入树），提取 AnimationPlayer
	var anim_node: Node = anim_scene.instantiate()
	print("[Player3D] 动画场景子节点: ", anim_node.get_children().map(func(c): return c.name))
	var src_ap: AnimationPlayer
	for child in anim_node.find_children("*", "AnimationPlayer", true, false):
		src_ap = child
		break

	if not src_ap:
		push_warning("[Player3D] 动画场景中无 AnimationPlayer: " + path)
		anim_node.queue_free()
		return

	# 获取主模型骨骼路径（用于重映射）
	var main_skel_path: String = ""
	for child in _model_root.find_children("*", "Skeleton3D", true, false):
		main_skel_path = str(_model_root.get_path_to(child))
		break

	var anim_skel_path: String = ""
	for child in anim_node.find_children("*", "Skeleton3D", true, false):
		anim_skel_path = str(anim_node.get_path_to(child))
		break

	var lib := AnimationLibrary.new()
	for a in src_ap.get_animation_list():
		var anim: Animation = src_ap.get_animation(a)
		# 如果骨骼路径不一致，重映射 track 路径
		if main_skel_path != "" and anim_skel_path != "" and anim_skel_path != main_skel_path:
			anim = _remap_animation_tracks(anim.duplicate(), anim_skel_path, main_skel_path)
		lib.add_animation(anim_name, anim)

	_anim_player.add_animation_library(anim_name, lib)
	anim_node.queue_free()
	print("[Player3D] 动画加载成功: %s (%d tracks)" % [anim_name, src_ap.get_animation_list().size()])


## 重映射动画 track 中的骨骼路径（动画场景 → 主模型）
func _remap_animation_tracks(anim: Animation, from_prefix: String, to_prefix: String) -> Animation:
	for i in range(anim.get_track_count()):
		var tp: NodePath = anim.track_get_path(i)
		var tp_str: String = str(tp)
		if tp_str.begins_with(from_prefix):
			var new_path: String = to_prefix + tp_str.substr(from_prefix.length())
			anim.track_set_path(i, new_path)
	return anim


func _update_animation(input_length: float) -> void:
	if not _anim_player:
		return

	var new_state: AnimState
	if not is_on_floor():
		new_state = AnimState.JUMP
	elif input_length > 0.1:
		new_state = AnimState.RUN
	else:
		new_state = AnimState.IDLE

	if new_state == _anim_state:
		return
	_anim_state = new_state

	match new_state:
		AnimState.IDLE:
			if _anim_player.has_animation("idle"):
				_anim_player.play("idle")
		AnimState.RUN:
			if _anim_player.has_animation("run"):
				_anim_player.play("run")
		AnimState.JUMP:
			if _anim_player.has_animation("jump"):
				_anim_player.play("jump")


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
	_update_animation(input_dir.length())


func _face_mouse() -> void:
	var hit := get_mouse_ground_position()
	var look_target := Vector3(hit.x, global_position.y, hit.z)
	if look_target.distance_squared_to(global_position) > 0.001:
		look_at(look_target, Vector3.UP)

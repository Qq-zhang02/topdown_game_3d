extends CharacterBody3D
class_name Player3D
## 3D 俯视角玩家

const EquipmentClass := preload("res://scripts/equipment.gd")

# 动画状态
enum AnimState { IDLE, RUN, JUMP }

var _model_path: String = "res://models/character/character-archer.glb"
var _skin_path: String = "res://models/character/colormap.png"

@export var speed: float = 5.0
@export var jump_velocity: float = 15.0
@export var gravity: float = 35.0
@export var vision_range: float = 5.0  # 视力属性，瞄准时摄像机最大偏移距离

var _equipment_mgr: Node
var _model_root: Node3D
var _anim_player: AnimationPlayer
var _anim_state: AnimState = AnimState.IDLE
var _anim_map: Dictionary = {}  # "idle"→实际动画名, "run"→..., "jump"→...

var _health: Node
var _inventory: Node
var _dead: bool = false
var _attacking: bool = false


func set_model_path(path: String) -> void:
	_model_path = path


func set_skin_path(path: String) -> void:
	_skin_path = path


func _ready() -> void:
	_create_model()
	_create_collision()
	_create_lights_and_equipment()
	_create_survival()
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
		return

	# 尝试从 GLB 模型中找自带的 AnimationPlayer
	_anim_player = _model_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not _anim_player:
		return

	# GLB 动画名可能不同，建立 状态→实际名 映射
	var anims := _anim_player.get_animation_list()
	print("[Player3D] 发现内嵌动画: ", anims)

	for a in anims:
		var lower := a.to_lower()
		if "attack-melee" in lower:
			if not _anim_map.has("attack"):
				_anim_map["attack"] = a
		elif "die" in lower and "idle" not in lower:
			_anim_map["die"] = a
		elif "idle" in lower:
			_anim_map["idle"] = a
		elif "run" in lower or "walk" in lower:
			_anim_map["run"] = a
		elif "jump" in lower:
			_anim_map["jump"] = a

	# 移动动画循环，攻击/死亡不循环
	for key in _anim_map:
		var anim := _anim_player.get_animation(_anim_map[key])
		if anim:
			if key == "attack" or key == "die":
				anim.loop_mode = Animation.LOOP_NONE
			else:
				anim.loop_mode = Animation.LOOP_LINEAR

	if _anim_map.has("idle"):
		_anim_player.play(_anim_map["idle"])


func _update_animation(input_length: float) -> void:
	if not _anim_player or _attacking or _dead:
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
			if _anim_map.has("idle"):
				_anim_player.play(_anim_map["idle"])
		AnimState.RUN:
			if _anim_map.has("run"):
				_anim_player.play(_anim_map["run"])
		AnimState.JUMP:
			if _anim_map.has("jump"):
				_anim_player.play(_anim_map["jump"])


## 近战挥击动画（由 MeleeController 调用）
func play_attack() -> void:
	if _dead or _attacking:
		return
	if not _anim_player or not _anim_map.has("attack"):
		return
	_attacking = true
	_anim_player.play(_anim_map["attack"])
	if not _anim_player.animation_finished.is_connected(_on_anim_finished):
		_anim_player.animation_finished.connect(_on_anim_finished)


func _on_anim_finished(anim_name: String) -> void:
	if _anim_map.has("attack") and anim_name == _anim_map["attack"]:
		_attacking = false
		_anim_state = AnimState.IDLE
		if not _dead and _anim_map.has("idle"):
			_anim_player.play(_anim_map["idle"])


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


# ═══════════════════════════════════════════
# 生存系统：血量 / 背包 / 近战
# ═══════════════════════════════════════════

func _create_survival() -> void:
	var HealthScript := load("res://scripts/combat/health.gd")
	_health = Node.new()
	_health.set_script(HealthScript)
	_health.name = "Health"
	_health.set("max_hp", 100.0)
	add_child(_health)
	_health.died.connect(_on_died)

	var InvScript := load("res://scripts/inventory/inventory.gd")
	_inventory = Node.new()
	_inventory.set_script(InvScript)
	_inventory.name = "Inventory"
	add_child(_inventory)

	var MeleeScript := load("res://scripts/combat/melee_controller.gd")
	var melee := Node.new()
	melee.set_script(MeleeScript)
	melee.name = "MeleeController"
	add_child(melee)

	# 初始物资（用于验证各系统）
	var ItemDBScript := load("res://scripts/core/item_db.gd")
	_inventory.add_item(ItemDBScript.get_item("wood"), 12)
	_inventory.add_item(ItemDBScript.get_item("stone"), 8)
	var sword: Resource = ItemDBScript.get_item("sword_wood")
	if sword:
		_equipment_mgr.add_equipment(sword)


func get_health() -> Health:
	return _health as Health


func get_inventory() -> Node:
	return _inventory


func is_dead() -> bool:
	return _dead


func _on_died() -> void:
	_dead = true
	velocity = Vector3.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if _anim_player and _anim_map.has("die"):
		_anim_player.play(_anim_map["die"])


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
	eq.set("omni_range", 6.0)
	eq.set("omni_attenuation", 0.8)
	eq.set("light_color", Color(1.0, 0.55, 0.15))
	eq.set("light_energy", 5.0)
	eq.set("light_indirect_energy", 1.0)
	eq.set("shadow_enabled", false)
	eq.set("equipped", true)
	return eq


func _input(event: InputEvent) -> void:
	if _dead:
		return
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
	if _dead:
		return

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

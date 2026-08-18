@tool
extends CharacterBody3D
class_name Player3D
## 3D 俯视角玩家

# 动画状态
enum AnimState { IDLE, RUN, JUMP, FALL }

var _model_path: String = "res://models/character/character-archer.glb"
const DEFAULT_SKIN := "res://models/character/Textures/colormap.png"
var _skin_path: String = DEFAULT_SKIN

@export var speed: float = 4.0
@export var jump_velocity: float = 15.0
@export var gravity: float = 35.0
@export var rotation_lag: float = 0.0  # 转向迟滞，越高转向越笨重，最高加到0.95
@export var vision_range: float = 6.0  # 视力属性，瞄准时摄像机最大偏移距离

var _equipment_mgr: Node
var _model_root: Node3D
var _anim_player: AnimationPlayer
var _anim_state: AnimState = AnimState.IDLE
var _anim_map: Dictionary = {}  # "idle"→实际动画名, "run"→..., "jump"→...

var _health: Node
var _inventory: Node
var _dead: bool = false
var _attacking: bool = false
var _knockback: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _in_water: bool = false
var _stepped_up_last_frame: bool = false
var _collision_shape: CollisionShape3D
var _step_fail_pos: Vector3 = Vector3.INF
var _step_fail_cd: float = 0.0


func set_model_path(path: String) -> void:
	_model_path = path


func set_skin_path(path: String) -> void:
	_skin_path = path


func _ready() -> void:
	# 编辑器预览：给场景中预置的模型应用皮肤贴图（GLB 无内嵌贴图）
	if Engine.is_editor_hint():
		_apply_editor_preview_skin()
		return
	_create_model()
	_create_collision()
	_create_inventory()
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

	var placeholder: Node3D = get_node_or_null("CharacterModel")
	if not placeholder:
		return
	# 清掉编辑器里预置的预览模型，运行时按角色选择加载实际模型
	for child in placeholder.get_children():
		placeholder.remove_child(child)
		child.queue_free()
	_model_root = scene.instantiate()
	_model_root.name = "CharacterModelInstance"
	placeholder.add_child(_model_root)

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


## 为 FBX 模型（无内嵌贴图）应用皮肤纹理
func _apply_skin(model_path: String) -> void:
	if _skin_path.is_empty() or not ResourceLoader.exists(_skin_path):
		_skin_path = DEFAULT_SKIN
		if not ResourceLoader.exists(_skin_path):
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


## 编辑器预览：给场景预置模型应用皮肤（GLB 无内嵌贴图，运行时才应用）
func _apply_editor_preview_skin() -> void:
	if _skin_path.is_empty() or not ResourceLoader.exists(_skin_path):
		_skin_path = DEFAULT_SKIN
		if not ResourceLoader.exists(_skin_path):
			return
	var tex: Texture2D = load(_skin_path)
	if not tex:
		return
	var placeholder := get_node_or_null("CharacterModel")
	if not placeholder:
		return
	for node: Node in placeholder.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh or not mesh.mesh:
			continue
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(i)
			if not mat:
				continue
			var dup := mat.duplicate()
			if dup is StandardMaterial3D:
				dup.albedo_texture = tex
				mesh.set_surface_override_material(i, dup)


func _create_collision() -> void:
	# ★ 场景中预置的 CollisionShape3D 优先：完全尊重编辑器里调整的
	#   形状/位置，不再按模型 AABB 覆盖（可视化编辑即所见即所得）
	var col: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if col:
		_collision_shape = col
		return
	# 兜底：场景无碰撞节点时按模型 AABB 生成
	col = CollisionShape3D.new()
	add_child(col)
	_collision_shape = col
	if not _model_root:
		return
	var aabb := _get_model_aabb(_model_root)
	if aabb.size.length_squared() < 0.1:
		return
	var shape := CapsuleShape3D.new()
	shape.radius = max(aabb.size.x, aabb.size.z) * 0.45
	shape.height = aabb.size.y * 0.85
	col.shape = shape
	col.position = to_local(aabb.position + aabb.size * 0.5)


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
		elif "fall" in lower:
			_anim_map["fall"] = a

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
	if _in_water:
		new_state = AnimState.FALL
	elif not is_on_floor():
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
		AnimState.FALL:
			if _anim_map.has("fall"):
				_anim_player.play(_anim_map["fall"])
			elif _anim_map.has("jump"):
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
# 背包（提前创建，装备管理器需要引用）
# ═══════════════════════════════════════════

func _create_inventory() -> void:
	_inventory = $Inventory


# ═══════════════════════════════════════════
# 装备系统
# ═══════════════════════════════════════════

func _create_lights_and_equipment() -> void:
	_equipment_mgr = $EquipmentManager
	_equipment_mgr.setup($SpotLight, $OmniLight, _inventory)


# ═══════════════════════════════════════════
# 生存系统：血量 / 近战
# ═══════════════════════════════════════════

func _create_survival() -> void:
	_health = $Health
	_health.died.connect(_on_died)

	# 初始物资 → 先进背包再装备
	var ItemDBScript := load("res://scripts/core/item_db.gd")
	_inventory.add_item(ItemDBScript.get_item("wood"), 12)
	_inventory.add_item(ItemDBScript.get_item("stone"), 8)

	# 功能装备：手电筒、火把
	var flashlight: Resource = ItemDBScript.get_item("flashlight")
	if flashlight:
		_inventory.add_item(flashlight, 1)
		_equipment_mgr.equip_from_inventory(_find_inventory_slot("flashlight"))

	var torch: Resource = ItemDBScript.get_item("torch")
	if torch:
		_inventory.add_item(torch, 1)
		_equipment_mgr.equip_from_inventory(_find_inventory_slot("torch"))

	# 武器：木剑
	var sword: Resource = ItemDBScript.get_item("sword_wood")
	if sword:
		_inventory.add_item(sword, 1)
		_equipment_mgr.equip_from_inventory(_find_inventory_slot("sword_wood"))


func _find_inventory_slot(item_id: String) -> int:
	for i in range(_inventory.slots.size()):
		var st = _inventory.get_stack(i)
		if st and st.item.get("id") == item_id:
			return i
	return -1


func get_health() -> Health:
	return _health as Health


func get_inventory() -> Node:
	return _inventory


func apply_knockback(dir: Vector3, impulse: float) -> void:
	_knockback = dir * impulse


## 竖直击退：瞬时冲量（直接作用于 velocity.y，与跳跃同机制）
## 只生效一帧，不进入 _knockback 衰减队列，避免落地后残值反复抬升抖动
func apply_up_knockback(v: float) -> void:
	if v > 0.0:
		velocity.y = maxf(velocity.y, v)


func is_dead() -> bool:
	return _dead


func _on_died() -> void:
	_dead = true
	velocity = Vector3.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if _anim_player and _anim_map.has("die"):
		_anim_player.play(_anim_map["die"])


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _dead:
		return
	if event.is_action_pressed("cycle_equipment"):
		_equipment_mgr.cycle_utility()
	if event.is_action_pressed("cycle_weapon"):
		_equipment_mgr.cycle_weapon()
	if event.is_action_pressed("consume_1"):
		_equipment_mgr.use_consumable(0)
	if event.is_action_pressed("consume_2"):
		_equipment_mgr.use_consumable(1)
	if event.is_action_pressed("consume_3"):
		_equipment_mgr.use_consumable(2)


# ═══════════════════════════════════════════
# 移动 + 跳跃 + 朝向
# ═══════════════════════════════════════════

## 获取鼠标指向的地面世界坐标
func get_mouse_ground_position() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return global_position

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_pos)

	# 先尝试射线检测地形碰撞（层 1 = 地面/障碍物）
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + ray_dir * 200.0)
	query.collision_mask = 1
	var result := space.intersect_ray(query)
	if not result.is_empty():
		return result.position

	# 回退：平面相交
	var ground_plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = ground_plane.intersects_ray(from, ray_dir)
	if hit is Vector3:
		return hit
	return global_position


## 是否处于瞄准状态（按住鼠标右键）
func is_aiming() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func set_in_water(v: bool) -> void:
	_in_water = v


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _dead:
		return

	if _in_water:
		# 水中缓慢下沉，覆盖重力和跳跃
		velocity.y = -2.0
	elif not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not _in_water:
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var current_speed: float = speed * 0.25 if is_aiming() else speed #瞄准状态下减速
	velocity.x = input_dir.x * current_speed
	velocity.z = input_dir.y * current_speed
	# 击退（叠加后衰减）
	velocity += _knockback
	_knockback = _knockback.lerp(Vector3.ZERO, delta * 4.0)

	# 跨步失败回退：上帧抬升后撞墙悬空 -> 退回原高度
	if _stepped_up_last_frame:
		_stepped_up_last_frame = false
		if is_on_wall() and not is_on_floor():
			global_position.y -= STEP_HEIGHT
			_step_fail_pos = global_position
			_step_fail_cd = 0.3
		else:
			_step_fail_pos = Vector3.INF
			_step_fail_cd = 0.0

	_step_up(delta)

	move_and_slide()

	_face_mouse(delta)
	_update_animation(input_dir.length())

@export var STEP_HEIGHT: float = 0.8 # 跨越高度（米）
@export var STEP_FORWARD: float = 0.15 # 前探距离
@export var STEP_FAIL_BLOCK_RADIUS: float = 0.3 # 失败阻断半径


func _step_up(delta: float) -> void:
	# 失败 CD 倒计时
	if _step_fail_cd > 0.0:
		_step_fail_cd -= delta
	if _step_fail_pos != Vector3.INF and global_position.distance_to(_step_fail_pos) < STEP_FAIL_BLOCK_RADIUS and _step_fail_cd > 0.0:
		return
	if _step_fail_cd <= 0.0:
		_step_fail_pos = Vector3.INF

	if not is_on_floor() or _in_water:
		return

	var h_vel := Vector3(velocity.x, 0.0, velocity.z)
	var h_speed := h_vel.length()
	if h_speed < 0.01:
		return
	var h_dir := h_vel / h_speed

	# 1) 近距法线探测：区分垂直台阶和斜坡
	var probe := move_and_collide(h_dir * 0.1, true)
	if not probe:
		return
	if probe.get_normal().y > cos(floor_max_angle):
		return

	var space := get_world_3d().direct_space_state
	if not _collision_shape or not _collision_shape.shape:
		return
	var body_shape: Shape3D = _collision_shape.shape

	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = body_shape
	q.collision_mask = collision_mask
	q.exclude = [self]
	q.margin = 0.02

	# 用碰撞体实际世界位置（零旋转），避免朝向影响
	var col_origin := _collision_shape.global_position

	# 2) 上方净空：轴对齐静态检测
	q.transform = Transform3D(Basis(), col_origin + Vector3.UP * STEP_HEIGHT)
	if not space.intersect_shape(q, 1).is_empty():
		return

	# 3) 从抬升位置向前：是否净空？
	var fwd_offset: Vector3 = h_dir * max(STEP_FORWARD, h_speed * delta)
	q.transform = Transform3D(Basis(), col_origin + Vector3.UP * STEP_HEIGHT + fwd_offset)
	if not space.intersect_shape(q, 1).is_empty():
		return

	# 4) 前方下方是否有支撑地面？（防悬崖/深坑）
	q.transform = Transform3D(Basis(), col_origin + fwd_offset + Vector3(0.0, -STEP_HEIGHT * 0.3, 0.0))
	if space.intersect_shape(q, 1).is_empty():
		return

	# 5) 全部通过，执行抬升
	global_position.y += STEP_HEIGHT
	_stepped_up_last_frame = true

const ROTATION_DAMPING: float = 12.0 #初始转向速度

func _face_mouse(delta: float) -> void:
	var hit := get_mouse_ground_position()
	var look_target := Vector3(hit.x, global_position.y, hit.z)
	if look_target.distance_squared_to(global_position) > 0.001:
		_target_yaw = atan2(-(hit.x - global_position.x), -(hit.z - global_position.z))

	var factor: float = ROTATION_DAMPING * maxf(0.05, 1.0 - rotation_lag) * delta
	rotation.y = lerp_angle(rotation.y, _target_yaw, minf(factor, 1.0))

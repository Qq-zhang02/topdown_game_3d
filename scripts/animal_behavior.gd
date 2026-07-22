extends Node
class_name AnimalBehavior
## 小动物：自然弹跳 + 被人推挤 + 翻滚恢复

@export var hop_impulse: float = 2.0         # 弹跳水平冲量
@export var hop_up: float = 3.5            # 弹跳垂直冲量
@export var min_hop_interval: float = 1.0
@export var max_hop_interval: float = 4.0

# ── 玩家推挤参数 ──
@export var push_impulse_min: float = 1.5   # 最小推力冲量（玩家静止/慢走时）
@export var push_impulse_max: float = 3    # 最大推力冲量（玩家全速跑时）
@export var player_speed_factor: float = 0.12 # 玩家速度 → 推力转换系数
@export var push_cooldown: float = 0.25       # 两次推力之间的冷却时间（秒）

# ── 安全保护 ──
@export var world_boundary: float = 49.0        # 世界边界（由 AnimalSpawner 设置）
@export var max_linear_velocity: float = 20.0   # 最大水平速度，防止穿透地面

const PUSH_DISTANCE: float = 0.6

var _body: RigidBody3D
var _hop_timer: float = 0.0
var _next_hop: float = 2.0
var _push_cooldown_left: float = 0.0


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	_next_hop = randf_range(min_hop_interval, max_hop_interval)
	if _body:
		_body.axis_lock_angular_x = true
		_body.axis_lock_angular_z = true


func _physics_process(delta: float) -> void:
	if not _body:
		return

	# 冷却递减
	if _push_cooldown_left > 0.0:
		_push_cooldown_left -= delta

	_check_player_push()
	_clamp_to_world()
	_cap_velocity()

	# 弹跳计时
	_hop_timer += delta
	if _hop_timer >= _next_hop:
		_hop_timer = 0.0
		_next_hop = randf_range(min_hop_interval, max_hop_interval)
		_do_hop()


func _do_hop() -> void:
	var angle := randf_range(0.0, TAU)
	var dir := Vector3(cos(angle), 0, sin(angle))

	var model := _body.get_node_or_null("Model") as Node3D
	if model:
		# 用 look_at 计算正确的目标朝向（避免手动算角度出错）
		var target_pos := model.global_position + dir
		var saved_y := model.rotation.y
		model.look_at(target_pos, Vector3.UP, true)
		var target_y := model.rotation.y
		model.rotation.y = saved_y  # 恢复当前朝向

		# 平滑旋转到目标朝向，完成后再弹跳
		var tween := create_tween()
		tween.tween_property(model, "rotation:y", target_y, 0.2)
		tween.tween_callback(_apply_hop.bind(dir))
	else:
		_apply_hop(dir)


func _apply_hop(dir: Vector3) -> void:
	_body.apply_central_impulse(dir * hop_impulse + Vector3.UP * hop_up)


# ── 边界安全 ──

func _clamp_to_world() -> void:
	var pos := _body.global_position
	var clamped := false

	if abs(pos.x) > world_boundary:
		pos.x = clampf(pos.x, -world_boundary, world_boundary)
		clamped = true
	if abs(pos.z) > world_boundary:
		pos.z = clampf(pos.z, -world_boundary, world_boundary)
		clamped = true
	# 防止掉到地下
	if pos.y < -10.0:
		pos.y = 2.0
		_body.linear_velocity = Vector3.ZERO
		clamped = true

	if clamped:
		_body.global_position = pos


# ── 速度限制（防止高速穿透）──

func _cap_velocity() -> void:
	var vel := _body.linear_velocity
	var h_speed := Vector2(vel.x, vel.z).length()
	if h_speed > max_linear_velocity:
		var ratio := max_linear_velocity / h_speed
		_body.linear_velocity = Vector3(vel.x * ratio, vel.y, vel.z * ratio)


# ── 玩家推挤（代码驱动，无物理双向碰撞）──

func _check_player_push() -> void:
	# 冷却中不处理
	if _push_cooldown_left > 0.0:
		return

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: CharacterBody3D = players[0] as CharacterBody3D
	if not player:
		return

	var dist: float = _body.global_position.distance_to(player.global_position)
	if dist > PUSH_DISTANCE:
		return

	# 推开方向（远离玩家）
	var away: Vector3 = _body.global_position - player.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	away = away.normalized()

	# ── 推力计算 ──
	# 距离越近力越大（ratio: 0→1）
	var ratio: float = 1.0 - dist / PUSH_DISTANCE

	# 玩家水平速度越大，推力越大
	var player_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var speed_bonus: float = player_speed * player_speed_factor

	# 最终冲量 = 基础值 + 速度加成，限制在 min/max 之间
	var impulse_mag: float = clampf(
		push_impulse_min + speed_bonus * ratio,
		push_impulse_min,
		push_impulse_max
	)

	# 一次性冲量（而非每帧持续施力），不会把动物越推越快
	_body.apply_central_impulse(away * impulse_mag + Vector3.UP * impulse_mag * 0.15)

	# 进入冷却
	_push_cooldown_left = push_cooldown

extends Node
class_name AnimalBehavior
## 小动物：自然弹跳 + 玩家推挤 + 夜间狂暴（19:00 ~ 6:00）

@export var hop_impulse: float = 2.0
@export var hop_up: float = 3.5
@export var min_hop_interval: float = 1.0
@export var max_hop_interval: float = 4.0

# ── 玩家推挤参数 ──
@export var push_impulse_min: float = 1.5
@export var push_impulse_max: float = 3.0
@export var player_speed_factor: float = 0.12
@export var push_cooldown: float = 0.25

# ── 夜间狂暴参数 ──
const NIGHT_AGGRO_RANGE: float = 8.0        # 夜间发现玩家的距离
const NIGHT_HOP_IMPULSE: float = 6.0        # 夜间跳跃水平冲量
const NIGHT_HOP_UP: float = 5.0             # 夜间跳跃垂直冲量
const NIGHT_LANDING_RANGE: float = 2.0      # 落地攻击判定半径
const NIGHT_LANDING_DAMAGE: float = 8.0     # 落地攻击伤害
const NIGHT_START_HOUR: float = 19.0
const NIGHT_END_HOUR: float = 6.0

@export var world_boundary: float = 49.0
@export var max_linear_velocity: float = 20.0

const PUSH_DISTANCE: float = 0.6

var _body: RigidBody3D
var _hop_timer: float = 0.0
var _next_hop: float = 2.0
var _push_cooldown_left: float = 0.0
var _day_night: Node
var _night_attacking: bool = false


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	_next_hop = randf_range(min_hop_interval, max_hop_interval)
	if _body:
		_body.axis_lock_angular_x = true
		_body.axis_lock_angular_z = true
	# 查找昼夜系统
	var dns := get_tree().get_nodes_in_group("day_night_system")
	if not dns.is_empty():
		_day_night = dns[0]


func _physics_process(delta: float) -> void:
	if not _body:
		return

	if _push_cooldown_left > 0.0:
		_push_cooldown_left -= delta

	_check_player_push()
	_clamp_to_world()
	_cap_velocity()

	# 弹跳计时（夜间间隔减半）
	var interval_mult: float = 0.5 if _is_night() else 1.0
	_hop_timer += delta
	if _hop_timer >= _next_hop * interval_mult:
		_hop_timer = 0.0
		_next_hop = randf_range(min_hop_interval, max_hop_interval)
		_do_hop()


func _is_night() -> bool:
	if not _day_night:
		var dns := get_tree().get_nodes_in_group("day_night_system")
		if not dns.is_empty():
			_day_night = dns[0]
	if not _day_night:
		return false
	var hours: float = _day_night.get_time_hours()
	if NIGHT_START_HOUR > NIGHT_END_HOUR:
		return hours >= NIGHT_START_HOUR or hours < NIGHT_END_HOUR
	return hours >= NIGHT_START_HOUR and hours < NIGHT_END_HOUR


func _get_player() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as CharacterBody3D


func _do_hop() -> void:
	var dir: Vector3
	var is_night_attack := false

	if _is_night():
		var player := _get_player()
		if player and _body.global_position.distance_to(player.global_position) <= NIGHT_AGGRO_RANGE:
			# 夜间：跳向玩家
			dir = player.global_position - _body.global_position
			dir.y = 0.0
			if dir.length_squared() < 0.01:
				dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			dir = dir.normalized()
			is_night_attack = true
			_night_attacking = true
		else:
			dir = _random_dir()
	else:
		dir = _random_dir()

	var model := _body.get_node_or_null("Model") as Node3D
	if model:
		var target_pos := model.global_position + dir
		var saved_y := model.rotation.y
		model.look_at(target_pos, Vector3.UP, true)
		var target_y := model.rotation.y
		model.rotation.y = saved_y

		var tween := create_tween()
		tween.tween_property(model, "rotation:y", target_y, 0.15)
		tween.tween_callback(_apply_hop.bind(dir, is_night_attack))
	else:
		_apply_hop(dir, is_night_attack)


func _random_dir() -> Vector3:
	var angle := randf_range(0.0, TAU)
	return Vector3(cos(angle), 0, sin(angle))


func _apply_hop(dir: Vector3, is_night_attack: bool) -> void:
	if is_night_attack:
		_body.apply_central_impulse(dir * NIGHT_HOP_IMPULSE + Vector3.UP * NIGHT_HOP_UP)
		# 落地后检测攻击
		get_tree().create_timer(0.6).timeout.connect(_check_landing_attack)
	else:
		_body.apply_central_impulse(dir * hop_impulse + Vector3.UP * hop_up)


func _check_landing_attack() -> void:
	if not _night_attacking:
		return
	_night_attacking = false

	var player := _get_player()
	if not player:
		return

	var dist := _body.global_position.distance_to(player.global_position)
	if dist > NIGHT_LANDING_RANGE:
		return

	# 对玩家造成伤害
	var health: Health = player.get_health() as Health
	if health:
		health.take_damage(NIGHT_LANDING_DAMAGE, _body.global_position)


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
	if pos.y < -10.0:
		pos.y = 2.0
		_body.linear_velocity = Vector3.ZERO
		clamped = true

	if clamped:
		_body.global_position = pos


# ── 速度限制 ──

func _cap_velocity() -> void:
	var vel := _body.linear_velocity
	var h_speed := Vector2(vel.x, vel.z).length()
	if h_speed > max_linear_velocity:
		var ratio := max_linear_velocity / h_speed
		_body.linear_velocity = Vector3(vel.x * ratio, vel.y, vel.z * ratio)


# ── 玩家推挤 ──

func _check_player_push() -> void:
	if _push_cooldown_left > 0.0:
		return

	var player := _get_player()
	if not player:
		return

	var dist: float = _body.global_position.distance_to(player.global_position)
	if dist > PUSH_DISTANCE:
		return

	var away: Vector3 = _body.global_position - player.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	away = away.normalized()

	var ratio: float = 1.0 - dist / PUSH_DISTANCE
	var player_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var speed_bonus: float = player_speed * player_speed_factor

	var impulse_mag: float = clampf(
		push_impulse_min + speed_bonus * ratio,
		push_impulse_min,
		push_impulse_max
	)

	_body.apply_central_impulse(away * impulse_mag + Vector3.UP * impulse_mag * 0.15)
	_push_cooldown_left = push_cooldown

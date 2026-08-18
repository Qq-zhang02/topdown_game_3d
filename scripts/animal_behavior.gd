extends Node
class_name AnimalBehavior
## 小动物行为：
## - 白天：随机播放内置动画（idle/dance/eat/gesture/static），普通移动使用 walk 动画
## - 夜间：玩家进入警戒范围后进入狂暴状态，使用 run 动画追击；
##   追到近距离后恢复原来的跳跃攻击（起跳冲量 + 落地范围伤害）

# ── 白天随机行为参数 ──
@export var walk_speed: float = 1.5            # 白天散步速度（m/s）
@export var min_walk_duration: float = 1.5     # 最短散步时长
@export var max_walk_duration: float = 4.0     # 最长散步时长
@export var day_walk_chance: float = 0.45      # 停止后选择去散步的概率
@export var min_action_interval: float = 1.5   # 静止动作最短保持时长
@export var max_action_interval: float = 4.0   # 静止动作最长保持时长
@export var turn_speed: float = 12.0           # 朝向转动速度

# ── 玩家推挤参数 ──
@export var push_impulse_min: float = 1.5
@export var push_impulse_max: float = 4.5
@export var player_speed_factor: float = 10
@export var push_cooldown: float = 0.25

# ── 夜间狂暴参数 ──
const NIGHT_AGGRO_RANGE: float = 6.0            # 夜间发现玩家的距离
const NIGHT_AGGRO_LOSE_RANGE: float = 10.0      # 丢失玩家的距离
const NIGHT_JUMP_RANGE: float = 3.0             # 进入跳跃攻击的近距离
const NIGHT_HOP_IMPULSE: float = 6.0            # 夜间跳跃水平冲量（原跳跃攻击）
const NIGHT_HOP_UP: float = 5.0                 # 夜间跳跃垂直冲量
const NIGHT_LANDING_RANGE: float = 1.0          # 落地攻击判定半径
const NIGHT_LANDING_DAMAGE: float = 5.0         # 落地攻击伤害
const NIGHT_JUMP_COOLDOWN: float = 1.5          # 两次跳跃攻击的间隔
const NIGHT_START_HOUR: float = 19.0
const NIGHT_END_HOUR: float = 6.0

@export var post_attack_pause: float = 1.0      # 发动一次攻击后原地停留的时间（秒）
@export var night_run_speed: float = 5.0        # 夜间狂暴追击速度（略快于玩家）
@export var world_boundary: float = 49.0
@export var max_linear_velocity: float = 20.0

const PUSH_DISTANCE: float = 0.6
const TURN_READY_ANGLE: float = deg_to_rad(8.0)  # 朝向误差小于该角度后才开始移动
const JUMP_WINDUP_MAX: float = 0.6               # 起跳前最多转向时间（转到目标方向即可提前起跳）
const LANDING_CHECK_DELAY: float = 0.6           # 起跳后多久判定落地伤害

enum State { DAY_ACTION, DAY_WALK, NIGHT_CHASE, NIGHT_JUMP, NIGHT_PAUSE }

const DAY_ACTION_KEYS: Array[String] = [
	"idle", "dance", "eat", "gesture-negative", "gesture-positive", "static",
]
const LOOPING_ANIM_KEYS: Array[String] = ["idle", "walk", "run"]

var _body: RigidBody3D
var _model: Node3D
var _anim_player: AnimationPlayer
var _anim_map: Dictionary = {}  # 逻辑名（idle/walk/run/...）→ GLB 实际动画名
var _playing_key: String = ""
var _day_night: Node

var _state: int = State.DAY_ACTION
var _state_elapsed: float = 0.0
var _state_time_left: float = 0.0
var _turn_ready: bool = false
var _walk_dir: Vector3 = Vector3.FORWARD
var _walk_speed: float = 1.5
var _walk_stuck_time: float = 0.0
var _last_walk_pos: Vector3 = Vector3.ZERO

var _aggroed: bool = false
var _night_attacking: bool = false
var _jump_cooldown_left: float = 0.0
var _post_attack_pause_left: float = 0.0
var _jump_windup_left: float = 0.0
var _jump_dir: Vector3 = Vector3.FORWARD
var _landing_check_left: float = -1.0

var _push_cooldown_left: float = 0.0


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	if _body:
		# 朝向完全由 Model 子节点控制，锁定刚体自身全部旋转，避免走路/碰撞时身体乱转
		_body.axis_lock_angular_x = true
		_body.axis_lock_angular_y = true
		_body.axis_lock_angular_z = true

	_find_day_night()
	_setup_animations()
	_enter_state(State.DAY_ACTION)


func _physics_process(delta: float) -> void:
	if not _body:
		return

	if _push_cooldown_left > 0.0:
		_push_cooldown_left -= delta

	_update_state(delta)
	_check_player_push()
	_clamp_to_world()
	_cap_velocity()


# ═══════════════════════════════════════════
# 动画系统（根据 GLB 内置动画自动映射）
# ═══════════════════════════════════════════

func _setup_animations() -> void:
	if not _body:
		return
	_model = _body.get_node_or_null("Model") as Node3D
	if not _model:
		return
	_anim_player = _model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not _anim_player:
		return

	var anim_list := _anim_player.get_animation_list()
	for anim_name in anim_list:
		var lower := anim_name.to_lower()
		if lower == "idle":
			_anim_map["idle"] = anim_name
		elif lower == "walk":
			_anim_map["walk"] = anim_name
		elif lower == "run":
			_anim_map["run"] = anim_name
		elif lower == "dance":
			_anim_map["dance"] = anim_name
		elif lower == "eat":
			_anim_map["eat"] = anim_name
		elif lower == "gesture-negative":
			_anim_map["gesture-negative"] = anim_name
		elif lower == "gesture-positive":
			_anim_map["gesture-positive"] = anim_name
		elif lower == "static":
			_anim_map["static"] = anim_name

	# 兜底：动画名不完全是上述名字时，按关键字匹配
	for key in ["idle", "walk", "run", "dance", "eat", "gesture-negative", "gesture-positive", "static"]:
		if _anim_map.has(key):
			continue
		for anim_name in anim_list:
			if key in anim_name.to_lower():
				_anim_map[key] = anim_name
				break

	# walk/run/idle 循环播放；其余动作一次性播放
	for key in _anim_map:
		var anim := _anim_player.get_animation(_anim_map[key])
		if not anim:
			continue
		if key in LOOPING_ANIM_KEYS:
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE

	if not _anim_player.animation_finished.is_connected(_on_animation_finished):
		_anim_player.animation_finished.connect(_on_animation_finished)

	print("[AnimalBehavior] %s 动画: %s" % [_body.name, anim_list])


func _play_animation(key: String, restart: bool = false) -> void:
	if not _anim_player or not _anim_map.has(key):
		return
	var anim_name: String = _anim_map[key]
	if restart or _anim_player.current_animation != anim_name or not _anim_player.is_playing():
		_anim_player.stop()
		_anim_player.play(anim_name, 0.15)
	_playing_key = key


func _on_animation_finished(anim_name: StringName) -> void:
	# 白天一次性动作播放完后，回到 idle 等待下一次随机选择
	if _state != State.DAY_ACTION:
		return
	if _playing_key.is_empty() or _playing_key == "idle":
		return
	if not _anim_map.has(_playing_key) or _anim_map[_playing_key] != anim_name:
		return
	_play_animation("idle", true)


func _pick_day_action() -> String:
	var available: Array[String] = []
	for key in DAY_ACTION_KEYS:
		if _anim_map.has(key):
			available.append(key)
	if available.is_empty():
		return ""

	# 提高 idle 权重，避免动作切换太吵
	if available.has("idle") and randf() < 0.4:
		return "idle"
	return available[randi_range(0, available.size() - 1)]


# ═══════════════════════════════════════════
# 状态机
# ═══════════════════════════════════════════

func _enter_state(new_state: int) -> void:
	_state = new_state
	_state_elapsed = 0.0
	_state_time_left = 0.0
	_turn_ready = false
	_walk_stuck_time = 0.0
	_stop_horizontal_movement()

	match new_state:
		State.DAY_ACTION:
			_state_time_left = randf_range(min_action_interval, max_action_interval)
			var action := _pick_day_action()
			if not action.is_empty():
				_play_animation(action, true)

		State.DAY_WALK:
			if not _anim_map.has("walk"):
				_enter_state(State.DAY_ACTION)
				return
			_walk_dir = _random_dir()
			_walk_speed = walk_speed * randf_range(0.7, 1.3)
			_last_walk_pos = _body.global_position
			_state_time_left = randf_range(min_walk_duration, max_walk_duration)
			_play_animation("walk", true)

		State.NIGHT_CHASE:
			if _anim_map.has("run"):
				_play_animation("run", true)
			elif _anim_map.has("walk"):
				_play_animation("walk", true)

		State.NIGHT_JUMP:
			var player := _get_living_player()
			if not player:
				_aggroed = false
				_enter_state(State.DAY_ACTION)
				return
			_jump_dir = player.global_position - _body.global_position
			_jump_dir.y = 0.0
			if _jump_dir.length_squared() < 0.01:
				_jump_dir = _random_dir()
			else:
				_jump_dir = _jump_dir.normalized()
			_jump_windup_left = JUMP_WINDUP_MAX
			_landing_check_left = -1.0
			# 跳跃过程没有独立动画，继续使用 run 保持狂暴感
			if _anim_map.has("run"):
				_play_animation("run", true)

		State.NIGHT_PAUSE:
			# 攻击后原地停留，回到待机动画
			if _anim_map.has("idle"):
				_play_animation("idle", true)


func _update_state(delta: float) -> void:
	_state_elapsed += delta
	if _jump_cooldown_left > 0.0:
		_jump_cooldown_left -= delta
	if _post_attack_pause_left > 0.0:
		_post_attack_pause_left -= delta

	_update_aggro()

	match _state:
		State.DAY_ACTION:
			_update_day_action(delta)
		State.DAY_WALK:
			_update_day_walk(delta)
		State.NIGHT_CHASE:
			_update_night_chase(delta)
		State.NIGHT_JUMP:
			_update_night_jump(delta)
		State.NIGHT_PAUSE:
			_update_night_pause(delta)


func _update_aggro() -> void:
	var player := _get_living_player()
	var night := _is_night()

	if not night or not player:
		_aggroed = false
	elif not _aggroed:
		_aggroed = _body.global_position.distance_to(player.global_position) <= NIGHT_AGGRO_RANGE
	else:
		_aggroed = _body.global_position.distance_to(player.global_position) <= NIGHT_AGGRO_LOSE_RANGE

	if _aggroed:
		if _state == State.DAY_ACTION or _state == State.DAY_WALK:
			_enter_state(State.NIGHT_CHASE)
	elif _state == State.NIGHT_CHASE:
		_enter_state(State.DAY_ACTION)


func _update_day_action(delta: float) -> void:
	_state_time_left -= delta
	if _state_time_left > 0.0:
		return

	if _anim_map.has("walk") and randf() < day_walk_chance:
		_enter_state(State.DAY_WALK)
	else:
		_enter_state(State.DAY_ACTION)


func _update_day_walk(delta: float) -> void:
	# 先原地转向移动方向，转好后才开始走动
	if not _turn_ready:
		if _turn_towards(_walk_dir, delta):
			_turn_ready = true
			_state_elapsed = 0.0
			_last_walk_pos = _body.global_position
			_walk_stuck_time = 0.0
		else:
			return

	_face_direction(_walk_dir, delta)
	_move_body_horizontal(_walk_dir, _walk_speed)

	# 撞到障碍物时换一个方向继续散步
	var moved: float = Vector2(
		_body.global_position.x - _last_walk_pos.x,
		_body.global_position.z - _last_walk_pos.z
	).length()
	_last_walk_pos = _body.global_position
	if _state_elapsed > 0.4:
		if moved < _walk_speed * delta * 0.25:
			_walk_stuck_time += delta
			if _walk_stuck_time > 0.6:
				_walk_dir = _random_dir()
				_walk_stuck_time = 0.0
				_turn_ready = false  # 换方向后先原地转好，避免边旋转边走路
		else:
			_walk_stuck_time = 0.0

	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_enter_state(State.DAY_ACTION)


func _update_night_chase(delta: float) -> void:
	var player := _get_living_player()
	if not player:
		_aggroed = false
		_enter_state(State.DAY_ACTION)
		return

	var to_player := player.global_position - _body.global_position
	to_player.y = 0.0

	# 先原地转向玩家，转好后才开始 run 追击
	if not _turn_ready:
		if _turn_towards(to_player, delta):
			_turn_ready = true
		else:
			return

	var dist := to_player.length()

	if dist <= NIGHT_JUMP_RANGE and _jump_cooldown_left <= 0.0:
		_enter_state(State.NIGHT_JUMP)
		return

	if dist > 0.001:
		var dir := to_player / dist
		_face_direction(dir, delta)
		_move_body_horizontal(dir, night_run_speed)


func _update_night_jump(delta: float) -> void:
	# 起跳前先原地转向玩家，转到目标方向后起跳（最多等 JUMP_WINDUP_MAX 秒）
	if _jump_windup_left > 0.0:
		_jump_windup_left -= delta
		var aligned := _turn_towards(_jump_dir, delta)
		if _jump_windup_left <= 0.0 or aligned:
			_jump_windup_left = 0.0
			if not _aggroed:
				_enter_state(State.DAY_ACTION)
				return
			_body.apply_central_impulse(_jump_dir * NIGHT_HOP_IMPULSE + Vector3.UP * NIGHT_HOP_UP)
			_night_attacking = true
			_landing_check_left = LANDING_CHECK_DELAY
		return

	if _landing_check_left > 0.0:
		_landing_check_left -= delta
		if _landing_check_left <= 0.0:
			_finish_jump_attack()


func _update_night_pause(_delta: float) -> void:
	# 攻击后原地停留：倒计时结束前不移动
	if _post_attack_pause_left > 0.0:
		return

	var player := _get_living_player()
	if _is_night() and player and _body.global_position.distance_to(player.global_position) <= NIGHT_AGGRO_LOSE_RANGE:
		_aggroed = true
		_enter_state(State.NIGHT_CHASE)
	else:
		_aggroed = false
		_enter_state(State.DAY_ACTION)


func _finish_jump_attack() -> void:
	_check_landing_attack()
	_jump_cooldown_left = NIGHT_JUMP_COOLDOWN
	_post_attack_pause_left = post_attack_pause

	# 攻击结束后先原地停留，停留结束再决定是否继续追击
	var player := _get_living_player()
	if _is_night() and player and _body.global_position.distance_to(player.global_position) <= NIGHT_AGGRO_LOSE_RANGE:
		_aggroed = true
	else:
		_aggroed = false
	_enter_state(State.NIGHT_PAUSE)


# ═══════════════════════════════════════════
# 移动 / 朝向
# ═══════════════════════════════════════════

func _move_body_horizontal(dir: Vector3, speed: float) -> void:
	var vel := _body.linear_velocity
	vel.x = dir.x * speed
	vel.z = dir.z * speed
	_body.linear_velocity = vel


func _stop_horizontal_movement() -> void:
	if not _body:
		return
	var vel := _body.linear_velocity
	vel.x = 0.0
	vel.z = 0.0
	_body.linear_velocity = vel


func _face_direction(dir: Vector3, delta: float) -> void:
	_turn_towards(dir, delta)


## 原地转向 dir：朝向误差小于 TURN_READY_ANGLE 时返回 true（表示可以开始移动）
## 动物模型的前方是 +Z（经模型顶点分布确认），因此用 atan2(dir.x, dir.z) 计算目标 yaw
func _turn_towards(dir: Vector3, delta: float) -> bool:
	if not _model or dir.length_squared() < 0.001:
		return true

	var target_yaw := atan2(dir.x, dir.z)
	var diff := angle_difference(_model.rotation.y, target_yaw)
	if absf(diff) <= TURN_READY_ANGLE:
		_model.rotation.y = target_yaw
		return true

	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, minf(1.0, turn_speed * delta))
	return false


func _random_dir() -> Vector3:
	var angle := randf_range(0.0, TAU)
	return Vector3(cos(angle), 0, sin(angle))


# ═══════════════════════════════════════════
# 昼夜 / 玩家
# ═══════════════════════════════════════════

func _find_day_night() -> void:
	var dns := get_tree().get_nodes_in_group("day_night_system")
	if not dns.is_empty():
		_day_night = dns[0]


func _is_night() -> bool:
	if not _day_night:
		_find_day_night()
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


func _get_living_player() -> CharacterBody3D:
	var player := _get_player()
	if not player:
		return null
	if player.has_method("is_dead") and player.is_dead():
		return null
	return player


# ═══════════════════════════════════════════
# 跳跃攻击（沿用原来的判定）
# ═══════════════════════════════════════════

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

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
@export var day_walk_chance: float = 0.6      # 停止后选择去散步的概率
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
const NIGHT_LANDING_DAMAGE: float = 1.0         # 落地攻击伤害
const NIGHT_JUMP_COOLDOWN: float = 1.5          # 两次跳跃攻击的间隔
const NIGHT_START_HOUR: float = 19.0
const NIGHT_END_HOUR: float = 6.0

@export var post_attack_pause: float = 1.0      # 发动一次攻击后原地停留的时间（秒）
@export var lava_sink_speed: float = 1.0        # 掉进岩浆后的下沉速度（与玩家一致）
@export var night_run_speed: float = 5.0        # 夜间狂暴追击速度（略快于玩家）
@export var world_boundary: float = 49.0
@export var max_linear_velocity: float = 20.0

const PUSH_DISTANCE: float = 0.6
const TURN_READY_ANGLE: float = deg_to_rad(8.0)  # 朝向误差小于该角度后才开始移动
const JUMP_WINDUP_MAX: float = 0.6               # 起跳前最多转向时间（转到目标方向即可提前起跳）
const LANDING_CHECK_DELAY: float = 0.6           # 起跳后多久判定落地伤害
const TERRAIN_QUERY_LAYER: int = 1 << 3          # 与 world_3d.gd 中地形专用射线层一致
const LAVA_ENTER_Y: float = 0.0                  # 动物掉到该高度且下方无地形时开始挣扎
const LAVA_STRUGGLE_TIME: float = 1.0            # 挣扎动画持续时间
const LAVA_DISAPPEAR_Y: float = -5.0              # 兜底：掉进岩浆下方该高度后动物消失
const BOUNDARY_LOOKAHEAD: float = 1.2             # 边界移动统一前瞻距离

enum State { DAY_ACTION, DAY_WALK, NIGHT_CHASE, NIGHT_JUMP, NIGHT_PAUSE, NIGHT_BLOCKED }

const DAY_ACTION_KEYS: Array[String] = [
	"idle", "dance", "eat", "gesture-negative", "gesture-positive", "static",
]
const LOOPING_ANIM_KEYS: Array[String] = ["idle", "walk", "run"]

var _body: RigidBody3D
var _model: Node3D
var _anim_player: AnimationPlayer
var _anim_map: Dictionary = {}  # 逻辑名（idle/walk/run/...）→ GLB 实际动画名
var _playing_key: String = ""
var _day_action_key: String = ""
var _day_action_repeats_left: int = 0
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
var _dying_in_lava: bool = false
var _lava_struggle_left: float = 0.0
var _lava_struggle_anim: String = ""

# 地形径向边界（由生成器传入，空则回退方形世界边界）
@export var terrain_boundary: Array[float] = []
@export var terrain_center: Vector2 = Vector2.ZERO


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

	# 掉进岩浆后的挣扎阶段：以固定速度缓慢下沉，倒计时结束后消失
	if _dying_in_lava:
		var vel := _body.linear_velocity
		vel.y = -lava_sink_speed
		_body.linear_velocity = vel
		_lava_struggle_left -= delta
		if _lava_struggle_left <= 0.0:
			_body.queue_free()
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
	# 挣扎阶段选了 gesture-negative：1 秒内循环重播
	if _dying_in_lava:
		if _lava_struggle_anim == "gesture-negative" and _anim_map.has("gesture-negative") and _anim_map["gesture-negative"] == anim_name:
			_play_animation("gesture-negative", true)
		return

	# 白天随机动作：一次性动作连续随机播放 2~3 次，再回到 idle 持续播放
	if _state != State.DAY_ACTION:
		return
	if _day_action_key.is_empty() or _day_action_key == "idle":
		return
	if not _anim_map.has(_day_action_key) or _anim_map[_day_action_key] != anim_name:
		return

	if _day_action_repeats_left > 1:
		_day_action_repeats_left -= 1
		_play_animation(_day_action_key, true)
	else:
		_day_action_key = "idle"
		_day_action_repeats_left = 0
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
	_day_action_key = ""
	_day_action_repeats_left = 0
	_stop_horizontal_movement()

	match new_state:
		State.DAY_ACTION:
			_state_time_left = randf_range(min_action_interval, max_action_interval)
			var action := _pick_day_action()
			if not action.is_empty():
				_day_action_key = action
				if action != "idle":
					# 一次性动作连续播放 2~3 次，播完再回到 idle
					_day_action_repeats_left = randi_range(2, 3)
				_play_animation(action, true)

		State.DAY_WALK:
			if not _anim_map.has("walk"):
				_enter_state(State.DAY_ACTION)
				return
			_walk_dir = _pick_safe_direction(_body.global_position, _random_dir())
			if _walk_dir == Vector3.ZERO:
				_enter_state(State.DAY_ACTION)
				return
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

		State.NIGHT_BLOCKED:
			# 追到地形边界但下一步会出岛：原地等待，不再持续播放 run
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
		State.NIGHT_BLOCKED:
			_update_night_blocked(delta)


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
	elif _state == State.NIGHT_CHASE or _state == State.NIGHT_BLOCKED:
		_enter_state(State.DAY_ACTION)


func _update_day_action(delta: float) -> void:
	# 一次性随机动作还在重复播放时先不走计时，保证完整播放 2~3 次；
	# 播放完切回 idle 后，idle 再持续播放一段时间
	if not _day_action_key.is_empty() and _day_action_key != "idle":
		return

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

	# 统一边界判定：动物被击退出真实地形时不再接管水平移动，让岩浆逻辑处理
	if not _position_is_on_terrain(_body.global_position):
		_stop_horizontal_movement()
		return

	# 下一步不安全时，主动挑一个能走开的方向，而不是停在边界
	if not _is_direction_safe(_body.global_position, _walk_dir):
		var safe_dir := _pick_safe_direction(_body.global_position, _walk_dir)
		if safe_dir == Vector3.ZERO:
			_enter_state(State.DAY_ACTION)
			return
		_walk_dir = safe_dir
		_turn_ready = false
		_walk_stuck_time = 0.0
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
				var safe_dir := _pick_safe_direction(_body.global_position, _random_dir())
				if safe_dir == Vector3.ZERO:
					_enter_state(State.DAY_ACTION)
					return
				_walk_dir = safe_dir
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
		# 统一边界判定：已被击退出真实地形时停止 run，让动物掉落消失
		if not _position_is_on_terrain(_body.global_position):
			_stop_horizontal_movement()
			return
		if not _is_direction_safe(_body.global_position, dir):
			# 追到边界外会掉岩浆：切到边界等待/绕行状态，避免一直播放 run 原地踏步
			_enter_state(State.NIGHT_BLOCKED)
			return
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


func _update_night_blocked(delta: float) -> void:
	var player := _get_living_player()
	if not player:
		_aggroed = false
		_enter_state(State.DAY_ACTION)
		return

	var pos := _body.global_position
	if not _position_is_on_terrain(pos):
		# 已被击退出真实地形：交给统一的岩浆消失逻辑，不再移动
		_stop_horizontal_movement()
		return

	var to_player := player.global_position - pos
	to_player.y = 0.0
	var dist := to_player.length()

	if dist <= NIGHT_JUMP_RANGE and _jump_cooldown_left <= 0.0:
		_enter_state(State.NIGHT_JUMP)
		return

	if dist > 0.001:
		var dir := to_player / dist
		if dist > NIGHT_JUMP_RANGE and _is_direction_safe(pos, dir):
			_enter_state(State.NIGHT_CHASE)
			return

		# 直追不安全：尝试沿边界绕行/向岛内退一步，避免永远卡在边界
		var detour := _pick_safe_direction(pos, dir)
		if detour != Vector3.ZERO:
			_face_direction(detour, delta)
			_move_body_horizontal(detour, night_run_speed * 0.7)
			if _anim_map.has("walk"):
				_play_animation("walk")
		else:
			_face_direction(dir, delta)


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

func _terrain_radius_at(x: float, z: float) -> float:
	if terrain_boundary.is_empty():
		return world_boundary + 1.0
	var samples := float(terrain_boundary.size())
	var angle := atan2(z, x)
	var f := angle / TAU * samples
	if f < 0.0:
		f += samples
	var i0 := int(floor(f)) % terrain_boundary.size()
	var i1 := (i0 + 1) % terrain_boundary.size()
	var t: float = f - floor(f)
	return lerpf(terrain_boundary[i0], terrain_boundary[i1], t)


func _is_inside_terrain(pos: Vector3, margin: float = 0.0) -> bool:
	if terrain_boundary.is_empty():
		return abs(pos.x) <= world_boundary - margin and abs(pos.z) <= world_boundary - margin
	var dx := pos.x - terrain_center.x
	var dz := pos.z - terrain_center.y
	var r := sqrt(dx * dx + dz * dz)
	return r <= _terrain_radius_at(dx, dz) - margin


## 自主移动的目标位置是否安全（靠近边界时用真实地形射线确认）
func _next_step_is_safe(next_pos: Vector3) -> bool:
	if not _is_inside_terrain(next_pos, 0.0):
		return false
	var dx := next_pos.x - terrain_center.x
	var dz := next_pos.z - terrain_center.y
	var r := sqrt(dx * dx + dz * dz)
	if r <= _terrain_radius_at(dx, dz) - 2.0:
		return true
	return not is_nan(_terrain_height_at(next_pos.x, next_pos.z))


## 当前 XZ 位置是否真的站在地形上（所有状态共用的统一判定）
func _position_is_on_terrain(pos: Vector3) -> bool:
	if terrain_boundary.is_empty():
		return abs(pos.x) <= world_boundary and abs(pos.z) <= world_boundary
	var dx := pos.x - terrain_center.x
	var dz := pos.z - terrain_center.y
	var r := sqrt(dx * dx + dz * dz)
	if r <= _terrain_radius_at(dx, dz) - 2.0:
		return true
	return not is_nan(_terrain_height_at(pos.x, pos.z))


## 预判一个移动方向是否安全（统一前瞻距离）
func _is_direction_safe(pos: Vector3, dir: Vector3) -> bool:
	if dir.length_squared() < 0.001:
		return false
	return _next_step_is_safe(pos + dir * BOUNDARY_LOOKAHEAD)


## 在边界附近挑选一个可以继续走的方向；优先 preferred，其次朝岛内、沿边界、随机
func _pick_safe_direction(pos: Vector3, preferred: Vector3) -> Vector3:
	if preferred.length_squared() > 0.001 and _is_direction_safe(pos, preferred):
		return preferred.normalized()

	var inward := Vector2(terrain_center.x - pos.x, terrain_center.y - pos.z)
	var candidates: Array[Vector3] = []
	if inward.length_squared() > 0.01:
		candidates.append(Vector3(inward.x, 0.0, inward.y).normalized())
	if preferred.length_squared() > 0.001:
		var base := preferred.normalized()
		candidates.append(base.rotated(Vector3.UP, PI * 0.35))
		candidates.append(base.rotated(Vector3.UP, -PI * 0.35))
	for i in range(8):
		var angle := randf_range(0.0, TAU)
		candidates.append(Vector3(cos(angle), 0.0, sin(angle)))
	for dir in candidates:
		if _is_direction_safe(pos, dir):
			return dir.normalized()
	return Vector3.ZERO


## 地形射线：返回 XZ 处地形表面 Y；无地形返回 NAN
func _terrain_height_at(x: float, z: float) -> float:
	var space := _body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, 100.0, z),
		Vector3(x, -50.0, z)
	)
	query.collision_mask = TERRAIN_QUERY_LAYER
	var result := space.intersect_ray(query)
	if result.is_empty():
		return NAN
	return result.position.y


## 开始岩浆挣扎：随机播放 run 或 gesture-negative，以固定速度缓慢下沉，倒计时结束后消失
func _start_lava_struggle() -> void:
	_dying_in_lava = true
	_lava_struggle_left = LAVA_STRUGGLE_TIME
	_stop_horizontal_movement()

	# 与玩家掉入岩浆一致：关闭重力，按固定速度慢慢下沉
	_body.gravity_scale = 0.0
	var vel := _body.linear_velocity
	vel.y = -lava_sink_speed
	_body.linear_velocity = vel

	var has_run := _anim_map.has("run")
	var has_gesture := _anim_map.has("gesture-negative")
	if has_run and has_gesture:
		_lava_struggle_anim = "run" if randf() < 0.5 else "gesture-negative"
	elif has_run:
		_lava_struggle_anim = "run"
	elif has_gesture:
		_lava_struggle_anim = "gesture-negative"
	else:
		_lava_struggle_anim = "idle" if _anim_map.has("idle") else ""
	_play_animation(_lava_struggle_anim, true)


func _clamp_to_world() -> void:
	var pos := _body.global_position

	# 有地形边界时不再用方形边界拉回动物：动物可以被玩家击退到岛外并掉进岩浆
	if terrain_boundary.is_empty():
		var clamped := false
		if abs(pos.x) > world_boundary:
			pos.x = clampf(pos.x, -world_boundary, world_boundary)
			clamped = true
		if abs(pos.z) > world_boundary:
			pos.z = clampf(pos.z, -world_boundary, world_boundary)
			clamped = true
		if clamped:
			_body.global_position = pos

	# 掉进岩浆：下方没有真实地形，进入 1 秒挣扎动画，之后消失
	if pos.y < LAVA_ENTER_Y:
		var ground_y := _terrain_height_at(pos.x, pos.z)
		if is_nan(ground_y):
			_start_lava_struggle()
			return

	# 兜底：如果没触发挣扎但已掉到很深且无地形，直接消失
	if pos.y < LAVA_DISAPPEAR_Y:
		var ground_y := _terrain_height_at(pos.x, pos.z)
		if is_nan(ground_y):
			_body.queue_free()
			return

	# 有真实地形但动物卡到地形下方很深的位置时，抬回地面（防止模型不可见）
	if pos.y < -3.0:
		var ground_y := _terrain_height_at(pos.x, pos.z)
		if not is_nan(ground_y) and pos.y < ground_y - 3.0:
			_body.global_position = Vector3(pos.x, ground_y + 0.5, pos.z)
			_body.linear_velocity = Vector3.ZERO


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

extends Camera3D
class_name CameraFollow3D
## 俯视角摄像机：偏差驱动追踪 + 瞄准偏移

var target: Node3D

# ═══════════════════════════════════════════
# 基础
# ═══════════════════════════════════════════
const HEIGHT: float = 10.0               # 距地面高度（m）
const TILT_ANGLE: float = 52.0           # 默认俯角（度）

# ═══════════════════════════════════════════
# 位置追踪 — 有偏差才追，速度 = 最小值 + 距离 × 系数，无上限
# ═══════════════════════════════════════════
const POS_MIN_SPEED: float = 0.5         # 最小追速（m/s）
const POS_SPEED_FACTOR: float = 2.0      # 每 1m 偏移增加的追速（m/s/m）

# ═══════════════════════════════════════════
# 角度追踪 — 未对准才旋转，速度 = 最小值 + 角度差 × 系数，无上限
# ═══════════════════════════════════════════
const LOOK_ANGLE_RANGE: float = 4.0      # 俯角/偏航最大偏离（度）
const LOOK_MIN_SPEED: float = 0.3        # 最小旋转速度（度/s）
const LOOK_SPEED_FACTOR: float = 1.0     # 每 1° 偏差增加的转速（度/s/度）

# ═══════════════════════════════════════════
# 瞄准偏移 — 匀速向鼠标方向平移
# ═══════════════════════════════════════════
const AIM_SPEED: float = 8.0             # 瞄准偏移速度（m/s，匀速）
const AIM_RETURN_SPEED: float = 10.0     # 松开右键后偏移归位速度（m/s）

# ── 内部状态 ──
var _follow_pos := Vector3.ZERO
var _aim_offset := Vector3.ZERO
var _look_pitch: float = 0.0
var _look_yaw: float = 0.0
var _was_aiming: bool = false
var _aim_pitch: float = 0.0
var _aim_yaw: float = 0.0


func _ready() -> void:
	_look_pitch = deg_to_rad(-TILT_ANGLE)
	rotation = Vector3(_look_pitch, 0.0, 0.0)
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = 60.0


func _process(delta: float) -> void:
	if not target:
		return

	var tp: Vector3 = target.global_position
	var back_offset: Vector3 = Vector3(0, 0, HEIGHT * cos(deg_to_rad(TILT_ANGLE)))
	var aiming: bool = target.has_method("is_aiming") and target.is_aiming()

	# ── 瞄准偏移 ──
	if aiming:
		var target_aim := Vector3.ZERO
		if target.has_method("get_mouse_ground_position"):
			var mw: Vector3 = target.get_mouse_ground_position()
			var pg: Vector3 = Vector3(tp.x, 0.0, tp.z)
			var dm: Vector3 = mw - pg
			if dm.length() > 0.01:
				var vision: float = 5.0
				var v = target.get("vision_range")
				if v != null: vision = float(v)
				var r := clampf(dm.length() / (vision * 2.5), 0.0, 1.0)
				target_aim = dm.normalized() * vision * r
				target_aim.y = 0.0
		_aim_offset = _aim_offset.move_toward(target_aim, AIM_SPEED * delta)
	else:
		_aim_offset = _aim_offset.move_toward(Vector3.ZERO, AIM_RETURN_SPEED * delta)

	# ── 位置追踪 —— 瞄准时随 _aim_offset 匀速偏移，否则有偏差才追 ──
	var raw_pos := Vector3(tp.x + _aim_offset.x, tp.y + HEIGHT, tp.z + _aim_offset.z) + back_offset
	if _follow_pos == Vector3.ZERO:
		_follow_pos = raw_pos

	if aiming:
		# _aim_offset 已匀速移动，位置直贴，不额外加阻尼
		_follow_pos = raw_pos
	else:
		var pos_dist := _follow_pos.distance_to(raw_pos)
		if pos_dist > 0.001:
			var pos_speed := POS_MIN_SPEED + pos_dist * POS_SPEED_FACTOR
			_follow_pos = _follow_pos.move_toward(raw_pos, pos_speed * delta)
	global_position = _follow_pos

	# ── 角度追踪 —— 瞄准时锁定按下瞬间的角度，不追人物 ──
	var def_pitch := deg_to_rad(-TILT_ANGLE)
	var limit := deg_to_rad(LOOK_ANGLE_RANGE)

	if aiming:
		if not _was_aiming:
			_aim_pitch = _look_pitch
			_aim_yaw = _look_yaw
		var tp_pitch := _aim_pitch
		var tp_yaw := _aim_yaw
		var ad := absf(tp_pitch - _look_pitch) + absf(tp_yaw - _look_yaw)
		if ad > 0.0001:
			var asp := deg_to_rad(LOOK_MIN_SPEED) + ad * LOOK_SPEED_FACTOR
			_look_pitch = move_toward(_look_pitch, tp_pitch, asp * delta)
			_look_yaw = move_toward(_look_yaw, tp_yaw, asp * delta)
	else:
		var lt := tp + Vector3(0, 1.5, 0)
		var d := (lt - global_position).normalized()
		var tp_pitch := clampf(asin(d.y), def_pitch - limit, def_pitch + limit)
		var tp_yaw := clampf(-atan2(d.x, -d.z), -limit, limit)
		var ad := absf(tp_pitch - _look_pitch) + absf(tp_yaw - _look_yaw)
		if ad > 0.0001:
			var asp := deg_to_rad(LOOK_MIN_SPEED) + ad * LOOK_SPEED_FACTOR
			_look_pitch = move_toward(_look_pitch, tp_pitch, asp * delta)
			_look_yaw = move_toward(_look_yaw, tp_yaw, asp * delta)

	_was_aiming = aiming
	rotation = Vector3(_look_pitch, _look_yaw, 0.0)

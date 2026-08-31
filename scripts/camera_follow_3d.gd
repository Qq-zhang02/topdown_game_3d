extends Camera3D
class_name CameraFollow3D
## 俯视角摄像机：偏差驱动追踪 + 瞄准偏移

var target: Node3D

# ═══════════════════════════════════════════
# 基础
# ═══════════════════════════════════════════
const HEIGHT: float = 8.0               # 距地面高度（m）
const TILT_ANGLE: float = 52.0           # 默认俯角（度）

# ═══════════════════════════════════════════
# 位置追踪 — 有偏差才追，速度 = 最小值 + 距离 × 系数，无上限
# ═══════════════════════════════════════════
const POS_MIN_SPEED: float = 0.1         # 最小追速（m/s）
const POS_SPEED_FACTOR: float = 2.0      # 每 1m 偏移增加的追速（m/s/m）

# ═══════════════════════════════════════════
# 角度追踪 — 未对准才旋转，速度 = 最小值 + 角度差 × 系数，无上限
# ═══════════════════════════════════════════
const LOOK_ANGLE_RANGE: float = 4.0      # 俯角/偏航最大偏离（度）
const LOOK_MIN_SPEED: float = 0.2        # 最小旋转速度（度/s）
const LOOK_SPEED_FACTOR: float = 1.0     # 每 1° 偏差增加的转速（度/s/度）

# ═══════════════════════════════════════════
# 瞄准偏移 — 匀速向鼠标方向平移
# ═══════════════════════════════════════════
const AIM_SPEED: float = 8.0             # 瞄准偏移最大速度（m/s）
const AIM_RETURN_SPEED: float = 10.0     # 松开右键后偏移归位速度（m/s）
const AIM_ACCEL: float = 60.0            # 瞄准偏移加速度（m/s²），进入瞄准时平滑起步、不突跳

# ═══════════════════════════════════════════
# 视野旋转 — 左Ctrl 逆时针 / 左Alt 顺时针，每次 90°，绕目标平滑公转
# ═══════════════════════════════════════════
const VIEW_ROTATE_STEP: float = 90.0     # 每次旋转角度（度）
const VIEW_ROTATE_SPEED: float = 180.0   # 旋转速度（度/s），90° 约 0.5s
const ROTATE_TRACK_RATE: float = 20.0    # 旋转期间位置追踪增益（1/s），防止公转时人物甩出屏幕

# ── 内部状态 ──
var _follow_pos := Vector3.ZERO
var _aim_offset := Vector3.ZERO
var _look_pitch: float = 0.0
var _look_yaw: float = 0.0
var _was_aiming: bool = false
var _aim_pitch: float = 0.0
var _aim_yaw: float = 0.0
var _aim_speed: float = 0.0             # 当前瞄准偏移速度（由 AIM_ACCEL 平滑加速到 AIM_SPEED）
var _view_yaw: float = 0.0              # 当前视野偏航（度）
var _view_yaw_target: float = 0.0       # 目标视野偏航（度，按一次 ±90 累计）


func _ready() -> void:
	_look_pitch = deg_to_rad(-TILT_ANGLE)
	rotation = Vector3(_look_pitch, 0.0, 0.0)
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = 60.0


func _process(delta: float) -> void:
	if not target:
		return

	# ── 视野旋转（90° 步进，平滑过渡）──
	if Input.is_action_just_pressed("camera_rotate_left"):
		_view_yaw_target += VIEW_ROTATE_STEP
	if Input.is_action_just_pressed("camera_rotate_right"):
		_view_yaw_target -= VIEW_ROTATE_STEP
	_view_yaw = move_toward(_view_yaw, _view_yaw_target, VIEW_ROTATE_SPEED * delta)
	var view_rad := deg_to_rad(_view_yaw)
	var rotating := absf(_view_yaw_target - _view_yaw) > 0.01

	var tp: Vector3 = target.global_position
	var back_offset: Vector3 = Vector3(0, 0, HEIGHT * cos(deg_to_rad(TILT_ANGLE)))
	var aiming: bool = target.has_method("is_aiming") and target.is_aiming()
	# 原始按住状态（未过延迟也算按住）：延迟期间保持偏移、不归位
	var held: bool = target.has_method("is_aim_held") and target.is_aim_held()

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
		# 起步带加速度：进入瞄准瞬间平滑加速，不“咣”地一下弹出
		_aim_speed = minf(_aim_speed + AIM_ACCEL * delta, AIM_SPEED)
		_aim_offset = _aim_offset.move_toward(target_aim, _aim_speed * delta)
	elif held:
		# 已按住右键但未过瞄准延迟：保持当前偏移不动，避免“先归位再向鼠标移动”
		_aim_speed = 0.0
	else:
		_aim_speed = 0.0
		_aim_offset = _aim_offset.move_toward(Vector3.ZERO, AIM_RETURN_SPEED * delta)

	# ── 位置追踪 —— 瞄准时随 _aim_offset 偏移，否则有偏差才追；整个水平偏移随视野旋转绕目标公转 ──
	var horiz := (back_offset + Vector3(_aim_offset.x, 0.0, _aim_offset.z)).rotated(Vector3.UP, view_rad)
	var raw_pos := Vector3(tp.x, tp.y + HEIGHT, tp.z) + horiz
	if _follow_pos == Vector3.ZERO:
		_follow_pos = raw_pos

	if aiming:
		# 瞄准时：阻尼跟随（不低于偏移速度），避免模式切换瞬间位置跳动
		var pos_dist := _follow_pos.distance_to(raw_pos)
		if pos_dist > 0.001:
			var pos_speed := maxf(POS_MIN_SPEED + pos_dist * POS_SPEED_FACTOR, _aim_speed)
			if rotating:
				pos_speed = maxf(pos_speed, pos_dist * ROTATE_TRACK_RATE)
			_follow_pos = _follow_pos.move_toward(raw_pos, pos_speed * delta)
	else:
		var pos_dist := _follow_pos.distance_to(raw_pos)
		if pos_dist > 0.001:
			var pos_speed := POS_MIN_SPEED + pos_dist * POS_SPEED_FACTOR
			if rotating:
				pos_speed = maxf(pos_speed, pos_dist * ROTATE_TRACK_RATE)
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
		# 转到视野本地坐标系再求偏航：追踪围绕视野旋转角（而非固定的世界正南）
		var d_local := d.rotated(Vector3.UP, -view_rad)
		var tp_yaw := clampf(-atan2(d_local.x, -d_local.z), -limit, limit)
		var ad := absf(tp_pitch - _look_pitch) + absf(tp_yaw - _look_yaw)
		if ad > 0.0001:
			var asp := deg_to_rad(LOOK_MIN_SPEED) + ad * LOOK_SPEED_FACTOR
			_look_pitch = move_toward(_look_pitch, tp_pitch, asp * delta)
			_look_yaw = move_toward(_look_yaw, tp_yaw, asp * delta)

	_was_aiming = aiming
	rotation = Vector3(_look_pitch, _look_yaw + view_rad, 0.0)

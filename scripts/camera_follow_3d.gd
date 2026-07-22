extends Camera3D
class_name CameraFollow3D
## 俯视角摄像机：从斜上方跟随玩家，按住右键进入瞄准视角

var target: Node3D

const HEIGHT: float = 10.0             # 摄像机高度（地上）
const TILT_ANGLE: float = 52.0         # 俯视角度（度），值越小视角越倾斜
const AIM_ACCEL: float = 18.0          # 瞄准时速度加速度（越大启动越快）
const AIM_MAX_SPEED: float = 22.0      # 瞄准时最大移动速度
const AIM_INIT_SPEED: float = 1.0      # 瞄准初始速度
const AIM_RETURN_SPEED: float = 20.0   # 松开右键归位速度

var _aim_offset := Vector3.ZERO        # 当前瞄准偏移
var _aim_speed: float = 0.0            # 当前偏移速度（由慢到快）


func _ready() -> void:
	rotation_degrees = Vector3(-TILT_ANGLE, 0, 0)
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = 60.0


func _process(delta: float) -> void:
	if not target:
		return

	var tp: Vector3 = target.global_position
	var back_offset: Vector3 = Vector3(0, 0, HEIGHT * cos(deg_to_rad(TILT_ANGLE)))

	# ── 瞄准偏移（纯水平，速度由慢到快）──
	var target_aim := Vector3.ZERO
	if target.has_method("is_aiming") and target.is_aiming():
		if target.has_method("get_mouse_ground_position"):
			var mouse_world: Vector3 = target.get_mouse_ground_position()
			var player_ground: Vector3 = Vector3(tp.x, 0.0, tp.z)
			var delta_mouse: Vector3 = mouse_world - player_ground
			var mouse_dist: float = delta_mouse.length()
			if mouse_dist > 0.01:
				var vision: float = 5.0
				var v: Variant = target.get("vision_range")
				if v != null and typeof(v) in [TYPE_FLOAT, TYPE_INT]:
					vision = v
				var max_mouse := vision * 2.5
				var ratio := clampf(mouse_dist / max_mouse, 0.0, 1.0)
				target_aim = delta_mouse.normalized() * vision * ratio
				target_aim.y = 0.0

		# 由初始速度开始加速
		if _aim_speed < AIM_INIT_SPEED:
			_aim_speed = AIM_INIT_SPEED
		_aim_speed = minf(_aim_speed + AIM_ACCEL * delta, AIM_MAX_SPEED)
		_aim_offset = _aim_offset.move_toward(target_aim, _aim_speed * delta)
	else:
		# 松开右键：速度归零，平滑归位
		_aim_speed = 0.0
		_aim_offset = _aim_offset.move_toward(Vector3.ZERO, AIM_RETURN_SPEED * delta)

	_aim_offset.y = 0.0

	# 摄像机位置：基础位置 + XZ 偏移
	global_position = Vector3(tp.x + _aim_offset.x, tp.y + HEIGHT, tp.z + _aim_offset.z) + back_offset

	# look_at 目标同步偏移，保证摄像机仅平移不旋转
	var look_target := Vector3(tp.x + _aim_offset.x, tp.y + 1.0, tp.z + _aim_offset.z)
	look_at(look_target)

extends Node
class_name DayNightCycle
## 昼夜循环系统：24小时模拟，太阳/月亮/环境光渐变
##
## ★ 时间以「归一化进度 day_progress」记录（0.0~1.0），24h 制时钟由进度推导。
##   这样调整 seconds_per_day 改变一天总时长时，时钟显示与存档都自动保持正确。

const DAWN_HOUR: float = 6.0             # 6:00 黎明
const DUSK_HOUR: float = 18.0            # 18:00 黄昏

## ★ 一天（白天+夜晚）的真实秒数 —— 唯一的时长配置点，改这里即可
@export var seconds_per_day: float = 480.0  # 480 = 8分钟一天

## 归一化进度：0.0 = 0:00, 0.25 = 6:00, 0.5 = 12:00, 1.0 = 24:00
var day_progress: float = 0.25  # 从早上 6:00 开始

var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var environment: Environment


func _process(delta: float) -> void:
	if seconds_per_day > 0.0:
		day_progress = fmod(day_progress + delta / seconds_per_day, 1.0)

	_update_sun()
	_update_moon()
	_update_ambient()


## 24h 制时钟小时（0~24，由进度相对推导，与总时长无关）
func get_time_hours() -> float:
	return day_progress * 24.0


# ═══════════════════════════════════════════
# 太阳
# ═══════════════════════════════════════════

func _get_sun_elevation_angle() -> float:
	# 6:00=0°(地平线), 12:00=-90°(正头顶), 18:00=-180°(地平线), 24:00=-270°(地下)
	var hours: float = get_time_hours()
	return -(hours - DAWN_HOUR) * 15.0


func _get_sun_height_factor() -> float:
	# sin((hours-6)*15°): 6点=0, 12点=1, 18点=0
	var hours: float = get_time_hours()
	return max(0.0, sin(deg_to_rad((hours - DAWN_HOUR) * 15.0)))


func _update_sun() -> void:
	if not sun_light:
		return

	sun_light.rotation_degrees = Vector3(_get_sun_elevation_angle(), 30, 0)
	var height: float = _get_sun_height_factor()

	# 颜色：黎明/黄昏偏暖（橙），正午偏白
	var warmth: float = 1.0 - clamp(height * 3.0, 0.0, 1.0)  # 越高越不暖
	var sun_color: Color = Color.WHITE.lerp(Color(1.0, 0.55, 0.25), warmth)

	sun_light.light_color = sun_color
	sun_light.light_energy = height * 1.3
	sun_light.shadow_enabled = height > 0.03


# ═══════════════════════════════════════════
# 月亮
# ═══════════════════════════════════════════

func _update_moon() -> void:
	if not moon_light:
		return

	# 月亮在太阳对面
	var moon_angle: float = _get_sun_elevation_angle() + 180.0
	moon_light.rotation_degrees = Vector3(moon_angle, 210, 0)

	var moon_height: float = max(0.0, sin(deg_to_rad(moon_angle + 90.0)))

	# 柔和蓝白月光
	moon_light.light_color = Color(0.45, 0.55, 0.85)
	moon_light.light_energy = moon_height * 0.35
	moon_light.shadow_enabled = false


# ═══════════════════════════════════════════
# 环境光 + 天空
# ═══════════════════════════════════════════

func _update_ambient() -> void:
	if not environment:
		return

	var sun_h: float = _get_sun_height_factor()

	# 黄昏过渡（太阳低于 15° 时开始暖色渐变）
	var sun_angle: float = _get_sun_elevation_angle()
	var twilight_t: float = clamp((-sun_angle - 165.0) / 15.0, 0.0, 1.0) if sun_angle < -165 else 0.0
	var dawn_t: float = clamp((sun_angle + 15.0) / 15.0, 0.0, 1.0) if sun_angle > -15 else 0.0
	var twilight_blend: float = max(twilight_t, 1.0 - dawn_t)

	# 日间环境光 → 夜晚环境光
	var day_ambient := Color(0.45, 0.48, 0.55)
	var night_ambient := Color(0.06, 0.07, 0.16)
	var twilight_ambient := Color(0.35, 0.25, 0.30)  # 晨昏暖色

	var blend: float = clamp(sun_h, 0.08, 1.0)
	var ambient_color := night_ambient.lerp(day_ambient, blend)
	if twilight_blend > 0.0:
		ambient_color = ambient_color.lerp(twilight_ambient, twilight_blend * 0.6)

	environment.ambient_light_color = ambient_color
	environment.ambient_light_energy = lerpf(0.25, 1.0, blend)

	# 天空背景色
	var day_sky := Color(0.25, 0.45, 0.85)
	var night_sky := Color(0.02, 0.02, 0.08)
	environment.background_color = night_sky.lerp(day_sky, blend)

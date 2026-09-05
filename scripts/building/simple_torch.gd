extends Node
class_name SimpleTorchLogic
## 简易火把：放置即燃烧（小范围照明），站立燃烧 burn_duration_hours 游戏小时后燃尽。
## 被玩家/小动物碰到会翻倒（向远离碰撞者的方向），火焰数秒内缩小熄灭，
## 随后整支火把沉入地面消失（同时反注册占地，该位置可重新建造）。
## 站立期间触碰会受到一次伤害（危险区由 BuildingData.hazard_* 配置：触碰立即结算一次，
## 翻倒即关闭危险区，故只有一次伤害）。
## ★ 由 world_3d.place_building 挂载（BuildingData.logic_script）

const GROUP := "simple_torch"

# 木杆在预制体本地空间的布局（与 building_simple_torch.tscn 保持一致）
const STICK_BASE_Y := -0.475   # 杆底（触地点）
const STICK_CENTER_Y := -0.15  # 杆中心
const STICK_HEIGHT := 0.65     # 杆长

enum State { BURNING, FADING, GONE }

var _burn_hours: float = 4.0
var _burn_remaining: float = 4.0
var _state: int = State.BURNING

var _root: Node3D
var _day_night: Node
var _light: OmniLight3D
var _stick: MeshInstance3D
var _wrap: MeshInstance3D
var _flames: Array[MeshInstance3D] = []
var _flame_base_scale: Array[Vector3] = []
var _hazard: Area3D

var _light_energy: float = 2.2
var _flicker_t: float = 0.0
var _occupied_aabb := AABB()
var _base_offset_y: float = STICK_BASE_Y  # 触地点在本地空间的 Y（= AABB 最低点）
var _fall_pivot := Vector3.ZERO
var _fall_start_basis: Basis
var _fall_end_basis: Basis
var _ready: bool = false


func setup(data: Resource, _player: Node3D, day_night: Node, state: Dictionary = {}) -> void:
	add_to_group(GROUP)
	_day_night = day_night
	_root = get_parent() as Node3D

	_light = _root.get_node_or_null("Light") as OmniLight3D
	if _light:
		_light_energy = _light.light_energy
	_stick = _root.get_node_or_null("Stick") as MeshInstance3D
	_wrap = _root.get_node_or_null("Wrap") as MeshInstance3D
	for n in ["FlameOuter", "FlameInner"]:
		var f := _root.get_node_or_null(n) as MeshInstance3D
		if f:
			_flames.append(f)
			_flame_base_scale.append(f.scale)

	# 危险区：站立时开启，触碰翻倒后关闭（一次性伤害）
	_hazard = _root.get_node_or_null("Hazard") as Area3D
	if _hazard:
		_hazard.body_entered.connect(_on_body_touched)

	_burn_hours = float(data.get("burn_duration_hours"))
	if _burn_hours <= 0.0:
		_burn_hours = 4.0
	_burn_remaining = clampf(float(state.get("remaining_hours", _burn_hours)), 0.0, _burn_hours)

	# 记录放置时登记的占地（与 place_building 相同算法），消失时反注册
	_capture_occupied()

	# 触地点：整体 AABB 最低点（翻倒时的旋转轴心）
	# ★ _compute_aabb 对已入树节点返回全局 AABB，需减去放置高度换算回本地偏移
	var aabb := BuildingData._compute_aabb(_root)
	_base_offset_y = aabb.position.y - _root.position.y

	# 存档恢复：燃料耗尽的火把（旧档残留）直接进入燃尽流程
	if _burn_remaining <= 0.0:
		_burn_out.call_deferred()
	_update_burn_visuals()
	_ready = true


## 存档状态：{lit, remaining_hours}
func get_state() -> Dictionary:
	return {"lit": _state == State.BURNING, "remaining_hours": maxf(_burn_remaining, 0.0)}


func is_burning() -> bool:
	return _state == State.BURNING


func _process(delta: float) -> void:
	if not _ready or _state != State.BURNING:
		return

	# 用昼夜系统换算游戏小时推进速度（暂停/改一天时长都自动正确）
	var spd := 0.0
	if _day_night:
		var v: Variant = _day_night.get("seconds_per_day")
		if v != null:
			spd = float(v)
	if spd > 0.0:
		_burn_remaining -= delta * 24.0 / spd
	if _burn_remaining <= 0.0:
		_burn_out()
		return
	_update_burn_visuals()
	_flicker(delta)


## 被玩家/小动物碰到：立即翻倒（危险区已先结算一次伤害）
## ★ 与 hazard.gd 相同的受害者过滤：忽略自身碰撞体/地形等静态体，只有玩家和带 Health 的刚体有效
func _on_body_touched(body: Node3D) -> void:
	if not _ready or _state != State.BURNING or not (body is Node3D):
		return
	if not (body.is_in_group("player") or (body is RigidBody3D and body.get_node_or_null("Health") != null)):
		return
	_knock_over(body)


## 翻倒：向远离碰撞者的方向倒下，火焰逐渐变小熄灭，随后沉入地面消失
func _knock_over(body: Node3D) -> void:
	if _state != State.BURNING:
		return
	_state = State.FADING
	_disable_hazard()

	var dir := _fall_direction(body)
	var axis := Vector3.UP.cross(Vector3.FORWARD)
	if dir.length_squared() > 0.0001:
		axis = Vector3.UP.cross(dir.normalized())
	axis = axis.normalized()

	# 绕触地点（杆底）翻倒：倒下后木杆平躺，随后按地形贴地（坡地上杆梢下方地面更低）
	_fall_pivot = _root.global_transform * Vector3(0, _base_offset_y, 0)
	_fall_start_basis = _root.global_transform.basis
	_fall_end_basis = Basis(axis, deg_to_rad(88.0)) * _fall_start_basis
	var tw := create_tween()
	tw.tween_method(_apply_fall_step, 0.0, 1.0, 0.45)
	tw.tween_callback(_settle_on_ground)
	_fade_and_sink(2.2)


## 倒伏方向：始终倒向远离碰撞者的一侧（触碰发生在危险区盒边缘，远离侧即正确侧）
func _fall_direction(body: Node3D) -> Vector3:
	var dir := _root.global_position - body.global_position
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		return dir.normalized()
	return Vector3.FORWARD


## 翻倒插值：绕触地点旋转，保持杆底始终贴在地面
func _apply_fall_step(t: float) -> void:
	var basis := _fall_start_basis.slerp(_fall_end_basis, t).orthonormalized()
	_root.global_transform = Transform3D(basis, _fall_pivot - basis * Vector3(0, _base_offset_y, 0))


## 翻倒结束后按地形贴地：取杆底/杆梢两处地形较低者，把整支火把下移到搁在地面上
## （坡地上直杆会沿下坡方向悬空，必须整体下落）
func _settle_on_ground() -> void:
	var world := get_tree().current_scene
	if world == null or not world.has_method("get_terrain_height_at"):
		return
	var basis := _root.global_transform.basis
	var tip := _fall_pivot + basis * Vector3(0, STICK_HEIGHT, 0)
	var h_base: float = world.get_terrain_height_at(_fall_pivot.x, _fall_pivot.z)
	var h_tip: float = world.get_terrain_height_at(tip.x, tip.z)
	var target := minf(h_base, h_tip) + 0.1  # 抬高一点，避免火焰/光源被地面遮住
	var pos := _root.global_position
	pos.y += target - _fall_pivot.y
	_root.global_position = pos


## 燃尽（燃烧时间耗尽）：原地熄灭并消失
func _burn_out() -> void:
	if _state != State.BURNING:
		return
	_state = State.FADING
	_disable_hazard()
	_fade_and_sink(2.5)


func _disable_hazard() -> void:
	if _hazard:
		_hazard.set_deferred("monitoring", false)


## 火焰逐渐变小熄灭（灯光同步变暗），停顿后沉入地底并消失
func _fade_and_sink(flame_secs: float) -> void:
	var tw := create_tween()
	if _light:
		tw.parallel().tween_property(_light, "light_energy", 0.0, flame_secs)
	for i in _flames.size():
		tw.parallel().tween_property(_flames[i], "scale", Vector3.ONE * 0.05, flame_secs)
	tw.tween_interval(0.2)
	tw.tween_callback(_sink)


func _sink() -> void:
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN)
	# 下沉速度为常规的 1/3（距离不变、时长 ×3）
	tw.tween_property(_root, "position:y", _root.position.y - 2.2, 3.3)
	tw.tween_callback(_vanish)


## 消失：反注册占地（该位置可重新建造），移除整支火把
func _vanish() -> void:
	_state = State.GONE
	var world := get_tree().current_scene
	if world and world.has_method("unregister_occupied") and _occupied_aabb.size != Vector3.ZERO:
		world.unregister_occupied(_occupied_aabb)
	_root.queue_free()
	queue_free()


## 复现 place_building 的占地登记，确保消失时能按相同 AABB 反注册
func _capture_occupied() -> void:
	var bsize := BuildingData._compute_aabb_size(_root)
	if bsize == Vector3.ZERO:
		return
	var half := Vector2(bsize.x, bsize.z) * 0.5
	if int(round(rad_to_deg(_root.rotation.y))) % 180 != 0:
		half = Vector2(bsize.z, bsize.x) * 0.5
	_occupied_aabb = AABB(
		Vector3(_root.position.x - half.x, 0.0, _root.position.z - half.y),
		Vector3(half.x * 2.0, bsize.y, half.y * 2.0)
	)


## 燃烧消耗：木杆逐渐变短，绑扎/火焰/灯光跟随燃烧端下移（灯光始终高于火焰一段距离）
func _update_burn_visuals() -> void:
	var s := clampf(_burn_remaining / _burn_hours, 0.0, 1.0)
	if _stick:
		_stick.scale.y = s
		_stick.position.y = STICK_BASE_Y + (STICK_CENTER_Y - STICK_BASE_Y) * s
	var top := STICK_BASE_Y + STICK_HEIGHT * s
	if _wrap:
		_wrap.position.y = top - 0.07
	if _flames.size() > 0:
		_flames[0].position.y = top + 0.12
	if _flames.size() > 1:
		_flames[1].position.y = top + 0.08
	# 光源位于火焰尖端（火焰中心 +0.12，锥高 0.42 → 尖端 +0.33）
	if _light:
		_light.position.y = top + 0.33


## 火焰轻微抖动
func _flicker(delta: float) -> void:
	_flicker_t += delta
	if _light:
		_light.light_energy = _light_energy * (0.9 + 0.12 * (sin(_flicker_t * 10.0) * 0.5 + sin(_flicker_t * 21.0) * 0.5))
	for i in _flames.size():
		var s := 1.0 + 0.07 * sin(_flicker_t * 12.0 + float(i) * 1.3)
		_flames[i].scale = _flame_base_scale[i] * s

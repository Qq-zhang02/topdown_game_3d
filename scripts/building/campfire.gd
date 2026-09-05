extends Node
class_name CampfireLogic
## 篝火交互逻辑：刚放置只有石头，不发光；靠近按 E 消耗木材点燃（木柴+火焰出现），
## 木柴大小随燃料消耗逐渐变小；剩余燃料过半后可按 E 追加少量木柴把燃料补满；
## 燃尽熄灭后木柴消失，需重新按点燃价格加柴（循环）。
## ★ 由 world_3d.place_building 挂载（BuildingData.fuel_item_id 非空时）

const GROUP := "campfire"
const LOG_MIN_SCALE := 0.08  # 木柴最小缩放（避免 0 缩放，熄灭时直接隐藏）

var _fuel_item_id: String = "wood"
var _fuel_per_ignite: int = 3
var _fuel_per_refuel: int = 0
var _refuel_threshold: float = 0.5
var _burn_hours: float = 6.0
var _interaction_range: float = 2.6

var _player: Node3D
var _inventory: Node
var _day_night: Node

var _light: OmniLight3D
var _flame: Node3D
var _prompt: Label3D
var _hazard: Area3D
var _logs: Array[MeshInstance3D] = []

var _light_energy: float = 3.0
var _burning: bool = false
var _burn_remaining: float = 0.0   # 剩余燃烧时长（游戏小时）
var _flicker_t: float = 0.0
var _feedback_t: float = 0.0       # "木材不足" 红色提示剩余时长
var _feedback_amount: int = 0      # 上次尝试交互所需的木材数
var _prompt_base_y: float = 0.0
var _ready: bool = false


func setup(data: Resource, player: Node3D, day_night: Node, state: Dictionary = {}) -> void:
	add_to_group(GROUP)
	_player = player
	_inventory = player.get_inventory() if player and player.has_method("get_inventory") else null
	_day_night = day_night

	var fuel: Variant = data.get("fuel_item_id")
	_fuel_item_id = fuel if fuel != null else "wood"
	_fuel_per_ignite = int(data.get("fuel_per_ignite"))
	_fuel_per_refuel = int(data.get("fuel_per_refuel"))
	_refuel_threshold = float(data.get("refuel_threshold"))
	if _refuel_threshold <= 0.0:
		_refuel_threshold = 0.5
	_burn_hours = float(data.get("burn_duration_hours"))
	_interaction_range = float(data.get("interaction_range"))

	var bld := get_parent() as Node3D
	_light = bld.get_node_or_null("Light") as OmniLight3D
	_flame = bld.get_node_or_null("Flame")
	_prompt = bld.get_node_or_null("Prompt") as Label3D
	_hazard = bld.get_node_or_null("Hazard") as Area3D
	_logs.clear()
	for i in range(1, 4):
		var log_mesh := bld.get_node_or_null("Log%d" % i) as MeshInstance3D
		if log_mesh:
			_logs.append(log_mesh)
	if _light:
		_light_energy = float(data.get("light_energy"))
	if _prompt:
		_prompt_base_y = _prompt.position.y

	# 初始未点燃：只有石头，不发光 / 无火焰 / 无木柴 / 危险区关闭
	_apply_burning(false)

	# 存档恢复：以剩余时长继续燃烧（不重复扣材料）
	if bool(state.get("lit", false)):
		_burn_remaining = clampf(float(state.get("remaining_hours", _burn_hours)), 0.05, _burn_hours)
		_start_burning()
	_ready = true


## 存档状态：{lit, remaining_hours}
func get_state() -> Dictionary:
	return {"lit": _burning, "remaining_hours": _burn_remaining}


func is_burning() -> bool:
	return _burning


func _process(delta: float) -> void:
	if not _ready:
		return

	if _feedback_t > 0.0:
		_feedback_t = maxf(_feedback_t - delta, 0.0)

	if _burning:
		# 用昼夜系统换算游戏小时推进速度（暂停/改一天时长都自动正确）
		var spd: float = float(_day_night.get("seconds_per_day")) if _day_night else 0.0
		if spd > 0.0:
			_burn_remaining -= delta * 24.0 / spd
		if _burn_remaining <= 0.0:
			_extinguish()
		else:
			_flicker(delta)
			_update_logs_scale()

	_update_prompt()


## 燃烧中且剩余燃料降到阈值内时，允许追加燃料补满
func _refuel_allowed() -> bool:
	return _burning and _fuel_per_refuel > 0 and _burn_remaining <= _burn_hours * _refuel_threshold


## 按 E：未点燃 → 消耗 fuel_per_ignite 点燃；燃烧中且燃料过半 → 消耗 fuel_per_refuel 补满
func _try_ignite() -> void:
	if _burning:
		return
	var cost := {_fuel_item_id: _fuel_per_ignite}
	if _inventory == null or not _inventory.has_cost(cost):
		_feedback_t = 1.2
		_feedback_amount = _fuel_per_ignite
		return
	_inventory.consume_cost(cost)
	_burn_remaining = _burn_hours
	_start_burning()


func _try_refuel() -> void:
	if not _refuel_allowed():
		return
	var cost := {_fuel_item_id: _fuel_per_refuel}
	if _inventory == null or not _inventory.has_cost(cost):
		_feedback_t = 1.2
		_feedback_amount = _fuel_per_refuel
		return
	_inventory.consume_cost(cost)
	_burn_remaining = _burn_hours
	_update_logs_scale()


func _start_burning() -> void:
	_burning = true
	_flicker_t = 0.0
	_apply_burning(true)
	_update_logs_scale()


func _extinguish() -> void:
	_burning = false
	_burn_remaining = 0.0
	_apply_burning(false)


## 切换燃烧视觉状态：灯光 / 火焰 / 木柴 / 危险区 只在实际点燃后生效
func _apply_burning(b: bool) -> void:
	if _light:
		if b:
			_light.light_energy = _light_energy
			_light.visible = true
		else:
			_light.visible = false
	if _flame:
		_flame.visible = b
		_flame.scale = Vector3.ONE
	for log_mesh in _logs:
		log_mesh.visible = b
	if _hazard:
		_hazard.monitoring = b
	if not b and _prompt:
		_prompt.visible = false


## 木柴随剩余燃料比例缩小（补满燃料后恢复原大小）
func _update_logs_scale() -> void:
	if _logs.is_empty():
		return
	var ratio := clampf(_burn_remaining / _burn_hours, 0.0, 1.0)
	var s := maxf(ratio, LOG_MIN_SCALE)
	for log_mesh in _logs:
		log_mesh.scale = Vector3.ONE * s


## 火光 / 火焰轻微抖动
func _flicker(delta: float) -> void:
	_flicker_t += delta
	if _light and _light.visible:
		_light.light_energy = _light_energy * (0.88 + 0.18 * (sin(_flicker_t * 9.0) * 0.5 + sin(_flicker_t * 23.0) * 0.5))
	if _flame:
		var s := 1.0 + 0.06 * sin(_flicker_t * 11.0)
		_flame.scale = Vector3(s, 1.0 + 0.10 * sin(_flicker_t * 13.0 + 1.7), s)


func _dist_to_player() -> float:
	if _player == null or not is_instance_valid(_player):
		return INF
	var bld := get_parent() as Node3D
	return _player.global_position.distance_to(bld.global_position)


## 多个篝火同时在交互范围内时，只允许最近的响应，避免按一次扣多份材料
func _is_nearest() -> bool:
	for other in get_tree().get_nodes_in_group(GROUP):
		if other == self or not is_instance_valid(other):
			continue
		if other._dist_to_player() <= other._interaction_range and other._dist_to_player() < _dist_to_player():
			return false
	return true


## 交互提示：未点燃，或燃烧中燃料降到可追加范围时，且玩家靠近才显示（浮动 + 颜色区分木材是否足够）
func _update_prompt() -> void:
	if _prompt == null:
		return
	var near: bool = not _player.is_dead() and _dist_to_player() <= _interaction_range + 0.5
	var action_available: bool = not _burning or _refuel_allowed()
	var show: bool = near and action_available
	_prompt.visible = show
	if not show:
		return

	var amount: int = _fuel_per_refuel if _burning else _fuel_per_ignite
	if _feedback_t > 0.0:
		_prompt.text = "[E] 木材不足 ×%d" % _feedback_amount
		_prompt.modulate = Color(0.95, 0.4, 0.35)
	elif _inventory and _inventory.count_item(_fuel_item_id) >= amount:
		_prompt.text = "[E] 添加木柴 ×%d" % amount
		_prompt.modulate = Color(1.0, 0.82, 0.25)
	else:
		_prompt.text = "需要木材 ×%d" % amount
		_prompt.modulate = Color(0.9, 0.6, 0.35)

	# 上下浮动，更显眼
	_prompt.position.y = _prompt_base_y + sin(Time.get_ticks_msec() * 0.004) * 0.05


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if get_tree().paused or not _ready:
		return
	if _player == null or _player.is_dead():
		return
	if _dist_to_player() > _interaction_range or not _is_nearest():
		return
	if _burning:
		if _refuel_allowed():
			_try_refuel()
			get_viewport().set_input_as_handled()
	else:
		_try_ignite()
		get_viewport().set_input_as_handled()

extends Node
class_name CampfireLogic
## 篝火交互逻辑：放置后不发光，靠近弹出提示按 E 消耗木材点燃，
## 按游戏时间燃烧指定时长后熄灭，熄灭后可再次添加木柴（循环）。
## ★ 由 world_3d.place_building 挂载（BuildingData.fuel_item_id 非空时）

const GROUP := "campfire"

var _fuel_item_id: String = "wood"
var _fuel_per_ignite: int = 3
var _burn_hours: float = 6.0
var _interaction_range: float = 2.6

var _player: Node3D
var _inventory: Node
var _day_night: Node

var _light: OmniLight3D
var _flame: Node3D
var _prompt: Label3D
var _hazard: Area3D

var _light_energy: float = 3.0
var _burning: bool = false
var _burn_remaining: float = 0.0   # 剩余燃烧时长（游戏小时）
var _flicker_t: float = 0.0
var _feedback_t: float = 0.0       # "木材不足" 红色提示剩余时长
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
	_burn_hours = float(data.get("burn_duration_hours"))
	_interaction_range = float(data.get("interaction_range"))

	var bld := get_parent() as Node3D
	_light = bld.get_node_or_null("Light") as OmniLight3D
	_flame = bld.get_node_or_null("Flame")
	_prompt = bld.get_node_or_null("Prompt") as Label3D
	_hazard = bld.get_node_or_null("Hazard") as Area3D
	if _light:
		_light_energy = float(data.get("light_energy"))
	if _prompt:
		_prompt_base_y = _prompt.position.y

	# 初始未点燃：不发光 / 无火焰 / 危险区关闭
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

	_update_prompt()


## 按 E：尝试消耗燃料点燃（已在 _input 里确认是最近的可交互篝火）
func _try_ignite() -> void:
	if _burning:
		return
	if _inventory == null or not _inventory.has_cost({_fuel_item_id: _fuel_per_ignite}):
		_feedback_t = 1.2
		return
	_inventory.consume_cost({_fuel_item_id: _fuel_per_ignite})
	_burn_remaining = _burn_hours
	_start_burning()


func _start_burning() -> void:
	_burning = true
	_flicker_t = 0.0
	_apply_burning(true)


func _extinguish() -> void:
	_burning = false
	_burn_remaining = 0.0
	_apply_burning(false)


## 切换燃烧视觉状态：灯光 / 火焰 / 危险区 只在实际点燃后生效
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
	if _hazard:
		_hazard.monitoring = b
	if not b and _prompt:
		_prompt.visible = false


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


## 交互提示：未点燃且玩家靠近时显示（浮动 + 颜色区分木材是否足够）
func _update_prompt() -> void:
	if _prompt == null:
		return
	var show: bool = false
	if not _burning and not _player.is_dead() and _dist_to_player() <= _interaction_range + 0.5:
		show = true
	_prompt.visible = show
	if not show:
		return

	if _feedback_t > 0.0:
		_prompt.text = "[E] 木材不足 ×%d" % _fuel_per_ignite
		_prompt.modulate = Color(0.95, 0.4, 0.35)
	elif _inventory and _inventory.count_item(_fuel_item_id) >= _fuel_per_ignite:
		_prompt.text = "[E] 添加木柴 ×%d" % _fuel_per_ignite
		_prompt.modulate = Color(1.0, 0.82, 0.25)
	else:
		_prompt.text = "需要木材 ×%d" % _fuel_per_ignite
		_prompt.modulate = Color(0.9, 0.6, 0.35)

	# 上下浮动，更显眼
	_prompt.position.y = _prompt_base_y + sin(Time.get_ticks_msec() * 0.004) * 0.05


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if get_tree().paused or not _ready:
		return
	if _burning or _player == null or _player.is_dead():
		return
	if _dist_to_player() > _interaction_range or not _is_nearest():
		return
	_try_ignite()
	get_viewport().set_input_as_handled()

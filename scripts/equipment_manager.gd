extends Node
class_name EquipmentManager
## 装备管理器：功能装备 / 武器 / 消耗品 三个分区
## 物品存于背包，装备栏只持有 item_id 引用

const EquipmentScript := preload("res://scripts/equipment.gd")
const CONSUMABLE_SLOTS := 3
const CONSUMABLE_COOLDOWN: float = 8.0

signal utility_changed(active_index: int)
signal weapon_changed(active_index: int)
signal consumables_changed(slot: int)
signal consumable_used(slot: int, heal_amount: float)

# ── 功能装备区（存 item_id）──
var utility_slots: Array[String] = []  # ["flashlight", "torch"]
var _utility_index: int = -1

# ── 武器区（存 item_id）──
var weapon_slots: Array[String] = []   # ["sword_wood"]
var _weapon_index: int = -1

# ── 消耗品区（存 item_id，3 固定槽位）──
var _cons_slots: Array[String] = []     # ["meat", "", ""]
var _cons_cooldowns: Array[float] = []  # 每槽冷却

# ── 光源节点 ──
var _spot_light: SpotLight3D
var _omni_light: OmniLight3D
var _inventory: Node


# ═══════════════════════════════════════════
# 初始化
# ═══════════════════════════════════════════

func setup(spot: SpotLight3D, omni: OmniLight3D, inventory: Node) -> void:
	_spot_light = spot
	_omni_light = omni
	_inventory = inventory
	_cons_slots.resize(CONSUMABLE_SLOTS)
	_cons_cooldowns.resize(CONSUMABLE_SLOTS)
	_turn_off_all()
	if inventory.has_signal("changed"):
		inventory.changed.connect(_on_inventory_changed)


func _process(delta: float) -> void:
	# 防御：setup() 调用前数组未初始化（场景化后 _process 可能先运行）
	if _cons_cooldowns.size() < CONSUMABLE_SLOTS:
		return
	for i in range(CONSUMABLE_SLOTS):
		if _cons_cooldowns[i] > 0.0:
			_cons_cooldowns[i] = maxf(_cons_cooldowns[i] - delta, 0.0)
			consumables_changed.emit(i)


# ═══════════════════════════════════════════
# 物品查询（从 ItemDB 读 Resource）
# ═══════════════════════════════════════════

func _on_inventory_changed() -> void:
	for i in range(CONSUMABLE_SLOTS):
		if not _cons_slots[i].is_empty():
			consumables_changed.emit(i)


func _get_item(id: String) -> Resource:
	if id.is_empty():
		return null
	var ItemDBScript := load("res://scripts/core/item_db.gd")
	return ItemDBScript.get_item(id)


func _find_inv_slot(item_id: String) -> int:
	for i in range(_inventory.slots.size()):
		var st = _inventory.get_stack(i)
		if st and st.item.get("id") == item_id:
			return i
	return -1


func _item_count(item_id: String) -> int:
	var n := 0
	for i in range(_inventory.slots.size()):
		var st = _inventory.get_stack(i)
		if st and st.item.get("id") == item_id:
			n += st.count
	return n


# ═══════════════════════════════════════════
# 装备 / 卸下
# ═══════════════════════════════════════════

func equip_from_inventory(inv_slot: int) -> bool:
	var st = _inventory.get_stack(inv_slot)
	if not st:
		return false
	var item_id: String = st.item.get("id")
	var itype: int = st.item.get("item_type")

	if itype == 1: # EQUIPMENT → 功能装备
		if item_id in utility_slots:
			return false
		utility_slots.append(item_id)
		if utility_slots.size() == 1:
			_utility_index = 0
			_apply_utility()
		utility_changed.emit(_utility_index)
		_inventory.changed.emit()
		return true

	elif itype == 2: # WEAPON
		if item_id in weapon_slots:
			return false
		weapon_slots.append(item_id)
		if weapon_slots.size() == 1:
			_weapon_index = 0
			_apply_weapon()
		weapon_changed.emit(_weapon_index)
		_inventory.changed.emit()
		return true

	elif st.item.get("heal_amount") > 0.0: # 消耗品
		if item_id in _cons_slots:
			return false
		for i in range(CONSUMABLE_SLOTS):
			if _cons_slots[i].is_empty():
				_cons_slots[i] = item_id
				_cons_cooldowns[i] = 0.0
				consumables_changed.emit(i)
				_inventory.changed.emit()
				return true
		return false

	return false


func unequip_utility(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= utility_slots.size():
		return false
	utility_slots.remove_at(slot_index)
	if _utility_index >= utility_slots.size():
		_utility_index = utility_slots.size() - 1
	_apply_utility()
	_inventory.changed.emit()
	utility_changed.emit(_utility_index)
	return true


func unequip_weapon(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= weapon_slots.size():
		return false
	weapon_slots.remove_at(slot_index)
	if _weapon_index >= weapon_slots.size():
		_weapon_index = weapon_slots.size() - 1
	_apply_weapon()
	_inventory.changed.emit()
	weapon_changed.emit(_weapon_index)
	return true


func unequip_consumable(slot: int) -> bool:
	if slot < 0 or slot >= CONSUMABLE_SLOTS:
		return false
	_cons_slots[slot] = ""
	_cons_cooldowns[slot] = 0.0
	_inventory.changed.emit()
	consumables_changed.emit(slot)
	return true


## 根据背包格子自动判断分区并卸下
func unequip_item_from_inventory(inv_slot: int) -> bool:
	var st = _inventory.get_stack(inv_slot)
	if not st:
		return false
	var item_id: String = st.item.get("id")
	var itype: int = st.item.get("item_type")

	if itype == 1: # EQUIPMENT
		var idx := utility_slots.find(item_id)
		if idx >= 0:
			return unequip_utility(idx)
	elif itype == 2: # WEAPON
		var idx := weapon_slots.find(item_id)
		if idx >= 0:
			return unequip_weapon(idx)
	elif st.item.get("heal_amount") > 0.0:
		var idx := _cons_slots.find(item_id)
		if idx >= 0:
			return unequip_consumable(idx)
	return false


## 直接从背包使用消耗品（右键"使用"）
func use_from_inventory(inv_slot: int) -> bool:
	var st = _inventory.get_stack(inv_slot)
	if not st:
		return false
	if st.item.get("heal_amount") <= 0.0:
		return false
	st.count -= 1
	if st.count <= 0:
		_inventory.slots[inv_slot] = null
	_inventory.changed.emit()
	return true


# ═══════════════════════════════════════════
# 快捷操作
# ═══════════════════════════════════════════

func cycle_utility() -> void:
	if utility_slots.is_empty():
		_utility_index = -1
		_turn_off_all()
		utility_changed.emit(_utility_index)
		return
	_utility_index += 1
	if _utility_index >= utility_slots.size():
		_utility_index = -1
	_apply_utility()
	utility_changed.emit(_utility_index)


func cycle_weapon() -> void:
	if weapon_slots.is_empty():
		_weapon_index = -1
		weapon_changed.emit(_weapon_index)
		return
	_weapon_index += 1
	if _weapon_index >= weapon_slots.size():
		_weapon_index = -1
	_apply_weapon()
	weapon_changed.emit(_weapon_index)


func use_consumable(slot: int) -> bool:
	if slot < 0 or slot >= CONSUMABLE_SLOTS:
		return false
	if _cons_slots[slot].is_empty():
		return false
	if _cons_cooldowns[slot] > 0.0:
		return false

	var item_id: String = _cons_slots[slot]
	var inv_idx := _find_inv_slot(item_id)
	if inv_idx < 0:
		_cons_slots[slot] = ""
		_cons_cooldowns[slot] = 0.0
		consumables_changed.emit(slot)
		return false

	var st = _inventory.get_stack(inv_idx)
	if not st or st.count <= 0:
		_cons_slots[slot] = ""
		_cons_cooldowns[slot] = 0.0
		consumables_changed.emit(slot)
		return false

	var heal: float = st.item.get("heal_amount")
	st.count -= 1
	if st.count <= 0:
		_inventory.slots[inv_idx] = null
	_cons_cooldowns[slot] = CONSUMABLE_COOLDOWN
	_inventory.changed.emit()
	consumables_changed.emit(slot)

	var player := get_parent()
	if player:
		var h: Health = player.get_health()
		if h:
			h.heal(heal)
	consumable_used.emit(slot, heal)
	return true


# ═══════════════════════════════════════════
# 查询
# ═══════════════════════════════════════════

func get_utility_count() -> int:
	return utility_slots.size()


func get_utility_active() -> int:
	return _utility_index


func get_utility_at(idx: int) -> Resource:
	if idx >= 0 and idx < utility_slots.size():
		return _get_item(utility_slots[idx])
	return null


func get_weapon_count() -> int:
	return weapon_slots.size()


func get_weapon_active() -> int:
	return _weapon_index


func get_weapon_at(idx: int) -> Resource:
	if idx >= 0 and idx < weapon_slots.size():
		return _get_item(weapon_slots[idx])
	return null


func get_current_weapon() -> Resource:
	if _weapon_index >= 0 and _weapon_index < weapon_slots.size():
		return _get_item(weapon_slots[_weapon_index])
	return null


func get_cons_item(slot: int) -> Resource:
	if slot >= 0 and slot < CONSUMABLE_SLOTS and not _cons_slots[slot].is_empty():
		return _get_item(_cons_slots[slot])
	return null


func get_cons_count(slot: int) -> int:
	if slot >= 0 and slot < CONSUMABLE_SLOTS and not _cons_slots[slot].is_empty():
		return _item_count(_cons_slots[slot])
	return 0


func get_cons_cooldown(slot: int) -> float:
	if slot >= 0 and slot < CONSUMABLE_SLOTS:
		return _cons_cooldowns[slot]
	return 0.0


func get_cons_cooldown_ratio(slot: int) -> float:
	if CONSUMABLE_COOLDOWN <= 0.0:
		return 0.0
	return clampf(_cons_cooldowns[slot] / CONSUMABLE_COOLDOWN, 0.0, 1.0)


## 物品是否已装备（供背包高亮）
func is_item_equipped(item_id: String) -> bool:
	return item_id in utility_slots or item_id in weapon_slots or item_id in _cons_slots


func is_utility_equipped(item_id: String) -> bool:
	return item_id in utility_slots


func is_weapon_equipped(item_id: String) -> bool:
	return item_id in weapon_slots


func is_consumable_equipped(item_id: String) -> bool:
	return item_id in _cons_slots


# ═══════════════════════════════════════════
# 存档
# ═══════════════════════════════════════════

func get_save_data() -> Dictionary:
	return {
		"utility_ids": utility_slots.duplicate(),
		"utility_index": _utility_index,
		"weapon_ids": weapon_slots.duplicate(),
		"weapon_index": _weapon_index,
		"consumables": _cons_slots.duplicate(),
		"cooldowns": _cons_cooldowns.duplicate(),
	}


func restore_from_data(data: Dictionary) -> void:
	utility_slots.clear()
	var arr: Array = data.get("utility_ids", [])
	for id in arr:
		utility_slots.append(str(id))
	_utility_index = data.get("utility_index", -1)
	if _utility_index >= utility_slots.size():
		_utility_index = utility_slots.size() - 1
	_apply_utility()

	weapon_slots.clear()
	var warr: Array = data.get("weapon_ids", [])
	for id in warr:
		weapon_slots.append(str(id))
	_weapon_index = data.get("weapon_index", -1)
	if _weapon_index >= weapon_slots.size():
		_weapon_index = weapon_slots.size() - 1
	_apply_weapon()

	var carr: Array = data.get("consumables", [])
	var cdarr: Array = data.get("cooldowns", [])
	for i in range(CONSUMABLE_SLOTS):
		if i < carr.size():
			_cons_slots[i] = str(carr[i]) if carr[i] != null else ""
		else:
			_cons_slots[i] = ""
		if i < cdarr.size():
			_cons_cooldowns[i] = float(cdarr[i])
		else:
			_cons_cooldowns[i] = 0.0

	utility_changed.emit(_utility_index)
	weapon_changed.emit(_weapon_index)
	for i in range(CONSUMABLE_SLOTS):
		consumables_changed.emit(i)


# ═══════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════

func _apply_utility() -> void:
	var eq := get_utility_at(_utility_index)
	if eq == null:
		_turn_off_all()
		# 功能装备不提供转向迟滞；切换后重新应用当前武器的迟滞，避免把武器迟滞清掉
		_apply_weapon()
		return

	_turn_off_all()
	_apply_weapon()

	var light_type = eq.get("light_type")
	if light_type == EquipmentScript.LightType.SPOT:
		_apply_to_spot(eq)
	elif light_type == EquipmentScript.LightType.OMNI:
		_apply_to_omni(eq)


func _apply_weapon() -> void:
	var wpn := get_current_weapon()
	var lag: float = wpn.get("rotation_lag") if wpn and "rotation_lag" in wpn else 0.0
	_set_player_lag(lag)


func _set_player_lag(lag: float) -> void:
	var player := get_parent()
	if player and "rotation_lag" in player:
		player.rotation_lag = lag


func _turn_off_all() -> void:
	if _spot_light:
		_spot_light.visible = false
		_spot_light.light_energy = 0.0
	if _omni_light:
		_omni_light.visible = false
		_omni_light.light_energy = 0.0


func _apply_to_spot(eq: Resource) -> void:
	if not _spot_light:
		return
	# ★ 位置/旋转/角度范围(spot_angle)由场景(.tscn)可视化摆定，不被覆盖；
	#   强度/射程/距离衰减/角度衰减/颜色/阴影由装备数据(.tres)控制
	_spot_light.spot_range = eq.get("spot_range")
	_spot_light.spot_attenuation = eq.get("spot_attenuation")
	_spot_light.spot_angle_attenuation = eq.get("spot_angle_attenuation")
	_spot_light.light_color = eq.get("light_color")
	_spot_light.light_energy = eq.get("light_energy")
	_spot_light.light_indirect_energy = eq.get("light_indirect_energy")
	_spot_light.shadow_enabled = eq.get("shadow_enabled")
	_spot_light.visible = true


func _apply_to_omni(eq: Resource) -> void:
	if not _omni_light:
		return
	# ★ 位置由场景(.tscn)可视化摆定，不被覆盖；
	#   强度/范围/衰减/颜色等效果参数由装备数据(.tres)控制
	_omni_light.omni_range = eq.get("omni_range")
	_omni_light.omni_attenuation = eq.get("omni_attenuation")
	_omni_light.light_color = eq.get("light_color")
	_omni_light.light_energy = eq.get("light_energy")
	_omni_light.light_indirect_energy = eq.get("light_indirect_energy")
	_omni_light.shadow_enabled = eq.get("shadow_enabled")
	_omni_light.visible = true

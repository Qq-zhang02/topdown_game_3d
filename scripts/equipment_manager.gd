extends Node
class_name EquipmentManager
## 装备管理器：管理装备列表、切换、应用属性到光源节点

# 跨文件引用（避免 class_name 解析顺序问题）
const EquipmentScript := preload("res://scripts/equipment.gd")

signal equipment_changed(equipment_name: String)
signal equipment_cycled(index: int, equipment_name: String)

var equipment_list: Array = []    # Array[Resource]
var _current_index: int = -1      # -1 = 未装备（关）

var _spot_light: SpotLight3D
var _omni_light: OmniLight3D


# ═══════════════════════════════════════════
# 初始化
# ═══════════════════════════════════════════

func setup(spot: SpotLight3D, omni: OmniLight3D) -> void:
	_spot_light = spot
	_omni_light = omni
	_turn_off_all()


func add_equipment(eq: Resource) -> void:
	equipment_list.append(eq)
	if equipment_list.size() == 1:
		equip_index(0)


func clear() -> void:
	equipment_list.clear()
	_current_index = -1
	_turn_off_all()


# ═══════════════════════════════════════════
# 操作
# ═══════════════════════════════════════════

func equip_index(idx: int) -> void:
	if idx < -1 or idx >= equipment_list.size():
		return
	_current_index = idx
	_apply_current()


func cycle_next() -> void:
	"""只遍历 equipped=true 的装备；无装备时全关"""
	var equipped_indices: Array[int] = []
	for i in range(equipment_list.size()):
		if equipment_list[i].get("equipped") != false:
			equipped_indices.append(i)

	if equipped_indices.is_empty():
		_current_index = -1
		_turn_off_all()
		return

	# 找到下一个装备（循环到关）
	if _current_index >= 0:
		var pos := equipped_indices.find(_current_index)
		if pos < equipped_indices.size() - 1:
			_current_index = equipped_indices[pos + 1]
		else:
			_current_index = -1
	else:
		_current_index = equipped_indices[0]

	_apply_current()


func cycle_prev() -> void:
	var total := equipment_list.size()
	if total == 0:
		_current_index = -1
		_turn_off_all()
		return

	_current_index -= 1
	if _current_index < -1:
		_current_index = total - 1

	_apply_current()


func get_current() -> Resource:
	if _current_index >= 0 and _current_index < equipment_list.size():
		return equipment_list[_current_index]
	return null


func get_current_name() -> String:
	var eq := get_current()
	if eq:
		return eq.get("display_name")
	return "无装备"


func get_current_index() -> int:
	return _current_index


func get_count() -> int:
	"""已装备（equipped=true）的数量"""
	var n := 0
	for eq in equipment_list:
		if eq.get("equipped") != false:
			n += 1
	return n


func get_name_at(slot: int) -> String:
	"""第 slot 个已装备项的名字"""
	var idx := _slot_to_index(slot)
	if idx >= 0:
		return equipment_list[idx].get("display_name")
	return ""


func get_active_slot() -> int:
	"""当前装备在已装备列表中的槽位号，-1=关"""
	if _current_index < 0:
		return -1
	var slot := 0
	for i in range(_current_index):
		if i < equipment_list.size() and equipment_list[i].get("equipped") != false:
			slot += 1
	return slot


func is_equipped_at(index: int) -> bool:
	if index >= 0 and index < equipment_list.size():
		return equipment_list[index].get("equipped") != false
	return false


func _slot_to_index(slot: int) -> int:
	"""已装备槽位号 → equipment_list 索引"""
	var s := 0
	for i in range(equipment_list.size()):
		if equipment_list[i].get("equipped") != false:
			if s == slot:
				return i
			s += 1
	return -1


# ═══════════════════════════════════════════
# 内部：应用装备属性到光源
# ═══════════════════════════════════════════

func _apply_current() -> void:
	var eq := get_current()
	if eq == null:
		_turn_off_all()
		equipment_changed.emit("")
		equipment_cycled.emit(_current_index, "")
		return

	_turn_off_all()

	var light_type: int = eq.get("light_type")
	var LIGHT_SPOT: int = EquipmentScript.LightType.SPOT
	var LIGHT_OMNI: int = EquipmentScript.LightType.OMNI

	if light_type == LIGHT_SPOT:
		_apply_to_spot(eq)
	elif light_type == LIGHT_OMNI:
		_apply_to_omni(eq)

	var name_str: String = eq.get("display_name")
	equipment_changed.emit(name_str)
	equipment_cycled.emit(_current_index, name_str)


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
	_spot_light.position = eq.get("position_offset")
	_spot_light.rotation = eq.get("rotation_offset")
	_spot_light.spot_range = eq.get("spot_range")
	_spot_light.spot_attenuation = eq.get("spot_attenuation")
	_spot_light.spot_angle = eq.get("spot_angle")
	_spot_light.light_color = eq.get("light_color")
	_spot_light.light_energy = eq.get("light_energy")
	_spot_light.light_indirect_energy = eq.get("light_indirect_energy")
	_spot_light.shadow_enabled = eq.get("shadow_enabled")
	_spot_light.visible = true


func _apply_to_omni(eq: Resource) -> void:
	if not _omni_light:
		return
	_omni_light.position = eq.get("position_offset")
	_omni_light.omni_range = eq.get("omni_range")
	_omni_light.omni_attenuation = eq.get("omni_attenuation")
	_omni_light.light_color = eq.get("light_color")
	_omni_light.light_energy = eq.get("light_energy")
	_omni_light.light_indirect_energy = eq.get("light_indirect_energy")
	_omni_light.shadow_enabled = eq.get("shadow_enabled")
	_omni_light.visible = true

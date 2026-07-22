extends Node
class_name Inventory
## 背包数据层：固定格子 + 增删查 + 消耗材料，变更时发 changed 信号

signal changed

const ItemStackClass := preload("res://scripts/core/item_stack.gd")

@export var slot_count: int = 32

var slots: Array = []  # ItemStack | null


func _ready() -> void:
	slots.resize(slot_count)


## 放入物品，返回放不下的剩余数量
func add_item(item: Resource, count: int = 1) -> int:
	var remaining := count
	var max_stack: int = item.get("max_stack")
	if max_stack <= 0:
		max_stack = 99

	# 先合并到已有堆叠
	for i in slots.size():
		var st = slots[i]
		if st and st.item == item and st.count < max_stack:
			var take: int = mini(max_stack - st.count, remaining)
			st.count += take
			remaining -= take
			if remaining <= 0:
				break

	# 再占空格子
	if remaining > 0:
		for i in slots.size():
			if slots[i] == null:
				var take: int = mini(max_stack, remaining)
				slots[i] = ItemStackClass.new(item, take)
				remaining -= take
				if remaining <= 0:
					break

	changed.emit()
	return remaining


func get_stack(index: int) -> ItemStack:
	if index >= 0 and index < slots.size():
		return slots[index]
	return null


## 拖拽移动/合并两个格子
func move_slot(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return
	if from_idx < 0 or from_idx >= slots.size() or to_idx < 0 or to_idx >= slots.size():
		return

	var a = slots[from_idx]
	var b = slots[to_idx]
	if a and b and a.item == b.item:
		var max_stack: int = a.item.get("max_stack")
		var total: int = a.count + b.count
		if total <= max_stack:
			b.count = total
			slots[from_idx] = null
		else:
			b.count = max_stack
			a.count = total - max_stack
	else:
		slots[from_idx] = b
		slots[to_idx] = a
	changed.emit()


func count_item(id: String) -> int:
	var n := 0
	for st in slots:
		if st and st.item.get("id") == id:
			n += st.count
	return n


## 检查材料是否足够，cost 格式 {"wood": 5, "stone": 3}
func has_cost(cost: Dictionary) -> bool:
	for k in cost:
		if count_item(k) < int(cost[k]):
			return false
	return true


## 消耗材料，不足则不动并返回 false
func consume_cost(cost: Dictionary) -> bool:
	if not has_cost(cost):
		return false
	for k in cost:
		_remove_by_id(k, int(cost[k]))
	changed.emit()
	return true


func _remove_by_id(id: String, amount: int) -> void:
	var remaining := amount
	for i in slots.size():
		var st = slots[i]
		if st and st.item.get("id") == id:
			var take: int = mini(st.count, remaining)
			st.count -= take
			remaining -= take
			if st.count <= 0:
				slots[i] = null
			if remaining <= 0:
				break

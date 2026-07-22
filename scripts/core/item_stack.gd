extends RefCounted
class_name ItemStack
## 背包中的一个格子：某物品 + 数量

var item: Resource  # ItemData
var count: int = 1


func _init(p_item: Resource = null, p_count: int = 1) -> void:
	item = p_item
	count = p_count


func clone() -> ItemStack:
	return ItemStack.new(item, count)

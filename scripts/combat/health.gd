extends Node
class_name Health
## 通用血量组件：玩家/动物/资源节点共用
## 挂在父节点下并命名为 "Health"，父节点加入 "damageable" 组即可被近战命中

signal damaged(amount: float, from_position: Vector3)
signal died

@export var max_hp: float = 100.0

var hp: float


func _ready() -> void:
	hp = max_hp


func take_damage(amount: float, from_position: Vector3 = Vector3.ZERO) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	damaged.emit(amount, from_position)
	if hp <= 0.0:
		hp = 0.0
		died.emit()


func heal(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = minf(hp + amount, max_hp)


func is_dead() -> bool:
	return hp <= 0.0

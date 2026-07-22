extends "res://scripts/core/item_data.gd"
class_name WeaponData
## 近战武器数据：装备到手后左键挥击

@export var damage: float = 10.0
@export var attack_range: float = 2.2      # 攻击距离（米）
@export var attack_arc: float = 100.0      # 扇形角度（度）
@export var cooldown: float = 0.5          # 两次攻击间隔（秒）
@export var knockback: float = 3.0         # 击退冲量


func _init() -> void:
	item_type = ItemType.WEAPON
	max_stack = 1

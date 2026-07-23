extends "res://scripts/core/item_data.gd"
class_name WeaponData
## 近战武器数据：加减模式，最终 = 拳头基础 + 武器加成值
## 新建 .tres 时显式填写各项加成，不填的默认为 0（无加成）

@export var damage: float = 0.0          # 伤害加成
@export var attack_range: float = 0.0    # 攻击距离加成（米）
@export var attack_arc: float = 0.0      # 扇形角度加成（度）
@export var cooldown: float = 0.0        # 冷却时间加成（秒，负值=更快）
@export var knockback: float = 0.0       # 击退冲量加成
@export var rotation_lag: float = 0.0    # 转向迟滞
@export var has_projectile_vfx: bool = false      # 攻击时是否显示弧形剑气（SlashArc.glb + shader）


func _init() -> void:
	item_type = ItemType.WEAPON
	max_stack = 1

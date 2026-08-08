extends "res://scripts/core/item_data.gd"
class_name Equipment
## 装备数据资源：光源类装备（手电筒/火把等），继承物品基类
## ★ 位置/旋转/角度范围(spot_angle)在 .tscn 场景中设置，不在此资源中
## ★ 强度/射程/衰减(距离+角度)/颜色/阴影等效果参数在此资源(.tres)中设置

enum LightType { NONE, SPOT, OMNI }

# ── 装备状态 ──
@export var equipped: bool = true  # 是否已装备（在切换循环中）

# ── 光源类型 ──
@export var light_type: LightType = LightType.NONE

# ── 通用光源参数（位置/旋转/角度范围在 .tscn 场景中设置）──
@export var light_color: Color = Color.WHITE
@export var light_energy: float = 1.0
@export var light_indirect_energy: float = 1.0
@export var shadow_enabled: bool = false

# ── 聚光灯专用 ──
@export var spot_range: float = 10.0           # 射程（距离）
@export var spot_attenuation: float = 0.5       # 距离衰减
@export var spot_angle_attenuation: float = 1.0 # 角度衰减（光锥边缘软硬）

# ── 点光源专用 ──
@export var omni_range: float = 5.0
@export var omni_attenuation: float = 0.5


func _init() -> void:
	item_type = ItemType.EQUIPMENT
	max_stack = 1

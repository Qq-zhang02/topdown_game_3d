extends "res://scripts/core/item_data.gd"
class_name Equipment
## 装备数据资源：光源类装备（手电筒/火把等），继承物品基类

enum LightType { NONE, SPOT, OMNI }

# ── 装备状态 ──
@export var equipped: bool = true  # 是否已装备（在切换循环中）

# ── 光源类型 ──
@export var light_type: LightType = LightType.NONE

# ── 通用光源参数 ──
@export var light_color: Color = Color.WHITE
@export var light_energy: float = 1.0
@export var light_indirect_energy: float = 1.0
@export var shadow_enabled: bool = false
@export var position_offset: Vector3 = Vector3.ZERO
@export var rotation_offset: Vector3 = Vector3.ZERO

# ── 聚光灯专用 ──
@export var spot_range: float = 10.0
@export var spot_attenuation: float = 0.5
@export var spot_angle: float = 45.0

# ── 点光源专用 ──
@export var omni_range: float = 5.0
@export var omni_attenuation: float = 0.5


func _init() -> void:
	item_type = ItemType.EQUIPMENT
	max_stack = 1

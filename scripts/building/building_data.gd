extends Resource
class_name BuildingData
## 建筑配方 + 定义：在 data/buildings/ 下新建 .tres 即新增一种建筑
## ★ 建筑尺寸不在此资源中：由 scene_path 指向的预制体(.tscn)的 mesh AABB 决定

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color(0.6, 0.5, 0.4)
@export var cost: Dictionary = {}               # 材料消耗 {"wood": 5}
@export var scene_path: String = ""             # 建筑外观场景预制体（空则回退 BoxMesh 默认 1x1x1）


## 从预制体的 mesh AABB 计算建筑尺寸（幽灵预览/占地/放置用）
func get_size() -> Vector3:
	var aabb := _prefab_aabb()
	if aabb.size != Vector3.ZERO:
		return aabb.size
	return Vector3.ONE  # 回退默认 1×1×1


## AABB 底部相对原点的偏移：放置时 pos.y = 地表 - min_y 即可让模型底部贴地
## （居中建模的 BoxMesh 为 -一半高度，地面堆叠建模如篝火则为较小的负值/0）
func get_min_y() -> float:
	var aabb := _prefab_aabb()
	if aabb.size != Vector3.ZERO:
		return aabb.position.y
	return -get_size().y * 0.5  # 回退：假定居中建模


## 预制体 mesh 完整 AABB（含位置），未找到时返回空 AABB
func _prefab_aabb() -> AABB:
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		var ps: PackedScene = load(scene_path)
		if ps:
			var inst := ps.instantiate()
			if inst is Node3D:
				var aabb := _compute_aabb(inst as Node3D)
				inst.free()
				return aabb
	return AABB()


static func _compute_aabb(node: Node3D) -> AABB:
	var aabb := AABB()
	var in_tree := node.is_inside_tree()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			var local_aabb: AABB = mi.mesh.get_aabb()
			# 未入树的实例（get_size 预览）global_transform 不可用，用本地变换代替
			var global_aabb: AABB = (mi.global_transform if in_tree else mi.transform) * local_aabb
			if aabb.size.length_squared() < 0.01:
				aabb = global_aabb
			else:
				aabb = aabb.merge(global_aabb)
	return aabb


## 兼容接口：只取 AABB 尺寸（place_building 对实例重新计算用）
static func _compute_aabb_size(node: Node3D) -> Vector3:
	return _compute_aabb(node).size

# ── 发光（篝火等）：光源参数唯一数据源，覆盖预制体内的灯光 ──
@export var emits_light: bool = false
@export var light_color: Color = Color(1.0, 0.6, 0.2)
@export var light_energy: float = 3.0
@export var light_range: float = 8.0
@export var light_attenuation: float = 1.0  # 衰减（灯光位置在 .tscn 预制体内）
@export var light_shadow_enabled: bool = true   # 灯光是否投阴影

# ── 危险区（触碰扣血 + 击退，如篝火/地刺）──
@export var hazard_damage: float = 0.0        # 每次扣血量（>0 启用危险区）
@export var hazard_interval: float = 1.0      # 扣血间隔（秒）
@export var hazard_knockback: float = 0.0     # 击退冲量（0 = 不击退）
@export var hazard_knockback_up: float = 0.0  # 击退竖直分量
@export var hazard_animal_damage_multiplier: float = 1.0     # 小动物扣血倍率（相对玩家，如 3 = 动物受 3 倍伤害）
@export var hazard_animal_knockback_multiplier: float = 1.0  # 小动物击退倍率（相对玩家，如 1.5 = 动物被弹得更远）

# ── 交互（篝火点火/加柴）：fuel_item_id 非空则放置时挂载交互逻辑，发光/危险区只在该建筑"点燃"后生效 ──
@export var fuel_item_id: String = ""       # 燃料物品ID（如 "wood"）
@export var fuel_per_ignite: int = 0        # 每次点燃消耗的燃料数量（0 = 不可交互点火）
@export var burn_duration_hours: float = 0.0 # 单次燃烧时长（游戏小时）
@export var interaction_range: float = 2.5  # 交互半径（米，玩家需靠近即可按交互键）

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
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		var ps: PackedScene = load(scene_path)
		if ps:
			var inst := ps.instantiate()
			if inst is Node3D:
				var sz := _compute_aabb_size(inst as Node3D)
				inst.free()
				if sz != Vector3.ZERO:
					return sz
	return Vector3.ONE  # 回退默认 1×1×1


static func _compute_aabb_size(node: Node3D) -> Vector3:
	var aabb := AABB()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			var local_aabb: AABB = mi.mesh.get_aabb()
			var global_aabb: AABB = mi.global_transform * local_aabb
			if aabb.size.length_squared() < 0.01:
				aabb = global_aabb
			else:
				aabb = aabb.merge(global_aabb)
	return aabb.size

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

extends Resource
class_name BuildingData
## 建筑配方 + 定义：在 data/buildings/ 下新建 .tres 即新增一种建筑

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var size: Vector3 = Vector3(1, 1, 1)   # 占地尺寸（米）
@export var color: Color = Color(0.6, 0.5, 0.4)
@export var cost: Dictionary = {}               # 材料消耗 {"wood": 5}

# ── 发光（篝火等）──
@export var emits_light: bool = false
@export var light_color: Color = Color(1.0, 0.6, 0.2)
@export var light_energy: float = 3.0
@export var light_range: float = 8.0

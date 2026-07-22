extends Resource
class_name ItemData
## 物品基类：所有物品（材料/装备/武器）的数据定义
## 新增物品 = 在 data/items/ 下新建一个 .tres，无需改代码

enum ItemType { MATERIAL, EQUIPMENT, WEAPON }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var item_type: ItemType = ItemType.MATERIAL
@export var max_stack: int = 99
@export var heal_amount: float = 0.0  # >0 表示可食用回血
@export var ui_color: Color = Color(0.7, 0.7, 0.7)  # 背包格子里的底色（无图标时代替图标）

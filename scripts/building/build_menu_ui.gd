extends CanvasLayer
class_name BuildMenuUI
## 建造菜单：列出所有建筑配方，显示材料消耗，点击进入放置模式

signal recipe_selected(data: Resource)

const ItemDBClass := preload("res://scripts/core/item_db.gd")

const PANEL_W := 300.0
const ROW_H := 56

var _panel: Panel
var _inventory: Node


func setup(recipes: Array, inventory: Node) -> void:
	_inventory = inventory
	layer = 70
	_build(recipes)
	get_tree().root.size_changed.connect(_layout)
	_layout()
	hide()
	if inventory and inventory.has_signal("changed"):
		inventory.changed.connect(_refresh_afford.bind(recipes))


func _build(recipes: Array) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.12, 0.92)
	style.border_width_bottom = 2; style.border_width_left = 2
	style.border_width_right = 2; style.border_width_top = 2
	style.border_color = Color(0.5, 0.5, 0.6, 0.5)
	style.corner_radius_top_left = 10; style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10; style.corner_radius_bottom_right = 10
	_panel.add_theme_stylebox_override("panel", style)
	_panel.size = Vector2(PANEL_W, 60 + recipes.size() * (ROW_H + 8) + 16)
	root.add_child(_panel)

	var title := Label.new()
	title.text = "建造　（B 关闭）"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	title.size = Vector2(PANEL_W, 34)
	title.position = Vector2(0, 10)
	_panel.add_child(title)

	var y := 50
	for data in recipes:
		var btn := Button.new()
		btn.name = "Recipe_" + data.id
		btn.text = "%s\n%s" % [data.display_name, _cost_text(data.cost)]
		btn.size = Vector2(PANEL_W - 24, ROW_H)
		btn.position = Vector2(12, y)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_recipe_clicked.bind(data))
		_panel.add_child(btn)
		y += ROW_H + 8

	_refresh_afford(recipes)


func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in cost:
		var item := ItemDBClass.get_item(k)
		var item_name: String = item.get("display_name") if item else k
		parts.append("%s x%d" % [item_name, int(cost[k])])
	return "需要: " + (" ".join(parts) if parts else "无")


## 材料不足的配方置灰
func _refresh_afford(recipes: Array) -> void:
	if _inventory == null:
		return
	for data in recipes:
		var btn: Button = _panel.get_node_or_null("Recipe_" + data.id)
		if btn:
			btn.disabled = not _inventory.has_cost(data.cost)


func _on_recipe_clicked(data: Resource) -> void:
	recipe_selected.emit(data)


func _layout() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = Vector2(24, (vs.y - _panel.size.y) * 0.5)

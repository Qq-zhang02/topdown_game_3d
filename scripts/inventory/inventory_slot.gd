extends Panel
class_name InventorySlot
## 背包格子：负责显示一个格位并处理拖拽 + 右键菜单

var index: int = -1
var ui: CanvasLayer  # InventoryUI


func _get_drag_data(_pos: Vector2) -> Variant:
	if ui == null:
		return null
	var st = ui.get_stack(index)
	if st == null:
		return null

	var preview := Panel.new()
	preview.custom_minimum_size = Vector2(72, 40)
	var label := Label.new()
	label.text = "%s x%d" % [st.item.get("display_name"), st.count]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(72, 40)
	label.add_theme_font_size_override("font_size", 13)
	preview.add_child(label)
	set_drag_preview(preview)
	return {"from": index}


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("from") and int(data["from"]) != index


func _drop_data(_pos: Vector2, data: Variant) -> void:
	if ui:
		ui.move_slot(int(data["from"]), index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if ui and ui.has_method("_show_context_menu"):
			ui._show_context_menu(index, get_global_mouse_position())
			accept_event()

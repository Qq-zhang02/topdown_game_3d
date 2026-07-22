extends CanvasLayer
class_name InventoryUI
## 背包界面：8x4 格子，Tab 开关，鼠标拖拽整理，右键使用物品

signal item_used(item_data: Resource, slot_index: int)

const SlotClass := preload("res://scripts/inventory/inventory_slot.gd")

const COLS := 8
const ROWS := 4
const SLOT_SIZE := Vector2(76, 76)
const GAP := 6
const PANEL_PAD := 16
const TITLE_H := 40

var _inventory: Node
var _panel: Panel
var _slots: Array[Panel] = []
var _name_labels: Array[Label] = []
var _count_labels: Array[Label] = []
var _bg_styles: Array[StyleBoxFlat] = []


func setup(inv: Node) -> void:
	_inventory = inv
	layer = 60
	add_to_group("inventory_ui")
	_build()
	_refresh()
	inv.changed.connect(_refresh)
	get_tree().root.size_changed.connect(_layout)
	_layout()
	hide()


func get_stack(index: int) -> ItemStack:
	return _inventory.get_stack(index)


func move_slot(from_idx: int, to_idx: int) -> void:
	_inventory.move_slot(from_idx, to_idx)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		visible = not visible
		get_viewport().set_input_as_handled()

	if not visible:
		return

	# 右键使用物品
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var idx := _get_hovered_slot_index()
		if idx >= 0:
			var st: ItemStack = _inventory.get_stack(idx) as ItemStack
			if st and st.item.get("heal_amount") > 0.0:
				_consume_slot(idx, st)
				get_viewport().set_input_as_handled()


func _build() -> void:
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
	root.add_child(_panel)

	var title := Label.new()
	title.text = "背包　（Tab 关闭 · 拖拽整理）"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	title.size = Vector2(_panel_width(), TITLE_H)
	title.position = Vector2(0, 6)
	_panel.add_child(title)

	for i in range(COLS * ROWS):
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.16, 0.16, 0.18, 0.85)
		bg.border_width_bottom = 1; bg.border_width_left = 1
		bg.border_width_right = 1; bg.border_width_top = 1
		bg.border_color = Color(0.35, 0.35, 0.40, 0.6)
		bg.corner_radius_top_left = 6; bg.corner_radius_top_right = 6
		bg.corner_radius_bottom_left = 6; bg.corner_radius_bottom_right = 6
		_bg_styles.append(bg)

		var slot: Panel = SlotClass.new()
		slot.name = "Slot_%d" % i
		slot.index = i
		slot.ui = self
		slot.custom_minimum_size = SLOT_SIZE
		slot.size = SLOT_SIZE
		slot.position = Vector2(
			PANEL_PAD + (i % COLS) * (SLOT_SIZE.x + GAP),
			TITLE_H + PANEL_PAD + (i / COLS) * (SLOT_SIZE.y + GAP)
		)
		slot.add_theme_stylebox_override("panel", bg)
		_panel.add_child(slot)
		_slots.append(slot)

		var name_label := Label.new()
		name_label.size = Vector2(SLOT_SIZE.x, SLOT_SIZE.y - 16)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(name_label)
		_name_labels.append(name_label)

		var count_label := Label.new()
		count_label.size = Vector2(SLOT_SIZE.x - 6, 18)
		count_label.position = Vector2(0, SLOT_SIZE.y - 20)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.add_theme_font_size_override("font_size", 13)
		count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		slot.add_child(count_label)
		_count_labels.append(count_label)


func _panel_width() -> float:
	return COLS * SLOT_SIZE.x + (COLS - 1) * GAP + PANEL_PAD * 2


func _panel_height() -> float:
	return TITLE_H + ROWS * SLOT_SIZE.y + (ROWS - 1) * GAP + PANEL_PAD * 2


func _layout() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(_panel_width(), _panel_height())
	_panel.position = (vs - _panel.size) * 0.5


func _refresh() -> void:
	if not _inventory:
		return
	for i in range(_slots.size()):
		var st: ItemStack = _inventory.get_stack(i) as ItemStack
		var name_label := _name_labels[i]
		var count_label := _count_labels[i]
		var bg := _bg_styles[i]
		if st:
			name_label.text = st.item.get("display_name")
			count_label.text = "x%d" % st.count if st.count > 1 else ""
			var c: Color = st.item.get("ui_color")
			bg.bg_color = Color(c.r * 0.45, c.g * 0.45, c.b * 0.45, 0.90)
			bg.border_color = Color(c.r, c.g, c.b, 0.8)
		else:
			name_label.text = ""
			count_label.text = ""
			bg.bg_color = Color(0.14, 0.14, 0.16, 0.70)
			bg.border_color = Color(0.35, 0.35, 0.40, 0.4)

			# 可食用物品标记
			if st and st.item.get("heal_amount") > 0.0:
				count_label.text = ("♥%d  x%d" % [int(st.item.get("heal_amount")), st.count]) if st.count > 1 else ("♥%d" % int(st.item.get("heal_amount")))


func _get_hovered_slot_index() -> int:
	var mp := _panel.get_local_mouse_position()
	if mp.x < PANEL_PAD or mp.y < TITLE_H + PANEL_PAD:
		return -1
	for i in range(_slots.size()):
		var slot := _slots[i]
		var r := Rect2(slot.position, slot.size)
		if r.has_point(mp):
			return i
	return -1


func _consume_slot(idx: int, st: ItemStack) -> void:
	var heal: float = st.item.get("heal_amount")
	st.count -= 1
	if st.count <= 0:
		_inventory.slots[idx] = null
	_inventory.changed.emit()
	item_used.emit(st.item, idx)

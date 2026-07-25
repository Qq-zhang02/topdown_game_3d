extends CanvasLayer
class_name InventoryUI
## 背包界面：8x4 格子，Tab 开关，鼠标拖拽整理，右键菜单（装备/卸下/使用）

signal item_used(item_data: Resource, slot_index: int)

const SlotClass := preload("res://scripts/inventory/inventory_slot.gd")

const COLS := 8
const ROWS := 4
const SLOT_SIZE := Vector2(76, 76)
const GAP := 6
const PANEL_PAD := 16
const TITLE_H := 40

var _inventory: Node
var _equip_mgr: Node
var _panel: Panel
var _slots: Array[Panel] = []
var _name_labels: Array[Label] = []
var _count_labels: Array[Label] = []
var _bg_styles: Array[StyleBoxFlat] = []
var _context_menu: PopupMenu
var _context_slot: int = -1


func setup(inv: Node, equip_mgr: Node) -> void:
	_inventory = inv
	_equip_mgr = equip_mgr
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

	# 右键菜单已由 InventorySlot._gui_input 处理，这里不再处理右键


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
	title.text = "背包　（Tab 关闭 · 拖拽整理 · 右键操作）"
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

	# 右键菜单
	_context_menu = PopupMenu.new()
	_context_menu.name = "ContextMenu"
	_context_menu.add_item("装备", 0)
	_context_menu.add_item("卸下", 1)
	_context_menu.add_item("使用", 2)
	_context_menu.id_pressed.connect(_on_context_action)
	root.add_child(_context_menu)


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
			var item_id: String = st.item.get("id")
			
			if _equip_mgr and _equip_mgr.is_item_equipped(item_id):
				bg.bg_color = Color(c.r * 0.55, c.g * 0.55, c.b * 0.35, 1.0)
				bg.border_color = Color(1.0, 0.85, 0.2, 1.0)
				bg.border_width_bottom = 2; bg.border_width_left = 2
				bg.border_width_right = 2; bg.border_width_top = 2
			else:
				bg.bg_color = Color(c.r * 0.45, c.g * 0.45, c.b * 0.45, 0.90)
				bg.border_color = Color(c.r, c.g, c.b, 0.8)
				bg.border_width_bottom = 1; bg.border_width_left = 1
				bg.border_width_right = 1; bg.border_width_top = 1
			
			if st.item.get("heal_amount") > 0.0:
				count_label.text = ("+%d♥ x%d" % [int(st.item.get("heal_amount")), st.count]) if st.count > 1 else ("+%d♥" % int(st.item.get("heal_amount")))
		else:
			name_label.text = ""
			count_label.text = ""
			bg.bg_color = Color(0.14, 0.14, 0.16, 0.70)
			bg.border_color = Color(0.35, 0.35, 0.40, 0.4)


func _show_context_menu(slot_index: int, screen_pos: Vector2) -> void:
	_context_slot = slot_index
	var st = _inventory.get_stack(slot_index)
	if not st:
		return

	var item = st.item
	var item_id: String = item.get("id")
	var itype: int = item.get("item_type")
	var is_cons: bool = item.get("heal_amount") > 0.0

	# 根据物品类型和装备状态设置菜单项
	if itype == 1: # EQUIPMENT — 功能装备
		var is_equipped: bool = _equip_mgr.is_utility_equipped(item_id)
		_context_menu.set_item_disabled(0, is_equipped)   # 装备
		_context_menu.set_item_disabled(1, not is_equipped) # 卸下
		_context_menu.set_item_disabled(2, true)            # 使用 — 灰色

	elif itype == 2: # WEAPON
		var is_equipped: bool = _equip_mgr.is_weapon_equipped(item_id)
		_context_menu.set_item_disabled(0, is_equipped)
		_context_menu.set_item_disabled(1, not is_equipped)
		_context_menu.set_item_disabled(2, true)

	elif is_cons: # 消耗品
		var is_equipped: bool = _equip_mgr.is_consumable_equipped(item_id)
		_context_menu.set_item_disabled(0, is_equipped)
		_context_menu.set_item_disabled(1, not is_equipped)
		_context_menu.set_item_disabled(2, false)

	else:
		return # 普通材料不显示菜单

	_context_menu.position = screen_pos
	_context_menu.popup()


func _on_context_action(id: int) -> void:
	if _context_slot < 0:
		return
	var st = _inventory.get_stack(_context_slot)
	if not st:
		return

	match id:
		0: # 装备
			if _equip_mgr and _equip_mgr.has_method("equip_from_inventory"):
				_equip_mgr.equip_from_inventory(_context_slot)
		1: # 卸下
			if _equip_mgr and _equip_mgr.has_method("unequip_item_from_inventory"):
				_equip_mgr.unequip_item_from_inventory(_context_slot)
		2: # 使用
			if _equip_mgr and _equip_mgr.has_method("use_from_inventory"):
				_equip_mgr.use_from_inventory(_context_slot)
				item_used.emit(st.item, _context_slot)

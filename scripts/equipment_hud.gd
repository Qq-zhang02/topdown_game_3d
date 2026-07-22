extends Control
class_name EquipmentHUD
## 底部装备栏：只显示 equipped=true 的装备，当前装备高亮

const MAX_SLOTS := 10
const SLOT_SIZE := Vector2(64, 64)
const GAP := 6

var _manager: Node
var _slots: Array[Panel] = []
var _labels: Array[Label] = []
var _bg_styles: Array[StyleBoxFlat] = []
var _initialized: bool = false
var _f_label: Label


func setup(manager: Node) -> void:
	_manager = manager
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_slots()
	_update_slots()
	if manager.has_signal("equipment_cycled"):
		manager.connect("equipment_cycled", _on_equipment_changed)
	_initialized = true


func _ready() -> void:
	if _initialized:
		call_deferred("_slots_arrange")
	get_tree().root.size_changed.connect(_slots_arrange)


func _get_key_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			return ev.as_text().trim_suffix(" (Physical)")
	return "?"


func refresh_key_label() -> void:
	if _f_label:
		_f_label.text = _get_key_label("cycle_equipment")


func _build_slots() -> void:
	_f_label = Label.new()
	_f_label.name = "FKeyHint"
	_f_label.text = _get_key_label("cycle_equipment")
	_f_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_f_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_f_label.add_theme_font_size_override("font_size", 16)
	_f_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 0.7))
	_f_label.size = Vector2(24, SLOT_SIZE.y)
	add_child(_f_label)

	for i in range(MAX_SLOTS):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.10, 0.10, 0.60)
		style.border_width_bottom = 2; style.border_width_left = 2
		style.border_width_right = 2; style.border_width_top = 2
		style.border_color = Color(0.25, 0.25, 0.25, 0.50)
		style.corner_radius_top_left = 5; style.corner_radius_top_right = 5
		style.corner_radius_bottom_left = 5; style.corner_radius_bottom_right = 5
		_bg_styles.append(style)

		var panel := Panel.new()
		panel.name = "Slot_%d" % i
		panel.custom_minimum_size = SLOT_SIZE
		panel.size = SLOT_SIZE
		panel.add_theme_stylebox_override("panel", style)
		_slots.append(panel)
		add_child(panel)

		var label := Label.new()
		label.name = "Name"
		label.size = SLOT_SIZE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.85))
		_labels.append(label)
		panel.add_child(label)


func _slots_arrange() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var total_w: float = MAX_SLOTS * SLOT_SIZE.x + (MAX_SLOTS - 1) * GAP
	var label_w: float = _f_label.size.x + 6
	var start_x: float = (vs.x - total_w - label_w) * 0.5
	var y: float = vs.y - SLOT_SIZE.y - 12

	_f_label.position = Vector2(start_x, y + (SLOT_SIZE.y - _f_label.size.y) * 0.5)

	for i in range(MAX_SLOTS):
		_slots[i].position = Vector2(start_x + label_w + i * (SLOT_SIZE.x + GAP), y)


func _update_slots() -> void:
	if not _manager:
		return

	var count: int = _manager.get_count()
	var active_slot: int = _manager.get_active_slot()

	for i in range(MAX_SLOTS):
		var style := _bg_styles[i]
		var label := _labels[i]

		if i < count:
			label.text = _manager.get_name_at(i)
			if i == active_slot:
				style.bg_color = Color(0.25, 0.50, 0.85, 0.80)
				style.border_color = Color(0.45, 0.80, 1.0, 1.0)
				label.add_theme_color_override("font_color", Color.WHITE)
			else:
				style.bg_color = Color(0.12, 0.12, 0.12, 0.65)
				style.border_color = Color(0.30, 0.30, 0.30, 0.55)
				label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.70))
		else:
			label.text = ""
			style.bg_color = Color(0.06, 0.06, 0.06, 0.25)
			style.border_color = Color(0.20, 0.20, 0.20, 0.20)


func _on_equipment_changed(_idx: int, _name: String) -> void:
	_update_slots()

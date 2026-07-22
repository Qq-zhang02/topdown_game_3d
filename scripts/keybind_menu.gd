extends CanvasLayer
class_name KeybindMenu
## 按键设置面板

signal bindings_changed

const ACTIONS := [
	{"id": "move_up",     "label": "前进",     "default": KEY_W},
	{"id": "move_down",   "label": "后退",     "default": KEY_S},
	{"id": "move_left",   "label": "左移",     "default": KEY_A},
	{"id": "move_right",  "label": "右移",     "default": KEY_D},
	{"id": "cycle_equipment",  "label": "切换装备", "default": KEY_F},
	{"id": "jump",        "label": "跳跃",     "default": KEY_SPACE},
	{"id": "inventory_toggle", "label": "背包", "default": KEY_TAB},
	{"id": "build_menu",  "label": "建造菜单", "default": KEY_B},
	{"id": "build_rotate", "label": "旋转建筑", "default": KEY_R},
	{"id": "pause",       "label": "暂停",     "default": KEY_ESCAPE},
]

const CONFIG_PATH := "user://keybinds.cfg"

var _root: Control
var _listening_action: String = ""
var _row_btns: Dictionary = {}
var _panel: Panel


func _ready() -> void:
	layer = 400
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_load_bindings()
	_layout_ui()
	get_tree().root.size_changed.connect(_layout_ui)
	hide()


# ═══════════════════════════════════════════
# 持久化
# ═══════════════════════════════════════════

func _load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return

	for action_info in ACTIONS:
		var action_id: String = action_info.id
		var key_str: String = cfg.get_value("bindings", action_id, "")
		if key_str != "":
			var kc: Key = OS.find_keycode_from_string(key_str)
			if kc != KEY_NONE:
				_apply_binding(action_id, kc)

	_refresh_all_buttons()


func _save_bindings() -> void:
	var cfg := ConfigFile.new()
	for action_info in ACTIONS:
		var action_id: String = action_info.id
		var events := InputMap.action_get_events(action_id)
		for ev in events:
			if ev is InputEventKey:
				cfg.set_value("bindings", action_id, ev.as_text_keycode())
				break
	cfg.save(CONFIG_PATH)


func _reset_defaults() -> void:
	DirAccess.remove_absolute(CONFIG_PATH)
	for action_info in ACTIONS:
		_apply_binding(action_info.id, action_info.default)
	_save_bindings()
	_refresh_all_buttons()
	bindings_changed.emit()


# ═══════════════════════════════════════════
# 核心
# ═══════════════════════════════════════════

func _apply_binding(action: String, keycode: Key) -> void:
	# 清掉旧绑定，建新键事件（keycode 和 physical_keycode 都必须设）
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _get_key_text(action: String) -> String:
	var events := InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			return ev.as_text().trim_suffix(" (Physical)")
	return "未绑定"


# ═══════════════════════════════════════════
# UI
# ═══════════════════════════════════════════

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "KeybindRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	_root.add_child(bg)

	_panel = Panel.new()
	_panel.size = Vector2(400, 545)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	style.border_width_bottom = 2; style.border_width_left = 2
	style.border_width_right = 2; style.border_width_top = 2
	style.border_color = Color(0.5, 0.5, 0.6, 0.5)
	style.corner_radius_top_left = 10; style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10; style.corner_radius_bottom_right = 10
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	var title := Label.new()
	title.text = "按键设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size = Vector2(400, 35)
	title.position = Vector2(0, 12)
	_panel.add_child(title)

	var hint := Label.new()
	hint.text = "点击按键 → 按下新键 → 确认"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint.size = Vector2(400, 20)
	hint.position = Vector2(0, 47)
	_panel.add_child(hint)

	var y := 75
	for action_info in ACTIONS:
		var action_id: String = action_info.id

		var name_label := Label.new()
		name_label.text = action_info.label
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		name_label.size = Vector2(180, 30)
		name_label.position = Vector2(25, y)
		_panel.add_child(name_label)

		var key_btn := Button.new()
		key_btn.text = _get_key_text(action_id)
		key_btn.size = Vector2(130, 30)
		key_btn.position = Vector2(230, y)
		key_btn.add_theme_font_size_override("font_size", 14)
		key_btn.pressed.connect(_on_key_clicked.bind(action_id, key_btn))
		_panel.add_child(key_btn)

		_row_btns[action_id] = key_btn
		y += 38

	# ── 按钮行 ──
	var btn_y := y + 10
	var reset_btn := Button.new()
	reset_btn.text = "重置默认"
	reset_btn.size = Vector2(110, 36)
	reset_btn.position = Vector2(40, btn_y)
	reset_btn.add_theme_font_size_override("font_size", 14)
	reset_btn.pressed.connect(_reset_defaults)
	_panel.add_child(reset_btn)

	var back_btn := Button.new()
	back_btn.text = "← 返回"
	back_btn.size = Vector2(110, 36)
	back_btn.position = Vector2(250, btn_y)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.pressed.connect(hide)
	_panel.add_child(back_btn)


func _on_key_clicked(action: String, btn: Button) -> void:
	_listening_action = action
	btn.text = "... 按任意键 ..."
	btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))


func _input(event: InputEvent) -> void:
	if not visible or _listening_action == "":
		return

	if event is InputEventKey and event.pressed:
		# ESC 只能绑暂停
		if event.keycode == KEY_ESCAPE and _listening_action != "pause":
			_listening_action = ""
			_refresh_all_buttons()
			get_viewport().set_input_as_handled()
			return

		# 检查冲突：已被其他动作用的键，先清除旧绑定
		for action_info in ACTIONS:
			var aid: String = action_info.id
			if aid == _listening_action:
				continue
			if _get_key_text(aid) == event.as_text().trim_suffix(" (Physical)"):
				InputMap.action_erase_events(aid)

		_apply_binding(_listening_action, event.keycode)
		_save_bindings()
		_listening_action = ""
		_refresh_all_buttons()
		bindings_changed.emit()
		get_viewport().set_input_as_handled()


func _refresh_all_buttons() -> void:
	for action_info in ACTIONS:
		var action_id: String = action_info.id
		if _row_btns.has(action_id):
			var btn: Button = _row_btns[action_id]
			btn.text = _get_key_text(action_id)
			btn.remove_theme_color_override("font_color")


## 窗口缩放时重新居中 + 按比例缩放
func _layout_ui() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	const REF: Vector2 = Vector2(1920.0, 1080.0)
	var scale: float = clampf(minf(vs.x / REF.x, vs.y / REF.y), 0.6, 1.6)
	_panel.scale = Vector2(scale, scale)
	var pw: float = 400.0 * scale
	var ph: float = 545.0 * scale
	_panel.position = Vector2((vs.x - pw) / 2.0, (vs.y - ph) / 2.0)

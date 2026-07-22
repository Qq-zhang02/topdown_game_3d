extends CanvasLayer
class_name SaveSelectScreen
## 存档选择界面：5个槽位，可新建/进入/删除存档

signal load_game(save_data: Dictionary, slot: int)
signal new_game(slot: int)

const MAX_SLOTS := 5

var _root: Control
var _slot_panels: Array[Panel] = []
var _title: Label
var _saves_info: Array[Dictionary] = []


func _ready() -> void:
	layer = 500
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_saves()
	_build_ui()
	get_tree().root.size_changed.connect(_layout_ui)


func _refresh_saves() -> void:
	_saves_info = SaveManager.list_saves()


# ═══════════════════════════════════════════
# UI 构建
# ═══════════════════════════════════════════

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "SaveSelectRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.08, 0.12, 0.97)
	_root.add_child(bg)

	# ── 标题 ──
	_title = Label.new()
	_title.text = "TopDown Explorer"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_title.size = Vector2(600, 55)
	_root.add_child(_title)

	var subtitle := Label.new()
	subtitle.text = "选择存档"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	subtitle.size = Vector2(200, 28)
	_root.add_child(subtitle)

	# ── 存档槽位 ──
	const SLOT_W: float = 520.0
	const SLOT_H: float = 100.0
	const GAP: float = 14.0
	const START_Y: float = 140.0
	const REF_X: float = 1920.0
	var slot_x: float = (REF_X - SLOT_W) / 2.0

	for i in range(MAX_SLOTS):
		var y := START_Y + i * (SLOT_H + GAP)
		var info: Dictionary = _saves_info[i]
		var empty: bool = info.get("empty", true)

		# 面板背景
		var panel := Panel.new()
		panel.name = "SlotPanel_%d" % i
		panel.size = Vector2(SLOT_W, SLOT_H)
		panel.position = Vector2(slot_x, y)
		var style := StyleBoxFlat.new()
		if empty:
			style.bg_color = Color(0.10, 0.12, 0.16, 0.85)
			style.border_color = Color(0.25, 0.30, 0.40, 0.4)
		else:
			style.bg_color = Color(0.14, 0.18, 0.22, 0.9)
			style.border_color = Color(0.35, 0.50, 0.65, 0.6)
		style.border_width_bottom = 2; style.border_width_left = 2
		style.border_width_right = 2; style.border_width_top = 2
		style.corner_radius_top_left = 10; style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10; style.corner_radius_bottom_right = 10
		panel.add_theme_stylebox_override("panel", style)
		_root.add_child(panel)
		_slot_panels.append(panel)

		# 槽位编号
		var num_label := Label.new()
		num_label.text = "存档 %d" % (i + 1)
		num_label.position = Vector2(18, 14)
		num_label.size = Vector2(80, 24)
		num_label.add_theme_font_size_override("font_size", 17)
		num_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.62))
		panel.add_child(num_label)

		# 存档信息
		var info_label := Label.new()
		info_label.name = "InfoLabel"
		info_label.position = Vector2(18, 44)
		info_label.size = Vector2(370, 42)
		info_label.add_theme_font_size_override("font_size", 13)
		info_label.autowrap_mode = TextServer.AUTOWRAP_OFF

		if empty:
			info_label.text = "空存档 — 点击右侧按钮创建新游戏"
			info_label.add_theme_color_override("font_color", Color(0.35, 0.42, 0.55))
		else:
			var time_str := _format_play_time(info.get("play_time", 0.0))
			var ts: String = info.get("timestamp", "")
			if ts.length() >= 10:
				ts = ts.substr(0, 10)
			info_label.text = "游戏时长: %s    最后保存: %s    血量: %.0f%%" % [
				time_str, ts, info.get("player_health", 100.0)
			]
			info_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
		panel.add_child(info_label)

		# 进入 / 新建 按钮
		var action_btn := Button.new()
		action_btn.name = "ActionBtn"
		action_btn.size = Vector2(90, 34)
		action_btn.position = Vector2(SLOT_W - 90 - 55, (SLOT_H - 34) / 2)
		action_btn.add_theme_font_size_override("font_size", 14)
		if empty:
			action_btn.text = "新建"
		else:
			action_btn.text = "进入"
		action_btn.pressed.connect(_on_slot_clicked.bind(i))
		panel.add_child(action_btn)

		# 删除按钮（仅非空槽位）
		if not empty:
			var del_btn := Button.new()
			del_btn.name = "DelBtn"
			del_btn.text = "✕"
			del_btn.size = Vector2(36, 34)
			del_btn.position = Vector2(SLOT_W - 36 - 12, (SLOT_H - 34) / 2)
			del_btn.add_theme_font_size_override("font_size", 14)
			del_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.35))
			del_btn.pressed.connect(_on_delete_clicked.bind(i))
			panel.add_child(del_btn)

	# ── 底部提示 ──
	var hint := Label.new()
	hint.text = "最多 %d 个存档 · 点击存档进入游戏" % MAX_SLOTS
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.35, 0.38, 0.48))
	hint.size = Vector2(500, 22)
	_root.add_child(hint)

	# ── 存档路径设置 ──
	const PATH_Y: float = START_Y + MAX_SLOTS * (SLOT_H + GAP) + 45.0

	var path_label := Label.new()
	path_label.name = "PathLabel"
	path_label.text = "存档路径: " + _shorten_path(SaveManager.get_display_path())
	path_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	path_label.add_theme_font_size_override("font_size", 12)
	path_label.add_theme_color_override("font_color", Color(0.45, 0.48, 0.55))
	path_label.size = Vector2(SLOT_W, 20)
	_root.add_child(path_label)

	var btn_path := Button.new()
	btn_path.name = "PathBtn"
	btn_path.text = "设置路径"
	btn_path.size = Vector2(100, 28)
	btn_path.add_theme_font_size_override("font_size", 12)
	btn_path.pressed.connect(_on_set_path)
	_root.add_child(btn_path)

	var btn_reset := Button.new()
	btn_reset.name = "ResetPathBtn"
	btn_reset.text = "恢复默认"
	btn_reset.size = Vector2(100, 28)
	btn_reset.add_theme_font_size_override("font_size", 12)
	btn_reset.pressed.connect(_on_reset_path)
	_root.add_child(btn_reset)

	# FileDialog 选择文件夹
	var fd := FileDialog.new()
	fd.name = "PathFileDialog"
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fd.title = "选择存档目录"
	fd.size = Vector2(700, 500)
	fd.dir_selected.connect(_on_path_selected)
	_root.add_child(fd)

	# 定位
	_layout_ui()


# ═══════════════════════════════════════════
# 交互
# ═══════════════════════════════════════════

func _on_slot_clicked(slot: int) -> void:
	var info: Dictionary = _saves_info[slot]
	if info.get("empty", true):
		new_game.emit(slot)
	else:
		var data := SaveManager.load_save(slot)
		if not data.is_empty():
			load_game.emit(data, slot)


func _on_delete_clicked(slot: int) -> void:
	# 弹出确认
	var confirm := AcceptDialog.new()
	confirm.title = "删除存档"
	confirm.dialog_text = "确定要删除存档 %d 吗？此操作不可撤销。" % (slot + 1)
	confirm.size = Vector2(350, 100)
	confirm.confirmed.connect(_do_delete.bind(slot, confirm))
	_root.add_child(confirm)
	confirm.popup_centered()


func _do_delete(slot: int, dialog: AcceptDialog) -> void:
	SaveManager.delete_save(slot)
	dialog.queue_free()
	_rebuild()


# ═══════════════════════════════════════════
# 重建 UI
# ═══════════════════════════════════════════

func _rebuild() -> void:
	for child in _root.get_children():
		child.queue_free()
	_slot_panels.clear()
	_refresh_saves()
	_build_ui()


# ═══════════════════════════════════════════
# 路径设置
# ═══════════════════════════════════════════

func _on_set_path() -> void:
	var fd := _root.get_node("PathFileDialog") as FileDialog
	if fd:
		# 从当前路径打开
		var current := SaveManager.get_save_dir()
		fd.current_dir = current if not current.begins_with("user://") else ProjectSettings.globalize_path(current)
		fd.popup_centered()


func _on_reset_path() -> void:
	SaveManager.reset_save_dir()
	_refresh_path_display()
	_refresh_saves()
	_rebuild_slots()


func _on_path_selected(dir: String) -> void:
	# 如果选中的目录在项目目录下，转为 res://
	var project_dir := ProjectSettings.globalize_path("res://")
	if dir.begins_with(project_dir):
		var rel := dir.trim_prefix(project_dir)
		SaveManager.set_save_dir("res://" + rel)
	else:
		SaveManager.set_save_dir(dir)
	_refresh_path_display()
	_refresh_saves()
	_rebuild_slots()


func _refresh_path_display() -> void:
	var lbl := _root.get_node_or_null("PathLabel") as Label
	if lbl:
		lbl.text = "存档路径: " + _shorten_path(SaveManager.get_display_path())


func _rebuild_slots() -> void:
	# 只重建槽位面板，不重建整个 UI
	for panel in _slot_panels:
		panel.queue_free()
	_slot_panels.clear()
	# 需要在 _build_ui 中调用的槽位构建逻辑...
	# 简化处理：全量重建
	_rebuild()


func _shorten_path(path: String) -> String:
	if path.length() > 70:
		return "..." + path.right(67)
	return path


func _format_play_time(seconds: float) -> String:
	var total := int(seconds)
	var h := total / 3600
	var m := (total % 3600) / 60
	if h > 0:
		return "%d小时%d分钟" % [h, m]
	return "%d分钟" % m


# ═══════════════════════════════════════════
# 窗口缩放适配
# ═══════════════════════════════════════════

func _layout_ui() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	const REF: Vector2 = Vector2(1920.0, 1080.0)
	var scale: float = clampf(minf(vs.x / REF.x, vs.y / REF.y), 0.6, 1.6)
	_root.scale = Vector2(scale, scale)
	_root.position = (vs - REF * scale) / 2.0

	_title.position.x = (REF.x - _title.size.x) / 2.0
	_title.position.y = 30.0

	const SLOT_W: float = 520.0
	const SLOT_H: float = 100.0
	const GAP: float = 14.0
	const START_Y: float = 140.0
	var slot_x: float = (REF.x - SLOT_W) / 2.0

	# 重定位所有槽位面板
	for i in range(MAX_SLOTS):
		var panel_name := "SlotPanel_%d" % i
		if _root.has_node(panel_name):
			var panel := _root.get_node(panel_name)
			panel.position = Vector2(slot_x, START_Y + i * (SLOT_H + GAP))

	const PATH_Y: float = START_Y + MAX_SLOTS * (SLOT_H + GAP) + 45.0

	for child in _root.get_children():
		if child is Label and child.text.begins_with("选择存档"):
			child.position = Vector2((REF.x - child.size.x) / 2.0, 85.0)
		elif child is Label and child.text.begins_with("最多"):
			child.position = Vector2((REF.x - child.size.x) / 2.0, START_Y + MAX_SLOTS * (SLOT_H + GAP) + 15.0)
		elif child is Label and child.name == "PathLabel":
			child.position = Vector2(slot_x, PATH_Y)
		elif child is Button and child.name == "PathBtn":
			child.position = Vector2(slot_x + SLOT_W - 220, PATH_Y - 2)
		elif child is Button and child.name == "ResetPathBtn":
			child.position = Vector2(slot_x + SLOT_W - 110, PATH_Y - 2)

extends CanvasLayer
class_name SaveSelectScreen
## 存档选择界面：左侧3D角色预览 + 5个存档槽位 + 路径设置

signal load_game(save_data: Dictionary, slot: int)
signal new_game(slot: int)

const MAX_SLOTS := 5
const DEFAULT_MODEL := "res://models/character/character-archer.glb"
const DEFAULT_SKIN := "res://models/character/colormap.png"

# 动画预览列表
const PREVIEW_ANIMS := [
	"idle", "walk", "sprint", "jump", "fall", "die", "crouch",
	"static", "sit", "drive", "pick-up",
	"attack-melee-left", "attack-melee-right", "attack-kick-left", "attack-kick-right",
	"holding-both", "holding-both-shoot", "holding-left", "holding-left-shoot",
	"holding-right", "holding-right-shoot",
	"interact-left", "interact-right",
	"emote-no", "emote-yes",
	"wheelchair-sit", "wheelchair-look-left", "wheelchair-look-right",
	"wheelchair-move-forward", "wheelchair-move-back", "wheelchair-move-left", "wheelchair-move-right",
]

# 布局常量（1920x1080 参考）
const PREVIEW_X: float = 60.0
const PREVIEW_Y: float = 140.0
const PREVIEW_SIZE: float = 240.0
const SLOT_X: float = 340.0
const SLOT_Y: float = 140.0
const SLOT_W: float = 520.0
const SLOT_H: float = 100.0
const SLOT_GAP: float = 14.0

var _root: Control
var _slot_panels: Array[Panel] = []
var _title: Label
var _saves_info: Array[Dictionary] = []
var _preview_viewport: SubViewport
var _preview_model: Node3D
var _playing_anim: bool = false
var _anim_buttons: Array[Button] = []


func _ready() -> void:
	layer = 500
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_saves()
	_build_ui()
	_create_preview()
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

	# ── 左侧预览面板背景 ──
	var preview_bg := Panel.new()
	preview_bg.name = "PreviewBg"
	preview_bg.size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
	preview_bg.position = Vector2(PREVIEW_X - 10, PREVIEW_Y - 10)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.05, 0.05, 0.08, 0.8)
	pstyle.border_color = Color(0.3, 0.3, 0.4, 0.5)
	pstyle.border_width_bottom = 2; pstyle.border_width_left = 2
	pstyle.border_width_right = 2; pstyle.border_width_top = 2
	pstyle.corner_radius_top_left = 10; pstyle.corner_radius_top_right = 10
	pstyle.corner_radius_bottom_left = 10; pstyle.corner_radius_bottom_right = 10
	preview_bg.add_theme_stylebox_override("panel", pstyle)
	_root.add_child(preview_bg)

	# ── 存档槽位 ──
	for i in range(MAX_SLOTS):
		var y := SLOT_Y + i * (SLOT_H + SLOT_GAP)
		var info: Dictionary = _saves_info[i]
		var empty: bool = info.get("empty", true)

		var panel := Panel.new()
		panel.name = "SlotPanel_%d" % i
		panel.size = Vector2(SLOT_W, SLOT_H)
		panel.position = Vector2(SLOT_X, y)
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

		# 删除按钮
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

	# ── 存档路径设置（两行，不重叠） ──
	var path_bottom: float = SLOT_Y + MAX_SLOTS * (SLOT_H + SLOT_GAP) + 15.0
	var path_label := Label.new()
	path_label.name = "PathLabel"
	path_label.text = "存档路径: " + _shorten_path(SaveManager.get_display_path())
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

	# ── 动画预览按钮（左侧预览区下方）──
	var anim_label := Label.new()
	anim_label.name = "AnimLabel"
	anim_label.text = "动画预览:"
	anim_label.add_theme_font_size_override("font_size", 12)
	anim_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	anim_label.size = Vector2(200, 18)
	_root.add_child(anim_label)

	const ANIM_COLS := 3
	var anim_btn_w: float = 73.0
	var anim_btn_h: float = 18.0
	var anim_gap: float = 3.0

	for i in range(PREVIEW_ANIMS.size()):
		var row: int = i / ANIM_COLS
		var col: int = i % ANIM_COLS
		var btn := Button.new()
		btn.text = PREVIEW_ANIMS[i]
		btn.size = Vector2(anim_btn_w, anim_btn_h)
		btn.add_theme_font_size_override("font_size", 9)
		btn.pressed.connect(_play_preview_anim.bind(i))
		_anim_buttons.append(btn)
		_root.add_child(btn)

	# ── 退出游戏按钮 ──
	var btn_quit := Button.new()
	btn_quit.name = "QuitBtn"
	btn_quit.text = "退出游戏"
	btn_quit.size = Vector2(120, 34)
	btn_quit.add_theme_font_size_override("font_size", 14)
	btn_quit.pressed.connect(func(): get_tree().quit())
	_root.add_child(btn_quit)

	# FileDialog
	var fd := FileDialog.new()
	fd.name = "PathFileDialog"
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fd.title = "选择存档目录"
	fd.size = Vector2(700, 500)
	fd.dir_selected.connect(_on_path_selected)
	_root.add_child(fd)

	_layout_ui()


# ═══════════════════════════════════════════
# 3D 角色预览
# ═══════════════════════════════════════════

func _create_preview() -> void:
	var container := SubViewportContainer.new()
	container.name = "PreviewContainer"
	container.size = Vector2(PREVIEW_SIZE - 20, PREVIEW_SIZE - 20)
	container.position = Vector2(PREVIEW_X, PREVIEW_Y)
	container.stretch = true
	_root.add_child(container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2(PREVIEW_SIZE - 20, PREVIEW_SIZE - 20)
	_preview_viewport.transparent_bg = true
	container.add_child(_preview_viewport)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.6, 3.8)
	cam.fov = 40.0
	_preview_viewport.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.5, 0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.5
	_preview_viewport.add_child(light)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.5)
	env.background_color = Color(0.05, 0.05, 0.08)
	env_node.environment = env
	_preview_viewport.add_child(env_node)

	_load_preview_model()


func _load_preview_model() -> void:
	if _preview_model:
		_preview_model.queue_free()
		_preview_model = null

	if not ResourceLoader.exists(DEFAULT_MODEL):
		return

	var scene: PackedScene = load(DEFAULT_MODEL)
	if not scene:
		return

	_preview_model = scene.instantiate()
	_preview_viewport.add_child(_preview_model)

	_apply_preview_skin()

	var aabb := _get_model_aabb(_preview_model)
	if aabb.size.length_squared() > 0.01:
		var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		var s: float = 2.0 / max_dim
		var center := aabb.position + aabb.size * 0.5
		_preview_model.scale = Vector3(s, s, s)
		_preview_model.position = -center * s


func _get_model_aabb(node: Node3D) -> AABB:
	var aabb: AABB = AABB()
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = child
		var la := m.get_aabb()
		if la.size.length_squared() > 0.001:
			var ga := m.global_transform * la
			if aabb.size.length_squared() < 0.001:
				aabb = ga
			else:
				aabb = aabb.merge(ga)
	return aabb


func _apply_preview_skin() -> void:
	if not ResourceLoader.exists(DEFAULT_SKIN):
		return
	var tex: Texture2D = load(DEFAULT_SKIN)
	if not tex:
		return
	for mesh: MeshInstance3D in _preview_model.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mesh.mesh
		if not m:
			continue
		for i in m.get_surface_count():
			var mat := mesh.get_active_material(i)
			if not mat:
				continue
			mat = mat.duplicate()
			mat.albedo_texture = tex
			mesh.set_surface_override_material(i, mat)


func _process(delta: float) -> void:
	if _preview_model and not _playing_anim:
		_preview_model.rotation.y -= delta * 1.2


func _play_preview_anim(idx: int) -> void:
	if not _preview_model:
		return
	var ap := _preview_model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not ap:
		return
	var anim_name: String = PREVIEW_ANIMS[idx]
	if not ap.has_animation(anim_name):
		return

	_playing_anim = true
	ap.play(anim_name)
	var anim := ap.get_animation(anim_name)
	if anim:
		get_tree().create_timer(anim.length).timeout.connect(_on_anim_done)


func _on_anim_done() -> void:
	_playing_anim = false


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
# 路径设置
# ═══════════════════════════════════════════

func _on_set_path() -> void:
	var fd := _root.get_node("PathFileDialog") as FileDialog
	if fd:
		var current := SaveManager.get_save_dir()
		fd.current_dir = current if not current.begins_with("user://") else ProjectSettings.globalize_path(current)
		fd.popup_centered()


func _on_reset_path() -> void:
	var confirm := AcceptDialog.new()
	confirm.title = "恢复默认路径"
	confirm.dialog_text = "确定要将存档路径恢复为默认吗？\n已有存档文件不会自动迁移。"
	confirm.size = Vector2(380, 110)
	confirm.confirmed.connect(_do_reset_path.bind(confirm))
	_root.add_child(confirm)
	confirm.popup_centered()


func _do_reset_path(dialog: AcceptDialog) -> void:
	SaveManager.reset_save_dir()
	dialog.queue_free()
	_refresh_path_display()
	_refresh_saves()
	_rebuild_slots()


func _on_path_selected(dir: String) -> void:
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
	for panel in _slot_panels:
		panel.queue_free()
	_slot_panels.clear()
	_rebuild()


func _shorten_path(path: String) -> String:
	# 截断过长的路径，保证一行能显示完
	if path.length() > 55:
		return "..." + path.right(52)
	return path


# ═══════════════════════════════════════════
# 重建 UI
# ═══════════════════════════════════════════

func _rebuild() -> void:
	for child in _root.get_children():
		child.queue_free()
	_slot_panels.clear()
	_anim_buttons.clear()
	_preview_model = null
	_refresh_saves()
	_build_ui()
	_create_preview()


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

	var path_bottom: float = SLOT_Y + MAX_SLOTS * (SLOT_H + SLOT_GAP) + 15.0
	var path_row1_y: float = path_bottom + 10.0
	var path_row2_y: float = path_row1_y + 22.0

	# 动画预览区
	const ANIM_COLS := 3
	var anim_btn_w: float = 73.0
	var anim_btn_h: float = 18.0
	var anim_gap: float = 3.0
	var anim_start_y: float = PREVIEW_Y + PREVIEW_SIZE + 50.0
	var anim_left_x: float = PREVIEW_X - 10.0

	for child in _root.get_children():
		if child is Label and child.text.begins_with("选择存档"):
			child.position = Vector2((REF.x - child.size.x) / 2.0, 85.0)
		elif child is Label and child.text.begins_with("最多"):
			child.position = Vector2((REF.x - child.size.x) / 2.0, path_bottom)
		elif child is Label and child.name == "PathLabel":
			child.position = Vector2(SLOT_X, path_row1_y)
		elif child is Label and child.name == "AnimLabel":
			child.position = Vector2(anim_left_x, anim_start_y)
		elif child is Button and child.name == "PathBtn":
			child.position = Vector2(SLOT_X, path_row2_y)
		elif child is Button and child.name == "ResetPathBtn":
			child.position = Vector2(SLOT_X + 115, path_row2_y)
		elif child is Button and child.name == "QuitBtn":
			child.position = Vector2((REF.x - child.size.x) / 2.0, path_row2_y + 50.0)

	# 动画按钮
	for i in range(_anim_buttons.size()):
		var row: int = i / ANIM_COLS
		var col: int = i % ANIM_COLS
		_anim_buttons[i].position = Vector2(
			anim_left_x + col * (anim_btn_w + anim_gap),
			anim_start_y + 22.0 + row * (anim_btn_h + anim_gap)
		)

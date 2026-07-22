extends CanvasLayer
class_name StartScreen
## 初始角色选择界面

# ── 角色数据表 ──
# 加新角色只需加一行：{id="xxx", name="显示名", path="模型路径"}
const CHARACTERS := [
	{id="archer", name="弓箭手", path="res://models/character/character-archer.glb", skin="res://models/character/colormap.png"},
]

signal started(selected_model_path: String, selected_skin_path: String)

var _selected_path: String = CHARACTERS[0].path
var _selected_skin: String = CHARACTERS[0].skin
var _selected_btn: Button
var _highlight_style: StyleBoxFlat
var _sel_label: Label
var _preview_viewport: SubViewport
var _preview_model: Node3D

# 需要响应缩放的 UI 元素引用
var _root: Control
var _title: Label
var _subtitle: Label
var _preview_bg: Panel
var _preview_container: SubViewportContainer
var _start_btn: Button
var _grid_buttons: Array[Button] = []
var _grid_cols: int = 7
var _grid_btn_w: float = 80.0
var _grid_gap: float = 4.0
var _grid_start_y: float = 120.0

# 动画预览按钮
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
var _anim_buttons: Array[Button] = []
var _anim_label: Label
var _playing_anim: bool = false


func _ready() -> void:
	layer = 500
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_update_preview()
	_layout_ui()
	get_tree().root.size_changed.connect(_layout_ui)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "StartRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.10, 0.15, 0.95)
	_root.add_child(bg)

	# ── 标题 ──
	_title = Label.new()
	_title.text = "TopDown Explorer"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_title.size = Vector2(600, 50)
	_title.position.y = 20
	_root.add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = "选择你的角色  (%d种)" % CHARACTERS.size()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 16)
	_subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_subtitle.size = Vector2(400, 25)
	_subtitle.position.y = 70
	_root.add_child(_subtitle)

	# ── 3D 预览 ──
	_preview_bg = Panel.new()
	_preview_bg.size = Vector2(260, 260)
	_preview_bg.position.y = 120
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.05, 0.08, 0.8)
	ps.border_color = Color(0.3, 0.3, 0.4, 0.5); ps.border_width_bottom = 2
	ps.border_width_left = 2; ps.border_width_right = 2; ps.border_width_top = 2
	ps.corner_radius_top_left = 10; ps.corner_radius_top_right = 10
	ps.corner_radius_bottom_left = 10; ps.corner_radius_bottom_right = 10
	_preview_bg.add_theme_stylebox_override("panel", ps)
	_root.add_child(_preview_bg)

	_preview_container = SubViewportContainer.new()
	_preview_container.size = Vector2(240, 240)
	_preview_container.position.y = 130
	_preview_container.stretch = true
	_root.add_child(_preview_container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2(240, 240)
	_preview_viewport.transparent_bg = true
	_preview_container.add_child(_preview_viewport)

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

	# ── 高亮样式 ──
	_highlight_style = StyleBoxFlat.new()
	_highlight_style.bg_color = Color(0.25, 0.55, 0.9, 0.85)
	_highlight_style.border_color = Color(0.5, 0.85, 1.0, 1.0); _highlight_style.border_width_bottom = 2
	_highlight_style.border_width_left = 2; _highlight_style.border_width_right = 2; _highlight_style.border_width_top = 2
	_highlight_style.corner_radius_top_left = 4; _highlight_style.corner_radius_top_right = 4
	_highlight_style.corner_radius_bottom_left = 4; _highlight_style.corner_radius_bottom_right = 4

	# ── 角色网格（7列 × 6行 ≈ 42个） ──
	var btn_h := 28.0

	for i in range(CHARACTERS.size()):
		var row: int = i / _grid_cols
		var y := _grid_start_y + row * (btn_h + _grid_gap)

		var btn := Button.new()
		btn.text = CHARACTERS[i].name
		btn.size = Vector2(_grid_btn_w, btn_h)
		btn.position.y = y
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_model_clicked.bind(i, btn))
		_grid_buttons.append(btn)
		_root.add_child(btn)

		if CHARACTERS[i].id == "archer":
			_selected_btn = btn
			btn.add_theme_stylebox_override("normal", _highlight_style)

	# ── 当前选择 ──
	_sel_label = Label.new()
	_sel_label.name = "SelectedLabel"
	_sel_label.text = "已选：" + CHARACTERS[0].name
	_sel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sel_label.add_theme_font_size_override("font_size", 15)
	_sel_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_sel_label.size = Vector2(250, 25)
	_sel_label.position.y = 400
	_root.add_child(_sel_label)

	# ── 开始 ──
	_start_btn = Button.new()
	_start_btn.text = "  开始游戏  ▶"
	_start_btn.size = Vector2(250, 48)
	_start_btn.position.y = 440
	_start_btn.add_theme_font_size_override("font_size", 20)
	_start_btn.pressed.connect(_on_start)
	_root.add_child(_start_btn)

	# ── 动画预览按钮 ──
	_anim_label = Label.new()
	_anim_label.text = "动画预览："
	_anim_label.add_theme_font_size_override("font_size", 13)
	_anim_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_anim_label.size = Vector2(250, 20)
	_anim_label.position.y = 500
	_root.add_child(_anim_label)

	var cols := 7
	var anim_btn_w: float = 140.0
	var anim_btn_h: float = 22.0
	var anim_gap: float = 3.0

	for i in range(PREVIEW_ANIMS.size()):
		var row: int = i / cols
		var col: int = i % cols
		var btn := Button.new()
		btn.text = PREVIEW_ANIMS[i]
		btn.size = Vector2(anim_btn_w, anim_btn_h)
		btn.position = Vector2(col * (anim_btn_w + anim_gap), 525 + row * (anim_btn_h + anim_gap))
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_play_preview_anim.bind(i))
		_anim_buttons.append(btn)
		_root.add_child(btn)


func _on_model_clicked(idx: int, btn: Button) -> void:
	if _selected_btn:
		_selected_btn.remove_theme_stylebox_override("normal")
	_selected_btn = btn
	btn.add_theme_stylebox_override("normal", _highlight_style)

	_selected_path = CHARACTERS[idx].path
	_selected_skin = CHARACTERS[idx].skin
	_sel_label.text = "已选：" + CHARACTERS[idx].name
	_update_preview()


func _update_preview() -> void:
	if _preview_model:
		_preview_model.queue_free()
		_preview_model = null
	_playing_anim = false

	if not ResourceLoader.exists(_selected_path):
		return

	var scene: PackedScene = load(_selected_path)
	if not scene:
		return

	_preview_model = scene.instantiate()
	_preview_model.rotation.y = PI / 4  # 正面偏 45°

	# 先入树再算全局包围盒（骨骼层级变换才能正确计算）
	_preview_viewport.add_child(_preview_model)

	# 给模型贴当前选中的皮肤
	_apply_preview_skin()

	var aabb := _get_global_aabb(_preview_model)
	if aabb.size.length_squared() > 0.01:
		var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		var s: float = 2.0 / max_dim
		# 包围盒中心 → 移到视口原点
		var center := aabb.position + aabb.size * 0.5
		_preview_model.scale = Vector3(s, s, s)
		_preview_model.position = -center * s


func _get_global_aabb(node: Node3D) -> AABB:
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


## 预览窗口也给幸存者贴皮肤
func _apply_preview_skin() -> void:
	if _selected_skin.is_empty():
		return
	var tex: Texture2D = load(_selected_skin)
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


func _on_start() -> void:
	started.emit(_selected_path, _selected_skin)
	queue_free()


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
	# 播放完后恢复旋转
	var anim := ap.get_animation(anim_name)
	if anim:
		get_tree().create_timer(anim.length).timeout.connect(_on_anim_done)


func _on_anim_done() -> void:
	_playing_anim = false


## 响应窗口缩放，重新计算位置 + 按比例缩放
func _layout_ui() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	const REF: Vector2 = Vector2(1920.0, 1080.0)

	# 整体缩放
	var scale: float = clampf(minf(vs.x / REF.x, vs.y / REF.y), 0.6, 1.6)
	_root.scale = Vector2(scale, scale)
	# 缩放后 _root 内元素坐标系统不变，但需把 root 移到视口中心来居中整体
	_root.position = (vs - REF * scale) / 2.0

	# 缩放后微调网格 X 位置（内部坐标不变，只需微调水平偏移）
	var preview_margin: float = 30.0
	var preview_w: float = _preview_bg.size.x

	_title.position.x = maxf(0.0, (REF.x - _title.size.x) / 2.0)
	_subtitle.position.x = maxf(0.0, (REF.x - _subtitle.size.x) / 2.0)

	_preview_bg.position.x = preview_margin
	_preview_container.position.x = preview_margin + 10.0

	var grid_start_x: float = preview_margin + preview_w + 20.0
	var grid_available_w: float = REF.x - grid_start_x - preview_margin
	var total_grid_w: float = _grid_cols * _grid_btn_w + (_grid_cols - 1) * _grid_gap
	var grid_offset_x: float = maxf(0.0, (grid_available_w - total_grid_w) / 2.0)

	for i in range(_grid_buttons.size()):
		var col: int = i % _grid_cols
		_grid_buttons[i].position.x = grid_start_x + grid_offset_x + col * (_grid_btn_w + _grid_gap)

	var bottom_x: float = preview_margin + 5.0
	_sel_label.position.x = bottom_x
	_start_btn.position.x = bottom_x
	_anim_label.position.x = bottom_x

	var anim_cols := 7
	var anim_btn_w: float = 140.0
	var anim_btn_h: float = 22.0
	var anim_gap: float = 3.0
	var anim_start_y: float = 525.0

	for i in range(_anim_buttons.size()):
		var row: int = i / anim_cols
		var col: int = i % anim_cols
		_anim_buttons[i].position = Vector2(bottom_x + col * (anim_btn_w + anim_gap), anim_start_y + row * (anim_btn_h + anim_gap))

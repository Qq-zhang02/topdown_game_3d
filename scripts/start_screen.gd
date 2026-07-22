extends CanvasLayer
class_name StartScreen
## 初始角色选择界面

# ── 角色数据表 ──
# 加新角色只需加一行：{id="xxx", name="显示名", path="模型路径"}
const CHARACTERS := [
	# 动物
	{id="beaver",     name="🦫 河狸",      path="res://models/animals/animal-beaver.glb"},
	{id="bee",        name="🐝 蜜蜂",      path="res://models/animals/animal-bee.glb"},
	{id="bunny",      name="🐰 兔子",      path="res://models/animals/animal-bunny.glb"},
	{id="cat",        name="🐱 猫",        path="res://models/animals/animal-cat.glb"},
	{id="caterpillar",name="🐛 毛毛虫",    path="res://models/animals/animal-caterpillar.glb"},
	{id="chick",      name="🐤 小鸡",      path="res://models/animals/animal-chick.glb"},
	{id="cow",        name="🐮 牛",        path="res://models/animals/animal-cow.glb"},
	{id="crab",       name="🦀 螃蟹",      path="res://models/animals/animal-crab.glb"},
	{id="deer",       name="🦌 鹿",        path="res://models/animals/animal-deer.glb"},
	{id="dog",        name="🐶 狗",        path="res://models/animals/animal-dog.glb"},
	{id="elephant",   name="🐘 大象",      path="res://models/animals/animal-elephant.glb"},
	{id="fish",       name="🐟 鱼",        path="res://models/animals/animal-fish.glb"},
	{id="fox",        name="🦊 狐狸",      path="res://models/animals/animal-fox.glb"},
	{id="giraffe",    name="🦒 长颈鹿",    path="res://models/animals/animal-giraffe.glb"},
	{id="hog",        name="🐗 野猪",      path="res://models/animals/animal-hog.glb"},
	{id="koala",      name="🐨 考拉",      path="res://models/animals/animal-koala.glb"},
	{id="lion",       name="🦁 狮子",      path="res://models/animals/animal-lion.glb"},
	{id="monkey",     name="🐵 猴子",      path="res://models/animals/animal-monkey.glb"},
	{id="panda",      name="🐼 熊猫",      path="res://models/animals/animal-panda.glb"},
	{id="parrot",     name="🦜 鹦鹉",      path="res://models/animals/animal-parrot.glb"},
	{id="penguin",    name="🐧 企鹅",      path="res://models/animals/animal-penguin.glb"},
	{id="pig",        name="🐷 猪",        path="res://models/animals/animal-pig.glb"},
	{id="polar",      name="🐻‍❄️ 北极熊",   path="res://models/animals/animal-polar.glb"},
	{id="tiger",      name="🐯 老虎",      path="res://models/animals/animal-tiger.glb"},
	# 方块角色
	{id="char_a",     name="🧑 角色 A",    path="res://models/blocky/character-a.glb"},
	{id="char_b",     name="🧑 角色 B",    path="res://models/blocky/character-b.glb"},
	{id="char_c",     name="🧑 角色 C",    path="res://models/blocky/character-c.glb"},
	{id="char_d",     name="🧑 角色 D",    path="res://models/blocky/character-d.glb"},
	{id="char_e",     name="🧑 角色 E",    path="res://models/blocky/character-e.glb"},
	{id="char_f",     name="🧑 角色 F",    path="res://models/blocky/character-f.glb"},
	{id="char_g",     name="🧑 角色 G",    path="res://models/blocky/character-g.glb"},
	{id="char_h",     name="🧑 角色 H",    path="res://models/blocky/character-h.glb"},
	{id="char_i",     name="🧑 角色 I",    path="res://models/blocky/character-i.glb"},
	{id="char_j",     name="🧑 角色 J",    path="res://models/blocky/character-j.glb"},
	{id="char_k",     name="🧑 角色 K",    path="res://models/blocky/character-k.glb"},
	{id="char_l",     name="🧑 角色 L",    path="res://models/blocky/character-l.glb"},
	{id="char_m",     name="🧑 角色 M",    path="res://models/blocky/character-m.glb"},
	{id="char_n",     name="🧑 角色 N",    path="res://models/blocky/character-n.glb"},
	{id="char_o",     name="🧑 角色 O",    path="res://models/blocky/character-o.glb"},
	{id="char_p",     name="🧑 角色 P",    path="res://models/blocky/character-p.glb"},
	{id="char_q",     name="🧑 角色 Q",    path="res://models/blocky/character-q.glb"},
	{id="char_r",     name="🧑 角色 R",    path="res://models/blocky/character-r.glb"},
]

signal started(selected_model_path: String)

var _selected_path: String = CHARACTERS[12].path  # 默认狐狸
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

		if CHARACTERS[i].id == "fox":
			_selected_btn = btn
			btn.add_theme_stylebox_override("normal", _highlight_style)

	# ── 当前选择 ──
	_sel_label = Label.new()
	_sel_label.name = "SelectedLabel"
	_sel_label.text = "已选：Fox"
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


func _on_model_clicked(idx: int, btn: Button) -> void:
	if _selected_btn:
		_selected_btn.remove_theme_stylebox_override("normal")
	_selected_btn = btn
	btn.add_theme_stylebox_override("normal", _highlight_style)

	_selected_path = CHARACTERS[idx].path
	_sel_label.text = "已选：" + CHARACTERS[idx].name
	_update_preview()


func _update_preview() -> void:
	if _preview_model:
		_preview_model.queue_free()
		_preview_model = null

	if not ResourceLoader.exists(_selected_path):
		return

	var scene: PackedScene = load(_selected_path)
	if not scene:
		return

	_preview_model = scene.instantiate()
	_preview_model.rotation.y = PI / 4  # 正面偏 45°

	# 先入树再算全局包围盒（骨骼层级变换才能正确计算）
	_preview_viewport.add_child(_preview_model)

	var aabb := _get_global_aabb(_preview_model)
	if aabb.size.length_squared() > 0.01:
		var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		var s: float = 2.0 / max_dim
		# 包围盒中心 → 移到视口原点
		var center := aabb.position + aabb.size * 0.5
		_preview_model.scale = Vector3(s, s, s)
		_preview_model.position = -center * s


func _get_global_aabb(node: Node3D) -> AABB:
	# 用 global_transform 正确计算骨骼层级下的实际包围盒
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


func _on_start() -> void:
	started.emit(_selected_path)
	queue_free()


func _process(delta: float) -> void:
	if _preview_model:
		_preview_model.rotation.y -= delta * 1.2


## 响应窗口缩放，重新计算位置 + 按比例缩放
func _layout_ui() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	const REF: Vector2 = Vector2(1280.0, 720.0)

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

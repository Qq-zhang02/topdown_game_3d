extends CanvasLayer
class_name MenuManager
## 暂停菜单：继续、重新开始、返回主页面

var _menu_root: Control
var _paused: bool = false
var _keybind_menu: CanvasLayer
var _menu_panel: Panel


func set_keybind_menu(km: CanvasLayer) -> void:
	_keybind_menu = km


func _ready() -> void:
	layer = 300
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_menu()
	_layout_menu()
	get_tree().root.size_changed.connect(_layout_menu)


func _build_menu() -> void:
	_menu_root = Control.new()
	_menu_root.name = "MenuRoot"
	_menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_root.hide()
	add_child(_menu_root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	_menu_root.add_child(bg)

	_menu_panel = Panel.new()
	_menu_panel.name = "MenuPanel"
	_menu_panel.size = Vector2(300, 330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.92)
	style.border_width_bottom = 2; style.border_width_left = 2
	style.border_width_right = 2; style.border_width_top = 2
	style.border_color = Color(0.5, 0.5, 0.6, 0.5)
	style.corner_radius_top_left = 10; style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10; style.corner_radius_bottom_right = 10
	_menu_panel.add_theme_stylebox_override("panel", style)
	_menu_root.add_child(_menu_panel)

	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size = Vector2(300, 40)
	title.position = Vector2(0, 20)
	_menu_panel.add_child(title)

	var btn_continue := Button.new()
	btn_continue.text = "继续游戏"
	btn_continue.size = Vector2(240, 40)
	btn_continue.position = Vector2(30, 75)
	btn_continue.add_theme_font_size_override("font_size", 16)
	btn_continue.pressed.connect(_resume)
	_menu_panel.add_child(btn_continue)

	var btn_restart := Button.new()
	btn_restart.text = "重新开始"
	btn_restart.size = Vector2(240, 40)
	btn_restart.position = Vector2(30, 125)
	btn_restart.add_theme_font_size_override("font_size", 16)
	btn_restart.pressed.connect(_on_restart)
	_menu_panel.add_child(btn_restart)

	var btn_home := Button.new()
	btn_home.text = "返回主页面"
	btn_home.size = Vector2(240, 40)
	btn_home.position = Vector2(30, 175)
	btn_home.add_theme_font_size_override("font_size", 16)
	btn_home.pressed.connect(_on_home)
	_menu_panel.add_child(btn_home)

	var btn_keybind := Button.new()
	btn_keybind.text = "按键设置"
	btn_keybind.size = Vector2(240, 40)
	btn_keybind.position = Vector2(30, 225)
	btn_keybind.add_theme_font_size_override("font_size", 16)
	btn_keybind.pressed.connect(_on_keybind)
	_menu_panel.add_child(btn_keybind)

	var btn_quit := Button.new()
	btn_quit.text = "退出游戏"
	btn_quit.size = Vector2(240, 40)
	btn_quit.position = Vector2(30, 275)
	btn_quit.add_theme_font_size_override("font_size", 16)
	btn_quit.pressed.connect(_on_quit)
	_menu_panel.add_child(btn_quit)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _paused:
			_resume()
		else:
			_pause()


func _pause() -> void:
	_paused = true
	get_tree().paused = true
	_menu_root.show()


func _resume() -> void:
	_paused = false
	get_tree().paused = false
	_menu_root.hide()


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_home() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_keybind() -> void:
	if _keybind_menu:
		_keybind_menu.show()


func _on_quit() -> void:
	get_tree().quit()


## 窗口缩放时重新居中 + 按比例缩放
func _layout_menu() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	const REF: Vector2 = Vector2(1920.0, 1080.0)
	var scale: float = clampf(minf(vs.x / REF.x, vs.y / REF.y), 0.6, 1.6)
	_menu_panel.scale = Vector2(scale, scale)
	var pw: float = 300.0 * scale
	var ph: float = 330.0 * scale
	_menu_panel.position = Vector2((vs.x - pw) / 2.0, (vs.y - ph) / 2.0)

extends CanvasLayer
class_name DeathScreen
## 死亡界面：玩家死亡后显示，按钮回到开始界面

func setup(health: Node) -> void:
	layer = 290
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()
	health.died.connect(_on_died)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.15, 0.02, 0.02, 0.75)
	root.add_child(bg)

	var title := Label.new()
	title.text = "你 死 了"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.15))
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.size = Vector2(600, 100)
	title.position -= Vector2(300, 120)
	root.add_child(title)

	var hint := Label.new()
	hint.text = "大海不欢迎胆小鬼"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.8, 0.7, 0.7, 0.8))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint.size = Vector2(600, 30)
	hint.position -= Vector2(300, 60)
	root.add_child(hint)

	var btn := Button.new()
	btn.text = "回到主菜单"
	btn.custom_minimum_size = Vector2(220, 50)
	btn.add_theme_font_size_override("font_size", 18)
	btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	btn.position -= Vector2(110, -20)
	btn.pressed.connect(_on_back)
	root.add_child(btn)


func _on_died() -> void:
	# 稍等死亡动画/倒地再弹界面
	await get_tree().create_timer(1.2).timeout
	show()


func _on_back() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

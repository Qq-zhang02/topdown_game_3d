extends Control
class_name EquipmentHUD
## 底部装备栏：功能装备(F) | 武器(Q) | 消耗品(1/2/3) 三个分区

const SLOT_SIZE := Vector2(64, 64)
const GAP := 6
const KEY_MIN_W := 20
const SECTION_GAP := 16
const MAX_UTILITY := 5
const MAX_WEAPON := 4
const CONS_SLOTS := 3

var _mgr: Node

# ── 功能装备区 ──
var _f_key: Label
var _util_bg: Array = []
var _util_labels: Array[Label] = []
var _util_active: int = -1

# ── 武器区 ──
var _q_key: Label
var _wpn_bg: Array = []
var _wpn_labels: Array[Label] = []
var _wpn_active: int = -1

# ── 消耗品区 ──
var _cons_bg: Array = []
var _cons_labels: Array[Label] = []
var _cons_cooldown_rects: Array[ColorRect] = []
var _cons_key_labels: Array[Label] = []

var _initialized: bool = false


func setup(manager: Node) -> void:
	_mgr = manager
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_update_display()
	if manager.has_signal("utility_changed"):
		manager.utility_changed.connect(_on_utility_changed)
	if manager.has_signal("weapon_changed"):
		manager.weapon_changed.connect(_on_weapon_changed)
	if manager.has_signal("consumables_changed"):
		manager.consumables_changed.connect(_on_consumable_changed)
	_initialized = true


func _ready() -> void:
	get_tree().root.size_changed.connect(_arrange)
	if _initialized:
		call_deferred("_arrange")


func _get_key_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			return ev.as_text().trim_suffix(" (Physical)")
	return "?"


func _key_width(label: Label) -> float:
	return label.get_minimum_size().x

func refresh_key_labels() -> void:
	if _f_key:
		_f_key.text = _get_key_label("cycle_equipment")
	if _q_key:
		_q_key.text = _get_key_label("cycle_weapon")
	var cons_actions := ["consume_1", "consume_2", "consume_3"]
	for i in range(CONS_SLOTS):
		if i < _cons_key_labels.size():
			_cons_key_labels[i].text = _get_key_label(cons_actions[i])
	if get_viewport():
		_arrange()


func _make_slot_style(active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if active:
		s.bg_color = Color(0.25, 0.50, 0.85, 0.80)
		s.border_color = Color(0.45, 0.80, 1.0, 1.0)
	else:
		s.bg_color = Color(0.12, 0.12, 0.12, 0.65)
		s.border_color = Color(0.30, 0.30, 0.30, 0.55)
	s.border_width_bottom = 2; s.border_width_left = 2
	s.border_width_right = 2; s.border_width_top = 2
	s.corner_radius_top_left = 5; s.corner_radius_top_right = 5
	s.corner_radius_bottom_left = 5; s.corner_radius_bottom_right = 5
	return s


func _make_key_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60, 0.85))
	l.custom_minimum_size = Vector2(KEY_MIN_W, SLOT_SIZE.y)
	l.size = Vector2(0, SLOT_SIZE.y)
	return l


func _build() -> void:
	# ── 功能装备键标签 ──
	_f_key = _make_key_label(_get_key_label("cycle_equipment"))
	add_child(_f_key)

	# 功能装备格子
	for i in range(MAX_UTILITY):
		var panel := Panel.new()
		panel.name = "Util_%d" % i
		panel.custom_minimum_size = SLOT_SIZE
		panel.size = SLOT_SIZE
		add_child(panel)
		_util_bg.append(panel)

		var lbl := Label.new()
		lbl.size = SLOT_SIZE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.85))
		panel.add_child(lbl)
		_util_labels.append(lbl)

	# ── 武器键标签 ──
	_q_key = _make_key_label(_get_key_label("cycle_weapon"))
	add_child(_q_key)

	# 武器格子
	for i in range(MAX_WEAPON):
		var panel := Panel.new()
		panel.name = "Wpn_%d" % i
		panel.custom_minimum_size = SLOT_SIZE
		panel.size = SLOT_SIZE
		add_child(panel)
		_wpn_bg.append(panel)

		var lbl := Label.new()
		lbl.size = SLOT_SIZE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.85))
		panel.add_child(lbl)
		_wpn_labels.append(lbl)

	# ── 消耗品区 ──
	var cons_actions := ["consume_1", "consume_2", "consume_3"]
	for i in range(CONS_SLOTS):
		var kl := _make_key_label(_get_key_label(cons_actions[i]))
		add_child(kl)
		_cons_key_labels.append(kl)

		var panel := Panel.new()
		panel.name = "Cons_%d" % i
		panel.custom_minimum_size = SLOT_SIZE
		panel.size = SLOT_SIZE
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		_cons_bg.append(panel)

		# 冷却覆盖层（底部向上缩小）
		var cd_rect := ColorRect.new()
		cd_rect.color = Color(0.5, 0.5, 0.5, 0.85)
		cd_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_rect.visible = false
		panel.add_child(cd_rect)
		_cons_cooldown_rects.append(cd_rect)

		# 物品名 + 数量
		var lbl := Label.new()
		lbl.size = SLOT_SIZE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.85))
		panel.add_child(lbl)
		_cons_labels.append(lbl)


func _arrange() -> void:
	if not get_viewport():
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var y: float = vs.y - SLOT_SIZE.y - 12

	# 各按键实际宽度
	var f_kw: float = _key_width(_f_key)
	var q_kw: float = _key_width(_q_key)
	var c_kw: Array[float] = []
	for i in range(CONS_SLOTS):
		c_kw.append(_key_width(_cons_key_labels[i]))

	var util_count: int = _mgr.get_utility_count() if _mgr else 0
	var wpn_count: int = _mgr.get_weapon_count() if _mgr else 0

	# 总宽度
	var total_w := f_kw + GAP
	if util_count > 0:
		total_w += util_count * (SLOT_SIZE.x + GAP) - GAP
	total_w += SECTION_GAP

	total_w += q_kw + GAP
	if wpn_count > 0:
		total_w += wpn_count * (SLOT_SIZE.x + GAP) - GAP
	total_w += SECTION_GAP

	for i in range(CONS_SLOTS):
		total_w += c_kw[i] + GAP + SLOT_SIZE.x + GAP
	total_w -= GAP

	var x: float = (vs.x - total_w) * 0.5

	# ── 功能装备区 ──
	_f_key.position = Vector2(x, y)
	x += f_kw + GAP
	for i in range(MAX_UTILITY):
		if i < util_count:
			_util_bg[i].position = Vector2(x, y)
			_util_bg[i].visible = true
			x += SLOT_SIZE.x + GAP
		else:
			_util_bg[i].visible = false
	if util_count > 0:
		x -= GAP
	x += SECTION_GAP

	# ── 武器区 ──
	_q_key.position = Vector2(x, y)
	x += q_kw + GAP
	for i in range(MAX_WEAPON):
		if i < wpn_count:
			_wpn_bg[i].position = Vector2(x, y)
			_wpn_bg[i].visible = true
			x += SLOT_SIZE.x + GAP
		else:
			_wpn_bg[i].visible = false
	if wpn_count > 0:
		x -= GAP
	x += SECTION_GAP

	# ── 消耗品区 ──
	for i in range(CONS_SLOTS):
		_cons_key_labels[i].position = Vector2(x, y)
		x += c_kw[i] + GAP
		_cons_bg[i].position = Vector2(x, y)
		x += SLOT_SIZE.x + GAP


func _update_display() -> void:
	if not _mgr:
		return

	# 功能装备
	var util_count: int = _mgr.get_utility_count()
	var util_active: int = _mgr.get_utility_active()
	for i in range(MAX_UTILITY):
		if i < util_count:
			var eq: Resource = _mgr.get_utility_at(i)
			_util_labels[i].text = eq.get("display_name") if eq else ""
			var style := _make_slot_style(i == util_active)
			_util_bg[i].add_theme_stylebox_override("panel", style)
			if i == util_active:
				_util_labels[i].add_theme_color_override("font_color", Color.WHITE)
			else:
				_util_labels[i].add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.70))
	_util_active = util_active

	# 武器
	var wpn_count: int = _mgr.get_weapon_count()
	var wpn_active: int = _mgr.get_weapon_active()
	for i in range(MAX_WEAPON):
		if i < wpn_count:
			var wpn: Resource = _mgr.get_weapon_at(i)
			_wpn_labels[i].text = wpn.get("display_name") if wpn else ""
			var style := _make_slot_style(i == wpn_active)
			_wpn_bg[i].add_theme_stylebox_override("panel", style)
			if i == wpn_active:
				_wpn_labels[i].add_theme_color_override("font_color", Color.WHITE)
			else:
				_wpn_labels[i].add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.70))
	_wpn_active = wpn_active

	# 消耗品
	for i in range(CONS_SLOTS):
		var item: Resource = _mgr.get_cons_item(i)
		var count: int = _mgr.get_cons_count(i)
		var cd_ratio: float = _mgr.get_cons_cooldown_ratio(i)

		var style := _make_slot_style(false)
		# 有物品且不在冷却中 → 稍微亮一点
		if item and cd_ratio <= 0.0:
			style.bg_color = Color(0.16, 0.16, 0.18, 0.70)
			style.border_color = Color(0.40, 0.40, 0.45, 0.60)
		_cons_bg[i].add_theme_stylebox_override("panel", style)

		if item:
			_cons_labels[i].text = "%s x%d" % [item.get("display_name"), count]
			_cons_labels[i].add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 0.90))
		else:
			_cons_labels[i].text = ""
			_cons_labels[i].add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))

		# 冷却覆盖层（从底部向上缩小）
		var cr := _cons_cooldown_rects[i]
		if cd_ratio > 0.001:
			cr.visible = true
			cr.size = Vector2(SLOT_SIZE.x, SLOT_SIZE.y * cd_ratio)
			cr.position = Vector2(0, SLOT_SIZE.y - cr.size.y)
		else:
			cr.visible = false

	_arrange()


func _on_utility_changed(_idx: int) -> void:
	_update_display()


func _on_weapon_changed(_idx: int) -> void:
	_update_display()


func _on_consumable_changed(_slot: int) -> void:
	_update_display()

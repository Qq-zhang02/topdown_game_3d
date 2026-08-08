extends Node
class_name BuildController
## 建造控制器：B 打开配方菜单 → 选配方 → 幽灵预览（绿=可放/红=不可放）
## 左键放置（消耗背包材料，可连续放置），R 旋转 90°，右键/B 退出
## 世界需提供: get_world_half() / is_area_free(center, half) / place_building(data, pos, rot)

const BuildMenuScript := preload("res://scripts/building/build_menu_ui.gd")

const GRID := 1.0  # 网格吸附（米）

var _player: Node3D
var _inventory: Node
var _world: Node3D
var _recipes: Array = []
var _menu: CanvasLayer

var _current: Resource = null
var _current_size: Vector3 = Vector3.ONE  # 从预制体 AABB 缓存的尺寸
var _placing: bool = false
var _rot_index: int = 0  # 0~3，90° 一档
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _ghost_valid: bool = false
var _ghost_pos: Vector3


func setup(player: Node3D, inventory: Node, world: Node3D) -> void:
	_player = player
	_inventory = inventory
	_world = world
	add_to_group("build_controller")
	_load_recipes()
	_create_menu()
	_create_ghost()


func is_placing() -> bool:
	return _placing


func is_menu_open() -> bool:
	return _menu and _menu.visible


# ═══════════════════════════════════════════
# 配方 & 菜单
# ═══════════════════════════════════════════

func _load_recipes() -> void:
	var dir := DirAccess.open("res://data/buildings/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		# 导出的包里文件会带 .remap 后缀，先去掉再判断/加载
		var clean := fname.trim_suffix(".remap")
		if not dir.current_is_dir() and clean.ends_with(".tres"):
			var res: Resource = load("res://data/buildings/" + clean)
			if res:
				_recipes.append(res)
		fname = dir.get_next()


func _create_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.set_script(BuildMenuScript)
	_menu.name = "BuildMenu"
	_world.add_child(_menu)
	_menu.setup(_recipes, _inventory)
	_menu.recipe_selected.connect(_on_recipe_selected)


func _on_recipe_selected(data: Resource) -> void:
	_current = data
	# ★ 尺寸由预制体 mesh AABB 决定（tres 不保存尺寸），选中时缓存一次
	_current_size = data.get_size()
	_rot_index = 0
	_placing = true
	_menu.hide()
	_update_ghost_mesh()


# ═══════════════════════════════════════════
# 幽灵预览
# ═══════════════════════════════════════════

func _create_ghost() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost = MeshInstance3D.new()
	_ghost.name = "BuildGhost"
	_ghost.material_override = _ghost_mat
	_ghost.visible = false
	_world.add_child(_ghost)


func _update_ghost_mesh() -> void:
	var box := BoxMesh.new()
	box.size = _current_size
	_ghost.mesh = box
	_ghost.visible = true


## 旋转后的 XZ 半尺寸
func _half_extents() -> Vector2:
	var s: Vector3 = _current_size
	if _rot_index % 2 == 1:
		return Vector2(s.z, s.x) * 0.5
	return Vector2(s.x, s.z) * 0.5


func _process(_delta: float) -> void:
	if not _placing or _current == null:
		return

	var target: Vector3 = _player.get_mouse_ground_position()
	target.x = roundf(target.x / GRID) * GRID
	target.z = roundf(target.z / GRID) * GRID
	target.y = _world.get_terrain_height_at(target.x, target.z) + _current_size.y * 0.5
	_ghost_pos = target

	_ghost.position = target
	_ghost.rotation.y = _rot_index * PI * 0.5

	_ghost_valid = _check_valid(target)
	if _ghost_valid:
		_ghost_mat.albedo_color = Color(0.2, 0.9, 0.3, 0.45)
	else:
		_ghost_mat.albedo_color = Color(0.9, 0.2, 0.2, 0.45)


func _check_valid(pos: Vector3) -> bool:
	if not _inventory.has_cost(_current.cost):
		return false
	return _world.is_area_free(pos, _half_extents())


# ═══════════════════════════════════════════
# 输入
# ═══════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	if _placing:
		if event.is_action_pressed("attack"):
			_try_place()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("build_rotate"):
			_rot_index = (_rot_index + 1) % 4
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("build_menu"):
			_cancel_placing()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_placing()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_menu"):
		if is_menu_open():
			_menu.hide()
		else:
			_menu.show()
		get_viewport().set_input_as_handled()


func _try_place() -> void:
	if _current == null or not _ghost_valid:
		return
	if not _inventory.consume_cost(_current.cost):
		return
	_world.place_building(_current, _ghost_pos, _rot_index * PI * 0.5)
	# 材料可能用尽，立即刷新幽灵颜色
	_ghost_valid = _check_valid(_ghost_pos)


func _cancel_placing() -> void:
	_placing = false
	_current = null
	if _ghost:
		_ghost.visible = false

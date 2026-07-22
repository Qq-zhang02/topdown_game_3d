extends Node3D
## 3D 世界管理器

const WORLD_HALF: float = 50.0
const OBSTACLE_COUNT: int = 100
const MINIMAP_SIZE := Vector2(220, 220)

var _obstacle_positions: Array[Vector3] = []
var _obstacle_data: Array[Dictionary] = []
var _occupied: Array[AABB] = []  # 障碍物/资源/建筑占地区域（建造系统用）
var _day_night: Node
var _player: CharacterBody3D
var _ocean: Node3D
var _buildings_data: Array[Dictionary] = []  # 建筑记录 [{resource_path, position, rot_y}]
var _play_time: float = 0.0                 # 累计游玩时间（秒）
var _save_slot: int = -1                    # 当前存档槽位
var _game_started: bool = false             # 游戏是否已开始（用于自动存档）
var _auto_save_timer: float = 0.0            # 自动存档计时器
var _save_toast: Label                        # 自动存档提示标签


func _ready() -> void:
	# 默认全屏启动
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# 先显示存档选择界面
	var SaveSelectScript := load("res://scripts/save_select_screen.gd")
	var save_select := CanvasLayer.new()
	save_select.set_script(SaveSelectScript)
	save_select.name = "SaveSelectScreen"
	save_select.load_game.connect(_on_load_game)
	save_select.new_game.connect(_on_new_game)
	add_child(save_select)


func _on_new_game(slot: int) -> void:
	_save_slot = slot
	# 移除存档选择界面
	_remove_save_select()

	var StartScript := load("res://scripts/start_screen.gd")
	var start_scr := CanvasLayer.new()
	start_scr.set_script(StartScript)
	start_scr.name = "StartScreen"
	start_scr.setup(slot)
	start_scr.started.connect(_on_game_started)
	add_child(start_scr)


func _on_load_game(save_data: Dictionary, slot: int) -> void:
	_save_slot = slot
	_play_time = save_data.get("play_time", 0.0)
	_remove_save_select()

	var model_path: String = save_data.get("character_model", "res://models/character/character-archer.glb")
	var skin_path: String = save_data.get("character_skin", "res://models/character/colormap.png")

	_on_game_started(model_path, skin_path, slot)

	# 世界构建完成后恢复存档状态
	call_deferred("_restore_from_save", save_data)


func _remove_save_select() -> void:
	var ss := get_node_or_null("SaveSelectScreen")
	if ss:
		ss.queue_free()


func _on_game_started(model_path: String, skin_path: String, save_slot: int) -> void:
	_save_slot = save_slot
	# 玩家选好角色后，构建世界
	_create_lighting()
	_create_ground()
	_create_obstacles()
	_create_ocean()
	_create_player(model_path, skin_path)
	_ocean.setup(_player, _player.get_health())
	_create_resource_nodes()
	_create_animals()
	_create_camera(_player)
	_create_minimap(_player)
	_create_equipment_hud(_player)
	_create_inventory_ui()
	_create_build_system()
	_create_death_screen()
	_create_menu()
	_create_day_night_system()
	_create_time_display()
	_create_hp_bar()
	_game_started = true
	# 创建自动存档提示
	_create_save_toast()
	# 延迟保存初始状态（等所有节点的 _ready 执行完）
	_save_current_game.call_deferred()


# ═══════════════════════════════════════════
# 光照
# ═══════════════════════════════════════════

func _create_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-90, 30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.0
	add_child(sun)

	var moon := DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.rotation_degrees = Vector3(90, 210, 0)
	moon.shadow_enabled = false
	moon.light_color = Color(0.45, 0.55, 0.85)
	moon.light_energy = 0.0
	add_child(moon)

	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnv"
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.45)
	env.background_color = Color(0.12, 0.18, 0.28)
	env.ssao_enabled = true
	env.ssao_light_affect = 0.3
	env.glow_enabled = false
	env_node.environment = env
	add_child(env_node)


# ═══════════════════════════════════════════
# 地面
# ═══════════════════════════════════════════

func _create_ground() -> void:
	var total_size := WORLD_HALF * 2.0

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(total_size, total_size)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.38, 0.15)
	mat.albedo_texture = _make_noise_texture(0.015, randi())
	mat.roughness = 0.9
	mat.metallic = 0.0
	ground.material_override = mat
	add_child(ground)

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(total_size, 0.05, total_size)
	col.shape = shape
	col.position = Vector3(0, -0.025, 0)
	body.add_child(col)
	add_child(body)


func _make_noise_texture(frequency: float, seed: int) -> NoiseTexture2D:
	var fast_noise := FastNoiseLite.new()
	fast_noise.seed = seed
	fast_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fast_noise.frequency = frequency
	fast_noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = fast_noise
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	return tex


# ═══════════════════════════════════════════
# 海洋（地图边界：落水持续掉血致死）
# ═══════════════════════════════════════════

func _create_ocean() -> void:
	var OceanScript := load("res://scripts/world/ocean.gd")
	_ocean = Node3D.new()
	_ocean.set_script(OceanScript)
	_ocean.name = "Ocean"
	add_child(_ocean)
	_ocean.build(WORLD_HALF)


# ═══════════════════════════════════════════
# 障碍物
# ═══════════════════════════════════════════

func _create_obstacles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var margin: float = 5.0
	var material_presets := _make_material_presets()

	for i in range(OBSTACLE_COUNT):
		var w: float = rng.randf_range(1.0, 4.0)
		var d: float = rng.randf_range(1.0, 4.0)
		var h: float = rng.randf_range(1.5, 5.0)

		var pos := Vector3(
			rng.randf_range(margin, WORLD_HALF * 2 - margin) - WORLD_HALF,
			h / 2.0,
			rng.randf_range(margin, WORLD_HALF * 2 - margin) - WORLD_HALF
		)

		var mat_idx: int = 0
		var roll: float = rng.randf()
		if roll < 0.10: mat_idx = 3
		elif roll < 0.25: mat_idx = 2
		elif roll < 0.50: mat_idx = 1

		var vis := MeshInstance3D.new()
		vis.name = "Obstacle_%d" % i
		vis.position = pos
		var box := BoxMesh.new()
		box.size = Vector3(w, h, d)
		vis.mesh = box
		vis.material_override = material_presets[mat_idx].duplicate()
		vis.material_override.albedo_color = Color(
			rng.randf_range(0.3, 0.55),
			rng.randf_range(0.35, 0.55),
			rng.randf_range(0.3, 0.50)
		)
		add_child(vis)

		var sb := StaticBody3D.new()
		sb.name = "ObstacleBody_%d" % i
		sb.position = pos
		var sc := CollisionShape3D.new()
		var shp := BoxShape3D.new()
		shp.size = Vector3(w, h, d)
		sc.shape = shp
		sb.add_child(sc)
		add_child(sb)

		_obstacle_positions.append(pos)
		_obstacle_data.append({"position": pos, "size": Vector3(w, h, d)})
		_occupied.append(AABB(pos - Vector3(w, h, d) * 0.5, Vector3(w, h, d)))


func _make_material_presets() -> Array[StandardMaterial3D]:
	var presets: Array[StandardMaterial3D] = []
	var stone := StandardMaterial3D.new(); stone.roughness = 0.85; stone.metallic = 0.0; presets.append(stone)
	var polished := StandardMaterial3D.new(); polished.roughness = 0.4; polished.metallic = 0.15; presets.append(polished)
	var glossy := StandardMaterial3D.new(); glossy.roughness = 0.15; glossy.metallic = 0.05; glossy.clearcoat = 0.3; glossy.clearcoat_roughness = 0.1; presets.append(glossy)
	var metal := StandardMaterial3D.new(); metal.roughness = 0.2; metal.metallic = 0.9; metal.metallic_specular = 0.5; presets.append(metal)
	return presets


# ═══════════════════════════════════════════
# 资源节点（树/石头，近战采集）
# ═══════════════════════════════════════════

func _create_resource_nodes() -> void:
	var ResNodeScript := load("res://scripts/world/resource_node.gd")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var kinds := {"tree": 25, "rock": 15}

	for kind in kinds:
		for i in range(kinds[kind]):
			var pos := Vector3.ZERO
			var found := false
			for attempt in range(60):
				pos = Vector3(
					rng.randf_range(-WORLD_HALF + 4.0, WORLD_HALF - 4.0),
					0,
					rng.randf_range(-WORLD_HALF + 4.0, WORLD_HALF - 4.0)
				)
				if is_area_free(pos, Vector2(1.0, 1.0)) and pos.distance_to(_player.global_position) > 6.0:
					found = true
					break
			if found:
				var node = ResNodeScript.spawn(self, kind, pos)
				register_occupied(node.occupied_aabb)
				# 同时让动物生成器避开
				_obstacle_data.append({"position": pos, "size": Vector3(1.5, 2.0, 1.5)})


# ═══════════════════════════════════════════
# 建造系统：占地查询 / 放置
# ═══════════════════════════════════════════

func register_occupied(aabb: AABB) -> void:
	_occupied.append(aabb)


func unregister_occupied(aabb: AABB) -> void:
	_occupied.erase(aabb)


## 检查 center 周围 half(XZ半尺寸) 的区域是否可以放置建筑
func is_area_free(center: Vector3, half: Vector2) -> bool:
	if abs(center.x) + half.x > WORLD_HALF - 1.0:
		return false
	if abs(center.z) + half.y > WORLD_HALF - 1.0:
		return false
	var box := AABB(
		Vector3(center.x - half.x, 0.0, center.z - half.y),
		Vector3(half.x * 2.0, 8.0, half.y * 2.0)
	)
	for o in _occupied:
		if box.intersects(o):
			return false
	if _player:
		var d := Vector2(
			center.x - _player.global_position.x,
			center.z - _player.global_position.z
		).length()
		if d < 1.2:
			return false
	return true


## 放置建筑（由 BuildController 调用，材料已在控制器中扣除）
func place_building(data: Resource, pos: Vector3, rot_y: float, from_save: bool = false) -> void:
	if not from_save:
		_buildings_data.append({
			"resource_path": data.resource_path,
			"position": pos,
			"rot_y": rot_y
		})

	var body := StaticBody3D.new()
	body.name = "Building_" + data.id
	body.collision_layer = 1
	body.position = pos
	body.rotation.y = rot_y
	add_child(body)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = data.size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.color
	mat.roughness = 0.8
	mesh.material_override = mat
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = data.size
	col.shape = shape
	body.add_child(col)

	if data.emits_light:
		var light := OmniLight3D.new()
		light.light_color = data.light_color
		light.light_energy = data.light_energy
		light.omni_range = data.light_range
		light.position = Vector3(0, data.size.y * 0.5 + 0.6, 0)
		body.add_child(light)

	var half := Vector2(data.size.x, data.size.z) * 0.5
	if int(round(rad_to_deg(rot_y))) % 180 != 0:
		half = Vector2(data.size.z, data.size.x) * 0.5
	register_occupied(AABB(
		Vector3(pos.x - half.x, 0.0, pos.z - half.y),
		Vector3(half.x * 2.0, data.size.y, half.y * 2.0)
	))

# ═══════════════════════════════════════════
# 玩家
# ═══════════════════════════════════════════

func _create_player(model_path: String, skin_path: String) -> void:
	var ps := load("res://scenes/player.tscn")
	_player = ps.instantiate() as CharacterBody3D
	_player.name = "Player"
	_player.position = Vector3(0, 0, 0)
	_player.set_model_path(model_path)
	_player.set_skin_path(skin_path)
	_player.collision_mask = 1  # 只与地面/障碍物碰撞
	_player.add_to_group("player")
	add_child(_player)


# ═══════════════════════════════════════════
# 小动物
# ═══════════════════════════════════════════

func _create_animals() -> void:
	var AnimalSpawnerScript := load("res://scripts/animal_spawner.gd")
	var spawner := Node.new()
	spawner.set_script(AnimalSpawnerScript)
	spawner.name = "AnimalSpawner"
	spawner.setup(WORLD_HALF, _obstacle_data, _player.position)
	add_child(spawner)
	spawner.spawn_all()


# ═══════════════════════════════════════════
# 摄像机
# ═══════════════════════════════════════════

func _create_camera(target: Node3D) -> void:
	var CamScript := load("res://scripts/camera_follow_3d.gd")
	var cam := Camera3D.new()
	cam.name = "MainCamera"
	cam.set_script(CamScript)
	cam.set("target", target)
	cam.make_current()
	add_child(cam)


# ═══════════════════════════════════════════
# 小地图
# ═══════════════════════════════════════════

func _create_minimap(target: Node3D) -> void:
	var layer := CanvasLayer.new()
	layer.name = "MinimapLayer"
	layer.layer = 100
	add_child(layer)

	var MinimapScript := load("res://scripts/minimap_3d.gd")
	var minimap := Control.new()
	minimap.set_script(MinimapScript)
	minimap.name = "Minimap3D"
	minimap.position = Vector2(15, 15)
	minimap.size = MINIMAP_SIZE
	minimap.set("world_half", WORLD_HALF)
	minimap.set("target", target)
	minimap.set("obstacle_positions", _obstacle_positions)
	layer.add_child(minimap)


# ═══════════════════════════════════════════
# 装备栏 HUD
# ═══════════════════════════════════════════

func _create_equipment_hud(player_node: Node3D) -> void:
	var mgr: Node = player_node.get_node("EquipmentManager")
	if not mgr:
		return

	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	layer.layer = 50
	add_child(layer)

	var hscr := load("res://scripts/equipment_hud.gd")
	var hud := Control.new()
	hud.set_script(hscr)
	hud.name = "EquipmentHUD"
	hud.setup(mgr)
	layer.add_child(hud)


# ═══════════════════════════════════════════
# 背包界面
# ═══════════════════════════════════════════

func _create_inventory_ui() -> void:
	var UIScript := load("res://scripts/inventory/inventory_ui.gd")
	var ui := CanvasLayer.new()
	ui.set_script(UIScript)
	ui.name = "InventoryUI"
	add_child(ui)
	ui.setup(_player.get_inventory())


# ═══════════════════════════════════════════
# 建造系统
# ═══════════════════════════════════════════

func _create_build_system() -> void:
	var BCScript := load("res://scripts/building/build_controller.gd")
	var bc := Node.new()
	bc.set_script(BCScript)
	bc.name = "BuildController"
	add_child(bc)
	bc.setup(_player, _player.get_inventory(), self)


# ═══════════════════════════════════════════
# 死亡界面
# ═══════════════════════════════════════════

func _create_death_screen() -> void:
	var DSScript := load("res://scripts/world/death_screen.gd")
	var ds := CanvasLayer.new()
	ds.set_script(DSScript)
	ds.name = "DeathScreen"
	add_child(ds)
	ds.setup(_player.get_health())


# ═══════════════════════════════════════════
# 菜单
# ═══════════════════════════════════════════

func _create_menu() -> void:
	var MenuScript := load("res://scripts/menu_manager.gd")
	var menu := CanvasLayer.new()
	menu.set_script(MenuScript)
	menu.name = "MenuManager"
	add_child(menu)
	menu.save_requested.connect(_save_current_game)

	var KeybindScript := load("res://scripts/keybind_menu.gd")
	var keybind := CanvasLayer.new()
	keybind.set_script(KeybindScript)
	keybind.name = "KeybindMenu"
	add_child(keybind)
	menu.set_keybind_menu(keybind)
	# 改键时自动刷新装备栏的按键提示
	var hud := get_node_or_null("HUDLayer/EquipmentHUD")
	if hud and hud.has_method("refresh_key_label"):
		keybind.bindings_changed.connect(hud.refresh_key_label)
		# 首次同步：KeybindMenu 加载保存的键位后，强制刷新装备栏标签
		hud.refresh_key_label.call_deferred()


# ═══════════════════════════════════════════
# 昼夜循环
# ═══════════════════════════════════════════

func _create_day_night_system() -> void:
	var DNCScript := load("res://scripts/day_night_cycle.gd")
	_day_night = Node.new()
	_day_night.set_script(DNCScript)
	_day_night.name = "DayNightCycle"
	_day_night.set("sun_light", $SunLight)
	_day_night.set("moon_light", $MoonLight)
	_day_night.set("environment", $WorldEnv.environment)
	_day_night.set("time_scale", 60.0)
	_day_night.add_to_group("day_night_system")
	add_child(_day_night)


# ═══════════════════════════════════════════
# 时间显示
# ═══════════════════════════════════════════

func _create_time_display() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TimeLayer"
	layer.layer = 40
	add_child(layer)

	var bg := Panel.new()
	bg.name = "TimeBg"
	bg.position = Vector2(15, 245)
	bg.size = Vector2(72, 28)
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0, 0, 0, 0.55)
	ts.corner_radius_top_left = 6; ts.corner_radius_top_right = 6
	ts.corner_radius_bottom_left = 6; ts.corner_radius_bottom_right = 6
	bg.add_theme_stylebox_override("panel", ts)
	layer.add_child(bg)

	var time_label := Label.new()
	time_label.name = "TimeLabel"
	time_label.position = Vector2(23, 248)
	time_label.size = Vector2(56, 22)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 14)
	time_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	time_label.text = "06:00"
	layer.add_child(time_label)

	# 每帧更新时间
	var updater := Node.new()
	updater.name = "TimeUpdater"
	updater.set_script(load("res://scripts/time_display.gd"))
	updater.set("day_night", _day_night)
	updater.set("label", time_label)
	add_child(updater)


# ═══════════════════════════════════════════
# 玩家血条 HUD
# ═══════════════════════════════════════════

func _create_hp_bar() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HPBarLayer"
	layer.layer = 40
	add_child(layer)

	var bg := Panel.new()
	bg.name = "HPBg"
	bg.position = Vector2(15, 280)
	bg.size = Vector2(220, 26)
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0, 0, 0, 0.55)
	ts.corner_radius_top_left = 6; ts.corner_radius_top_right = 6
	ts.corner_radius_bottom_left = 6; ts.corner_radius_bottom_right = 6
	bg.add_theme_stylebox_override("panel", ts)
	layer.add_child(bg)

	var fill := ColorRect.new()
	fill.name = "HPFill"
	fill.position = Vector2(18, 283)
	fill.size = Vector2(214, 20)
	fill.color = Color(0.2, 0.85, 0.2)
	layer.add_child(fill)

	var label := Label.new()
	label.name = "HPLabel"
	label.position = Vector2(18, 283)
	label.size = Vector2(214, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.text = "100 / 100"
	layer.add_child(label)

	var health: Health = _player.get_health() as Health
	health.damaged.connect(_on_hp_changed.bind(fill, label))
	_on_hp_changed(0.0, Vector3.ZERO, fill, label)


func _on_hp_changed(_amount: float, _from: Vector3, fill: ColorRect, label: Label) -> void:
	var health: Health = _player.get_health() as Health
	var ratio := clampf(health.hp / health.max_hp, 0.0, 1.0)
	fill.size.x = 214.0 * ratio

	if ratio > 0.5:
		fill.color = Color(0.2, 0.85, 0.2).lerp(Color(0.85, 0.85, 0.1), (1.0 - ratio) * 2.0)
	else:
		fill.color = Color(0.85, 0.85, 0.1).lerp(Color(0.85, 0.15, 0.1), (0.5 - ratio) * 2.0)

	label.text = "%d / %d" % [int(ceil(health.hp)), int(health.max_hp)]


# ═══════════════════════════════════════════
# 游玩时间 & 退出存档
# ═══════════════════════════════════════════

func _process(delta: float) -> void:
	if _game_started:
		_play_time += delta
		_auto_save_timer += delta
		if _auto_save_timer >= 60.0:
			_auto_save_timer = 0.0
			_save_current_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_current_game()


# ═══════════════════════════════════════════
# 存档：收集世界状态 → JSON → 写入磁盘
# ═══════════════════════════════════════════

func _collect_save_data() -> Dictionary:
	var data := {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"play_time": _play_time,
		"character_model": _player.get("_model_path") if _player else "",
		"character_skin": _player.get("_skin_path") if _player else "",
		"player": _collect_player_data(),
		"world": _collect_world_data(),
	}
	return data


func _collect_player_data() -> Dictionary:
	if not _player:
		return {}

	var pos := _player.global_position
	var health_node: Health = _player.get_health()
	var hp: float = health_node.get("hp") if health_node else 100.0

	# 背包
	var inv: Node = _player.get_inventory()
	var inv_data: Array = []
	if inv:
		for st in inv.slots:
			if st and st.item:
				inv_data.append({"id": st.item.get("id"), "count": st.count})
			else:
				inv_data.append(null)

	# 装备
	var equip_mgr: Node = _player.get_node_or_null("EquipmentManager")
	var equip_idx: int = equip_mgr.get_current_index() if equip_mgr else -1

	return {
		"pos_x": pos.x, "pos_y": pos.y, "pos_z": pos.z,
		"health": hp,
		"inventory": inv_data,
		"equipment_index": equip_idx,
	}


func _collect_world_data() -> Dictionary:
	var day_time: float = 0.25
	if _day_night and _day_night.get("game_time") != null:
		day_time = float(_day_night.get("game_time"))

	var buildings: Array[Dictionary] = []
	for b in _buildings_data:
		var bp: Vector3 = b.position
		buildings.append({
			"resource_path": b.resource_path,
			"px": bp.x, "py": bp.y, "pz": bp.z,
			"rot_y": b.rot_y,
		})

	return {
		"day_time": day_time,
		"buildings": buildings,
	}


func _save_current_game() -> void:
	if _save_slot < 0 or not _game_started:
		return
	var data := _collect_save_data()
	if SaveManager.save_game(_save_slot, data):
		_show_save_toast()


func _create_save_toast() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ToastLayer"
	layer.layer = 350
	add_child(layer)

	_save_toast = Label.new()
	_save_toast.name = "SaveToast"
	_save_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_toast.add_theme_font_size_override("font_size", 15)
	_save_toast.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6, 1.0))
	_save_toast.size = Vector2(200, 28)
	layer.add_child(_save_toast)


func _show_save_toast() -> void:
	if not _save_toast:
		return
	var vs := get_viewport().get_visible_rect().size
	_save_toast.text = "游戏已保存"
	_save_toast.position = Vector2((vs.x - 200) / 2.0, vs.y - 50)
	_save_toast.modulate.a = 1.0

	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(_save_toast, "modulate:a", 0.0, 1.0)


# ═══════════════════════════════════════════
# 存档：从 JSON 恢复世界状态
# ═══════════════════════════════════════════

func _restore_from_save(data: Dictionary) -> void:
	if not _player:
		return

	# ── 玩家状态 ──
	var pd: Dictionary = data.get("player", {})
	if not pd.is_empty():
		_player.global_position = Vector3(
			pd.get("pos_x", 0.0), pd.get("pos_y", 0.0), pd.get("pos_z", 0.0)
		)

		var health_node: Health = _player.get_health()
		if health_node:
			health_node.set("hp", pd.get("health", 100.0))

		# 背包
		var inv: Node = _player.get_inventory()
		if inv:
			inv.slots.clear()
			inv.slots.resize(inv.slot_count)
			var ItemDBScript := load("res://scripts/core/item_db.gd")
			var ItemStackClass := load("res://scripts/core/item_stack.gd")
			for i in range(pd.get("inventory", []).size()):
				var entry = pd["inventory"][i]
				if entry and entry.get("id"):
					var item: Resource = ItemDBScript.get_item(entry["id"])
					if item:
						inv.slots[i] = ItemStackClass.new(item, int(entry.get("count", 1)))
			inv.changed.emit()

		# 装备
		var equip_mgr: Node = _player.get_node_or_null("EquipmentManager")
		if equip_mgr:
			var idx: int = pd.get("equipment_index", 0)
			equip_mgr.equip_index(idx)

	# ── 世界状态 ──
	var wd: Dictionary = data.get("world", {})

	# 昼夜时间
	if _day_night and wd.has("day_time"):
		_day_night.set("game_time", float(wd["day_time"]))

	# 建筑
	for bd in wd.get("buildings", []):
		var res_path: String = bd.get("resource_path", "")
		if res_path.is_empty() or not ResourceLoader.exists(res_path):
			continue
		var bres: Resource = load(res_path)
		if not bres:
			continue
		var pos := Vector3(
			bd.get("px", 0.0), bd.get("py", 0.0), bd.get("pz", 0.0)
		)
		var rot_y: float = bd.get("rot_y", 0.0)
		place_building(bres, pos, rot_y, true)

	print("[World3D] 存档加载完成 (slot %d)" % _save_slot)
	# 恢复完成后立即保存一次（覆盖 _on_game_started 中的初始保存）
	_save_current_game.call_deferred()

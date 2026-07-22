extends Node3D
## 3D 世界管理器

const WORLD_HALF: float = 50.0
const OBSTACLE_COUNT: int = 100
const MINIMAP_SIZE := Vector2(220, 220)

var _obstacle_positions: Array[Vector3] = []
var _obstacle_data: Array[Dictionary] = []
var _day_night: Node
var _player: CharacterBody3D


func _ready() -> void:
	# 默认全屏启动
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# 先显示角色选择界面
	var StartScript := load("res://scripts/start_screen.gd")
	var start_scr := CanvasLayer.new()
	start_scr.set_script(StartScript)
	start_scr.name = "StartScreen"
	start_scr.started.connect(_on_game_started)
	add_child(start_scr)


func _on_game_started(model_path: String, skin_path: String) -> void:
	# 玩家选好角色后，构建世界
	_create_lighting()
	_create_ground()
	_create_obstacles()
	_create_boundary()
	_create_player(model_path, skin_path)
	_create_animals()
	_create_camera(_player)
	_create_minimap(_player)
	_create_equipment_hud(_player)
	_create_menu()
	_create_day_night_system()


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
# 边界墙
# ═══════════════════════════════════════════

func _create_boundary() -> void:
	var hw := WORLD_HALF
	var wall_height := 3.0
	var wall_thickness := 0.5

	for i in range(4):
		var wall := MeshInstance3D.new()
		wall.name = "Wall_%d" % i
		var box := BoxMesh.new()
		match i:
			0: box.size = Vector3(hw * 2, wall_height, wall_thickness); wall.position = Vector3(0, wall_height / 2, -hw)
			1: box.size = Vector3(hw * 2, wall_height, wall_thickness); wall.position = Vector3(0, wall_height / 2, hw)
			2: box.size = Vector3(wall_thickness, wall_height, hw * 2); wall.position = Vector3(-hw, wall_height / 2, 0)
			3: box.size = Vector3(wall_thickness, wall_height, hw * 2); wall.position = Vector3(hw, wall_height / 2, 0)

		wall.mesh = box
		var wall_mat := StandardMaterial3D.new()
		wall_mat.albedo_color = Color(0.5, 0.35, 0.2)
		wall_mat.roughness = 0.75
		wall_mat.metallic = 0.1
		wall.material_override = wall_mat
		add_child(wall)

		var sb := StaticBody3D.new()
		sb.name = "WallBody_%d" % i
		sb.position = wall.position
		var sc := CollisionShape3D.new()
		var shp := BoxShape3D.new()
		shp.size = box.size
		sc.shape = shp
		sb.add_child(sc)
		add_child(sb)


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


func _make_material_presets() -> Array[StandardMaterial3D]:
	var presets: Array[StandardMaterial3D] = []
	var stone := StandardMaterial3D.new(); stone.roughness = 0.85; stone.metallic = 0.0; presets.append(stone)
	var polished := StandardMaterial3D.new(); polished.roughness = 0.4; polished.metallic = 0.15; presets.append(polished)
	var glossy := StandardMaterial3D.new(); glossy.roughness = 0.15; glossy.metallic = 0.05; glossy.clearcoat = 0.3; glossy.clearcoat_roughness = 0.1; presets.append(glossy)
	var metal := StandardMaterial3D.new(); metal.roughness = 0.2; metal.metallic = 0.9; metal.metallic_specular = 0.5; presets.append(metal)
	return presets


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
# 菜单
# ═══════════════════════════════════════════

func _create_menu() -> void:
	var MenuScript := load("res://scripts/menu_manager.gd")
	var menu := CanvasLayer.new()
	menu.set_script(MenuScript)
	menu.name = "MenuManager"
	add_child(menu)

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
	add_child(_day_night)

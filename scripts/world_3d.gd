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
var _lava: Node3D
var _buildings_data: Array[Dictionary] = []  # 建筑记录 [{resource_path, position, rot_y}]
var _play_time: float = 0.0                 # 累计游玩时间（秒）
var _save_slot: int = -1                    # 当前存档槽位
var _game_started: bool = false             # 游戏是否已开始（用于自动存档）
var _auto_save_timer: float = 0.0            # 自动存档计时器
var _save_toast: Label                        # 自动存档提示标签
var _hp_fill: ColorRect                       # 血条填充引用
var _hp_label: Label                          # 血条文本引用
var _damage_flash: ColorRect                  # 受伤红色闪烁
var _height_label: Label
var _loading_save: bool = false               # 是否正在加载存档（跳过初始保存）
var _resource_positions: Array[Dictionary] = []  # 资源节点位置存档 [{kind, pos_x, pos_z}]
var _regen_timer: float = 0.0                    # 资源重生计时器
var _animal_regen_timer: float = 0.0              # 动物重生计时器
var _terrain_max_y: float = 0.0                   # 地形最高点 Y（用于初始站位估算）


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
	_loading_save = true
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
	_create_lava()
	_create_player(model_path, skin_path)
	_lava.setup(_player, _player.get_health())
	_create_day_night_system()       # ★ 必须在动物之前创建
	if not _loading_save:
		_create_resource_nodes()
	_create_animals()
	_create_camera(_player)
	_create_minimap(_player)
	_create_equipment_hud(_player)
	_create_inventory_ui()
	_create_build_system()
	_create_death_screen()
	_create_menu()
	_create_time_display()
	_create_hp_bar()
	_create_height_display()
	_create_damage_flash()
	_game_started = true
	# 创建自动存档提示
	_create_save_toast()
	# 加载存档时跳过初始保存（_restore_from_save 最后会保存）
	if not _loading_save:
		_save_current_game.call_deferred()
	_loading_save = false


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
	const TERRAIN_PATH := "res://models/landscape/地形.glb"
	if not ResourceLoader.exists(TERRAIN_PATH):
		# 回退：程序化地面
		var total_size := WORLD_HALF * 2.0
		var ground := MeshInstance3D.new()
		ground.name = "Ground"
		var plane := PlaneMesh.new()
		plane.size = Vector2(total_size, total_size)
		ground.mesh = plane
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _make_terrain_texture()
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
		return

	var scene: PackedScene = load(TERRAIN_PATH)
	var terrain: Node3D = scene.instantiate()
	terrain.name = "Terrain"
	terrain.position = Vector3.ZERO
	add_child(terrain)

	# 计算地形整体 AABB
	var aabb := AABB()
	for mi in terrain.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh:
			var local_aabb := m.mesh.get_aabb()
			var global_aabb := m.global_transform * local_aabb
			if aabb.size.length_squared() < 0.01:
				aabb = global_aabb
			else:
				aabb = aabb.merge(global_aabb)

	# 将地形最低点沉到 y=0，中心对齐世界原点
	terrain.position = Vector3(-aabb.get_center().x, -aabb.position.y, -aabb.get_center().z)

	# 缩放地形使其 XZ 覆盖世界范围
	var terrain_xz := maxf(aabb.size.x, aabb.size.z)
	var target_xz := WORLD_HALF * 2.0
	var scale_factor := 1.0
	if terrain_xz > 0.01 and terrain_xz < target_xz:
		scale_factor = target_xz / terrain_xz
		terrain.scale = Vector3(scale_factor, 1.0, scale_factor)
		print("[World3D] 地形缩放: %.1f → %.1f (×%.2f)" % [terrain_xz, target_xz, scale_factor])

	# 手动创建碰撞体（从 mesh face 构建，放在世界根下避免变换继承问题）
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	add_child(body)

	var mesh_count := 0
	for mi in terrain.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh and mi.mesh.get_faces().size() > 0:
			var col := CollisionShape3D.new()
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(mi.mesh.get_faces())
			col.shape = shape
			# 用全局变换：terrain.position/scale/rotation × mesh 局部变换
			col.global_transform = terrain.global_transform * mi.transform
			body.add_child(col)
			mesh_count += 1

	print("[World3D] 地形加载完成, %d 个碰撞体, 缩放=%.1f, AABB=%s" % [mesh_count, scale_factor, aabb.size])


## 公开接口：获取地形表面高度（供建造等外部系统使用）
func get_terrain_height_at(x: float, z: float) -> float:
	return _get_terrain_height(x, z)


## 射线检测地表高度（从上方 100m 向下射）
func _get_terrain_height(x: float, z: float) -> float:
	var space := get_world_3d().direct_space_state
	var from := Vector3(x, 100.0, z)
	var to := Vector3(x, -100.0, z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # 地面/障碍物层
	var result := space.intersect_ray(query)
	if not result.is_empty():
		return result.position.y
	return 0.0


func _make_terrain_texture() -> Texture2D:
	var biome_noise := FastNoiseLite.new()
	biome_noise.seed = randi()
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	biome_noise.frequency = 0.015
	biome_noise.fractal_octaves = 4
	biome_noise.fractal_lacunarity = 2.0
	biome_noise.fractal_gain = 0.5

	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = randi()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.06
	detail_noise.fractal_octaves = 2

	var size := 512
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)

	for y in range(size):
		for x in range(size):
			var n := biome_noise.get_noise_2d(x, y)
			var d := detail_noise.get_noise_2d(x, y)
			var blend := d * 0.15

			var color: Color
			if n + blend > 0.25:
				var t := (n + blend - 0.25) / 0.75
				color = Color(0.22, 0.42, 0.12).lerp(Color(0.38, 0.55, 0.18), t)
			elif n + blend > -0.15:
				var t := (n + blend + 0.15) / 0.4
				color = Color(0.50, 0.33, 0.16).lerp(Color(0.22, 0.42, 0.12), t)
			else:
				var t := clampf((n + blend + 0.15) / 0.3, 0.0, 1.0)
				color = Color(0.55, 0.52, 0.48).lerp(Color(0.45, 0.38, 0.30), 1.0 - t)

			color *= 0.90 + 0.20 * d
			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


func _create_lava() -> void:
	var LavaScript := load("res://scripts/world/lava.gd")
	_lava = Node3D.new()
	_lava.set_script(LavaScript)
	_lava.name = "Lava"
	add_child(_lava)
	_lava.build(WORLD_HALF)


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

		var pos_x := rng.randf_range(margin, WORLD_HALF * 2 - margin) - WORLD_HALF
		var pos_z := rng.randf_range(margin, WORLD_HALF * 2 - margin) - WORLD_HALF
		var pos := Vector3(pos_x, _get_terrain_height(pos_x, pos_z) + h / 2.0, pos_z)

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
				var rx := rng.randf_range(-WORLD_HALF + 4.0, WORLD_HALF - 4.0)
				var rz := rng.randf_range(-WORLD_HALF + 4.0, WORLD_HALF - 4.0)
				pos = Vector3(rx, _get_terrain_height(rx, rz), rz)
				if is_area_free(pos, Vector2(1.0, 1.0)) and pos.distance_to(_player.global_position) > 6.0:
					found = true
					break
			if found:
				var node = ResNodeScript.spawn(self, kind, pos)
				register_occupied(node.occupied_aabb)
				_obstacle_data.append({"position": pos, "size": Vector3(1.5, 2.0, 1.5)})
				_resource_positions.append({"kind": kind, "pos_x": pos.x, "pos_z": pos.z})


## 从存档数据生成资源节点
func _spawn_resources_from_save() -> void:
	var ResNodeScript := load("res://scripts/world/resource_node.gd")
	for r in _resource_positions:
		var kind: String = r.get("kind", "tree")
		var sx := r.get("pos_x", 0.0) as float
		var sz := r.get("pos_z", 0.0) as float
		var pos := Vector3(sx, _get_terrain_height(sx, sz), sz)
		if is_area_free(pos, Vector2(1.0, 1.0)):
			var node = ResNodeScript.spawn(self, kind, pos)
			register_occupied(node.occupied_aabb)
			_obstacle_data.append({"position": pos, "size": Vector3(1.5, 2.0, 1.5)})


## 白天资源缓慢重生
func _try_regen_resource() -> void:
	if not _day_night:
		return
	var hours: float = _day_night.get_time_hours()
	# 只在白天 (6:00-19:00) 重生
	if hours < 6.0 or hours >= 19.0:
		return
	# 资源总数控制
	if _resource_positions.size() >= 50:
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var kind := "tree" if rng.randf() < 0.6 else "rock"
	var ResNodeScript := load("res://scripts/world/resource_node.gd")

	for attempt in range(30):
		var rx := rng.randf_range(-WORLD_HALF + 4.0, WORLD_HALF - 4.0)
		var rz := rng.randf_range(-WORLD_HALF + 4.0, WORLD_HALF - 4.0)
		var pos := Vector3(rx, _get_terrain_height(rx, rz), rz)
		if not _player or pos.distance_to(_player.global_position) < 8.0:
			continue
		if is_area_free(pos, Vector2(1.0, 1.0)):
			var node = ResNodeScript.spawn(self, kind, pos)
			register_occupied(node.occupied_aabb)
			_obstacle_data.append({"position": pos, "size": Vector3(1.5, 2.0, 1.5)})
			_resource_positions.append({"kind": kind, "pos_x": pos.x, "pos_z": pos.z})
			return


## 白天动物缓慢重生
func _try_regen_animal() -> void:
	if not _day_night:
		return
	var hours: float = _day_night.get_time_hours()
	if hours < 6.0 or hours >= 19.0:
		return

	# 统计存活动物
	var count := 0
	for body in get_tree().get_nodes_in_group("damageable"):
		if body is RigidBody3D:
			count += 1
	if count >= 30:
		return

	_spawn_single_animal()


func _spawn_single_animal() -> void:
	const MODEL_DIR := "res://models/animals/"
	const ANIMALS := [
		"animal-beaver.glb", "animal-bee.glb", "animal-bunny.glb",
		"animal-cat.glb", "animal-caterpillar.glb", "animal-chick.glb",
		"animal-cow.glb", "animal-crab.glb", "animal-deer.glb",
		"animal-dog.glb", "animal-elephant.glb", "animal-fish.glb",
		"animal-fox.glb", "animal-giraffe.glb", "animal-hog.glb",
		"animal-koala.glb", "animal-lion.glb", "animal-monkey.glb",
		"animal-panda.glb", "animal-parrot.glb", "animal-penguin.glb",
		"animal-pig.glb", "animal-polar.glb", "animal-tiger.glb",
	]

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var pos: Vector3
	var found := false
	for attempt in range(30):
		var ax := rng.randf_range(-WORLD_HALF + 4.0, WORLD_HALF - 4.0)
		var az := rng.randf_range(-WORLD_HALF + 4.0, WORLD_HALF - 4.0)
		pos = Vector3(ax, 50.0, az)
		if _player and pos.distance_to(_player.global_position) < 10.0:
			continue
		if is_area_free(pos, Vector2(1.0, 1.0)):
			found = true
			break
	if not found:
		return

	var model_idx := rng.randi_range(0, ANIMALS.size() - 1)
	var model_path: String = MODEL_DIR + ANIMALS[model_idx]
	if not ResourceLoader.exists(model_path):
		return

	var scene: PackedScene = load(model_path)
	if not scene:
		return

	var s: float = rng.randf_range(0.4, 0.5)
	var ry: float = rng.randf_range(0.0, TAU)

	var body := RigidBody3D.new()
	body.name = ANIMALS[model_idx].trim_suffix(".glb")
	body.position = pos
	body.mass = 1.0
	body.gravity_scale = 1.0
	body.collision_layer = 2
	body.collision_mask = 1
	body.linear_damp = 0.6
	body.angular_damp = 0.9
	body.continuous_cd = true
	add_child(body)

	var model_root: Node3D = scene.instantiate()
	model_root.name = "Model"
	model_root.scale = Vector3(s, s, s)
	model_root.rotation.y = ry
	body.add_child(model_root)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25 * s
	shape.height = 0.6 * s
	col.shape = shape
	col.position = Vector3(0, shape.height * 0.5, 0)
	body.add_child(col)

	var BehaviorScript := load("res://scripts/animal_behavior.gd")
	var behavior := Node.new()
	behavior.set_script(BehaviorScript)
	behavior.name = "Behavior"
	behavior.set("hop_impulse", randf_range(1.5, 3.0))
	behavior.set("hop_up", randf_range(2.5, 5.0))
	behavior.set("world_boundary", WORLD_HALF - 1.0)
	body.add_child(behavior)

	body.add_to_group("damageable")
	var HealthScript := load("res://scripts/combat/health.gd")
	var health := Node.new()
	health.set_script(HealthScript)
	health.name = "Health"
	health.set("max_hp", 30.0)
	health.set_particle_color(Color(0.75, 0.3, 0.3))
	body.add_child(health)

	var ItemDBScript := load("res://scripts/core/item_db.gd")
	var PickupScript := load("res://scripts/combat/pickup.gd")
	health.died.connect(func():
		var meat: Resource = ItemDBScript.get_item("meat")
		if meat:
			PickupScript.spawn(self, meat, randi_range(1, 2), body.global_position)
		body.queue_free()
	)


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
	_player.position = Vector3(0, 50.0, 0)  # 从高处落下，重力自动着陆地形
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
	var mgr: Node = _player.get_node_or_null("EquipmentManager")
	var UIScript := load("res://scripts/inventory/inventory_ui.gd")
	var ui := CanvasLayer.new()
	ui.set_script(UIScript)
	ui.name = "InventoryUI"
	add_child(ui)
	ui.setup(_player.get_inventory(), mgr)
	ui.item_used.connect(_on_item_used)
	if mgr and mgr.has_signal("consumable_used"):
		mgr.consumable_used.connect(_on_consumable_used)


func _on_item_used(item: Resource, _slot: int) -> void:
	var health: Health = _player.get_health() as Health
	if health:
		var heal: float = item.get("heal_amount")
		health.heal(heal)
		_update_hp_bar()


func _on_consumable_used(_slot: int, _heal_amount: float) -> void:
	_update_hp_bar()


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
	if hud and hud.has_method("refresh_key_labels"):
		keybind.bindings_changed.connect(hud.refresh_key_labels)
		# 首次同步：KeybindMenu 加载保存的键位后，强制刷新装备栏标签
		hud.refresh_key_labels.call_deferred()


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

	_hp_fill = ColorRect.new()
	_hp_fill.name = "HPFill"
	_hp_fill.position = Vector2(18, 283)
	_hp_fill.size = Vector2(214, 20)
	_hp_fill.color = Color(0.2, 0.85, 0.2)
	layer.add_child(_hp_fill)

	_hp_label = Label.new()
	_hp_label.name = "HPLabel"
	_hp_label.position = Vector2(18, 283)
	_hp_label.size = Vector2(214, 20)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 13)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.text = "100 / 100"
	layer.add_child(_hp_label)

	var health: Health = _player.get_health() as Health
	health.damaged.connect(_on_hp_changed)
	_update_hp_bar()


func _create_height_display() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HeightLayer"
	layer.layer = 40
	add_child(layer)

	_height_label = Label.new()
	_height_label.name = "HeightLabel"
	_height_label.position = Vector2(15, 312)
	_height_label.size = Vector2(120, 22)
	_height_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_height_label.add_theme_font_size_override("font_size", 13)
	_height_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_height_label.text = "Y: 0.0m"
	layer.add_child(_height_label)


func _update_height_display() -> void:
	if not _player:
		return
	var y := _player.global_position.y
	_height_label.text = "Y: %.1fm" % y


func _on_hp_changed(amount: float, from: Vector3) -> void:
	_update_hp_bar()
	if amount > 0.0:
		_show_damage_flash()
		_knockback_player(from)


func _create_damage_flash() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DamageFlashLayer"
	layer.layer = 380
	add_child(layer)
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(1, 0, 0, 0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_damage_flash)


func _show_damage_flash() -> void:
	if not _damage_flash:
		return
	_damage_flash.color = Color(1, 0, 0, 0.3)
	var tw := create_tween()
	tw.tween_property(_damage_flash, "color:a", 0.0, 0.3)


func _tint_player_red() -> void:
	if not _player:
		return
	for mesh: MeshInstance3D in _player.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mesh.mesh
		if not m:
			continue
		for i in m.get_surface_count():
			var mat := mesh.get_active_material(i)
			if not mat:
				continue
			mat = mat.duplicate()
			var std_mat := mat as StandardMaterial3D
			if not std_mat:
				continue
			var orig_color: Color = std_mat.albedo_color
			std_mat.albedo_color = Color.RED
			mesh.set_surface_override_material(i, mat)
			# 0.3秒后恢复原色
			var tw := create_tween()
			tw.tween_property(std_mat, "albedo_color", orig_color, 0.3)


func _knockback_player(from: Vector3) -> void:
	if not _player or from == Vector3.ZERO:
		return
	var dir := (_player.global_position - from)
	dir.y = 0.0
	# 自己对自己造成的伤害（溺水）不触发击退
	if dir.length_squared() < 0.01:
		return
	dir = dir.normalized()
	# 击退只做水平，不干扰跳跃判定
	_player.apply_knockback(dir, 8.0)


func _update_hp_bar() -> void:
	if not _player or not _hp_fill or not _hp_label:
		return
	var health: Health = _player.get_health() as Health
	if not health:
		return
	var ratio := clampf(health.hp / health.max_hp, 0.0, 1.0)
	_hp_fill.size.x = 214.0 * ratio

	if ratio > 0.5:
		_hp_fill.color = Color(0.2, 0.85, 0.2).lerp(Color(0.85, 0.85, 0.1), (1.0 - ratio) * 2.0)
	else:
		_hp_fill.color = Color(0.85, 0.85, 0.1).lerp(Color(0.85, 0.15, 0.1), (0.5 - ratio) * 2.0)

	_hp_label.text = "%d / %d" % [int(ceil(health.hp)), int(health.max_hp)]


# ═══════════════════════════════════════════
# 游玩时间 & 退出存档
# ═══════════════════════════════════════════

func _process(delta: float) -> void:
	if _game_started:
		_play_time += delta
		_auto_save_timer += delta
		_regen_timer += delta
		if _regen_timer >= 30.0:
			_regen_timer = 0.0
			_try_regen_resource()
		_animal_regen_timer += delta
		if _animal_regen_timer >= 45.0:
			_animal_regen_timer = 0.0
			_try_regen_animal()
		if _auto_save_timer >= 60.0:
			_auto_save_timer = 0.0
			_save_current_game()

		_update_height_display()


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

	# 装备（新结构）
	var equip_mgr: Node = _player.get_node_or_null("EquipmentManager")
	var equip_data: Dictionary = equip_mgr.get_save_data() if equip_mgr else {}

	return {
		"pos_x": pos.x, "pos_y": pos.y, "pos_z": pos.z,
		"health": hp,
		"inventory": inv_data,
		"equipment": equip_data,
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

	var animal_count := 0
	for body in get_tree().get_nodes_in_group("damageable"):
		if body is RigidBody3D:
			animal_count += 1

	return {
		"day_time": day_time,
		"buildings": buildings,
		"resources": _resource_positions,
		"animal_count": animal_count,
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
	print("[World3D] 开始加载存档 (slot %d)..." % _save_slot)
	if not _player:
		print("[World3D] 错误: _player 不存在")
		return

	# ── 玩家状态 ──
	var pd: Dictionary = data.get("player", {})
	if not pd.is_empty():
		var saved_pos := Vector3(
			pd.get("pos_x", 0.0), pd.get("pos_y", 0.0), pd.get("pos_z", 0.0)
		)
		_player.global_position = saved_pos
		print("[World3D] 位置恢复: ", saved_pos)

		var health_node: Health = _player.get_health() as Health
		if health_node:
			var saved_hp: float = pd.get("health", 100.0)
			health_node.set("hp", saved_hp)
			print("[World3D] 血量恢复: ", saved_hp)
			_update_hp_bar()

		# 背包
		var inv: Node = _player.get_inventory()
		if inv:
			inv.slots.clear()
			inv.slots.resize(inv.slot_count)
			var ItemDBScript := load("res://scripts/core/item_db.gd")
			var ItemStackClass := load("res://scripts/core/item_stack.gd")
			var inv_arr: Array = pd.get("inventory", [])
			for i in range(inv_arr.size()):
				var entry = inv_arr[i]
				if entry and entry.get("id"):
					var item: Resource = ItemDBScript.get_item(entry["id"])
					if item:
						inv.slots[i] = ItemStackClass.new(item, int(entry.get("count", 1)))
			inv.changed.emit()
			print("[World3D] 背包恢复: %d 项" % inv_arr.size())

			# 装备
			var equip_mgr: Node = _player.get_node_or_null("EquipmentManager")
			if equip_mgr:
				if pd.has("equipment"):
					equip_mgr.restore_from_data(pd["equipment"])
					print("[World3D] 装备恢复: 新格式")
				elif pd.has("equipment_index"):
					print("[World3D] 装备恢复: 旧存档格式，装备已重置（请在游戏中重新装备）")

	# ── 世界状态 ──
	var wd: Dictionary = data.get("world", {})

	# 昼夜时间
	if _day_night and wd.has("day_time"):
		_day_night.set("game_time", float(wd["day_time"]))
		print("[World3D] 昼夜恢复: ", wd["day_time"])

	# 资源节点：用存档位置取代随机生成
	var resources: Array = wd.get("resources", [])
	if not resources.is_empty():
		_resource_positions.clear()
		for r in resources:
			_resource_positions.append(r as Dictionary)
		_spawn_resources_from_save()
		print("[World3D] 资源恢复: %d 个" % resources.size())

	# 建筑
	var bld_count := 0
	for bd in wd.get("buildings", []):
		var res_path: String = bd.get("resource_path", "")
		if res_path.is_empty() or not ResourceLoader.exists(res_path):
			print("[World3D] 跳过建筑: 资源不存在 ", res_path)
			continue
		var bres: Resource = load(res_path)
		if not bres:
			continue
		var pos := Vector3(
			bd.get("px", 0.0), bd.get("py", 0.0), bd.get("pz", 0.0)
		)
		var rot_y: float = bd.get("rot_y", 0.0)
		place_building(bres, pos, rot_y, true)
		# 同时重建 _buildings_data
		_buildings_data.append({
			"resource_path": res_path,
			"position": pos,
			"rot_y": rot_y,
		})
		bld_count += 1

	print("[World3D] 存档加载完成 (slot %d): 建筑=%d, 动物=%d" % [_save_slot, bld_count, wd.get("animal_count", 0)])
	# 恢复完成后立即保存一次（覆盖 _on_game_started 中的初始保存）
	_save_current_game.call_deferred()

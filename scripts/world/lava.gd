extends Node3D
class_name Lava
## 岩浆：环绕岛屿的熔岩层（滚动噪声贴图），玩家越界落入持续掉血致死

const TERRAIN_QUERY_LAYER: int = 1 << 3  # 与 world_3d.gd 中地形专用射线层一致

@export var lava_damage_per_sec: float = 60.0
@export var sink_speed: float = 2.0
@export var fall_kill_y: float = -20.0
@export var scroll_speed := Vector2(0.015, 0.01)

var _mat: StandardMaterial3D
var _world_half: float = 50.0
var _terrain_boundary: Array[float] = []
var _player: Node3D
var _health: Health
var _was_in_lava: bool = false
var _physics_ready: bool = false


func build(world_half: float, terrain_boundary: Array[float] = []) -> void:
	_world_half = world_half
	_terrain_boundary = terrain_boundary

	var surface := MeshInstance3D.new()
	surface.name = "LavaSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	surface.mesh = plane
	surface.position = Vector3(0, -0.35, 0)

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.418, 0.172, 0.046, 1.0)
	_mat.albedo_texture = _make_lava_texture()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.roughness = 0.6
	_mat.metallic = 0.3
	_mat.emission_enabled = true
	_mat.emission = Color(0.899, 0.253, 0.0, 1.0)
	_mat.emission_energy_multiplier = 0.4
	_mat.uv1_scale = Vector3(20, 20, 20)
	surface.material_override = _mat
	add_child(surface)


func _make_lava_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.06
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	return tex


func setup(player: Node3D, health: Health) -> void:
	_player = player
	_health = health
	# 等地形碰撞体注册进物理空间后再用射线做精确判定
	await get_tree().physics_frame
	_physics_ready = true


## 玩家正下方是否存在地形碰撞体（只查地形专用层）
func _has_terrain_below(p: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		p + Vector3(0.0, 10.0, 0.0),
		p + Vector3(0.0, -60.0, 0.0)
	)
	query.collision_mask = TERRAIN_QUERY_LAYER
	return not space.intersect_ray(query).is_empty()


## 类圆形地形边界：点是否落在岛外
## 优先使用真实地形碰撞射线（任何轮廓凹陷/凸出都不会漏判），物理未就绪时回退径向边界
func _is_outside_terrain(p: Vector3) -> bool:
	if _physics_ready:
		return not _has_terrain_below(p)

	if _terrain_boundary.is_empty():
		return abs(p.x) > _world_half or abs(p.z) > _world_half
	var samples := float(_terrain_boundary.size())
	var angle := atan2(p.z, p.x)
	var f := angle / TAU * samples
	if f < 0.0:
		f += samples
	var i0 := int(floor(f)) % _terrain_boundary.size()
	var i1 := (i0 + 1) % _terrain_boundary.size()
	var t: float = f - floor(f)
	var limit := lerpf(_terrain_boundary[i0], _terrain_boundary[i1], t)
	var r := sqrt(p.x * p.x + p.z * p.z)
	return r > limit


func _process(delta: float) -> void:
	if _mat:
		_mat.uv1_offset += Vector3(scroll_speed.x, scroll_speed.y, 0) * delta

	if _player == null or _health == null or _health.is_dead():
		if _was_in_lava:
			_was_in_lava = false
			if _player and _player.has_method("set_in_water"):
				_player.set_in_water(false)
		return

	var p := _player.global_position
	var in_lava: bool = _is_outside_terrain(p)

	if in_lava != _was_in_lava:
		_was_in_lava = in_lava
		if _player.has_method("set_in_water"):
			_player.set_in_water(in_lava)

	if in_lava:
		_health.take_damage(lava_damage_per_sec * delta, p)
	elif p.y < fall_kill_y:
		_health.take_damage(10000.0, p)

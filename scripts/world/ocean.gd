extends Node3D
class_name Ocean
## 海洋：环绕岛屿的水面（滚动噪声贴图），玩家越界落水持续掉血致死

@export var water_damage_per_sec: float = 45.0
@export var fall_kill_y: float = -6.0     # 掉到这个深度直接死
@export var scroll_speed := Vector2(0.012, 0.007)

var _mat: StandardMaterial3D
var _world_half: float = 50.0
var _player: Node3D
var _health: Health


## 创建水面网格（在玩家创建前调用）
func build(world_half: float) -> void:
	_world_half = world_half

	var water := MeshInstance3D.new()
	water.name = "WaterSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	water.mesh = plane
	water.position = Vector3(0, -0.35, 0)

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.06, 0.28, 0.48, 0.88)
	_mat.albedo_texture = _make_water_texture()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.roughness = 0.15
	_mat.metallic = 0.4
	_mat.uv1_scale = Vector3(24, 24, 24)
	water.material_override = _mat
	add_child(water)


func _make_water_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.08
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	return tex


## 玩家创建后调用，接入伤害判定
func setup(player: Node3D, health: Health) -> void:
	_player = player
	_health = health


func _process(delta: float) -> void:
	if _mat:
		_mat.uv1_offset += Vector3(scroll_speed.x, scroll_speed.y, 0) * delta

	if _player == null or _health == null or _health.is_dead():
		return

	var p := _player.global_position
	if p.y < fall_kill_y:
		_health.take_damage(10000.0, p)
	elif abs(p.x) > _world_half or abs(p.z) > _world_half or p.y < -0.6:
		_health.take_damage(water_damage_per_sec * delta, p)

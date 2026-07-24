extends Node3D
class_name Lava
## 岩浆：环绕岛屿的熔岩层（滚动噪声贴图），玩家越界落入持续掉血致死

@export var lava_damage_per_sec: float = 60.0
@export var sink_speed: float = 2.0
@export var fall_kill_y: float = -20.0
@export var scroll_speed := Vector2(0.015, 0.01)

var _mat: StandardMaterial3D
var _world_half: float = 50.0
var _player: Node3D
var _health: Health
var _was_in_lava: bool = false


func build(world_half: float) -> void:
	_world_half = world_half

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
	var in_lava: bool = abs(p.x) > _world_half or abs(p.z) > _world_half

	if in_lava != _was_in_lava:
		_was_in_lava = in_lava
		if _player.has_method("set_in_water"):
			_player.set_in_water(in_lava)

	if in_lava:
		_health.take_damage(lava_damage_per_sec * delta, p)
	elif p.y < fall_kill_y:
		_health.take_damage(10000.0, p)

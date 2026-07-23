extends Node
class_name AnimalSpawner
## 在世界中随机生成小动物（RigidBody3D，可被玩家推动）

@export var count: int = 30
@export var min_scale: float = 0.4
@export var max_scale: float = 0.5
@export var spawn_margin: float = 6.0

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

var _obstacle_data: Array[Dictionary] = []
var _world_half: float = 50.0
var _player_pos: Vector3 = Vector3.ZERO


func setup(world_half: float, obstacle_data: Array[Dictionary], player_pos: Vector3) -> void:
	_world_half = world_half
	_obstacle_data = obstacle_data
	_player_pos = player_pos


func spawn_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(count):
		var attempts := 0
		var pos: Vector3
		var found := false

		while attempts < 50 and not found:
			pos = Vector3(
				rng.randf_range(-_world_half + spawn_margin, _world_half - spawn_margin),
				0,
				rng.randf_range(-_world_half + spawn_margin, _world_half - spawn_margin)
			)
			if _is_position_clear(pos) and pos.distance_to(_player_pos) > 5.0:
				found = true
			attempts += 1

		if found:
			var model_idx := rng.randi_range(0, ANIMALS.size() - 1)
			var s: float = rng.randf_range(min_scale, max_scale)
			var ry: float = rng.randf_range(0.0, TAU)
			_spawn_animal(ANIMALS[model_idx], pos, s, ry)


func _is_position_clear(pos: Vector3) -> bool:
	for obs in _obstacle_data:
		var opos: Vector3 = obs["position"]
		var osize: Vector3 = obs["size"]
		var half_x: float = osize.x * 0.5 + spawn_margin
		var half_z: float = osize.z * 0.5 + spawn_margin
		if abs(pos.x - opos.x) < half_x and abs(pos.z - opos.z) < half_z:
			return false
	return true


func _spawn_animal(model_name: String, pos: Vector3, scale_val: float, rot_y: float) -> void:
	var model_path := MODEL_DIR + model_name
	if not ResourceLoader.exists(model_path):
		return

	var scene: PackedScene = load(model_path)
	if not scene:
		return

	var body := RigidBody3D.new()
	body.name = model_name.trim_suffix(".glb")
	body.position = pos
	body.mass = 1.0
	body.gravity_scale = 1.0
	body.collision_layer = 2
	body.collision_mask = 1  # 只与地面/障碍物碰撞
	body.linear_damp = 0.6
	body.angular_damp = 0.9
	body.continuous_cd = true  # 连续碰撞检测，防止高速穿透薄地面
	add_child(body)

	var model_root: Node3D = scene.instantiate()
	model_root.name = "Model"
	model_root.scale = Vector3(scale_val, scale_val, scale_val)
	model_root.rotation.y = rot_y
	body.add_child(model_root)

	# 小胶囊碰撞体
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25 * scale_val
	shape.height = 0.6 * scale_val
	col.shape = shape
	col.position = Vector3(0, shape.height * 0.5, 0)
	body.add_child(col)

	# 关阴影
	for mesh: MeshInstance3D in model_root.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 挂载随机弹跳行为
	var BehaviorScript := load("res://scripts/animal_behavior.gd")
	var behavior := Node.new()
	behavior.set_script(BehaviorScript)
	behavior.name = "Behavior"
	behavior.set("hop_impulse", randf_range(1.5, 3.0))
	behavior.set("hop_up", randf_range(2.5, 5.0))
	behavior.set("world_boundary", _world_half - 1.0)  # 边界安全距离
	body.add_child(behavior)

	# 血量 + 可被近战攻击 + 死亡掉落
	body.add_to_group("damageable")
	var HealthScript := load("res://scripts/combat/health.gd")
	var health := Node.new()
	health.set_script(HealthScript)
	health.name = "Health"
	health.set("max_hp", 30.0)
	health.set_particle_color(Color(0.75, 0.3, 0.3))
	body.add_child(health)
	health.died.connect(_on_animal_died.bind(body))


func _on_animal_died(body: RigidBody3D) -> void:
	var pos := body.global_position
	var ItemDBScript := load("res://scripts/core/item_db.gd")
	var PickupScript := load("res://scripts/combat/pickup.gd")
	var meat: Resource = ItemDBScript.get_item("meat")
	if meat:
		PickupScript.spawn(self, meat, randi_range(1, 2), pos)
	body.queue_free()

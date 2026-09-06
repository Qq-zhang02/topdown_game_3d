extends StaticBody3D
class_name ResourceNode
## 可采集资源节点：树（掉木材）/ 石头（掉石头）
## 近战攻击削减血量，血量归零后爆掉落物并消失
## 外观由 scenes/prefabs/ 下预制体定义（编辑器可视化），预制体缺失时回退程序化构建

const ItemDBClass := preload("res://scripts/core/item_db.gd")
const PickupClass := preload("res://scripts/combat/pickup.gd")

var drop_id: String = ""
var drop_min: int = 2
var drop_max: int = 4
var occupied_aabb: AABB  # 占地区域，销毁时通知世界释放


## kind: "tree" | "rock"
static func spawn(parent: Node, kind: String, pos: Vector3) -> ResourceNode:
	var node: ResourceNode = null
	var scene_path := "res://scenes/prefabs/tree.tscn" if kind == "tree" else "res://scenes/prefabs/rock.tscn"
	if ResourceLoader.exists(scene_path):
		var ps: PackedScene = load(scene_path)
		if ps:
			node = ps.instantiate() as ResourceNode

	if node == null:
		# 回退：程序化构建（预制体缺失时）
		node = ResourceNode.new()
		node._fallback_build(kind)

	node.name = "Resource_" + kind
	node.position = pos
	node.collision_layer = 1
	node.collision_mask = 0
	node.add_to_group("damageable")
	if kind == "tree":
		# 树冠团簇非对称：随机朝向+轻微缩放让每棵树外观不同
		node.rotate_y(randf() * TAU)
		node.scale = Vector3.ONE * randf_range(0.9, 1.1)

	match kind:
		"tree":
			node.drop_id = "wood"
			node.drop_min = 2
			node.drop_max = 4
		"rock":
			node.drop_id = "stone"
			node.drop_min = 2
			node.drop_max = 4

	# Health 参数在 add_child 前设置（Health._ready() 会快照 hp = max_hp）
	var health_node: Node = node.get_node_or_null("Health")
	if health_node:
		if kind == "tree":
			health_node.set("max_hp", 40.0)
			health_node.set_particle_color(Color(0.40, 0.26, 0.13))
			health_node.set_particle_offset_scale(0.3)
		else:
			health_node.set("max_hp", 60.0)
			health_node.set_particle_color(Color(0.45, 0.45, 0.48))
		if not health_node.died.is_connected(node._on_died):
			health_node.died.connect(node._on_died)

	parent.add_child(node)
	node._compute_occupied()
	return node


func _compute_occupied() -> void:
	if drop_id == "wood":
		occupied_aabb = AABB(global_position + Vector3(-0.6, 0, -0.6), Vector3(1.2, 3, 1.2))
	else:
		occupied_aabb = AABB(global_position + Vector3(-0.8, 0, -0.8), Vector3(1.6, 1.2, 1.6))


## 回退构建：预制体加载失败时的简易外观 + 碰撞 + Health
func _fallback_build(kind: String) -> void:
	var mesh := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.6
	m.height = 1.2
	mesh.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.40, 0.35, 0.3)
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.6, 0)
	add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 1.2
	col.shape = shape
	col.position = Vector3(0, 0.6, 0)
	add_child(col)

	var health := Node.new()
	health.name = "Health"
	health.set_script(preload("res://scripts/combat/health.gd"))
	add_child(health)


func _on_died() -> void:
	var parent := get_parent()
	var drops := randi_range(drop_min, drop_max)
	var item := ItemDBClass.get_item(drop_id)
	if parent and item:
		PickupClass.spawn(parent, item, drops, global_position)
	if parent and parent.has_method("unregister_occupied"):
		parent.unregister_occupied(occupied_aabb)
	queue_free()

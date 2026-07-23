extends StaticBody3D
class_name ResourceNode
## 可采集资源节点：树（掉木材）/ 石头（掉石头）
## 近战攻击削减血量，血量归零后爆掉落物并消失

const ItemDBClass := preload("res://scripts/core/item_db.gd")
const PickupClass := preload("res://scripts/combat/pickup.gd")
const HealthClass := preload("res://scripts/combat/health.gd")

var drop_id: String = ""
var drop_min: int = 2
var drop_max: int = 4
var occupied_aabb: AABB  # 占地区域，销毁时通知世界释放


## kind: "tree" | "rock"
static func spawn(parent: Node, kind: String, pos: Vector3) -> ResourceNode:
	var node := ResourceNode.new()
	node.name = "Resource_" + kind
	node.position = pos
	node.collision_layer = 1
	node.collision_mask = 0
	node.add_to_group("damageable")
	parent.add_child(node)

	match kind:
		"tree":
			node.drop_id = "wood"
			node.drop_min = 2
			node.drop_max = 4
			node._build_tree()
			node._add_health(40.0, Color(0.40, 0.26, 0.13))
		"rock":
			node.drop_id = "stone"
			node.drop_min = 2
			node.drop_max = 4
			node._build_rock()
			node._add_health(60.0, Color(0.45, 0.45, 0.48))
	return node


func _build_tree() -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.18
	trunk_mesh.height = 1.4
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0, 0.7, 0)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.40, 0.26, 0.13)
	trunk_mat.roughness = 0.9
	trunk.material_override = trunk_mat
	add_child(trunk)

	var leaves := MeshInstance3D.new()
	var leaves_mesh := SphereMesh.new()
	leaves_mesh.radius = 0.95
	leaves_mesh.height = 1.9
	leaves.mesh = leaves_mesh
	leaves.position = Vector3(0, 1.9, 0)
	var leaves_mat := StandardMaterial3D.new()
	leaves_mat.albedo_color = Color(0.18, 0.45, 0.15)
	leaves_mat.roughness = 0.85
	leaves.material_override = leaves_mat
	add_child(leaves)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 1.6
	col.shape = shape
	col.position = Vector3(0, 0.8, 0)
	add_child(col)

	occupied_aabb = AABB(global_position + Vector3(-0.6, 0, -0.6), Vector3(1.2, 3, 1.2))


func _build_rock() -> void:
	var rock := MeshInstance3D.new()
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.7
	rock_mesh.height = 1.0
	rock.mesh = rock_mesh
	rock.position = Vector3(0, 0.35, 0)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.45, 0.45, 0.48)
	rock_mat.roughness = 0.7
	rock_mat.metallic = 0.1
	rock.material_override = rock_mat
	add_child(rock)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.65
	col.shape = shape
	col.position = Vector3(0, 0.35, 0)
	add_child(col)

	occupied_aabb = AABB(global_position + Vector3(-0.8, 0, -0.8), Vector3(1.6, 1.2, 1.6))


func _add_health(hp: float, pc: Color = Color.WHITE) -> void:
	var health := Node.new()
	health.set_script(HealthClass)
	health.name = "Health"
	health.set("max_hp", hp)
	health.set_particle_color(pc)
	add_child(health)
	health.died.connect(_on_died)


func _on_died() -> void:
	var parent := get_parent()
	var drops := randi_range(drop_min, drop_max)
	var item := ItemDBClass.get_item(drop_id)
	if parent and item:
		PickupClass.spawn(parent, item, drops, global_position)
	if parent and parent.has_method("unregister_occupied"):
		parent.unregister_occupied(occupied_aabb)
	queue_free()

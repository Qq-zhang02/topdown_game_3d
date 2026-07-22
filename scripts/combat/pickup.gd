extends Node3D
class_name Pickup
## 地面掉落物：发光小方块 + 名称标签，玩家走近自动拾取
## 材料进背包；装备/武器直接进装备管理器

var item: Resource
var count: int = 1

var _base_y: float = 0.0
var _t: float = 0.0
var _mesh: MeshInstance3D
var _label: Label3D


## 在 parent 下生成一个掉落物
static func spawn(parent: Node, item_res: Resource, amount: int, pos: Vector3) -> void:
	if item_res == null:
		return
	var p := Pickup.new()
	p.item = item_res
	p.count = amount
	p.position = pos + Vector3(randf_range(-0.4, 0.4), 0.5, randf_range(-0.4, 0.4))
	parent.add_child(p)
	p._build()


func _build() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.32, 0.32, 0.32)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	var c: Color = item.get("ui_color")
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 0.6
	_mesh.material_override = mat
	add_child(_mesh)

	_label = Label3D.new()
	_label.position = Vector3(0, 0.55, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.pixel_size = 0.008
	_label.outline_size = 8
	_label.modulate = Color(1, 1, 1, 0.95)
	_update_label()
	add_child(_label)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1  # 玩家
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.1
	col.shape = sph
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_on_body_entered)

	_base_y = position.y


func _update_label() -> void:
	_label.text = "%s x%d" % [item.get("display_name"), count]


func _process(delta: float) -> void:
	_t += delta
	_mesh.rotation.y += delta * 2.0
	position.y = _base_y + sin(_t * 2.5) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	# 装备/武器 → 装备管理器；材料 → 背包
	var type: int = item.get("item_type")
	if type == 1 or type == 2:  # EQUIPMENT / WEAPON
		var mgr: Node = body.get_node_or_null("EquipmentManager")
		if mgr and mgr.has_method("add_equipment"):
			mgr.add_equipment(item.duplicate())
			queue_free()
		return

	var inv: Node = body.get_node_or_null("Inventory")
	if inv == null:
		return
	var leftover: int = inv.add_item(item, count)
	if leftover <= 0:
		queue_free()
	else:
		count = leftover
		_update_label()

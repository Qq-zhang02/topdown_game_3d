extends Node3D
class_name Pickup
## 地面掉落物：发光小方块 + 名称标签，玩家走近自动拾取
## 材料进背包；装备/武器直接进装备管理器

var item: Resource
var count: int = 1

var _can_pickup: bool = false
var _flying_to: Node3D = null
var _fly_speed: float = 6.0
var _area: Area3D

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
	p.position = pos + Vector3(randf_range(-0.3, 0.3), 2.0, randf_range(-0.3, 0.3))
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
	_area = area

	_base_y = position.y

	# 掉落动画：先禁用拾取，落地弹跳+滑行后才可拾取
	area.monitoring = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", 0.2, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var slide_x := randf_range(-0.8, 0.8)
	var slide_z := randf_range(-0.8, 0.8)
	tween.tween_property(self, "position:x", position.x + slide_x, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:z", position.z + slide_z, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_drop_finished)


func _update_label() -> void:
	_label.text = "%s x%d" % [item.get("display_name"), count]


func _process(delta: float) -> void:
	# 拾取飞行阶段：飞向玩家，缩小，加速旋转
	if _flying_to != null:
		var target := _flying_to.global_position
		target.y = global_position.y
		var dist := global_position.distance_to(target)
		global_position = global_position.move_toward(target, _fly_speed * delta)
		_mesh.rotation.y += delta * 6.0
		scale = Vector3.ONE * clamp(dist / 1.5, 0.05, 1.0)
		if dist < 0.3:
			_do_pickup(_flying_to)
		return

	# 掉落动画期间只旋转，不做浮动
	_mesh.rotation.y += delta * 2.0
	if not _can_pickup:
		return

	# 可拾取状态：正常浮动
	_t += delta
	position.y = _base_y + sin(_t * 2.5) * 0.12


func _on_drop_finished() -> void:
	_base_y = position.y
	_can_pickup = true
	_area.monitoring = true


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not _can_pickup or _flying_to != null:
		return

	# 所有物品先进背包
	var inv: Node = body.get_node_or_null("Inventory")
	if inv == null:
		return
	var leftover: int = inv.add_item(item, count)
	if leftover > 0:
		count = leftover
		_update_label()
		return

	# 开始飞向玩家
	_flying_to = body
	_area.monitoring = false


func _do_pickup(body: Node3D) -> void:
	queue_free()

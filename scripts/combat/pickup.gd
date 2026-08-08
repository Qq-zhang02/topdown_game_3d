extends Node3D
class_name Pickup
## 地面掉落物：发光小方块 + 名称标签，玩家走近自动拾取
## 所有物品统一进背包
## 外观由 scenes/prefabs/pickup.tscn 定义（编辑器可视化），预制体缺失时回退空节点

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
	var p: Pickup = null
	const PREFAB := "res://scenes/prefabs/pickup.tscn"
	if ResourceLoader.exists(PREFAB):
		var ps: PackedScene = load(PREFAB)
		if ps:
			p = ps.instantiate() as Pickup
	if p == null:
		p = Pickup.new()

	p.item = item_res
	p.count = amount
	p.position = pos + Vector3(randf_range(-0.3, 0.3), 2.0, randf_range(-0.3, 0.3))
	parent.add_child(p)
	p._init_drop()


func _init_drop() -> void:
	# 从预制体获取节点引用
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	_label = get_node_or_null("Label") as Label3D
	_area = get_node_or_null("Area") as Area3D

	# 覆盖材质颜色/发光（依赖运行时的 item.ui_color）
	if _mesh:
		var c: Color = item.get("ui_color")
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 0.6
		_mesh.material_override = mat

	_update_label()

	if _area and not _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.connect(_on_body_entered)

	_base_y = position.y

	# 探测地表高度作为落地目标
	var ground_y: float = 0.2
	if get_world_3d():
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(Vector3(position.x, 100.0, position.z), Vector3(position.x, -100.0, position.z))
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		ground_y = hit.position.y if not hit.is_empty() else 0.2

	# 掉落动画：先禁用拾取，落地弹跳+滑行后才可拾取
	if _area:
		_area.monitoring = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", ground_y + 0.2, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var slide_x := randf_range(-0.8, 0.8)
	var slide_z := randf_range(-0.8, 0.8)
	tween.tween_property(self, "position:x", position.x + slide_x, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:z", position.z + slide_z, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_drop_finished)


func _update_label() -> void:
	if _label:
		_label.text = "%s x%d" % [item.get("display_name"), count]


func _process(delta: float) -> void:
	# 拾取飞行阶段：飞向玩家，缩小，加速旋转
	if _flying_to != null:
		var target := _flying_to.global_position
		target.y = global_position.y
		var dist := global_position.distance_to(target)
		global_position = global_position.move_toward(target, _fly_speed * delta)
		if _mesh:
			_mesh.rotation.y += delta * 6.0
		scale = Vector3.ONE * clamp(dist / 1.5, 0.05, 1.0)
		if dist < 0.3:
			_do_pickup(_flying_to)
		return

	# 掉落动画期间只旋转，不做浮动
	if _mesh:
		_mesh.rotation.y += delta * 2.0
	if not _can_pickup:
		return

	# 可拾取状态：正常浮动
	_t += delta
	position.y = _base_y + sin(_t * 2.5) * 0.12


func _on_drop_finished() -> void:
	_base_y = position.y
	_can_pickup = true
	if _area:
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
	if _area:
		_area.monitoring = false


func _do_pickup(body: Node3D) -> void:
	queue_free()

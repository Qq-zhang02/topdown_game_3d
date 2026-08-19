extends Area3D
class_name Hazard
## 危险区组件：玩家/小动物触碰后周期性扣血 + 击退
## 挂载在建筑/物品下（如篝火），用于触碰到扣血击退的功能
## 后续地刺等危险物可复用：挂 Area3D + Hazard + CollisionShape3D

var damage: float = 5.0            # 每次触碰/每间隔扣血量
var damage_interval: float = 1.0   # 扣血间隔（秒）
var knockback: float = 4.0         # 击退冲量（0 = 不击退）
var knockback_up: float = 0.0      # 击退竖直分量
var animal_damage_multiplier: float = 1.0     # 小动物扣血倍率（相对玩家）
var animal_knockback_multiplier: float = 1.0  # 小动物击退倍率（相对玩家）

# 目标表：Node3D -> 距离下次扣血的剩余时间（秒）
# 用字典而不是单个引用，这样玩家 + 多个小动物可同时受危险区影响
var _victims := {}


## 初始化危险区参数
func setup(p_damage: float, p_interval: float, p_knockback: float, p_knockback_up: float = 0.0, p_animal_dmg_mult: float = 1.0, p_animal_kb_mult: float = 1.0) -> void:
	damage = p_damage
	damage_interval = maxf(p_interval, 0.1)
	knockback = p_knockback
	knockback_up = p_knockback_up
	animal_damage_multiplier = p_animal_dmg_mult
	animal_knockback_multiplier = p_animal_kb_mult
	collision_layer = 0          # 不参与碰撞，只做检测
	collision_mask = 1 | 2       # 检测层1（玩家/建筑）+ 层2（小动物）
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## 判定目标：玩家 或 带 Health 的刚体（小动物）。树/石头等静态资源不受篝火影响
func _is_victim(body: Node3D) -> bool:
	if body.is_in_group("player"):
		return true
	return body is RigidBody3D and body.get_node_or_null("Health") != null


func _on_body_entered(body: Node3D) -> void:
	if not _is_victim(body):
		return
	_victims[body] = damage_interval
	_hit(body)  # 触碰立即触发一次


func _on_body_exited(body: Node3D) -> void:
	_victims.erase(body)


func _process(delta: float) -> void:
	for body in _victims.keys():
		if not is_instance_valid(body):
			_victims.erase(body)
			continue
		_victims[body] -= delta
		if _victims[body] <= 0.0:
			_victims[body] = damage_interval
			_hit(body)


## 对单个目标扣血 + 击退
func _hit(body: Node3D) -> void:
	# 区分小动物（刚体）与玩家，小动物套用倍率
	var is_animal := body is RigidBody3D
	var dmg_mult := animal_damage_multiplier if is_animal else 1.0
	var kb_mult := animal_knockback_multiplier if is_animal else 1.0

	# 扣血（玩家通过 get_health()，小动物直接用名为 Health 的子节点）
	var health: Node = body.get_node_or_null("Health")
	if health == null and body.has_method("get_health"):
		health = body.get_health()
	if health and health.has_method("take_damage"):
		health.take_damage(damage * dmg_mult, global_position)

	# 击退：水平方向从危险区中心向外 + 独立竖直冲量（knockback_up）
	if knockback > 0.0:
		var dir := body.global_position - global_position
		dir.y = 0.0
		if dir.length_squared() < 0.01:
			dir = Vector3.FORWARD
		else:
			dir = dir.normalized()
		if is_animal:
			# 小动物是刚体：直接施加冲量（水平击退 + 上挑，均乘动物击退倍率）
			body.apply_central_impulse(dir * knockback * kb_mult + Vector3.UP * knockback_up * kb_mult)
		elif body.has_method("apply_knockback"):
			# 玩家：走 apply_knockback / apply_up_knockback（不受动物倍率影响）
			body.apply_knockback(dir, knockback)
			if knockback_up > 0.0 and body.has_method("apply_up_knockback"):
				body.apply_up_knockback(knockback_up)

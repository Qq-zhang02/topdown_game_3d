extends Area3D
class_name Hazard
## 危险区组件：玩家触碰后周期性扣血 + 击退
## 挂载在建筑/物品下（如篝火），用于触碰到扣血击退的功能
## 后续地刺等危险物可复用：挂 Area3D + Hazard + CollisionShape3D

var damage: float = 5.0            # 每次触碰/每间隔扣血量
var damage_interval: float = 1.0   # 扣血间隔（秒）
var knockback: float = 4.0         # 击退冲量（0 = 不击退）
var knockback_up: float = 0.0      # 击退竖直分量

var _player: Node3D = null
var _timer: float = 0.0


## 初始化危险区参数
func setup(p_damage: float, p_interval: float, p_knockback: float, p_knockback_up: float = 0.0) -> void:
	damage = p_damage
	damage_interval = maxf(p_interval, 0.1)
	knockback = p_knockback
	knockback_up = p_knockback_up
	collision_layer = 0          # 不参与碰撞，只做检测
	collision_mask = 1           # 检测碰撞层1（玩家/建筑所在层，用组过滤玩家）
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if _player != null:
		return
	if not body.is_in_group("player"):
		return
	_player = body
	_timer = damage_interval  # 触碰立即触发一次
	_hit()


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = null
		return
	_timer += delta
	if _timer >= damage_interval:
		_timer = 0.0
		_hit()


func _hit() -> void:
	if _player == null:
		return
	# 扣血（触发 player 的受击反馈/击退由 world_3d 处理；此处按玩家 health）
	if _player.has_method("get_health"):
		var h: Health = _player.get_health()
		if h:
			h.take_damage(damage, global_position)
	# 额外击退：水平方向从危险区中心向外 + 独立竖直冲量（knockback_up）
	if knockback > 0.0 and _player.has_method("apply_knockback"):
		var dir := _player.global_position - global_position
		dir.y = 0.0
		if dir.length_squared() < 0.01:
			dir = Vector3.FORWARD
		else:
			dir = dir.normalized()
		_player.apply_knockback(dir, knockback)
	if knockback_up > 0.0 and _player.has_method("apply_up_knockback"):
		_player.apply_up_knockback(knockback_up)

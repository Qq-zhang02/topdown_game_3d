extends Node
class_name MeleeController
## 近战攻击：左键挥击，扇形范围判定，命中 "damageable" 组内目标
## 伤害参数取自当前装备的 WeaponData，未持武器时用拳头

const WeaponDataClass := preload("res://scripts/items/weapon_data.gd")

@export var fist_damage: float = 5.0
@export var fist_range: float = 1.8
@export var fist_arc: float = 90.0
@export var fist_cooldown: float = 0.45
@export var fist_knockback: float = 2.0
@export var hit_delay: float = 0.18  # 挥击动作到伤害生效的延迟

var _player: CharacterBody3D
var _equipment_mgr: Node
var _cooldown_left: float = 0.0


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	_equipment_mgr = _player.get_node_or_null("EquipmentManager")


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("attack"):
		return
	if _cooldown_left > 0.0:
		return
	if _player.get("_dead"):
		return
	if _ui_blocking():
		return
	_do_attack()


## UI 打开（背包/建造/暂停）时不触发攻击
func _ui_blocking() -> bool:
	for bc in get_tree().get_nodes_in_group("build_controller"):
		if bc.is_placing() or bc.is_menu_open():
			return true
	for ui_node in get_tree().get_nodes_in_group("inventory_ui"):
		if ui_node.visible:
			return true
	return get_tree().paused


func _get_weapon() -> Resource:
	if _equipment_mgr == null:
		return null
	var eq = _equipment_mgr.get_current()
	if eq != null and eq is WeaponDataClass:
		return eq
	return null


func _do_attack() -> void:
	var weapon := _get_weapon()
	var dmg: float = weapon.damage if weapon else fist_damage
	var rng: float = weapon.attack_range if weapon else fist_range
	var arc: float = weapon.attack_arc if weapon else fist_arc
	var knock: float = weapon.knockback if weapon else fist_knockback
	_cooldown_left = weapon.cooldown if weapon else fist_cooldown

	if _player.has_method("play_attack"):
		_player.play_attack()

	await get_tree().create_timer(hit_delay).timeout
	if not is_instance_valid(_player) or _player.get("_dead"):
		return
	_apply_hits(dmg, rng, arc, knock)


func _apply_hits(dmg: float, rng: float, arc_deg: float, knock: float) -> void:
	var forward := -_player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	for node in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var to: Vector3 = node.global_position - _player.global_position
		to.y = 0.0
		var dist := to.length()
		if dist > rng + 0.4:  # 0.4 = 目标体半径的宽容度
			continue
		var angle := 0.0
		if dist > 0.01:
			angle = rad_to_deg(forward.angle_to(to / dist))
		if angle > arc_deg * 0.5:
			continue

		var health: Node = node.get_node_or_null("Health")
		if health and health.has_method("take_damage"):
			health.take_damage(dmg, _player.global_position)
		if node is RigidBody3D and dist > 0.01:
			node.apply_central_impulse(to / dist * knock + Vector3.UP * knock * 0.3)

extends Node
class_name MeleeController
## 近战攻击：左键挥击，矩形范围判定，命中 "damageable" 组内目标
## 伤害参数取自当前装备的 WeaponData，未持武器时用拳头

const WeaponDataClass := preload("res://scripts/items/weapon_data.gd")

@export var fist_damage: float = 5.0
@export var fist_range: float = 1          # 前方攻击距离（米）
@export var fist_arc: float = 0.3            # 左右半宽（米）
@export var fist_cooldown: float = 0.4
@export var fist_knockback: float = 2.0
@export var hit_delay: float = 0.18

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
	var dmg: float = fist_damage + (weapon.damage if weapon else 0)
	var rng: float = fist_range + (weapon.attack_range if weapon else 0)
	var half_w: float = fist_arc + (weapon.attack_arc if weapon else 0)
	var knock: float = fist_knockback + (weapon.knockback if weapon else 0)
	_cooldown_left = fist_cooldown + (weapon.cooldown if weapon else 0)

	if _player.has_method("play_attack"):
		_player.play_attack()

	if weapon and weapon.has_projectile_vfx:
		_spawn_thrust_vfx()

	await get_tree().create_timer(hit_delay).timeout
	if not is_instance_valid(_player) or _player.get("_dead"):
		return
	_apply_hits(dmg, rng, half_w, knock)


func _apply_hits(dmg: float, rng: float, half_w: float, knock: float) -> void:
	var tolerance: float = 0.4

	for node in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var local_pos: Vector3 = _player.to_local(node.global_position)
		local_pos.y = 0.0
		# 矩形判定：前方 -rng~0 内，左右 ±half_w 内
		if local_pos.z > -tolerance or local_pos.z < -rng - tolerance:
			continue
		if abs(local_pos.x) > half_w + tolerance:
			continue

		var health: Node = node.get_node_or_null("Health")
		if health and health.has_method("take_damage"):
			health.take_damage(dmg, _player.global_position)
		var to: Vector3 = node.global_position - _player.global_position
		to.y = 0.0
		var dist := to.length()
		if node is RigidBody3D and dist > 0.01:
			node.apply_central_impulse(to / dist * knock + Vector3.UP * knock * 0.3)


func _spawn_thrust_vfx() -> void:
	const ThrustVfx := preload("res://scripts/vfx/thrust_beam_vfx.gd")
	var beam := ThrustVfx.new()
	beam.scale = Vector3(2, 0.4, 1.7)
	_player.add_child(beam)
	beam.play()

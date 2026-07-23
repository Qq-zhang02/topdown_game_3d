extends Node
class_name Health
## 通用血量组件：玩家/动物/资源节点共用
## 挂在父节点下并命名为 "Health"，父节点加入 "damageable" 组即可被近战命中

signal damaged(amount: float, from_position: Vector3)
signal died

@export var max_hp: float = 100.0

var hp: float
var particle_color: Color = Color.WHITE  # 受击溅射粒子颜色
var particle_offset_scale: float = 1.0  # 粒子偏移系数（树=0.3，其他默认1.0）


func _ready() -> void:
	hp = max_hp


func take_damage(amount: float, from_position: Vector3 = Vector3.ZERO) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	damaged.emit(amount, from_position)
	_tint_parent_red()
	_spawn_hit_particles(from_position)
	if hp <= 0.0:
		hp = 0.0
		died.emit()


func heal(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = minf(hp + amount, max_hp)


func is_dead() -> bool:
	return hp <= 0.0


func set_particle_color(c: Color) -> void:
	particle_color = c


func set_particle_offset_scale(s: float) -> void:
	particle_offset_scale = s


func _tint_parent_red() -> void:
	var parent := get_parent() as Node3D
	if not parent:
		return
	for mesh: MeshInstance3D in parent.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mesh.mesh
		if not m:
			continue
		for i in m.get_surface_count():
			var mat := mesh.get_active_material(i)
			if not mat:
				continue
			mat = mat.duplicate()
			var std_mat := mat as StandardMaterial3D
			if not std_mat:
				continue
			var orig_color: Color = std_mat.albedo_color
			std_mat.albedo_color = Color.RED
			mesh.set_surface_override_material(i, mat)
			var tw := create_tween()
			tw.tween_property(std_mat, "albedo_color", orig_color, 0.3)


func _spawn_hit_particles(from_position: Vector3 = Vector3.ZERO) -> void:
	var parent := get_parent() as Node3D
	if not parent:
		return

	var ps := GPUParticles3D.new()

	# 从模型 MeshInstance3D 的 AABB 计算 XZ 半径
	var radius := 0.3
	for child in parent.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if not mi or not mi.mesh:
			continue
		var aabb := mi.get_aabb()
		if aabb.size.length_squared() < 0.001:
			continue
		var corners: PackedVector3Array = [
			aabb.position,
			aabb.position + Vector3(aabb.size.x, 0, 0),
			aabb.position + Vector3(0, 0, aabb.size.z),
			aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		]
		for c in corners:
			var p: Vector3 = mi.transform * c
			var d := Vector2(p.x, p.z).length()
			if d > radius:
				radius = d
	radius *= 0.6 * particle_offset_scale  #粒子偏移距离系数,不同物体的偏移系数不一样

	# 从受击方向的表面发出
	if from_position != Vector3.ZERO:
		var hit_dir := from_position - parent.global_position
		hit_dir.y = 0.0
		if hit_dir.length_squared() > 0.001:
			ps.position = hit_dir.normalized() * radius

	ps.one_shot = true
	ps.emitting = false
	ps.amount = 20
	ps.lifetime = 0.15
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))

	# 圆形粒子（小圆球），发光为主，透明度为辅
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere_mat.vertex_color_use_as_albedo = true  # 让粒子颜色生效
	sphere_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # 加色混合发光
	sphere_mat.albedo_color = Color.WHITE
	sphere_mat.emission_enabled = true
	sphere_mat.emission = Color.WHITE
	sphere_mat.emission_energy_multiplier = 12.0 #发光强度
	sphere.material = sphere_mat
	ps.draw_pass_1 = sphere

	var pm := ParticleProcessMaterial.new()
	pm.color = particle_color
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.gravity = Vector3(0, -6, 0)
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 6.0
	pm.scale_min = 0.2
	pm.scale_max = 0.4
	pm.lifetime_randomness = 0.2
	# 透明度随生命周期衰减
	var curve_tex := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5)) #粒子出生时透明度 0.5
	curve.add_point(Vector2(0.2, 0.5)) #前 20% 的生命周期保持 0.5 不变
	curve.add_point(Vector2(1.0, 0.0)) #从 20% 到死亡，线性渐隐到完全透明
	curve_tex.curve = curve
	pm.alpha_curve = curve_tex
	ps.process_material = pm

	parent.add_child(ps)
	ps.emitting = true

	var tw := create_tween()
	tw.tween_callback(ps.queue_free).set_delay(1.0)

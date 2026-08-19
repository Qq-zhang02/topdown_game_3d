extends Node3D
## 突刺光束 VFX：光束 + 侧向溅射粒子 + 尖端爆开
## 点击攻击 → 0.1s 光束出现 → 0.14s 粒子溅射 → 0.2s 全部结束

const THRUST_MODEL := preload("res://models/vfx/ThrustBeam.glb")
const BEAM_SHADER := preload("res://shaders/thrust_beam.gdshader")

var _beam: MeshInstance3D
var _mat: ShaderMaterial
var _side_splash: GPUParticles3D
var _impact_burst: GPUParticles3D
var _t: float = 0.0
var _playing: bool = false
var _beam_started: bool = false
var _particle_spawned: bool = false
var _start_z: float = 0.0  # 突刺起始 Z 位置


func _ready() -> void:
	var scene := THRUST_MODEL.instantiate()
	if not scene:
		queue_free()
		return

	if scene is MeshInstance3D:
		_beam = scene
	else:
		var children := scene.find_children("*", "MeshInstance3D", true, false)
		if children.is_empty():
			scene.queue_free()
			queue_free()
			return
		_beam = children[0] as MeshInstance3D
		scene.remove_child(_beam)
		scene.queue_free()

	_beam.name = "BeamMesh"
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 从实例化的 GLB 场景里剥离出的节点，先清空 owner，避免“owner 不一致”警告
	_beam.owner = null
	add_child(_beam)

	var base_mat := _beam.get_active_material(0)
	if base_mat:
		_mat = ShaderMaterial.new()
		_mat.shader = BEAM_SHADER
		_beam.set_surface_override_material(0, _mat)

	_setup_side_splash()
	_setup_impact_burst()

	# 尝试附着到角色左手/左臂骨骼 + 偏移微调，找不到则用硬编码
	var parent := get_parent()
	var found_hand := false
	if parent:
		var skel_nodes := parent.find_children("*", "Skeleton3D", true, false)
		if not skel_nodes.is_empty():
			var skel := skel_nodes[0] as Skeleton3D
			if skel:
				for bone_idx in range(skel.get_bone_count()):
					var bone_name: String = skel.get_bone_name(bone_idx).to_lower()
					if ("hand" in bone_name or "arm" in bone_name) and ("l" in bone_name or "left" in bone_name):
						var pose: Transform3D = skel.get_bone_global_pose(bone_idx)
						var bone_global: Vector3 = skel.global_transform * pose.origin
						position = parent.to_local(bone_global) + Vector3(-0.2, -0.3, -0.5) #相对左手骨骼偏移
						found_hand = true
						break
	if not found_hand:
		position = Vector3(0, 0.8, -0.7)

	visible = false


func _make_quad(size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = m
	return quad


func _gradient_tex(c1: Color, c2: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.add_point(0.0, c1)
	g.add_point(1.0, c2)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _setup_side_splash() -> void:
	_side_splash = GPUParticles3D.new()
	_side_splash.name = "SideSplash"
	_side_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_side_splash.one_shot = false
	_side_splash.emitting = false
	_side_splash.amount = 80
	_side_splash.lifetime = 0.06
	_side_splash.local_coords = true
	_side_splash.position = Vector3(0, 0, -0.5)
	_side_splash.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))

	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ppm.emission_box_extents = Vector3(0.15, 0.15, 0.5)
	ppm.direction = Vector3.FORWARD
	ppm.flatness = 1.0
	ppm.spread = 15.0
	ppm.initial_velocity_min = 1.0
	ppm.initial_velocity_max = 2.5
	ppm.gravity = Vector3(0, -2, 0)
	ppm.scale_min = 0.03
	ppm.scale_max = 0.12
	ppm.lifetime_randomness = 0.4
	ppm.color_ramp = _gradient_tex(Color(0.532, 0.471, 0.126, 0.8), Color(0.0, 0.3, 0.6, 0.0))
	_side_splash.process_material = ppm
	_side_splash.draw_pass_1 = _make_quad(0.12)
	add_child(_side_splash)


func _setup_impact_burst() -> void:
	_impact_burst = GPUParticles3D.new()
	_impact_burst.name = "ImpactBurst"
	_impact_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_impact_burst.one_shot = true
	_impact_burst.emitting = false
	_impact_burst.amount = 40
	_impact_burst.lifetime = 0.06
	_impact_burst.local_coords = true
	_impact_burst.position = Vector3(0, 0, -1.0)
	_impact_burst.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))

	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	ppm.emission_sphere_radius = 0.18
	ppm.direction = Vector3.ZERO
	ppm.spread = 180.0
	ppm.initial_velocity_min = 2.0
	ppm.initial_velocity_max = 5.0
	ppm.gravity = Vector3(0, -3, 0)
	ppm.scale_min = 0.05
	ppm.scale_max = 0.25
	ppm.lifetime_randomness = 0.5
	ppm.color_ramp = _gradient_tex(Color(0.945, 0.886, 0.554, 1.0), Color(0.2, 0.6, 1.0, 0.0))
	_impact_burst.process_material = ppm
	_impact_burst.draw_pass_1 = _make_quad(0.2)
	add_child(_impact_burst)


func play() -> void:
	_playing = true
	_t = 0.0
	_beam_started = false
	_particle_spawned = false
	_side_splash.emitting = false
	_impact_burst.emitting = false
	visible = false
	_start_z = position.z


func _process(delta: float) -> void:
	if not _playing:
		return

	_t += delta

	if not _beam_started and _t >= 0.1:
		_beam_started = true
		visible = true
		if _mat:
			_mat.set_shader_parameter("progress", 0.0)
			_mat.set_shader_parameter("intensity", 4.0)

	if not _particle_spawned and _t >= 0.14:
		_particle_spawned = true
		_side_splash.emitting = true
		_impact_burst.restart()
		_impact_burst.emitting = true

	if _beam_started and _mat:
		var beam_t := (_t - 0.1) / 0.1
		var p := clampf(beam_t, 0.0, 1.0)
		_mat.set_shader_parameter("progress", p)
		var fade := 1.0 - p
		_mat.set_shader_parameter("intensity", 4.0 * fade)

		# 向前突刺：光束在可见期间沿 local -Z 移动 0.4m
		position.z = _start_z + lerpf(0.0, -0.4, p)

	if _t >= 0.2:
		_playing = false
		_side_splash.emitting = false
		await get_tree().create_timer(0.3).timeout
		visible = false
		queue_free()

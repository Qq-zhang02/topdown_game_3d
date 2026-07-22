extends Control
class_name Minimap3D
## 左上角小地图（3D 世界 → 2D 缩略图）

var world_half: float = 50.0
var target: Node3D
var obstacle_positions: Array[Vector3] = []


func _ready() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var world_size: float = world_half * 2.0
	var scale_factor: float = size.x / world_size

	# ── 背景 ──
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05, 0.75))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.4, 0.4, 0.6), false, 1.5)

	if not target:
		return

	# ── 障碍物 ──
	for obs in obstacle_positions:
		var mp: Vector2 = _world3d_to_minimap(obs, world_half, scale_factor)
		if Rect2(Vector2.ZERO, size).has_point(mp):
			draw_circle(mp, 1.5, Color(0.5, 0.5, 0.5))

	# ── 玩家位置（亮黄点） ──
	var pp: Vector3 = target.global_position
	var player_mp: Vector2 = _world3d_to_minimap(pp, world_half, scale_factor)
	draw_circle(player_mp, 4.0, Color(1.0, 0.85, 0.1))
	draw_circle(player_mp, 4.0, Color.BLACK, false, 1.0)

	# ── 朝向指示（3D Y轴旋转 → 2D 三角形） ──
	var angle: float = target.rotation.y  # Godot 3D 中 Y 轴旋转是朝向
	var tip: Vector2 = player_mp + Vector2(-sin(angle), -cos(angle)) * 7
	var left: Vector2 = player_mp + Vector2(-sin(angle + 2.5), -cos(angle + 2.5)) * 4.5
	var right: Vector2 = player_mp + Vector2(-sin(angle - 2.5), -cos(angle - 2.5)) * 4.5
	draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(1.0, 0.3, 0.3))


func _world3d_to_minimap(world_pos: Vector3, half_world: float, scale: float) -> Vector2:
	# 3D XZ 平面 → 2D 小地图 XY
	return Vector2(
		(world_pos.x + half_world) * scale,
		(world_pos.z + half_world) * scale
	)

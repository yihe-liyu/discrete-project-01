## 命中框覆盖层 —— 工作台调试用
## 独立 CanvasLayer + 高 z_index（> 敌弹 10 / 特效 50），画在子弹贴图之上
## 轻量绘制：判定圆 12 段 / 矩形一次 draw_rect
extends Node2D
class_name HitboxOverlay

## 实体注册表（工作台注入）；空则不画敌人/自机
var entity_registry: EntityRegistry
## 弹幕世界（工作台注入）；不再读 BulletManager.current
var bullet_manager: BulletManager

## 是否显示命中框；setter 同时切换 visible / 每帧刷新，并在开启时立即重绘。
var is_enabled: bool = false:
	set(value):
		is_enabled = value
		visible = value
		set_process(value)  # 关键：开启时才运行 _process（每帧跟随子弹刷新）
		if is_enabled:
			queue_redraw()


func _ready() -> void:
	# 暂停时冻结（子弹也不动，内容一致即可）
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(is_enabled)


func _process(_delta: float) -> void:
	if is_enabled:
		queue_redraw()


## 命中框中心 = BulletManager 局部位置 → 画布全局 + 判定偏移（随朝向旋转）。
## 偏移与朝向的唯一语义在 [method BulletType.hit_center_for]；本方法只补 manager 的全局变换。
func bullet_center_for(manager: Node2D, bt: BulletType, local_pos: Vector2, velocity: Vector2) -> Vector2:
	var local := bt.hit_center_for(local_pos, velocity)
	return manager.to_global(local) if manager != null else local


func _draw() -> void:
	if not is_enabled:
		return
	# 子弹判定（红）—— 内核行
	var bm := bullet_manager
	var sys := bm.kernel_system() if bm else null
	if sys != null:
		var positions := sys.get_positions()
		var velocities := sys.get_velocities()
		var type_indices := sys.get_type_indices()
		var registry := sys.get_type_registry()
		for i in sys.get_active_count():
			var ti: int = type_indices[i]
			if ti < 0:
				continue
			var bt: BulletType = registry[ti]
			var rot: float = bt.rotation_for(velocities[i])
			# 内核坐标是 BulletManager 的局部坐标；贴图也吃它的 Node2D 变换。
			# 嵌入创作台后 manager.global_position 有页面偏移，只画 positions[i] 会整体错位。
			var center: Vector2 = bullet_center_for(bm, bt, positions[i], velocities[i])
			if bt.hitbox_size != Vector2.ZERO:
				draw_set_transform(center, rot, Vector2.ONE)
				draw_rect(Rect2(-bt.hitbox_size / 2.0, bt.hitbox_size), Color.RED, false, 1.0)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			else:
				draw_arc(center, bt.hitbox_radius, 0, TAU, 12, Color.RED, 1.0)
	# 敌人判定（绿）
	for enemy in (entity_registry.get_active_enemies() if entity_registry else []):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var er: float = enemy.get("hitbox_radius") if "hitbox_radius" in enemy else 8.0
		draw_arc(enemy.global_position, er, 0, TAU, 12, Color.GREEN, 1.5)
	# 玩家判定（青 = 命中，蓝 = 擦弹范围）
	var player = entity_registry.player if entity_registry else null
	if is_instance_valid(player):
		var pr: float = player.get("hitbox_radius") if "hitbox_radius" in player else 2.0
		var gr: float = player.get("graze_radius") if "graze_radius" in player else 24.0
		draw_arc(player.global_position, gr, 0, TAU, 24, Color(0.3, 0.6, 1.0, 0.5), 1.0)
		draw_arc(player.global_position, pr, 0, TAU, 12, Color.CYAN, 2.0)

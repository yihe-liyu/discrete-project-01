## 命中框覆盖层 —— 工作台调试用
## 独立 CanvasLayer + 高 z_index（> 敌弹 10 / 特效 50），画在子弹贴图之上
## 轻量绘制：判定圆 12 段 / 矩形一次 draw_rect
extends Node2D
class_name HitboxOverlay

## W4b-3b：实体注册表（工作台注入）；空则不画敌人/自机
var refs: EntityRegistry

var enabled: bool = false:
	set(v):
		enabled = v
		visible = v
		set_process(v)  # 关键：开启时才运行 _process（每帧跟随子弹刷新）
		if enabled:
			queue_redraw()


func _ready() -> void:
	# 暂停时冻结（子弹也不动，内容一致即可）
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(enabled)


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	# 子弹判定（红）—— 内核行
	var bm := BulletManager.current
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
			var center: Vector2 = positions[i] + bt.hitbox_offset.rotated(rot)
			if bt.hitbox_size != Vector2.ZERO:
				draw_set_transform(center, rot, Vector2.ONE)
				draw_rect(Rect2(-bt.hitbox_size / 2.0, bt.hitbox_size), Color.RED, false, 1.0)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			else:
				draw_arc(center, bt.hitbox_radius, 0, TAU, 12, Color.RED, 1.0)
	# 敌人判定（绿）
	for enemy in (refs.get_active_enemies() if refs else []):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var er: float = enemy.get("hitbox_radius") if "hitbox_radius" in enemy else 8.0
		draw_arc(enemy.global_position, er, 0, TAU, 12, Color.GREEN, 1.5)
	# 玩家判定（青 = 命中，蓝 = 擦弹范围）
	var player = refs.player if refs else null
	if is_instance_valid(player):
		var pr: float = player.get("hitbox_radius") if "hitbox_radius" in player else 2.0
		var gr: float = player.get("graze_radius") if "graze_radius" in player else 24.0
		draw_arc(player.global_position, gr, 0, TAU, 24, Color(0.3, 0.6, 1.0, 0.5), 1.0)
		draw_arc(player.global_position, pr, 0, TAU, 12, Color.CYAN, 2.0)

@tool
extends Node2D
## 判定框可视化编辑器。
## 在编辑器里把 .tscn 实例化，调整 @export 参数就能实时看到碰撞框。

enum Mode { CIRCLE, RECTANGLE }

@export var mode: Mode = Mode.RECTANGLE:
	set(v): mode = v; queue_redraw()
@export var hitbox_radius: float = 4.0:
	set(v): hitbox_radius = v; queue_redraw()
@export var hitbox_size: Vector2 = Vector2(48, 24):
	set(v): hitbox_size = v; queue_redraw()
@export var hitbox_offset: Vector2 = Vector2.ZERO:
	set(v): hitbox_offset = v; queue_redraw()
@export var show_texture: Texture2D:
	set(v): show_texture = v; queue_redraw()
@export var texture_scale: Vector2 = Vector2.ONE:
	set(v): texture_scale = v; queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	# 绘制纹理
	if show_texture:
		var tex_size := show_texture.get_size() * texture_scale
		draw_texture_rect(show_texture, Rect2(-tex_size / 2.0, tex_size), false, Color.WHITE)

	var center := hitbox_offset

	match mode:
		Mode.CIRCLE:
			draw_circle(center, hitbox_radius, Color(1, 0, 0, 0.25), true)
			draw_circle(center, hitbox_radius, Color(1, 0, 0, 1), false, 1.5)
			draw_circle(center, 2.0, Color(1, 1, 0, 1))
			var r := hitbox_radius
			if r > 8:
				draw_line(center, center + Vector2(0, -r), Color(1, 1, 0, 0.7), 1, true)
				draw_string(ThemeDB.fallback_font, center + Vector2(4, -r - 4), "r=%.1f" % r, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 0))

		Mode.RECTANGLE:
			var half := hitbox_size / 2.0
			var rect := Rect2(center - half, hitbox_size)
			draw_rect(rect, Color(0, 0.6, 1, 0.15), true)
			draw_rect(rect, Color(0, 0.6, 1, 1), false, 1.5)
			# 十字中线
			draw_line(center + Vector2(-half.x - 6, 0), center + Vector2(half.x + 6, 0), Color(0, 1, 1, 0.4), 1)
			draw_line(center + Vector2(0, -half.y - 6), center + Vector2(0, half.y + 6), Color(0, 1, 1, 0.4), 1)
			# 尺寸标注
			if hitbox_size.length() > 16:
				draw_string(ThemeDB.fallback_font, center + Vector2(half.x + 4, -half.y + 14), "%.0f×%.0f" % [hitbox_size.x, hitbox_size.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 1, 1))

	# 基准十字
	var ref := 80.0
	draw_line(Vector2(-ref, 0), Vector2(ref, 0), Color(0.5, 0.5, 0.5, 0.25), 0.5)
	draw_line(Vector2(0, -ref), Vector2(0, ref), Color(0.5, 0.5, 0.5, 0.25), 0.5)
	draw_circle(Vector2.ZERO, 2.0, Color(0.5, 0.5, 0.5, 0.5))

	# 偏移线
	if hitbox_offset != Vector2.ZERO:
		draw_line(Vector2.ZERO, center, Color(1, 1, 0, 0.4), 1, true)
		draw_string(ThemeDB.fallback_font, center / 2.0 + Vector2(0, -8), "offset (%.0f, %.0f)" % [hitbox_offset.x, hitbox_offset.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 0))

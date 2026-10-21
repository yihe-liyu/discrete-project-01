## 工作台的画框层：东方框金边 + 网格 / 幽灵路径参考线。
##
## 为什么单独一层：画框必须画在 3D 背景之上。这两样以前都在 [code]workbench.gd::_draw()[/code] 里，
## 而根 Control 的 [code]_draw[/code] 渲染在子节点之前 ⇒ 背景一铺就盖住金边（当年为此把背景内缩 3px
## 绕开，代价是预览与真游戏差 ≈4% 横向 FOV）。拆成叠在背景之上的独立节点后，背景可以照真游戏的
## over-scan 规格铺（[code]GameConfig.BACKGROUND_OVERSCAN[/code]），金边照样在最上层。
##
## 由 [code]workbench.gd::_redraw_stage()[/code] 在页面偏移变化 / 背景开关变化 / 载入关卡时 [code]sync()[/code]。
extends Control
class_name FrameOverlay

## 嵌入创作台时的页面偏移（舞台视觉归一回游戏坐标用）
var stage_shift_y := 0.0
## 只在无背景时画网格/路径线（有背景时线会浮在 3D 上，很难看）
var draw_grid := true


func sync(p_shift_y: float, p_draw_grid: bool) -> void:
	stage_shift_y = p_shift_y
	draw_grid = p_draw_grid
	queue_redraw()


func _draw() -> void:
	var field := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP - stage_shift_y,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT,
		GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
	# 东方框金边（提示边界）—— 必须在背景之上
	draw_rect(field, Color(0.62, 0.52, 0.28, 0.5), false, 2.0)
	if not draw_grid:
		return
	for grid_x in range(64, 833, 64):
		draw_line(Vector2(grid_x, 32 - stage_shift_y), Vector2(grid_x, 928 - stage_shift_y), Color(1, 1, 1, 0.05))
	for grid_y in range(32, 929, 64):
		draw_line(Vector2(64, grid_y - stage_shift_y), Vector2(832, grid_y - stage_shift_y), Color(1, 1, 1, 0.05))
	# 幽灵玩家路径参考（纵向漂移中线）
	draw_line(Vector2(64, GameConfig.PLAYER_START.y - stage_shift_y), Vector2(832, GameConfig.PLAYER_START.y - stage_shift_y), Color(0.3, 0.9, 0.5, 0.15))

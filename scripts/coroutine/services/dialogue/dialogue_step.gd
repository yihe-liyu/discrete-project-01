## 对话步骤 —— 一步演出操作（数据载体）
## 由 DialogueSteps DSL 生成、DialogueRunner 解释
class_name DialogueStep
extends RefCounted

enum Type {
	LINE,      ## 显示一句（从台词库按 line_id 取）
	ENTER,     ## 登场（profile + 位置 + opts{flip, dim, emotion}）
	EXIT,      ## 退场
	MOVE,      ## 移动立绘（可选 duration）
	FLIP,      ## 水平翻转
	DIM,       ## 手动明暗
	PORTRAIT,  ## 换表情
	BUBBLE,    ## 调气泡偏移
	EVENT,     ## 行间事件（时机精确）
	WAIT,      ## 停顿（秒）
}

## 步骤类型（Type）。
var type: Type
## 目标角色名。
var char_name: String = ""
## ENTER 用的角色档案。
var profile: CharacterProfile     # ENTER 用
## LINE 用的内联台词数据。
var line_data: DialogueLine       # LINE 用（DSL 内联台词构造的一屏数据）
## ENTER / MOVE 的目标位置。
var pos: Vector2 = Vector2.ZERO   # ENTER/MOVE 用
## MOVE / WAIT 的时长（秒）。
var duration: float = 0.0         # MOVE/WAIT 用
## ENTER 默认翻转 / FLIP 目标状态。
var is_flip: bool = false         # ENTER(默认 false)/FLIP 用
## ENTER 的 dim 选项 / DIM 目标明暗。
var light: float = 1.0            # ENTER 的 dim 选项 / DIM 用
## ENTER / PORTRAIT 的表情名。
var emotion: String = "通常"      # ENTER/PORTRAIT 用
## BUBBLE 的气泡偏移。
var bubble_offset: Vector2 = Vector2(-220.0, 250.0)  # BUBBLE 用
## EVENT 的事件 key。
var event_key: String = ""        # EVENT 用
## LINE 选项：{skippable, auto_advance}。
var opts: Dictionary = {}         # LINE 用：{skippable, auto_advance}

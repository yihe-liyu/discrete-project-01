class_name DialogueStep
extends RefCounted
## 对话步骤 —— 一步演出操作（数据载体）
## 由 DialogueSteps DSL 生成、DialogueRunner 解释

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

var type: Type
var char_name: String = ""
var profile: CharacterProfile     # ENTER 用
var line_data: DialogueLine       # LINE 用（DSL 内联台词构造的一屏数据）
var pos: Vector2 = Vector2.ZERO   # ENTER/MOVE 用
var duration: float = 0.0         # MOVE/WAIT 用
var is_flip: bool = false         # ENTER(默认 false)/FLIP 用
var light: float = 1.0            # ENTER 的 dim 选项 / DIM 用
var emotion: String = "通常"      # ENTER/PORTRAIT 用
var bubble_offset: Vector2 = Vector2(-220.0, 250.0)  # BUBBLE 用
var event_key: String = ""        # EVENT 用
var opts: Dictionary = {}         # LINE 用：{skippable, auto_advance}

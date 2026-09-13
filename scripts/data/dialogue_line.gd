# DialogueLine.gd
extends Resource
class_name DialogueLine

## 台词库中的一句（内容层）
## 本帧气泡（可多个 → 多人齐声 / 空文本 = 在场不说话）
## 说话者自动从 bubbles[].speaker 收集, text 为空者渲染但暗
## 行内事件用 DSL 步骤 d.event() 表达，时机精确到行间
@export var bubbles: Array[DialogueBubble] = []
## 是否可跳过（按 X 跳至下一句，false 则必须按 Z）
@export var skippable: bool = true
## 自动播放时间（秒），0 为手动控制（DSL 的 line opts 可覆盖）
@export var auto_advance: float = 0.0

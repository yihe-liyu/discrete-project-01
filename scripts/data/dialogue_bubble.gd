# DialogueBubble.gd
## 台词库中的一个气泡（内容层：只存"谁说什么、什么表情"）
## 演出（位置/翻转/明暗/气泡偏移）由 DSL 步骤 + ActorState 管理，不在此存储
extends Resource
class_name DialogueBubble

## 说话者
@export var speaker: CharacterProfile
## 内容
@export_multiline var text: String = ""
## 表情 key
@export var emotion: String = "通常"

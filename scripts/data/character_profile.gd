# CharacterProfile.gd
extends Resource
class_name CharacterProfile

## 角色名
@export var char_name: String = ""
## 表情集 { "通常": Texture2D, "笑": Texture2D, ... }
@export var portraits: Dictionary = {}
## 对话首次登场默认立绘锚点（ActorState 用；旧 profile 无此字段时取默认）
@export var default_pos: Vector2 = Vector2(50, 230)
## 对话首次登场默认水平翻转
@export var default_flip: bool = false
## 对话气泡相对立绘右缘的默认偏移（ActorState 用；避免每段手调 d.bubble）
@export var default_bubble_offset: Vector2 = Vector2(12, 0)

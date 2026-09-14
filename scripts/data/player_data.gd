extends Resource
## 自机数据：移动速度、动画、射击脚本
class_name PlayerData

@export_group("Speed")
## 按住 Focus（低速）时的移动速度（像素/秒）
@export var focus_speed: int
## 常规移动速度（像素/秒）
@export var normal_speed: int

@export_group("", "")
## 角色动画帧（AnimatedSprite2D 用 SpriteFrames）
@export var animation: SpriteFrames

## 射击脚本（PlayerShootScript）
@export var shoot_script: Script

@export_group("Bomb")
## 自机 bomb 数据（BombData 家族；环状 RingBombData / 云状 MistBombData）
@export var bomb: BombData

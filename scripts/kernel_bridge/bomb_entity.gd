## BombEntity —— 自机 bomb 的宿主实体基类（不走内核池）。
## 统一注入槽与 setup 签名；子类只管自己的运动/判定/视觉。
class_name BombEntity
extends Node2D

## 内容数据（KernelBulletHost 注入）
var data: BombData
## 实体注册表（自机 / 敌机 / Boss；KernelBulletHost 注入）
var entity_registry: EntityRegistry
## 弹幕世界（KernelBulletHost 注入）——清弹 / 视觉用
var bullet_manager: BulletManager
## 爆炸贴图父节点（KernelBulletHost 注入 World；空则挂自身父级）
var fx_parent: Node2D


## 子类覆写：读 data、建视觉、初始化状态。tint / spawn_delay 是逐颗参数。
func setup(_data: BombData, _pos: Vector2, _direction: Vector2, _tint: Color = Color.WHITE, _spawn_delay: float = 0.0) -> void:
	push_error("BombEntity.setup 未覆写")

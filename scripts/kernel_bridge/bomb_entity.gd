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
## 持续震屏强度（>0 时本 bomb 存活期间一直持有；exit 时归零）。
var _shake_sustain: float = 0.0


## 子类覆写：读 data、建视觉、初始化状态。tint / spawn_delay 是逐颗参数。
func setup(_data: BombData, _pos: Vector2, _direction: Vector2, _tint: Color = Color.WHITE, _spawn_delay: float = 0.0) -> void:
	push_error("BombEntity.setup 未覆写")


## 子类 setup() 读完 data 后调用：整个 bomb 存活期间持续震屏（data.shake_sustain）。
func _hold_shake_sustain() -> void:
	_shake_sustain = data.shake_sustain if data != null else 0.0
	if _shake_sustain > 0.0:
		GameEvents.screen_shake_sustain.emit(_shake_sustain)


func _exit_tree() -> void:
	if _shake_sustain > 0.0:
		GameEvents.screen_shake_sustain.emit(0.0)

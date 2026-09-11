## 行为基类：每类/每配置一份实例，注册一次；每弹状态不在对象里，在子弹行（swap 安全）。
## 数据两槽：get_behavior_params() 共享只读 | get/set_behavior_state() 每弹私有可写。
## 注册/发射都用名字（StringName），无手动数字 id。
extends RefCounted
class_name Behavior


## 行为入口（子类覆写）。dt 型行为用 system.get_delta()，改走 set_velocity，由系统下帧积分。
func process(_sys: BulletSystem, _bullet_id: int, _ctx: BehaviorContext) -> void:
	pass

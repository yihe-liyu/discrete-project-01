## 战场实体注册表 —— 自机 / 在场敌机（含 Boss）的显式引用。
## 替代旧的全局运行时引用：由关卡组合根（`StageRuntime`）持有，随关卡场景存亡（R9）。
## 过渡期宿主门面（自机 / active_enemies 属性）转发到本对象，
## 迁移完成后删除转发；内核/实体改经注入读取。
class_name EntityRegistry
extends RefCounted

const BossScript = preload("res://scripts/enemy/boss.gd")

## 当前自机（Player / GhostPlayer）；未注入 = null。
## 用内建 Node2D 类型：对象释放时 Godot 自动置 null（无类型 Variant 会残留"已释放实例"）。
var player: Node2D

## 在场敌机 / Boss（顺序 = 注册顺序）
var enemies: Array = []


func bind_player(p: Node2D) -> void:
	player = p


func register_enemy(e) -> void:
	if e != null and not enemies.has(e):
		enemies.append(e)


func unregister_enemy(e) -> void:
	enemies.erase(e)


func get_active_enemies() -> Array:
	return enemies


## 当前场上的 Boss（无 → null）。按脚本类型识别，与旧全局查询判据一致。
func get_boss():
	for e in enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.get_script() == BossScript:
			return e
	return null


## 清场：释放所有敌机（自机不动——自机跨关卡存活）。
func clear() -> void:
	for e in enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			e.queue_free()
	enemies.clear()

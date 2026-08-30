class_name PhaseShell
extends RefCounted
## 阶段试验台 —— 阶段"壳"（构建副本，不改动原 .tres 资源）
## 魂：move_script × shoot_script 双槽（默认取所选阶段 .tres 的值，可换/可清空）

const KAMORUI_BOSS := preload("res://data/enemy_visual/boss/stage01/kamorui.tscn")

## 从已有 PhaseData 生成实战副本（覆盖槽位与 HP/时限）
func build_copy(base: PhaseData, move_script: Script, shoot_script: Script,
		hp_override: float, time_override: float) -> PhaseData:
	var d := PhaseData.new()
	d.name = base.name
	d.uid = base.uid
	d.bonus = base.bonus
	d.time_limit = time_override
	d.hp = int(hp_override)
	d.is_timeout_only = base.is_timeout_only
	d.move_script = move_script
	d.shoot_script = shoot_script
	d.background = base.background
	d.item_power = base.item_power
	d.item_point = base.item_point
	d.item_life = base.item_life
	d.item_bomb = base.item_bomb
	d.item_life_full = base.item_life_full
	d.item_bomb_full = base.item_bomb_full
	d.params = base.params.duplicate()
	d.open_reduce_time = base.open_reduce_time
	d.open_reduce_ratio = base.open_reduce_ratio
	return d


## Boss 视觉（当前库只有卡摩瑞；后续从 data/enemy_visual/boss 扫描扩展）
func boss_scene() -> PackedScene:
	return KAMORUI_BOSS

class_name PhaseShell
extends RefCounted
## 阶段试验台 —— 阶段"数值/脚本"载体（构建副本，不改动原 .tres 资源）
## 双槽：move_script × shoot_script（默认取所选阶段 .tres 的值，可换/可清空）

const KAMORUI_BOSS := preload("res://data/enemy_visual/boss/stage01/kamorui.tscn")

## 从已有 PhaseData 生成实战副本（覆盖槽位与 HP/时限）
func build_copy(base: PhaseData, move_script: Script, shoot_script: Script,
		hp_override: float, time_override: float) -> PhaseData:
	var phase := PhaseData.new()
	phase.name = base.name
	phase.uid = base.uid
	phase.time_limit = time_override
	phase.hp = int(hp_override)
	phase.is_timeout_only = base.is_timeout_only
	phase.move_script = move_script
	phase.shoot_script = shoot_script
	phase.item_power = base.item_power
	phase.item_point = base.item_point
	phase.item_life = base.item_life
	phase.item_bomb = base.item_bomb
	phase.item_life_full = base.item_life_full
	phase.item_bomb_full = base.item_bomb_full
	phase.params = base.params.duplicate()
	phase.open_reduce_time = base.open_reduce_time
	phase.open_reduce_ratio = base.open_reduce_ratio
	return phase


## Boss 视觉（当前库只有卡摩瑞；后续从 data/enemy_visual/boss 扫描扩展）
func boss_scene() -> PackedScene:
	return KAMORUI_BOSS

class_name EnemyShell
extends RefCounted
## 敌人试验台 —— 敌人"外形/数值"载体（临时试验道具，不落盘）。
## 对应 EnemyData 的"外观/数值侧：外观/HP/判定/掉落；行为脚本由组合台选择，二者独立组合。

var visual_key: String = "red_little_fairy"
var max_hp: int = 100
var hitbox_radius: float = 25.0
var item_power: int = 2
var item_point: int = 0
var item_life: int = 0
var item_bomb: int = 0
var item_life_full: int = 0
var item_bomb_full: int = 0


## 组装 EnemyData（外形/数值 → 行为脚本；与游戏内容同款字段）
func build(behavior_script: Script = null) -> EnemyData:
	var enemy_data := EnemyData.new()
	enemy_data.visual(visual_key)
	enemy_data.hp(max_hp)
	enemy_data.hbox(hitbox_radius)
	enemy_data.power(item_power)
	enemy_data.point(item_point)
	enemy_data.life(item_life)
	enemy_data.bomb(item_bomb)
	enemy_data.life_full(item_life_full)
	enemy_data.bomb_full(item_bomb_full)
	if behavior_script:
		enemy_data.with_script(behavior_script)
	return enemy_data


## 外观清单（来自 AssetRegistry，顺序稳定）
static func visual_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in AssetRegistry.enemy_visuals:
		keys.append(key)
	return keys
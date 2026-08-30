class_name EnemyShell
extends RefCounted
## 敌人试验台 —— 敌人"壳"（临时试验道具，不落盘）。
## 对应 EnemyData 的"外表侧"：外观/HP/判定/掉落；魂=行为脚本，二者独立组合。

var visual_key: String = "red_little_fairy"
var max_hp: int = 100
var hitbox_radius: float = 25.0
var item_power: int = 2
var item_point: int = 0
var item_life: int = 0
var item_bomb: int = 0
var item_life_full: int = 0
var item_bomb_full: int = 0


## 组装 EnemyData（光壳 → 行为脚本；与游戏内容同款字段）
func build(behavior_script: Script = null) -> EnemyData:
	var d := EnemyData.new()
	d.visual(visual_key)
	d.hp(max_hp)
	d.hbox(hitbox_radius)
	d.power(item_power)
	d.point(item_point)
	d.life(item_life)
	d.bomb(item_bomb)
	d.life_full(item_life_full)
	d.bomb_full(item_bomb_full)
	if behavior_script:
		d.with_script(behavior_script)
	return d


## 外观清单（来自 AssetRegistry，顺序稳定）
static func visual_keys() -> Array[String]:
	var keys: Array[String] = []
	for k in AssetRegistry.enemy_visuals:
		keys.append(k)
	return keys
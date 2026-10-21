## Boss 名册（数据 .tres）：所有 BossData 的扁平清单。
## BossCatalog 按 stage_id 分组、order 排序 —— 加符卡只改 .tres，不写 GDScript。
class_name BossRegistry
extends Resource

## 全部 BossData 的扁平清单；[code]BossCatalog[/code] 按 stage_id 分组、order 排序，不在这里手写顺序。
@export var bosses: Array[BossData] = []

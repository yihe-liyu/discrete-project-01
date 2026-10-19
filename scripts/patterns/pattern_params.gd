class_name PatternParams
extends Resource
## 弹幕 pattern 的手感参数（**默认值**，不是规则）。
##
## 用法：
##   - `.tres` 预设：inspector 里调，热重载后即时生效
##   - 代码内联：`var p := PATTERN_PARAMS.new(); p.count = 12 + diff_pick(...)`
##
## 只放“经常调、调起来烦”的数值；流程/条件/循环仍在 GDScript。

## 发射的弹型定义（`data/bullets/*.tres`，外观+碰撞+朝向）。
@export var bullet_def: BulletDef
## 染色 / 阵营 / 混合（pattern 在构造 BulletData 时套用）。
@export var color: Color = Color.WHITE
@export var enemy: bool = true
@export var blend: bool = true
@export var count: int = 12
@export var speed: float = 160.0
## 总张角：TAU = 整圈；PI/2 = 90° 扇形。
@export var spread: float = TAU
## 连续型 pattern 用（瞬时 pattern 忽略）。
@export var interval: float = 0.08
@export var duration: float = 3.0
## true = 以自机为基准方向；false = 用调用方传入的 direction。
@export var aim: bool = false
## 不封死 schema：具体 pattern 的特殊参数放这里。
@export var extra: Dictionary = {}

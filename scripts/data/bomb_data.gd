## 自机 bomb 数据**基类**：所有 bomb 共有的外观 / 编队 / 无敌。
## 具体炸弹类型继承它，补自己的运动与判定字段（RingBombData / MistBombData）。
## 与弹幕数据（BulletData）分开：bomb 是**宿主实体**（个位数、宿主动作），不是弹幕。
extends Resource
class_name BombData

@export_group("外观")
@export var texture: Texture2D                              ## 炸弹贴图（单帧）
@export var z_index: int = LayerConfig.BOMB                 ## 渲染层

@export_group("编队（一次 bomb 的生成方式）")
@export var count: int = 8                                  ## 生成几颗（Player 逐颗 spawn）
@export var interval: float = 0.1                           ## 每颗间隔（秒）
@export var invincible_time: float = 4.0                    ## 自机无敌时长

## 自机 bomb 数据：外观 / 编队 / 运动 / 爆炸。做成资源（.tres）由内容调。
## 与弹幕数据（BulletData）分开：bomb 是**宿主实体**（个位数、宿主动作），不是弹幕。
extends Resource
class_name BombData

@export_group("外观")
@export var texture: Texture2D                              ## 炸弹贴图（单帧）
@export var z_index: int = LayerConfig.BOMB                 ## 渲染层
@export var hitbox_radius: float = 45.0                     ## 判定半径（追敌引爆距离）

@export_group("编队（一次 bomb 的生成方式）")
@export var count: int = 8                                  ## 生成几颗
@export var interval: float = 0.1                           ## 每颗间隔（秒）
@export var speed: float = 220.0                            ## 飞向敌机速度
@export var invincible_time: float = 4.0                    ## 自机无敌时长

@export_group("运动（绕自机外扩 → 保持 → 追敌）")
@export var orbit_speed_deg: float = 300.0                  ## 环绕角速度（度/秒）
@export var radius_growth: float = 200.0                    ## 外扩速度（px/s）
@export var max_radius: float = 200.0                       ## 外扩上限
@export var hold_time: float = 1.8                          ## 外圈保持时长
@export var homing_speed: float = 1500.0                    ## 追踪速度

@export_group("爆炸")
@export var explode_damage: float = 150.0
@export var explode_radius: float = 140.0
@export var explode_duration: float = 0.4
@export var explode_start_radius: float = 20.0
@export var clear_radius: float = 90.0                      ## 持续清弹半径（每帧）

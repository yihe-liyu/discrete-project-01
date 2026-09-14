## Mist bomb 数据：单贴图分阶段展开（长 → 保持 → 宽 → 保持 → 淡出），锚点跟随自机。
## 宿主实体 = KernelMistBomb。数值全在 .tres 里可调，别写回引擎代码。
extends BombData
class_name MistBombData

@export_group("锚点 / 朝向")
@export var follow_player: bool = true                      ## 锚点跟随自机
@export var anchor_offset: Vector2 = Vector2.ZERO           ## 相对自机的偏移
@export var rotation_deg: float = -90.0                     ## 贴图朝向（-90 = 长轴朝上）
@export var pivot_ratio: Vector2 = Vector2(0.0, 0.5)        ## 锚点（贴图 0..1；接在自机上的"弯曲处"）

@export_group("展开范围（每轴 起始→最终；1.0 = 贴图该维全长）")
@export var length_range: Vector2 = Vector2(0.0, 1.0)       ## x=长的起始比例，y=长的最终比例
@export var width_range: Vector2 = Vector2(0.0, 1.0)        ## x=宽的起始比例（= 初始宽度），y=宽的最终比例

@export_group("分阶段展开（秒）")
@export var grow_length_time: float = 0.35                  ## 阶段1：长 起始→最终
@export var hold_length_time: float = 0.5                   ## 阶段2：保持长
@export var grow_width_time: float = 0.25                   ## 阶段3：宽 起始→最终
@export var hold_width_time: float = 0.5                    ## 阶段4：保持宽
@export var fade_time: float = 0.25                         ## 阶段5：淡出

@export_group("判定")
@export var dps: float = 200.0                              ## 覆盖范围内每秒伤害（每帧 dps*delta）
@export var clear_scale: float = 1.0                        ## 清弹椭圆 = 判定椭圆 × 它（1.0 = 与贴图一致，>1 多清一圈）

# DecorLayer.gd — 一层装饰物配置
## 一层装饰物的生成配置：贴图 / 尺寸范围 / 密度 / 生成带 / LOD。
class_name DecorLayer
extends Resource

## 层名（调试用，可选）
@export var name: String = ""

## 贴图
@export var texture: Texture2D

## 世界空间尺寸范围（生成时随机取值）
@export var size_min: Vector2 = Vector2(4, 4)
## 世界空间尺寸上限（每个实例在 [code]size_min[/code] 到 [code]size_max[/code] 之间逐分量随机）
@export var size_max: Vector2 = Vector2(16, 16)

## 每米密度（在 spawn_band 区间内的平均实例数/米）
@export var density: float = 0.5

## 垂直偏移
@export var y_offset: float = 0.0
## 垂直随机（batch_spawn 贴地自动计算，此值用于手动 spawn）
@export var y_variance: float = 0.0

## 在相机前方多远区间生成新实例 (z_near, z_far)
@export var spawn_band: Vector2 = Vector2(-200, 0)

## LOD 裁剪距离——超过此距离跳过渲染更新（纯性能）
@export var lod_distance: float = 150.0

## Alpha 模式：SCISSOR = 不透明快路径（整层平移、无逐实例排序）；
## BLEND = 半透明（逐实例位移 + 画家排序，代价更高）。
enum AlphaMode { SCISSOR, BLEND }
## Alpha 裁剪模式
@export var alpha_mode: AlphaMode = AlphaMode.SCISSOR
## SCISSOR 模式的 alpha 裁剪阈值：像素 alpha 低于它的区域直接丢弃（0..1，仅 SCISSOR 生效）。
@export var alpha_threshold: float = 0.5

## 是否 Billboard
@export var is_billboard: bool = true

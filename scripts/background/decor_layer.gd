# DecorLayer.gd — 一层装饰物配置
class_name DecorLayer
extends Resource

## 层名（调试用，可选）
@export var name: String = ""

## 贴图
@export var texture: Texture2D

## 世界空间尺寸范围（生成时随机取值）
@export var size_min: Vector2 = Vector2(4, 4)
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

## Alpha 模式
enum AlphaMode { SCISSOR, BLEND }
@export var alpha_mode: AlphaMode = AlphaMode.SCISSOR
@export var alpha_threshold: float = 0.5

## 是否 Billboard
@export var is_billboard: bool = true

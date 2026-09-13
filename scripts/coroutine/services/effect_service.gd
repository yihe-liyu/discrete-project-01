class_name EffectService
extends RefCounted
## 特效服务 —— ctx.effects 下的特效 API（Miss 圈 / 命中特效）

## Miss 圈渲染节点（组合根 GameScene 注入；为空则静默跳过，便于测试/无场景上下文）
var miss_layer: MissCircleLayer

## 特效层（组合根 GameScene 注入；为空则静默跳过）
var fx_pool: FxPool

## 全屏圆形 Miss 特效圈（由注入的 MissCircleLayer 场景节点渲染）
func add_miss_circle(world_pos: Vector2, duration: float, max_radius: float,
		start_radius: float = 0.0, start_delay: float = 0.0, fade_out: float = 0.0) -> void:
	if miss_layer and is_instance_valid(miss_layer):
		miss_layer.add_circle(world_pos, duration, max_radius, start_radius, start_delay, fade_out)

## 命中特效（对象池，FxPool 注入）
func play_hit_effect(scene: PackedScene, pos: Vector2) -> void:
	if fx_pool and is_instance_valid(fx_pool):
		fx_pool.play(scene, pos)

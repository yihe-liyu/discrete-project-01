class_name FxPool
extends Node2D
## 精灵特效池（局部、世界坐标）：命中 / 消弹 / 擦弹等 `HitEffect` 复用实例，避免频繁 instantiate()/queue_free()。
## 与 MissCircleLayer 分工：本层是「节点池 + 精灵动画」（世界坐标）；全屏反色圈在 MissCircleLayer（屏幕空间 shader）。
## 取代 HitEffectPool autoload —— 由组合根 GameScene 创建并注入，不再是全局，也不再全树找 "World"（R2/R9）。
## 按 PackedScene 分池复用；播完自动回池。挂在哪，特效就 add_child 到哪（位置一律用 global_position，与父变换无关）。

var _pools: Dictionary = {}   # PackedScene → Array[HitEffect]
var _return_method: Callable


func _init() -> void:
	_return_method = _recycle   # 构造即就绪：play 无需等待入树


## 从池中取一个特效实例播放；scene 为空返回 null。
func play(scene: PackedScene, pos: Vector2, vel: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> HitEffect:
	var effect := _acquire(scene)
	if not effect:
		return null
	effect.z_index = LayerConfig.EFFECT
	effect.activate(pos, vel, tint, _return_method)
	return effect


## 从池中取一个实例：优先复用不可见的，没有则新建（挂到本层下）。
func _acquire(scene: PackedScene) -> HitEffect:
	if scene == null:
		return null
	var arr: Array = _pools.get(scene, [])

	for i in arr.size():
		var eff: HitEffect = arr[i] as HitEffect
		if not is_instance_valid(eff):
			arr[i] = null
			continue
		if not eff.visible:
			return eff

	var instance: Node = scene.instantiate()
	if instance == null or not (instance is HitEffect):
		push_warning("FxPool: 场景根节点必须是 HitEffect（Node2D + hit_effect.gd）：%s" % scene.resource_path)
		return null
	instance.visible = false
	add_child(instance)
	var idx := arr.find(null)
	if idx >= 0:
		arr[idx] = instance
	else:
		arr.append(instance)
	_pools[scene] = arr
	return instance


## 清空池（换关/重开）。
func clear_pool() -> void:
	for key in _pools:
		for eff in _pools[key]:
			if is_instance_valid(eff):
				eff.queue_free()
	_pools.clear()


func _recycle(effect: HitEffect) -> void:
	effect.visible = false

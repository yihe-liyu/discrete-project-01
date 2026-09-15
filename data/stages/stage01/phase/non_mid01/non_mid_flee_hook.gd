extends RefCounted
## non_mid01「近 Boss 散圈」钩子（b2b）：内容侧注册进 LifecycleHooks，原生事件按名字回调。

## 近 Boss 散圈半径（按难度）—— 端口与回调共用同一份
const BOSS_RADIUS := [175.0, 150.0, 125.0, 100.0]
const RING_SPEED := 400.0

## 复用弹型实例（M2）
var _normal_bullet_data: BulletData
var _red_bullet_data: BulletData


## 内核事件签名：(pos, boss_pos, has_boss, host) -> bool（true = 已散圈）
func burst(pos: Vector2, boss_pos: Vector2, has_boss: bool, host) -> bool:
	if not has_boss:
		return false
	if pos.distance_to(boss_pos) >= float(BOSS_RADIUS[SaveData.selected_difficulty]):
		return false
	if _normal_bullet_data == null:
		_normal_bullet_data = BulletData.new().tex("小玉").speed(RING_SPEED)\
			.color(Color(0.349, 0.584, 0.798, 1.0)).blend(true).enemy()
	var rand_dir := Vector2.DOWN.rotated(RNG.randf() * TAU)
	_spread(_normal_bullet_data, int(_pick([2, 4, 6, 8])), TAU, rand_dir, pos, host)
	if SaveData.selected_difficulty >= 2:
		var away := (pos - boss_pos).normalized()
		var num: int = int(_pick([0, 0, 1, 2]))
		var count: int = int(_pick([0, 0, 4, 8]))
		if _red_bullet_data == null:
			_red_bullet_data = BulletData.new().tex("棱弹").color(Color.RED).blend(true).enemy()
		for i in count:
			_red_bullet_data.speed(RING_SPEED + i * 50)  # 速度不属弹型：每发写一次
			_spread(_red_bullet_data, num, 1 / TAU / 3, away, pos, host)
	AudioManager.play_sfx(AssetRegistry.sounds["kira"], -8.0)
	return true


## 按难度取值（原 diff_pick 的本地版）
func _pick(arr: Array) -> Variant:
	return arr[SaveData.selected_difficulty]


## 内核版 shoot_spread：只入队（行为循环中途禁止直接 spawn）
func _spread(data: BulletData, count: int, spread: float, base_dir: Vector2, at: Vector2, host) -> void:
	if count <= 0:
		return
	if count == 1:
		host.queue_spawn(data, at, base_dir)
		return
	var step := spread / (count - 1) if spread < TAU - 0.001 else spread / count
	for i in count:
		host.queue_spawn(data, at, base_dir.rotated(-spread / 2.0 + step * i))

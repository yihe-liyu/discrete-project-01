extends CoroutineScript
## 弹丸行为：飞行 → 靠近自机时转向逃跑 → 靠近 Boss 时消失并散开一圈
##
## **内核端口载体**：状态机（TRAVEL → 近自机 FLEE）+ 距离检测在桥接
## `test/reference/behavior/non_mid_flee_behavior.gd`；散圈（难度 / RNG / 形状）
## 留在内容侧，由 `on_flee_burst` 回调提供。

const PLAYER_PROXIMITY: float = 150.0
const RING_SPEED: float = 400.0

## 复用弹型实例（M2）
var _normal_bullet_data: BulletData
var _red_bullet_data: BulletData


## 内核端口：TRAVEL→FLEE + 近 Boss 散圈。散圈逻辑留在内容侧。
func kernel_port() -> Dictionary:
	return {
		"move": &"non_mid_flee",
		"params": {
			&"player_proximity": PLAYER_PROXIMITY,
			&"on_flee_burst": Callable(self, "_kernel_on_flee_burst"),
		},
	}


## FLEE 阶段靠近 Boss → 散圈（true = 已散圈）。散圈只入队，由 host 循环后发射。
func _kernel_on_flee_burst(pos: Vector2, boss_pos: Vector2, has_boss: bool, host) -> bool:
	if not has_boss:
		return false
	if pos.distance_to(boss_pos) >= diff_pick([175, 150, 125, 100]):
		return false
	if _normal_bullet_data == null:
		_normal_bullet_data = BulletData.new().tex("小玉").speed(RING_SPEED)\
			.color(Color(0.349, 0.584, 0.798, 1.0)).blend(true).enemy()
	var rand_dir := Vector2.DOWN.rotated(RNG.randf() * TAU)
	_kernel_spread(_normal_bullet_data, diff_pick([2, 4, 6, 8]), TAU, rand_dir, pos, host)
	if SaveData.selected_difficulty >= 2:
		var away := (pos - boss_pos).normalized()
		var num: int = diff_pick([0, 0, 1, 2])
		var count: int = diff_pick([0, 0, 4, 8])
		if _red_bullet_data == null:
			_red_bullet_data = BulletData.new().tex("棱弹").color(Color.RED).blend(true).enemy()
		for i in count:
			_red_bullet_data.speed(RING_SPEED + i * 50)  # 速度不属弹型：每发写一次
			_kernel_spread(_red_bullet_data, num, 1 / TAU / 3, away, pos, host)
	AudioManager.play_sfx(AssetRegistry.sounds["kira"], -8.0)
	return true


## 内核版 shoot_spread：只入队（内核行为循环中途禁止直接 spawn）。
func _kernel_spread(data: BulletData, count: int, spread: float, base_dir: Vector2, at: Vector2, host) -> void:
	if count <= 0:
		return
	if count == 1:
		host.queue_spawn(data, at, base_dir)
		return
	var step := spread / (count - 1) if spread < TAU - 0.001 else spread / count
	for i in count:
		host.queue_spawn(data, at, base_dir.rotated(-spread / 2.0 + step * i))

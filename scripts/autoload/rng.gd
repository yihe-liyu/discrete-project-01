extends Node
## 可复现随机数（replay 基础）。所有随机数必须走 RNG，不要用全局 randf()/randi()。
## 本项目**唯一随机真源**；其他可播种 RNG（如内核 BulletSystem）跟随本 autoload 的 seed。

signal seed_changed(seed_value: int)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready():
	randomize_seed()   # 走方法以广播 seed（启动期通常无监听者，安全）

func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value
	seed_changed.emit(seed_value)

## 重新随机化种子（工作台关闭"固定种子"时调用）
func randomize_seed() -> void:
	_rng.randomize()
	seed_changed.emit(_rng.seed)

func get_seed() -> int:
	return _rng.seed

func randf() -> float:
	return _rng.randf()

func randi() -> int:
	return _rng.randi()

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func randfn(mean: float = 0.0, deviation: float = 1.0) -> float:
	return _rng.randfn(mean, deviation)

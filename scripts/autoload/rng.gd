extends Node
## 可复现随机数（replay 基础）。所有随机数必须走 RNG，不要用全局 randf()/randi()。
## 本项目唯一随机真源；其他可播种 RNG（如内核 BulletSystem）跟随本 autoload 的 seed。

signal seed_changed(seed_value: int)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 纯表现随机流（屏幕抖动 / 粒子 / UI）：不参与 gameplay，不污染回放 RNG。
var _fx_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Replay 调试钩子：每次 gameplay RNG 调用都通知（参数 = 入口名）。
var rng_trace_hook: Callable = Callable()
## 调试：接下来多少次 RNG 调用打印 hook 状态。
var debug_calls_left: int = 0

func _ready():
	randomize_seed()   # 走方法以广播 seed（启动期通常无监听者，安全）
	_fx_rng.randomize()

func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value
	seed_changed.emit(seed_value)

## 重新随机化种子（工作台关闭"固定种子"时调用）
func randomize_seed() -> void:
	_rng.randomize()
	seed_changed.emit(_rng.seed)

func get_seed() -> int:
	return _rng.seed


## 快照完整 RNG 状态（seed + state）；创作台反射探针用完恢复。
func snapshot_state() -> Dictionary:
	return {"seed": _rng.seed, "state": _rng.state}


func restore_state(snapshot: Dictionary, p_emit: bool = false) -> void:
	if snapshot.is_empty():
		return
	_rng.seed = int(snapshot.get("seed", _rng.seed))
	_rng.state = int(snapshot.get("state", _rng.state))
	if p_emit:
		seed_changed.emit(_rng.seed)

func randf() -> float:
	var before := _rng.state
	var value := _rng.randf()
	if rng_trace_hook.is_valid():
		var caller := ""
		var st := get_stack()
		if st.size() > 1:
			caller = str(st[1].source) + ":" + str(st[1].line)
		rng_trace_hook.call(&"randf", before, _rng.state, caller)
	return value

func randi() -> int:
	var before := _rng.state
	var value := _rng.randi()
	if rng_trace_hook.is_valid():
		var caller := ""
		var st := get_stack()
		if st.size() > 1:
			caller = str(st[1].source) + ":" + str(st[1].line)
		rng_trace_hook.call(&"randi", before, _rng.state, caller)
	return value

func randf_range(from: float, to: float) -> float:
	var before := _rng.state
	var value := _rng.randf_range(from, to)
	if rng_trace_hook.is_valid():
		var caller := ""
		var st := get_stack()
		if st.size() > 1:
			caller = str(st[1].source) + ":" + str(st[1].line)
		rng_trace_hook.call(&"randf_range", before, _rng.state, caller)
	return value

func randi_range(from: int, to: int) -> int:
	var before := _rng.state
	var value := _rng.randi_range(from, to)
	if rng_trace_hook.is_valid():
		var caller := ""
		var st := get_stack()
		if st.size() > 1:
			caller = str(st[1].source) + ":" + str(st[1].line)
		rng_trace_hook.call(&"randi_range", before, _rng.state, caller)
	return value

func randfn(mean: float = 0.0, deviation: float = 1.0) -> float:
	var before := _rng.state
	var value := _rng.randfn(mean, deviation)
	if rng_trace_hook.is_valid():
		var caller := ""
		var st := get_stack()
		if st.size() > 1:
			caller = str(st[1].source) + ":" + str(st[1].line)
		rng_trace_hook.call(&"randfn", before, _rng.state, caller)
	return value

func fx_randf() -> float:
	return _fx_rng.randf()


func fx_randf_range(from: float, to: float) -> float:
	return _fx_rng.randf_range(from, to)

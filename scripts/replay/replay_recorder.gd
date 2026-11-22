## ReplayRecorder —— Replay 录输入基础设施
## 每帧记录玩家输入位掩码 + RNG 种子，可序列化为 JSON（ReplaySession 负责录制/播放生命周期）
## 铁律：capture() 必须挂在 _physics_process（物理帧固定 60Hz，与渲染帧率设置无关）——
##   挂渲染帧会导致不同帧率下录制长度不同、回放错乱。Engine.max_fps 只限渲染，物理 tick 不变。
class_name ReplayRecorder
extends RefCounted

## 录制动作顺序（位掩码按此索引 —— 格式兼容性，勿改顺序）
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "shoot", "focus", "memory_release"]
const FORMAT_VERSION := 1

## 每帧输入位掩码
var frames: PackedByteArray = PackedByteArray()
## 录制起始 RNG 种子（勿叫 seed：会遮蔽内建 seed()）
var rng_seed: int = 0
## 录制开始时的完整 RNG state；只存 seed 会丢掉当前 state。
var rng_state: int = 0
## 是否正在录制
var recording := false
## 已录帧数
var duration_frames := 0
## 首个录制物理帧的 Engine 帧号；事件 engine_tick 是绝对帧号，回放用它与本值
## 一起换算成“录制内相对 tick”，避免跨进程回放时事件被当成早就到点。
var start_engine_tick: int = -1
## 录制时 GameScene 是否以 -1000 priority 先推进回放/采样，再让 MarisaShoot(-100)
## 等负 priority 节点跑。旧录像没有这个字段，回放沿用旧时序。
var clock_first: bool = false
## deathbomb 是否用 GameplayClock 冻结玩法（SceneTree 暂停）。旧录像没有这个字段，
## 回放必须继续用 Engine.time_scale=0，否则冻结期的协程相位会差一帧。
var clock_freeze: bool = false
## 内容计时是否走整数物理帧（CoroutineRunner / Timeline / ClockService）。
## 旧录像没有这个字段：回放继续用浮点 dt，保持旧内容相位。
var frame_content: bool = false
var _capture_started := false
## 回放元数据（关卡 / 难度 / 角色 / 分数等；由录制方填写）
var metadata: Dictionary = {}
## 离散输入事件（bomb / memory_release）：{frame, action}。
## 不能只靠每帧位掩码：deathbomb 定格期间物理帧停止，bomb 事件必须单独记。
var events: Array[Dictionary] = []
## 逐帧状态采样（位置 / RNG / 分数 / 残机 / 雷）；用于定位回放首个分歧。
var samples: Array[Dictionary] = []
## 得分来源事件 {frame, amount, source}：追 score 分歧用。
var score_events: Array[Dictionary] = []
## 每次敌弹命中自机：frame / uid / type / pos。很小，常驻。
var hit_events: Array[Dictionary] = []
## 弹幕生成事件：frame / uid / type / p / faction / behavior。很小，常驻。
var spawn_events: Array[Dictionary] = []
## gameplay RNG 调用序列：frame / 入口名。用于定位 RNG 流错位。
var rng_calls: Array[Dictionary] = []
## 擦弹事件：frame / uid / roll 前后 state；定位 graze 清弹跨帧。
var graze_events: Array[Dictionary] = []
## 弹消失事件：frame / uid。回放只用来校验/定位是哪颗弹在录制里被回收。
var despawn_events: Array[Dictionary] = []
## 对话等待结束（LINE/WAIT）的 Engine tick；回放按帧推进对话。
var dialogue_advances: Array[Dictionary] = []


## 开始录制：重置缓冲 + 记录当前 RNG 种子
func start() -> void:
	frames = PackedByteArray()
	events.clear()
	samples.clear()
	score_events.clear()
	despawn_events.clear()
	dialogue_advances.clear()
	var rng_snapshot := RNG.snapshot_state()
	rng_seed = int(rng_snapshot.get("seed", 0))
	rng_state = int(rng_snapshot.get("state", 0))
	recording = true
	duration_frames = 0
	start_engine_tick = -1
	clock_first = true
	clock_freeze = true
	frame_content = true
	_capture_started = false


## 每帧调用一次：采样当前输入为位掩码
func capture() -> void:
	if not recording:
		return
	if not _capture_started:
		_capture_started = true
		start_engine_tick = Engine.get_physics_frames()
	frames.append(input_mask())
	duration_frames += 1


## 记录一次离散动作；frame = 当前已录物理帧数（定格中也可用）。
## [param at_next_tick] 用于输入事件：输入在物理帧之间派发，效果从下一物理帧开始，
## 因此归属 tick = duration_frames + 1；物理帧内派发的事件归属当前 tick。
func capture_event(action: StringName, at_next_tick: bool = false) -> void:
	if not recording:
		return
	# 当前帧 sample 已写 = 事件发生在采样之后；否则会落在下一帧采样前。
	var after_sample := samples.size() >= duration_frames
	# capture_frame 在物理帧开头先 +1，但这一帧的 sample 在帧末才写。
	# before_sample 事件实际属于 sample(duration-1)，事件帧必须同步减一。
	var event_frame := duration_frames
	if not after_sample and duration_frames > 0:
		event_frame = duration_frames - 1
	events.append({
		"frame": event_frame,
		# tick 是回放消费用的真实物理 tick（与 frame 的 sample 相位解耦）。
		"tick": duration_frames + (1 if at_next_tick else 0),
		# engine_tick 是 Engine 物理帧号：回放/录制场景装载差不会让它漂移。
		"engine_tick": Engine.get_physics_frames() + (1 if at_next_tick else 0),
		"action": String(action),
		"after_sample": after_sample,
		"at_next_tick": at_next_tick,
	})


## 记录一次得分来源（敌人 / 道具 / 擦弹 / 符卡奖励）。
func capture_score(amount: int, source: StringName) -> void:
	if not recording:
		return
	score_events.append({"frame": duration_frames, "amount": amount, "source": String(source)})


## 记录一帧状态采样（与 frames 同序）。
func capture_sample(sample: Dictionary) -> void:
	if not recording:
		return
	samples.append(sample.duplicate(true))


## 停止录制
func stop() -> void:
	recording = false


## 当前输入 → 位掩码（ACTIONS[i] 按下则第 i 位置 1）
## 优先用 PlayerInput 的本物理 tick 锁存，保证录制与玩法读到同一份快照。
func input_mask() -> int:
	return PlayerInput.input_mask()


## 某帧是否按下某动作（回放播放器用）
func is_action_pressed_at(frame: int, action: String) -> bool:
	var idx := ACTIONS.find(action)
	if idx < 0 or frame < 0 or frame >= frames.size():
		return false
	return (frames[frame] & (1 << idx)) != 0


## 序列化（JSON）
func to_dict() -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"actions": ACTIONS,
		"seed": str(rng_seed),
		"rng_state": str(rng_state),  # 字符串防 JSON int64 精度丢失（种子决定可复现性！）
		"duration": duration_frames,
		"start_engine_tick": start_engine_tick,
		"clock_first": clock_first,
		"clock_freeze": clock_freeze,
		"frame_content": frame_content,
		"frames_hex": frames.hex_encode(),
		"metadata": metadata,
		"events": events,
		"samples": samples,
		"score_events": score_events,
		"hits": hit_events,
		"spawns": spawn_events,
		"rng_calls": rng_calls,
		"graze_events": graze_events,
		"dialogue_advances": dialogue_advances,
		"despawns": despawn_events,
	}


## 存盘（user:// 或绝对路径）
func save(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ReplayRecorder: 无法写入 " + path)
		return false
	file.store_string(JSON.stringify(to_dict()))
	return true


## 从字典加载（版本/帧数校验；失败静默返回 false，由调用方决定日志）
func load_dict(data: Dictionary) -> bool:
	if data.get("version", 0) != FORMAT_VERSION:
		return false
	rng_seed = int(data.get("seed", "0"))  # 兼容字符串存储（JSON 键仍叫 seed）
	rng_state = int(data.get("rng_state", "0"))
	duration_frames = data.get("duration", 0)
	start_engine_tick = int(data.get("start_engine_tick", -1))
	clock_first = bool(data.get("clock_first", false))
	clock_freeze = bool(data.get("clock_freeze", false))
	frame_content = bool(data.get("frame_content", false))
	frames = (data.get("frames_hex", "") as String).hex_decode()
	if frames.size() != duration_frames:
		return false
	metadata = data.get("metadata", {})
	if metadata is not Dictionary:
		metadata = {}
	events.clear()
	var raw_events = data.get("events", [])
	if raw_events is Array:
		for e in raw_events:
			if e is Dictionary:
				events.append(e.duplicate(true))
	samples.clear()
	var raw_samples = data.get("samples", [])
	if raw_samples is Array:
		for sample in raw_samples:
			if sample is Dictionary:
				samples.append(sample.duplicate(true))
	score_events.clear()
	var raw_scores = data.get("score_events", [])
	if raw_scores is Array:
		for e in raw_scores:
			if e is Dictionary:
				score_events.append(e.duplicate(true))
	hit_events.clear()
	var raw_hits = data.get("hits", [])
	if raw_hits is Array:
		for e in raw_hits:
			if e is Dictionary:
				hit_events.append(e.duplicate(true))
	spawn_events.clear()
	var raw_spawns = data.get("spawns", [])
	if raw_spawns is Array:
		# 旧录制里 behavior emit 可能被 spawn_prepared 和 notify 各记一次，
		# 同一 (frame, uid, type) 只保留第一次（真正的出生点）。
		var seen_spawns := {}
		for e in raw_spawns:
			if e is Dictionary:
				var key := "%d:%d:%d" % [
					int(e.get("frame", 0)), int(e.get("uid", 0)), int(e.get("type", -1))]
				if seen_spawns.has(key):
					continue
				seen_spawns[key] = true
				spawn_events.append(e.duplicate(true))
	rng_calls.clear()
	var raw_rng = data.get("rng_calls", [])
	if raw_rng is Array:
		for e in raw_rng:
			if e is Dictionary:
				rng_calls.append(e.duplicate(true))
	despawn_events.clear()
	var raw_despawns = data.get("despawns", [])
	if raw_despawns is Array:
		for e in raw_despawns:
			if e is Dictionary:
				despawn_events.append(e.duplicate(true))
	dialogue_advances.clear()
	var raw_dialogue = data.get("dialogue_advances", [])
	if raw_dialogue is Array:
		for e in raw_dialogue:
			if e is Dictionary:
				dialogue_advances.append(e.duplicate(true))
	graze_events.clear()
	var raw_graze = data.get("graze_events", [])
	if raw_graze is Array:
		for e in raw_graze:
			if e is Dictionary:
				graze_events.append(e.duplicate(true))
	return true


## 读取存档文件
func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return false
	return load_dict(parsed)

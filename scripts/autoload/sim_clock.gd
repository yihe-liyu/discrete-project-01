## 确定性物理 tick 时钟 —— 玩法时间的唯一权威。
##
## [b]职责[/b][br]
## - 每个物理 tick 自增 [member tick]；冻结期间 tick 继续走，玩法节点由
##   [code]SceneTree.paused[/code] 停步。[br]
## - 在每个 tick 开头锁存输入，冻结窗口里的 ALWAYS 节点也读同一份快照。[br]
## - 定格只认 tick/frames，不碰 [code]Engine.time_scale[/code]，也不用真实时间 Timer。[br]
## [br]
## [b]冻结[/b][br]
## - [method freeze] 支持多个 owner 嵌套；只有最后一个 owner 移除才恢复玩法树。[br]
## - [code]auto_unfreeze = true[/code] 到点自动解冻（Boss 全破定格）；
##   [code]false[/code] 由 owner 自己收尾（deathbomb 要在同一 tick 结算 miss）。[br]
## - 暂停菜单自己也会暂停树；本时钟只在“自己暂停的”情况下负责恢复，且覆盖层打开时不抢恢复。
extends Node

## 固定物理 tick 率；玩法状态只能按这个步长推进，不读引擎 delta。
const TICK_RATE := 60
const DT := 1.0 / float(TICK_RATE)

## 自加载以来的物理 tick 计数（含冻结帧；暂停菜单期间不走）。
var tick: int = 0
## tick 钩子：prepare 在 latch 前（回放注入输入），observer 在 latch 后（录制/校验状态）。
var tick_prepare: Callable = Callable()
var tick_observer: Callable = Callable()
## 显式 tick 化的移动器：由 SimClock 统一推进，避免“物理回调中新增节点错过本帧注册”。
var _movers: Array[Node] = []

## owner -> {left: int, auto: bool}
var _freezes: Dictionary = {}
## 本次冻结是否由本时钟把 SceneTree.paused 置 true。
var _paused_tree: bool = false
## 物理帧内解冻时，把“恢复树”推迟到下一 tick 的最开头，优先于所有玩法节点。
var _unpause_pending: bool = false


func _ready() -> void:
	# 暂停菜单 / 定格时时钟必须继续走，否则窗口永远关不掉。
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 先于所有玩法节点推进，保证冻结 tick 的边界稳定。
	process_physics_priority = -10000


func _physics_process(_delta: float) -> void:
	if _unpause_pending:
		_unpause_pending = false
		_paused_tree = false
		_unpause_tree_if_clean()
	# 冻结期间如果别的系统把树解开了（例如暂停菜单关闭），先重新压住，
	# 保证“冻结”在任何情况下都不会漏出一帧玩法。
	if is_frozen() and not get_tree().paused:
		get_tree().paused = true
		_paused_tree = true
	# 暂停菜单：树被暂停但不是玩法冻结 → 时钟不走，输入也不锁存。
	if get_tree().paused and not is_frozen():
		return

	var next_tick := tick + 1
	if tick_prepare.is_valid():
		tick_prepare.call(next_tick)
	tick = next_tick
	PlayerInput.latch()
	if tick_observer.is_valid():
		tick_observer.call(tick)
	if not is_frozen():
		_tick_movers()  # 冻结期间玩法树暂停；mover 也不能偷偷前进
	if _freezes.is_empty():
		return
	_advance_freezes()


## 注册一个 TickMover（由 TickMover._ready 调用）。
func register_mover(mover: Node) -> void:
	if mover != null and not _movers.has(mover):
		_movers.append(mover)


## 注销 TickMover（由 TickMover._exit_tree 调用）。
func unregister_mover(mover: Node) -> void:
	_movers.erase(mover)


func _tick_movers() -> void:
	if _movers.is_empty():
		return
	for mover in _movers.duplicate():
		if not is_instance_valid(mover):
			_movers.erase(mover)
			continue
		mover.tick_mover()


## 冻结玩法 [param frames] 个物理 tick。返回 true = 新增了一个 owner。
## [param auto_unfreeze] false 时，帧数走到 0 仍保持冻结，由 owner 调 [method unfreeze] 收尾。
func freeze(p_owner: Object, frames: int, auto_unfreeze: bool = true) -> bool:
	if p_owner == null or not is_instance_valid(p_owner):
		return false
	if _freezes.has(p_owner):
		return false
	_freezes[p_owner] = {"left": maxi(1, frames), "auto": auto_unfreeze}
	if _freezes.size() == 1:
		# 还没执行的解冻被新的冻结覆盖：树必须保持暂停。
		_unpause_pending = false
		if not get_tree().paused:
			get_tree().paused = true
			_paused_tree = true
	return true


## 移除一个冻结 owner；最后一个 owner 移除时安排恢复玩法树。
func unfreeze(p_owner: Object) -> bool:
	if p_owner == null or not _freezes.has(p_owner):
		return false
	_freezes.erase(p_owner)
	if _freezes.is_empty():
		_schedule_unpause()
	return true


## 当前是否处于玩法冻结。
func is_frozen() -> bool:
	return not _freezes.is_empty()


## 某个 owner 还剩多少冻结帧；不是 owner = 0。
func frames_left(p_owner: Object) -> int:
	if p_owner == null or not _freezes.has(p_owner):
		return 0
	return int((_freezes[p_owner] as Dictionary).get("left", 0))


## 注册 tick 钩子；传空 Callable 清除。
## prepare：latch 前（回放注入 mask / 命令）；observer：latch 后（录制 / 哈希校验）。
func set_tick_hooks(prepare: Callable, observer: Callable) -> void:
	tick_prepare = prepare
	tick_observer = observer


## 清除 tick 钩子（场景退出 / 测试清理）。
func clear_tick_hooks() -> void:
	tick_prepare = Callable()
	tick_observer = Callable()


## 测试 / 场景回收兜底：清空所有冻结并恢复树（覆盖层打开时交给菜单恢复）。
func reset() -> void:
	_freezes.clear()
	_movers.clear()
	_unpause_pending = false
	tick_prepare = Callable()
	tick_observer = Callable()
	if _paused_tree:
		_paused_tree = false
		# 场景回收 / 测试兜底：这里必须强制恢复，不能留给可能正在销毁的菜单。
		if is_inside_tree():
			get_tree().paused = false


func _advance_freezes() -> void:
	for p_owner in _freezes.keys():
		if not is_instance_valid(p_owner):
			_freezes.erase(p_owner)
			continue
		var rec: Dictionary = _freezes[p_owner]
		rec["left"] = int(rec.get("left", 0)) - 1
		if int(rec.get("left", 0)) <= 0 and bool(rec.get("auto", false)):
			_freezes.erase(p_owner)
	if _freezes.is_empty():
		_schedule_unpause()


func _schedule_unpause() -> void:
	if not _paused_tree:
		return
	if Engine.is_in_physics_frame():
		_unpause_pending = true
	else:
		_paused_tree = false
		_unpause_tree_if_clean()


func _unpause_tree_if_clean() -> void:
	if not is_inside_tree():
		return
	if GameManager.has_open_overlay():
		return
	get_tree().paused = false

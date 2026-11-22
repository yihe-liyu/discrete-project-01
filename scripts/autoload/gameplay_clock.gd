## 玩法物理时钟 —— 影响玩法的时序只认这里的物理 tick。
##
## [b]职责[/b][br]
## - 记录本局经过的物理 tick（含 deathbomb 定格帧，不含暂停菜单）。[br]
## - 提供可嵌套的冻结：冻结期间玩法节点停步，但时钟本身仍走，
##   这样回放帧、deathbomb 倒计时和输入事件不会跟着停。[br]
## - 冻结用 [code]SceneTree.paused[/code] 实现；玩法节点不再依赖
##   [code]Engine.time_scale = 0[/code]（旧录像兼容路径除外）。[br]
## - 默认表现也会随树暂停；需要继续走真实时间的层自己标
##   [code]PROCESS_MODE_ALWAYS[/code] / [code]TWEEN_PAUSE_PROCESS[/code]。[br]
##
## [b]边界[/b][br]
## - 时钟只负责 tick 与冻结状态，不直接改节点 [code]process_mode[/code]。[br]
## - 冻结 owner 必须成对 [method freeze] / [method unfreeze]；
##   owner 出树时要自己 unfreeze（见 Player._exit_tree）。[br]
## - 暂停菜单也暂停 SceneTree，但它不经过这里；[method _physics_process]
##   在「树暂停且非本时钟冻结」时直接返回，不会偷偷推进玩法 tick。
extends Node

## 每个玩法物理 tick 发一次；参数是自加载以来的累计 tick（含冻结帧）。
signal ticked(tick: int)
## 冻结开始 / 结束（最外层 owner 变化时各发一次）。
signal freeze_changed(frozen: bool)

## 累计物理 tick；只用于排序/诊断，不作为跨进程绝对时间。
var tick: int = 0

## 当前冻结 owner（Object 身份；同一 owner 重复 freeze 只算一次）。
var _freeze_owners: Array[Object] = []
## 最外层冻结开始后经过的物理 tick；新的冻结开始时归零。
var _freeze_ticks: int = 0
## 本次冻结是否由本时钟把 SceneTree.paused 置 true（暂停菜单自己置的不能替它恢复）。
var _paused_tree: bool = false
## 物理帧内解冻时，把「恢复树」推迟到下一物理 tick 的最开头（优先于所有玩法节点）。
## 用 call_deferred 会晚一个物理帧，deathbomb 后的第一轮弹幕会整体错一帧。
var _unpause_pending: bool = false
## 冻结期间每 tick 的驱动（GameScene 注册；用于回放帧 / 录制采样继续走）。
var _freeze_driver: Callable = Callable()


func _ready() -> void:
	# 暂停菜单会暂停整棵树；时钟必须继续走，否则 deathbomb 窗口永远关不掉。
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 先于所有玩法节点推进，保证冻结 tick 的边界稳定。
	process_physics_priority = -10000


func _physics_process(_delta: float) -> void:
	# 上一物理帧内解冻：在本 tick 所有玩法节点之前恢复树，不能多丢一帧。
	if _unpause_pending:
		_unpause_pending = false
		_paused_tree = false
		_unpause_tree_if_clean()
	# 暂停菜单：树被暂停，但不是玩法冻结 → 玩法 tick 停走。
	if get_tree().paused and not is_frozen():
		return
	tick += 1
	if is_frozen():
		_freeze_ticks += 1
		if _freeze_driver.is_valid():
			_freeze_driver.call()
	ticked.emit(tick)


## 冻结玩法。返回 true = 这次调用真的新增了一个 owner。
## [param p_owner] 用调用方自身（通常 [code]self[/code]），便于出树时精确解冻。
func freeze(p_owner: Object) -> bool:
	if p_owner == null or not is_instance_valid(p_owner):
		return false
	if _freeze_owners.has(p_owner):
		return false
	_freeze_owners.append(p_owner)
	if _freeze_owners.size() == 1:
		_freeze_ticks = 0
		# 还没执行的解冻被新的冻结覆盖：树必须保持暂停。
		_unpause_pending = false
		if not get_tree().paused:
			get_tree().paused = true
			_paused_tree = true
		freeze_changed.emit(true)
	return true


## 解冻；只有最后一个 owner 移除时才真正恢复 SceneTree。
## 物理帧内解冻会在下一物理 tick 的最开头恢复，避免同一 tick 后半段节点突然执行。
func unfreeze(p_owner: Object) -> bool:
	if p_owner == null or not _freeze_owners.has(p_owner):
		return false
	_freeze_owners.erase(p_owner)
	if _freeze_owners.is_empty():
		_freeze_ticks = 0
		if _paused_tree:
			if Engine.is_in_physics_frame():
				_unpause_pending = true
			else:
				_paused_tree = false
				_unpause_tree_if_clean()
		freeze_changed.emit(false)
	return true


## 当前是否处于玩法冻结。
func is_frozen() -> bool:
	return not _freeze_owners.is_empty()


## 最外层冻结开始后经过的玩法物理 tick（冻结期间每 tick +1）。
func freeze_ticks() -> int:
	return _freeze_ticks


## 冻结期间每 tick 的回调；传空 Callable 解除。GameScene 退出时必须解除。
func set_freeze_driver(driver: Callable) -> void:
	_freeze_driver = driver


## 测试 / 场景回收兜底：清空所有 owner 并恢复树。
## 正常流程不要用它代替成对的 unfreeze。
func reset() -> void:
	if _freeze_owners.is_empty() and not _paused_tree:
		return
	_freeze_owners.clear()
	_freeze_ticks = 0
	_unpause_pending = false
	if _paused_tree:
		_paused_tree = false
		if is_inside_tree():
			get_tree().paused = false
	freeze_changed.emit(false)


## 只有没有暂停菜单覆盖层时才恢复树；窗口里按暂停时，树应保持暂停。
func _unpause_tree_if_clean() -> void:
	if not is_inside_tree():
		return
	if GameManager.has_open_overlay():
		return
	get_tree().paused = false

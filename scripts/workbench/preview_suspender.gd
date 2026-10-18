extends RefCounted
## 整关预览冻结/恢复服务（D3：从 Workbench 拆出的第一块）。
##
## 为什么单独一层：
##   - Workbench 的 $World / 背景显式 `process_mode=PAUSABLE`，根节点 DISABLED 压不住；
##     必须递归快照整棵子树的 process_mode。
##   - CanvasLayer 不随父 Control visible 隐藏；stage 脚本的 logo 是运行时 add_child 的层。
##   - BGM 要暂停而不是 stop（恢复后原处继续）；全局 paused/time_scale 必须解掉。
##   - Tween 的 TWEEN_PAUSE_BOUND 会随绑定节点 process_mode 暂停，不需要（也不应该）全局 pause。
##
## 本服务只碰宿主树/引擎/音频总线，不碰 Workbench 的播放状态；恢复后的
## Playback 投影由宿主通过 on_resume 回调下发。

var _host: Node
var _on_resume: Callable
var _suspended: bool = false
## 切走时递归收集的 CanvasLayer + 原可见性
var _layers: Array[CanvasLayer] = []
var _layer_visibility: Array[bool] = []
## 切走时整棵子树的 process_mode 快照
var _process_modes: Dictionary = {}


func setup(host: Node, on_resume: Callable) -> void:
	_host = host
	_on_resume = on_resume


func is_suspended() -> bool:
	return _suspended


func suspend() -> void:
	if _suspended or _host == null or not is_instance_valid(_host):
		return
	_suspended = true
	_host.visible = false
	_set_layers_visible(false)
	_freeze_process_subtree()
	AudioManager.pause_bgm()
	var tree := _host.get_tree()
	if tree != null:
		tree.paused = false
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8
	AudioManager.set_bgm_pitch(1.0)
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, false)
	_host.process_mode = Node.PROCESS_MODE_DISABLED


func resume() -> void:
	if not _suspended:
		return
	_suspended = false
	if _host == null or not is_instance_valid(_host):
		return
	_host.visible = true
	_set_layers_visible(true)
	_restore_process_modes()
	_host.process_mode = Node.PROCESS_MODE_ALWAYS
	AudioManager.resume_bgm()
	if _on_resume.is_valid():
		_on_resume.call()


## CanvasLayer 不随父 Control 的 visible 隐藏；stage logo 是内容脚本在 StageRuntime 里
## add_child 的层，必须递归找。
func _set_layers_visible(on: bool) -> void:
	if on:
		for i in _layers.size():
			var layer: CanvasLayer = _layers[i]
			if is_instance_valid(layer):
				layer.visible = _layer_visibility[i]
		_layers.clear()
		_layer_visibility.clear()
		return
	_layers.clear()
	_layer_visibility.clear()
	_collect_layers(_host)
	for layer in _layers:
		_layer_visibility.append(layer.visible)
		layer.visible = false


func _collect_layers(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			_layers.append(child as CanvasLayer)
		_collect_layers(child)


## $World/背景显式 PAUSABLE 不会自动继承根节点 DISABLED ⇒ 逐个快照/禁用。
func _freeze_process_subtree() -> void:
	_process_modes.clear()
	_snapshot_and_disable(_host)


func _snapshot_and_disable(node: Node) -> void:
	_process_modes[node] = node.process_mode
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_snapshot_and_disable(child)


func _restore_process_modes() -> void:
	for node in _process_modes:
		if is_instance_valid(node):
			node.process_mode = _process_modes[node]
	_process_modes.clear()

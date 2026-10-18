extends RefCounted
## 整关预览键盘快捷键（D3：从 Workbench 拆出的第三块）。
##
## 只做“键盘事件 → 意图”的翻译；真正的重跑/逐帧/跳转仍在 Workbench，
## 通过 Callable 注入，避免服务反向摸宿主私有状态。
##
## 快捷键：Space 播放/暂停 · R 重跑 · F 逐帧 · 1~7 速度档
##         ←/→ 跳 ±1s（Ctrl ±5s）· B 打书签 · Home 回开头 · Ctrl+G 强制清场

var _host: Node
var _playback: Playback
var _bookmark_panel
var _restart: Callable
var _frame_step: Callable
var _jump_to: Callable
var _time_getter: Callable
var _debug_force_clear: Callable


func setup(host: Node, playback: Playback, bookmark_panel, restart: Callable,
		frame_step: Callable, jump_to: Callable, time_getter: Callable,
		debug_force_clear: Callable) -> void:
	_host = host
	_playback = playback
	_bookmark_panel = bookmark_panel
	_restart = restart
	_frame_step = frame_step
	_jump_to = jump_to
	_time_getter = time_getter
	_debug_force_clear = debug_force_clear


## 返回 true = 已消费，调用方负责 set_input_as_handled。
func handle(event: InputEvent) -> bool:
	if _host == null or _playback == null:
		return false
	var fo := _host.get_viewport().gui_get_focus_owner()
	if fo and (fo is LineEdit or fo is TextEdit or fo is SpinBox):
		return false
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var keycode: int = event.physical_keycode
	if keycode == 0:
		keycode = event.keycode
	match keycode:
		KEY_SPACE:
			_playback.toggle_play()
		KEY_R:
			if _restart.is_valid():
				_restart.call()
		KEY_F:
			if _frame_step.is_valid():
				_frame_step.call()
		KEY_LEFT, KEY_RIGHT:
			if _jump_to.is_valid() and _time_getter.is_valid():
				var step := 5.0 if event.ctrl_pressed else 1.0
				var target: float = maxf(_time_getter.call() + (step if keycode == KEY_RIGHT else -step), 0.0)
				_jump_to.call(target)
		KEY_B:
			if _bookmark_panel != null:
				_bookmark_panel.open_add()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
			var idx: int = keycode - KEY_1
			if idx >= 0 and idx < Playback.SPEEDS.size():
				_playback.select_speed(idx)
		KEY_HOME:
			if _restart.is_valid():
				_restart.call()
		KEY_G:
			if event.ctrl_pressed and _debug_force_clear.is_valid():
				_debug_force_clear.call()
		_:
			return false
	return true

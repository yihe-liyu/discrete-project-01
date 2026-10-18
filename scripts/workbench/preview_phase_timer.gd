extends RefCounted
## 整关预览的 Boss 符卡倒计时（D3：从 Workbench 拆出的第五块）。
## 与真游戏 BossUI 同款：两位秒数、框顶中央、符卡名下方；间隙/无 Boss 隐藏。

var _stage_runtime: StageRuntime
var _label: Label


func setup(ui_layer: CanvasLayer, runtime: StageRuntime) -> void:
	_stage_runtime = runtime
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 32)
	# y 与 BossUI.TimerLabel 对齐（场景 offset_top = 64：场地坐标即 FIELD_TOP + 64）
	_label.position = Vector2(
		GameConfig.FIELD_LEFT + (GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT) / 2.0 - 16.0,
		GameConfig.FIELD_TOP + 64.0)
	_label.visible = false
	ui_layer.add_child(_label)


func label() -> Label:
	return _label


## 倒计时更新（超时归零、间隙隐藏）
func update() -> void:
	if _label == null or _stage_runtime == null:
		return
	var boss: Boss = _stage_runtime.entity_registry.get_boss()
	if boss == null or not is_instance_valid(boss):
		_label.visible = false
		return
	var phase := boss.current_phase()
	if not phase or phase.time_limit <= 0 or boss.is_in_gap():
		_label.visible = false
		return
	_label.visible = true
	var rem := maxf(phase.time_limit - boss.get_elapsed(), 0.0)
	_label.text = "%02d" % int(ceil(rem))

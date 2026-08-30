class_name PlaybackBar
extends VBoxContainer
## 播放控制行：播放/暂停、重跑、静音、背景、命中框、速度档位
## 纯视图：只发信号不碰状态；状态由 Workbench 主控制器持有并同步回来

signal play_toggled
signal restart_requested
signal mute_toggled(on: bool)
signal bg_toggled(on: bool)
signal hitbox_toggled(on: bool)
signal speed_selected(idx: int)
signal seed_toggled(on: bool)

const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]

var _play_btn: Button
var _speed_opt: OptionButton
var _fixed_seed_cb: CheckButton


func _init() -> void:
	add_theme_constant_override("separation", 4)
	# 行 1：播放/重跑 并排（剪辑软件式传送带）
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	_play_btn = Button.new()
	_play_btn.text = "暂停"
	_play_btn.pressed.connect(func(): play_toggled.emit())
	row1.add_child(_play_btn)
	var restart := Button.new()
	restart.text = "重跑"
	restart.pressed.connect(func(): restart_requested.emit())
	row1.add_child(restart)
	add_child(row1)

	# 行 2：紧凑开关一行排开（不再与速度下拉交错）
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	var mute := CheckButton.new()
	mute.text = "静音"
	mute.toggled.connect(func(on: bool): mute_toggled.emit(on))
	row2.add_child(mute)
	var bg := CheckButton.new()
	bg.text = "背景"
	bg.button_pressed = true
	bg.toggled.connect(func(on: bool): bg_toggled.emit(on))
	row2.add_child(bg)
	var hb := CheckButton.new()
	hb.text = "命中框"
	hb.toggled.connect(func(on: bool): hitbox_toggled.emit(on))
	row2.add_child(hb)
	var fixed_seed := CheckButton.new()
	fixed_seed.text = "固定种子"
	fixed_seed.tooltip_text = "重跑时复用同一随机种子 → 弹幕序列可复现（调参看效果必备）"
	fixed_seed.toggled.connect(func(on: bool): seed_toggled.emit(on))
	row2.add_child(fixed_seed)
	_fixed_seed_cb = fixed_seed
	add_child(row2)

	# 行 3：速度档位（独占一行，避免与其他开关交错）
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	var speed := OptionButton.new()
	speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in SPEEDS:
		speed.add_item("×" + str(s))
	speed.selected = 2
	speed.item_selected.connect(func(idx: int): speed_selected.emit(idx))
	row3.add_child(speed)
	_speed_opt = speed
	add_child(row3)


## 速度档位同步（主控制器快捷键调档时更新下拉显示）
func set_speed(idx: int) -> void:
	if _speed_opt and idx >= 0 and idx < _speed_opt.item_count:
		_speed_opt.selected = idx


## 播放状态同步（主控制器调用：按钮文字跟随）
func set_playing(playing: bool) -> void:
	_play_btn.text = "暂停" if playing else "播放"

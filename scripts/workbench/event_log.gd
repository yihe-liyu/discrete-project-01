class_name EventLog
extends VBoxContainer
## 事件日志：Boss/符卡事件 + 工作台操作记录
## 自连 GameEvents（_exit_tree 统一断开，符合项目信号生命周期规范）

var _log: RichTextLabel
var _lines: Array[String] = []


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL  # 容器撑满页签，日志才能撑满容器
	add_theme_constant_override("separation", 4)
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0, 120)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.fit_content = false
	_log.scroll_following = true
	add_child(_log)


func _ready() -> void:
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.phase_start.connect(_on_phase_start)
	GameEvents.phase_end.connect(_on_phase_end)
	GameEvents.boss_defeated.connect(_on_boss_defeated)


func _exit_tree() -> void:
	if GameEvents.boss_spawned.is_connected(_on_boss_spawned):
		GameEvents.boss_spawned.disconnect(_on_boss_spawned)
	if GameEvents.phase_start.is_connected(_on_phase_start):
		GameEvents.phase_start.disconnect(_on_phase_start)
	if GameEvents.phase_end.is_connected(_on_phase_end):
		GameEvents.phase_end.disconnect(_on_phase_end)
	if GameEvents.boss_defeated.is_connected(_on_boss_defeated):
		GameEvents.boss_defeated.disconnect(_on_boss_defeated)


func log_line(text: String) -> void:
	_lines.append(text)
	while _lines.size() > 80:
		_lines.pop_front()
	_log.text = "\n".join(_lines)


# ═══ 关卡事件（自连，无需主控制器转发）═══

func _on_boss_spawned(_boss: Node) -> void:
	log_line("★ Boss 登场")


func _on_phase_start(phase: PhaseData) -> void:
	log_line("◆ 符卡开始：%s" % (phase.name if phase else "？"))


func _on_phase_end(_captured: bool, _bonus: int) -> void:
	log_line("◆ 符卡结束")


func _on_boss_defeated(_boss: Node) -> void:
	log_line("★ Boss 击破")

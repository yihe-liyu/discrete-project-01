# BossUI.gd
extends CanvasLayer

const GRAY := Color(0.4, 0.4, 0.4, 1.0)
const GREEN := Color(0.098, 0.7, 0.198, 1.0)
const GOLD := Color(0.95, 0.839, 0.475, 1.0)
const RED := Color(1.0, 0.0, 0.0, 1.0)
const PURPLE := Color(0.858, 0.5, 1.0, 1.0)
const DOT_SIZE := 16.0
## 符卡名大字报（场景声明式：Label 根 + Background/BonusLabel/CaptureLabel 子节点）。
const ANNOUNCE_SCENE := preload("res://scenes/ui/announce_label.tscn")
## 符卡名底衬（敌方 = 红）。玩家符卡（Bomb 名）用 player_spell_name_background。
const ENEMY_SPELL_NAME_BG := preload("res://assets/Textures/ascii/enemy_spell_name_background.png")

@onready var _boss_name: Label = $Control/BossName
@onready var _history: HBoxContainer = $Control/History

var _dots: Array[ColorRect] = []
var _phase_idx: int = 0
var _announce_label: AnnounceLabel
var _boss: Boss
var _boss_hud: BossHud
var _timer_label: Label

func _ready() -> void:
	visible = false
	_boss_name.visible = false   # 名字节点默认隐藏（关底 reveal 时才亮）
	_history.visible = false     # 阶段进度点默认隐藏（show_phase_dots 时才亮）
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_defeated.connect(_on_boss_defeated)
	GameEvents.phase_start.connect(_on_phase_start)
	GameEvents.phase_end.connect(_on_phase_end)
	GameEvents.phase_bonus_tick.connect(_on_tick)


func _exit_tree() -> void:
	for conn in [
		[GameEvents.boss_spawned, _on_boss_spawned],
		[GameEvents.boss_defeated, _on_boss_defeated],
		[GameEvents.phase_start, _on_phase_start],
		[GameEvents.phase_end, _on_phase_end],
		[GameEvents.phase_bonus_tick, _on_tick],
	]:
		if conn[0].is_connected(conn[1]):
			conn[0].disconnect(conn[1])
	_disconnect_hud()


## 断开当前 BossHud 的订阅（换 Boss / 退场时）
func _disconnect_hud() -> void:
	if _boss_hud == null:
		return
	if _boss_hud.display_name_changed.is_connected(_on_display_name_changed):
		_boss_hud.display_name_changed.disconnect(_on_display_name_changed)
	if _boss_hud.name_visibility_changed.is_connected(_on_name_visibility_changed):
		_boss_hud.name_visibility_changed.disconnect(_on_name_visibility_changed)
	if _boss_hud.phase_dots_visibility_changed.is_connected(_on_phase_dots_visibility_changed):
		_boss_hud.phase_dots_visibility_changed.disconnect(_on_phase_dots_visibility_changed)
	_boss_hud = null


func _on_boss_spawned(boss: Node) -> void:
	# 断开上一只 Boss 的显示状态连接（换 Boss / spawn 新 Boss 时）
	_disconnect_hud()
	_boss = boss as Boss
	var boss_data: BossData = boss.boss_data
	# 订阅显示状态——改名 / 显隐即时同步，不再每帧轮询
	_boss_hud = _boss.hud
	if _boss_hud != null:
		_boss_hud.display_name_changed.connect(_on_display_name_changed)
		_boss_hud.name_visibility_changed.connect(_on_name_visibility_changed)
		_boss_hud.phase_dots_visibility_changed.connect(_on_phase_dots_visibility_changed)
		_on_display_name_changed(_boss_hud.get_name())
		_on_name_visibility_changed(_boss_hud.is_name_shown())
		_on_phase_dots_visibility_changed(_boss_hud.is_phase_dots_shown())

	if not _timer_label:
		_timer_label = Label.new()
		_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_timer_label.add_theme_font_size_override("font_size", 32)
		$Control.add_child(_timer_label)
	_timer_label.position = Vector2($Control.size.x / 2.0 - 16, 16)
	_timer_label.visible = false

	for d in _dots: d.queue_free()
	_dots.clear()
	_phase_idx = 0

	for i in range(boss_data.phases_for_difficulty(SaveData.selected_difficulty).size() - 1, -1, -1):
		var phase: PhaseData = boss_data.phases_for_difficulty(SaveData.selected_difficulty)[i]
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.color = GRAY if phase.uid == 0 else GREEN
		_history.add_child(dot)
		_dots.append(dot)

	visible = true

func _on_display_name_changed(display_name: String) -> void:
	_boss_name.text = display_name if display_name != "" else "???"


func _on_name_visibility_changed(is_shown: bool) -> void:
	_boss_name.visible = is_shown


func _on_phase_dots_visibility_changed(is_shown: bool) -> void:
	_history.visible = is_shown

func _process(_delta: float) -> void:
	if not _boss or not is_instance_valid(_boss) or not visible:
		return
	var phase := _boss.current_phase()
	# 间隙期（换阶段之间）不显示
	if not phase or phase.time_limit <= 0 or _boss.is_in_gap():
		_timer_label.visible = false
		return
	_timer_label.visible = true
	var rem := maxf(phase.time_limit - _boss.get_elapsed(), 0.0)
	_timer_label.text = "%02d" % int(ceil(rem))

func _on_boss_defeated(_defeated_boss: Node) -> void:
	visible = false

func _on_phase_start(phase: PhaseData) -> void:
	if phase.uid != 0:
		_play_spell_announce(phase.name)
	else:
		_clear_announce()

	var vis_idx := _dots.size() - 1 - _phase_idx
	if vis_idx >= 0 and vis_idx < _dots.size():
		_dots[vis_idx].color = PURPLE

func _on_tick(bonus: int) -> void:
	if _announce_label and is_instance_valid(_announce_label):
		_announce_label.set_bonus_text(str(bonus))

func _on_phase_end(captured: bool, _bonus: int) -> void:
	_clear_announce()
	var vis_idx := _dots.size() - 1 - _phase_idx
	if vis_idx >= 0 and vis_idx < _dots.size():
		_dots[vis_idx].color = GOLD if captured else RED
	_phase_idx += 1

func _clear_announce() -> void:
	if _announce_label and is_instance_valid(_announce_label):
		_announce_label.clear()
		_announce_label = null


func _play_spell_announce(spell_name: String) -> void:
	_clear_announce()
	_announce_label = ANNOUNCE_SCENE.instantiate() as AnnounceLabel
	$Control.add_child(_announce_label)
	_announce_label.finished.connect(_update_capture_text, CONNECT_ONE_SHOT)
	_announce_label.play(spell_name, $Control.size, ENEMY_SPELL_NAME_BG)


func _update_capture_text() -> void:
	if not _announce_label or not is_instance_valid(_announce_label) or not _boss:
		return
	var pid := _boss.get_phase_id()
	if not pid:
		return
	var book: SpellRecordBook = SaveData.spell_book
	var rec: SpellRecord = book.get_record(pid.stage_id, pid.phase_index, pid.boss_index, pid.character, pid.difficulty)
	if rec:
		if PracticeSession.is_practice_mode:
			_announce_label.set_capture_text("%02d/%02d" % [rec.practice_captures, rec.practice_attempts])
		else:
			_announce_label.set_capture_text("%02d/%02d" % [rec.captures, rec.attempts])

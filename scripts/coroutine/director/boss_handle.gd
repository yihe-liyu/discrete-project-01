class_name BossHandle
extends RefCounted
## 关内 Boss 的命名句柄 —— 内容层的"Boss 场景动词"。
## 绑定一个命名槽位（StageObjects 的 key）+ 对应 BossData，内容用动词操控它，
## 不直接碰注册表 / Boss 内部 / create_tween。
## 动词时序无关：可单独调用（符卡练习），也可被 Timeline 摆放。
##
## 注意：name 会遮蔽 Node.name，故句柄侧用 key 而非 name 做槽位键。

var data: BossData

var _key: String
var _hide_name: String = "？？？"
## 命名槽位注册表（由 StageDirector 注入其 ctx.objects；为空则 resolve 恒 null）
var _stage_objects: StageObjects

func _init(p_key: String, p_data: BossData, p_hide: String = "？？？", p_objects: StageObjects = null) -> void:
	_key = p_key
	data = p_data
	_hide_name = p_hide
	_stage_objects = p_objects

## 从命名槽位解析当前 Boss（未注册/已亡 → null）
func resolve() -> Boss:
	if _stage_objects == null:
		return null
	return _stage_objects.resolve_as(_key, Boss)

## Boss 是否已在场上
func exists() -> bool:
	return resolve() != null

## 揭真名：改名 + 亮出名字节点（BossUI 订阅同步）。
func reveal(name: String) -> BossHandle:
	var boss := resolve()
	if boss:
		boss.hud.set_name(name)
		boss.hud.set_name_shown(true)
	else:
		push_warning("BossHandle.reveal: 槽位 '%s' 无 Boss" % _key)
	return self


## 只改显示名（不动名字节点显隐；要连显隐一起亮用 reveal）。
func set_name(name: String) -> BossHandle:
	var boss := resolve()
	if boss:
		boss.hud.set_name(name)
	return self


## 只亮出名字节点（不改名）—— 名字节点默认隐藏，需要单独亮时用。
func show_name() -> BossHandle:
	var boss := resolve()
	if boss:
		boss.hud.set_name_shown(true)
	return self


## 亮出阶段进度点（默认隐藏，手动控制）。
func show_phase_dots() -> BossHandle:
	var boss := resolve()
	if boss:
		boss.hud.set_phase_dots_shown(true)
	return self


## 收起阶段进度点。
func hide_phase_dots() -> BossHandle:
	var boss := resolve()
	if boss:
		boss.hud.set_phase_dots_shown(false)
	return self

## 隐藏真名（战前开局用）
func hide_name() -> BossHandle:
	var boss := resolve()
	if boss:
		boss.hud.set_name(_hide_name)
		boss.hud.set_name_shown(false)
	return self

## 进场：移动到 to（起点已由 spawn 设好，重设 from 幂等无害）
func enter(to: Vector2, from: Vector2, dur: float = 1.5) -> BossHandle:
	var boss := resolve()
	if not boss:
		return self
	boss.global_position = from
	var tw := boss.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(boss, "global_position", to, dur)
	return self

## 进入阶段。idle_only=true 时只在未开战才进入（对话 boss_fight 用，防重入）。
## 按**当前难度**取阶段表：各难度列同形、同槽可换卡 —— 只看 phases_normal 会让
## 难度专属符卡串味（与 stage01.gd / boss_ui.gd 的 phases_for_difficulty 保持一致）。
func phase(index: int = 0, idle_only: bool = false) -> BossHandle:
	var boss := resolve()
	if not boss:
		return self
	if idle_only and boss.current_phase() != null:
		return self
	if data == null:
		push_warning("BossHandle.phase: 槽位 '%s' 无 BossData" % _key)
		return self
	var phases := data.phases_for_difficulty(SaveData.selected_difficulty)
	if index < 0 or index >= phases.size():
		push_warning("BossHandle.phase: 槽位 '%s' 的 %s 难度只有 %d 个阶段，要求第 %d 个" % [
			_key, BossData.difficulty_name(SaveData.selected_difficulty), phases.size(), index])
		return self
	boss.start_phase(phases[index])
	return self

## 退场：受控退出 + 仆街 + 飞出，播完清 ref（外部停 _process，指示器跟随照常）
func retreat(to: Vector2, dur: float = 2.0) -> BossHandle:
	var boss := resolve()
	if not boss:
		return self
	boss.set_exit_controlled()
	boss.die()
	var tw := boss.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(boss, "global_position", to, dur)
	tw.tween_callback(boss.queue_free)
	return self


## **全破**：被打死（区别于 `retreat` = 没打死的退场/逃走）。
## = 播全破演出（`Boss.play_defeat`：定格/清弹/冲击环/爆点/震屏/音效/闪白）+ `die()` + 退场 tween + 回收。
## 时机由内容摆（典型：`sequence_phases` 打完后 `wait(2.0).do(func(): handle.defeat())`）。
func defeat(to: Vector2 = Vector2(GameConfig.FIELD_CENTER_X, -150.0), dur: float = 1.4) -> BossHandle:
	var boss := resolve()
	if not boss:
		return self
	boss.set_exit_controlled()
	boss.play_defeat()
	boss.die()
	var tw := boss.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(boss, "global_position", to, dur)
	tw.tween_callback(boss.queue_free)
	return self

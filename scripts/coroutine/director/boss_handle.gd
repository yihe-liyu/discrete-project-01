class_name BossHandle
extends RefCounted
## 关内 Boss 的命名句柄 —— 内容层的"Boss 场景动词"。
## 绑定一个命名槽位（StageObjects 的 key）+ 对应 BossData，内容用动词操控它，
## 不直接碰 StageObjects / Boss 内部 / create_tween。
## 动词时序无关：可单独调用（符卡练习），也可被 Timeline 摆放。
##
## 注意：name 会遮蔽 Node.name，故句柄侧用 key 而非 name 做槽位键。

var _key: String
var data: BossData
var _hide_name: String = "？？？"

func _init(p_key: String, p_data: BossData, p_hide: String = "？？？") -> void:
	_key = p_key
	data = p_data
	_hide_name = p_hide

## 从命名槽位解析当前 Boss（未注册/已亡 → null）
func resolve() -> Boss:
	return StageObjects.resolve_as(_key, Boss)

## Boss 是否已在场上
func exists() -> bool:
	return resolve() != null

## 揭真名（发 display_name_changed，BossUI 订阅同步）
func reveal(name: String) -> BossHandle:
	var b := resolve()
	if b:
		b.set_boss_name(name)
	else:
		push_warning("BossHandle.reveal: 槽位 '%s' 无 Boss" % _key)
	return self

## 隐藏真名（战前开局用）
func hide_name() -> BossHandle:
	var b := resolve()
	if b:
		b.set_boss_name(_hide_name)
	return self

## 进场：移动到 to（起点已由 spawn 设好，重设 from 幂等无害）
func enter(to: Vector2, from: Vector2, dur: float = 1.5) -> BossHandle:
	var b := resolve()
	if not b:
		return self
	b.global_position = from
	var tw := b.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "global_position", to, dur)
	return self

## 进入阶段。idle_only=true 时只在未开战才进入（对话 boss_fight 用，防重入）
func phase(index: int = 0, idle_only: bool = false) -> BossHandle:
	var b := resolve()
	if not b:
		return self
	if idle_only and b.current_phase() != null:
		return self
	if data == null:
		push_warning("BossHandle.phase: 槽位 '%s' 无 BossData" % _key)
		return self
	if index < 0 or index >= data.phases.size():
		push_warning("BossHandle.phase: 槽位 '%s' 的 BossData 只有 %d 个阶段，要求第 %d 个" % [_key, data.phases.size(), index])
		return self
	b.start_phase(data.phases[index])
	return self

## 退场：受控退出 + 仆街 + 飞出，播完清 ref（外部停 _process，指示器跟随照常）
func retreat(to: Vector2, dur: float = 2.0) -> BossHandle:
	var b := resolve()
	if not b:
		return self
	b.set_exit_controlled()
	b.die()
	var tw := b.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "global_position", to, dur)
	tw.tween_callback(b.queue_free)
	return self

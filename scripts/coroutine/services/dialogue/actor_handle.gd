class_name ActorHandle
extends RefCounted
## 对话里**某个角色**的"场景动词"句柄 —— 由 `DialogueSteps.enter()` 返回。
##
## 与 `BossHandle` 同一路子（"谁"是**接收者**而不是参数），但更简单：
## 它只在**构建期写步骤**、不做运行时解析 —— 播放器仍按 `char_name` 查 actor，
## 步骤载荷一个字段都没变（见 `test_stage_ops_take_profile_and_store_actor_key`）。
##
## 用法：
##   var reimu := d.enter(REIMU, Vector2(50, 230))
##   reimu.line("啊，什么线索都没有…")
##   var ka := d.enter(KA, Vector2(550, 230))
##   ka.line("哦呀，弱小的人类怎么会在永夜出门？").portrait("耍帅").move(Vector2(500, 230), 0.6)
##   ka.exit()
##
## 动词一律返回 `self`（可链式），全部落到同一个 actor key。
## 与 `d` 上那些"收 profile 的动词"的关系：**薄委托**（`_dialogue_steps.portrait(_character_profile, …)`），
## 没有第二套构建逻辑 —— 所以两种写法产物完全一致（可混用）。

var _dialogue_steps: DialogueSteps
var _character_profile: CharacterProfile
var _exited: bool = false
var _warned_after_exit: bool = false


func _init(p_d: DialogueSteps, p_profile: CharacterProfile) -> void:
	_dialogue_steps = p_d
	_character_profile = p_profile


## 该句柄对应的角色档案（只读）
var profile: CharacterProfile:
	get: return _character_profile


## 是否已 `exit()`（退场后再调度动词 = 剧本顺序多半写错了）
func is_exited() -> bool:
	return _exited


## 说一句（等价于 `d.say(profile, text, opts)`）；`opts.emotion` 换表情、`opts.auto_advance` 自动推进
func line(text: String, opts: Dictionary = {}) -> ActorHandle:
	_warn_if_exited()
	_dialogue_steps.say(_character_profile, text, opts)
	return self


## 移动立绘（`duration` = 0 立即到位）
func move(pos: Vector2, duration: float = 0.0) -> ActorHandle:
	_warn_if_exited()
	_dialogue_steps.move(_character_profile, pos, duration)
	return self


## 水平翻转（默认翻到朝左）
func flip(flipped: bool = true) -> ActorHandle:
	_warn_if_exited()
	_dialogue_steps.flip(_character_profile, flipped)
	return self


## 手动明暗（0~1）
func dim(value: float) -> ActorHandle:
	_warn_if_exited()
	_dialogue_steps.dim(_character_profile, value)
	return self


## 换表情（立绘 key）
func portrait(emotion_key: String) -> ActorHandle:
	_warn_if_exited()
	_dialogue_steps.portrait(_character_profile, emotion_key)
	return self


## 调气泡偏移
func bubble(offset: Vector2) -> ActorHandle:
	_warn_if_exited()
	_dialogue_steps.bubble(_character_profile, offset)
	return self


## 退场（`actor.visible = false`）。之后再用本句柄只告警一次、不拦步骤。
func exit() -> ActorHandle:
	_warn_if_exited()
	_dialogue_steps.exit(_character_profile)
	_exited = true
	return self


## 退场后再调度动词 → 告警一次（不拦、不抛，剧本仍能跑完）
func _warn_if_exited() -> void:
	if _exited and not _warned_after_exit:
		_warned_after_exit = true
		push_warning("ActorHandle(%s): 已 exit() 之后又调度了动词（剧本顺序写错了？）" % _character_profile.char_name)

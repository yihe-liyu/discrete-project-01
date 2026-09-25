extends RefCounted
## 测试夹具工厂 —— 让**机制测试**不必绑真实内容（契约见 `docs/TEST_INDEX.md`「内容绑定契约」）。
##
## 判据：**测试对内容的依赖，应等于它要验证的内容属性。**
## 机制测试 → 用本工厂自建；内容校验 / 内容形状 → 仍绑真实内容（那正是它的价值）。
##
## 无 `class_name`（新增全局类要 `--import` 重建缓存）—— 使用方 `preload` 本文件。

## 通用替身脚本（都 `extends CoroutineScript`）：可当 enemy behavior / move / shoot 槽。
const SCRIPT_A := preload("res://test/fixtures/no_port_behavior.gd")
const SCRIPT_B := preload("res://test/fixtures/lifecycle_port_behavior.gd")
## 机体射击脚本夹具：**必须** `extends PlayerShootScript`（`Player` 里有 assert 卡这个类型）。
const PLAYER_SHOOT := preload("res://test/fixtures/player_shoot_probe.gd")


## 夹具 SpriteFrames：`Player.change_state` 会 `play(idle/lefting/left/righting/right)`，
## 没有 frames 会报 `Condition "frames.is_null()" is true`（引擎错误 → GUT 判失败）。
static func player_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var tex := PlaceholderTexture2D.new()
	tex.size = Vector2(32, 48)
	for anim in [&"idle", &"lefting", &"left", &"righting", &"right"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 8.0)
		sf.add_frame(anim, tex)
	return sf


## 夹具 PlayerData：速度合法 + 挂一个**真能 `new`** 的 `PlayerShootScript`（`Player.reinit_shoot` 会 new 它）
## + 一套最小 SpriteFrames（状态机要 play 动画名）。
## `bomb` 留空 —— 只测移动 / 换机体 / 碰撞的用例不需要它。
static func player_data(normal_speed: int = 6, focus_speed: int = 2, shoot: Script = PLAYER_SHOOT) -> PlayerData:
	var pd := PlayerData.new()
	pd.normal_speed = normal_speed
	pd.focus_speed = focus_speed
	pd.shoot_script = shoot
	pd.animation = player_sprite_frames()
	return pd


## 夹具 EffectType：带一张 16×16 占位贴图（渲染分组要 `get_size()`），时长/缩放/透明度可指定。
static func effect(duration: float = 0.2, scale_from: float = 2.0, scale_to: float = 1.0,
		alpha_from: float = 1.0, alpha_to: float = 0.0) -> EffectType:
	var fx := EffectType.new()
	var tex := PlaceholderTexture2D.new()
	tex.size = Vector2(16, 16)
	fx.texture = tex
	fx.duration = duration
	fx.scale_from = scale_from
	fx.scale_to = scale_to
	fx.alpha_from = alpha_from
	fx.alpha_to = alpha_to
	return fx

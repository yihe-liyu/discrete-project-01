## 灵梦射击：主弹 + 子机编队（power 阈值 / 数量 / 偏移）。
extends PlayerShootScript
class_name ReimuShoot

const OPTION_VISUAL = preload("res://scripts/coroutine/player/reimu_option_visual.gd")

const MAIN_INTERVAL: int = 3

## 复用弹型实例（内核弹型缓存在 SpawnSpec 实例上，禁止每发 new）
var _main_bullet: SpawnSpec
var _focus_bullet: SpawnSpec
var _spread_bullet: SpawnSpec


func _option_setup() -> Dictionary:
	return {
		visual_script = OPTION_VISUAL,
		power_thresholds = [0, 100, 200, 300],
		counts = [1, 2, 3, 4],
		offsets_focus = [
			[Vector2(0, 60)],
			[Vector2(-10, 60), Vector2(10, 60)],
			[Vector2(-20, 60), Vector2(0, 60), Vector2(20, 60)],
			[Vector2(-30, 60), Vector2(-10, 60), Vector2(10, 60), Vector2(30, 60)],
		],
		offsets_spread = [
			[Vector2(0, -80)],
			[Vector2(-40, -80), Vector2(40, -80)],
			[Vector2(-40, -60), Vector2(0, -80), Vector2(40, -60)],
			[Vector2(-60, -60), Vector2(-20, -80), Vector2(20, -80), Vector2(60, -60)],
		],
	}


func _main_shoot(_ctx: StageContext, player: Player) -> float:
	if _main_bullet == null:
		_main_bullet = SpawnSpec.new().tex("reimu_main").blend(false).speed(4000).player()
		_main_bullet.color(Color(1, 1, 1, 0.5))
		_main_bullet.damage = 6
		_main_bullet.hit_effect = preload("res://scenes/effect/hit_effect_reimu.tscn")
	ctx.bullets.shoot_spread(_main_bullet, 1, 0.0, Vector2.UP, player.global_position + Vector2(-20, 0))
	ctx.bullets.shoot_spread(_main_bullet, 1, 0.0, Vector2.UP, player.global_position + Vector2(20, 0))
	return ctx.clock.wait_frames(MAIN_INTERVAL)


func _option_shoot(_ctx: StageContext, _count: int) -> float:
	if PlayerInput.is_action_pressed("focus"):
		if _focus_bullet == null:
			_focus_bullet = SpawnSpec.new().tex("reimu_opt2").blend(false).speed(5000).player()
			_focus_bullet.color(Color(1, 1, 1, 0.5))
			_focus_bullet.damage = 1.4
			_focus_bullet.hit_effect = preload("res://scenes/effect/hit_effect_reimu_option02.tscn")
		_shoot_options(ctx, _focus_bullet, 1, 0.0, Vector2.UP, Vector2(-7, 0))
		_shoot_options(ctx, _focus_bullet, 1, 0.0, Vector2.UP, Vector2(7, 0))
		return ctx.clock.wait_frames(4)
	else:
		if _spread_bullet == null:
			_spread_bullet = SpawnSpec.new().tex("reimu_opt1").blend(false).speed(1000).player()
			_spread_bullet.color(Color(1, 1, 1, 0.5))
			_spread_bullet.damage = 3.5
			_spread_bullet.hit_effect = preload("res://scenes/effect/hit_effect_reimu_option01.tscn")
			_spread_bullet.with_behavior(BulletBehaviors.homing(
				500.0, deg_to_rad(720.0),
				BulletBehaviors.HOMING_NEAREST_ENEMY,
				2000.0, 2.0, 2.0, 150.0, 2.0))
		_shoot_options(ctx, _spread_bullet, 1, 0.0, Vector2.UP, Vector2.ZERO)
		return ctx.clock.wait_frames(6)

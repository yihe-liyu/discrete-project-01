extends PlayerShootScript
class_name ReimuShoot

const OPTION_VISUAL = preload("res://scripts/coroutine/player/reimu_option_visual.gd")

const MAIN_INTERVAL: int = 3

## 复用弹型实例（M2：内核弹型缓存在 BulletData 实例上，禁止每发 new）
var _main_bullet_data: BulletData
var _focus_bullet_data: BulletData
var _spread_bullet_data: BulletData


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
	if _main_bullet_data == null:
		_main_bullet_data = BulletData.new().tex("reimu_main").speed(4000).player()
		_main_bullet_data.color(Color(1, 1, 1, 0.5))
		_main_bullet_data.damage = 6
		_main_bullet_data.hit_effect = preload("res://scenes/effect/hit_effect_reimu.tscn")
	ctx.bullets.shoot_spread(_main_bullet_data, 1, 0.0, Vector2.UP, player.global_position + Vector2(-20, 0))
	ctx.bullets.shoot_spread(_main_bullet_data, 1, 0.0, Vector2.UP, player.global_position + Vector2(20, 0))
	return ctx.clock.wait_frames(MAIN_INTERVAL)


func _option_shoot(_ctx: StageContext, _count: int) -> float:
	if Input.is_action_pressed("focus"):
		if _focus_bullet_data == null:
			_focus_bullet_data = BulletData.new().tex("reimu_opt2").speed(5000).player()
			_focus_bullet_data.color(Color(1, 1, 1, 0.5))
			_focus_bullet_data.damage = 1.4
			_focus_bullet_data.hit_effect = preload("res://scenes/effect/hit_effect_reimu_option02.tscn")
		_shoot_options(ctx, _focus_bullet_data, 1, 0.0, Vector2.UP, Vector2(-7, 0))
		_shoot_options(ctx, _focus_bullet_data, 1, 0.0, Vector2.UP, Vector2(7, 0))
		return ctx.clock.wait_frames(4)
	else:
		if _spread_bullet_data == null:
			_spread_bullet_data = BulletData.new().tex("reimu_opt1").speed(1000).player()
			_spread_bullet_data.color(Color(1, 1, 1, 0.5))
			_spread_bullet_data.damage = 3.5
			_spread_bullet_data.hit_effect = preload("res://scenes/effect/hit_effect_reimu_option01.tscn")
			_spread_bullet_data.trajectory(BulletLifecycle.homing())
		_shoot_options(ctx, _spread_bullet_data, 1, 0.0, Vector2.UP, Vector2.ZERO)
		return ctx.clock.wait_frames(6)

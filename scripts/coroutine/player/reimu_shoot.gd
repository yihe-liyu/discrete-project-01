## 灵梦射击：主弹 + 子机编队（power 阈值 / 数量 / 偏移）。
extends PlayerShootScript
class_name ReimuShoot

const OPTION_VISUAL = preload("res://scripts/coroutine/player/reimu_option_visual.gd")

const MAIN_INTERVAL: int = 3

## 复用弹型实例（内核弹型缓存在 SpawnSpec 实例上，禁止每发 new）
var main_spawn_spec: SpawnSpec
var focus_spawn_spec: SpawnSpec
var spread_spawn_spec: SpawnSpec


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
	if main_spawn_spec == null:
		main_spawn_spec = SpawnSpec.new().tex("reimu_main").blend(false).speed(4000).player()
		main_spawn_spec.color(Color(1, 1, 1, 0.5))
		main_spawn_spec.damage = 6
		main_spawn_spec.hit_effect = preload("res://scenes/effect/hit_effect_reimu.tscn")
	ctx.bullets.shoot_spread(main_spawn_spec, 1, 0.0, Vector2.UP, player.global_position + Vector2(-20, 0))
	ctx.bullets.shoot_spread(main_spawn_spec, 1, 0.0, Vector2.UP, player.global_position + Vector2(20, 0))
	return ctx.clock.wait_frames(MAIN_INTERVAL)


func _option_shoot(_ctx: StageContext, _count: int) -> float:
	if PlayerInput.is_action_pressed("focus"):
		if focus_spawn_spec == null:
			focus_spawn_spec = SpawnSpec.new().tex("reimu_opt2").blend(false).speed(5000).player()
			focus_spawn_spec.color(Color(1, 1, 1, 0.5))
			focus_spawn_spec.damage = 1.4
			focus_spawn_spec.hit_effect = preload("res://scenes/effect/hit_effect_reimu_option02.tscn")
		_shoot_options(ctx, focus_spawn_spec, 1, 0.0, Vector2.UP, Vector2(-7, 0))
		_shoot_options(ctx, focus_spawn_spec, 1, 0.0, Vector2.UP, Vector2(7, 0))
		return ctx.clock.wait_frames(4)
	else:
		if spread_spawn_spec == null:
			spread_spawn_spec = SpawnSpec.new().tex("reimu_opt1").blend(false).speed(1000).player()
			spread_spawn_spec.color(Color(1, 1, 1, 0.5))
			spread_spawn_spec.damage = 3.5
			spread_spawn_spec.hit_effect = preload("res://scenes/effect/hit_effect_reimu_option01.tscn")
			spread_spawn_spec.with_behavior(BulletBehaviors.homing(
				500.0, deg_to_rad(720.0),
				BulletBehaviors.HOMING_NEAREST_ENEMY,
				2000.0, 2.0, 2.0, 150.0, 2.0))
		_shoot_options(ctx, spread_spawn_spec, 1, 0.0, Vector2.UP, Vector2.ZERO)
		return ctx.clock.wait_frames(6)

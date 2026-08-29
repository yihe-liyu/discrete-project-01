extends PlayerShootScript
class_name MarisaShoot

const OPTION_VISUAL = preload("res://scripts/coroutine/player/ov_marisa.gd")
const LASER_FOLLOW = preload("res://scripts/coroutine/player/marisa_laser_follow.gd")
## 激光贴图：从注册器取（与 bullet_configs marisa_opt1 同源）
var LASER_TEX: Texture2D = AssetRegistry.get_bullet_tex("marisa_opt1")

const MAIN_INTERVAL: int = 3
const OPTION_INTERVAL: int = 6

## 非 focus 分段激光参数
const SEG_W: float = 64.0              # 每段宽度 —— 唯一需要调的参数！
const SEG_H: float = 32.0              # 每段高度（贴图高度，判定贴视觉）
const LASER_FRAME: int = 0             # 所有段公用这一帧（0~段数-1，同图案均匀重复）
const LASER_DAMAGE: float = 1.2           # 每段伤害（支持小数，累积到整才扣血）
const LASER_DRIFT_SPEED: float = 2000.0    # 激光流动速度（px/s）
const LASER_SPACING_OVERLAP: float = 0.85  # 段间距 = 段宽 × 0.85（轻微重叠→遮住图案边缘空隙）
## 频率自动跟随速度：每漂移一个间距喷一段，任何速度都无缝
## 各 power 等级下每道激光的发射角度（度：0=垂直向上，正=右偏，负=左偏）
## 外层索引 = power 等级（0..3），内层 = 子机索引（0,1,2...）—— 按你的设计填！
const LASER_ANGLES := [
	[0.0],                     # power 0   （1 子机）
	[0.0, 0.0],                # power 100 （2 子机）
	[-8.0, 0.0, 8.0],          # power 200 （3 子机）
	[-8.0, 0.0, 0.0, 8.0],     # power 300 （4 子机）
]

var _spawn_accumulator: float = 0.0       # 漂移累积量（达到间距即喷一段）
var _laser_frame_seq: int = 0             # 帧序列（每轮喷射 +1 → 图案随时间变换）
var _segments: int = -1                   # 段数缓存（由图集自动算）
var _segment_textures: Array[AtlasTexture] = []  # 切片缓存（省每段 new）


func _seg_count() -> int:
	if _segments < 0:
		_segments = maxi(1, int(LASER_TEX.get_size().x / SEG_W))
	return _segments


func _option_setup() -> Dictionary:
	return {
		visual_script = OPTION_VISUAL,
		power_thresholds = [0, 100, 200, 300],
		counts = [1, 2, 3, 4],
		offsets_focus = [
			[Vector2(0, -40)],
			[Vector2(-10, -40), Vector2(10, -40)],
			[Vector2(-20, -30), Vector2(0, -40), Vector2(20, -30)],
			[Vector2(-30, -30), Vector2(-10, -40), Vector2(10, -40), Vector2(30, -30)],
		],
		offsets_spread = [
			[Vector2(0, -80)],
			[Vector2(-40, -80), Vector2(40, -80)],
			[Vector2(-40, -60), Vector2(0, -80), Vector2(40, -60)],
			[Vector2(-60, -60), Vector2(-20, -80), Vector2(20, -80), Vector2(60, -60)],
		],
	}


func _main_shoot(_ctx: StageContext, player: Player) -> float:
	var b := BulletData.new().tex("marisa_main").speed(4000).player()
	b.color(Color(1, 1, 1, 0.5))
	b.damage = 6
	b.hit_effect = preload("res://scenes/effect/hit_effect_marisa.tscn")
	ctx.bullets.shoot_spread(b, 1, 0.0, Vector2.UP, player.global_position + Vector2(-15, 0))
	ctx.bullets.shoot_spread(b, 1, 0.0, Vector2.UP, player.global_position + Vector2(15, 0))
	return ctx.clock.wait_frames(MAIN_INTERVAL)


func _option_shoot(_ctx: StageContext, _count: int) -> float:
	if Input.is_action_pressed("focus"):
		# focus：竖直向上匀加速星弹（初速 + 加速度，每秒加速 —— 数值可调）
		var b: BulletData = BulletData.new().tex("marisa_opt2").speed(1500).accelerate(0, -5000).player()
		b.color(Color(1, 1, 1, 0.5))
		b.damage = 4
		b.hit_sfx = "marisa_damage"  # focus 弹命中用专属音效
		b.hit_effect = preload("res://scenes/effect/hit_effect_marisa_option02.tscn")
		_shoot_options(ctx, b, 1, 0.0, Vector2.UP, Vector2.ZERO)
		ctx.audio.play_sfx(AssetRegistry.sounds["msl"], -8.0)
		return ctx.clock.wait_frames(5)
	else:
		# 非 focus：流水激光（按间距喷段，频率自动跟随漂移速度 → 任何速度都无缝）
		var player: Player = ctx.player.get_player()
		if not is_instance_valid(player):
			return ctx.clock.wait_frames(OPTION_INTERVAL)
		var dt := get_dt()
		_spawn_accumulator += LASER_DRIFT_SPEED * dt
		var spacing: float = SEG_W * LASER_SPACING_OVERLAP
		while _spawn_accumulator >= spacing:
			_spawn_accumulator -= spacing
			# 本轮所有子机共用同一帧（4 道激光同步），轮间帧变换
			var frame: int = (_laser_frame_seq + LASER_FRAME) % _seg_count()
			_laser_frame_seq += 1
			if _options.size() > 0:
				for opt in _options:
					_spawn_laser_segment(player, opt, frame)
			else:
				_spawn_laser_segment(player, null, frame)
		return dt  # 每帧都调用，驱动累积


## 把长贴图切成第 i 段（AtlasTexture 切片）—— 切片缓存复用（省每段 new）
func _make_laser_segment(i: int) -> AtlasTexture:
	if _segment_textures.is_empty():
		for s in _seg_count():
			var at := AtlasTexture.new()
			at.atlas = LASER_TEX
			at.region = Rect2(s * SEG_W, 0, SEG_W, SEG_H)
			_segment_textures.append(at)
	return _segment_textures[i % _seg_count()]


## 从指定子机喷出一段激光：段在发射口生成，向上漂移，间距=漂移×间隔（自动无缝）
func _spawn_laser_segment(player: Player, source: Node2D, frame: int) -> void:
	# 发射口 = 指定子机（无效时回退自机）
	if source == null or not is_instance_valid(source):
		source = player

	# 本轮共享帧：同轮所有子机图案一致，轮间变换 → 整齐且流动
	var seg := _make_laser_segment(frame % _seg_count())
	var b := BulletData.new().player()
	b.texture = seg
	b.color(Color(1, 1, 1, 0.5))
	b.damage = LASER_DAMAGE
	b.hit_effect = preload("res://scenes/effect/hit_effect_marisa_option01.tscn")  # 激光专用击中特效
	# 矩形判定覆盖整段（贴视觉：64x32，旋转后 32x64 竖条）
	b.hitbox_shape = BulletData.HitboxShape.RECTANGLE
	b.hitbox_size = Vector2(SEG_W, SEG_H)
	b.coroutine_script = LASER_FOLLOW

	# 段在发射口生成（offset=0），drift 从 0 独立累积 → 根部永远在子机
	var bullet := ctx.bullets.shoot_spread(b, 1, 0.0, Vector2.UP, source.global_position)
	if bullet:
		# 按火力 + 子机索引查发射角度（LASER_ANGLES 表）
		var opt_idx: int = _options.find(source)
		if opt_idx < 0:
			opt_idx = 0
		var lv: int = clampi(_options.size() - 1, 0, LASER_ANGLES.size() - 1)
		var angles: Array = LASER_ANGLES[lv]
		var angle_rad: float = deg_to_rad(angles[opt_idx] if opt_idx < angles.size() else 0.0)
		# 贴图旋转 = 基础竖过来（-90°）+ 发射角度 → 贴图朝向 = 漂移方向
		bullet.rotation = -PI / 2.0 + angle_rad
		bullet.extra["anchor_node"] = source
		bullet.extra["laser_offset"] = Vector2.ZERO
		bullet.extra["drift_speed"] = LASER_DRIFT_SPEED
		bullet.extra["drift_angle"] = angle_rad

## 魔理沙射击：主弹 + 子机分段激光；覆写 option 装配与激光参数。
extends PlayerShootScript
class_name MarisaShoot

const OPTION_VISUAL = preload("res://scripts/coroutine/player/marisa_option_visual.gd")
## 激光条 = 图集合体格 [code]魔理沙子机高速弹[/code]（512×32，8 段 ×64）；切片直接取自原始图集。
const LASER_SHAPE := &"魔理沙子机高速弹"

const MAIN_INTERVAL: int = 3
const OPTION_INTERVAL: int = 6

## 非 focus 分段激光参数
const SEG_W: float = 64.0              # 每段宽度 —— 唯一需要调的参数！
const SEG_H: float = 32.0              # 每段高度（贴图高度，判定贴视觉）
const LASER_FRAME: int = 0             # 所有段公用这一帧（0~段数-1，同图案均匀重复）
const LASER_DAMAGE: float = 1.2           # 每段伤害（支持小数，累积到整才扣血）
const LASER_DRIFT_SPEED: float = 2000.0    # 激光流动速度（px/s）
const LASER_SPACING_OVERLAP: float = 0.85  # 段间距 = 段宽 × 0.85（轻微重叠→遮住图案边缘空隙）
## 首帧也要移动：出生位置和 anchor_drift 初始位移都先走一小步，避免原地停一帧。
const LASER_FIRST_STEP: float = LASER_DRIFT_SPEED / 60.0
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

## 复用弹型实例（内核弹型缓存在 SpawnSpec 实例上，禁止每发 new）
var _main_bullet: SpawnSpec
var _focus_bullet: SpawnSpec
var _laser_bullets: Array[SpawnSpec] = []
## 子机的稳定锚点：不直接引用会被重建/释放的 Option 节点。
## 每帧把锚点移到对应子机的 global_position；激光锚点 id 永远有效。
var _laser_anchors: Array[Node2D] = []


func _ready() -> void:
	# 子机锚点必须在弹幕 behavior 之前更新；默认 0 会晚一帧。
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	if ctx != null:
		var player: Player = ctx.player.get_player()
		if is_instance_valid(player):
			_sync_laser_anchors(player)
	# 不能吞掉 CoroutineRunner 的 tick，否则射击状态机/子机同步全停。
	super._physics_process(_delta)


func _seg_count() -> int:
	if _segments < 0:
		_segments = maxi(1, int(BulletShapes.pixel_rect(LASER_SHAPE).size.x / SEG_W))
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


func _cleanup_options() -> void:
	super._cleanup_options()
	for anchor in _laser_anchors:
		if is_instance_valid(anchor):
			anchor.queue_free()
	_laser_anchors.clear()


func _main_shoot(_ctx: StageContext, player: Player) -> float:
	if _main_bullet == null:
		_main_bullet = SpawnSpec.new().tex("marisa_main").blend(false).speed(4000).player()
		_main_bullet.color(Color(1, 1, 1, 0.5))
		_main_bullet.damage = 6
		_main_bullet.hit_effect = preload("res://scenes/effect/hit_effect_marisa.tscn")
	ctx.bullets.shoot_spread(_main_bullet, 1, 0.0, Vector2.UP, player.global_position + Vector2(-15, 0))
	ctx.bullets.shoot_spread(_main_bullet, 1, 0.0, Vector2.UP, player.global_position + Vector2(15, 0))
	return ctx.clock.wait_frames(MAIN_INTERVAL)


func _option_shoot(_ctx: StageContext, _count: int) -> float:
	if Input.is_action_pressed("focus"):
		# focus：竖直向上匀加速星弹（初速 + 加速度，每秒加速 —— 数值可调）
		if _focus_bullet == null:
			_focus_bullet = SpawnSpec.new().tex("marisa_opt2").blend(false).speed(1500).with_behavior(
				BulletBehaviors.accel(Vector2(0, -5000))).player()
			_focus_bullet.color(Color(1, 1, 1, 0.5))
			_focus_bullet.damage = 4
			_focus_bullet.hit_sfx = "marisa_damage"  # focus 弹命中用专属音效
			_focus_bullet.hit_effect = preload("res://scenes/effect/hit_effect_marisa_option02.tscn")
		_shoot_options(ctx, _focus_bullet, 1, 0.0, Vector2.UP, Vector2.ZERO)
		ctx.audio.play_sfx(AssetRegistry.sounds["msl"])
		return ctx.clock.wait_frames(5)
	else:
		# 非 focus：流水激光（按间距喷段，频率自动跟随漂移速度 → 任何速度都无缝）
		var player: Player = ctx.player.get_player()
		if not is_instance_valid(player):
			return ctx.clock.wait_frames(OPTION_INTERVAL)
		_sync_laser_anchors(player)
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
		for segment in _seg_count():
			var at := AtlasTexture.new()
			at.atlas = BulletShapes.BULLET_ATLAS_TEXTURE
			at.region = Rect2(BulletShapes.pixel_rect(LASER_SHAPE).position + Vector2(segment * SEG_W, 0.0), Vector2(SEG_W, SEG_H))
			_segment_textures.append(at)
	return _segment_textures[i % _seg_count()]


## 子机锚点：每个子机槽一个持久 Marker2D，每帧跟随子机位置。
## 激光只持有 Marker 的 id；子机节点被重建也不会让 id 失效。
func _sync_laser_anchors(player: Player) -> void:
	while _laser_anchors.size() < _options.size():
		var anchor := Node2D.new()
		anchor.name = "LaserAnchor_%d" % _laser_anchors.size()
		player.add_child(anchor)
		_laser_anchors.append(anchor)
	for i in _options.size():
		if is_instance_valid(_options[i]) and is_instance_valid(_laser_anchors[i]):
			_laser_anchors[i].global_position = _options[i].global_position
	# 不主动删旧槽 Marker：子机减少时旧激光可能还持有它的 id。
	# 留着空 Marker 成本可忽略；下次数量增加直接复用，清理时统一释放。


## 激光段锚点：优先用对应子机槽的稳定 Marker；无子机时退回自机。
func _laser_anchor(player: Player, source: Node2D) -> Dictionary:
	var anchor: Node2D = player
	var index := _options.find(source)
	if index >= 0 and index < _laser_anchors.size() and is_instance_valid(_laser_anchors[index]):
		anchor = _laser_anchors[index]
	return {&"id": anchor.get_instance_id(), &"offset": Vector2.ZERO, &"use_global": true}


## 段弹型：按帧缓存（同一帧复用同一 SpawnSpec 实例 → 内核弹型表不随发射增长）。
func _get_laser_bullet(frame: int) -> SpawnSpec:
	var i: int = frame % _seg_count()
	while _laser_bullets.size() < _seg_count():
		var k: int = _laser_bullets.size()
		var spec := SpawnSpec.new().player().blend(false)
		spec.kind = BulletType.Kind.LASER
		spec.texture = _make_laser_segment(k)
		spec.color(Color(1, 1, 1, 0.5))
		spec.damage = LASER_DAMAGE
		spec.hit_effect = preload("res://scenes/effect/hit_effect_marisa_option01.tscn")  # 激光专用击中特效
		# 矩形判定覆盖整段（贴视觉：64x32，旋转后 32x64 竖条）
		spec.hitbox_rect(Vector2(SEG_W, SEG_H))
		_laser_bullets.append(spec)
	return _laser_bullets[i]


## 从指定子机喷出一段激光：段在发射口生成，向上漂移，间距=漂移×间隔（自动无缝）
func _spawn_laser_segment(player: Player, source: Node2D, frame: int) -> void:
	# 发射口 = 指定子机（无效时回退自机）
	if source == null or not is_instance_valid(source):
		source = player

	# 本轮共享帧：同轮所有子机图案一致，轮间变换 → 整齐且流动
	var spec := _get_laser_bullet(frame)

	# 按火力 + 子机索引查发射角度（LASER_ANGLES 表）——旧池/内核共用
	var opt_idx: int = _options.find(source)
	if opt_idx < 0:
		opt_idx = 0
	var lv: int = clampi(_options.size() - 1, 0, LASER_ANGLES.size() - 1)
	var angles: Array = LASER_ANGLES[lv]
	var angle_rad: float = deg_to_rad(angles[opt_idx] if opt_idx < angles.size() else 0.0)

	# 弹道 = 原生 anchor_drift；锚点是 per-shot（位置由宿主每帧解析）
	spec.with_behavior(BulletBehaviors.anchor_drift(
		angle_rad, LASER_DRIFT_SPEED, LASER_FIRST_STEP, true))
	spec.anchor = _laser_anchor(player, source)

	# 出生方向必须就是激光的漂移方向：首帧 behavior 还没跑，
	# follow_dir 先用 velocity 定贴图朝向；若这里传 UP，首帧会竖一下再转。
	var spawn_dir := Vector2(sin(angle_rad), -cos(angle_rad))
	# 第一帧的渲染位置 = 第一次 anchor_drift 写出的位置，避免在子机原点多停一帧。
	var spawn_pos := source.global_position + spawn_dir * LASER_FIRST_STEP
	ctx.bullets.shoot_spread(spec, 1, 0.0, spawn_dir, spawn_pos)

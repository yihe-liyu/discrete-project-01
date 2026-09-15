## KernelMistBomb —— 单贴图分阶段展开的自机 bomb（宿主实体，不走内核池）。
## 锚点跟随自机（可关）；长（贴图 x）先展开 → 保持 → 宽（贴图 y）展开 → 保持 → 淡出。
## 覆盖范围（椭圆，跟当前 scale 走）内清敌弹全程有效；伤敌从 MistBombData.damage_from_stage 起。
extends BombEntity

const Stage = MistBombData.Stage

var _sprite: Sprite2D
var _size := Vector2.ZERO
var _stage: int = Stage.LENGTH
var _stage_t: float = 0.0

var _is_follow: bool = true
var _anchor_offset := Vector2.ZERO
var _length: Vector2 = Vector2(0.0, 1.0)      # 长的 起始→最终（贴图 x 的比例）
var _width: Vector2 = Vector2(0.0, 1.0)       # 宽的 起始→最终（贴图 y 的比例）
var _grow_len: float = 0.35
var _hold_len: float = 0.5
var _grow_wid: float = 0.25
var _hold_wid: float = 0.5
var _fade: float = 0.25
var _damage_from: int = Stage.LENGTH
var _dps: float = 200.0
var _clear_scale: float = 1.0


func setup(p_data: BombData, pos: Vector2, _direction: Vector2, tint: Color = Color.WHITE, _spawn_delay: float = 0.0) -> void:
	global_position = pos
	var d := p_data as MistBombData
	if d == null:
		push_error("[KernelMistBomb] setup 需要 MistBombData")
		return
	data = d
	_is_follow = d.follow_player
	_anchor_offset = d.anchor_offset
	_length = d.length_range
	_width = d.width_range
	_grow_len = maxf(d.grow_length_time, 0.0)
	_hold_len = d.hold_length_time
	_grow_wid = maxf(d.grow_width_time, 0.0)
	_hold_wid = d.hold_width_time
	_fade = maxf(d.fade_time, 0.001)
	_damage_from = int(d.damage_from_stage)
	_dps = d.dps
	_clear_scale = d.clear_scale
	rotation = deg_to_rad(d.rotation_deg)
	_sprite = Sprite2D.new()
	_sprite.texture = d.texture
	_sprite.modulate = tint
	if d.texture != null:
		_size = d.texture.get_size()
		_sprite.offset = _size * (Vector2(0.5, 0.5) - d.pivot_ratio)   # 让"弯曲处"对齐节点原点
	_sprite.scale = Vector2.ZERO
	add_child(_sprite)
	z_index = d.z_index


## 当前展开的"长" / "宽"（贴图对应维的全长；测试/调试用）。
func length_now() -> float:
	return _size.x * _sprite.scale.x


func width_now() -> float:
	return _size.y * _sprite.scale.y


func _physics_process(delta: float) -> void:
	_stage_t += delta
	if _is_follow and entity_registry != null:
		var p = entity_registry.player
		if is_instance_valid(p):
			global_position = p.global_position + _anchor_offset
	match _stage:
		Stage.LENGTH:
			_sprite.scale = Vector2(lerpf(_length.x, _length.y, _k(_grow_len)), _width.x)
			if _stage_t >= _grow_len:
				_advance(Stage.HOLD_L)
		Stage.HOLD_L:
			_sprite.scale = Vector2(_length.y, _width.x)
			if _stage_t >= _hold_len:
				_advance(Stage.WIDTH)
		Stage.WIDTH:
			_sprite.scale = Vector2(_length.y, lerpf(_width.x, _width.y, _k(_grow_wid)))
			if _stage_t >= _grow_wid:
				_advance(Stage.HOLD_W)
		Stage.HOLD_W:
			_sprite.scale = Vector2(_length.y, _width.y)
			if _stage_t >= _hold_wid:
				_advance(Stage.FADE)
		Stage.FADE:
			_sprite.modulate.a = clampf(1.0 - _stage_t / _fade, 0.0, 1.0)
			if _stage_t >= _fade:
				queue_free()
			return
	_damage_and_clear(delta)


func _advance(next_stage: int) -> void:
	_stage = next_stage
	_stage_t = 0.0


func _k(duration: float) -> float:
	return 1.0 if duration <= 0.0 else clampf(_stage_t / duration, 0.0, 1.0)


func _damage_and_clear(delta: float) -> void:
	# 椭圆判定在 bomb 本地空间做 → 天然支持 rotation / anchor_offset
	var center := _sprite.offset * _sprite.scale
	var half_a := _size.x * 0.5 * _sprite.scale.x
	var half_b := _size.y * 0.5 * _sprite.scale.y
	# 伤敌可从指定阶段才开始（数据决定）；清弹不受此限、全程有效。
	if entity_registry != null and _stage >= _damage_from:
		for enemy in entity_registry.get_active_enemies():
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
				continue
			if _ellipse_hit(to_local(enemy.global_position), center,
					half_a + enemy.hitbox_radius, half_b + enemy.hitbox_radius):
				enemy.take_damage(_dps * delta)
	if bullet_manager:
		var half := Vector2(half_a, half_b) * _clear_scale
		var inside := func(p: Vector2) -> bool:
			return _ellipse_hit(to_local(p), center, half.x, half.y)
		bullet_manager.clear_enemy_bullets_in_shape(to_global(center), maxf(half.x, half.y), inside)


## 轴对齐椭圆包含测试（伤敌 + 清敌弹共用；调用方把点转到 bomb 本地空间）。
static func _ellipse_hit(p: Vector2, c: Vector2, a: float, b: float) -> bool:
	if a <= 0.0 or b <= 0.0:
		return false
	var d := p - c
	var u := d.x / a
	var v := d.y / b
	return u * u + v * v <= 1.0

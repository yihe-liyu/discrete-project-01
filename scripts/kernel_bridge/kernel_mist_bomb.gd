## KernelMistBomb —— 单贴图横向展开的云状自机 bomb（宿主实体，不走内核池）。
## 宽从 0 生长到贴图实际宽；覆盖范围（轴对齐椭圆）内持续伤敌 + 清敌弹；结束淡出。
extends BombEntity

var _sprite: Sprite2D
var _t: float = 0.0
var _size := Vector2.ZERO
var _grow_time: float = 0.35
var _hold_time: float = 0.6
var _fade_time: float = 0.25
var _dps: float = 200.0
var _clear_scale: float = 0.95
var _half_a: float = 0.0
var _half_b: float = 0.0
var _center := Vector2.ZERO


func setup(p_data: BombData, pos: Vector2, _direction: Vector2, tint: Color = Color.WHITE, _spawn_delay: float = 0.0) -> void:
	global_position = pos
	data = p_data
	if data == null:
		push_error("[KernelMistBomb] setup 需要 BombData")
		return
	_grow_time = maxf(data.grow_time, 0.001)
	_hold_time = data.hold_time
	_fade_time = data.fade_time
	_dps = data.dps
	_clear_scale = data.clear_scale
	_sprite = Sprite2D.new()
	_sprite.texture = data.texture
	_sprite.modulate = tint
	if data.texture != null:
		_size = data.texture.get_size()
		_sprite.offset = _size * (Vector2(0.5, 0.5) - data.pivot_ratio)   # 让"弯曲处"对齐节点原点
	_sprite.scale = Vector2(0.0, 1.0)
	add_child(_sprite)
	z_index = data.z_index
	_update_area(0.0)


## 当前覆盖椭圆的半长轴（宽的一半；测试/调试用）。
func half_width() -> float:
	return _half_a


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > _grow_time + _hold_time:
		var fk := (_t - _grow_time - _hold_time) / _fade_time
		_sprite.modulate.a = clampf(1.0 - fk, 0.0, 1.0)
		if fk >= 1.0:
			queue_free()
		return
	var k := clampf(_t / _grow_time, 0.0, 1.0)
	_sprite.scale = Vector2(k, 1.0)
	_update_area(k)
	_damage_enemies(delta)
	_clear_bullets()


func _update_area(k: float) -> void:
	_half_a = _size.x * 0.5 * k
	_half_b = _size.y * 0.5
	_center = global_position + _sprite.offset * _sprite.scale


func _damage_enemies(delta: float) -> void:
	if entity_registry == null:
		return
	for enemy in entity_registry.get_active_enemies():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if _ellipse_hit(enemy.global_position, _center, _half_a + enemy.hitbox_radius, _half_b + enemy.hitbox_radius):
			enemy.take_damage(_dps * delta)


func _clear_bullets() -> void:
	if bullet_manager:
		bullet_manager.clear_enemy_bullets_in_circle(_center, maxf(_half_a, _half_b) * _clear_scale)


## 轴对齐椭圆包含测试（伤害 / 清弹判定共用）。
static func _ellipse_hit(p: Vector2, c: Vector2, a: float, b: float) -> bool:
	if a <= 0.0 or b <= 0.0:
		return false
	var d := p - c
	var u := d.x / a
	var v := d.y / b
	return u * u + v * v <= 1.0

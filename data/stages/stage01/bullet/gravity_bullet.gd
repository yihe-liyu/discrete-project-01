extends CoroutineScript
## 子弹竖直向下加速：每帧 velocity.y += gravity * dt
## 用法：挂到 BulletData.coroutine_script 上

var gravity: float = 200.0

func _tick(_ctx: StageContext) -> Variant:
	if not is_instance_valid(target):
		return false
	var bullet = target
	var dt := get_dt()
	bullet.velocity.y += gravity * dt
	bullet.global_position += bullet.velocity * dt
	bullet.rotation = bullet.velocity.angle()
	return true


## 内核端口：竖直向下匀加速 = 世界 accel 行为。
func kernel_port() -> Dictionary:
	return {"move": &"world_accel", "params": {&"world_accel": Vector2(0, gravity)}}

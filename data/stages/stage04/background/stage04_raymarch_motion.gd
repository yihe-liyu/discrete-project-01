extends CoroutineScript
## Stage04 raymarch 背景的前进演出：只移动相机，不碰地形 / 弹幕。
## raymarch 地形本身是无限高度场，相机持续前进就会产生飞行视差。

@export var forward_speed: float = 5.0
@export var bob_amplitude: float = 0.0
@export var bob_speed: float = 0.7

var _base_y: float = 0.0
var _t: float = 0.0


func _on_start() -> void:
	if ctx and ctx.background and ctx.background.camera:
		_base_y = ctx.background.camera.position.y


func _tick(_ctx: StageContext) -> Variant:
	if ctx == null or ctx.background == null or ctx.background.camera == null:
		return true
	var dt := get_dt()
	_t += dt
	var cam := ctx.background.camera
	cam.position.z -= forward_speed * dt
	cam.position.y = _base_y + sin(_t * bob_speed) * bob_amplitude
	return true

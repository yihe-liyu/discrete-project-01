extends CoroutineScript
## 夹具「发动前走位」：`duration` 秒内向左挪一点，然后**自己结束**。
## ⚠️ `auto_stop` 默认 false（持续运行语义）→ 必须显式打开，`_tick` 返回 false 才会结束。

var duration: float = 0.6
var speed: float = 40.0
var _left: float = 0.0


func _init() -> void:
	auto_stop = true


func _tick(_ctx: StageContext) -> bool:
	if not target:
		return false
	_left += get_dt()
	target.global_position.x -= speed * get_dt()
	return _left < duration

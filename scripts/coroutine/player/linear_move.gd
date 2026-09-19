extends CoroutineScript
## 极简线性移动：替代 _physics_process 默认路径
## auto_stop = false

func _tick(_ctx: StageContext):
	if not target: return false
	target.global_position += target.velocity * get_dt()
	return true

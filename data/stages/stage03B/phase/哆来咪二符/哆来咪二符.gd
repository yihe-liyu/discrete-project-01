extends CoroutineScript
## 哆来咪二符

func _on_start() -> void:
	pass


func _tick(p_ctx: StageContext) -> Variant:
	if not target:
		return p_ctx.clock.wait(0)
	
	
	return p_ctx.clock.wait(0)

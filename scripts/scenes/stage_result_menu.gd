## 关卡结算覆盖层：显示本局累计资源与最高分，并提供 Continue / Return。
##
## 由 GameScene 在 stage_cleared 后实例化并 push；不负责推进路线，
## Continue 的语义由 GameScene._on_stage_result_action() 决定。
@tool
class_name StageResultMenu
extends NavPage

var _has_next: bool = false


## 在 push 之前调用：填标题 / 统计；All Clear 时移除 Continue，只留 Return。
func configure(data: Dictionary) -> void:
	_has_next = bool(data.get("has_next", false))
	var title := get_node_or_null("Panel/TitleLabel") as Label
	if title:
		title.text = "ALL CLEAR" if not _has_next else "STAGE CLEAR"
	var stage_label := get_node_or_null("Panel/StageLabel") as Label
	if stage_label:
		stage_label.text = "Stage %d · %s" % [
			int(data.get("stage_no", 0)),
			str(data.get("stage_name", "")),
		]
	var stats := get_node_or_null("Panel/StatsLabel") as Label
	if stats:
		stats.text = "\n".join([
			"Score        %d" % int(data.get("score", 0)),
			"High Score   %d" % int(data.get("high_score", 0)),
			"Graze        %d" % int(data.get("graze", 0)),
			"Power        %s/4.00" % str(data.get("power", "1.00")),
			"Lives        %d" % int(data.get("lives", 0)),
			"Bombs        %d" % int(data.get("bombs", 0)),
		])
	if not _has_next:
		var continue_label := get_node_or_null("Panel/Container/ContinueLabel")
		if continue_label:
			continue_label.get_parent().remove_child(continue_label)
			continue_label.free()


func on_enter() -> void:
	super.on_enter()
	_fade_overlay_in(0.3)


func on_leave() -> void:
	_is_nav_enabled = false
	_stop_pulse()
	if _container == null:
		queue_free()
		return
	_overlay_leave(_container)


func _on_item_selected(index: int) -> void:
	# 不调 done()：GameScene 收到 finished 后会 pop_overlay_menu()，
	# 那才是覆盖层唯一的 on_leave 入口，避免退场动画跑两次。
	if _has_next:
		match index:
			0: finished.emit({"action": "continue"})
			1: finished.emit({"action": "return"})
	else:
		finished.emit({"action": "return"})

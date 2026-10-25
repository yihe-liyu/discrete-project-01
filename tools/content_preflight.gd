extends Node
## 内容预检：跨资源的关系问题（对话事件 / 无人 Boss / 未登记 / 孤儿阶段 / 参数键）。
##
## 只读，不写文件；与 check_content 的分工：
## check_content 查「资源本身能不能加载、注册表/引用是否一致」；
## 本检查查「资源之间的关系是否闭环」。
## 用法：./tools/content_preflight.sh
## 退出码：0 = 无 error；1 = 有 error（warning 不红）。

func _ready() -> void:
	var index := ContentIndex.new()
	index.build()
	var issues := Preflight.run(index)

	var errors := 0
	var warnings := 0
	for issue in issues:
		var level := String(issue.get("level", "warning"))
		var message := String(issue.get("message", ""))
		var source := String(issue.get("source", ""))
		if level == "error":
			errors += 1
			print("❌ " + message + _source_suffix(source))
		else:
			warnings += 1
			print("⚠️ " + message + _source_suffix(source))

	if errors == 0:
		print("✅ 内容预检通过（%d 个 warning）" % warnings)
	else:
		print("❌ 内容预检失败：%d 个 error / %d 个 warning" % [errors, warnings])
	get_tree().quit(1 if errors > 0 else 0)


func _source_suffix(source: String) -> String:
	return "  ← " + source if source != "" else ""

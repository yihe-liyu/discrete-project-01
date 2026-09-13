## 书签提取器 —— 从关卡脚本源码自动提取 timeline.at() 时刻
## 工作台书签不再硬编码：加载任意关卡时扫描其编排脚本。
## 支持：
##   1. 字面量：timeline.at(35.0) → 35.0
##   2. 常见循环展开：timeline.at(17.0 + i * 0.5) + 前面最近的 for i in 7 → 17.0~20.0
## 结果升序、去重（0.2s 内合并）。
extends RefCounted
class_name BookmarkExtractor

## 提取关卡脚本里的时间锚点 → [{t: float, label: String}]
static func extract_from_script(script: Script) -> Array[Dictionary]:
	if script == null:
		return []
	var source: String = script.source_code
	if source.is_empty():
		return []
	var times := _collect_times(source)
	times.sort()
	var result: Array[Dictionary] = []
	var last := -INF
	for t in times:
		if t - last < 0.2:
			continue
		last = t
		result.append({"t": t, "label": "t=%.1fs" % t})
	return result


## 收集所有时刻：字面量 + 循环展开
static func _collect_times(source: String) -> Array[float]:
	var times: Array[float] = []
	# 所有 for i in N（位置 → 循环次数）
	var for_list: Array = []
	var re_for := RegEx.new()
	re_for.compile(r"for i in (\d+)")
	for m in re_for.search_all(source):
		for_list.append({"pos": m.get_start(0), "n": int(m.get_string(1))})
	# 1) 字面量：timeline.at(X)（无循环变量）
	var re_lit := RegEx.new()
	re_lit.compile(r"timeline\.at\(\s*(-?[0-9]+(?:\.[0-9]+)?)\)")
	for m in re_lit.search_all(source):
		times.append(float(m.get_string(1)))
	# 2) 循环展开：timeline.at(A + i * B)，i 取前面最近的 for 次数
	var re_loop := RegEx.new()
	re_loop.compile(r"timeline\.at\(\s*(-?[0-9]+(?:\.[0-9]+)?)\s*\+\s*i\s*\*\s*([0-9]+(?:\.[0-9]+)?)\)")
	for m in re_loop.search_all(source):
		var base := float(m.get_string(1))
		var step := float(m.get_string(2))
		var n := _nearest_for_count(for_list, m.get_start(0))
		for i in n:
			times.append(base + step * i)
	return times


## 找 pos 之前最近一个 for i in N 的 N（关卡脚本里 at 在循环体内）
static func _nearest_for_count(for_list: Array, pos: int) -> int:
	var n := 0
	for f in for_list:
		if f.pos < pos:
			n = f.n
		else:
			break
	return n

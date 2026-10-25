## 内容源码事实：从关卡脚本里扫出「字面时刻 cue / 击破后 wait / 动态时刻」。
##
## 只做导航，不做 GDScript 解析器：字面量能定位就定位；循环/表达式只登记，
## 实际发生仍以飞行记录仪为准。扫描失败就返回空表，不猜。
class_name SourceFacts
extends RefCounted


## 扫描一个关卡脚本；返回 {path, cues, waits, dynamic}。
## cue: {t, line, label, source}；wait: {offset, line, label, source}；
## dynamic: {expr, line, label, source}。
static func scan_stage(path: String) -> Dictionary:
	var out: Dictionary = {"path": path, "cues": [], "waits": [], "dynamic": []}
	if path == "" or not FileAccess.file_exists(path):
		return out
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return out
	var lines := text.split("\n")
	var at_re := RegEx.new()
	at_re.compile("timeline\\.at\\(\\s*([0-9.]+)\\s*\\)")
	var wait_re := RegEx.new()
	wait_re.compile("\\.wait\\(\\s*([0-9.]+)\\s*\\)")
	var dyn_re := RegEx.new()
	dyn_re.compile("timeline\\.at\\(\\s*([^)]*[A-Za-z][^)]*)\\)")

	for i in lines.size():
		var line: String = lines[i]
		var source := "%s:%d" % [path, i + 1]
		var label := _label(lines, i)
		var at_match := at_re.search(line)
		if at_match != null:
			out.cues.append({
				"t": at_match.get_string(1).to_float(),
				"line": i + 1,
				"label": label,
				"source": source,
			})
			continue
		var wait_match := wait_re.search(line)
		if wait_match != null:
			out.waits.append({
				"offset": wait_match.get_string(1).to_float(),
				"line": i + 1,
				"label": label,
				"source": source,
			})
			continue
		var dyn_match := dyn_re.search(line)
		if dyn_match != null:
			out.dynamic.append({
				"expr": dyn_match.get_string(1).strip_edges(),
				"line": i + 1,
				"label": label,
				"source": source,
			})
	return out


## 从 cue 行 + 后 6 行里猜一个人类标签；猜不出就 "cue"（不硬编语义）。
static func _label(lines: PackedStringArray, index: int) -> String:
	var end := mini(index + 7, lines.size())
	var block := "\n".join(lines.slice(index, end))
	if block.find("stage_bgm") != -1:
		return "BGM"
	if block.find("show_logo") != -1:
		return "Logo"
	if block.find("_stage_director.dialogue") != -1:
		return "对话"
	if block.find("_stage_director.boss") != -1:
		return "Boss 进场"
	if block.find("sequence_phases") != -1 or block.find("start_sequence_now") != -1 or block.find("start_phase") != -1:
		return "阶段序列"
	if block.find("_stage_director.bgm") != -1:
		return "切 BGM"
	if block.find("defeat(") != -1 or block.find("retreat(") != -1:
		return "Boss 退场"
	if block.find("finish_stage") != -1:
		return "收尾"
	if block.find("despawn_all") != -1 or block.find("clear_enemy_bullets") != -1:
		return "清场"
	if block.find("_spawn_mid_enemy") != -1:
		return "增援"
	if block.find("ctx.enemies.spawn") != -1:
		return "波次"
	return "cue"


## 扫描一个协程脚本里的 var 声明（P0-D-B 只读调参单用）。
## 返回 {path, vars}；var: {name, type, kind, value, values, expr, line, source}。
static func scan_script(path: String) -> Dictionary:
	var out: Dictionary = {"path": path, "vars": []}
	if path == "" or not FileAccess.file_exists(path):
		return out
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return out
	var lines := text.split("\n")
	var var_re := RegEx.new()
	var_re.compile("^\\s*(?:@export\\s+)?var\\s+([^\\s:=]+)\\s*(?::\\s*([^\\s=]+))?\\s*:?=\\s*(.+)$")
	var i := 0
	while i < lines.size():
		var line: String = lines[i]
		var m := var_re.search(line)
		if m == null:
			i += 1
			continue
		var expr := m.get_string(3).strip_edges()
		var end := i
		while _bracket_balance(expr) > 0 and end + 1 < lines.size():
			end += 1
			expr += "\n" + lines[end].strip_edges()
		var entry := _parse_var(m.get_string(1), m.get_string(2), expr, path, i + 1)
		entry["scope"] = "member" if line == line.strip_edges() else "local"
		out.vars.append(entry)
		i = end + 1
	return out


static func _parse_var(name: String, type_hint: String, expr: String, path: String, line: int) -> Dictionary:
	var entry: Dictionary = {
		"name": name,
		"type": type_hint,
		"kind": "expr",
		"value": null,
		"values": [],
		"expr": expr,
		"line": line,
		"source": "%s:%d" % [path, line],
	}
	var diff_re := RegEx.new()
	diff_re.compile("(?s)^diff_pick\\(\\s*\\[(.*)\\]\\s*\\)$")
	var diff_match := diff_re.search(expr)
	if diff_match != null:
		var parts := _split_top_level(diff_match.get_string(1))
		var parsed: Array = []
		var all_literal := true
		for part in parts:
			if String(part).strip_edges() == "":
				continue
			var lit := _literal(part)
			if not bool(lit.get("ok", false)):
				all_literal = false
				break
			parsed.append(lit)
		if all_literal and not parsed.is_empty():
			entry.kind = "diff_pick"
			entry.literal = true
			entry.values = parsed
			if type_hint == "":
				entry.type = String(parsed[0].get("type", ""))
			return entry
		entry.kind = "diff_pick_dynamic"
		entry.literal = false
		return entry
	var value_lit := _literal(expr)
	if bool(value_lit.get("ok", false)):
		entry.kind = "literal"
		entry.literal = true
		entry.value = value_lit.get("value")
		if type_hint == "":
			entry.type = String(value_lit.get("type", ""))
	return entry


static func _literal(text: String) -> Dictionary:
	var value := text.strip_edges()
	if value == "true" or value == "false":
		return {"ok": true, "type": "bool", "value": value == "true", "text": value}
	if value == "null":
		return {"ok": true, "type": "null", "value": null, "text": "null"}
	if value.length() >= 2 and value.begins_with("\"") and value.ends_with("\""):
		return {"ok": true, "type": "String", "value": value.substr(1, value.length() - 2), "text": value.substr(1, value.length() - 2)}
	if value.length() >= 2 and value.begins_with("'") and value.ends_with("'"):
		return {"ok": true, "type": "String", "value": value.substr(1, value.length() - 2), "text": value.substr(1, value.length() - 2)}
	var number_re := RegEx.new()
	number_re.compile("^-?[0-9]+(?:\\.[0-9]+)?$")
	if number_re.search(value) != null:
		if value.find(".") == -1:
			return {"ok": true, "type": "int", "value": int(value), "text": value}
		return {"ok": true, "type": "float", "value": float(value), "text": value}
	return {"ok": false}


static func _bracket_balance(text: String) -> int:
	var depth := 0
	for i in text.length():
		var ch := text[i]
		if ch == "[" or ch == "(" or ch == "{":
			depth += 1
		elif ch == "]" or ch == ")" or ch == "}":
			depth -= 1
	return depth


static func _split_top_level(text: String) -> Array[String]:
	var parts: Array[String] = []
	var depth := 0
	var quote := ""
	var start := 0
	for i in text.length():
		var ch := text[i]
		if quote != "":
			if ch == quote:
				quote = ""
			continue
		if ch == "\"" or ch == "'":
			quote = ch
		elif ch == "[" or ch == "(" or ch == "{":
			depth += 1
		elif ch == "]" or ch == ")" or ch == "}":
			depth -= 1
		elif ch == "," and depth == 0:
			parts.append(text.substr(start, i - start).strip_edges())
			start = i + 1
	parts.append(text.substr(start, text.length() - start).strip_edges())
	return parts


## `_init()` 是否只做当前约定内的安全赋值（auto_stop / pass）。
## 反射探针会跑 _init；不安全的脚本直接退回静态扫描，不冒险。
static func init_is_trivial(path: String) -> bool:
	if path == "" or not FileAccess.file_exists(path):
		return true
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var stripped: String = lines[i].strip_edges()
		if not stripped.begins_with("func _init"):
			continue
		var colon := stripped.find(":")
		if colon >= 0:
			var inline := stripped.substr(colon + 1).strip_edges()
			if inline != "" and not _trivial_init_stmt(inline):
				return false
		for j in range(i + 1, lines.size()):
			var body := lines[j]
			var body_stripped := body.strip_edges()
			if body_stripped == "" or body_stripped.begins_with("#"):
				continue
			if body.begins_with("func ") or body.begins_with("static func "):
				break
			if not _trivial_init_stmt(body_stripped):
				return false
		return true
	return true


static func _trivial_init_stmt(text: String) -> bool:
	var compact := text.replace(" ", "").replace("\t", "")
	return compact in ["pass", "auto_stop=true", "auto_stop=false"]


## 扫对话脚本里的 d.event("key")。
static func scan_dialogue_events(path: String) -> Array[Dictionary]:
	return _scan_dot_calls(path, "\\.event\\(\\s*[\"']([^\"']+)[\"']\\s*\\)")


## 扫关卡脚本里的 _stage_director.on("key", handler)。
static func scan_stage_handlers(path: String) -> Array[Dictionary]:
	return _scan_dot_calls(path, "\\.on\\(\\s*[\"']([^\"']+)[\"']\\s*,")


static func _scan_dot_calls(path: String, pattern: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if path == "" or not FileAccess.file_exists(path):
		return out
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	var regex := RegEx.new()
	regex.compile(pattern)
	for i in lines.size():
		var match := regex.search(lines[i])
		if match == null:
			continue
		out.append({
			"event": match.get_string(1),
			"line": i + 1,
			"source": "%s:%d" % [path, i + 1],
		})
	return out

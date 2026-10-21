## 内容目录：从 res://data/ 自动派生的索引（创作台 / 工作台用）。
##
## [b]模型[/b][br]
## 索引永不手写：按目录 / 命名约定 + 顶部 @role 注解扫描 .gd / .tres 自动生成。
## 角色判定优先级：@role 注解 > 路径 / 命名约定；约定 = misc 时 @role 只补空缺，不算冲突。
## [codeblock]
## var catalog := ContentCatalog.new().scan()
## catalog.by_role(ContentCatalog.ROLE_PHASE)
## [/codeblock]
## [br]
## [b]边界[/b][br]
## - 只扫 data/；只收 extends CoroutineScript / CoroutineRunner / AsyncCoroutineScript 的 .gd。[br]
## - dialogue/ 目录排除；阶段 .tres 必须在 /phase/ 下且加载成 PhaseData。[br]
## - refs_from / refs_to 是派生信息，只供目录面板显示，不参与路由。[br]
## - 无人引用的脚本保持“未分类”，这是正确结果。
class_name ContentCatalog
extends RefCounted

## 角色：关卡编排。
const ROLE_STAGE := "stage"
## 角色：阶段（阶段资源 .tres）。
const ROLE_PHASE := "phase"
## 角色：Boss 移动。
const ROLE_BOSS_MOVE := "boss_move"
## 角色：Boss 弹幕发射。
const ROLE_BOSS_SHOOT := "boss_shoot"
## 角色：弹丸行为。
const ROLE_BULLET := "bullet"
## 角色：敌人行为。
const ROLE_ENEMY := "enemy"
## 角色：背景演出。
const ROLE_BG := "bg"
## 角色：未分类。
const ROLE_MISC := "misc"

## 角色展示顺序（目录面板按此排）。
const ROLE_ORDER: Array[String] = [
	ROLE_STAGE, ROLE_PHASE, ROLE_BOSS_MOVE, ROLE_BOSS_SHOOT, ROLE_BULLET, ROLE_ENEMY, ROLE_BG, ROLE_MISC,
]

## 角色显示名。
const ROLE_LABELS := {
	ROLE_STAGE: "关卡编排",
	ROLE_PHASE: "阶段",
	ROLE_BOSS_MOVE: "Boss 移动",
	ROLE_BOSS_SHOOT: "弹幕发射",
	ROLE_BULLET: "弹丸行为",
	ROLE_ENEMY: "敌人行为",
	ROLE_BG: "背景演出",
	ROLE_MISC: "未分类",
}

## 默认扫描根。
const DEFAULT_ROOT := "res://data"


## 一个目录条目：脚本或阶段资源。
class Entry:
	## 角色；取本类 ROLE_*。
	var role: String = ""
	## res:// 路径。
	var path: String = ""
	## 显示名（const META / @name / 顶部注释首行）。
	var name: String = ""
	## 描述（注释块剩余行 / META.desc）。
	var description: String = ""
	## 所属关卡的目录名（stage01 / stage03B…）。
	var stage_key: String = ""
	## 顶部注解（@role / @name / @desc 等）。
	var annotations: Dictionary = {}
	## 引用它的资源 / 脚本路径（派生）。
	var refs_from: Array[String] = []
	## 它引用的资源 / 脚本路径（派生）。
	var refs_to: Array[String] = []
	## 角色附加信息（阶段：uid / hp / 时限 / 脚本引用…）。
	var extra: Dictionary = {}


var _entries: Array = []         # Array[Entry]
var _by_path: Dictionary = {}    # path -> Entry
var _warnings: Array[String] = []


## 全量扫描（默认 res://data）：清空旧结果，扫 .gd / .tres，建引用关系，返回 self。
## 可传其他根目录（测试用夹具）。
func scan(p_root: String = DEFAULT_ROOT) -> ContentCatalog:
	_entries.clear()
	_by_path.clear()
	_warnings.clear()
	var files := _walk(p_root)
	for path in files:
		if path.ends_with(".gd"):
			_scan_script(path)
		elif path.ends_with(".tres"):
			_scan_tres(path)
	_build_refs_from()
	_apply_reference_fixes()
	return self


## ── 查询 ──

## 全部条目（扫描顺序）。
func get_entries() -> Array:
	return _entries


## 按角色取条目。阶段按 uid 升序（符卡在前），并列 / 无 uid 按 path；其余角色保持扫描顺序。
func by_role(role: String) -> Array:
	var out: Array = []
	for entry in _entries:
		if (entry as Entry).role == role:
			out.append(entry)
	if role == ROLE_PHASE:
		out.sort_custom(func(a: Entry, b: Entry) -> bool:
			var ua := int(a.extra.get("uid", 0))
			var ub := int(b.extra.get("uid", 0))
			if (ua > 0) != (ub > 0):
				return ua > 0            # 符卡（有 uid）排在非符前
			if ua != ub:
				return ua < ub           # 符卡：uid 升序
			return a.path < b.path)      # 并列 / 都无 uid：路径定序（确定性）
	return out


## 按 res:// 路径取条目；不存在 = null。
func find(path: String) -> Entry:
	return _by_path.get(path, null) as Entry


## 扫描期警告（角色冲突 / 无显示名 / 资源加载失败等）。
func get_warnings() -> Array[String]:
	return _warnings


## 统计：total / by_role / warnings。
func get_stats() -> Dictionary:
	var role_counts := {}
	for role in ROLE_ORDER:
		role_counts[role] = 0
	for entry in _entries:
		role_counts[(entry as Entry).role] = role_counts.get((entry as Entry).role, 0) + 1
	return {
		"total": _entries.size(),
		"by_role": role_counts,
		"warnings": _warnings.size(),
	}


## ── 扫描 ──

func _walk(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if not da:
		_warnings.append("目录不可打开：" + dir)
		return out
	da.list_dir_begin()
	var file_name := da.get_next()
	while file_name != "":
		if da.current_is_dir():
			if not file_name.begins_with("."):
				out.append_array(_walk(dir.path_join(file_name)))
		elif file_name.ends_with(".gd") or file_name.ends_with(".tres"):
			out.append(dir.path_join(file_name))
		file_name = da.get_next()
	da.list_dir_end()
	return out


func _scan_script(path: String) -> void:
	# 边界：dialogue 目录排除（对话构建脚本，非演出逻辑）
	if path.contains("/dialogue/"):
		return
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return
	# 边界：只收协程脚本（extends CoroutineScript / CoroutineRunner / AsyncCoroutineScript / 路径式 extends）
	if not _is_coroutine_script(text):
		return
	var ann := _parse_header(text)
	var convention := _convention_role(path)
	var role := convention
	if ann.has("role"):
		role = ann["role"]
		# 只有“约定真是规则”时才算冲突；约定 = misc 只是“没规则匹配上”，
		# 此时 @role 是在补空缺（如孤儿走位脚本 corner_sweep），不该报冲突。
		if role != convention and convention != ROLE_MISC:
			_warnings.append(
				"角色分类冲突 [%s]：约定=%s 注解=%s（注解优先）"
				% [path.get_file(), convention, role])
	var entry := Entry.new()
	entry.role = role
	entry.path = path
	entry.annotations = ann
	entry.stage_key = _stage_key(path)
	_apply_meta(entry, ann, path, text)
	_add(entry)


## const META 优先；缺 name 或加载失败 → 回退 @name/@desc 注解/注释块（不静默）
func _apply_meta(entry: Entry, ann: Dictionary, path: String, text: String) -> void:
	if text.contains("const META"):
		var meta: Dictionary = _read_meta(path)
		if not meta.is_empty():
			var name_value: Variant = meta.get("name", "")
			if name_value is String and name_value.strip_edges() != "":
				var name: String = name_value.strip_edges()
				entry.name = _truncate(name, 18)
				entry.extra["full_title"] = name
				var desc_value: Variant = meta.get("desc", "")
				entry.description = (desc_value as String).strip_edges() if desc_value is String else ""
				return
			_warnings.append("META 缺 name [%s]：回退注解" % path.get_file())
	# 回退：注解 / 注释块
	if not ann.has("name") and not ann.has("_default_name"):
		# 「不静默」：名字退化成文件名时要说出来（面板的「警告 N」会亮）——
		# 三种成因：没写顶部注释块 / 注释块紧贴声明（被当成员文档丢掉）/ 只写了 @role
		_warnings.append("脚本无显示名（回退文件名 [%s]）：加 `const META` 或顶部 `## @name:` / 隔行注释块"
			% path.get_file())
	var raw_name: String = ann.get("name", ann.get("_default_name", path.get_file().get_basename()))
	entry.name = _short_name(raw_name, entry.role)
	entry.extra["full_title"] = raw_name
	entry.description = ann.get("desc",
		" ".join(ann.get("_comments", [])) if ann.has("name") else ann.get("_desc", ""))


## 读脚本 const META（有则返回字典，无/加载失败返回空）
func _read_meta(path: String) -> Dictionary:
	var S := load(path)
	if S == null:
		return {}
	var map: Dictionary = S.get_script_constant_map()
	var meta: Variant = map.get("META", {})
	return meta if meta is Dictionary else {}


## 仅按长度截断（不再砍"："之后 —— 那是旧 _short_name 的坑）
func _truncate(text: String, limit: int) -> String:
	if text.length() > limit:
		return text.substr(0, limit) + "…"
	return text


func _scan_tres(path: String) -> void:
	# 阶段资源：data/stages/**/phase/*.tres
	if not path.contains("/phase/"):
		return
	var res: Resource = load(path)
	if res == null:
		_warnings.append("阶段资源加载失败：" + path)
		return
	if not (res is PhaseData):
		return
	var phase := res as PhaseData
	var entry := Entry.new()
	entry.role = ROLE_PHASE
	entry.path = path
	entry.name = phase.name if phase.name != "" else path.get_file().get_basename()
	entry.description = "uid=%d · hp=%d · 时限=%.1fs" % [phase.uid, phase.hp, phase.time_limit]
	entry.stage_key = _stage_key(path)
	entry.extra = {
		"uid": phase.uid,
		"hp": phase.hp,
		"time_limit": phase.time_limit,
		"is_timeout_only": phase.is_timeout_only,
		"move_script": phase.move_script.resource_path if phase.move_script else "",
		"pre_move_script": phase.pre_move_script.resource_path if phase.pre_move_script else "",
		"shoot_script": phase.shoot_script.resource_path if phase.shoot_script else "",
	}
	_add(entry)


## 脚本→脚本/资源 引用扫描（preload/load("res://...")），生成 refs_from（信息列）
## 注：不用正则字符串（GDScript 对 \s 等转义不友好），手工扫描 "res://" 出现点
func _build_refs_from() -> void:
	for entry in _entries:
		if not (entry as Entry).path.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string((entry as Entry).path)
		var src_path := (entry as Entry).path
		var idx := 0
		while true:
			var pos := text.find("res://", idx)
			if pos < 0:
				break
			# 前一个非空白字符必须是 "，且句首是 preload(/load(
			var quote_index := pos - 1
			while quote_index >= 0 and (text[quote_index] == " " or text[quote_index] == "\t"):
				quote_index -= 1
			if quote_index >= 0 and text[quote_index] == "\"":
				var head := text.substr(maxi(quote_index - 9, 0), quote_index - maxi(quote_index - 9, 0)).strip_edges()
				if head.ends_with("load("):
					var end := text.find("\"", pos + 6)
					if end >= 0:
						var target := text.substr(pos, end - pos)
						var te := find(target)
						if te:
							if not te.refs_from.has(src_path):
								te.refs_from.append(src_path)
							if not (entry as Entry).refs_to.has(target):
								(entry as Entry).refs_to.append(target)
			idx = pos + 6


## ── 角色判定 ──

## 引用反推（约定 / 注解都判不出来时）：阶段 .tres 的 move_script / pre_move_script / shoot_script
## → boss_move / boss_shoot；boss_shoot 脚本 preload 的 misc 脚本 → bullet。
## 没人引用的脚本保持“未分类”（正确结果，但不能当路由目标）。
func _apply_reference_fixes() -> void:
	for entry in _entries:
		var ent := entry as Entry
		if ent.role != ROLE_PHASE:
			continue
		_assign_if_misc(ent.extra.get("move_script", ""), ROLE_BOSS_MOVE)
		_assign_if_misc(ent.extra.get("pre_move_script", ""), ROLE_BOSS_MOVE)
		_assign_if_misc(ent.extra.get("shoot_script", ""), ROLE_BOSS_SHOOT)
	for entry in _entries:
		var ent := entry as Entry
		if ent.role != ROLE_BOSS_SHOOT:
			continue
		for tpath in ent.refs_to:
			_assign_if_misc(tpath, ROLE_BULLET)


## 目录显示名：敌人脚本可砍掉“角色标签: ”，再按长度截断（有标签 18 字 / 无标签 24 字）。
## 标签需同时满足：role == enemy；前缀非空、≤ 6 字、无空白 / 标点；半角冒号必须是 ": "。
## 其它角色用整句标题或 const META；冒号在句中时不能当标签，否则会把标题从中间劈开。
func _short_name(raw: String, role: String) -> String:
	var text := raw.strip_edges()
	var limit := 24
	if role == ROLE_ENEMY:
		var idx := _tag_separator(text)
		if idx >= 1:
			text = text.substr(idx).strip_edges()
			limit = 18
	if text.length() > limit:
		text = text.substr(0, limit) + "…"
	return text


## 找「角色标签: 行为」的冒号位置；不是标签形状 → -1。返回值 = 内容起始下标。
func _tag_separator(text: String) -> int:
	var idx := -1
	var full := text.find("：")
	if full >= 0:
		idx = full
	var half := text.find(": ")
	if half >= 0 and (idx < 0 or half < idx):
		idx = half
	if idx < 0:
		return -1
	var tag := text.substr(0, idx).strip_edges()
	if tag.is_empty() or tag.length() > 6:
		return -1
	for ch in [" ", "\t", "（", "）", "，", "、", "。", "—", "/", "·", "「", "」"]:
		if tag.contains(ch):
			return -1
	# 冒号后要有内容（“## 红杂鱼:”这种光杆标签不算）
	var rest := text.substr(idx).lstrip(":：").strip_edges()
	if rest.is_empty():
		return -1
	return idx + 1 if text[idx] == "：" else idx + 2


func _assign_if_misc(path: String, role: String) -> void:
	if path == "":
		return
	var entry := find(path)
	if entry and entry.role == ROLE_MISC:
		entry.role = role

func _convention_role(path: String) -> String:
	# 文件名后缀优先（显式命名约定），其次目录，最后未分类
	var fname := path.get_file()
	if fname.ends_with("_move.gd"):
		return ROLE_BOSS_MOVE
	if fname.ends_with("_shoot.gd"):
		return ROLE_BOSS_SHOOT
	if fname.ends_with("_bullet.gd") or path.contains("/bullet/"):
		return ROLE_BULLET
	if path.contains("/background/"):
		return ROLE_BG
	if path.contains("/stage_script/"):
		return ROLE_STAGE
	if path.contains("/enemy/"):
		return ROLE_ENEMY
	return ROLE_MISC


func _is_coroutine_script(text: String) -> bool:
	return text.contains("extends CoroutineScript") \
		or text.contains("extends CoroutineRunner") \
		or text.contains("extends AsyncCoroutineScript") \
		or text.contains("coroutine_script.gd") \
		or text.contains("async_coroutine_script.gd")


## 解析文件顶部注释块：@role / @name / @desc 注解，普通行 → 默认名（首行）/ 描述（后续行）。
## “顶部”= 第一条语句之前，且注释块与下面声明之间有空行；否则那块是成员文档，不能当脚本名。
## 含 @ 注解的块即使贴住声明也认（显式意图）。
func _parse_header(text: String) -> Dictionary:
	var ann := {}
	var first := text.find("##")
	if first < 0:
		return ann
	# ① 顶部：## 之前不许有代码
	for line in text.substr(0, first).split("\n"):
		var above := line.strip_edges()
		if above.is_empty() or above.begins_with("#") or above.begins_with("extends") \
				or above.begins_with("class_name") or above.begins_with("@tool"):
			continue
		return ann
	var lines := text.substr(first).split("\n")
	var comments: Array[String] = []
	var has_annotation := false
	var block_len := 0
	for line in lines:
		var line_text := line.strip_edges()
		if not line_text.begins_with("##"):
			break
		block_len += 1
		var body := line_text.substr(2).strip_edges()
		if body.begins_with("@"):
			has_annotation = true
			var parts := body.split(":", true, 1)
			if parts.size() == 2:
				ann[parts[0].substr(1).strip_edges()] = parts[1].strip_edges()
			else:
				ann[body] = true
		else:
			comments.append(body)
	# ② 隔开才算脚本头；贴住声明 = 成员文档（除非块里有 @ 注解）
	if not has_annotation and block_len < lines.size() and not lines[block_len].strip_edges().is_empty():
		return {}
	if comments.size() > 0:
		ann["_default_name"] = comments[0]
	if comments.size() > 1:
		ann["_desc"] = " ".join(comments.slice(1))
	if comments.size() > 0:
		ann["_comments"] = comments
	return ann


# ── 内部 ──

func _add(entry: Entry) -> void:
	_entries.append(entry)
	_by_path[entry.path] = entry


func _stage_key(path: String) -> String:
	for seg in path.split("/"):
		if seg.to_lower() == "stages":
			continue
		if seg.to_lower().begins_with("stage"):
			return seg
	return ""

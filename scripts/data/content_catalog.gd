class_name ContentCatalog
extends RefCounted
## 内容目录 —— 从 res://data/ 自动派生的索引（创作台）
##
## 铁律：索引永不手写清单；按「目录/命名约定 + ## @role 注解」从文件自动生成。
## 角色判定优先级：@role 注解 > 路径/命名约定；两者打架 → warning（响亮，不静默）。
## 边界：只扫 data/（内容边界）；只收 extends CoroutineScript/CoroutineRunner 的 .gd；
##       dialogue/ 目录排除（对话脚本非演出逻辑）。

const ROLE_STAGE := "stage"
const ROLE_PHASE := "phase"
const ROLE_BOSS_MOVE := "boss_move"
const ROLE_BOSS_SHOOT := "boss_shoot"
const ROLE_BULLET := "bullet"
const ROLE_ENEMY := "enemy"
const ROLE_BG := "bg"
const ROLE_MISC := "misc"

const ROLE_ORDER: Array[String] = [
	ROLE_STAGE, ROLE_PHASE, ROLE_BOSS_MOVE, ROLE_BOSS_SHOOT, ROLE_BULLET, ROLE_ENEMY, ROLE_BG, ROLE_MISC,
]

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

const DEFAULT_ROOT := "res://data"


class Entry:
	## 一个目录条目：要么是脚本（stage/move/shoot/bullet/enemy/misc），要么是阶段资源
	var role: String = ""
	var path: String = ""
	var name: String = ""          ## @name 或注释首行
	var description: String = ""   ## 注释块剩余行
	var stage_key: String = ""     ## 所属关卡的目录名（stage01 / stage03B…）
	var annotations: Dictionary = {}
	var refs_from: Array[String] = []   ## 引用它的资源/脚本路径（派生）
	var refs_to: Array[String] = []     ## 它引用的资源/脚本路径（派生）
	var extra: Dictionary = {}          ## 角色附加信息（阶段：uid/hp/时限/脚本引用…）


var _entries: Array = []         # Array[Entry]
var _by_path: Dictionary = {}    # path -> Entry
var _warnings: Array[String] = []


## 全量扫描（默认 res://data）。可传其他根目录（测试用夹具）。
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

func get_entries() -> Array:
	return _entries


func by_role(role: String) -> Array:
	var out: Array = []
	for entry in _entries:
		if (entry as Entry).role == role:
			out.append(entry)
	return out


func find(path: String) -> Entry:
	return _by_path.get(path, null) as Entry


func get_warnings() -> Array[String]:
	return _warnings


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
	# 边界：只收协程脚本（extends CoroutineScript / CoroutineRunner / 路径式 extends）
	if not _is_coroutine_script(text):
		return
	var ann := _parse_header(text)
	var convention := _convention_role(path)
	var role := convention
	if ann.has("role"):
		role = ann["role"]
		if role != convention:
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
	var raw_name: String = ann.get("name", ann.get("_default_name", path.get_file().get_basename()))
	entry.name = _short_name(raw_name)
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
		"bonus": phase.bonus,
		"is_timeout_only": phase.is_timeout_only,
		"move_script": phase.move_script.resource_path if phase.move_script else "",
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

## 引用反推（两遍）：约定/注解都判不出来时，用真实引用关系定角色
## ① 阶段 .tres 的 move_script/shoot_script 字段 → boss_move / boss_shoot
## ② boss_shoot 脚本 preload 的 misc 脚本 → bullet 行为（如 orbit_probe）
func _apply_reference_fixes() -> void:
	for entry in _entries:
		var ent := entry as Entry
		if ent.role != ROLE_PHASE:
			continue
		_assign_if_misc(ent.extra.get("move_script", ""), ROLE_BOSS_MOVE)
		_assign_if_misc(ent.extra.get("shoot_script", ""), ROLE_BOSS_SHOOT)
	for entry in _entries:
		var ent := entry as Entry
		if ent.role != ROLE_BOSS_SHOOT:
			continue
		for tpath in ent.refs_to:
			_assign_if_misc(tpath, ROLE_BULLET)


## 目录显示名：优先取"："之后的内容（角色标签不重复），超长截断
## 有冒号 → 18 字符；无冒号 → 24 字符（保持短名完整）
func _short_name(raw: String) -> String:
	var text := raw.strip_edges()
	var limit := 24
	var idx := text.find("：")
	if idx >= 0:
		text = text.substr(idx + 1).strip_edges()
		limit = 18
	if text.length() > limit:
		text = text.substr(0, limit) + "…"
	return text


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
		or text.contains("coroutine_script.gd")


## 解析文件顶部注释块：
##   ## @role: xxx    注解（角色覆盖，最高优先级）
##   ## @name: xxx    显示名覆盖
##   ## @desc: xxx    描述覆盖
##   ## 普通行          → 默认显示名（第一行）/ 描述（后续行）
func _parse_header(text: String) -> Dictionary:
	var ann := {}
	var first := text.find("##")
	if first < 0:
		return ann
	var lines := text.substr(first).split("\n")
	var comments: Array[String] = []
	for line in lines:
		var line_text := line.strip_edges()
		if not line_text.begins_with("##"):
			break
		var body := line_text.substr(2).strip_edges()
		if body.begins_with("@"):
			var parts := body.split(":", true, 1)
			if parts.size() == 2:
				ann[parts[0].substr(1).strip_edges()] = parts[1].strip_edges()
			else:
				ann[body] = true
		else:
			comments.append(body)
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

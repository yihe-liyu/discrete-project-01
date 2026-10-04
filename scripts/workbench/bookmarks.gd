class_name Bookmarks
extends RefCounted
## 书签模型（工作台）—— 两类书签 + 缓存读写 + 合并规则，一处持有、可无树测试。
##
##   auto   ：静态提取（扫关卡脚本的 `timeline.at()` 时刻）。确定性重算，不依赖缓存。
##   manual ：人工打点（可编辑、改时间轴右键/面板添加）。**必须持久化**。
##
## 为什么要单独一层（2026-09-30，S3）：这些规则原先散在 `workbench.gd`（提取/持久化/失效）
## 与 `bookmark_panel.gd`（合并展示）里。抽出来后顺带发现并修掉一个真 bug：
## `BookmarkCache.load()` / `has_cache()` **从来没被调用过** —— 人工打点只写不读，
## 重启工作台就全丢（"人工打点（可编辑，持久化）"名不副实）。
##
## 分工：本类不碰 UI、不播报；宿主拿 `open()` 的返回值去写日志。

const CACHE := preload("res://scripts/workbench/bookmark_cache.gd")
const EXTRACTOR := preload("res://scripts/workbench/bookmark_extractor.gd")

## 当前关卡 id（<= 0 = 未打开，`save()` 直接不写）
var stage_id := 0
## 当前关卡内容哈希（主脚本 + 目录下全部 .gd；脚本一变 → 旧 auto 失效）
var content_hash := 0
## 自动书签 [{t}]
var auto: Array = []
## 人工书签 [{t, label}]
var manual: Array = []


## 打开关卡：人工打点从缓存恢复 + 自动书签现场静态提取。
## 返回 {cache_hit, cache_fresh, auto, manual} 供宿主播报（首次 / 缓存命中 / 脚本已改是三件事）。
func open(stage: StageData) -> Dictionary:
	stage_id = stage.stage_id if stage != null else 0
	content_hash = CACHE.stage_content_hash(stage)
	var cache_hit := stage_id > 0 and CACHE.has_cache(stage_id)
	var cached := CACHE.load(stage_id, content_hash)
	var cached_manual: Variant = cached.get("manual", [])
	manual = cached_manual.duplicate(true) if cached_manual is Array else []
	auto = extract(stage.create_script if stage != null else null)
	return {
		"cache_hit": cache_hit,
		"cache_fresh": bool(cached.get("ok", false)),
		"auto": auto.size(),
		"manual": manual.size(),
	}


## 静态提取：扫关卡脚本的 `timeline.at()` 时刻 → [{t}]
func extract(script: Script) -> Array:
	var out: Array = []
	for bookmark in EXTRACTOR.extract_from_script(script):
		out.append({"t": bookmark.t})
	return out


## 接管一份新书签（面板编辑完回传时用；存副本，避免两边共用同一个 Array）
func adopt(auto_bm: Array, manual_bm: Array) -> void:
	auto = auto_bm.duplicate(true)
	manual = manual_bm.duplicate(true)


## 落盘（未打开关卡则不写）
func save() -> void:
	if stage_id <= 0:
		return
	CACHE.save(stage_id, content_hash, auto, manual)


## 合并视图（人工覆盖同名自动）→ 升序 [{t, label, is_manual}]；时间轴与列表面板共用
func merged() -> Array:
	return merged_of(auto, manual)


## 合并排序（静态版，方便无树断言/别处复用）
static func merged_of(auto_bm: Array, manual_bm: Array) -> Array:
	var items: Array = []
	for bm in manual_bm:
		var bookmark_time: float = bm.t if bm is Dictionary else float(bm)
		var label: String = bm.label if bm is Dictionary and bm.has("label") else "t=%.1fs" % bookmark_time
		items.append({"t": bookmark_time, "label": label, "is_manual": true})
	for bm in auto_bm:
		var bookmark_time: float = bm.t if bm is Dictionary else float(bm)
		if items.any(func(m: Dictionary) -> bool: return absf(m.t - bookmark_time) < 0.01):
			continue  # 被人工书签覆盖（改名）
		items.append({"t": bookmark_time, "label": "t=%.1fs" % bookmark_time, "is_manual": false})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	return items

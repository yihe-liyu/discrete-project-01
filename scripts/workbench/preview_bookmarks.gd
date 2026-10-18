extends RefCounted
## 整关预览的书签接线（D3：从 Workbench 拆出）。
## 数据模型在 Bookmarks；这里只负责 open/保存/时间轴刷新/日志文案。

var _bookmarks: Bookmarks
var _bookmark_panel: BookmarkPanel
var _timeline_bar
var _log_line: Callable


func setup(bookmarks: Bookmarks, bookmark_panel: BookmarkPanel, timeline_bar, log_line: Callable) -> void:
	_bookmarks = bookmarks
	_bookmark_panel = bookmark_panel
	_timeline_bar = timeline_bar
	_log_line = log_line


## 打开某面：读缓存（人工打点）+ 静态提取（自动书签）
func open(stage_data: StageData) -> void:
	var info := _bookmarks.open(stage_data)
	_bookmark_panel.refresh()
	refresh_timeline()
	if _log_line.is_valid():
		_log_line.call("＊ 书签：自动 %d 个 · 人工 %d 个（%s）"
			% [info.auto, info.manual, _source_text(info)])


## 时间轴书签刷新（与列表面板同源的合并视图）
func refresh_timeline() -> void:
	_timeline_bar.clear_bookmarks()
	for it in _bookmarks.merged():
		_timeline_bar.add_bookmark(it.t, it.label, "manual" if it.get("is_manual", false) else "")


## 书签被编辑 → 落盘 + 刷时间轴
func on_changed() -> void:
	_bookmarks.save()
	refresh_timeline()


func _source_text(info: Dictionary) -> String:
	if not info.cache_hit:
		return "首次，无缓存"
	return "缓存命中" if info.cache_fresh else "缓存失效（关卡脚本已改，自动书签重收集）"

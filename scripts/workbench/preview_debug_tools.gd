extends RefCounted
## 整关预览的调试工具（D3：从 Workbench 拆出的第六块）。
## 只做两件事：Ctrl+G 强制击破当前 Boss 阶段；启动时扫描 phase .tres uid 冲突。
## 日志通过 Callable 注入，不反向依赖 EventLog。

var _stage_runtime: StageRuntime
var _log: Callable


func setup(runtime: StageRuntime, log_line: Callable) -> void:
	_stage_runtime = runtime
	_log = log_line


## Ctrl+G：强制击破当前 Boss 阶段（调试解锁 + 跳阶段）
func force_clear() -> void:
	if _stage_runtime == null:
		return
	var boss = _stage_runtime.entity_registry.get_boss()
	if not boss:
		_emit("＊ 无 Boss（先跑到 Boss 阶段再按 Ctrl+G）")
		return
	var p_name: String = boss._phase_data.name if boss._phase_data else "?"
	boss.clear_phase(true)
	_emit("！ 强制击破：%s（记录已解锁，阶段链继续）" % p_name)


## 启动检查：扫描全部阶段 .tres 的 uid，冲突报日志（防手滑）
func check_phase_uid_conflicts() -> void:
	var seen := {}
	var da := DirAccess.open("res://data/stages")
	if not da:
		return
	for stage_dir in da.get_directories():
		var phase_dir := "res://data/stages/%s/phase" % stage_dir
		if not DirAccess.dir_exists_absolute(phase_dir):
			continue
		var pda := DirAccess.open(phase_dir)
		if not pda:
			continue
		for file_name in pda.get_files():
			if not file_name.ends_with(".tres"):
				continue
			var phase: PhaseData = load("%s/%s" % [phase_dir, file_name])
			if not phase or phase.uid <= 0:
				continue
			var path := "%s/%s" % [phase_dir, file_name]
			if seen.has(phase.uid):
				_emit("⚠ uid 冲突：%d 同时用于 %s 和 %s" % [phase.uid, seen[phase.uid], path])
			else:
				seen[phase.uid] = path


func _emit(text: String) -> void:
	if _log.is_valid():
		_log.call(text)

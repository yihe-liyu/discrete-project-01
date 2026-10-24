## 阶段脚手架：给当前 Stage / Boss 追加一张 PhaseData（V2-3 第一版）。
##
## 只追加到难度数组末尾，不插入 / 不重排（插入会让已有 phase_index 全部平移）。
## 先 plan、再 apply；plan 只生成文件文本与 BossData diff，不写盘。
class_name PhaseScaffoldService
extends RefCounted

const PHASE_DATA_SCRIPT := "res://scripts/data/phase_data.gd"
const DEFAULT_MOVE := "res://data/boss_scripts/move/random_dir_move.gd"
const DIFF_KEYS := ["easy", "normal", "hard", "lunatic", "extra"]


## options：
##   kind: "spell" / "nonspell"
##   difficulties: Array[int]
##   name, uid, hp, time_limit, timeout_only, slug
##   move_script, shoot_script, pre_move_script（可选；shoot_script=null 会生成模板）
func plan(stage_data: StageData, boss_data: BossData, options: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var warnings: Array[String] = []
	if stage_data == null or boss_data == null:
		issues.append("缺少 StageData / BossData")
	if stage_data != null and boss_data != null and stage_data.stage_id != boss_data.stage_id:
		issues.append("BossData.stage_id=%d 不属于 StageData.stage_id=%d" % [boss_data.stage_id, stage_data.stage_id])
	if stage_data != null and stage_data.resource_path.is_empty():
		issues.append("StageData 没有 resource_path")
	if boss_data != null and boss_data.resource_path.is_empty():
		issues.append("BossData 没有 resource_path")
	var kind: String = options.get("kind", "spell")
	var difficulties: Array = options.get("difficulties", [])
	var name: String = options.get("name", "")
	var uid: int = int(options.get("uid", 0))
	var hp: int = int(options.get("hp", 4000))
	var time_limit: float = float(options.get("time_limit", 30.0))
	var slug: String = options.get("slug", "")
	if issues.is_empty():
		if difficulties.is_empty():
			issues.append("至少选择一个难度")
		for diff in difficulties:
			if not Difficulty.is_valid(int(diff)):
				issues.append("非法难度 %s" % str(diff))
		if hp <= 0:
			issues.append("hp 必须 > 0")
		if time_limit <= 0.0:
			issues.append("time_limit 必须 > 0")
		if slug == "" or slug.contains("/") or slug.contains("\\"):
			issues.append("slug 不能为空，也不能包含路径分隔符")
		if kind == "spell":
			if name == "":
				issues.append("符卡必须填 name")
			if uid <= 0:
				issues.append("符卡 uid 必须 > 0")
			elif BossCatalog.collect_spells().has(uid):
				issues.append("符卡 uid=%d 已被使用" % uid)
		elif kind == "nonspell":
			if uid != 0:
				issues.append("非符 uid 必须为 0")
		else:
			issues.append("kind 必须是 spell / nonspell")
		# 共享 PhaseData 会追加到每个选中难度；各难度当前长度必须相同，否则同一资源会落在不同槽。
		var lengths: Array[int] = []
		for diff in difficulties:
			lengths.append(boss_data.phases_for_difficulty(int(diff)).size())
		if not lengths.is_empty():
			for length in lengths:
				if length != lengths[0]:
					issues.append("选中难度的当前槽数不一致；共享阶段无法落在同一槽位")
					break

	if not issues.is_empty():
		return {"ok": false, "issues": issues, "warnings": warnings}

	var timeout_only: bool = bool(options.get("timeout_only", false))
	var stage_root := stage_data.resource_path.get_base_dir().get_base_dir()
	var phase_dir := stage_root.path_join("phase").path_join(slug)
	var phase_path := phase_dir.path_join(slug + ".tres")
	if FileAccess.file_exists(phase_path):
		return {"ok": false, "issues": ["目标已存在：" + phase_path], "warnings": warnings}

	var move_script: Script = options.get("move_script", load(DEFAULT_MOVE))
	var shoot_script: Script = options.get("shoot_script", null)
	var pre_move_script: Script = options.get("pre_move_script", null)
	var shoot_path := ""
	var shoot_text := ""
	if shoot_script == null:
		shoot_path = phase_dir.path_join(slug + "_shoot.gd")
		if FileAccess.file_exists(shoot_path):
			return {"ok": false, "issues": ["目标已存在：" + shoot_path], "warnings": warnings}
		shoot_text = _shoot_template(name if kind == "spell" else "非符 " + slug)
	if move_script != null and not move_script.can_instantiate():
		return {"ok": false, "issues": ["move_script 不可实例化"], "warnings": warnings}
	if shoot_script != null and not shoot_script.can_instantiate():
		return {"ok": false, "issues": ["shoot_script 不可实例化"], "warnings": warnings}
	if pre_move_script != null and not pre_move_script.can_instantiate():
		return {"ok": false, "issues": ["pre_move_script 不可实例化"], "warnings": warnings}

	var phase_uid := ResourceUID.create_id()
	var phase_text := _phase_text(phase_uid, name, uid, hp, time_limit, timeout_only,
		move_script, shoot_script, shoot_path, pre_move_script)
	var boss_text := _boss_text_with_phase(boss_data, phase_path, phase_uid, difficulties)
	return {
		"ok": true,
		"issues": [],
		"warnings": warnings,
		"phase_path": phase_path,
		"phase_text": phase_text,
		"shoot_path": shoot_path,
		"shoot_text": shoot_text,
		"boss_path": boss_data.resource_path,
		"boss_text": boss_text,
		"difficulties": difficulties,
		"slot": boss_data.phases_for_difficulty(int(difficulties[0])).size(),
		"preview": "新建 %s\n新建 %s\n修改 %s（%s 追加）" % [
			phase_path, shoot_path if shoot_path != "" else "（复用现有 shoot_script）",
			boss_data.resource_path, _diff_list_name(difficulties)],
	}


## 写盘并把同一条 PhaseData 追加到 BossData 各难度数组。
func apply(p_plan: Dictionary, boss_data: BossData) -> Array[String]:
	if not p_plan.get("ok", false):
		return ["计划不可执行"]
	var errs: Array[String] = []
	if FileAccess.file_exists(p_plan.phase_path):
		return ["目标已存在：" + p_plan.phase_path]
	if p_plan.shoot_path != "" and FileAccess.file_exists(p_plan.shoot_path):
		return ["目标已存在：" + p_plan.shoot_path]
	if not _write_text(p_plan.phase_path, p_plan.phase_text):
		return ["写入失败：" + p_plan.phase_path]
	if p_plan.shoot_path != "" and not _write_text(p_plan.shoot_path, p_plan.shoot_text):
		errs.append("写入失败：" + p_plan.shoot_path)
		return errs
	if not _write_text(p_plan.boss_path, p_plan.boss_text):
		return ["写入失败：" + p_plan.boss_path]

	# plan 里没有逐字段回传；从生成的 .tres 重新加载，避免复制字段逻辑。
	var loaded := ResourceLoader.load(p_plan.phase_path) as PhaseData
	if loaded == null:
		return ["新阶段无法重新加载：" + p_plan.phase_path]
	for diff in p_plan.difficulties:
		match int(diff):
			0: boss_data.phases_easy.append(loaded)
			1: boss_data.phases_normal.append(loaded)
			2: boss_data.phases_hard.append(loaded)
			3: boss_data.phases_lunatic.append(loaded)
			4: boss_data.phases_extra.append(loaded)
	return errs


func _phase_text(phase_uid: int, name: String, uid: int,
		hp: int, time_limit: float, timeout_only: bool, move_script: Script, shoot_script: Script,
		shoot_path: String, pre_move_script: Script) -> String:
	var phase_script_id := "1_type"
	var shoot_id := "3_shoot"
	var move_id := "2_move"
	var pre_id := "4_pre"
	var ext := '[ext_resource type="Script"%s path="%s" id="%s"]' % [
		_uid_attr(PHASE_DATA_SCRIPT), PHASE_DATA_SCRIPT, phase_script_id]
	if move_script != null:
		ext += '\n[ext_resource type="Script"%s path="%s" id="%s"]' % [
			_uid_attr(move_script.resource_path), move_script.resource_path, move_id]
	if shoot_script != null:
		ext += '\n[ext_resource type="Script"%s path="%s" id="%s"]' % [
			_uid_attr(shoot_script.resource_path), shoot_script.resource_path, shoot_id]
	elif shoot_path != "":
		ext += '\n[ext_resource type="Script" path="%s" id="%s"]' % [shoot_path, shoot_id]
	if pre_move_script != null:
		ext += '\n[ext_resource type="Script"%s path="%s" id="%s"]' % [
			_uid_attr(pre_move_script.resource_path), pre_move_script.resource_path, pre_id]
	var body := '[resource]\nscript = ExtResource("%s")\n' % phase_script_id
	if name != "":
		body += 'name = "%s"\n' % name
	if uid != 0:
		body += 'uid = %d\n' % uid
	body += 'time_limit = %s\nhp = %d\n' % [str(time_limit), hp]
	if timeout_only:
		body += 'is_timeout_only = true\n'
	if move_script != null:
		body += 'move_script = ExtResource("%s")\n' % move_id
	if shoot_script != null or shoot_path != "":
		body += 'shoot_script = ExtResource("%s")\n' % shoot_id
	if pre_move_script != null:
		body += 'pre_move_script = ExtResource("%s")\n' % pre_id
	return '[gd_resource type="Resource" script_class="PhaseData" format=3 uid="uid://%s"]\n\n%s\n\n%s' % [
		ResourceUID.id_to_text(phase_uid), ext, body]


func _boss_text_with_phase(boss_data: BossData, phase_path: String, phase_uid: int, difficulties: Array) -> String:
	var text := FileAccess.get_file_as_string(boss_data.resource_path)
	var type_id := _find_ext_id(text, PHASE_DATA_SCRIPT)
	if type_id == "":
		type_id = "phase_type"
		text = _insert_ext(text, '[ext_resource type="Script"%s path="%s" id="%s"]' % [
			_uid_attr(PHASE_DATA_SCRIPT), PHASE_DATA_SCRIPT, type_id])
	var res_id := "phase_%s" % ResourceUID.id_to_text(phase_uid).replace("uid://", "")
	text = _insert_ext(text, '[ext_resource type="Resource" uid="uid://%s" path="%s" id="%s"]' % [
		ResourceUID.id_to_text(phase_uid), phase_path, res_id])
	for diff in difficulties:
		var key: String = "phases_" + DIFF_KEYS[int(diff)]
		var re := RegEx.new()
		re.compile('(?m)^%s = Array\\[ExtResource\\("[^"]+"\\)\\]\\(\\[(.*)\\]\\)$' % key)
		var m := re.search(text)
		if m != null:
			var line := m.get_string()
			var inner := m.get_string(1)
			var replacement: String
			if inner.strip_edges() == "":
				replacement = line.replace("[]", '[ExtResource("%s")]' % res_id)
			else:
				replacement = line.substr(0, line.length() - 2) + ', ExtResource("%s")])' % res_id
			text = text.substr(0, m.get_start()) + replacement + text.substr(m.get_end())
		else:
			if not text.ends_with("\n"):
				text += "\n"
			text += '%s = Array[ExtResource("%s")]([ExtResource("%s")])\n' % [key, type_id, res_id]
	return text


func _shoot_template(title: String) -> String:
	return 'extends CoroutineScript\n## %s（脚手架生成，替换成实际弹幕）\n\nfunc _tick(p_ctx: StageContext) -> Variant:\n\treturn p_ctx.clock.wait(1.0)\n' % title


func _uid_attr(path: String) -> String:
	var uid := ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		return ""
	return ' uid="%s"' % ResourceUID.id_to_text(uid)


func _find_ext_id(text: String, path: String) -> String:
	var re := RegEx.new()
	re.compile('(?m)^\\[ext_resource[^\\n]*path="%s"[^\\n]*id="([^"]+)"' % path)
	var m := re.search(text)
	return m.get_string(1) if m != null else ""


func _insert_ext(text: String, line: String) -> String:
	var pos := text.find("[resource]")
	if pos < 0:
		return text + "\n" + line + "\n"
	return text.substr(0, pos) + line + "\n" + text.substr(pos)


func _diff_list_name(difficulties: Array) -> String:
	var names: Array[String] = []
	for diff in difficulties:
		names.append(Difficulty.display_name(int(diff)))
	return "/".join(names)


func _write_text(path: String, text: String) -> bool:
	var dir_path := ProjectSettings.globalize_path(path.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return true

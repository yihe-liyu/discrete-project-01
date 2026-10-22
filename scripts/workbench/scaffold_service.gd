## 创作台脚手架：为 StageData 生成难度变体（第一版，只做 StageVariant）。
##
## 设计约束：先 plan、再 apply；不覆盖已有文件；不改注册表。
## `.tres` 用手写文本保留 UID（ResourceSaver 在运行时会把 `uid://` 头丢掉）。
class_name ScaffoldService
extends RefCounted

const STAGE_VARIANT_SCRIPT := "res://scripts/data/stage_variant.gd"
const VARIANT_DIR := "stage_variants"


## 生成变体计划；不写文件。issues 非空 = 不可 apply。
func plan_stage_variant(stage_data: StageData, difficulty: int, script: Script,
		bgm_key: String = "") -> Dictionary:
	var issues: Array[String] = []
	if stage_data == null:
		issues.append("缺少 StageData")
	if stage_data != null and stage_data.resource_path.is_empty():
		issues.append("StageData 没有 resource_path，无法定位目录")
	if stage_data != null and stage_data.variant_for(difficulty) != null:
		issues.append("难度 %s 已经有变体" % Difficulty.display_name(difficulty))
	if not Difficulty.is_valid(difficulty):
		issues.append("非法难度 %d" % difficulty)
	if script == null:
		issues.append("缺少 create_script")
	if not issues.is_empty():
		return {"ok": false, "issues": issues}

	var stage_path := stage_data.resource_path
	var variant_dir := stage_path.get_base_dir().get_base_dir().path_join(VARIANT_DIR)
	var variant_name := stage_path.get_file().get_basename() + "_" + Difficulty.display_name(difficulty).to_lower() + ".tres"
	var variant_path := variant_dir.path_join(variant_name)
	if FileAccess.file_exists(variant_path):
		issues.append("目标已存在：" + variant_path)
		return {"ok": false, "issues": issues}

	var variant_uid := ResourceUID.create_id()
	var variant_uid_text := ResourceUID.id_to_text(variant_uid)
	var script_uid := ResourceLoader.get_resource_uid(script.resource_path)
	var script_uid_attr := ""
	if script_uid != ResourceUID.INVALID_ID:
		script_uid_attr = ' uid="%s"' % ResourceUID.id_to_text(script_uid)

	var variant_text := '''[gd_resource type="Resource" script_class="StageVariant" format=3 uid="uid://%s"]

[ext_resource type="Script"%s path="res://scripts/data/stage_variant.gd" id="1_type"]
[ext_resource type="Script"%s path="%s" id="2_script"]

[resource]
script = ExtResource("1_type")
difficulty = %d
create_script = ExtResource("2_script")
''' % [variant_uid_text, _script_uid_attr(STAGE_VARIANT_SCRIPT), script_uid_attr, script.resource_path, difficulty]
	if bgm_key != "":
		variant_text += 'bgm_key = "%s"\n' % bgm_key

	var stage_text := _stage_text_with_variant(stage_data, variant_path, variant_uid_text)
	var preview := "新建 %s\n修改 %s（追加 variants）" % [variant_path, stage_path]
	return {
		"ok": true,
		"issues": [],
		"variant_path": variant_path,
		"variant_text": variant_text,
		"stage_path": stage_path,
		"stage_text": stage_text,
		"preview": preview,
		"difficulty": difficulty,
		"script": script,
		"bgm_key": bgm_key,
	}


## 写盘并把新变体追加到内存 StageData；失败会返回错误列表（可能部分写入，调用方先 plan）。
func apply(plan: Dictionary, stage_data: StageData) -> Array[String]:
	var errs: Array[String] = []
	if not plan.get("ok", false):
		return ["计划不可执行"]
	var variant_path: String = plan.variant_path
	var stage_path: String = plan.stage_path
	if FileAccess.file_exists(variant_path):
		return ["目标已存在：" + variant_path]
	if not _write_text(variant_path, plan.variant_text):
		return ["写入失败：" + variant_path]
	if not _write_text(stage_path, plan.stage_text):
		errs.append("写入失败：" + stage_path)
		return errs

	var variant := StageVariant.new()
	variant.difficulty = plan.difficulty
	variant.create_script = plan.script
	variant.bgm_key = plan.bgm_key
	stage_data.variants.append(variant)
	return errs


func _script_uid_attr(path: String) -> String:
	var uid := ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		return ""
	return ' uid="%s"' % ResourceUID.id_to_text(uid)


func _write_text(path: String, text: String) -> bool:
	var dir_path := ProjectSettings.globalize_path(path.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return true


## 在 StageData 文本里追加 variant：ext_resource + variants 数组项。
func _stage_text_with_variant(stage_data: StageData, variant_path: String, variant_uid: String) -> String:
	var text := FileAccess.get_file_as_string(stage_data.resource_path)
	var type_id := _find_ext_id(text, STAGE_VARIANT_SCRIPT)
	if type_id == "":
		type_id = "stage_variant_type"
		var type_line := '[ext_resource type="Script"%s path="%s" id="%s"]' % [
			_script_uid_attr(STAGE_VARIANT_SCRIPT), STAGE_VARIANT_SCRIPT, type_id]
		text = _insert_ext(text, type_line)
	var res_id := "variant_%s" % variant_uid
	var res_line := '[ext_resource type="Resource" uid="uid://%s" path="%s" id="%s"]' % [
		variant_uid, variant_path, res_id]
	text = _insert_ext(text, res_line)

	var re := RegEx.new()
	re.compile('(?m)^variants = Array\\[ExtResource\\("([^"]+)"\\)\\]\\(\\[(.*)\\]\\)$')
	var m := re.search(text)
	if m != null:
		var old := m.get_string()
		var new_line := old.substr(0, old.length() - 2) + ', ExtResource("%s")])' % res_id
		text = text.substr(0, m.get_start()) + new_line + text.substr(m.get_end())
	else:
		if not text.ends_with("\n"):
			text += "\n"
		text += 'variants = Array[ExtResource("%s")]([ExtResource("%s")])\n' % [type_id, res_id]
	return text


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

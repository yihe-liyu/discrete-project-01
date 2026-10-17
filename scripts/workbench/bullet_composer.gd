extends RefCounted
## BulletComposer —— F10 的**无 UI 模型**：相位 → Move/Until/Action → BulletLifecycle。
##
## 设计边界：
## - 只做**线性相位**（与 BulletLifecycle 一致，没有跳转/分支）；
## - 组合逻辑不复制：每个 op 都走 `DescriptorCatalog.apply_*()` → `BulletLifecycle` builder；
## - 难度变体不进本类：一个 Composer 代表**一个难度变体**；UI 用 4 个实例装 4 档；
## - 表达式/代码生成是 UI 层的事；本类只保证“拼出来的 lifecycle 与手写等价”。
##
## 数据结构：
##   phases = [{moves: [op_call...], until: op_call, on_end: [op_call...]}]
##   op_call = {op: StringName, ...args}
##
## 不加 class_name：测试/工作台用 preload，避免新 class_name 全局缓存未导入。

const CATALOG = preload("res://scripts/workbench/descriptor_catalog.gd")

## 每个相位：moves 有序；until 一个；on_end 有序。
var phases: Array = []


func _init() -> void:
	add_phase()


## 追加一个空相位（默认 until=never）。
func add_phase() -> int:
	phases.append({"moves": [], "until": {"op": "never"}, "on_end": []})
	return phases.size() - 1


func phase(index: int) -> Dictionary:
	return phases[index]


func move_count(index: int) -> int:
	return (phases[index]["moves"] as Array).size()


## 给某个相位追加 Move；args 里可以有任意键，`op` 由这里统一写入。
func add_move(phase_index: int, op: StringName, args: Dictionary = {}) -> void:
	var op_call: Dictionary = args.duplicate(true)
	op_call["op"] = op
	(phases[phase_index]["moves"] as Array).append(op_call)


## 设置某相位的 Until；`every` / `every_ticks` 是 Until 的修饰键，放在 args 里。
func set_until(phase_index: int, op: StringName, args: Dictionary = {}) -> void:
	var op_call: Dictionary = args.duplicate(true)
	op_call["op"] = op
	phases[phase_index]["until"] = op_call


## 给某相位追加 on_end Action。
func add_action(phase_index: int, op: StringName, args: Dictionary = {}) -> void:
	var op_call: Dictionary = args.duplicate(true)
	op_call["op"] = op
	(phases[phase_index]["on_end"] as Array).append(op_call)


## 从声明式 spec 载入（golden test / 工作区恢复 / UI 序列化共用）。
## spec = {phases: [{moves: [...], until: {...}, on_end: [...]}]}
func from_spec(spec: Dictionary) -> void:
	phases.clear()
	for p in spec.get("phases", []):
		var idx := add_phase()
		for m in p.get("moves", []):
			add_move(idx, StringName(m.get("op", &"")), m)
		var u: Dictionary = p.get("until", {})
		set_until(idx, StringName(u.get("op", &"never")), u)
		for a in p.get("on_end", []):
			add_action(idx, StringName(a.get("op", &"")), a)
	if phases.is_empty():
		add_phase()


func to_spec() -> Dictionary:
	return {"phases": phases.duplicate(true)}


## 核心：按顺序调 builder，得到与手写完全同构的 lifecycle。
## 注意：每个相位都要显式 apply_until（默认 never），保证 `_set_until` 的修饰键语义一致。
func to_lifecycle() -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	for i in phases.size():
		if i > 0:
			lc.then()
		var p: Dictionary = phases[i]
		for m in p["moves"]:
			CATALOG.apply_move(lc, m)
		CATALOG.apply_until(lc, p["until"])
		for a in p["on_end"]:
			CATALOG.apply_action(lc, a)
	return lc


## 静态校验：只查“拼装器能提前发现”的坑；编译期的 op/target 守卫仍在 BulletLifecycle。
## 返回 [] = 没发现问题；非空 = 人话错误列表。
func validate() -> Array[String]:
	var errors: Array[String] = []
	for i in phases.size():
		var p: Dictionary = phases[i]
		var has_rotate := false
		for m in p["moves"]:
			var mop := StringName(m.get("op", &""))
			if mop in [&"rotate", &"rotate_velocity", &"rotate_heading"]:
				has_rotate = true
			if mop == &"steer" and StringName(m.get("target", &"")) == &"":
				errors.append("相位 %d：steer 的 target 为空" % (i + 1))
		var u: Dictionary = p["until"]
		var uop := StringName(u.get("op", &"never"))
		if uop == &"turned" and not has_rotate:
			errors.append("相位 %d：until_turned 前必须有 rotate / rotate_velocity / rotate_heading" % (i + 1))
		if uop == &"near" and StringName(u.get("target", &"")) == &"":
			errors.append("相位 %d：until_near 的 target 为空" % (i + 1))
		for a in p["on_end"]:
			var aop := StringName(a.get("op", &""))
			if aop == &"emit" and a.get("spawn") == null:
				errors.append("相位 %d：emit 的 spawn 为空" % (i + 1))
			if aop == &"emit_variant":
				var d: Dictionary = a.get("dir", {})
				if StringName(d.get("kind", &"")) != BulletLifecycle.D_CHANCE:
					errors.append("相位 %d：emit_variant 的 dir 必须是 chance_toward" % (i + 1))
			if aop == &"on_end_call" and StringName(a.get("hook", &"")) == &"":
				errors.append("相位 %d：on_end_call 的 hook 为空" % (i + 1))
	return errors

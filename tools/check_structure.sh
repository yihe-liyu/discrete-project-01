#!/usr/bin/env bash
# 结构契约检查（N17）—— 把"重构这一路立下的纪律"变成**会自己红**的机械判据。
#
# 为什么需要：S1–S4 的成果（接缝化 / 抽服务 / 装配合一）都是"靠人记得"的约定；
# 靠记性的约定会在下一次改动里静默退化（本轮就踩到：创作台页签被子视图吃掉点击）。
# 这里只查**能被机械验证**的四条，不查文风：
#
#   ① 组合台必须有同名场景壳：`scripts/workbench/X_bench.gd` ↔ `scenes/workbench/X_bench.tscn`，
#      脚本 `extends BenchBase`，且场景根节点挂的就是这个脚本。
#   ② 测试白盒预算（`._xxx` 私有访问，粗计）**只减不增**：预算是常量，减少时把数字改小。
#   ③ 唯一来源常量：值只允许出现一次（同值多定义 = 漂移，两边改一边是必然的）。
#   ④ 舞台接线唯一：`bullet_manager.inject_*(...)` 这类调用只允许出现在 `stage_host.gd`
#      （S4 的成果；调用点自己接线就是分叉，漏一句就出隐性 bug）。
#
# 用法: bash tools/check_structure.sh   （默认只报告；`--fail` 时有违规 exit 1）
set -e
cd "$(dirname "$0")/.."

python3 - "$@" <<'PY'
import os, re, sys, collections

should_fail = "--fail" in sys.argv
BAD = []

# ── ① 组合台 ↔ 同名场景壳 ────────────────────────────────────────────
benches = sorted(f for f in os.listdir("scripts/workbench") if f.endswith("_bench.gd"))
if not benches:
	BAD.append(("① 组合台", "scripts/workbench/ 下一个 *_bench.gd 都没有 —— 目录结构变了？"))
for f in benches:
	stem = f[:-3]
	path = os.path.join("scripts/workbench", f)
	src = open(path, encoding="utf-8").read()
	scene = os.path.join("scenes/workbench", stem + ".tscn")
	if not os.path.exists(scene):
		BAD.append(("① 组合台", f"{path} 没有同名场景 {scene}（台子必须有场景壳）"))
	else:
		tscn = open(scene, encoding="utf-8").read()
		if f'path="res://{path}"' not in tscn:
			BAD.append(("① 组合台", f"{scene} 根节点没挂 {path}"))
	if not re.search(r"^extends\s+(BenchBase|\"res://scripts/workbench/bench_base\.gd\")", src, re.M):
		BAD.append(("① 组合台", f"{path} 必须 extends BenchBase（公共骨架只此一处）"))

# ── ② 测试白盒预算（只减不增）─────────────────────────────────────────
WHITEBOX_BUDGET = 463   # 2026-09-30 实测（S1 接缝化后 F 层为 0，这里是**全仓**预算）
hits = collections.Counter()
for dp, dn, fn in os.walk("test"):
	if ".godot" in dp or (os.sep + "reference") in (dp + os.sep):
		continue
	for n in fn:
		if not n.endswith(".gd"):
			continue
		p = os.path.join(dp, n)
		k = 0
		for line in open(p, encoding="utf-8").read().splitlines():
			if line.lstrip().startswith("#"):
				continue          # 注释里提到 API 名不算摸私有
			k += len(re.findall(r"\._[A-Za-z_]", line))
		if k:
			hits[p] = k
total = sum(hits.values())
if total > WHITEBOX_BUDGET:
	BAD.append(("② 白盒预算",
		f"测试里私有访问 {total} 处 > 预算 {WHITEBOX_BUDGET}（只减不增）—— 新增了 "
		f"{total - WHITEBOX_BUDGET} 处；改成走公开接缝，或把预算调小而不是调大"))
	if hits:
		top = ", ".join(f"{p}={c}" for p, c in hits.most_common(5))
		BAD.append(("② 白盒预算", f"最多的几个文件：{top}"))

# ── ③ 唯一来源常量（同值多定义 = 漂移）────────────────────────────────
# 值 → 允许出现的次数。改常量时只改 `bench_common.gd`，别在各文件里抄字面量。
UNIQUE_SOURCES = {
	"20260801": (1, "工作台固定种子（唯一来源：scripts/workbench/bench_common.gd 的 FIXED_SEED）"),
}
for value, (allowed, why) in UNIQUE_SOURCES.items():
	where = []
	for dp, dn, fn in os.walk("scripts"):
		if ".godot" in dp:
			continue
		for n in fn:
			if not n.endswith(".gd"):
				continue
			p = os.path.join(dp, n)
			for i, line in enumerate(open(p, encoding="utf-8").read().splitlines(), 1):
				if value in line:
					where.append(f"{p}:{i}")
	if len(where) != allowed:
		BAD.append(("③ 唯一来源", f"{value} 出现 {len(where)} 次（应 {allowed} 次）—— {why}：{', '.join(where)}"))

# ── ④ 舞台接线唯一 ───────────────────────────────────────────────────
WIRING_OK = {"scripts/stage/stage_host.gd"}
CALL = re.compile(r"\.inject_(?:stage_runtime|entity_registry)\s*\(")
for dp, dn, fn in os.walk("scripts"):
	if ".godot" in dp:
		continue
	for n in fn:
		if not n.endswith(".gd"):
			continue
		p = os.path.join(dp, n).replace(os.sep, "/")
		for i, line in enumerate(open(p, encoding="utf-8").read().splitlines(), 1):
			if line.lstrip().startswith("#"):
				continue          # 注释里提到 API 名不算调用
			if CALL.search(line) and p not in WIRING_OK:
				BAD.append(("④ 接线唯一", f"{p}:{i} 自己接线了：{line.strip()}（舞台接线只走 StageHost）"))

# ── 报告 ─────────────────────────────────────────────────────────────
print(f"check_structure: 组合台 {len(benches)} 个 · 测试白盒 {total}/{WHITEBOX_BUDGET} · "
	f"唯一来源常量 {len(UNIQUE_SOURCES)} 条 · 接线白名单 {len(WIRING_OK)} 个文件")
if BAD:
	for rule, msg in BAD:
		print(f"❌ [{rule}] {msg}")
	print(f"==> 应改：{len(BAD)} 条")
	sys.exit(1 if should_fail else 0)
print("✅ 结构契约全过")
PY

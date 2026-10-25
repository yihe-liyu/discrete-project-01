#!/usr/bin/env bash
# 结构契约检查（N17）—— 把"重构这一路立下的纪律"变成**会自己红**的机械判据。
#
# 为什么需要：S1–S4 的成果（接缝化 / 抽服务 / 装配合一）都是"靠人记得"的约定；
# 靠记性的约定会在下一次改动里静默退化（本轮就踩到：创作台页签被子视图吃掉点击）。
# 这里只查**能被机械验证的五条**，不查文风：
#
#   ① 测试白盒预算（`._xxx` 私有访问，粗计）**只减不增**：预算是常量，减少时把数字改小。
#   ② 唯一来源常量：值只允许出现一次（同值多定义 = 漂移，两边改一边是必然的）。
#   ③ 舞台接线唯一：`bullet_manager.inject_*(...)` 这类调用只允许出现在 `stage_host.gd`
#      （S4 的成果；调用点自己接线就是分叉，漏一句就出隐性 bug）。
#   ④ 跨语言常量一致：C++ OPS_ARGS / SLOT_STRIDE 必须与 GDScript ARGS / MAX_SLOTS 相同。
#   ⑤ 内容层不直连：`data/**/*.gd` 不得出现 `get_parent()` / `create_tween()`（BGA5；
#      取背景走 `ctx.background`，移动/渐变走 `ctx.enemies` / `ctx.boss` / `ctx.stage` 的意图动词）。
#
# 用法: bash tools/check_structure.sh   （默认只报告；`--fail` 时有违规 exit 1）
set -e
cd "$(dirname "$0")/.."

python3 - "$@" <<'PY'
import os, re, sys, collections

should_fail = "--fail" in sys.argv
BAD = []

# ── ① 测试白盒预算（只减不增）─────────────────────────────────────────
WHITEBOX_BUDGET = 327   # 2026-10-19 实测（符卡练习菜单 135 处改走 Probe 后；只减不增）
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

# ── ② 唯一来源常量（同值多定义 = 漂移）────────────────────────────────
# 值 → 允许出现的次数。改常量时只改 `bench_common.gd`，别在各文件里抄字面量。
UNIQUE_SOURCES = {
	"20260801": (1, "工具固定种子（唯一来源：scripts/debug/tool_defaults.gd 的 FIXED_SEED）"),
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

# ── ③ 舞台接线唯一 ───────────────────────────────────────────────────
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

# ── ④ 跨语言常量一致 ─────────────────────────────────────────────────
def _const(path: str, pattern: str):
	m = re.search(pattern, open(path, encoding="utf-8").read())
	return int(m.group(1)) if m else None
CROSS_CONST = [
	("OPS_ARGS", "gdextension/src/danmaku_store.h", r"static const int OPS_ARGS\s*=\s*(\d+)",
	 "ARGS", "scripts/kernel_bridge/lifecycle/lifecycle_compiler.gd", r"const ARGS\s*:=\s*(\d+)"),
	("SLOT_STRIDE", "gdextension/src/danmaku_store.h", r"static const int SLOT_STRIDE\s*=\s*(\d+)",
	 "MAX_SLOTS", "scripts/kernel_bridge/lifecycle/lifecycle_compiler.gd", r"const MAX_SLOTS\s*:=\s*(\d+)"),
]
for cpp_name, cpp_path, cpp_pat, gd_name, gd_path, gd_pat in CROSS_CONST:
	cpp_v = _const(cpp_path, cpp_pat)
	gd_v = _const(gd_path, gd_pat)
	if cpp_v is None or gd_v is None or cpp_v != gd_v:
		BAD.append(("⑤ 跨语言常量",
			f"{cpp_name}={cpp_v}（{cpp_path}）≠ {gd_name}={gd_v}（{gd_path}）"))

# ── ⑤ 内容层不直连 get_parent()/create_tween() ───────────────────────
CONTENT_BAD = 0
for dp, dn, fn in os.walk("data"):
	if ".godot" in dp:
		continue
	for n in fn:
		if not n.endswith(".gd"):
			continue
		p = os.path.join(dp, n).replace(os.sep, "/")
		for i, line in enumerate(open(p, encoding="utf-8").read().splitlines(), 1):
			code = line.split("#", 1)[0]       # 整行/行尾注释不算调用
			for token in ("get_parent()", "create_tween()"):
				if token in code:
					CONTENT_BAD += 1
					BAD.append(("⑥ 内容直连",
						f"{p}:{i} 用了 {token}：{line.strip()}（改走 ctx.* 意图动词）"))

# ── 报告 ─────────────────────────────────────────────────────────────
print(f"check_structure: 测试白盒 {total}/{WHITEBOX_BUDGET} · "
	f"唯一来源常量 {len(UNIQUE_SOURCES)} 条 · 跨语言常量 {len(CROSS_CONST)} 组 · "
	f"内容直连 {CONTENT_BAD} 条 · 接线白名单 {len(WIRING_OK)} 个文件")
if BAD:
	for rule, msg in BAD:
		print(f"❌ [{rule}] {msg}")
	print(f"==> 应改：{len(BAD)} 条")
	sys.exit(1 if should_fail else 0)
print("✅ 结构契约全过")
PY

#!/usr/bin/env bash
# 标识符命名契约检查（N16）——「同物同名」的机械校验。
#   规则（见 docs/BEST_PRACTICES_BASELINE.md「标识符命名契约」）：
#     ① 私有字段（_x）名 = "_" + 类型名 snake；公开字段/属性 = 角色名（对外 API，允许）
#     ② 同一类型不应有多个私有字段名（同物不同名）
#     ③ @onready 节点引用名 = 节点名 snake（节点名本身是内置类名时跳过）
#     ④ 节点名 PascalCase（R15）
#     ⑤ 形参 / 局部变量 / 循环变量遮蔽类成员（GDScript SHADOWED_VARIABLE / CONFUSABLE_LOCAL_USAGE）
# 用法: bash tools/check_naming.sh [--fail]   （默认只报告；--fail 时有违规 exit 1）
set -e
cd "$(dirname "$0")/.."
python3 - "$@" <<'PY'
import sys, re, os, collections

should_fail = "--fail" in sys.argv
ROOTS = ["scripts", "data", "test"]

def files(root):
    for dp, _dn, fn in os.walk(root):
        # test/reference 是冻结的 vendor 参照实现（原 scripts/kernel，改在重建版），不适用宿主命名契约
        if ".godot" in dp or (os.sep + "reference") in (dp + os.sep):
            continue
        for n in fn:
            if n.endswith(".gd"):
                yield os.path.join(dp, n)

def snake(s):
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s)
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", s)
    return s.lower()

cls = {}
scanned = 0
for root in ROOTS:
    for p in files(root):
        scanned += 1
        for line in open(p, encoding="utf-8").read().splitlines():
            m = re.match(r"\s*class_name\s+(\w+)", line)
            if m:
                cls[m.group(1)] = p

BUILTIN_NODE = {
    "Sprite2D", "AnimatedSprite2D", "TextureRect", "SubViewport", "Label",
    "GPUParticles2D", "Control", "CollisionShape2D", "Node2D", "CanvasLayer",
    "Marker2D", "ColorRect", "AudioStreamPlayer", "GridContainer",
    "VBoxContainer", "HBoxContainer", "Panel", "Button", "TextureProgressBar",
}
FIELD = re.compile(r"^(?:@export\w*\s+)?(?:static\s+)?(?:var|const)\s+(\w+)\s*:\s*([A-Za-z_]\w*)")
NODE = re.compile(r"@onready\s+var\s+(\w+)[^=]*=\s*(?:\$|%)\s*\"?([A-Za-z0-9_/]+)")

priv_bad, node_bad, node_case = [], [], []
priv_names = collections.defaultdict(set)
public_cnt = 0
for root in ROOTS:
    for p in files(root):
        for i, line in enumerate(open(p, encoding="utf-8").read().splitlines(), 1):
            m = FIELD.match(line)
            if m:
                name, typ = m.group(1), m.group(2)
                if typ in cls:
                    if name.startswith("_"):
                        priv_names[typ].add(name)
                        expect = "_" + snake(typ)
                        # 契约允许「限定词_类型snake」：_move_coroutine_runner
                        ok = name == expect or (name.endswith(expect) and len(name) > len(expect))
                        if not ok:
                            priv_bad.append((p, i, name, typ, expect))
                    else:
                        public_cnt += 1
            m = NODE.search(line)
            if m:
                name, path = m.group(1), m.group(2)
                for seg in path.split("/"):
                    if seg and seg[0].islower():
                        node_case.append((p, i, seg))
                node = path.split("/")[-1]
                if node not in BUILTIN_NODE and name.lstrip("_") != snake(node):
                    node_bad.append((p, i, name, node, snake(node)))

# ⑤ 形参 / 局部变量 / 循环变量遮蔽类成员（运行时 SHADOWED_VARIABLE / CONFUSABLE_LOCAL_USAGE）
#    契约（基线「标识符命名契约」）：形参遮蔽成员 → 加 `p_`；真的不用 → 单 `_`；禁止叠加 `_p_`。
MEMBER = re.compile(r"^(?:@\w+\s+)*(?:static\s+)?(?:var|const)\s+(\w+)")
FUNC = re.compile(r"^func\s+\w+\s*\(")
LOCAL = re.compile(r"^\s+var\s+(\w+)")
FORLOOP = re.compile(r"^\s+for\s+(\w+)\s+in\b")
shadow_bad = []
overlay_bad = []
field_letter_bad = []
for root in ROOTS:
    for p in files(root):
        lines = open(p, encoding="utf-8").read().splitlines()
        members = {}
        for i, ln in enumerate(lines):
            m = MEMBER.match(ln)
            if m:
                members[m.group(1)] = i + 1
                if re.fullmatch(r"[a-z]", m.group(1)):
                    field_letter_bad.append((p, i + 1, m.group(1)))
        i = 0
        while i < len(lines):
            ln = lines[i]
            if FUNC.match(ln):
                sig, j, depth = ln, i, ln.count("(") - ln.count(")")
                while depth > 0 and j + 1 < len(lines):
                    j += 1
                    sig += " " + lines[j]
                    depth += lines[j].count("(") - lines[j].count(")")
                inner = sig[sig.index("(") + 1:sig.rindex(")")]
                params = []
                for part in inner.split(","):
                    pm = re.match(r"\s*([A-Za-z_]\w*)", part)
                    if pm:
                        params.append(pm.group(1))
                for prm in params:
                    if prm in members:
                        shadow_bad.append((p, i + 1, "形参", prm, members[prm]))
                    # 契约禁止「叠加前缀」_p_：要么 p_x（用过），要么 _x（不用）
                    if prm.startswith("_p_"):
                        overlay_bad.append((p, i + 1, prm))
                k = j + 1
                while k < len(lines):
                    bl = lines[k]
                    if FUNC.match(bl):
                        break
                    lm = LOCAL.match(bl)
                    if lm and lm.group(1) in members:
                        shadow_bad.append((p, k + 1, "局部", lm.group(1), members[lm.group(1)]))
                    fm = FORLOOP.match(bl)
                    if fm and fm.group(1) in members:
                        shadow_bad.append((p, k + 1, "循环", fm.group(1), members[fm.group(1)]))
                    k += 1
                i = k
            else:
                i += 1

def _typed_ok(n, t):
    e = "_" + snake(t)
    return n == e or (n.endswith(e) and len(n) > len(e))
multi = sorted((t, sorted(ns)) for t, ns in priv_names.items() if len(ns) > 1 and not all(_typed_ok(n, t) for n in ns))

print(f"check_naming: 扫描 {scanned} 个脚本，{len(cls)} 个自定义类型")
print(f"\n[① 私有字段名 ≠ _+类型名 snake]（{len(priv_bad)}）")
for p, i, n, t, e in sorted(priv_bad):
    print(f"  {p}:{i}  {n}: {t}  → {e}")
print(f"\n[② 同类型多个私有字段名]（{len(multi)} 组）")
for t, ns in multi:
    print(f"  {t}: " + " / ".join(ns))
print(f"\n[③ @onready 变量名 ≠ 节点名]（{len(node_bad)}）")
for p, i, n, nd, e in sorted(node_bad):
    print(f"  {p}:{i}  {n} = {nd}  → {e}")
print(f"\n[④ 节点名非 PascalCase(R15)]（{len(set(node_case))}）")
for p, i, s in sorted(set(node_case)):
    print(f"  {p}:{i}  节点名 '{s}'")
print(f"\n[⑤ 形参/局部/循环变量遮蔽类成员]（{len(shadow_bad)}）")
for p, i, kind, n, ml in sorted(shadow_bad):
    print(f"  {p}:{i}  {kind} {n} 遮蔽成员（声明于 {ml}）")
print(f"\n[⑤ 形参叠加前缀 _p_]（{len(overlay_bad)}）")
for p, i, n in sorted(overlay_bad):
    print(f"  {p}:{i}  {n}  → p_{n[3:]} 或 _{n[3:]}")
print(f"\n[⑥ 类字段单字母]（{len(field_letter_bad)}）")
for p, i, n in sorted(field_letter_bad):
    print(f"  {p}:{i}  {n}  → 类字段必须全名")
print(f"\n[信息] 公开字段/属性（角色名，允许）：{public_cnt}")
tot = len(priv_bad) + len(multi) + len(node_bad) + len(set(node_case)) + len(shadow_bad) + len(overlay_bad) + len(field_letter_bad)
print(f"==> 应改：{tot} 条（私有字段 {len(priv_bad)} / 多名称类型 {len(multi)} / 节点引用 {len(node_bad)} / 节点名 {len(set(node_case))} / 遮蔽成员 {len(shadow_bad)} / _p_ 叠加 {len(overlay_bad)} / 字段单字母 {len(field_letter_bad)}）")
sys.exit(1 if (should_fail and tot) else 0)
PY
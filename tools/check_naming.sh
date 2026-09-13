#!/usr/bin/env bash
# 标识符命名契约检查（N16）——「同物同名」的机械校验。
#   规则（见 docs/BEST_PRACTICES_BASELINE.md「标识符命名契约」）：
#     ① 私有字段（_x）名 = "_" + 类型名 snake；公开字段/属性 = 角色名（对外 API，允许）
#     ② 同一类型不应有多个私有字段名（同物不同名）
#     ③ @onready 节点引用名 = 节点名 snake（节点名本身是内置类名时跳过）
#     ④ 节点名 PascalCase（R15）
# 用法: bash tools/check_naming.sh [--fail]   （默认只报告；--fail 时有违规 exit 1）
set -e
cd "$(dirname "$0")/.."
python3 - "$@" <<'PY'
import sys, re, os, collections

should_fail = "--fail" in sys.argv
ROOTS = ["scripts", "data", "test"]

def files(root):
    for dp, _dn, fn in os.walk(root):
        if ".godot" in dp:
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
                        if name != "_" + snake(typ):
                            priv_bad.append((p, i, name, typ, "_" + snake(typ)))
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

multi = sorted((t, sorted(ns)) for t, ns in priv_names.items() if len(ns) > 1)

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
print(f"\n[信息] 公开字段/属性（角色名，允许）：{public_cnt}")
tot = len(priv_bad) + len(multi) + len(node_bad) + len(set(node_case))
print(f"==> 应改：{tot} 条（私有字段 {len(priv_bad)} / 多名称类型 {len(multi)} / 节点引用 {len(node_bad)} / 节点名 {len(set(node_case))}）")
sys.exit(1 if (should_fail and tot) else 0)
PY
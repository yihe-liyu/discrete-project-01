#!/usr/bin/env bash
# 内核 vendor（M0b）—— 从重建版（内核开发环境）同步 scripts/kernel/，可复现、可校验。
#   用法: bash tools/vendor_kernel.sh          同步写入
#         bash tools/vendor_kernel.sh --check  只查漂移（有漂移 exit 1）
#   上游可用 REBUILD=/path 覆盖（默认 ../1-st-touhou-star-rebuild）
#
# vendor = 复制上游 + 两处**规范化**（见 scripts/kernel/README.md）：
#   ① 删 BulletRenderer 注入（内核本体不引用宿主渲染器类型）
#   ② 去行尾空白（跟随宿主风格；原项目 A11 已全仓清理）
# .uid 是**项目本地**的（Godot 生成、uid:// 引用指向本工程），不参与复制/比较，只清理孤儿。
set -e
cd "$(dirname "$0")/.."
exec python3 - "$@" <<'PY'
import sys, os, re

REBUILD = os.environ.get("REBUILD", "../1-st-touhou-star-rebuild")
VENDOR = "scripts/kernel"
CHECK = "--check" in sys.argv

# 上游 → vendor 的映射（只搬内核；defs/ 只取两个弹型，bullet/ 不取 renderer）
KERNEL_FILES = [
    ("scripts/bullet/bullet_system.gd", "bullet_system.gd"),
    ("scripts/defs/bullet_type.gd", "bullet_type.gd"),
    ("scripts/defs/effect_type.gd", "effect_type.gd"),
]
for d in ("behavior", "collision"):
    src = os.path.join(REBUILD, "scripts", d)
    for n in sorted(os.listdir(src)):
        if n.endswith(".gd"):
            KERNEL_FILES.append((os.path.join("scripts", d, n), os.path.join(d, n)))

UP_BLOCK = """# ==== ⓪ 节点装配：把自身注入直接子级视图（R2）====

## 父 → 子注入：BulletRenderer 依赖弹池，由弹池在 _ready 下发（不在 renderer 里摸父级）。
func _ready() -> void:
	setup_renderers()


## 幂等；只扫**直接子级**（组合，不是全树搜），对 N 个阵营批次都成立。
func setup_renderers() -> void:
	for child in get_children():
		if child is BulletRenderer:
			child.setup(self)
"""
VENDOR_BLOCK = """# ==== ⓪ 节点装配 ====
# KERNEL-VENDOR(S0)：已删除 BulletRenderer 注入（上游的 _ready / setup_renderers）。
# 内核本体不引用宿主渲染器类型（R2/R9）；原项目渲染由 adapter 负责——S2 把本池快照喂给 BulletMultiMesh。
"""

def normalize(text):
    return "\n".join(l.rstrip(" \t") for l in text.split("\n"))

def transform(rel, text):
    if rel == "bullet_system.gd":
        if VENDOR_BLOCK in text:
            return text
        if UP_BLOCK not in text:
            raise SystemExit("vendor: 上游找不到 ⓪ 节点装配块（结构变了？）")
        text = text.replace(UP_BLOCK, VENDOR_BLOCK)
    return normalize(text)

drift = []
for up_rel, v_rel in KERNEL_FILES:
    up, vp = os.path.join(REBUILD, up_rel), os.path.join(VENDOR, v_rel)
    if not os.path.exists(up):
        raise SystemExit(f"vendor: 上游缺文件 {up}")
    want = transform(v_rel, open(up, encoding="utf-8").read())
    have = open(vp, encoding="utf-8").read() if os.path.exists(vp) else None
    if have != want:
        drift.append(v_rel)
        if not CHECK:
            os.makedirs(os.path.dirname(vp), exist_ok=True)
            open(vp, "w", encoding="utf-8").write(want)

# 孤儿 .uid（.gd 已不存在 / 已改名）
orphans = []
for dp, _dn, fn in os.walk(VENDOR):
    for n in fn:
        if n.endswith(".gd.uid") and not os.path.exists(os.path.join(dp, n[:-4])):
            orphans.append(os.path.join(dp, n))
            if not CHECK:
                os.remove(os.path.join(dp, n))

HOST = ["GameState", "SaveData", "EntityRegistry", "PlayerResources", "BulletData", "BossData",
        "EnemyData", "PlayerData", "PhaseData", "Boss", "Enemy", "Player", "Item", "GameConfig",
        "AssetRegistry", "AudioManager", "GameEvents", "GameManager", "RNG", "FxPool",
        "MissCircleLayer", "BulletManager", "StageRuntime", "StageContext", "BulletMultiMesh",
        "LaserEngine", "DeathClear", "BulletRenderer"]
pat = re.compile(r"\b(" + "|".join(HOST) + r")\b")
viol = []
for dp, _dn, fn in os.walk(VENDOR):
    for n in sorted(fn):
        if not n.endswith(".gd"):
            continue
        p = os.path.join(dp, n)
        for i, line in enumerate(open(p, encoding="utf-8").read().splitlines(), 1):
            m = pat.search(line.split("#")[0])
            if m:
                viol.append(f"  {p}:{i}  {m.group(1)}")

print(f"vendor: 上游 = {REBUILD}（{len(KERNEL_FILES)} 个 .gd；.uid 属项目本地，不参与）")
if drift:
    print(f"[漂移] {len(drift)} 个 .gd" + ("（--check 不写入）" if CHECK else " → 已同步"))
    for d in drift:
        print("  " + d)
else:
    print("[漂移] 0 —— 与上游一致（除两处 vendor 规范化）")
if orphans:
    print(f"[孤儿 .uid] {len(orphans)}" + ("（--check 不删）" if CHECK else " → 已删"))
    for o in orphans:
        print("  " + o)
if viol:
    print(f"[守卫] ❌ 内核出现宿主引用 {len(viol)} 处：")
    for v in viol:
        print(v)
    sys.exit(1)
print("[守卫] ✅ 内核 0 宿主引用（R2/R9）")
if CHECK and (drift or orphans):
    sys.exit(1)
PY

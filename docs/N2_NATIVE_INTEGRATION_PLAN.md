# N2-real 接入计划：原生弹幕系统替换 BulletSystem

> **状态**：进行中。N2.1 完成（原生数据模型 + 批量 API + ~55×）；**N2.2 积分段完成**（原生 integrate 5.9×，桥接子类实现，不碰 vendor 内核）。
> **相关**：`docs/GDEXTENSION_KERNEL_DESIGN.md` §10（N0–N5）；`gdextension/`。

## 目标

把 `KernelBulletBackend.system` 从 GDScript `BulletSystem`（vendor 快照）换成**原生系统**，
同时**保持桥接 / 渲染 / 物理看到的 API 不变**，可开关、可回退。

## 为什么不能一步到位

`scripts/kernel/bullet_system.gd`（762 行 / ~70 public）同时管：存储 · 积分 · 剔除 · 宽相 ·
行为槽 · 特效行 · 渲染快照 · RNG。其中：

- **存储 + 积分 + 剔除 + 宽相 + 渲染快照** → 原生（N2/N4，已实测 ~55×）。
- **行为槽** → 需 N3(VM)。在此之前行为仍在 GDScript，**必须批量读/写**原生数据，
  否则逐弹跨语言边界会把原生收益吃掉。

## 步骤

- **N2.1 ✅（已完成）** 原生 `DanmakuStore`：per-bullet `type/faction/color` +
  `spawn_batch` + `fill_multimesh`。基准：6000 弹合计 **0.156ms**（GDScript 8.39ms，~54×）。
- **N2.2 实测教训（2026-09-13，已回退）**：先试「只把逐实例填充搬原生」——
  同进程对照（`tools/bench_render.gd`，6000 弹）：原生 **8.19ms** vs GDScript **9.31ms**，**仅 1.14×**。
  根因：开销在 **GDScript 侧的分组（Dictionary + 每弹 append）+ 每弹 `rotation_for` / `get_render_fade`**，
  不在 `set_instance_*` 调用本身；只搬填充还多了 Array→Packed 转换成本。
  **结论**：N4-real 必须把**整段 `_sync_kernel`**（分组 + 旋转 + fade + 填充）搬原生 ——
  原生需要 per-type `texture_handle / tint_mode / kind / follow_dir / dir_offset` + 宿主 MultiMesh 表。
- **N2.2（积分段）✅（2026-09-13）** 原生无状态 `DanmakuStore.integrate_batch`（积分 / 寿命 /
  出生相位 / 剔除 → 返回新数组 + `dead`），由桥接子类
  `scripts/kernel_bridge/kernel_native_system.gd`（**继承 vendored `BulletSystem`，只覆写 `_physics_process`**）
  同序重放 despawn。**不碰 vendor 内核 → 不触发 re-vendor**；行为 / 碰撞 / 渲染看到的仍是 `BulletSystem`。
  `KernelBulletBackend.use_native` 开关 + 无扩展自动回退。**实测 6000 弹 0.699 → 0.118ms/帧（5.9×）**；
  parity `test_native_integrate` 2/2（含 `native_frames` 覆盖断言）。
- **边界铁律（N2.2 实测）**：原生逐次 `get_position(i)` **110ns** vs GDScript `Packed[i]` **13ns**；
  批量 `get_positions()` 快照 15ns。→ **搬存储必须配套批量快照 / 写回**，逐次转发反而更慢。
- **N2.2（存储段核心 ✅ 2026-09-14）** 原生 `DanmakuStore` 持有真实 SoA（`pos/vel/type/faction/color` + **`life/fx/timer`**）+ `spawn/despawn/clear` + 完整 `integrate`（寿命/相位/位移/计时/剔除），与 GDScript 内核 **1:1**（`test_native_storage` 2/2：100 弹 × 180 帧逐位一致）。
  **未做**：原生宽相 `query_circle`（需 per-row hitbox 一并原生）、**原生行为执行器（L3）**、接入游戏。
  **注**：存储段与 L3 是同一原生系统的两面 —— 原生持有 SoA 后必须由原生执行描述符，否则 GDScript 行为逐弹跨界必亏。
  → 有空间，但必须按上面的批量约定设计。
- **N2.3** 批量行为桥：`get_behavior_inputs()` / `apply_behavior_outputs()`（Packed 数组），
  每帧**常数次**跨界；GDScript 行为循环照跑（成本仍在，等 N3）。
- **N3** 行为 / VM 原生：`kernel_port()` → program；删 `_port_by_sig`。
- **N4-real ✅（2026-09-13，渲染同步部分）** 原生 `DanmakuRenderBridge`：
  类型表（`tex_key_base` 含 Atlas region hash / `tint_mode` / `kind` / `follow_dir` / `dir_offset`）
  + `group(count, SoA, fade)` + `fill` → **整段渲染同步 6.5×**（6000 弹 7.19→1.10ms）。
  `BulletMultiMesh.use_native_sync` 开关 + GDScript 回退。余：图集资源本身（S13）按需再做。
- **人类试玩验收 ✅（2026-09-13）**：开关开、扩展构建下真人试玩 —— 弹朝向 / 激光淡出 / 图集弹**全部正确**（无串图、无错向）。**N4-real 渲染路径关闭**（自动化盲区已由人眼兜底）。

## 开关与回退

- `BulletManager` 加 `use_native`（默认 `false`，直到 N2.2 功能对齐）。
- 渲染：`BulletMultiMesh` 走原生 `fill_multimesh` 或 GDScript `_sync_kernel`。
- 对照：`tools/bench_danmaku.gd`（GDScript） vs `tools/bench_native.gd`（原生）。

## 验收

- `verify.sh` 全绿；真实舞台在 `use_native` 开 / 关下跑同一段弹幕，帧时间对比。

---

## 终局决策（2026-09-13）：扩展为**必需**，GDScript 内核转为过渡脚手架

- **决定**：本项目接受「跑源码必须构建扩展」。→ GDScript `BulletSystem`（vendor 快照）与重建版从
  「永久 fallback」降为**过渡**：**N2 存储段 + N3 行为**完成后删除；`use_native` 的「无扩展回退 GDScript」
  分支随之移除。
- **玩家侧零影响（澄清）**：Godot 导出把 `.so` 打进包，**玩家从不编译**。要补的是**多平台构建**
  （当前仅 linux x86_64；Windows / macOS 需进 CI）。
- **创作者方便 = 硬目标**：从源码跑需一次构建（`./tools/build_gdextension.sh`，需 SCons + 工具链）。
  便利路线**待拍板**：① 一键 setup 脚本；② 内置换平台预编译产物；③ 提供带扩展的编辑器构建。
- **内容面不原生**：N3 只搬**执行器**；`kernel_port()` / 工作台 / 内容脚本等**创作者接口保持高层 GDScript**，
  不让原语泄漏进创作面。
- **依赖顺序**：N2 存储段 → N3 行为 → 删 GDScript 内核 / 归档重建版（M4）。
  在此之前 GDScript 内核仍是**在跑的实现**，不得半途删。

---

## 拆除清单（N3 的验收尾巴，2026-09-13 登记）

> 铁律：旧实现必须等新实现**全覆盖**才能删。**N3 单独不简化；N3 + 拆除才简化。**
> **M4 并进本清单**（不给将死的实现单独选家）。**建议：N3 之前不做零碎删除**（收益低、伤过渡期 DX）。

| 删什么 | 量 | 门槛 |
|---|---|---|
| `scripts/kernel/**`（GDScript 内核整棵） | **1219 行** | N2 存储段 + N3 全覆盖 |
| `scripts/kernel_bridge/behavior/**` + `_port_by_sig` + `kernel_port` | **273 行** + 2 处 | N3 |
| `_sync_gdscript`（渲染回退） | ~56 行 | 扩展必需 + N4-real |
| `use_native` / `is_native_ready` 回退分支 | 7 处 | 内核删除后 |
| `KernelNativeSystem extends BulletSystem` scaffold | ~62 行 | 原生系统直接当内核 |
| rebuild 仓库（14 内核 .gd + 94 测试） + `tools/vendor_kernel.sh` | 120 行 + 一仓库 | 同上 |
| **保留**：`kernel_bridge/` 宿主耦合（伤害 / 擦弹 / bomb / Boss） | **~688 行** | **不是重复** |

**诚实提醒**：原生会长到 ~800–1200 行接替，**行数未必大减**；真收益 = **双维护消失 + 一处改 + 少一个仓库与 vendor 纪律**。

**待定**：`BulletType` / `EffectType` 在 `scripts/kernel/**` 删除后归位何处（原生 `DanmakuType`？还是搬 `scripts/data/`）。

---

## L3.5 接入方案（2026-09-14）

**目标量化**（`tools/bench_behavior_native.gd`，6000 弹）：

| 执行器 | ms/帧 |
|---|---|
| GDScript 行为（世界加速） | ~4.25 |
| **原生 `behavior_tick` world_accel** | **0.151** |
| **原生 `behavior_tick` homing** | **0.279** |

→ 行为段 **~15–28×**；全段接入后 6000 弹脚本侧 ≈ **~1.8–2.0ms**（现 5.8）。

**核心难点：两套存储的权威归属。** 现有 `BulletSystem`（GDScript）是渲染 / 物理 / 调试的唯一数据源；原生 store 是行为执行的存储。

### 方案 A（推荐）：原生权威 + GDScript 只读快照

- 原生 store 成为**唯一存储**；spawn / despawn / 积分 / 行为全原生。
- `BulletSystem` 退化为**快照视图**：每帧 pull 原生数组供渲染 / 物理 / 调试**只读**。
- GDScript 侧写（物理 despawn / `set_render_fade`）→ 经原生 API 回写。
- 原生需补：`query_circle` / `hit_test` / `is_grazed` / `mark_grazed`（`despawn` 已有）。
- 消费方改动：`BulletMultiMesh` / `KernelBulletPhysics` / `MarisaLaserFade` / `debug_drawer`。
- **代价大、但一次到位**：两套存储消失 → 正是 L4 拆除的前提。

### 方案 B（不推荐）：双存储 + 每帧同步

保持 `BulletSystem` 为权威、原生 store 作行为 scratch（commit/pull 数组）。改动小，但引入**永久同步层**，L4 拆不掉 —— 违背精简目标。

### 分步（方案 A）

1. **L3.5-1 ✅（2026-09-14）** 原生 `query_circle` / `hit_test` / `grazed`（`test_native_collision` 4/4 / 293 断言）。线性扫描（同序），宽相网格按需再上。
2. **L3.5-2 ✅（2026-09-14）** `LifecycleCatalog`：`move + params` → `BulletLifecycle`（10 个 move 全覆盖，内容零改动）+ 签名缓存（`test_lifecycle_catalog` 5/5）。
3. **L3.5-3** 原生 store 替 `KernelNativeSystem`；`BulletSystem` 退化快照视图。**(3a ✅ 2026-09-14)**：原生无状态 `behavior_batch`（数组进/出 + dead 重放）已就绪（`test_native_behavior_batch` 2/2）；**3b**：bridge 接入（映射 → 原生批，替 `BehaviorProcessor`）。
4. **L3.5-4** 消费方（render / physics / laser / debug）改读原生。
5. **L3.5-5** 事件 drain（emit / sfx / call → `queue_spawn` / sfx / 内容回调）。
6. **L3.5-6** 真实舞台开机 + 试玩。
7. **L4** 拆除（删 1219 + 273 + rebuild）。

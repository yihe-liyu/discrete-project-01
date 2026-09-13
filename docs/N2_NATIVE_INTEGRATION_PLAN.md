# N2-real 接入计划：原生弹幕系统替换 BulletSystem

> **状态**：进行中。N2.1 已完成（原生数据模型 + 批量 API + ~55× 实测）。
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
- **N2.2** 原生 `DanmakuSystem`：补齐桥接 / 渲染 / 物理用到的 `BulletSystem` 子集
  （spawn / despawn / get_active_count / get_positions / get_velocities / get_colors /
  get_type_indices / get_factions / query_circle / hit_test / cull_rect / get_delta）。
  `KernelBulletBackend` 加 `use_native` + 回退。
- **N2.3** 批量行为桥：`get_behavior_inputs()` / `apply_behavior_outputs()`（Packed 数组），
  每帧**常数次**跨界；GDScript 行为循环照跑（成本仍在，等 N3）。
- **N3** 行为 / VM 原生：`kernel_port()` → program；删 `_port_by_sig`。
- **N4-real** 图集 + 纹理句柄（M3 ③ 插座）。

## 开关与回退

- `BulletManager` 加 `use_native`（默认 `false`，直到 N2.2 功能对齐）。
- 渲染：`BulletMultiMesh` 走原生 `fill_multimesh` 或 GDScript `_sync_kernel`。
- 对照：`tools/bench_danmaku.gd`（GDScript） vs `tools/bench_native.gd`（原生）。

## 验收

- `verify.sh` 全绿；真实舞台在 `use_native` 开 / 关下跑同一段弹幕，帧时间对比。

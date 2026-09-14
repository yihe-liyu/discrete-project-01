# M3 决策：渲染 / 纹理归属

> **状态**：✅ **已拍板 ③（2026-09-13）**。本文保留作决策记录。
> **前置**：M2 已完成（词汇合一）；试玩已过一轮（修掉 5 个运行期 bug）。
> **相关**：`docs/archive/NEW_KERNEL_REFACTOR_PLAN.md` §16.3 / §16.5（M3 与判据）；`docs/GDEXTENSION_KERNEL_DESIGN.md` §6 / §10（N4）。

---

## 1. 现状

- 内核 `BulletType` **有意不带渲染**（决策备忘 §10.4）：它只带 `texture_key`（图集语义）。
- 宿主 `KernelBulletBackend` 维护 `_texture_by_index: Array[Texture2D]`（内核弹型下标 → 贴图）；`BulletMultiMesh` 每帧按 `type_index` 查表 → 分组 → MultiMesh 批次。
- 这是 `scripts/kernel_bridge/` 里**最后一张 `*_by_index` 侧表**（`_type_by_sig` / `_damage_by_index` / `_hit_sfx_by_index` 已随 M1/M2 删除）。

## 2. 三个选项

| 选项 | 含义 | 代价 | 与终局的关系 |
|---|---|---|---|
| ① 维持 hybrid | 旁表留着、接受；从「融合完成」判据里去掉 `_by_index = 0` | 0 | 渲染归属推迟到 N4，但判据变成一句永不达标的空话 |
| ② 内核带 renderer + 图集 | 渲染进内核，内容转图集（S13） | **高**：内核改动要回重建版 + vendor + tag；图集管线 | 与「内核克制、不带渲染」的既有决策冲突；**提前重渲染** |
| ③ **纹理句柄（正式化）** | 承认 `type_index` 就是**纹理句柄**、`texture_for_index()` 就是**宿主侧渲染插座**——它不是债，是设计好的 seam | **近 0**（命名 / 契约 / 文档） | **与 §6 完全一致**：原生 `RenderBridge` 保留「句柄 → 独立 PNG / AtlasTexture」的能力 |

## 3. 建议：选 ③

1. **§6 早已写明终局形态**：「纹理句柄抽象，同时支持独立 PNG 与 `AtlasTexture`」——今天的 `_texture_by_index` **就是那个抽象的 GDScript 版**。差别只在"叫它侧表、还是叫它插座"。
2. 选 ① 会让 §16.5 的 `_by_index = 0` 判据**永远不达标**，也丢掉"这是设计 seam"这个信息——下一轮审查又会把它当债列出来。
3. 选 ② 是**提前重渲染**：触发条件（≥6000 弹 / 实打实卡顿）没到；内核现在 0 宿主引用很干净，把渲染塞回内核会破坏这份克制。
4. ③ **零内核改动** → 不回重建版、不 vendor、不 tag，与 M 线流程硬约束（§16.4）无冲突。

## 4. 选 ③ 具体做什么（很小）

1. **契约/命名**：在基线渲染契约与 `scripts/kernel_bridge` 注释里，把 `_texture_by_index` / `texture_for_index()` 明确为 **render socket（渲染插座）**；`BulletType.type_index` = **纹理句柄**。命名保持 `值_by_键`（本就合规），不改名。
2. **改判据**：§16.5 的 `_by_index = 0` 收窄为「**类型 / 端口 / 伤害**侧表 = 0」；**纹理句柄表按设计保留**，由 N4 换成原生实例缓冲。
3. **文档**：本页 + `GDEXTENSION_KERNEL_DESIGN` §6 交叉引用。
4. **不做**：不改内核、不做图集、不动 `BulletMultiMesh` 分组逻辑；`_port_by_sig` 归 VM / 端口收口（另一条线）。

## 5. 拍板

- [x] **选 ③（2026-09-13）**：判据收窄 + 桥接注释正名
- [ ] 选 ①
- [ ] 选 ②

> 落地：`docs/archive/NEW_KERNEL_REFACTOR_PLAN` §16.1/§16.3/§16.5 已更新；`KernelBulletBackend` 注释正名为「渲染插座」；基线融合 bullet 同步。

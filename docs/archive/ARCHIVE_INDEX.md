# 归档索引（docs/archive/）

> **这是什么**：`docs/archive/` 里每一份的**一句话价值** + 现在还能被谁引用。目的是"要翻旧账时知道翻哪本"，
> 免得整个目录变成谁也不敢删、谁也不看的黑洞。
>
> **归档 ≠ 作废**：这里是**只增不改的历史**（决策记录 / 过期快照 / 按月日志）。要改结论请在当前文档里改，
> 别回头改归档 —— 归档的价值就是"当时确实这么想"。
> **规则**：搬进 `docs/archive/` 只**搬**不**删**；`LOG_*.md` 由 `python3 tools/log_archive.py --archive` 自动维护（时间正序）。

| 文件 | 一句话价值 | 状态 | 现在还被谁引用 |
|---|---|---|---|
| [SPEC.md](SPEC.md) | 系统规格书 v2.0（2026-06 逆向整理，最后校验 2026-08）：**迁移前**的代码真实现状 —— 旧文件树 / 命名 / 各系统清单 | 🕰 过期（内核迁移前） | `ARCHITECTURE.md` §8（历史出处） |
| [REFACTORING_PLAN.md](REFACTORING_PLAN.md) | 2026-07「把 AI 糊出来的架构打磨成可持续引擎」专项（阶段 0–3）—— **今天这套分层是怎么来的** | 🕰 已完成 | `ARCHITECTURE_ROADMAP.md`（互链） |
| [ARCHITECTURE_ROADMAP.md](ARCHITECTURE_ROADMAP.md) | 2026-07-31 全系统图景 + 改进路线 v5（阶段 0–3 完成时的横切视图）；**「内容工作台演进」专节**是工作台设计的来龙去脉 | 🕰 已完成 | `README.md`（内容工作台一节，注明"已归档"） |
| [STAGE_FLOW_PLAN.md](STAGE_FLOW_PLAN.md) | 编排 / 对象自治 / 身份归位 / 注入服务的**七步路线**：Step 1 / 3 / 4 已落，**Step 2（书签原生）、Step 6（`ctx.background`）仍是待办出处**，5 / 7 暂缓 | 🚧 部分未做（**仍活**） | 基线「🔴 待改进」、`ARCHITECTURE.md` §7 |
| [NEW_KERNEL_REFACTOR_PLAN.md](NEW_KERNEL_REFACTOR_PLAN.md) | 内核迁移的**方案 / 契约 / 决策**（Strangler 绞杀者）：§15.6 触发条件、§16 / §16.5 **结构性判据**（0 类型映射 / 0 内容签名侧表）至今是判据 | ✅ 方案已执行完 | `GDEXTENSION_KERNEL_DESIGN.md`、`BASELINE_EVIDENCE.md` |
| [N2_NATIVE_INTEGRATION_PLAN.md](N2_NATIVE_INTEGRATION_PLAN.md) | 原生弹幕系统替换 `BulletSystem` 的**接入 + 拆除清单 + 终局决策**；L3.5 每一步的验收数字（4a / 4b-pre / 4e / 4f） | ✅ 已完成（2026-09-14） | `GDEXTENSION_KERNEL_DESIGN.md`、`LIFECYCLE_MODEL.md`、`ARCHITECTURE.md` §7、`kernel_bullet_host.gd` 的报错文案 |
| [M3_TEXTURE_OWNERSHIP_DECISION.md](M3_TEXTURE_OWNERSHIP_DECISION.md) | M3 决策记录：**纹理插座不是债**（拍板 ③ 纹理句柄）—— 防止后人"顺手修掉"设计 seam | ✅ 已拍板 | 基线「其他契约」、`TODO_TEMP` |
| [SPELL_SYSTEM_TARGET.md](SPELL_SYSTEM_TARGET.md) | 符卡系统目标蓝图：卡定义 / 卡记录分离 + **uid 当身份证** + 三张表各司其职 | 🕰 蓝图早于实现（核心已由 `boss_catalog.gd` 落地） | `ARCHITECTURE.md` §7 |
| [CREATION_STATION_V1.md](CREATION_STATION_V1.md) | 创作台（工作台）设计 V1：与作者逐条拍板 —— **预览沙盒，不是编辑器** | 🕰 已被实现/演进取代 | —（工作台现状看 `scripts/workbench/`） |
| [REBUILD_REPO_STATUS.md](REBUILD_REPO_STATUS.md) | 重建版仓库归档登记：`1-st-touhou-star-rebuild` 完成历史使命；**「重建版改 → tag → vendor」流程已废止** | 📦 归档登记 | `TODO_TEMP.md`（内核方向） |
| [BEST_PRACTICES_BASELINE_OLD_AUDIT.md](BEST_PRACTICES_BASELINE_OLD_AUDIT.md) | 当前基线的前身（只记状态 + 旧 🔴 TODO 审计）—— 与今天基线对照可看出判据怎么演进的 | 🕰 已被取代 | 基线头部（说明出处） |
| [LOG_2026-09.md](LOG_2026-09.md) | 滚动日志按月归档（**内文时间正序**，可 `grep`） | 📚 历史底账 | `BEST_PRACTICES_LOG.md` 顶部索引 |
| [LOG_2026-09_kernel_migration.md](LOG_2026-09_kernel_migration.md) | 内核迁移期日志（L1–L3.5 / N2，2026-09-13~16）：含已废止的 vendor 流程与当时的踩坑 | 📚 历史底账 | `BEST_PRACTICES_LOG.md` 顶部索引 |
| [gdext_spike_probe/](gdext_spike_probe/) | 原生内核**探针**存档（2026-09-22）：从 216M 的 `_gdext_spike/` 与一个误建目录里抽出的纯源码 | 📦 归档登记 | — |

## 怎么往里加

1. **文档过时/被取代** → 搬进来（`git mv`），在本文加一行；原位置的引用改成 `docs/archive/...`。
2. **日志超期** → 交给 `python3 tools/log_archive.py --archive`（别手搬，索引会不一致）。
3. **别删**：删掉的决策过两年会被人重新做一遍。

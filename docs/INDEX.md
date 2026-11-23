# 文档索引（单一真源）

> **这一页只回答三件事**：哪个问题该看哪份文档、谁是权威、这份文档现在是否还有效。
> 新增 / 迁移 / 废弃文档时，先改本页，再改正文。`README.md` 只做入口，不再复制整张文档表。

## 0. 先读什么

| 你要做的事 | 先读 | 再查 |
|---|---|---|
| 第一次进项目 / 跑起来 | [README](../README.md) | [ARCHITECTURE](ARCHITECTURE.md) §1–3 |
| 改玩法 / 时间 / 状态 / 回放 | [ARCHITECTURE](ARCHITECTURE.md) + [REPLAY_MODEL](REPLAY_MODEL.md) | [BASELINE](BEST_PRACTICES_BASELINE.md) |
| 加关卡 / 敌人 / Boss / 符卡 / 对话 | [CONTENT_GUIDE](../CONTENT_GUIDE.md) | [内容作者契约](CONTENT_AUTHORING_CONTRACT.md) |
| 改弹幕 / 原生 behavior | [DANMAKU_API](DANMAKU_API.md) | [NATIVE_BEHAVIOR_PACK](NATIVE_BEHAVIOR_PACK.md) |
| 改测试 / 查哪条测试保护什么 | [TEST_INDEX](TEST_INDEX.md) | [BASELINE](BEST_PRACTICES_BASELINE.md) |
| 改路线 / 难度链 | [ROUTE_MODEL](ROUTE_MODEL.md) | [CONTENT_GUIDE](../CONTENT_GUIDE.md) §五 |
| 改背景 / 路径预览 | [BACKGROUND_TEMPLATE](BACKGROUND_TEMPLATE.md) · [TELEGRAPH_PREVIEW](TELEGRAPH_PREVIEW.md) | [ARCHITECTURE](ARCHITECTURE.md) §7 |
| 查性能预算 / 实测 | [PERFORMANCE_BUDGET](PERFORMANCE_BUDGET.md) | `tools/bench_*` |
| 查“为什么当时这么改” | [BEST_PRACTICES_LOG](BEST_PRACTICES_LOG.md)（历史，只看索引） | [archive](archive/ARCHIVE_INDEX.md) |

## 1. 权威矩阵（同一信息只写一处）

| 问题 | 权威 | 说明 |
|---|---|---|
| 项目是什么 / 怎么跑 / 当前进度 | [README](../README.md) | 入口与状态摘要；数字徽章由 `tools/check_docs.py` 校验 |
| 系统怎么分层 / 谁拥有什么 / tick 内顺序 | [ARCHITECTURE](ARCHITECTURE.md) | 架构单一真源 |
| replay 为什么可能不一致 / 状态边界 / 失败分类 | [REPLAY_MODEL](REPLAY_MODEL.md) | replay 单一真源 |
| 写内容的具体步骤 / 例子 / 对话 DSL | [CONTENT_GUIDE](../CONTENT_GUIDE.md) | 内容教程 + 参考 |
| 内容边界 / 六个对象 / 加卡路径 | [CONTENT_AUTHORING_CONTRACT](CONTENT_AUTHORING_CONTRACT.md) | 规范；教程不在这里重复 |
| 工程红线 / 命名 / 注入 / 会话 / 校验 | [BASELINE](BEST_PRACTICES_BASELINE.md) | 硬契约；状态表只留判据 |
| 测试文件 / 用例数 / 白盒预算 | [TEST_INDEX](TEST_INDEX.md) | 测试地图；抬头数字机械校验 |
| 弹幕字段 / behavior / 发射 API / 素材 key | [DANMAKU_API](DANMAKU_API.md) | §7.1/§7.2 由 `check_docs.py` 校验 |
| 原生 behavior pack 的写法 | [NATIVE_BEHAVIOR_PACK](NATIVE_BEHAVIOR_PACK.md) | C++ 侧模型与注册 |
| 路线 / 难度 / 记录主键 | [ROUTE_MODEL](ROUTE_MODEL.md) | StageRoute 模型 |
| 性能上限 / 实测口径 | [PERFORMANCE_BUDGET](PERFORMANCE_BUDGET.md) | 未实测项必须标“未验证” |
| 新 3D 背景的起点 | [BACKGROUND_TEMPLATE](BACKGROUND_TEMPLATE.md) | 继承模板，不复制 |
| 路径预览 / telegraph | [TELEGRAPH_PREVIEW](TELEGRAPH_PREVIEW.md) | 预览能力与边界 |
| 历史决策 / 过期快照 | [BEST_PRACTICES_LOG](BEST_PRACTICES_LOG.md) + [archive](archive/ARCHIVE_INDEX.md) | 只增不改；不要从历史反推现状 |

## 2. 当前有效文档

### 2.1 入口与契约

- [README](../README.md) — 项目入口、状态、快速开始、验证命令。
- [AGENTS](../AGENTS.md) — 本仓库给 AI / 开发者的工作约定（读什么、改完跑什么）。
- [ARCHITECTURE](ARCHITECTURE.md) — 分层、组合根、所有权、tick/事件顺序、代码地图、结构债。
- [REPLAY_MODEL](REPLAY_MODEL.md) — replay 的定义、模拟边界、状态所有权、录制/回放生命周期、失败分类、调试流程。
- [BASELINE](BEST_PRACTICES_BASELINE.md) — 工程红线、命名、注入、会话、校验。
- [TEST_INDEX](TEST_INDEX.md) — 测试地图与分层小计。

### 2.2 内容

- [CONTENT_GUIDE](../CONTENT_GUIDE.md) — 内容制作教程（关卡 / 敌人 / Boss / 阶段 / 对话）。
- [CONTENT_AUTHORING_CONTRACT](CONTENT_AUTHORING_CONTRACT.md) — 内容作者规范（六个对象、五条边界、最小路径）。
- [ROUTE_MODEL](ROUTE_MODEL.md) — 难度路线模型。
- [BACKGROUND_TEMPLATE](BACKGROUND_TEMPLATE.md) — 3D 背景最小模板。
- [TELEGRAPH_PREVIEW](TELEGRAPH_PREVIEW.md) — 路径预览。

### 2.3 弹幕 / 内核 / 性能

- [DANMAKU_API](DANMAKU_API.md) — `SpawnSpec` / behavior / 发射 API / 素材 key / 陷阱。
- [NATIVE_BEHAVIOR_PACK](NATIVE_BEHAVIOR_PACK.md) — 原生 behavior pack 写法。
- [PERFORMANCE_BUDGET](PERFORMANCE_BUDGET.md) — CPU / GPU / overdraw 预算与实测。

### 2.4 历史

- [BEST_PRACTICES_LOG](BEST_PRACTICES_LOG.md) — 滚动历史日志（正文只留近期，旧条目在 `archive/LOG_*.md`）。
- [archive/ARCHIVE_INDEX](archive/ARCHIVE_INDEX.md) — 归档索引；`archive/` 是只增不改的历史。

## 3. 已迁出的文档

以下文档**不再是现行工程文档**，已移入 `docs/archive/`，只作为 2026-10 / 2026-11 的历史审计快照保留：

| 旧位置 | 新位置 | 为什么迁出 |
|---|---|---|
| `docs/CONTENT_PIPELINE_AUDIT.md` | [archive/CONTENT_PIPELINE_AUDIT.md](archive/CONTENT_PIPELINE_AUDIT.md) | 2026-10-17 的内容流程审查；创作台已退役，文中现状描述作废 |
| `docs/DANMAKU_GAP_AUDIT.md` | [archive/DANMAKU_GAP_AUDIT.md](archive/DANMAKU_GAP_AUDIT.md) | 2026-11-12 的弹幕表现力审计；引用的 lifecycle / pattern 已删除，且回放/哈希结论已过时 |

> 这两份文件里的“现状/缺口”不能当今天的待办；当前 replay 模型见 [REPLAY_MODEL](REPLAY_MODEL.md)，当前内容流程见 [CONTENT_GUIDE](../CONTENT_GUIDE.md) + [CONTENT_AUTHORING_CONTRACT](CONTENT_AUTHORING_CONTRACT.md)。

## 4. 维护规则

1. **单一真源**：同一个问题只在一份文档里回答；其他文档用链接，不复制。
2. **状态与规则分离**：`BASELINE` 只留规则/判据；每次实测数字、逐条证据进 `archive/` 或专门的实测文档。
3. **文档随代码走**：改 `class_name` / 测试 / 内容路径 / 命令时，同步本页与对应文档；`./tools/check_docs.py` 至少会抓 TEST_INDEX、README 徽章/链接、DANMAKU key 表。
4. **归档不删**：过期文档 `git mv` 到 `docs/archive/`，在 [ARCHIVE_INDEX](archive/ARCHIVE_INDEX.md) 加一行，并把旧链接改成新位置。
5. **临时文件不入库**：`TODO_TEMP.md`、`probe_*.log`、截图、`user://` 都是本地临时物，不是工程文档。

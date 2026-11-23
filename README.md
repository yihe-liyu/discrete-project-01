# 1st Touhou Star ~ Broadest and Narrowest

> 东方同人 STG 引擎 · Godot 4.7 · Discrete Project 第一作

[![Godot](https://img.shields.io/badge/Godot-4.7-%23478cbf)](https://godotengine.org)
[![Tests](https://img.shields.io/badge/GUT-766%20tests%20/%20114%20scripts-green)]()<!-- 手动徽章：数字口径见 docs/TEST_INDEX.md（改测试后同步这里） -->
[![CI](https://github.com/yihe-liyu/1st-touhou-star/actions/workflows/verify.yml/badge.svg)](https://github.com/yihe-liyu/1st-touhou-star/actions/workflows/verify.yml)
[![License](https://img.shields.io/badge/code-MIT-blue)](LICENSE)

<p align="center">
  <img src="东方星尘回封面.png" alt="东方星尘回封面" width="360">
</p>

---

## 🌙 这是什么

**「东方星尘回 ～ Broadest and Narrowest」** 是一个东方 Project 二次创作的同人弹幕射击（STG）引擎与游戏工程。

- 使用 **Godot 4.7** + GDScript 从零搭建
- 已实现完整的弹幕引擎：对象池、空间哈希碰撞、MultiMesh 批量渲染、激光系统、协程时间线
- 已有一个可玩的 **Stage 1**（道中 + Boss 卡摩瑞）
- 世界观与角色设定完整（共 9 位 Boss），见 [omake.txt](docs/reference/omake.txt)
- 这是作者 **YiHe** 的 **Discrete Project（离散系列）** 第一作

> 本仓库是作者在 AI 辅助下设计、开发与维护的东方同人 STG 引擎。代码与工程文档均由作者最终验收负责。

---

## 📊 当前状态

| 类别 | 进度 |
|------|------|
| 引擎 | ████████████████████ 95% |
| 关卡（6 面） | ████ 20%（Stage 1 可玩；Stage 2/3B 内容在制作中） |
| 美术 | ██████ 30% |
| 音效 | ██████ 30% |
| 叙事 | ██████████ 50% |
| 打磨/QoL | ██████████████ 70% |

- **已完成**：原生弹幕内核、Stage 1 道中 + Boss、难度路线、符卡 / 关卡练习、对话、Bomb、Replay 的录制/严格播放；Stage 1 → Stage 2 完整 run 已零分歧。
- **进行中**：Stage 2 / 3B 内容；`content_hash` 已接入，headless 快进 / 跨平台一致性仍在收尾。
- **未完成**：Stage 3A / 4 / 5 / 6 的完整内容、`content_hash`、headless 快进验证、完整 run 结算 / Continue。

状态与缺口的权威口径在 [BASELINE](docs/BEST_PRACTICES_BASELINE.md) 的 S 表 + [REPLAY_MODEL](docs/REPLAY_MODEL.md)；本页只做入口摘要。

---

## 📖 文档入口

> **先看 [docs/INDEX.md](docs/INDEX.md)**：它只回答“哪个问题看哪份、谁是权威、是否还有效”。
> 日常最短路径：写内容看 [CONTENT_GUIDE](CONTENT_GUIDE.md)，改玩法/回放看 [ARCHITECTURE](docs/ARCHITECTURE.md) + [REPLAY_MODEL](docs/REPLAY_MODEL.md)，改代码前扫 [BASELINE](docs/BEST_PRACTICES_BASELINE.md)。

| 任务 | 打开 | 提醒 |
|---|---|---|
| 跑游戏 / 跑测试 | 本页 · [TEST_INDEX](docs/TEST_INDEX.md) | `./tools/verify.sh` 是总门禁 |
| 加一个波次 / 一张符卡 | [CONTENT_GUIDE](CONTENT_GUIDE.md) §0 / §四 / §六 | 改完用符卡练习看手感；先跑 `tools/check_content.sh` |
| 加敌人 / 新 Boss / 新面 | [CONTENT_GUIDE](CONTENT_GUIDE.md) §三 / §四 / §八 · [CONTENT_AUTHORING_CONTRACT](docs/CONTENT_AUTHORING_CONTRACT.md) | **必须进 `stage_registry.tres` / `boss_registry.tres`** |
| 改弹幕飞行 / behavior | [DANMAKU_API](docs/DANMAKU_API.md) · [NATIVE_BEHAVIOR_PACK](docs/NATIVE_BEHAVIOR_PACK.md) | 先拼现成 behavior；新增 pack 才动 C++ |
| 写对话 | [CONTENT_GUIDE](CONTENT_GUIDE.md) 附录 D | 事件驱动收尾，不要用 `wait(秒)` 猜台词 |
| 改背景 / 路径预览 | [BACKGROUND_TEMPLATE](docs/BACKGROUND_TEMPLATE.md) · [TELEGRAPH_PREVIEW](docs/TELEGRAPH_PREVIEW.md) | 背景视觉线已冻结；只做结构/接口 |
| 改引擎 / tick / 回放 | [ARCHITECTURE](docs/ARCHITECTURE.md) · [REPLAY_MODEL](docs/REPLAY_MODEL.md) · [BASELINE](docs/BEST_PRACTICES_BASELINE.md) | 先看 tick 顺序与 replay 不变量 |
| 查“为什么当初这么改” | [BEST_PRACTICES_LOG](docs/BEST_PRACTICES_LOG.md) 索引 → [archive](docs/archive/ARCHIVE_INDEX.md) | 历史只解释过去，不定义现在 |

---

## ⚡ 快速开始

0. **先构建原生内核扩展（必需）** —— 未构建 = 无扩展 = 游戏无法启动（L3.5-4f 起扩展为必需）：
   ```bash
   git submodule update --init --recursive   # 首次：拉 godot-cpp
   ./tools/build_gdextension.sh              # 需 SCons + C++ 工具链
   ```
   > 玩家侧不受影响：导出的包内含 `.so` / `.dll` / `.dylib`，玩家从不编译。
1. 用 Godot 4.7 打开 `project.godot`
2. 按 F5 运行 → 主菜单
3. 选 Start → 选难度 → 选角色 → 进入 Stage 1

### 跑测试（重构/改动后的安全带）

```bash
./test/run_tests_sharded.sh        # 全量并行（默认 min(nproc,8) 片；覆盖 = 全量）
./test/run_tests.sh                # 全量串行（排查顺序/共享状态用，~76s）
./test/run_tests.sh -gtest=res://test/test_x.gd   # 单文件
```

> 分片仍是同一批 `test/test_*.gd`（每个文件恰好进一片）；`test_sfx_mix` / `test_stage_background`
> 这两个慢文件各占一片，避免一片拖住整个墙钟。`GUT_SHARDS=4 ./test/run_tests_sharded.sh` 可指定片数。

### 一键验证（文档哨兵 + 语法 + 命名 + 结构 / 内容 + 启动 + 测试 + 所有权）

```bash
./tools/verify.sh            # 全量（默认并行分片）
./tools/verify.sh --fast     # 快速冒烟（~8s，不全量；提交前记得跑全量）
./tools/verify.sh --serial   # 全量串行（排查用）
```

> 第 1 步是**文档哨兵**（`tools/check_docs.py`）：TEST_INDEX 的测试清单 / 抬头数字 / **各层小节小计** /
> README 徽章 / `DANMAKU_API` 的弹型与音效 key 表 / README 链接 / 滚动日志，全部对着代码与数据机械核对
> —— 文档数字再也不会静默腐烂。
>
> **当前门禁状态（2026-11-23）**：`check_naming` 已清零；`check_docs` / `check_syntax` / `check_structure` / 启动可过。
> `verify.sh` 仍会停在第 4 步内容契约：Stage 02/06 内容 WIP（空 Boss / 缺失 BGM）；GUT 另有 2 个同类红。
> 这些是内容完成度问题，不是回放/命名问题；提交前仍以 `verify.sh` 实际输出为准。
>
> 第 4 步是**结构契约**（`tools/check_structure.sh`）：**测试白盒预算只减不增** ·
> 第 4 步同时跑**内容契约**（`tools/check_content.sh`）：Stage / Boss 注册表、脚本 / 背景 / BGM 引用、
> `StageVariant` 的难度唯一性与目录位置、manifest 一致性、孤儿内容 warning —— 漏注册、断引用、错放文件在 verify 阶段就会红。
> 随后跑**内容预检**（`tools/content_preflight.sh`）：对话事件有没有发送者/接收者、Boss 有没有阶段、
> 阶段有没有进任何难度槽、`params` 键是否认得 —— 只读，warning 不红。
> 生成只读内容清单：`./tools/build_content_manifest.sh` → `.godot/probe/content_manifest.json`。
> **唯一来源常量**（抄第二遍就红）· **舞台接线唯一**（`.inject_*` 只许在 `stage_host.gd`）。

### 开发常用

```bash
# 查找代码
grep -rn "关键词" --include="*.gd" scripts/ data/

# 添加新敌人 → 见 CONTENT_GUIDE.md 第二章
# 添加新符卡/Boss → 见 CONTENT_GUIDE.md 第四章
```

### 内容工具（无 UI）

> 创作台 / 工作台已退役（2026-10-24）。不再有 F6 内容编辑器；反馈回路回到游戏内与无头命令。

- **写代码**：关卡编排 = `stage01.gd`（Timeline API）；Boss 弹幕 = `PhaseData.tres` 显式引用脚本。
- **看手感**：主菜单 → Spell Practice（单张符卡最快）或 Start 整关；没有单独的预览沙盒。
- **守契约**：`./tools/check_content.sh`（注册表 / 引用 / UID / manifest）+ `./tools/content_preflight.sh`（对话事件闭环 / 无人 Boss / 孤儿阶段 / 参数键）。
- **对话预览**：`scenes/ui/dialogue_preview.tscn`，`--list` / `--dry` / `--shot`，不用打关卡。
- **背景截图 / 耗时**：`tools/background_capture.tscn`（固定种子、同帧对比）。
- **录制 / 观测**：`FlightRecorder` + `ParamTrace` 保留为无头调试库；不再有 UI 面板。

---

## 🎮 操作

| 键 | 功能 |
|----|------|
| Z | 射击 / 确认 |
| X | Bomb / 被弹炸弹（deathbomb） |
| C | 释放记忆 |
| Shift | 低速移动 |
| Esc | 暂停 |
| 方向键 / WASD | 移动 |

> 输入映射在 `project.godot` 的 `[input]` 节（可改键，勿在代码里注入）

---

## 🏗️ 技术栈

- **引擎**: Godot 4.7
- **测试**: GUT 9.7.1（`test/` 目录；`./tools/verify.sh` 全量门禁）
- **协程框架**: CoroutineScript + Timeline（游戏逻辑） / await（UI 过渡，见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)）
- **服务层**: StageContext（clock/bullets/player/dialogue/items/audio/effects）
- **弹幕**: 原生内核 GDExtension `DanmakuStore`（**唯一存储**：积分/行为/判定/宽相）+ MultiMesh 渲染（`KernelNativeSystem` 桥接 + 每帧只读快照）
- **激光**: 生长/直线/固定路径 三种模式
- **UI**: NavPage + MenuNav 页面栈（场景化 Overlay/PageHost）
- **数据**: .tres Resource 文件（EnemyData 构造链模板 / SpellRecordBook / MusicRegistry）
- **常量**: GameConfig（东方框边界）/ LayerConfig（z_index）
- **Replay**: Replay（每 tick 输入 mask + 离散命令 + 总/分项状态哈希；严格播放，不做 force 修正）；当前语义版本 `sim-v9`；sim-v8 的 Boss 入场差拍已修复，sim-v9 已通过 10,843 tick 的 Stage 1 → Stage 2 Game Over 完整 run 回放（零分歧）

---

## 🧭 架构速览（2026-09 内核迁移后）

```
project.godot(输入)
      │
      ▼
组合根 GameScene ──声明式装配 + 向下注入──▶ StageRuntime / BulletManager(内核 SoA) / FxPool / MissCircleLayer
      │                                          │
      │                                          └──▶ 实体（Player / Enemy / Boss）经 StageContext 服务 ctx.*
      ▼
UI / 菜单 ◀── 信号 GameEvents    ◀── 存档 SaveData（纯 static）
```

- 依赖单向：父级/组合根向下注入（R2）；数据类不持有场景，实体经 `ctx.*` 服务访问系统
- autoload 只剩 5 个真全局：`GameEvents / GameManager / RNG / AudioManager / SimClock`；场景 `_exit_tree` 统一断开信号
- 时间：玩法统一 `SimClock.DT = 1/60`；协程用 `CoroutineRunner` + `Timeline`，UI 才用 `await` / Tween / Timer
- 回放：`GameScene` 在 tick 钩子里注入输入/命令、比对状态哈希；回放不保存游戏状态
- 测试保护：核心数学（碰撞/掉落/符卡判定/时间线/RNG）+ Replay 格式/逐 tick 哈希有回归测试

---

## ⚖️ 二次创作与版权

- 《东方 Project》系列的角色、世界观与相关设定版权归 **ZUN / 上海爱丽丝幻乐团** 所有。
- 本仓库是**非商业**同人二次创作作品。
- 仓库内代码采用 **MIT License** 授权（见 [LICENSE](LICENSE)）。
- 美术、音乐、立绘等**素材资源不包含在 MIT 授权范围内**，其版权归原作者或作者本人所有；请勿用于商业用途。
- 详细说明见 [NOTICE.md](NOTICE.md)。
  - 第三方 Shader（记忆值水面）署名见 [`NOTICE.md`](NOTICE.md#第三方-shader-署名)。

---

## 🤖 AI 辅助声明

本项目由作者 **YiHe** 设计、决策与维护，代码和文档在 AI 辅助下完成。所有 AI 生成内容均经过作者审阅、测试与验收。

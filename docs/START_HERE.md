# 从这里开始（5 分钟）

> **项目有十几份文档，但日常只需要 3 份。** 本页是唯一入口；其余是按需查的契约/参考，和**不必通读**的历史。
> 项目介绍 / 运行 / 操作在 [README](../README.md)。

## 0. 三句话

- 内容 = GDScript + `.tres`；**没有可视化编辑器**；创作台是预览/调参台，不保存内容。
- 日常三份：[README](../README.md)（跑/操作）· [CONTENT_GUIDE](../CONTENT_GUIDE.md)（写内容）· [TEST_INDEX](TEST_INDEX.md)（改哪里看哪条）。
- 历史 / 证据 / 归档**不要通读**；用索引或 grep。

## 1. 你现在要做什么？

| 任务 | 只看这份 | 关键提醒 |
|---|---|---|
| 跑游戏 / 跑测试 | [README](../README.md) · [TEST_INDEX](TEST_INDEX.md) | `./tools/verify.sh` 是总门禁 |
| 加一个波次 / 一张符卡 | [CONTENT_GUIDE](../CONTENT_GUIDE.md) §0 / §四 / §六 | 阶段台有热更新；整关预览要重启 |
| 加敌人 | [CONTENT_GUIDE](../CONTENT_GUIDE.md) §三 | `EnemyData` 构造链 + 行为脚本 + `AssetRegistry` |
| 加一面 / 新 Boss | [CONTENT_GUIDE](../CONTENT_GUIDE.md) §四 / §八 · [ARCHITECTURE](ARCHITECTURE.md) §6 | **必须进 `stage_registry.tres` / `boss_registry.tres`** |
| 改某颗弹的飞行规律 | [DANMAKU_API](DANMAKU_API.md) · [CONTENT_GUIDE](../CONTENT_GUIDE.md) §六 | 先看 preset，再自己拼相位；`until` 顺序有坑 |
| 写对话 | [DIALOGUE_SYSTEM](DIALOGUE_SYSTEM.md) | `--list` / `--dry` / `--shot`，不用打关卡 |
| 改背景 | [archive/BACKGROUND_VISUAL_PLAN.md](archive/BACKGROUND_VISUAL_PLAN.md)（**已冻结**） | 现役 3D 背景；别重开视觉线 |
| 改引擎 / 内核 | [ARCHITECTURE](ARCHITECTURE.md) · [BEST_PRACTICES_BASELINE](BEST_PRACTICES_BASELINE.md) · [GDEXTENSION_KERNEL_DESIGN](GDEXTENSION_KERNEL_DESIGN.md) | 改 C++ 必须重编扩展 |
| 查某条测试 | [TEST_INDEX](TEST_INDEX.md) | 一行一条，改哪里看哪条 |
| 查“为什么当初这么改” | [BEST_PRACTICES_LOG](BEST_PRACTICES_LOG.md) 索引 → [archive](archive/ARCHIVE_INDEX.md) | 正文只留最近 12 条 |

## 2. 文档分层

| 层 | 文档 | 读法 |
|---|---|---|
| **日常必读（3）** | [README](../README.md) · [CONTENT_GUIDE](../CONTENT_GUIDE.md) · [TEST_INDEX](TEST_INDEX.md) | 通读 |
| **契约 / 参考（按需）** | [ARCHITECTURE](ARCHITECTURE.md) · [BEST_PRACTICES_BASELINE](BEST_PRACTICES_BASELINE.md) · [DANMAKU_API](DANMAKU_API.md) · [LIFECYCLE_MODEL](LIFECYCLE_MODEL.md) · [BULLET_PIPELINE](BULLET_PIPELINE.md) · [DIALOGUE_SYSTEM](DIALOGUE_SYSTEM.md) · [GDEXTENSION_KERNEL_DESIGN](GDEXTENSION_KERNEL_DESIGN.md) | 改对应系统时查 |
| **历史 / 附录（不必通读）** | [BEST_PRACTICES_LOG](BEST_PRACTICES_LOG.md)（只看索引） · [BASELINE_EVIDENCE](BASELINE_EVIDENCE.md) · [archive/](archive/ARCHIVE_INDEX.md) | 查“为什么/当时怎么想” |

> **分工（同一信息只写一处）**：规则与状态 = [BEST_PRACTICES_BASELINE](BEST_PRACTICES_BASELINE.md)；架构契约 = [ARCHITECTURE](ARCHITECTURE.md)；
> 历史与“为什么” = [BEST_PRACTICES_LOG](BEST_PRACTICES_LOG.md) + [archive](archive/ARCHIVE_INDEX.md)；参考资料 = [DANMAKU_API](DANMAKU_API.md) /
> [LIFECYCLE_MODEL](LIFECYCLE_MODEL.md) / [BULLET_PIPELINE](BULLET_PIPELINE.md) / [TEST_INDEX](TEST_INDEX.md) / [CONTENT_GUIDE](../CONTENT_GUIDE.md)。
> 内容原稿 = [archive/DIALOGUE.md](archive/DIALOGUE.md) / `docs/*.txt`（随实现走，非权威）。

## 3. 常用命令

```bash
./tools/verify.sh                         # 七步总门禁
./test/run_tests.sh                       # GUT 全量（~54s）
./test/run_tests.sh -gtest=res://test/test_x.gd   # 单文件
python3 tools/log_archive.py --archive    # 日志收短（默认留最近 2 天 / 至少 12 条）
```

运行：Godot 4.7 打开 `project.godot` → **F5**；创作台 **F6** `scenes/workbench/creation_station.tscn`。

## 4. 当前状态（2026-10-17）

- 引擎约 95%；**Stage 1 完整可玩**；Stage 2 只有道中（无 Boss）；3A/4/5/6A/6B 为空目录；3B/EX 有测试卡但无关卡脚本。
- 测试 **807 用例 / 7048 断言**；`./tools/verify.sh` 七步全绿。
- 已知缺口：Replay 播放器、结算画面、Stage 2~6 内容、47MB 二进制未上 Git LFS。

## 5. 文档维护规则（只改权威源）

- 改**状态/规则** → 只改 [BEST_PRACTICES_BASELINE](BEST_PRACTICES_BASELINE.md) 的一行；补证据 → [BASELINE_EVIDENCE](BASELINE_EVIDENCE.md)。
- 改**历史/为什么** → [BEST_PRACTICES_LOG](BEST_PRACTICES_LOG.md)；写完跑 `python3 tools/log_archive.py --archive`（别手搬）。
- 改**参考/契约** → 对应那一份；别新开“总结/说明”文档（先问它属于哪一层）。
- 过时 / 被取代 → `git mv` 进 [archive/](archive/ARCHIVE_INDEX.md) + 在 [ARCHIVE_INDEX](archive/ARCHIVE_INDEX.md) 加一行。

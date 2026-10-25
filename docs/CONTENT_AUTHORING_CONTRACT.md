# 内容作者契约

> 目的：加一张卡 / 一波敌人 / 一段对话时，只碰该碰的地方。
> 本文是**规范**，不是教程；操作细节见 [CONTENT_GUIDE](../CONTENT_GUIDE.md)，摩擦清单见 [CONTENT_PIPELINE_AUDIT](CONTENT_PIPELINE_AUDIT.md)。

## 0. 一句话

**数据归数据，行为归行为，编排归编排；每层只有一个 owner。**
默认值承担大多数情况，`params` 只是最后手段。

## 1. 六个对象

| 对象 | 回答的问题 | 不回答 |
|---|---|---|
| `StageData` | 这一面用什么脚本 / 背景 / BGM / 难度变体 | 这一面第几秒出什么 |
| `BossData` | 这只 Boss 各难度按什么顺序打哪些阶段 | 每张卡多少血、弹幕怎么飞 |
| `PhaseData` | 这一张卡的 HP / 时限 / 掉落 / 用哪三个脚本 | 这张卡排第几、什么时候出现 |
| 行为脚本 | 怎么移动、怎么发弹 | 自己在哪一关、第几秒出现 |
| 舞台编排 | 什么时候出敌人 / 进 Boss / 说话 / 收尾 | 阶段内部数值、弹幕形状 |
| 对话 `DialogueSteps` | 谁说什么、什么时候发哪个事件 | 事件发生后舞台做什么 |

## 2. 五条边界

1. **行为脚本不知道自己正跑在哪张卡上。** 只读自己的 `var`、`ctx`、`Difficulty`；不要读关卡脚本、不要碰 `Timeline`、不要按阶段名分支。
2. **阶段顺序只归 `BossData.phases_*`。** 普通战斗由舞台调用 `sequence_phases()` / `start_sequence_now()` 消费；舞台不手排普通阶段的先后。只有特殊演出才用 `start_phase()` 单点插入。
3. **舞台编排只决定「何时」。** 不写 `hp`、不写弹幕参数、不替阶段决定用哪个脚本。
4. **对话只决定「说什么 + 发哪个事件」。** `boss_enter` / `boss_fight` / `stage_end` 之后做什么，由舞台的 `_stage_director.on(key, handler)` 决定。
5. **注册表是发现的唯一入口。** 新 `BossData` → `data/registry/boss_registry.tres`；新面 → `data/registry/stage_registry.tres`。漏登记不会编译失败，只会「菜单里看不见」；preflight 会报。

## 3. 加一张卡的最小路径

| 步 | 做什么 | 落在哪 |
|---|---|---|
| 1 | 建阶段目录，写/复用行为脚本 | `data/stages/<面>/phase/<组>/` |
| 2 | 建 `PhaseData.tres`，填必填项 | 同目录 |
| 3 | 每个难度一份 `.tres`，共用行为脚本、只改数值 | 同目录 |
| 4 | 按顺序挂进 `BossData.phases_easy/normal/hard/lunatic/extra` | `data/stages/<面>/boss/<Boss>.tres` |
| 5 | 新 Boss 登记注册表；新面再登记 `StageData` | `data/registry/` |
| 6 | 舞台在正确时刻 `boss()` + 开打 | `data/stages/<面>/stage_script/<面>.gd` |
| 7 | 跑 `PhaseData.validate()` / `BossData.validate()`、`content_preflight`、符卡练习或整关 | — |

**必填**：`name`（非符空串）、`uid`（符卡全作唯一；非符 `0`）、`hp`、`time_limit`、`shoot_script`（纯演出/纯走位阶段可空）。
**有默认值，通常不用填**：掉落、`open_reduce_*`；`move_script` 常直接复用 `data/boss_scripts/move/random_dir_move.gd`，不填 = 本阶段不移动（合法）。
**只在需要时填**：`pre_move_script`（要「先走到位、再宣言」）、`params`。

## 4. 分化的三选一

| 变化的是 | 用什么 | 为什么 |
|---|---|---|
| 难度数值 | `diff_pick([...])` | 值就在逻辑旁边，改完即见 |
| 内容/结构 | 另写一个脚本 | 最直白，不制造隐式共享 |
| 同一脚本 × 同一张卡 × 只差两三个数 | `params` | 它唯一的独门场景 |

不要用 `params` 做难度轴，也不要用它塞一整套弹幕。`params` 是 move / shoot **共享字典**，同名键会互相干扰。

## 5. 一波敌人 / 一段对话

**敌人**：行为脚本放 `enemy/`，在舞台 `timeline.at(t).do(...)` 里 `spawn(EnemyData.new().with_script(...))`。敌人脚本不自己定时，也不自己决定第几秒出现。

**对话**：台词与事件写在 `data/dialogue/stage/<面>_dialogue.gd` 的 `static` 构建函数里；舞台只调用 `_stage_director.dialogue(...)` 并注册事件 handler。收尾优先用 `d.event("stage_end")`，不要用 `wait(秒)` 猜台词长度。

## 6. 验证顺序

1. **保存时**：`PhaseData.validate()` / `BossData.validate()` / `StageData.validate()` 报字段错误。
2. **开战前**：preflight 报 UID 重复、脚本缺失、孤儿阶段、未登记、事件无人接。
3. **看效果**：符卡练习（单张最快）→ 整关。
4. **回归**：GUT；手感仍要手动打。

## 7. 已知缺口（不是契约，是待还的债）

- Boss / Stage 仍靠手写注册表，漏登记只在 preflight / 菜单暴露。
- `params` 的未知键会报，但 **move / shoot 同名合法键仍会静默互改**。
- `CONTENT_GUIDE` 的部分路径示例已漂移（如 `spell03/`、`non01/`），**实际内容目录为准**；遇到不一致先改文档，别照着旧路径建新内容。

## 8. 下一步

**先不要做编辑器。** 拿这张契约做一张真实的新卡；如果某一步连续两次需要同时查三个以上文件，再把那一步做成脚手架或巡检项。

工具只在「同一个摩擦出现第二次」时才有资格存在。

# 🃏 符卡系统 · 目标蓝图

> 版本：2026-08 · 状态：**设计蓝图（尚未实现）**
> 一句话：把「卡定义」和「卡记录」分开，用 **uid 当身份证**，三张表各司其职。

---

## 0. 一句话总结

> **Boss 谱（按位置）存"卡在哪出场"（符卡 + 非符，练习占位也靠它）；符卡集合（按 uid）只服务"收集率"；成绩单（按 uid+自机+难度）存"你打得怎么样"。**

三个东西过去被揉在 `spell_records.tres` 一个文件里，现在拆成三张表。

---

## 1. 四个维度（先认清有哪些轴）

做一张符卡，会涉及四个维度，**每个都有固定去处**：

| 维度 | 是什么 | 住在哪张表 |
|------|--------|-----------|
| **uid** | 卡的身份证号（符卡有，非符=0） | 符卡集合的 key |
| **位置** | (stage, boss_index, phase_index) | Boss 谱的 key |
| **难度** | 强度旋钮 + 可换整列（E/N/H/L/**Extra**） | BossData 四列 / 难度字典 |
| **自机** | 路线选择（换卡 = 换 uid） | Boss 谱 + 成绩单 |

> ⚠️ **难度有 5 档**（含 Extra），但当前 `BossData` 只有 4 列、缺 Extra——见 §4。

---

## 2. 核心判据：名字不同 = 不同卡

这是整套模型的**定盘星**：

- **难度差分** = 同一张卡的"强度旋钮" → 名字一样、uid 一样，卡**内**变（血量/脚本）。
- **自机差分** = 不同角色的"路线" → 名字不同、**uid 不同**，是两张不同的卡。

判据就是**名字**：

```
灵梦打「灵符·星之梦」  uid 55
魔理沙打「恋符·星之梦」  uid 56   ← 名字不同 → 是两张卡
```

> 名字**你自己起**，存成显式字典 `{ NORMAL:"…", LUNATIC:"…" }`，不要什么后缀规则。

---

## 3. 三张表（复用现有类，不新写 CardDef/BossEntry）

> 已拍板：**复用 `BossData` + `PhaseData`**，只加"一层路由"，不新写类。
> 理由：BossData 已有 `phases_easy/hard/lunatic`（正是"每难度一整列"的 option 2 结构）；规模小用字典足够；迁移最小。

### ① Boss 谱 `BOSSES`（key = stage → boss → 自机 → BossData）

> 正篇 stage.gd 从这里取；**练习菜单的"占位"也靠它**（符卡 + 非符都有格子）。
> **自机差分 = 同一位置放不同的 BossData**（不同 uid 的卡）。

```gdscript
# data/registry/boss_catalog.gd（示意）
const BOSSES := {
    3: [   # stage 3 的 boss 列表（boss_index = 数组下标）
        {
            Character.REIMU: BossData.new().name("梦外见").look(BOSS3)
                .phase(NON30).phase(SPELL055),          # Normal 列
            Character.MARISA: BossData.new().name("梦外见").look(BOSS3)
                .phase(NON30).phase(SPELL056),          # 自机换卡 = 不同 BossData
        },
    ],
}
```

要点：

- **难度在 BossData 内**（`phases` / `phases_easy/hard/lunatic` 四列），**自机在 Boss 谱外**（换 BossData）。
- 阶段序列里，**符卡写 PhaseData（含 uid）**，**非符写无 uid 的 PhaseData**。

### ② 符卡集合 `SPELLS`（key = uid，**从 Boss 谱派生**）

> 不手写第二份（避免双驱动漂移），从 Boss 谱扫一遍收集所有 `uid != 0` 的卡。
> ⚠️ **它只服务"收集率"页面，不服务练习菜单的占位**（练习占位走 Boss 谱）。

```gdscript
static func collect_spells() -> Dictionary:
    var spells := {}
    for stage in BOSSES:
        for boss in BOSSES[stage]:
            for char in boss:
                for phase in boss[char].all_phases():   # 含四个难度列
                    if phase.uid != 0:
                        spells[phase.uid] = phase       # uid 冲突时报警
    return spells
```

- **收集率**页面遍历它（收集率本来就不含非符）。
- **uid 冲突检查**放这里，比散在各处可靠。

### ③ 成绩单 `spell_records.tres`（符卡和"非符"分两条键，但**同一张表**）

> 只存**战绩**，不存卡定义。已拍板：**练习解锁 = 正篇挑战过 ≥1 次**（符卡和非符都一样）。
> **不用拆成两张表**——同一张 `SpellRecord`；非符记"挑战次数"但**不记收取**。

```gdscript
# SpellRecord 瘦身成两段（同一份存档里分两类）：

# 符卡记录（正篇 + 练习都记）
uid + character + difficulty   → attempts / captures / practice_attempts / practice_captures / best_score / best_time

# 非符记录（正篇记"挑战次数"用于解锁 + 练习记战绩）
stage + boss_index + phase_index + character + difficulty
                              → attempts                      # 正篇挑战次数（≥1 = 解锁练习）
                              → practice_attempts / practice_captures   # 练习战绩
                              # 没有 captures（非符无"收取"）、没有 best_score/best_time
```

要点：

- **删掉** `phase_data` / `boss_scene` / `name` / `boss_name`（定义去 SPELLS/BOSSES 查）。
- 非符**不进符卡集合**，只在 Boss 谱里有位置；正篇记 `attempts`（解锁用），练习记 practice 战绩。
- **占位靠 Boss 谱（定义），不靠预建记录**——记录按需填，不预建空条目。

---

## 4. 难度差分（含 Extra 缺口）

### 两个粒度

| 差分类型 | 住哪 | 例子 |
|---------|------|------|
| 只改**数字**（弹数/速度） | 脚本内 `diff_pick` | `diff_pick([1,3,5,8])` |
| 改**整卡**（名字/血量/脚本） | BossData 四列 / `per_difficulty` | `.lunatic_phase(SPELL055_L)` |

- **90% 的卡**：只写一份 PhaseData，`diff_pick` 在脚本里吃难度 → 四难度共用。
- **少数卡**：名字/血量/脚本真随难度变 → 挂不同版本。

### ⚠️ Extra 缺口（已发现，待修）

- `SpellRecord.Difficulty` 有 **5** 档（EASY/NORMAL/HARD/LUNATIC/**EXTRA**）。
- `BossData` 只有 **4** 列，且 `phases_for_difficulty(4)` 和 `difficulty_name(4)` 都会**静默掉进 Normal**。

**根治方向（已拍板）**：难度枚举当 key，字典每格都有，漏不了：

```gdscript
enum Difficulty { EASY, NORMAL, HARD, LUNATIC, EXTRA }   # 只在一处定义

var phases_by_diff: Dictionary = {
    Difficulty.EASY: [], Difficulty.NORMAL: [], Difficulty.HARD: [],
    Difficulty.LUNATIC: [], Difficulty.EXTRA: [],
}
```

---

## 5. 现状体检（data/ 按 5 标准）

| 标准 | 主要发现 |
|------|---------|
| **统一** | 阶段目录结构不一致（`non01` 只有 shoot，`non_mid01` 有 move/shoot/bullet）；"move 脚本放哪"两套约定（共享 `boss_scripts/move/` vs 自建）；阶段命名混（`non`/`non_mid`/`spell01`/`spell03`） |
| **清晰** | 空目录死胡同：`dialogue/marisa/`、`phase/non02/`、`phase/spell02/`；`boss_scripts/enter`、`exit` 只有 `.gitkeep`；命名不自解释（`stage03B` 的 B、`YY_jade`） |
| **完整** | 孤儿内容：`spell001`（preload 被注释）、`spell053~056`（无 stage 脚本）；`stage03B` 半成品（只有 `phase/`） |
| **单一权威** | 内容无法枚举（无花名册）；`registry/` 混了静态表（stage/music）和可变存档（spell_records） |
| **命名自解释** | `phases`（Normal 裸奔）不对称；难度散成魔法数字 0~4 各写各的 |

> 这 5 个标准（统一/清晰/完整/单一权威/命名自解释）就是判断 `data/` 健不健康的尺子。

---

## 6. 迁移步骤（建议顺序）

1. **先画图**：确认三张表 + 四维度 + 判据（本文件即共识）。
2. **补 Extra**：`BossData` 加 `phases_extra`（或直接上难度字典）。
3. **瘦身成绩单**：`SpellRecord` 删 `phase_data/boss_scene/name/boss_name`，非符改为仅练习记。
4. **建 Boss 谱**：把 stage01.gd 里内联的 `BossData.new()...` 抽成 `BOSSES` 表。
5. **派生符卡集合**：从 Boss 谱收集 uid（含 uid 冲突检查）。
6. **接线**：stage.gd 和练习菜单改为从 Boss 谱 / 符卡集合取。
7. **（收尾，不阻塞前面）PhaseData 改代码构造**：彻底统一"数据即代码"，删 7 个 .tres。
8. **重打一关**：旧 `spell_records.tres` 失效，重新生成。

> 每步都该**绿测试 + 能进练习菜单**再走下一步。别一口气全改。

---

## 7. 已拍板 / 尚未拍板

### ✅ 已拍板

- 符卡**名字**：显式字典，作者自己起。
- **复用 vs 新写**：复用 `BossData`/`PhaseData`，不新写 `CardDef`/`BossEntry`。
- **非符**：正篇记挑战次数（`attempts`，≥1 解锁练习）；练习有入口 + practice 战绩。
- **难度**：枚举唯一权威 + 补 Extra。
- **占位**：练习菜单遍历 Boss 谱（符卡 + 非符都有格子），符卡集合只服务收集率。
- **PhaseData**：最终改代码构造（统一"数据即代码"），但排最后，不阻塞前面。
- **符卡集合生成**：运行时扫描（启动扫一次 Boss 谱、缓存，含 uid 冲突检查），不做静态导出。

### ⬜ 尚未拍板

（无——全部已拍板 ✅）

# Godot 最佳实践日志（BEST PRACTICES LOG）

> 本文件是**滚动日志**：记录"为什么这样改 / 当时学到什么 / 踩过的坑"。
> - **反复踩的坑 / 铁律** → 蒸馏进 `BEST_PRACTICES_BASELINE.md`（改动前必读）。
> - **正文只留最近 2 天**（且不少于 12 条）→ 更早的按**月**归档到 `docs/archive/LOG_<YYYY-MM>.md`
>   （**不删任何东西**；归档内文**时间正序**，越往下越新）。
> - **顶部索引**由工具生成，列**全部**条目（新→旧）：留在正文的直接往下读，归档的给文件链接。
> - 找旧事：先扫索引，或 `grep -n "关键词" docs/BEST_PRACTICES_LOG.md docs/archive/*.md`
>
> 维护：`python3 tools/log_archive.py --check`（体检格式/体积）· `--dry-run`（看会搬走什么）·
> `--index`（只重建索引）· `--archive [--days=7 --keep-min=20]`（归档 + 重建索引）。

---

## 模板（每条可复制）

### YYYY-MM-DD — 子系统名 / 改动名
- **目标**：一句话说明要改什么。
- **为什么**：为什么这样改才算符合最佳实践（对应哪篇文档哪一条）。
- **对照旧项目**：旧版 file.gd:line 哪里不好，我这次刻意没抄什么。
- **新落点**：新文件:行号。
- **验收**：./tools/verify.sh / 对应 GUT 测试结果。

---


## 索引

> 共 34 条（本文件留最近 34 条，其余在 `docs/archive/`；本段由 `tools/log_archive.py` 生成，手改会被覆盖）。

- 2026-09-27 — 约定：临时探针产物放 `.godot/probe/`（不再往项目根建目录，作者已认可）
- 2026-09-27 — 吃 P 点**不再变金色**（金色只属于「点」）
- 2026-09-27 — miss 后自机**复位两步**：瞬移到**框下方之外** → 升到 `_respawn_pos`（最后触发）
- 2026-09-27 — miss 的 P 点扇形：**左右不出场地框**（贴墙一侧压扁）
- 2026-09-27 — G8 追加：扇形飞完改**竖直下落**（作者："按弧形移动一会后就竖直向下落"）
- 2026-09-27 — G8 落地：miss 接上火力惩罚 + 撒 10 个 P 点「向上 180° 均匀弧形」（S6 → ✔）
- 2026-09-27 — S6 复核完毕：奖励分"待核"已过期 → 改判；顺带抓出**真缺口**（miss 的火力惩罚未接）
- 2026-09-27 — 文档哨兵进 `verify.sh`（第 1 步）+ N2 归档 + TODO_TEMP 去重（作者勾选的三项）
- 2026-09-27 — 非归档文档体检：修事实错误 + 给"混装"文档立「性质」栏位（作者："那其他所有除了以归档外的文档呢"）
- 2026-09-27 — 项目基线"还原本色"：正文只留规则与状态，证据/审计拆到附录（作者："没有基线那样精简了"）
- 2026-09-27 — 最佳实践日志"瘦身 + 可检索"：滚动窗口 + 顶部索引 + 按月归档（作者："太太太大了"）
- 2026-09-27 — 修回归：奖励分"作废"后的**早退**掐掉了减伤倒计时与时限判定（作者报）
- 2026-09-27 — 符卡记录页改成"**列全部符卡 + 三档显示**"（未遇见只给 uid 与问号，收取过才蓝）
- 2026-09-27 — 符卡奖励分"作废"机制：期间 **miss / 用 bomb** → 不给分 + 数字位显示「失败」
- 2026-09-27 — 对话预览加 `@export` + 窗口内选段（作者："要不要加 export 和选择具体对话"）
- 2026-09-27 — 对话的"方便测试方法"：**预览场景 + 干跑**（顺带修掉情绪被冲掉的老 bug）
- 2026-09-27 — 加 `ActorHandle`：对话"谁做什么"（`enter()` 返回句柄）
- 2026-09-27 — `DialogueSteps` 的六个"演出版"动词改收 `CharacterProfile`（作者："exit 为什么不传 profile？"）
- 2026-09-27 — 对话事件 handler 里的 `if` 巡检收口（作者："对句柄的判断是不是太多了"）
- 2026-09-27 — `StageDirector.dialogue` 改收 `DialogueSteps`（作者建议）；并订正"对话不冻结时间轴"的错误说法
- 2026-09-27 — "Boss 击破后、关卡结束前加对话"：接上战后对话（事件收尾）+ 收尾作者挪文件的断链
- 2026-09-27 — 对话构建函数**必须 static**；顺手修好被"静默跳过"的内容测试 + 补语法门禁盲区
- 2026-09-27 — 全破音效换成专用素材 `boss_die`（替掉借来的 `enemy_die` 占位 key）
- 2026-09-27 — 魔理沙子机（focus）发射/命中音效各压 7 dB（两轮；并修 `sfx_db_baseline` 的判定口径）
- 2026-09-27 — 全破反色圈改成**与自机 miss 同一套参数**（作者纠错：同心不等半径不是 miss 的做法）
- 2026-09-27 — Boss「全破」演出 + 关卡收尾动词（`defeat()` / `finish_stage()`）
- 2026-09-26 — 符卡练习 BGM 改成**每 Boss 一首**（道中曲 / Boss 曲可分别配）
- 2026-09-26 — 新增 `reflect()` 镜面方向原语（撞墙反弹不再只能"朝 Boss"）
- 2026-09-26 — 符卡奖励分改为**规则计算**（原作口径：难度权重 × 面序号 × 50 万；时限内均匀衰减到 30%）
- 2026-09-26 — Boss 计分行加说明前缀 + 倒计时再下移（并修掉前缀带出的两处版面 bug）
- 2026-09-26 — Boss 阶段倒计时挪到符卡名**下方**（位置改成场景声明）
- 2026-09-26 — 符卡练习二级列表：超长改为「开窗滚动」（不再膨胀出面板）
- 2026-09-26 — 符卡记录分页：每页行数从写死 6 → 按面板实测高度算
- 2026-09-26 — 阶段身份「槽位数」口径：`phases_normal` 长度 → 各难度列最大长度（EX 面解锁）

## 记录

### 2026-09-27 — 约定：临时探针产物放 `.godot/probe/`（不再往项目根建目录，作者已认可）

- **触发**：作者问"**tmp_probe_miss_fan 文件夹怎么放到项目根目录了**"。
- **根因（环境事实，记下来免得下次重踩）**：Agent 沙箱里**每次命令都是新的 `/tmp`**（实测跨调用不留存），而 `~` / `$DSH_HOME` **不可写** ——
  探针截图（要用 `read_image` 读出来贴给作者看）只有放**项目内**才能活过"写完 → 下一轮读取"这一步。
- **约定**（作者："probe 可以"）：探针产物一律写 `res://.godot/probe/` —— 项目内、**被 git 忽略**、`git status` 看不见；**看完即删**，不跨轮次留存。
- **补**：先前误放项目根的 `tmp_probe_miss_fan/` 已删除（它从未进过提交）；提交 `39b1b69` 里那 2 行 ignore 规则暂留 ——
  因推送失败、无法确认远端是否已收到该提交，所以**不擅自 amend**（要清掉随时说）。

### 2026-09-27 — 吃 P 点**不再变金色**（金色只属于「点」）

- **作者要求**："吃P点不再会变金色了"。
- **现状病根**：`Item._is_highlight`（"金色"）原先**不分道具类型**，两条置位路径都会给 P 点打上：
  ① 过收点线（`_tick_collect_or_fall` 里 `player.y < _auto_collect_line`）；② `force_collect()`（记忆释放 / 敌人掉落）。
  而金色的**机制意义只对「点」(POINT) 成立**（金色 → 拿满 `max_point`）；P 点吃下就是固定 +1 火力 +10 分，
  金色对它只剩"浮字变金"这个纯装饰副作用 —— 于是 P 点被强收/过线时会冒金数字。
- **改法**：新增 `_mark_highlight()`，**只认 `Type.POINT`**；两条置位路径都改走它（`force_collect()` 与过收点线分支）。
  P 点 / 碎片 / 整命整 B 从此不会被标金 → 浮字保持白色；「点」的金色与满分逻辑一字未动。
- **测试**：`test_score_popup` 改 1 增 1 —— 原 `test_force_collect_is_highlight`（拿 **P 点**断言金色）**本来就写错了对象**，
  改成 `test_force_collect_power_is_not_highlight`（P 点强收不金色），并新增 `test_cross_line_power_is_not_highlight`（P 点过线也不金色）；
  「点」那三条（强收满分+金色 / 过线金色 / 靠近白色）保持不动。`TEST_INDEX` 与 README 徽章同步（**620 用例**）。
- **验收**：`./tools/verify.sh` 六步全过。

### 2026-09-27 — miss 后自机**复位两步**：瞬移到**框下方之外** → 升到 `_respawn_pos`（最后触发）

- **作者要求**："自机 miss 后从正中下的位置移动到正中偏下的位置，这个移动在最后触发，因为反色圈是要在 miss 时的位置"；
  随后两轮纠正："移动的**最终位置**是 `_respawn_pos`，不是从 `_respawn_pos` 开始移动" / "**还是有瞬移的**，是先瞬移到正中的**超过框的下方**，然后再移动到 `_respawn_pos`"。
- **最终实现**（`Player.miss()` **最后**一步，两步）：
  ① `global_position = MISS_RESPAWN_FROM` —— **瞬移**到水平正中、**场地框下方之外**（`(FIELD_CENTER_X, FIELD_BOTTOM + 96)` = `(448, 1024)`）：船从框下升进场；
  ② `_move_to_respawn()`：0.45s tween（`TRANS_QUAD/EASE_OUT`）移动到 **`_respawn_pos`**（**终点**）= 复位点，默认 `MISS_RESPAWN_POS := (FIELD_CENTER_X, FIELD_BOTTOM − 88)` = `(448, 840)`"正中偏下"。
- **`_respawn_pos` 是 var**：关卡/模式想换复位点直接改它；`_is_respawning` 期间 `update_move()` 直接返回（锁输入，tween 在写 position），落地解锁。
- **我错了两次，值得记**：
  1. 第一版把 `_respawn_pos` 当**起点**（做成"瞬移回开局位置→再升到正中偏下"），语义整个反了；
  2. 第二版顺着"不是从 `_respawn_pos` 开始移动"把**瞬移那一步删了** —— 而作者的意思只是"瞬移的落点不是 `_respawn_pos`"，瞬移本身要留着（落点是**框外的正中下方**）。
  教训：作者描述里"从 A 移动到 B"时，**A 到底是"当时所在"还是"某个特定落点"要问清楚**，别自己脑补一步。
- **为什么必须放最后（作者点出的约束）**：反色圈 / 清弹 / P 点扇形全都是用**开头捕获的 `pos`**（中弹那一刻的位置）调的，
  移动自机只能最后做。另外所有特效调用都显式传 `pos`、不读 `global_position`，所以顺序再被谁插队也不会把圈画歪。
- **实测**（xvfb 探针，非仅靠断言）：`t=0.05s` 自机 `(448, 1024)`（框下）→ `t=0.25s` `(448, 850)`（已进框）→ `t=0.60s` `(448, 840)`（复位点）；
  截图确认"船从框下升进来"。
- **测试**：`test_player` 2 条（① 瞬移落点 == `MISS_RESPAWN_FROM` 且 y > `FIELD_BOTTOM` → 期间按方向键不动 → 终点 == `_respawn_pos` 并解锁；② 第二次中弹同样先瞬移到框下、复位点不变）。
  `TEST_INDEX` 与 README 徽章同步（**619 用例**，哨兵核对通过）。
- **验收**：`./tools/verify.sh` 六步全过。

### 2026-09-27 — miss 的 P 点扇形：**左右不出场地框**（贴墙一侧压扁）

- **作者反馈**："miss 生成的 P 点能改成左右不出游戏框吗"。
- **改法**：把"先算方向再飞"换成**先算目标点再飞** —— 新纯函数 `ItemService.fan_targets(count, origin, center_dir, spread_deg, radius, x_min, x_max)`：
  在均匀弧上算出 10 个目标点后，把**横坐标夹进 `[x_min, x_max]`**（纵向不动）。
  `ItemService.spawn_fan()` / `spawn_fan_in_pool()` 改成收 `targets` + `hang`：每个点按 `(target − origin) / hang` 直线飞过去，
  于是"到达时刻 = 宽限结束"仍然精确，第二段的竖直下落自然不会出框。
- **边界取值**：`Player.MISS_POWER_MARGIN = 16`（道具贴图 32×32 的**半张**）→ 夹取区间 `[FIELD_LEFT+16, FIELD_RIGHT−16]` = `[80, 816]`，
  整张贴图也留在框内。
- **贴墙时的形状（如实说明）**：靠墙一侧被压扁成**一条竖列**（例：自机 x=72 时目标 x = `80×5, 114, 192, 256, 298, 312`），另一侧保持完整半径 ——
  这是"既要 240px 半圆、又要不出框"的必然取舍；想更自然可以调小 `MISS_POWER_RADIUS` 或改成贴墙时收窄张角（待作者定）。
- **实测**（xvfb 探针，用**生产常量**跑，画面里画出场地框与夹取边界）：中央目标 x = `208…688`（= 448 ± 240，完整半圆）；
  贴墙目标 x 如上；**两种位置 × 两个时刻（0.30s / 0.95s）出框数都是 0**。
- **测试**：`test_item` +1（中央不夹取=完整半圆 / 贴左墙压到边界且右侧不受影响 / 贴右墙镜像 / 纵向弧高不变）
  · `test_player` +1（夹取边界必须真的在场地框内侧）。`TEST_INDEX` 与 README 徽章 → **617 用例 / 6164 断言**（哨兵核对通过）。
- **验收**：`./tools/verify.sh` 六步全过。

### 2026-09-27 — G8 追加：扇形飞完改**竖直下落**（作者："按弧形移动一会后就竖直向下落"）

- **作者追加**：P 点沿弧向飞一会儿后，要**竖直向下落**（不是继续向外抛）。
- **改法（两段式）**：把 `Item` 的爆发语义定死为"**初速只管宽限期**"—— 宽限归零那一帧 `_velocity = Vector2.ZERO`，
  随后交给常规物理（重力下落 + 正常吸附 / 收点线规则）→ 横向冻住 = **竖直下落**；`_tick_collect_or_fall` 一字未改。
- **顺带挖出一个隐藏坑（这条最值钱）**：旧参数 `280 px/s × 0.45s = 126px` **刚好卡在吸附半径 128 的内侧**，
  而吸附判定只在宽限归零后的**那一帧**才做（那时已飞过 128）→ 于是这 10 个点**永远不被吸附**、一路向外抛。
  不是 bug，是数值巧合 —— 但它暴露了一个**必须显式约束**的关系：**弧半径 vs 吸附半径**。于是：
  - 参数从"初速"改成**显式半径** `MISS_POWER_RADIUS = 160`（速度 = 半径 ÷ 悬停 0.45s = 355.6 px/s，推导写在注释里）；
  - `Item.PROXIMITY_RANGE` 提为**公开常量**，`test_player` 加契约断言 `MISS_POWER_RADIUS > Item.PROXIMITY_RANGE`
    —— 以后谁把半径调到 128 以内，测试立刻红，而不是"默默看不到第二段"。
- **实测**（xvfb 探针，不只看断言）：t=0.30s 十个点**全部 r=106.7**、角度 `0 / −20 / … / −160 / 180°`；
  t=0.55s 到达 r≈160；**t=0.95s 与 t=0.55s 的 x 坐标逐一相同**（+160.0 / +150.4 / +122.6 / +80.0 / +27.8 …）、只有 y 在增大 → 「竖直下落」成立 ✓。
- **测试**：`test_item` +1（斜向 burst → 第一段 x 变、第二段 **x 冻住且 y 下落**）· `test_player` +1（半径 > 吸附圈契约）。
  `TEST_INDEX` 与 README 徽章同步（**615 用例 / 6122 断言**，哨兵核对通过）。
- **验收**：`./tools/verify.sh` 六步全过（哨兵 · 语法 · 命名 · 启动 · GUT 615/614 · 所有权）。

### 2026-09-27 — G8 落地：miss 接上火力惩罚 + 撒 10 个 P 点「向上 180° 均匀弧形」（S6 → ✔）

- **作者指示**："接上，然后 miss 的时候，再加上自机处生成 10 个 P 点，绕自机为均匀的向上的 180 度弧形"。
- **① 接上火力惩罚**：`Player.miss()` 里加 `resources.on_miss_power_penalty()`（−50，clamp 0..300）——
  这条入口此前只被自己的测试调用（S6 的 `[~]`）。
- **② P 点扇形**：
  - 新原语 `ItemService.spawn_fan(type, count, origin, center_dir, spread_deg, speed, grace)` +
    **纯函数** `fan_directions()`（可单测）；实体部分拆成 `spawn_fan_in_pool()`（不依赖 ctx，便于测试喂真池）。
  - 几何：以 **正上** 为中轴、张角 **180°、含两端点** → 10 个点**相邻 20°**，从正左 → 正上 → 正右（向上半圆）。
    10 是偶数，**正中恰好没有采样点**（两侧各偏 10°）—— 这是"含端点"的必然结果，已写进测试断言。
  - 参数落在 `Player.MISS_POWER_*`（数量 10 / 张角 180 / 初速 280 px/s / 宽限 0.45s），要调手感改这一处。
- **③ 必需的新机制：`Item` 爆发宽限**（`burst()` + `_collect_grace`）。
  原因：道具吸附半径 128px、吸附速度 800px/s，且**过收点线/贴着自机当帧就收** ——
  在自机处生成的点会**当帧被吸走，弧形根本看不见**。宽限期内：只按径向初速飞，**不落重力、不吸附、`area_entered` 也不收**；
  宽限结束立刻恢复正常（吸附 + 重力 + 碰到收）。`setup()` 里必须归零（池复用铁律）。
- **④ 实测（不只看断言）**：xvfb 跑真引擎探针，t=0.30s 打印 10 个点的极坐标 ——
  **全部 r=84.0**、角度 `0 / −20 / −40 / … / −160 / 180°` → 等半径圆弧 + 均匀 20° 一档，肉眼截图也确认是干净的向上半圆。
  探针文件跑完即删（只留两张截图，见 `tmp_probe_miss_fan/`，已进 `.gitignore`）。
- **⑤ 测试**（+5 用例，全绿）：`test_player` +2（miss 削火力 / 无 ctx 安全跳过）；`test_item` +3
  （宽限内不被吸附且宽限过后被收走 / 扇形撒满 10 个且等半径 / `fan_directions` 均匀对称几何）。
  `TEST_INDEX` 与 README 徽章随新数字更新（**613 用例 / 6117 断言**，哨兵核对通过）。
- **⑥ 结案**：基线 **S6 🚧 → ✔**；证据文档 S6 的 `[~]` 换成 `[x]`（含探针实测数字）；`TODO_TEMP` G8 结案。
- **验收**：`./tools/verify.sh` 六步全过（哨兵 / 语法 351 / 命名 0 / 启动零错 / GUT **108 脚本 · 613 用例 · 612 通过**，唯一红仍是 `test_data_validity`）。

### 2026-09-27 — S6 复核完毕：奖励分"待核"已过期 → 改判；顺带抓出**真缺口**（miss 的火力惩罚未接）

- **作者指示**：改 S6（上一批我报了"奖励分已落地，S6 的『来源待核』是否改判待你拍板"）。
- **方法**：不看出处怎么写，把 S6 列的每一项**追到调用点**再下判。
- **结论 1 · 旧判据确实过期**：`[~] 分数来源…Bonus 待核` 早不成立 —— 奖励分 2026-09-26 已改成**规则算**
  （`SpellBonus`：难度权重 × 面序号 × 50 万；时限内线性衰减到 30%；**miss / 用 bomb 整张作废**），
  有 `test_spell_bonus` + `test_boss_phase` 锁定 → 该条改 `[x]`，并把**五条来源各自的调用点**钉进证据
  （击破 `enemy.gd:104 → player.gd:69`、奖励分 `boss.gd:372`、捡点 `item.gd:125 add_max_point`、擦弹 `on_graze()`、记忆）。
- **结论 2 · 措辞修正**：旧证据把**记忆**列进"分数来源"是错的 —— 它是**资源**（0–100）：擦弹 +0.25 / miss +25 / 每秒自然回复，
  被 `memory_release`（`player.gd:242`）消耗来强收道具，并决定 Stage 3A / 3B 路线。证据里已更正。
- **结论 3 · 新抓到的缺口**：`PlayerResources.on_miss_power_penalty()`（−50 火力，clamp 0..300）**只有它自己的测试调用**；
  生产 Miss 路径 `Player.miss()`（`player.gd:310`）只做「清弹 + 记忆 +25 + 扣残机 + 3 秒无敌」→ **本作目前 miss 不削火力**。
  旧 `SPEC.md` §API 表把它列为对外接口，所以这属于「**有意（本作 miss 反而给记忆）还是漏接**」的**产品决定**。
  → S6 状态**保持 🚧**，但"还差什么"从"来源待核"换成这一条；TODO_TEMP **G8** 登记待拍板（接上 or 连测试一起删）。
- **落点**：基线 S6 行 · `BASELINE_EVIDENCE` S6（逐条调用点 + 新 `[~]`）· `TODO_TEMP` G8 + F3 备注结案。
- **验收**：文档哨兵 ✅ · 语法 351 脚本 0 失败 ✅ · 命名 0 违规 ✅（纯文档改动，不涉及代码/GUT）。

### 2026-09-27 — 文档哨兵进 `verify.sh`（第 1 步）+ N2 归档 + TODO_TEMP 去重（作者勾选的三项）

- **作者选择**：① 加文档哨兵 ② N2 计划归档 + 建 `ARCHIVE_INDEX.md` ③ TODO_TEMP 去重（删与基线重复的 P4/P5）。
- **① 文档哨兵 `tools/check_docs.py`**（纯 Python，零 Godot）—— 七条**机械判据**：
  1. `TEST_INDEX` 登记的测试文件 == `test/*.gd`（1:1：不缺 / 不多 / 不重复）；
  2. `TEST_INDEX` 分层表「文件 / 用例」合计 == 抬头「N 脚本 / N 用例」== 实际文件数；
  3. `README` 测试徽章数字 == `TEST_INDEX` 抬头；
  4. `DANMAKU_API` §7.2 音效 key 集合 == `AssetRegistry.sounds`；
  5. `DANMAKU_API` §7.1 弹型 key 集合 == `data/bullets/*.tres`；
  6. `README` 里所有相对链接都指向存在的路径；
  7. `tools/log_archive.py --check`（滚动日志格式 / 体积）。
- **先做负向测试再上线**（否则"哨兵"可能是个永远绿的摆设）：注入三种真实故障 —— 假测试登记 `test_fake.gd` /
  徽章改 `600 tests` / 删掉 `boss_die` —— 三次都**点名到位**；备份还原后逐字节一致（`cmp`）且全过。
- **② `verify.sh` 五步 → 六步**：哨兵放**第 1 步**（毫秒级，fail fast）；`TEST_INDEX` 与 `README` 的"五步门禁"字样同步。
- **③ N2 归档**：`git mv docs/N2_NATIVE_INTEGRATION_PLAN.md docs/archive/` → 7 处引用改路径（`README` ×2、`ARCHITECTURE` §7、
  `GDEXTENSION_KERNEL_DESIGN` ×2、`LIFECYCLE_MODEL`、`BASELINE_EVIDENCE`、`kernel_bullet_host.gd` 的报错文案、
  `test_reference_oracle.gd` 注释），并修掉归档内 `NEW_KERNEL_REFACTOR_PLAN.md` 因同目录化而失效的相对链接。
- **④ 新建 `docs/archive/ARCHIVE_INDEX.md`**：14 条（**一句话价值 + 状态 + 现在还被谁引用**）+ 归档规则（只搬不删、日志交给工具）。
  写它的时候顺手发现两处：`SPELL_SYSTEM_TARGET` 自称"尚未实现"但核心已由 `boss_catalog.gd` 落地；`CREATION_STATION_V1` 已被实现演进取代 —— 都在索引里标清楚。
- **⑤ TODO_TEMP 去重**（它自己写着"别长成第二份基线"，结果真长了）：删掉「已生效契约」三条复述（契约出处收进基线新的
  **「其他契约」**小节：bomb 模型 / 弹型贴图 / **纹理插座不是债**，各指一个唯一出处）、删掉整个 **P4**（E4/E5/E9/E10/E11 全在基线）、
  **P5** 删 F2/F3/F4/F5/F6/F9（S3/S4/S6/S7/S9/S10/S12 的「还差什么」已写）、D3/D4 收进基线 R18/R19。
  只留基线没写的：F1 关卡练习占位 · F8 telegraph · F10 工作台描述符浏览 · D5 · P1 字符串接口 · V/N 审查 · 快照。G3（归档索引）就地结案。
- **⑥ 顺手抓的漂移**（都是"手工数字"，正是哨兵要治的病）：基线 R18/R19 的 `692/592` → 实测 **695/754**（`spell_practice_menu` 这轮长了 160 行）；
  `asset_registry.gd` 的 `res://` **75 → 54**（`bullet_configs` 退役所致）、`scripts/**` **219 → 209**。
- **⚠️ 报给作者复核**：TODO 里的 F3「Bonus 分数来源待接」**其实已经落地**（`scripts/data/spell_bonus.gd` + `test_spell_bonus.gd` + UI「失败」文案）——
  基线 **S6 状态行的"来源待核"是否改判**，等作者拍板，我没有替他改状态。
- **验收**：`./tools/verify.sh` 六步 —— 哨兵 ✅ / 语法 351 脚本 0 失败 / 命名 0 违规 / 启动零错 / GUT 108 脚本 608 用例（唯一红仍是 `test_data_validity` 内容 WIP）。

### 2026-09-27 — 非归档文档体检：修事实错误 + 给"混装"文档立「性质」栏位（作者："那其他所有除了以归档外的文档呢"）

- **作者反馈**：基线那套"正文薄 / 证据另置"的思路，其他非归档文档是不是也该这样？
- **做法**：先把 16 份非归档文档 + `docs/*.txt` 过一遍（体量 / 最后改动 / 性质 / 互相引用），**只改"事实错误"与"性质混淆"，不搬内容**。
- **修掉的事实错误（有实测依据）**：
  1. `README.md` 测试徽章写 **GUT-310 tests / 57 scripts** → 实际 **608 / 108**（差近 2×，纯手工徽章没人管）。
  2. `README.md` 文档索引漏了 **`docs/BULLET_PIPELINE.md`** 与 `TODO_TEMP.md`；`TEST_INDEX` 行写"99 个测试文件" → **108**。
  3. `README.md`「已知待做」与 `ARCHITECTURE.md` §8.3 都还写着 **Bomb 释放未接** —— 实际已落（`player.gd:210` → `player_resources.gd:120`，`BombData`/`RingBombData`/`MistBombData` + `test_bomb_data`/`test_mist_bomb`）。
  4. `ARCHITECTURE.md` §8.3 登记的「`PauseMenu`/`GameOverMenu` `_on_leave` 重复」**已不存在**（全项目 grep 0 处）；「DifficultyScreen 覆写 NavPage 90%」实测为 **同名函数 12/23**。
  5. `TODO_TEMP.md` 自述"**不要改成 `[x]`，那会长成第二份基线**"，但 F7 就是 `[x]`；`use_bomb` 行号漂到 `211/117`（实际 `210/120`）；`check_syntax` 脚本数写 301 → 实测 **351**。
  6. `docs/DANMAKU_API.md` §7.2 音效 key 表**漏了刚加的 `boss_die`**（表 17 个 / 注册表 18 个）→ 补齐 + 标注权威表是 `asset_registry.gd` 的 `sounds`。（同文件 §7.1 弹型表 23 条与 `data/bullets/*.tres` **23 条 1:1 吻合**，没烂 —— 说明"有人顺手改"的约定是有效的，只是没门禁。）
  7. `docs/TEST_INDEX.md` 抬头数字烂了：`106 个测试文件` → **108**；`109 脚本 / 599 用例 / 5990 断言 / 6 orphans` → **108 / 608 / 6025 / 19**（重跑实测）。**表体是准的**：它登记的 108 个文件与 `test/*.gd` **1:1 无缺无重**，烂的只是抬头那两行。
  8. `docs/ARCHITECTURE.md` §2.1.5 弹幕链路首行还写"内容弹丸脚本 `*_bullet.gd` → `kernel_port()`" —— `data/**` 实测 **0 个** `*_bullet.gd`（全改 `BulletData.trajectory(lc)`）；§6「新增弹幕行为」也照旧教 `kernel_port()`。→ 换成现状链路 + 一句"旧载体已弃用（CONTENT_GUIDE §六 ⑥ 有历史说明）"。
  9. `docs/BACKGROUND_VISUAL_PLAN.md` §验证流程挂着 ✅ 的截图工具 `tools/background_capture.tscn` **已不在仓库**（`git log --diff-filter=D` 显示随 `54d7758`「3D 背景重构·死代码清理」删除）→ 改成"已删除 + `git show bfe853f` 可取回"，不抹记录。
  10. `docs/BASELINE_EVIDENCE.md` S12 证据路径写 `scenes/nav_page.gd`（实际 `scripts/scenes/nav_page.gd`）—— 证据文档里也一起修，免得下一个人按错路径找。
- **立"性质"栏位（防再次混装）**：
  - `docs/GDEXTENSION_KERNEL_DESIGN.md` §5：本文头部虽已声明"通用 VM 已被取代"，但 **§5 正文没有标记** —— §5.3 还写着"现按路径 B 主动推进"、§0.1 表还列"`kernel_bridge` 964 行"的旧痛。→ §5 开头加**醒目作废横幅**、§5.3 改口、§0.1 表后加"这是迁移前的痛，不是现状"。
  - `docs/LIFECYCLE_MODEL.md`：模型（权威）+ 决策理由 + 历史记录三段混在一起 → 头部加「本文怎么读：§0–§6/§11 是权威 · §7/§8 是理由 · §9/§10 是历史（只增不改）」。
  - `docs/BACKGROUND_VISUAL_PLAN.md`：README 索引写"待实施"，文档里却已有两批"已完成"；§0"当前视觉构成"其实是**改动前**快照 → 头部改成"部分已实施" + 三段读法。
  - `docs/DIALOGUE.md`：自称"归档"却在 `docs/` 根、且指向的路径 `data/stages/.../stage01.gd` 早已不是台词所在（现为 `data/dialogue/stage/stage01_dialogue.gd`）；**Stage 1 代码与本文档已明显不一致**（代码有 `portrait(...)` 情绪、省略补白、`d.event(...)`）。→ 改标签为**剧本原稿**、修路径、写明"已实现的面一律以代码为准"。
  - `README.md` 文档索引头补一条**分工表**：规则与状态 / 架构契约 / 历史 / 参考 / 内容原稿，**同一信息只在一处写权威版**。
- **读法共识（本次确立）**：**状态只认基线 S 表与 🔴 待改进**；`README`「当前状态」、`ARCHITECTURE` §8.3、`TODO_TEMP` P4/P5 都只是摘要 —— 冲突时以基线为准（已在各处以一句话注明）。
- **未动（留给作者拍板）**：`N2_NATIVE_INTEGRATION_PLAN.md` 是否归档（已完成，但 4 处文档仍引用它）、`TODO_TEMP.md` 的 P4/P5 与基线重复段是否删、`docs/archive/` 是否加 `ARCHIVE_INDEX.md`、`docs/*.txt` 里三份没被任何文档引用的原始资料是否登记、`docs/DIALOGUE.md` 剧本是否要按代码回灌一次。
- **根因与建议**：这些腐烂**全是"手工数字没人管"**（徽章、TEST_INDEX 抬头、sfx key 行、`[x]`）—— 表体因为有"顺手改"的习惯反而准。建议加一条**零成本文档哨兵**（纯 Python，进 `verify.sh` 当第 6 步）：① `TEST_INDEX` 登记的测试文件集合 == `test/*.gd`；② `DANMAKU_API` §7.2 key 集合 == `AssetRegistry.sounds` 去掉 `music_*`；③ §7.1 弹型集合 == `data/bullets/*.tres`；④ `README` 徽章数字 == `TEST_INDEX` 抬头；⑤ `python3 tools/log_archive.py --check`。**待作者点头再落。**
- **验收**：`./tools/verify.sh`（语法 351 脚本 0 失败 · 命名 0 违规 · 启动零错 · GUT **108 脚本 / 608 用例 / 607 通过**，唯一红仍是 `test_data_validity` 内容 WIP）。

### 2026-09-27 — 项目基线"还原本色"：正文只留规则与状态，证据/审计拆到附录（作者："没有基线那样精简了"）

- **作者反馈**：`BEST_PRACTICES_BASELINE.md` 也有点大，不像"基线"那样精简。
- **诊断**（299 行 / 33 KB）：不是体量大，而是**角色混杂** —— 里面约 130 行是**状态证据与审计**：
  S1–S13 每条下的 `[x] —— 文件/方法` 清单、K0 实测表、以及契约里散布的"原项目现状 / 2026-09-13 拍板"旁注。
  基线该只回答"规则是什么 / 现在到哪了"，证据该另置可查。
- **改**（照 log 那次同一思路：**正文薄、证据厚、双向链接**）：
  1. 新建 `docs/BASELINE_EVIDENCE.md`（附录）：装 S 各条**逐条证据**、**决策旁注**、**K0 实测审计表**；
  2. 基线正文改成：**改动前 60 秒速查**（最高频 6 条）+ **S1–S13 状态总表**（一行一条：状态 / 适用红线 / 还差什么）
     + R1–R22 + 五条契约 + 踩坑铁律 + 待改进（压成 6 条）；
  3. 契约里的"现状/实测/拍板旁注"搬进附录，规则原样保留；待改进里那条 M3 长叙事压成一行 + 指向附录。
- **结果**：299 行 → **209 行**（33 KB → 19 KB）；附录 151 行；**规则一条没少**（R1–R22 原文、铁律原文）。
- **顺手发现（报给作者）**：S13 的状态判据**已过期** —— 表头写 `✘（未用图集）`，但它的 `[x]` 证据显示
  弹幕贴图 2026-09-20 已整体进 1024² 图集、余两项（gutter / 拆图阈值）自注"不适用"。总表里标了 ⚠️ **待复核**，没有替作者改判。
- **验收**：语法 ✅ · 命名 0 违规 · GUT 全量（唯一红仍是 `test_data_validity` 的内容 WIP）· 两份文档互链 ✓。

### 2026-09-27 — 最佳实践日志"瘦身 + 可检索"：滚动窗口 + 顶部索引 + 按月归档（作者："太太太大了"）

- **作者反馈**：log 太大，找东西困难。
- **诊断**：1396 行 / 193 KB / **98 条**（跨 09-18～09-27）。文件头本来就写着"只留近期条目、历史归档 `docs/archive/`"，
  但**从没执行过**。顺带确认：**没有任何文档锚点指向具体条目**（所以搬动安全），也没有门禁/测试管它。
- **方案**（新增 `tools/log_archive.py`，一条命令可复跑）：
  1. **滚动窗口**：正文只留最近 `--days` 天（默认 2）、且不少于 `--keep-min` 条（默认 12）；
  2. **按月归档**：更早的条目追加进 `docs/archive/LOG_<YYYY-MM>.md`（**不删任何东西**，归档内文**时间正序**）；
  3. **顶部索引**：列出**全部**条目（新→旧），归档的带文件链接 → 一眼定位、不用翻半本书；
  4. 顺带把正文**按日期重排**（历史原因：早期是"追加"、后期是"前插"，文件顺序本来是混的）。
- **结果**：正文 **193 KB → 59 KB**（23 条 + 98 条索引）；归档 75 条（139 KB）；**总数守恒**（24−1 模板 + 75 = 98 ✓）。
- **踩坑**：① 条目正则必须 `re.M`（条目文本是多行，`$` 得按行匹配，否则"格式统一"会全判错）；
  ② 索引在 `## 记录` **之前** → 解析时必须**头和正文都清旧索引**，否则每跑一次就多一份（实测多出 9.7 KB 才回到一份）；
  ③ `--keep-min` 一开始把 `--days` 顶掉了（正确语义是"取最近 N 天，至少 keep-min 条"）。
- **验收**：`--check` 格式统一 ✓ · **幂等**（连跑两次字节不变 60877 ✓）· 正文/归档条目数守恒 ✓。

### 2026-09-27 — 修回归：奖励分"作废"后的**早退**掐掉了减伤倒计时与时限判定（作者报）

- **作者报**："boss 弹幕开头的减伤阶段如果 miss 了，符卡倒计时为 0 也不会结束，而且符卡一直都会是减伤的情况。"
- **根因**（上一个改动引入）：我把"作废后不再衰减、不再发 tick"写成了 `if is_bonus_failed(): return` ——
  但 `Boss._process` 后半段还负责**开卡减伤倒计时**（`_open_reduce_left`）和**时限判定**
  （`_elapsed >= time_limit → clear_phase`）→ 早退把它们一起掐掉：倒计时到 0 不结束 + 减伤永久挂着 ❌。
- **修**：只包住"奖励分那一段"——
  `if not is_bonus_failed(): 衰减 + emit tick`，其余照常执行。
- **测试**：`test_failed_bonus_still_times_out_and_clears_open_reduce`（作废后 ① 减伤倒计时照常走完 ② 到点仍发 `phase_cleared`）。
  ⚠️ 写这条时我自己又踩两下：`clear_phase` **只置 `_is_cleared`、不清 `_phase_data`**（`current_phase()` 仍非空），
  且 Boss 没有 `is_cleared()` 访问器 → 断言直接用 `_is_cleared`。
- **教训**：`return` 早退是"跳过某一段"里最危险的写法 —— 函数后半段还有别的职责时，语义就从
  "跳过 A"偷偷变成"跳过 A 之后的一切"。宁可包成 `if`，也不要早退。

### 2026-09-27 — 符卡记录页改成"**列全部符卡 + 三档显示**"（未遇见只给 uid 与问号，收取过才蓝）

- **作者需求**："所有符卡都显示，没有遇见的只显示 uid 和问号，只有遇见的显示名字，并且在此基础上有至少一次收取才把字体改为蓝色"。
- **改动**：
  - `_collect_cards()` 的来源从**记录**换成**花名册**：按舞台遍历 `stage_phase_order` → `phase_at(stage, idx, 当前难度)`
    → 取 `uid != 0` 的符卡（非符跳过），按 uid 去重；名字按**当前难度**取；
  - `_render()` 不再用"有记录"过滤 → 全部渲染；空状态文案改成「该难度暂无符卡」；
  - `_make_row()` 三档：`rec == null` → 名字位 `？？？`（压暗一档，uid 照常显示）；`rec` 有但 `captures == 0` → 真名普通色；
    `captures > 0` → 真名**蓝色**（原逻辑保留，只是现在以"有记录"为前提）；
  - 难度切换改为 `_reload_diff()`（重扫花名册 + 重渲染）—— 卡片列表现在随难度变（同槽位在不同难度可挂不同 uid 的卡）。
- **写第一版时踩的坑（探针抓到的）**：我最初按"每个 Boss 的第几槽"遍历再拿它当 `phase_at` 的参数 —— 但
  `phase_at` 收的是**舞台规范槽号**（道中 2 槽 + 关底 ⇒ 关底第 0 槽是舞台第 2 槽），多 Boss 面上两者不同 ⇒ 只扫出 2 张卡 ❌。
  改成遍历 `stage_phase_order(stage)` 的规范槽号后：Normal 4 张 / Extra 10 张 ✅（用无头探针逐条打印核对）。
- **测试**：`test_player_data_menu` 重写为 4 条 —— 无记录也要列全（来源=花名册）/ **三档显示**（？？？·真名·蓝）/
  分页改为**注入卡片**测（分页与来源解耦）/ 每页行数随面板高度。
  ⚠️ 两个小坑：`menu._make_row(...)` 在 `Control` 类型变量上返回 Variant → 显式标注类型；uid 显示是**全角数字**，
  断言别拿半角 `"9"` 去比。
- **验证**：语法 ✅ · 命名 0 违规 · `test_player_data_menu` 4/4 · 实截图 `.shots/spell_record_tiers.png`
  （蓝「阳符『宏辉抑世』」/ 普通「光符『来去匆匆』」/ 其余 `No.163–170 ？？？`）。

### 2026-09-27 — 符卡奖励分"作废"机制：期间 **miss / 用 bomb** → 不给分 + 数字位显示「失败」

- **作者需求**："在符卡未击破前 miss 或者使用了 bomb，这张符卡的奖励分数就无法获得，并且数字改为'失败'两个字"。
- **改动（信号 → 判定 → 计分 → 显示，一条链）**：
  1. `GameEvents` 新增 `phase_bonus_failed`（每阶段最多发一次）；
  2. `Boss`：新增 `_is_phase_bombed`（`start_phase` 重置）+ 接 `GameEvents.player_bomb`；miss / bomb 走同一个
     `_fail_bonus()`（**bomb 与 miss 同罪**）→ 标位 + 发一次信号；`is_bonus_failed()` 作为唯一判据，
     `_process` 在作废后**不再衰减也不再发 `phase_bonus_tick`**（否则下一帧的数字会把 UI 的「失败」覆盖掉）；
     `clear_phase` 的**计分**与**符卡簿干净收取**都改用它把关；
  3. `BossUI`：订阅 `phase_bonus_failed` → `announce_label.set_bonus_text("失败")`（前缀还在 ⇒「奖励分数：失败」）。
- **顺带明确的既有行为**：原来 miss 只挡"符卡簿干净收取"，**奖励分照样给** —— 现在两件事统一到 `is_bonus_failed()`，
  bomb 也一并纳入（原作口径：bomb 与 miss 同属失败尝试）。只想影响奖励分、不影响符卡簿的话，改 `clear_phase` 那一行即可。
- **顺手修的（作者同期挪了对话文件）**：`data/dialogue/reimu/…` → `data/dialogue/stage/stage01_dialogue.gd`，
  构建函数也改成 `灵梦战斗前/后`、`魔理沙战斗前/后` → 同步了预览默认脚本、内容测试、关卡脚本注释与文档路径。
- **测试**：`test_boss_phase` +5（bomb 作废且定格 / miss 作废 / 开卡前用 bomb 不算 / 作废击破不给分 / **对照组**干净击破照常给分）；
  `test_boss_ui` +2（作废 → 数字位「失败」且前缀仍在 / 切「失败」前的数字照常）。
  ⚠️ 两个小坑：测试里 `stub` 变量名撞 GUT 的 `stub()` 函数（改 `player_stub`）；`boss_ui.gd` 无 `class_name` → 测试用 preload 取常量。
- **验证**：语法 ✅ · 命名 0 违规 · `test_boss_phase` 29/29 · `test_boss_ui` 7/7 · 全量见下。

### 2026-09-27 — 对话预览加 `@export` + 窗口内选段（作者："要不要加 export 和选择具体对话"）

- **作者提议** ✅ 采纳：预览场景加 `@export`（编辑器里选好直接 F5）+ 窗口内下拉选段（不敲命令行）。
- **`@export` 三个**：`dialogue_script` / `dialogue_func`（留空 = 默认脚本 / 第一个构建函数）· `auto_play`（进场景即播；
  关掉 = 先在下拉里挑好再按「▶ 播放」，挑台词时更省事）。
- **窗口内**：`PanelContainer` 里两个 `OptionButton`（脚本 / 段落）+ `▶ 播放（R）`——换脚本自动刷新段落列表并播第一个；
  右侧 `Info` 显示当前段 + 按键提示。
- **优先级写死为：命令行 > `@export` > 默认** —— 自动化那条路（`--func=战斗后 --dry` / `--shot=`）**不受影响**，
  实测 `--func=战斗后` 仍覆盖 export 播的是战后段 ✅；名字写错会告警并回落到第一个（不静默）。
- **实现细节**：下拉用 `set_item_metadata` 存路径/函数名（不用下标去猜）；程序 `select()` 不触发 `item_selected`
  → 同步下拉不会形成回环；命令行给的脚本不在扫描目录里时临时加一项，作者在面板上看得见当前播的是谁。
- **验证**：语法 ✅ · 启动零错误（新面板场景）· 实截图 `.shots/dialogue_preview_picker.png`（下拉 + 首句）
  与 `.shots/dialogue_preview_outro.png`（CLI 覆盖成战后段）。
- **后续（作者："可以不要进入就播放吗"）**：`auto_play` **默认改 `false`** —— 进场景只出面板，
  挑好段再按「▶ 播放」/ R；命令行给了 `--script=` / `--func=` 时例外（那本就是"现在就播"）。
  顺手把语义拆正交：**`--shot=` 只截图当前状态**、不隐含播放（否则"不自动播"就没法截图验证）——
  于是 `--shot` 单独用 = 截初始面板，`--func=X --shot` = 播了再截 ✅（两条都实测过）。
- **再后续（作者："换段落后的自动播放还没改"）** ✅ 又漏了一处：`auto_play` 只管了"进场景"，
  两个下拉的回调里还留着 `_play_current()`。改成**换段 = 只选中**（`_show_idle()` 停掉当前演出、提示按 ▶/R），
  顺手把回调从 lambda 提成具名方法（`_on_script_picked` / `_on_func_picked`）好测。
  **新增 `test_dialogue_preview.gd`**（3 条）锁这条契约：进场景不播但预选第一段 · 换段只改选中且停演出 · 换脚本同理
  —— 这类"漏一处"的 bug 靠人眼抓太贵，锁住更省。

### 2026-09-27 — 对话的"方便测试方法"：**预览场景 + 干跑**（顺带修掉情绪被冲掉的老 bug）

- **作者提问**："对话没有方便的测试方法🥺" —— 确实：之前只能**把关卡打过去**才看得到（战后对话尤其痛），
  自动化测试倒是有（`test_dialogue_steps` / `test_stage01_dialogue`），但没有"看一眼"的手段。
- **先探路（三条能力都验过才动手）**：`GDScript.get_script_method_list()` 能列出构建函数
  （`static` + 零参数 + 返回 `DialogueSteps` 的元数据判据）、`script.call(&"战斗后")` 能按名字调静态函数、
  `DialogueRunner` 是**纯逻辑**可无头跑完并读台词。
- **做出来的两样**：
  1. **`scenes/ui/dialogue_preview.tscn`**（独立预览场景，不进关卡）：
     `--list` 列目录 · `--func=X` 指定段 · 窗口模式真 `DialogueBox` 演出（Z/Enter/X · R 重播 · Q 退出）·
     `--shot=x.png` 截图（能进自动化检查）· 参数可省（默认脚本 + 第一个构建函数）；
  2. **`DialogueDryRun`**（干跑收集器）：无头把一段跑完，返回 `texts/speakers/emotions/events/finished`，
     `--dry` 直接打印成"台词 N 句 / 事件顺序 / 跑完与否"——**改完台词的最快检查**，也是测试的复用夹具。
- **顺手挖出并修掉一个老 bug**（作者把 intro 改成句柄写法时暴露）：`_build_line` 把气泡 emotion
  **默认写成 `"通常"`**，而 `StageState.apply_line` 的规则是"**非空才覆盖**"→ 于是
  `reimu.portrait("笑").line("…")` 刚设的表情**被这句话冲掉** ❌，违反文档里的"声明即改变，不声明不动"。
  修法：气泡 emotion 默认 **空**（screen 的字典形态同理），想复位就显式写 `{"emotion": "通常"}`。
- **测试**：`test_line_keeps_emotion_unless_declared`（回归锁：`portrait→line→line→复位` 的 emotions 应为 `笑/笑/通常`）；
  `test_stage01_dialogue` 新增两条**干跑**用例（战前/战后**整段必须跑得完** + 事件顺序）——
  跑不完 = 玩家卡在对话里，比台词写错严重得多；情绪断言改成**读舞台状态**（对写法免疫）。
- **验证**：语法 ✅（350 脚本）· 命名 0 违规 · `test_dialogue_steps` 28/28 · `test_stage01_dialogue` 9/9 · 实截图 `.shots/dialogue_preview.png`。

### 2026-09-27 — 加 `ActorHandle`：对话"谁做什么"（`enter()` 返回句柄）

- **由来**：上一步把六个"演出版"动词改成收 `CharacterProfile` 后，作者追问"更进一步的选项"，
  我给了 `ActorHandle` 设计（照 `BossHandle` 的路子），作者说"试试"。
- **核心**：`DialogueSteps.enter()` 现在**返回 `ActorHandle`** —— "谁"是**接收者**而不是参数：
  ```gdscript
  var reimu := d.enter(REIMU, Vector2(50, 230))
  reimu.line("啊，什么线索都没有…")
  var ka := d.enter(KA, Vector2(550, 230))
  ka.line("哦呀，弱小的人类怎么会在永夜出门？").portrait("耍帅").move(Vector2(500, 230), 0.6)
  ka.exit()
  ```
- **设计上的三条克制**（避免第二个真相 / 两套并列）：
  1. 句柄是**薄委托**：`_d.portrait(_profile, key)` —— **没有第二套构建逻辑**，
     产物与低层写法逐字段一致（`test_actor_handle_matches_low_level_verbs` 逐步对比 □）；
  2. 句柄**只在构建期写步骤**（不像 `BossHandle` 要运行时解析注册表）→ 更简单，也不会与播放器状态纠缠；
  3. **多角色同屏留在 `d.screen()`**（句柄表达不了"一屏多泡"）、`event`/`wait` 也留在 `d`。
- **顺带两处 DX**（作者列的待拍板项）：`exit()` 之后再用同一句柄 → **告警一次**（不拦步骤）；
  同一角色连续两次 `enter()`（漏 `exit`）→ 告警；`has_entered(profile)` 可自检；
  `enter(null)` 不再崩（跳过该步并告警）。
- **没动作者的剧本**：`data/dialogue/reimu/stage01_dialogue.gd` 一字未改（他正在改台词，
  小步走避免打架）；范例放**文档 §二**与**测试**里，要翻成句柄写法随时可做。
- **测试**：新增 5 条（句柄↔低层产物一致 / 链式与 actor key / `exit` 语义 / 重复 enter 两步都落 / `enter(null)` 安全）；
  ⚠️ 写测试时踩到一次自己的断言错：**LINE 步的说话者在 `line_data.bubbles` 里**，`char_name` 只服务演出动词 —— 两种载荷形态。
- **验证**：语法 ✅（348 脚本）· 命名 0 违规 · `test_dialogue_steps` 27/27 · 全量见下。

### 2026-09-27 — `DialogueSteps` 的六个"演出版"动词改收 `CharacterProfile`（作者："exit 为什么不传 profile？"）

- **作者观察** ✅ 成立：`enter(profile, …)` / `say(profile, …)` 收 profile，但
  `exit` / `move` / `flip` / `dim` / `portrait` / `bubble` **六个都收 `char_name: String`** —— 系统性不一致。
- **为什么会这样（不是好理由，是历史泄漏）**：步骤的落点字段是 `DialogueStep.char_name`，
  播放器（`StageState`/ActorState）**按名字查 actor** → 当年就把这个 stringly key 直接暴露给内容层了。
  但 profile 里本来就有 `char_name`，内容层也一直拿着 profile（`REIMU`/`KA` 常量）→ 没必要。
- **改**：六个动词收 `CharacterProfile`，内部经 `_actor_key(profile)` 解析成 actor key（null → 告警 + 空 key）；
  步骤载荷**仍是** name（播放器契约不变）。头部用法示例一并改。
- **实测价值**：改完立刻在**编译期**揪出两处遗留的字符串调用点 ——
  `Invalid argument for "move()" function: argument 1 should be "CharacterProfile" but is "String"`
  （旧 API 下这两处会**静默**留到最后：写错名字 = 那一步找不到 actor，什么也不发生）。
- **测试**：`test_stage_ops_take_profile_and_store_actor_key`（锁"profile 进、actor key 出"这条转换，
  防以后有人把步骤载荷也改成 profile —— 播放器是按名字查的）、
  `test_stage_ops_tolerate_null_profile`（null → 告警不崩、key 为空、不误伤别的 actor）。
- **文档**：`DIALOGUE_SYSTEM` §三 的动词签名 + "为什么都收 profile" 说明。
- **验证**：语法 ✅ · 命名 0 违规 · `test_dialogue_steps` 22/22 · 全量见下。

### 2026-09-27 — 对话事件 handler 里的 `if` 巡检收口（作者："对句柄的判断是不是太多了"）

- **作者观察** ✅ 成立。但**不能一刀切删** —— 先按性质分四类，各归其位：

  | 现场守卫 | 性质 | 处置 |
  |---|---|---|
  | `if ctx and ctx.active()`（4 处） | 生命周期巡检 | **收进 `StageDirector._route`**（全局唯一判据：关卡已拆/未装配 → 事件一律不派发）→ handler 不必再写 |
  | `if 关底卡摩瑞句柄:` / `resolve() if 句柄 else null`（2 处） | 句柄**延迟创建**（`boss_enter` 才建）导致 | **句柄改在 `start()` 里先建**（此刻实体未生成 = 未解析；句柄动词对空目标静默 no-op，见 `test_verbs_tolerate_missing_boss`）→ 永不为 null |
  | `not (句柄 and 句柄.exists())`（防事件重发冒出第二只） | 内容侧防重入 | **下沉进 `StageDirector.boss()`：同名槽位幂等**（已有 Boss 就只返回句柄）→ 内容不必自己判 |
  | `_timeline != null` | **死守卫**（`_timeline` 是 `CoroutineScript` 的字段，`start_timeline()` 后恒非空） | 删 |
  | `fb.current_phase() == null`（已开战就别再开） | **语义**判据（不是空值巡检） | 留 —— 但改成早返回，读起来是"前置条件"而非嵌套 |

- **结果**：`_on_boss_enter` / `_on_display_name` / `_on_bgm_switch` 各剩 1~2 行纯动词；
  `_on_boss_fight` 只剩两个语义守卫（不在场上 → 告警返回；已开战 → 返回）。
- **新增测试**：`test_dialogue_events_ignored_when_stage_not_live`（关卡不存活 → 不派发，这是"handler 不用判 active"的依据）、
  `test_boss_does_not_respawn_existing_slot` / `test_boss_spawns_when_slot_empty`（幂等两个方向，用 `SpawnSpy` 数 spawn 次数）。
- **文档**：`CONTENT_GUIDE` 加"事件 handler 里不用堆 if"的三条契约；`DIALOGUE_SYSTEM` §四 加"派发只在关卡存活时发生"。
- ⚠️ 注意一个细节，别把收口收错：对话播放期间宿主 runner 是 **paused 而非 stopped**，
  `ctx.active()` 仍为 true → 战前 `boss_enter`/`boss_fight` 这类"对话进行中"的事件照常派发 ✅
- **验证**：`test_stage_director` **11/11** · 语法 ✅ · 命名 0 违规 · 全量见下。

### 2026-09-27 — `StageDirector.dialogue` 改收 `DialogueSteps`（作者建议）；并订正"对话不冻结时间轴"的错误说法

- **作者建议**：`dialogue()` 的参数该收 `DialogueSteps` 而不是 `Array` —— 采纳 ✅
- **改**：`dialogue(p_steps: DialogueSteps)` + null 守卫，内部才取 `p_steps.steps`；
  内容侧两处调用点去掉 `.steps`（`_stage_director.dialogue(STAGE01_REIMU.战斗前())`）；
  `test_stage_director` 补"null / 无 runner 不崩"用例。底层原语（`ctx.play_dialogue_steps` /
  `DialogueService.play_steps` / `DialogueBox.play_steps`）仍收 `Array` —— 它们是机制层，
  夹具也直接造步骤数组，没必要把容器类型往里灌。
- **强类型的好处（实测）**：把 `.steps` 传回去，**编译期**就报
  `Invalid argument for "dialogue()" function: argument 1 should be "DialogueSteps" but is "Array[DialogueStep]".`
  —— 内容层不必知道步骤容器的内部结构，传错也不用等运行时。
- **订正（上一轮我说错了）**：我曾写"对话**不冻结时间轴** → 用 `wait` 秒数接收尾会被切断"。事实**相反**：
  `DialogueService.play_steps` 会 `pause()` **宿主 runner**（`box.finished` → `resume()`），
  所以对话期间宿主时间轴**确实不推进**，`wait` 方案是**能工作**的（事后偏移自然顺延到对话结束）。
  推荐"事件收口"的真实理由改为：
  1. **不依赖实现细节** —— "对话会 pause 宿主"是播放器的内部行为，哪天改掉，`wait` 方案会**静默地**在对话中途收尾；
  2. **偏移是绝对值** —— `wait(n)` 都从"最后一张击破"那个游标算起（不是"上一句之后"），
     两个 wait 的先后要靠手算秒数维持，台词/演出时长一改就得重算；
  3. **语义直白** —— `stage_end` = "剧本最后一句就是这关结束"，与时长天然解耦。
  已同步 `docs/DIALOGUE_SYSTEM.md`（§二 用法 + §四 新增"事件不冻结 / 但整段对话会 pause 宿主"的区分）与 `CONTENT_GUIDE`。
- **验证**：语法 ✅ · 命名 0 违规 ✅ · `test_stage_director` **8/8** · 全量 **583 用例 / 582 通过**（唯一红仍是 `test_data_validity`）。

### 2026-09-27 — "Boss 击破后、关卡结束前加对话"：接上战后对话（事件收尾）+ 收尾作者挪文件的断链

- **作者提问**："想在 Boss 被击破后、关卡结束前加对话怎么办？"
- **关键机制约束**：对话**不冻结时间轴**（`docs/DIALOGUE_SYSTEM.md` §四明写）→ 若写成
  `wait(6.0) → finish_stage()`，台词一长 / 玩家读得慢，关卡就会**在对话中途**结束。
  **正确写法 = 行间事件收口**（与战前 `boss_enter`/`bgm_switch`/`boss_fight` 同一套）：
  - 对话最后一步 `d.event("stage_end")`；
  - 关卡脚本 `_stage_director.on("stage_end", _on_stage_end)`，handler 里 `finish_stage()`。
- **改**：
  1. 战后对话落在作者新的组织方式里（他刚把对话从 `data/dialogue/<stage>/` 挪到 `data/dialogue/<角色>/`）：
     `data/dialogue/reimu/stage01_dialogue.gd` 里加第二个 static 构建函数 **`战斗后()`**
     （骨架 + `# TODO 作者的台词`，台词是作者的，我只搭结构 + 事件）；
  2. `stage01.gd`：`wait(2.0) → defeat()`、`wait(4.5) → dialogue(战斗后())`（退场 tween 走完），
     收尾改为 `_on_stage_end()`；注册 `on("stage_end", …)`；顺手修掉指向旧路径的注释。
- **顺手修掉挪文件的断链**（作者正在重构，门禁当时是红的）：`test/test_stage01_dialogue.gd` 还 preload 已删除的
  `data/dialogue/stage01/intro.gd` → 改成新路径，并补两条战后测试（**最后一步必须是 `stage_end`**、必须有非空台词）；
  `docs/DIALOGUE_SYSTEM.md` 的路径/示例/§四 全部同步（`<stage>` → `<角色>`，并新增"战后对话 / 用对话收尾"段）。
  （这也验证了上一轮刚补的语法门禁判据：断链立刻报 `[SYNTAX FAIL] test/test_stage01_dialogue.gd` ✓）
- **机制测试**：`test_stage_director.test_stage_end_event_routes_to_finish_stage`（发 `GameEvents.dialogue_event("stage_end")`
  → 路由到 `finish_stage()`），锁住"事件真的能收尾"这条链。
- **验证**：语法 ✅ · 命名 0 违规 ✅ · `test_stage01_dialogue` 7/7（5 战前 + 2 战后）· `test_stage_director` 7/7 · 全量 **582 用例 / 581 通过**（唯一红仍是 `test_data_validity` 的内容 WIP）。

### 2026-09-27 — 对话构建函数**必须 static**；顺手修好被"静默跳过"的内容测试 + 补语法门禁盲区

- **作者提问**："`data/dialogue/stage01/intro.gd` 的函数需要 static 吗？" → **需要**，原因是**调用点形态**：
  `const STAGE01_INTRO = preload("…/intro.gd")` + `STAGE01_INTRO.战斗前()` 是在**脚本类**上调用，
  GDScript 只允许静态函数（非 static 的报错原文就是 `Parse Error: Static function "…" not found in base "…"`）。
  `docs/DIALOGUE_SYSTEM.md` 也早把这条写成约定（原先写的是 `static build()`）。
  不想 static 就得 `INTRO.new().战斗前()`（`extends RefCounted` 支持），但纯生产步骤的脚本没有实例状态，白搭一次分配。
- **顺手发现的真问题**：作者把 `build()` 改名成 `战斗前()` 后，`test/test_stage01_dialogue.gd:12` 还在调 `build()`
  → 该测试文件**解析失败** → GUT 报 `Ignoring script … because it does not extend GutTest` 后**静默跳过**
  （那 5 条内容断言根本没跑）。**这正是那条内容测试存在的意义**（注释里写着"改台词/改名时该红"），
  只是它"红"的方式是编译错误而非断言失败 —— 探针实测：这种文件 `load()` 返回**非 null**、`can_instantiate()==false`。
- **改**：
  1. 测试调用改成 `STAGE01_INTRO.战斗前()`（实测命名契约放行：0 违规）；
  2. `docs/DIALOGUE_SYSTEM.md` 的约定段与示例同步成 `static <构建函数>()`，并写明"为什么必须 static"；
  3. **补门禁盲区**：`tools/check_syntax_runner.gd` 原先只判 `load() == null` → 漏掉**依赖级**编译失败
     （脚本自身没语法错、但调用了别处不存在的函数）。改成同时判 `can_instantiate()`。
     验证：把测试改回旧名 → `[SYNTAX FAIL] res://test/test_stage01_dialogue.gd` + `1 个失败`（改前是 `0 个失败`，只有 SCRIPT ERROR 行提示）✓
- **验证**：语法 ✅（347 脚本 0 失败）· 命名 0 违规 ✅ · `test_stage01_dialogue` **5/5 通过**（终于真在跑）· 全量 579 用例（唯一红仍是 `test_data_validity` 的内容缺口）。

### 2026-09-27 — 全破音效换成专用素材 `boss_die`（替掉借来的 `enemy_die` 占位 key）

- **作者提供素材** `assets/Sound/boss_die.wav` → 新增 key `boss_die`，`Boss.DEFAULT_DEFEAT_SFX` 从占位的
  `boss_defeat`（借 `enemy_die`）改成它；**删掉占位 key**（`sounds` + `SFX_DB` 各一行，避免留死 key）。
- **取值**：先跑 `tools/sfx_db_baseline.py` 拿到该素材的 RMS 基准 **−4.4**（比 `enemy_die` 响）。
  但直接填基准会让整表均值掉到 **−0.53**（越 ±0.5 契约）→ 按老规矩**整表居中 +0.5**，并把 `boss_die`
  抬到与其余未手调音效**同档**（工具判定 = 基准）：最终 **−3.0**，均值 **+0.02** ✓。
- **验证**：`test_sfx_mix` 3/3；工具输出 `boss_die -4.4 → -3.0 +0.3 = 基准`，`kira`/`msl`/`marisa_damage`
  仍为手调（−7.8）✓；启动零错误（新素材能被正常导入/预载）。
- 命名沿用 `*_die` 家族（`enemy_die` / `player_die` / `boss_die`）✓。
  ⚠️ 视觉特效场景仍叫 `scenes/effect/boss_defeat.tscn`（`defeat_fx` 字段）—— 那是**画面**，与音效 key 无关。

### 2026-09-27 — 魔理沙子机（focus）发射/命中音效各压 7 dB（两轮；并修 `sfx_db_baseline` 的判定口径）

- **作者反馈**（两轮）：魔理沙子机的**子弹发射**与**击中**音效偏大 → 第一轮各 −4 dB，作者"再小一点" → 第二轮再 −3 dB（**累计 −7**）。
- **定位**（两个 key 各自只被一处用，改表零副作用）：
  - 发射 `msl` —— `marisa_shoot.gd:88`（focus 分支 ~12 次/秒）
  - 命中 `marisa_damage` —— `marisa_shoot.gd:85` 的 focus 弹专属 `hit_sfx`（走节流 0.05 ⇒ 最多 20 次/秒）
  - 非 focus 的流水激光**没有**发射音、命中走默认（默认命中只在 Boss 残血播）⇒ 不在这次范围内。
- **先量后调**（`tools/sfx_db_baseline.py` + 自写 RMS 脚本）：这两个 key 此前都是 **"= RMS 基准"**（从没按频率调过），
  而 `kira`/`player_shoot` 早被按频率压过 −7.8/−9.1 —— 而 `marisa_damage` 的音源 RMS 又最高（表内 +5.9 = 全表最响）。
  压完两个 key 落到 **相对基准 −7.9**，正好与 `kira`（−7.8）**同档** ⇒ 高频持续音的均衡口径一致了。
- **算术约束（这次的坑）**：`test_sfx_mix` 要求**整表均值 ≈ 0 ± 0.5**。在 18 个 key 里压 2 个：
  - **不补偿**的话，压过 `0.5 × 18 / 2 = 4.5 dB` 就必然越界；
  - 所以走**整表居中补偿**：其余 16 行按 `c/8` 随压幅一起抬（c = 压幅）⇒ 均值恒定在 −0.17 ✓，压幅**不设上限**。
  两轮实际值：其余 16 行 **+0.5 → +0.9**（`+0.4`），`msl`/`marisa_damage` 从基线 +1.2/+5.9 → **−5.8/−1.1**。
- **顺带修工具**：整表平移后 `sfx_db_baseline.py` 把 18 个 key 全标成"手调"，把"哪些是耳朵定过的"这个信号淹了。
  改成判定前先扣掉**公共平移（取中位数，少数被手调的 key 不该拖偏基准）** —— 表本来就是**相对**语义
  （总电平在调用点 `SFX_LEVEL_DB`）。修完输出：手调 8 个，`msl`/`marisa_damage` 相对基准 **−7.9**，其余 `+0.0 = 基准` ✓
- **验证**：`test_sfx_mix` 3/3（每音效有基准 / 中心化 / ±12 dB 内）；工具输出如上。
  再想更小：**继续压这两个 key、同时把其余 16 行各抬 `压幅/8`**（一行一行抬，别动调用点）。

### 2026-09-27 — 全破反色圈改成**与自机 miss 同一套参数**（作者纠错：同心不等半径不是 miss 的做法）

- **作者追问两次**：先问"不能像自机 miss 一样也生成 5 个反色圈吗"，我第一版做成 **5 圈同心、半径错开**（想要涟漪），
  作者立刻指出"**这也不是按自机 miss 的反色圈做的呀**" —— 对，miss 的做法完全不同。
- **去读真实调用**（`scripts/player/player.gd:316-321`）才看清 miss 是：
  ```gdscript
  _miss_circle(pos, 2.5, 1280)                      # 5 发：同半径（满屏）、同 duration
  _miss_circle(pos + Vector2(100, 0), 2.5, 1280)    #      圆心呈十字 ±100 偏移
  _miss_circle(pos + Vector2(-100, 0), 2.5, 1280)
  _miss_circle(pos + Vector2(0, 100), 2.5, 1280)
  _miss_circle(pos + Vector2(0, -100), 2.5, 1280)
  _miss_circle(pos, 1.0, 1280, 0.0, 1.5)            # + 1 发延迟 1.5s 的"回声"
  ```
  → `Boss.play_defeat()` 逐字照搬（只换圆心）：`DEFEAT_RING_RADIUS/DURATION/DELAYED_DURATION/DELAY/OFFSETS`。
- **两个非显然的点（都是读 shader/实现才敢写的）**：
  - 反色是**奇偶**语义（`raw_mask` 奇=反色、偶=复原）。**同半径 + 圆心错开** ⇒ 中央被 5 发全盖（奇 → 反色），
    边界因偏移而成**五瓣月牙**；再叠上延迟那发 ⇒ 中央变成 6 发（**偶 → 复原**），于是"中心回色、外面仍反色"的
    **回声环**——这正是 miss 那第 6 发的观感（实测 t≈1.9s 那帧）。
  - 所有圈的 `start_delay + duration` 必须**相等**（同时收）：`MissCircleLayer` 在"本帧有圈到期且剩余圈数为奇"时
    会**同帧全清**（治反色闪烁的老 bug），不同时收的话后几发会被提前掐掉。miss 的 `1.5 + 1.0 = 2.5` 正好满足 —— 那不是巧合。
- **教训**：想"照某个现成效果做"时，**先去读那次调用的真实参数**，别凭语义想象（我凭"同心涟漪更好看"想象了一版，白做两轮）。
- **验证**：`test_boss_phase.test_play_defeat_spawns_miss_style_inverted_rings`（记录层 spy：**6 发** = 5 发十字偏移 + 1 发延迟，
  半径全为 1280）；实渲染四帧 `.shots/boss_defeat_miss_{1grow,2full,3echo,4end}.png`。
  ⚠️ 顺带记一个渲染踩坑：xvfb 里**帧率不是 60**（首帧 17fps），按"等 N 帧"或"等 N 秒"截图都会拍空 ——
  改成**轮询效果自身的 age** 才拿到确定性帧。

### 2026-09-27 — Boss「全破」演出 + 关卡收尾动词（`defeat()` / `finish_stage()`）

- **作者提问**：需要"boss 被完全击破的特效"和"后续的关卡控制"。查下来这条链**是断的**：
  - **全破没有任何特效**：`Boss._die()` 只做隐藏血环 + 注销 + `boss_defeated` 信号（+ 非 `exit_controlled` 时 `queue_free`）。`death_effect.tscn` 只有 `Enemy` 在用（Boss 是它的**兄弟类**，没接这条）；唯一的反馈是 `clear_phase` 里那次清弹扫掠。
  - **收尾没有出口**：`Timeline.tick()` 的完成判据只看 `_events`（`sequence_phases` 不算未完成）→ 事件耗尽就 `finished`；但关卡脚本 `auto_stop` 默认 **false**，所以时间轴跑空**也不会**结束 —— 结果 stage01 关底 `start_sequence_now(...)` 之后**什么都没接**：打完最后一张卡，Boss 站着不动、关卡永不结束。
- **判据澄清（差点写错两处）**：
  - `stop_stage()` **不能**当通关用：它**先**把 `current_stage` 置空，`_on_stage_finished()` 会在 `if not current_stage` 处 return、**不发 `stage_cleared`**（那是"拆场景"）。
  - 也不能靠 `_coroutine_script.stop()` 触发收尾：`CoroutineRunner.stop()` 只清任务、**不发 `finished`**（`finished` 只在任务自然跑完时发）。→ 所以 `finish_stage()` **直接收尾**再停脚本。
- **新增（表现层）**：
  - `scenes/effect/boss_defeat.tscn` + `scripts/effect/boss_defeat_fx.gd`（`extends HitEffect`，可池化、自足）：白闪（`glow_dot` 放大快收）→ 冲击波光斑 → **五个爆点片**（`etbreak`）→ 整体淡出；爆点**自动收集场景里的 AnimatedSprite2D**（加一片 = 场景加节点，不改代码）。
  - `Boss.play_defeat()`：定格（**保存原 time_scale 再恢复** —— 工作台 12x 快进不会被拉回 1.0；`create_timer(..., ignore_time_scale=true)` 到点恢复 + `_exit_tree` 兜底）→ 大范围清弹 → 播 FX → 震屏 → 音效 → 本体闪白淡出，两层顺序（`create_tween().set_parallel`）。
  - 数据可配：`BossData.defeat_fx` / `defeat_sfx` / `defeat_hitstop`；`AssetRegistry` 加 `boss_defeat` 音效 key（暂借 `enemy_die` 素材）+ 对应 `SFX_DB` 一行（`test_sfx_mix` 要求表里每个 key 都有基准音量，正好拦住漏配）。
- **新增（流程层）**：`BossHandle.defeat()`（= 打死，区别于 `retreat` = 没打死）· `StageRuntime.finish_stage()` · `StageDirector.finish_stage()`；内容侧 stage01 关底补 `wait(2.0).defeat()` + `wait(6.0).finish_stage()`，道中改用 `defeat()`。
- **走过一次弯路（记下来）**：第一版把**满屏冲击环**接到了 `MissCircleLayer.add_miss_circle` —— 渲染出来发现那玩意是**反色满屏圈**（自机 miss 语义），第一帧就把整场盖白、FX 全被压在下面。改成 FX 场景内置 `glow_dot` 冲击波 + 三层→五层爆点，并把 `play_defeat` 收敛成"只播一次 FX"（编排留在场景里）。**教训：复用前先渲染一张看它长什么样。**
- **验证**：`test_stage_runtime`（`finish_stage` 发 `stage_cleared` / `stop_stage` 不发 / 未激活 no-op）· `test_boss_phase` 加定格保存-恢复 & 出树兜底 · `test_stage_director` 加 `defeat()` 容错 + `finish_stage()` 转达；**实渲染**三帧存 `.shots/boss_defeat_{early,mid,late}.png`。全量 **578 用例 / 577 通过**（唯一红仍是 `test_data_validity` 的内容缺口）。

### 2026-09-26 — 符卡练习 BGM 改成**每 Boss 一首**（道中曲 / Boss 曲可分别配）

- **作者反馈**：练习 BGM 只能整面一首 —— 但练习是按「单张卡」打的，道中的卡该放道中曲、关底的卡该放 Boss 曲，调不了。
- **现状根因**：练习曲取自该面的 `StageData.bgm_key`（`game_scene._start_practice_game` 里的 `StageCatalog.find(stage_id)`）→ 一个面只有一个 key，而 `BossData` 上没有任何练习曲字段。
- **改动（回落链：Boss → 面默认）**：
  - `BossData` 新增 `@export practice_bgm_key`（空 = 回落该面 `StageData.bgm_key`；只影响练习，正常关卡仍由关卡脚本 `stage_director.bgm()` 起）。
  - `StageCatalog.bgm_key_of(stage_id)`（面的默认练习曲）+ `BossCatalog.practice_bgm_key(p_boss, stage)`（**回落链的唯一 owner**，纯函数、可单测）。
  - `PracticeSession.bgm_key` + `start(..., p_bgm_key)`（随载荷带上本局曲目，`clear()` 里清掉）；菜单在 `_start_practice()` 里按**选中的卡属于哪只 Boss**解析；`game_scene` 优先用载荷、没带则回落面默认（旧路径/合成场景仍能出声）。
  - 内容：**关底 Boss 填 Boss 曲**（`卡摩瑞关底` → `stage1_boss`、`似新存关底` → `stageEX_boss`），道中 Boss 留空 = 用面默认（道中曲）。于是「道中曲 / Boss 曲各就各位」只花了两个字段。
- **为什么粒度选 Boss 而不是 Phase**：道中 / 关底本来就是 `BossData` 的区分（`section_label`）；练习一场只面对一只 Boss，所以 Boss 粒度既够用、又不会给每张卡都加一个字段。
- **踩坑**：`practice_bgm_key(p_boss, stage)` 一开始把形参写成 `boss` → **遮蔽同类里的 `boss()` 函数**，项目把 `shadowed_variable` 提升为错误 → 编译红。按基线「形参遮蔽成员/函数 → 加 `p_`」改成 `p_boss`。
- **验证**：新增 `test_boss_catalog.test_practice_bgm_key_boss_overrides_stage_default`（Boss 覆盖优先 / 空缺回落面默认 / 两边都空 → 空串不崩）、`test_stage_catalog.test_bgm_key_of_reads_stage_data`（真内容 + 未收录面 → ""）、`test_practice_mode.test_practice_bgm_key_travels_with_payload_and_clears`（载荷带上 + 结束清空）。**实测** 571 用例 / 570 通过（唯一红仍是 `test_data_validity` 的内容缺口）。
- **文档**：`CONTENT_GUIDE` BossData 字段 + 「练习放哪首」专段（含本仓库现状与"想反过来也行"）；`TEST_INDEX` 计数刷新（层计数按 `func test_` 实测重算，合计 571 = GUT 571）。

### 2026-09-26 — 新增 `reflect()` 镜面方向原语（撞墙反弹不再只能"朝 Boss"）

- **由来（作者提问）**：卡摩瑞二符想做撞墙**镜面反弹**。`bounce` preset 的 `bounce_angle` 只是「相对 Boss 方向再转多少」，**拿不到入射方向** → 结构上就做不出镜面（它的展开 = `accel_heading` + `until_at_wall` + `emit(toward(T_BOSS, angle))` + `despawn`）。
- **先做的判断：不加"读/写自身状态"，加一个具名变换**。镜面本质是「读自身速度 → 算 → 写成新方向」，而"表达式"是 `LIFECYCLE_MODEL` §0 **铁律 2 明文排除**的（"无 pc / goto / **表达式** / 任意循环"；"刻意不在词汇里的：任意表达式…需要这些 → 说明它是低频逻辑"）。所以按 V21（`until_speed` = 为一个需求加一条**窄读**）的同一思路，落成**方向代数上的一个具名变换**。
- **关键实现选择：撞哪面墙由内核判，创作者不声明**
  - `at_wall` 是**纯谓词** —— 只把「夹到边上的相位结束落点」写进 Until 输出、**不改弹自身位置**（`danmaku_store.cpp` 的 `case 23`）→ **落点本身就携带"撞了哪条边"的信息**；
  - 于是 dk=6 只需看**发射点 `pos`** 贴哪条边来翻分量：左右翻 x / 上边翻 y / 角落两边都翻（= 原路返回）；
  - 好处：**零新增 per-bullet 状态**（不加数组、不用维护 swap-remove 一致性），且 `reflect()` 与 `at_wall` 的 mask **天然同步** —— 不必让创作者把"撞哪面墙"再声明一遍（那正是会脱节的地方，也是 `AT_PHASE_END` 存在的同一个理由）。
- **改动**：
  - C++ `_resolve_dir`：加 `const Vector2 &vel` 形参 + `p_dk == 6` 分支（翻分量后再 `rotated(angle)`；都不贴边 → 退化为自身朝向，不静默乱转向）。**翻的是速度不是 heading** —— heading 只在 spawn / `set_heading` / `rotate` 更新，`accel_world` 之后会和速度脱节。3 个调用点补 `Vector2(_vx[i], _vy[i])`。
  - GDScript：`D_REFLECT` / `DK_REFLECT := 6` / `static func reflect(angle := 0.0)` / `_dir_args` 映射。`content_signature()` 哈希的是编译后 args → 新 kind 自动进签名，结构共享不受影响。
  - **不动参考解释器**：`test/reference/**` 是冻结 vendor、不实现新原语 → 镜面写成**原生专属用例**，parity 套件不受影响。
- **验证**：新增 `test/test_native_reflect.gd` 6 条：右墙 `(1,1)→(-1,1)`、上墙 `(1,-1)→(1,1)`、右上角**原路返回**、`reflect(90°)` = 镜面再转（不是入射再转）、未贴边 → 退化自身朝向、编译后参数里出现 `dk = 6`。**实测**：6/6 通过；`test_native_executor` / `test_native_event_dispatch` 等 parity 全绿（新 dk 没碰旧词汇）；扩展 debug + release 均重建成功。
- **文档**：`DANMAKU_API` §3.5 方向表 + 镜面用法块；`LIFECYCLE_MODEL` 方向糖清单；`CONTENT_GUIDE` ④ 全词汇 + 镜面段；`TEST_INDEX` B 层新增一行。

### 2026-09-26 — 符卡奖励分改为**规则计算**（原作口径：难度权重 × 面序号 × 50 万；时限内均匀衰减到 30%）

- **目标**：奖励分不再逐张手填，由规则算；衰减也按原作口径。
- **规则（作者实测原作总结 + 多轮核对 + 定调）**：初始 bonus = **难度权重 × 面序号 × 500,000**（**乘法**）。难度权重 **E/N/H/L = 1/2/3/4，EX = 2**（Extra 单独破例）；面序号 1..6 / EX 面 = 7。**只有符卡有**（非符 0）；**非时符在时限内均匀（线性）衰减到初始的 30%**（速率 = (初始 − 30%) / `time_limit`，**不是固定值**）、**时符完全不衰减**。例：1 面 Easy = 50 万、1 面 Normal = 100 万、3 面 Lunatic = 600 万、6 面 Lunatic = 1,200 万、EX 面 = 700 万。
- **口径变更史（同一入口三轮）**：①「(权重+面序号)×100万」→ ②「(权重+面序号−1)×100万 → ×50万」→ ③ 现口径「权重 × 面序号 × 50万 + EX 权重 = 2」。**每次只改 `SpellBonus` 一处**，内容与调用方零改动 —— 这正是把规则抽成纯函数的价值。
- **速率为什么必须派生**：「均匀到 30%」这条不变量本身就把速率钉死成 `(初始 − 30%) / time_limit` —— 写成固定值（如「每 5 秒 100 万」）在长卡/短卡上都会失配：短卡掉不到 30% 就超时、长卡早就掉到底干等。
- **无面（`stage_no <= 0`）→ 初始 0**：乘法口径下面序号是因子，缺了就是 0（合成 Boss / 没挂面的夹具不再凭空得到奖励分）。
- **改动**：
  - 新增 `scripts/data/spell_bonus.gd`（`class_name SpellBonus`）= 规则的**唯一 owner**：`initial(stage_no, difficulty, is_spell)` / `decay_floor(initial)` / `decay_per_second(initial, time_limit, is_timeout_only)` / `decay_tick(delta, ...)` / `decayed(current, initial, time_limit, delta, is_timeout_only)` / `difficulty_weight()`。衰减做成**纯函数**才可单测（「时符 -> 0」「满时限 = 30%」「不会掉成 0」这几条尤其要锁）。
  - `PhaseData` **删掉 `@export bonus`**，并剥掉 `data/stages/**` 里 26 个 phase `.tres` 的手填 `bonus = 100000`（不删会变成"看着像真源"的死数据）。
  - `StageData` 新增 `@export stage_no`（符卡奖励分用的**面序号**）+ `StageCatalog.stage_no_of()`：`stage_id` 是**记录主键**（3B 面为了存档唯一取 4、EX 取 9），而公式要的是 **3 / 7** —— 两者解耦，别拿主键直接算。已填：stage01 = 1、stage03B = 3、stageEX = 7。
  - `boss.gd`：`_bonus_initial = SpellBonus.initial(StageCatalog.stage_no_of(_stage_id), SaveData.selected_difficulty, data.uid != 0)` → `_bonus = _bonus_initial`；每帧 `_bonus = SpellBonus.decayed(_bonus, _bonus_initial, _phase_data.time_limit, delta, _phase_data.is_timeout_only)`（原来的「按时限均摊」口径退役——但**新口径同样是"时限内走完"**，只是终点从 0 改成 30%）。留住 `_bonus_initial` 是因为**下限按初始值算**。
  - 工作台跟进：`phase_shell.gd` 不再复制 bonus、`content_catalog.gd` 的 phase extra 去掉 `bonus` 键（内容不再是真源，目录里留个字段只会误导）。
- **为什么这样改**：R17（数值走集中配置 / 不散落魔术数字）——「一张符卡给多少分」是**规则知识**，应该只有一处、可被测试锁定；内容资源只留"这张卡怎么打"。
- **验证**：新增 `test/test_spell_bonus.gd`（查表：1 面 Easy 50 万 / 1 面 Normal 100 万 / 1 面 Lunatic 200 万 / 3 面 Lunatic 600 万 / 6 面 Hard 900 万 / EX 面 700 万 + 「面序号 ×2 → 分 ×2」锁乘法；权重表 E/N/H/L/EX = 1/2/3/4/2；无面序号 → 0；非符 0；下限 = 30%；**速率 = (初始−30%)/时限**且时限更短速率更快；时符 / 非法时限 → 0；`decay_tick` 极小 delta 至少 1；**逐帧跑满时限 → 30%、全程单调不增且 > 0**）；`test_boss_phase.gd` 换成三条 —— 时限一半 ≈ 初始 65%、走满时限 ≈ 30%、每小时刻都不低于 30%，时符 30 秒一点不掉，非符恒 0；`test_phase_rig` / `test_float_damage` / `test_content_catalog` 去掉 bonus 字段相关断言。

### 2026-09-26 — Boss 计分行加说明前缀 + 倒计时再下移（并修掉前缀带出的两处版面 bug）

- **目标**：① 倒计时再往下挪一点；② `奖励分数：` / `历史：` 加在 BossUI 的 Bonus / Capture 前。
- **改动**：
  - `scenes/ui/boss_ui.tscn`：`TimerLabel` 的 `offset_top` 64 → **84**（名字视觉底 56 之下留 28px）。
  - `scripts/components/announce_label.gd`：新增 `@export bonus_prefix` / `capture_prefix`，两个 setter 变成 `前缀 + 值`；**文案声明在 `announce_label.tscn`**（改措辞不用动代码）。
- **前缀带出的两个版面 bug（都是"实测渲染"才发现的，纯跑断言不会红）**：
  1. **Capture 顶出场地右缘**：落点原是按「名字宽度的固定比例」`CAPTURE_X_RATIO = 0.6`，文本加前缀后变长 → 视觉右缘 = `768 − 0.24W + 0.6·文本宽`，**短名字越界 48px**、长名字也越界 14px。→ 改成**按布局框右缘对齐**（子节点继承父缩放，布局框对齐即视觉对齐）。
  2. **Bonus / Capture 叠在一起**：一个贴名字视觉左缘、一个贴右缘，两串加前缀后加起来 276px > 名字视觉宽 230px → 文字互相压。
     ③ 中途还踩了个自造 bug：把 `_capture_label.position = Vector2(x, h)` 改成只改 x 后**y 丢了**，Capture 跑回名字那一行 —— 也是渲染出来才看见。
  - 最终形态：两串排成**一行**，**整行右对齐到名字视觉右缘（= 场地右缘）**，向左依次排开，串间 `INFO_GAP = 32`（局部单位；屏幕 ×0.6 ≈ 19px）。整行宽度只与两串自身宽度有关，**与名字宽度解耦**，所以长短名字都不越界。
  3. **Bonus 逐帧递减导致整块抽动**（作者追加报）：落点若用**当前**文本宽度，bonus 每掉一位/换个数字，`奖励分数：` 整块就左右抽 —— 本作字体数字**不等宽**（实测 `"1"`=15px、`"8"`=18px，所以同样位数宽度也会变）。
     修法：Bonus 的预留宽度 **`_bonus_reserve` 只增不减**（`maxf` 累积）。递减计数器 ⇒ 见过的最宽即此后最宽 ⇒ 框钉死，数字在原地往左缩。无需任何"最多几位"的魔数。
- **验证**：`test_announce_label.gd` 的文本用例改为断言「前缀 + 值」且前缀非空（措辞留在场景，改词不会让测试白红）；新增两条 —— `test_info_labels_right_aligned_without_overlap`（整行右缘 = 名字视觉右缘、串间恰好 `INFO_GAP`、整行缩放后窄于场地）、`test_bonus_row_does_not_move_while_counting_down`（100000 → 0 全程 `position.x` 不变，且预留框仍保住 `INFO_GAP`）。
- **实测（xvfb 实渲染 + 逐值打印）**：Bonus 屏幕左缘在 `100000 / 99999 / 88888 / 11111 / 9999 / 888 / 1 / 0` 全程恒为 **483.0**（文本宽 266 → 175）；Capture 屏幕 x 662–768（场地右缘 = 768）；倒计时盒 y 84–132（名字视觉底 56）。截图 `.shots/boss_ui_timer_and_info.png`、`.shots/boss_ui_bonus_fixed.png`。

### 2026-09-26 — Boss 阶段倒计时挪到符卡名**下方**（位置改成场景声明）

- **目标**：Boss 弹幕的倒计时（两位秒数）落在符卡名**之下**，别跟名字同高。
- **作者报**：倒计时和符卡名一样高。
- **实测（改动前）**：符卡名（BOSS 大字报）右停位视觉带 **14–56**（布局高 70 × 0.6 缩放），倒计时写死 `position = (size.x/2 − 16, 16)` → 盒 16–63 → **倒计时顶比名字底还高 40px**（`−40`），两者同一行。
- **改动**：
  - `scenes/ui/boss_ui.tscn`：`TimerLabel` 从「代码定位」改为**场景声明**——`anchor_left/right = 0.5` + `offset_left/right = ∓60`（水平居中于场地，不再依赖 `size.x/2 − 16` 这类手算），`offset_top = 64`（= 名字视觉底 56 + 8 间距）。
  - `scripts/scenes/boss_ui.gd`：删掉 `_on_boss_spawned` 里的运行时 `position` 赋值（R17：位置是静态布局，不该是散在代码里的魔术数字），并把关系写进 `@onready` 的注释。
  - `scripts/workbench/workbench.gd`：工作台的仿真倒计时 `FIELD_TOP + 16.0` → `FIELD_TOP + 64.0`，与 BossUI 同值（否则工具显示的布局在骗人）。
- **验证**：`test_boss_ui.gd` 新增 `test_timer_sits_below_spell_name` —— 按 **AnnounceLabel 的 SHRINK 常量**算出名字视觉底，断言 `timer.offset_top > 名字视觉底`（锁**关系**不锁像素：以后觉得 8px 间距太大/太小，改场景一个数不会让测试白红），并复查仍水平居中 + 默认隐藏。
- **实测（改动后）**：倒计时盒 64–112 → **倒计时顶 − 名字底 = +8**；xvfb 实渲染对比图见 `.shots/spell_timer_{before,after}.png`。

### 2026-09-26 — 符卡练习二级列表：超长改为「开窗滚动」（不再膨胀出面板）

- **目标**：符卡练习第二级（阶段列表）内容变多时**只显示放得下的行**，选中项上下移动时窗口跟着滚（1、2、3 → 2、3、4 …）。
- **作者报**：弹幕/符卡一多，二级列表**往面板外长**。
- **根因**：`PhaseBox` 是普通 `VBoxContainer`（整棵子树没有裁剪），`_build_phase_list()` **无条件全量 `add_child`** → 行数超过容器高度就直接画到面板外。
- **改动**（`scripts/scenes/spell_practice_menu.gd`）：
  - 新增 `_rows_visible(vbox)`（可视行数 = 容器实测高度 / 行距；**量不到返回 -1**）+ `_row_pitch(vbox)`（真建一行 Label 量字高，不写死像素）+ `_window_start(current, selected, total, limit)`（窗口起点：越下沿 → `selected - limit + 1`，越上沿 → `selected`，两端 `clampi`）。
  - `_build_phase_list()` 只渲染 `[_phase_offset, _phase_offset + limit)`；`limit <= 0`（未布局）→ 起点 0 = 全渲染（**不藏内容**，也保住「测试直调 `_build_*`」的旧行为）。
  - 新增 `_phase_local_index()`（选中项在窗口内的行号）+ `var _phase_offset`；`_highlight()` 只在**窗口真的要变**时重建，然后按 local index 高亮/闪烁；`_get_highlighted_item()` 同步改用 local index（否则会取错行）。
  - 字号 `28` 提为 `const LIST_FONT_SIZE`（与 `_row_pitch` 同源）。
- **滚动提示（同批）**：场景里加 `PhaseScrollHint`（`PhaseBox` 正上方的独立 Label，锚点 y 0.20–0.262，**不占列表行数**，所以容量算法不用为它让位）；`_sync_phase_scroll_hint()` 显示 `▲ 3–13 / 15 ▼`：
  - `▲` = 上面还有、`▼` = 下面还有，中间是**当前可见区间 / 总数**；全都看得见 → 空串（**不制造噪音**）。
  - 箭头位用**全角空格占位** —— 只有一侧有箭头时字符串长度不变，提示不会左右抖。
  - 挂在 `_build_phase_list()` 末尾 + `_build_lists()` 的空态分支（二级清空则提示清空），所以窗口每滚一次提示自动同步，不额外维护状态。
- **为什么这样写**：与 `player_data_menu` 分页同一条原则 —— **版面容量是布局的结果，不是常量**。这里比那边多一层「窗口跟着选中项滚」，所以起点由选中项与容量共同决定，而不是单纯 `page * per_page`。
- **验证**：`test_spell_practice_menu.gd` 新增三条 —— `test_phase_list_window_follows_selection`（用**实测容量**而非写死数字：渲染行数恒 = 容量、选中项永远在窗口内、首行随滚动进出、末项贴底、回顶复位）、`test_phase_scroll_hint_shows_hidden_ends`（贴顶只有 ▼ / 中间两头都有 / 贴底只有 ▲ / 全装得下为空串 / 二级清空为空串）、`test_rows_visible_is_unknown_without_layout`（未入树 → -1 → 退回全渲染）。
  - 注：测试**不给带锚点的节点硬赋 `size`** —— 引擎会打 "size overridden after _ready()" 警告，GUT 视为 Unexpected Errors 直接判红；改为 `await process_frame` 拿到真实布局容量。
- **实测（headless 逻辑探针 + xvfb 实渲染截图）**：PhaseBox 576px / 行距 52px → **可视 11 行**；15 张卡时贴顶提示 `　 1–11 / 15 ▼`、滚到中间 `▲ 3–13 / 15 ▼`，高亮行跟着走到窗口末行（截图见 `.shots/spell_practice_hint_{top,mid}.png`）。

### 2026-09-26 — 符卡记录分页：每页行数从写死 6 → 按面板实测高度算

- **目标**：符卡记录页（`player_data_menu` 的 RECORD 视图）把面板**填满**再翻页。
- **作者报**：`No.161`~`166` 一页就翻走了，面板下方还空一大截（"符卡名还没填满就转到下一页"）。
- **根因**：`const PER_PAGE := 6` 是**写死的魔数**（R17 反例）。实测该面板可用高度 **560px**、一行含行距 **42px** → 能塞 **13 行**，写死 6 = 白扔一半版面；且它与面板尺寸**没有任何联动**（面板改锚点/改字号后立刻又不对）。
- **改动**（`scripts/scenes/player_data_menu.gd`）：
  - 删 `PER_PAGE`，新增 `_per_page`（运行期实测）+ `_rows_per_page()`：`可用高度 = 面板高 − 样式盒最小尺寸`，`行距 = _row_pitch()`（**真建一行 Label 量字高**，不写死像素），`行数 = floor(可用 / 行距)`。
  - **高度取面板而不是 ListBox**：隐藏时 ListBox 尺寸是 `(0,0)`（PanelContainer 不为隐藏子节点排版），而面板本身已经布局好 —— 首次翻开就能算对。
  - `_total_pages()` 改用 `_per_page`；`_render()` 里加 `_page = clampi(...)` 收敛页码（面板变矮/卡变少时不再出现空白页）。
  - `_make_row` 三个 Label 的 `26` 提为 `const ROW_FONT_SIZE`（与 `_row_pitch` 同源，字号改了行高自动跟上）。
- **为什么这样写**：版面容量是**布局的结果**，不是设计常量 —— 量出来才不会在改锚点/换字体后失配；这也让「面板变高 → 行更多」成为可测的不变量。
- **验证**：`test_player_data_menu.gd` 新增两条 —— `test_rows_per_page_follows_panel_height`（面板加高/变矮 → 行数必须跟着变，锁住"由布局决定"这条性质）、`test_page_fills_measured_capacity`（首页填满实测容量、页数=卡数/容量、末页只剩余数、页码越界收敛不空白）。
- **实测（headless 场景探针）**：每页 **13 行**（旧 6）；24 张卡 → 2 页、首页 13 行；**作者那 10 张（161–170）→ 1 页装完**。

### 2026-09-26 — 阶段身份「槽位数」口径：`phases_normal` 长度 → 各难度列最大长度（EX 面解锁）

- **目标**：让**只配 Extra 档**的 EX 面 Boss 也能解析阶段身份、被 F1 一键解锁、在符卡练习里列出 Extra 槽。
- **作者报**：加了 `data/stages/stageEX/phase/似新存道中一符/符卡161.tres`（阳符「宏辉抑世」）并挂进 `data/stages/stageEX/boss/似新存道中.tres`，按 F1 一键解锁后**符卡练习里看不见**。
- **根因（一条链，两处独立的硬编码）**：
  1. **槽位数硬取 `phases_normal.size()`**（`boss_catalog` 3 处 + `spell_book_manager` 1 处）。EX Boss `phases_normal` 空、只有 `phases_extra` → 规范序 **0 槽** → `resolve_identity` 在 `order[j]` 处**越界返回 null** → `RecordService.record_phase_start(null)` 直接 return → **记录永远写不出来**；`debug_unlock_all_spells` 的 `mini(arr.size(), shape)` = `mini(1, 0)` = 0 → 该 Boss **整体被跳过**（所以 F1 按了等于没按）；`phase_at` 也返 null（三级卡名会显示 `-`）。
  2. **练习菜单难度槽硬编码 `[0,1,2,3]`**（`MENU_DIFFS` + `_configured_diffs` 里同源一份）→ EX 面 `configured` 恒为空 → 四槽全锁 `?`、`_diff_index` 停在 -1 → **看得见也点不动**。（`spell_practice_menu.gd:26` 的注释早已预留 `MENU_DIFFS_EXTRA`，只是没接。）
- **改动**：
  - `BossCatalog.boss_slot_count(b)` = **各难度列的最大长度**（新）；调用点跟进：`phase_canonical_index` / `phase_at` / `boss_index_of_phase` / `debug_unlock_all_spells` 的 `shape`。
  - `BossCatalog.boss_slot_phases` / `_slot_phase` / `_difficulty_lists`（新）：每槽的**代表阶段**（优先规范列 `phases_normal`，该槽为空则依次回落 Easy → Hard → Lunatic → Extra）→ `stage_phase_order` 改用它展开；`resolve_identity` 的符卡/非符计数加 **null 守卫**（代表槽可能为空）；`_phase_offset` 复用 `_difficulty_lists`（去重）。
  - 练习菜单：`MENU_DIFFS_EXTRA = [SpellRecord.Difficulty.EXTRA]` + `_menu_diffs_for(stage)`（**按 stage 分支**：该面没有任何 Easy~Lunatic 阶段才只列 Extra）；`_configured_diffs(boss, diffs)` 改为收参（不再自带硬编码）；二级序号基数从 `bosses[bi].phases_normal` 改用 `boss_slot_phases`。
- **为什么这样改**：「各难度列同形、同槽可换卡」的语义是**槽位对齐**，不是**要求 Normal 非空** —— 形状权威取「各列最大长度」才是这句话的字面意思。本次取代 2026-09-20 那条里「`phases_normal` 是形状权威（长度/槽位）」的口径。
- **既有内容零影响**：现有 5 个 Boss 中 4 个各列等长（`max == phases_normal.size()`）→ 编号/记录一字不变；只有 EX 的 `似新存道中` 走新路径。
- **验证**：新增 3 条回归 —— `test_boss_catalog.test_extra_only_boss_resolves_identity`（extra-only 的槽位数/规范序/身份/反查 + 规范列优先当代表）、`test_spell_book_debug.test_debug_unlock_covers_extra_only_boss`（EX 必须被一键解锁覆盖，且不凭空造 Normal 记录）、`test_spell_practice_menu.test_extra_only_stage_lists_extra_slot`（EX 面只列 Extra 一槽且可选）。
- **实测（headless 场景探针，`user://` 隔离）**：`stage_phase_order(9).size() = 1`；`resolve_identity` → `phase_index=0 / boss_index=0 / uid=161 / phase_number=1`；F1 → 覆盖 stage `[1, 4, 9]`、uid 161 **2 条**（双自机）；练习三级槽 `[{diff:4, is_locked:false}]`、初始 `_diff_index = 0`、卡名行 = **阳符「宏辉抑世」**。
- **验收**：语法 `340 scripts / 0 失败`、命名契约 `0 违规`、GUT **541 tests / 540 pass**。

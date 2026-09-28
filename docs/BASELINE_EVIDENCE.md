# 基线证据与审计（BEST PRACTICES BASELINE 的附录）

> **这份不是"改动前必读"** —— 规则与状态总表在 [`BEST_PRACTICES_BASELINE.md`](BEST_PRACTICES_BASELINE.md)。
> 这里放**支撑那条状态判断的证据**：逐条文件/方法引用、实测数字、当时的拍板旁注。
> 维护：某条状态翻动时，改基线的总表一行 + 在本文件对应小节补/改证据。

---

# STG 品质需求（主轴：做一款好玩的东方弹幕游戏）

> 图例：`[x]` 已落地且有代码证据；`[~]` 部分落地 / 待核；`[ ]` 未做。
> **2026-09 按代码证据重审**（原自评多为未勾）—— 证据为文件 / 方法引用，校准原则：有硬证据才翻。

## S1. 输入与手感（game feel）
状态：✔（事件驱动已收口） ｜ 适用红线：R4, R5, R11
- [x] 自机移动每帧响应、无输入缓冲 Bug（十字方向、斜向速度归一）—— `player.gd`（`move_input.normalized()` + `is_focused` 切速）
- [x] focus/普速切换即时生效，Hitbox 实时显示 —— `player.gd is_focused` + `hit_point_display.gd`
- [x] 蓄力键/炸弹/解放记忆为事件驱动（_unhandled_input），无轮询 —— K3：`Player._unhandled_input` 处理 `memory_release`/`cancel&bomb`；菜单导航 / 暂停键亦统一事件驱动（`NavPage`/`GameManager`）
- [x] 判定不额外延迟：受击/擦弹按帧精确判定 —— `player.gd miss()/graze` 在物理帧

## S2. 自机判定与擦弹（hitbox / graze）
状态：✔（机制闭环） ｜ 适用红线：R1, R2, R10
- [x] 自机判定点极小；**focus 时**淡入显示、松开淡出（`move_toward` 0.15s，`_ready` 时 alpha = 0）——
      `scripts/player/hit_point_display.gd` + `Player.update_hitbox_display()`。
      原文写"始终可见（常显）"，2026-09-27 对过代码后**按实际行为改写**（作者拍板：改这行字，行为不动）。
      （另注：无敌闪烁**只动机体贴图** `AnimatedSprite2D`，判定点/枪口是兄弟节点、不受影响 —— 有断言守着）
- [x] 擦弹半径清晰（focus 时反馈），擦弹次数计入 HUD —— `player.gd graze_radius` + `game_ui.gd`
- [x] 无敌期间的碰撞被正确忽略，死亡清弹（death clear）覆盖全场 —— `is_invincible`（内核 `KernelBulletPhysics`）+ `scripts/bullet/death_clear.gd`
- [x] 碰撞用宽相网格，不做全弹 O(n²) —— 内核 uniform grid；旧 `SpatialHash` 已随旧池删除（W4a-2）

## S3. 自机操控与武器（移动 / Option / 射击 / 炸弹）
状态：✔（2026-09-27：炸弹资源扣除被 `use_bombs` 用例 + 被弹炸弹用例覆盖，原先的 `[~]` 关闭） ｜ 适用红线：R2, R6, R10, R20
- [x] 射击方向/弹型按角色数据（reimu/marisa）驱动，可复用 —— `scripts/data/player_data.gd` + `coroutine/player/reimu_shoot.gd`/`marisa_shoot.gd`
- [x] Option 子机行为独立、可复用 —— `reimu_option_visual.gd`/`marisa_option_visual.gd` + `option_follow.gd`
- [x] 炸弹：无敌时长、清弹、特效、资源扣除符合预期 —— `cancel&bomb` → `_bomb()` → `_fire_bomb()`（含 `bomb_data.invincible_time` 无敌）；
      `BombData` 家族与 mist 清弹形状有 `test_bomb_data` / `test_mist_bomb`；
      **资源扣除**：`use_bomb()` 走 `use_bombs(1)`，并有专门用例（扣 2 / 不足扣光 / 没雷不报错 / 负数当 0）；
      **被弹炸弹**（deathbomb）一次扣 `DEATHBOMB_COST`(2)、只剩 1 个就扣 1（详见 S6 的 miss 语义）
- [x] 武器/行为脚本走注入（ctx），不摸全局 —— `StageContext` + `CoroutineScript`；`grep GameState` **0**（W4b-4）

## S4. 弹幕可读性与公平（readability & fairness）
状态：🚧 ｜ 适用红线：R2, R10, R17
- [x] 弹型/颜色语义一致（敌弹颜色 vs 自机弹），背景/雾不吞弹 —— `BulletData.tint_mode`（MULTIPLY/BLEND）+ `bullet_batch` shader 分模式
- [~] 弹幕有"预告/起手"（telegraph），不存在无解弹幕 —— 出生雾 = 内核逐行 `_fx` 相位（冻结 / 不判定 / 不跑行为）+ `EffectType`（`data/fx/enemy_spawn_fx.tres`）+ `bullet_batch.gdshader`(BLEND)；逐弹型开关 `BulletType.is_spawn_fog`；无解性仍靠人工试玩
- [~] 弹幕密度、速度、命中点可读，玩家能瞬间判断下一步 —— `background/*` + `screen_fog_fx.gd` 已有；需人工调校
- [x] 每颗子弹命中判定精确（hitbox 形状/偏移，测到像素级）—— `BulletData.hitbox_shape/offset/size` + 内核 `hit_geometry.gd`

## S5. 敌人 / 阶段 / Boss / 符卡（phases & spell cards）
状态：✔（机制闭环） ｜ 适用红线：R2, R17, R18, R20
- [x] 敌人/Boss 由 Data 驱动（EnemyData/BossData/PhaseData），可复现 —— `scripts/data/{enemy_data,boss_data,phase_data}.gd` + `boss_catalog.gd`
- [x] 阶段时序（入场→非符→符卡）、HP 增长、超时判定明确 —— `boss.gd _enter_phase/_clear_phase` + `is_timeout_only`
- [x] 符卡可读：显示卡名、开奖（收/不收）规则一致 —— `scripts/scenes/boss_ui.gd` + `spell_record_book.gd`
- [x] 阶段脚本（move / shoot / timeline）走 CoroutineScript + 注入，不摸全局 —— `stage_director.gd` + `StageContext` + `timeline/*`

## S6. 资源经济（Power / lives / bombs / score / graze / memory）
状态：✔（**2026-09-27 复核 + 补齐**：奖励分来源早已落地；当日接上 miss 火力惩罚 + 补 P 点扇形） ｜ 适用红线：R8, R9, R18
- [x] 掉落→收集→加成链路清晰（power/point/life/bomb 碎片集满合成）—— `enemy.gd _drop_item` + `scripts/item/{item,item_pool}.gd` + `PlayerResources`
- [x] **分数来源全部可追溯，无黑箱**（2026-09-27 把每一条都追到调用点）：
      **击破** `enemy.gd:104 GameEvents.enemy_killed` → `player.gd:69 _on_enemy_killed` → `add_score(score_value)`；
      **奖励分** `SpellBonus`（难度权重 × 面序号 × 50 万 → 时限内线性衰减到 30%；**miss / 用 bomb 则整张作废**）→ `boss.gd:372 add_score(_bonus)`；
      **最大点 / 捡点** `item.gd:125` → `PlayerResources.add_max_point()`（`max_point` 恒 +10，入账当前值；深位递减）；
      **擦弹** `kernel_bullet_physics.gd:178 on_graze()` → `graze_count += 1` + `add_score(10)` + `add_memory(MEMORY_GRAZE)`；
      **记忆** —— 修正旧措辞：它不是**分数**来源，而是**资源**（0–100）：擦弹 +0.25、miss +25、每秒自然回复，`memory_release`（`player.gd:242`）消耗它强收道具，并决定 Stage 3A / 3B 路线。
- [x] **miss 语义完整**（2026-09-27 接上缺口 + 当日再补被弹炸弹 + 2026-09-28 补雷补偿）：`miss()` = 先判**被弹炸弹窗口** → 否则 `_apply_miss()`。
      `_apply_miss()` = 清弹 + 记忆 +25 + **火力 −50**（`on_miss_power_penalty()`，clamp 0..300）+ **直接 +2 个雷**（`MISS_BOMB_GAIN` → `PlayerResources.add_bombs()`：不撒掉落物、**雷碎片不动**、到 `MAX_BOMBS` 封顶）+ **撒 10 个 P 点扇形** + 扣残机 + **自机复位两步** + 3 秒无敌。
      （被弹炸弹窗口在 `miss()` 里**先**判定 ⇒ 这 2 个雷抢不了这一次命；窗口里抵消掉的那次不算 miss，不发补偿。）
      **被弹炸弹（deathbomb）窗口**：有雷（≥ `DEATHBOMB_MIN_BOMBS`）且机体配了 `BombData` 时，被弹瞬间 `Engine.time_scale = 0` **全局定格** `DEATHBOMB_FRAMES`(12) 帧 ≈ 0.2s
      （**保存/恢复倍率**，与 Boss 全破定格同一套；出树有安全阀，切场景/测试回收都不会把 `time_scale` 留在 0）。
      **收尾走真实时间计时器**（`create_timer(…, process_always=true, ignore_time_scale=true)`）—— 定格中 delta=0、玩家按暂停时 `tree.paused` 也照样到点。
      **踩过的坑（作者实测）**：早先按物理帧倒计时收尾，窗口内按暂停会把收尾一起冻住 → `time_scale` 永远回不到 1 → **暂停菜单出不来也解不开**；改成真实时间计时器后实测 `state 1→2→1 / tree.paused true→false / time_scale 全程 1.00`。
      窗口期还有**框内整体渐显红滤镜**：`GameEvents.deathbomb_started/ended` → `FieldFilterLayer`（`deathbomb_color` / `deathbomb_fade_in` 皆为 @export），
      tween 走 `set_ignore_time_scale(true)` + `TWEEN_PAUSE_PROCESS` —— 否则定格里一步都不动（探针实测：帧 1→12 时 `alpha 0.01→1.00`，全程 `time_scale=0.00`）。
      窗口里按 `cancel&bomb` → `_cancel_miss_by_deathbomb()`：花 `DEATHBOMB_COST`(2) 个雷（**只剩 1 个就扣 1**）并照常放炸弹 `_fire_bomb()` —— **不掉命 / 不削火力 / 不出扇形 / 不复活**；
      不按 → 窗口到点才走 `_apply_miss()`。定格期间的第二发命中被忽略（`miss()` 见窗口即 return）。
      **无敌时长**（2026-09-27 改成链接）：`MISS_INVINCIBLE_TIME`(3.0s)，但**残机归零**时 = `miss_invincible_time(true)` =
      `max(3.0, GameConfig.DEATH_MENU_DELAY + MISS_DEATH_INVINCIBLE_MARGIN(1.0))` —— 菜单延迟一调大，无敌自动跟上（有契约断言守着）。
      无敌期间**机体贴图闪烁**（`INVINCIBLE_BLINK_HZ` 6Hz，暗半周期 alpha 0.2），只动 `animation.modulate.a`。
      **复位两步**（放在 `_apply_miss` **最后**）：① **瞬移**到 `MISS_RESPAWN_FROM = (FIELD_CENTER_X, FIELD_BOTTOM + 96)` = `(448, 1024)` —— 框下方之外、水平正中（船从框下升进场）；
      ② tween（`MISS_RESPAWN_TIME`，**作者现调 1.0s**）移动到 **`_respawn_pos`**（**终点**；默认 `MISS_RESPAWN_POS = (FIELD_CENTER_X, FIELD_BOTTOM − 120)`），期间锁移动输入（`_is_respawning`）。
      探针实测（0.45s / 840 的旧参数下）：`t=0.05s (448, 1024)` 框下 → `t=0.25s (448, 850)` 已进框 → `t=0.60s` 复位点；现值由 `test_player` 的复位用例守着。
      **为什么必须最后**：反色圈 / 清弹 / 扇形全用开头的 `pos`（中弹那一刻的位置），移动自机只能最后做，否则圈会画到移动后的位置。
      扇形 = `ItemService.spawn_fan(POWER, 自机, targets, 0.45s)`，目标点由 `ItemService.fan_targets()` 算：**绕自机、向上 180°、均匀 20° 一档、含两端点**，
      并把横坐标**夹进场内** `[FIELD_LEFT+16, FIELD_RIGHT−16]`（留白 = 半张 32×32 贴图）→ **左右不出框**（贴墙时靠墙一侧压扁成竖列，纵向弧高不变）。
      **两段式**：① 沿弧向直线飞到目标点（`MISS_POWER_HANG` 0.45s，半径 `MISS_POWER_RADIUS` 240px）→ ② `Item.burst()` 在宽限结束那刻**把径向初速归零** → 只受重力 = **竖直下落**（横向不再飘）。
      道具侧 0.45s **爆发宽限**内：不落重力 / 不吸附 / `area_entered` 也不收 —— 否则在自机处生成的点当帧就被吸走，弧形根本看不见。
      **实测**（xvfb 探针，非仅靠断言）：中央时目标 x = `208…688`（= 448 ± 240，完整半圆）；贴左墙（自机 x=72）目标 x = `80×5, 114, 192, 256, 298, 312`；
      **两种位置、两个时刻（0.30s / 0.95s）出框数都是 0**；且 0.55s→0.95s 的 **x 逐一相同、只有 y 在掉** → 「竖直下落」成立。
      **契约**：`MISS_POWER_RADIUS` > `Item.PROXIMITY_RANGE`(128)（否则第二段不可见）· 夹取边界在框内（`test_player` 两条断言守着）。
- [x] 残机/炸弹上限、碎片合成规则集中在单一 owner（不用全局散改）—— `PlayerResources`（W4b-1 抽出，`Player` 持有）
- [x] 各资源只通过显式入口修改（封装，防作弊/防割裂）—— `PlayerResources` 显式入口 + `changed` 信号

## S7. 难度曲线（Easy → Lunatic）
状态：🚧 ｜ 适用红线：R17, R8
- [x] 每难度数值走 diff_pick / Resource，不散落 if 判断 —— `diff_pick`（多文件）+ `boss_data.phases_for_difficulty`
- [~] 曲线平滑无"断崖"；高难增加的是密度/速度/预判压力，而非不可读 —— 需人工试玩调校
- [~] 难度切换可复现（同一 seed 同难度结果一致）—— `RNG` 种子 + 难度分表已在；端到端验证待补

## S8. 反馈与演出（feedback / fx / sound / fog）
状态：✔（机制闭环） ｜ 适用红线：R2, R7, R20
- [x] 受击/消除/擦弹/Boss 阶段有即时视觉+音效反馈 —— `scripts/effect/*` + `AudioManager`
      **符卡结算**再补一块演出：`Boss.clear_phase` → `GameEvents.spell_result` → `PhaseResultBanner`
      （场地上部渐显 → 停 → 渐隐，**时长与阶段边界无关** —— 下一张开卡不会掐它）：干净收取 = 「Get Spell Card Bonus」+ 奖励分；
      失败（超时 / miss·bomb 作废）= 「Bonus Failed」且**不显示分数**（那分没入账）；两种都带一行**击破时间**。
      文案 / 配色 / 落点声明在 `scenes/ui/phase_result_banner.tscn`，改措辞不用动代码；
      落点夹在「倒计时之下、报幕大字最大态之上」（`test_phase_result_banner` 锁关系）。
- [x] 弹雾/背景与弹幕对比度足够，不吞弹、不刺眼 —— `screen_fog_fx.gd` + `bullet_batch.gdshader`(BLEND 特效应) + `background/*` + `decor_manager.gd`
- [x] 特效走服务/对象池（hit_effect / miss_effect），不再频繁 instantiate —— `FxPool`（精灵特效池，世界坐标/节点池）+ `MissCircleLayer`（全屏反色圈，屏幕空间 shader）；均组合根注入，非 autoload
- [x] 发弹雾 / 消弹消散**共用一套特效模型**（`EffectType` + 逐行 `fx_type` + 纯特效行）—— 消弹把被清弹原地换成一条纯特效行（`KernelNativeSystem.spawn_fx`），雾中的弹同样可消（直接切成消散）；渲染桥按行分流、`BulletMultiMesh` 用同一 `bullet_batch.gdshader` 批量画 —— `data/fx/*.tres`，不再逐弹 `EnemyBulletClear` 节点 + tween
- [x] 演出（入场/放 logo/BGM/对话）用 Timeline，可复现、可暂停 —— `coroutine/timeline/*` + `dialogue_runner.gd`

## S9. 性能（几千发子弹下的帧率余量）
状态：🚧 ｜ 适用红线：R10, R19
- [x] 子弹用内核 SoA 池 + MultiMesh，规避每弹节点开销 —— **原生 `DanmakuStore`（唯一存储）+ `KernelNativeSystem` 只读快照 + `bullet_multi_mesh.gd`**；旧 `BulletPool`/`Bullet` 节点/`SpatialHash` 已删（W4a-2）；GDScript `BulletSystem` 已从生产删除（L3.5-4f，冻结参照在 `test/reference/`）
- [~] 无每帧临时分配（贪心 alloc）；热路径避免 get_node("...") —— MultiMesh 同步每帧做分组/拼 key（旧代码自注有分配）；字符串 `get_node`/`get_node_or_null` 调用点 **29 处**（生产 14 / 测试 15；A3 更正）
- [x] 碰撞/移动每帧 walk 用数组索引（内核 SoA），不频繁排序
- [~] 大量对象时帧率稳定（目标：满载 60fps 有冗余）—— `test/perf_stress/*` 有压测场景，需实机确认

## S10. 可复现与回放（determinism / replay）
状态：🚧 ｜ 适用红线：R10, R13, R17
- [~] 唯一 RNG 走 RNG（种子可设），不用 randf()/randi() 全局 —— `RNG.*` **25 处**；gameplay 裸全局 **0**，仅 workbench 3 处 `randi()`（调试随机种子）
- [x] 帧/时间步用固定物理过程（_physics_process）+ 世界时钟，与帧率无关 —— `_physics_process` + `ReplayRecorder` 明确铁律
- [~] 回放记录输入序列可重放，且结果与首次一致 —— `replay_recorder.gd` 已有录制（输入位掩码 + seed），**播放器"后续接入"**
- [~] 工作台"固定种子/快进/续跑"功能以此为基础 —— `workbench/bullet_bench.gd _seed/_speed_spin` 已有，续跑待核

## S11. 场景流程与演出（stage flow / bgm / dialogue）
状态：✔（结构闭环） ｜ 适用红线：R1, R20, R21
- [x] 关卡流程（Main→World→GUI）结构化，入口点清晰 —— `scenes/ui/main_menu.tscn`（main_scene）+ `game_scene.gd` + `StageRuntime`
- [x] 换关时 World 子级可替换；GUI 不随关消失（独立存活）—— `StageRuntime`
- [x] 背景/环境独立子场景，可复用；BGM 语义 key 管理 —— `data/stages/stage01/background/*` + `music_registry.tres`
- [x] 对话/剧情由 DSL/步骤驱动，可复现、可暂停、不耦合 UI 细节 —— `dialogue_line/dialogue_step/dialogue_runner/dialogue_steps.gd`

## S12. 玩家体验与可访问（UX / menus / practice）
状态：✔（体系完整） ｜ 适用红线：R4, R6, R7, R20
- [x] 菜单统一继承（NavPage/BasePage），推/跳转/退场动画一致 —— `scripts/scenes/nav_page.gd`（extends `BasePage`）+ 各页
- [x] 暂停、重开、符卡/关卡练习、回放、手册、玩家数据等可达 —— `pause_menu/spell_practice_menu/stage_practice_menu/replay_menu/manual_menu/player_data_menu.gd`
- [x] 菜单只发信号、由上层决定状态与场景，UI 不直接写全局 —— `BasePage` 信号 + `SaveData`（纯 static）；`grep GameState` **0**
- [~] 页面可独立运行（F6），用 @export/% 引用，不硬编码节点名 —— 需逐页 F6 核验

## S13. 素材与图集（atlas / 贴图规格）
状态：✘（未用图集） ｜ 适用红线：R12, R17
- [x] 弹幕贴图统一进图集（一图一 MultiMesh）；布局数据走 Resource（R17）（2026-09-20 完成）—— 全部弹型贴图进 1024² 图集（`data/atlas/bullet_shapes.tres` 44 格）；弹型数据化 `data/bullets/*.tres`（内容资源 = `BulletDef`：外观+碰撞+朝向；运行时 `BulletType` 由构造链建；`bullet_configs` 退役）；`test_atlas_layout` 哨兵 + 像素核对（敌弹/灵梦系逐字节相等，marisa 系 maxdiff≤2，`魔理沙bomb` 仅低 alpha 边缘噪声）；**例外** `laser`（按拍板留独立 PNG → `AssetRegistry.LASER_TEXTURE`）
- [ ] 格间留 ≥1px 余量（gutter）—— 未用图集，不适用
- [ ] 拆图集阈值（单图 > 1024² 或形状数 > 80 → 拆）—— 未用图集，不适用
- [x] 弹型朝向：`follow_dir` / `dir_offset` 语义统一（2026-09-19）—— 三处公式（GDScript `BulletType.rotation_for` / 原生 `_hit_rot` / 渲染桥）逐字等价；死字段 `BulletData.hitbox_rotation` 已删；两字段经 `bullet_configs` + 实例直赋打通到内核弹型（`test_bullet_orientation` / `test_native_collision` 锁定）

---

# 决策旁注与实测审计（历史快照，只增不改）

> 基线正文只留规则；这些"当时为什么这么定 / 实测多少"的旁注放这里，避免正文持续膨胀。

## 待改进 · 长版（含行数/实测数字/决策经过；基线正文只留短清单）
> 这里是"当前版本"尚未达标的项（工程红线与 STG 需求均可能命中）。每修一条删一条，最终清空。
- [ ] R16：47MB 二进制未配 Git LFS（`.gitattributes` 仅 EOL 规范化）
- [ ] R18/R19：`workbench.gd`(692) / `spell_practice_menu.gd`(592) 上帝对象 + 3 个超长 `_build_ui`（三台热更新复制已收口，K5）
- [ ] R21：`workbench` 11 处 `.new()` + 15 处 `add_child`（开发工具，可后）
- [ ] R2（残余）：`item_service.gd:16` / `player.gd:286` 用 `current_scene.get_node_or_null("World")` 取 World，可改注入
- [ ] 编排路线（`docs/archive/STAGE_FLOW_PLAN.md`）：Step 2 书签原生（工作台仍正则扫源码）/ Step 6 `ctx.background` 注入服务 待做；Step 5 命令化时间线 + Step 7 命令编辑器 = 可选 / 产品决定，暂缓
- [ ] **内核融合（M3，见 `docs/archive/NEW_KERNEL_REFACTOR_PLAN.md` §16）**：M1（`damage`/`hit_sfx` 进弹型）+ **M2（词汇合一）已完成**；**M3（渲染/纹理归属）已拍板 ③ 纹理句柄** —— `_texture_by_index` 是**保留的渲染插座**（非债），由 N4 原生替换；余 `scripts/kernel_bridge/` **924 行**（适配器 236 + 宿主耦合 688；**行数不是目标**）+ `_port_by_sig` + 6 个 `kernel_port`（VM 前身）→ 判据改为**结构性**（0 类型映射 / 0 内容签名侧表），见 §16.5；**2026-09-13 决策：扩展为必需** —— GDScript 内核降为过渡，N2 存储段 + N3 后删除（见 `docs/archive/N2_NATIVE_INTEGRATION_PLAN.md` 终局决策）。**2026-09-14 已完成（L3.5-4e/4f）**：原生 `DanmakuStore` 成**唯一存储**；`scripts/kernel/**` 已从**生产删除**，冻结参照（oracle）移入 `test/reference/`；`KernelNativeSystem` 为 standalone 桥接类（`kernel_bridge/` 宿主耦合保留）

> **S1–S13 重审（2026-09-11，K0 完成）**：S / 红线状态已按代码实测刷新。
> - **R14（2026-09-13 A1 更正）**：`save_manager.gd` 走 `user://save_data.cfg`；但**内容侧**符卡簿 / 音乐解锁曾直接 `ResourceSaver.save` 到 `res://`（4 处，导出包只读必失败）→ 已迁「res:// 出厂默认 + user:// 覆盖」，并加 `test_persistence_paths` 守卫。
> - **R15 命名**：`scripts/**` 中文 `.gd` **0**；PascalCase 目录段已立豁免、**文件层 + 节点层已清**；`stage03B` 大写按拍板保留。
> - **过时引用清理**：`bullet_physics.gd`/`bullet.gd`/`bullet_fog.gd`/`SpatialHash` 均已随 W4a-2 删除，S 小节证据已改指内核 / `ScreenFogFX`。

## 外壳工程红线审计（2026-09-11，K0 实测）

| 红线 | 实测 | 判断 |
|---|---|---|
| R9 autoload | **4 个**（W1 12→10，W2 10→8，W3a 8→7，W3b 7→6，W4b 6→5，W4c 5→4） | `GameEvents / GameManager / RNG / AudioManager`；已达目标 |
| R18/R19 单一职责/DRY | 三台热更新管线 **基类 1 份 + 3 组 hook**（K5，净 -116 行）；`workbench.gd` 692 / `spell_practice_menu.gd` 592 行 | 余上帝对象 + 3 个超长 `_build_ui` |
| R21 声明式建树 | `game_scene` 服务节点全部 tscn 声明（K6：`BulletManager` 收尾）；余 `workbench.gd` 11 处 `.new()` + 15 处 `add_child` | `game_scene` ✅；workbench 开发工具，可后 |
| R6 私有调用 | **0**（K2：`has_method("_")` 12→0、生产对外私有调用 6 组→0） | ✅ 公开虚函数 + 类型化接口 |
| R4 输入 | 边沿轮询 **0**（K3）；`Input.is_action` 仅连续状态（移动/focus/shoot/回放/对话长按） | ✅ 符合「状态读取例外」 |
| R2 引用 | `find_child` **0**、`get_node("..")`/`$".."` **0**（K4）；`MenuNav` 容器改注入（K11）；余 `current_scene` 取 World 2 处 | 基本达标，余 2 处可注入 |
| R5 字符串 get_node | **29 个调用点**（生产 14 / 测试 15，含 `get_node_or_null`；A3 更正：原「19」是生产侧文本出现数、漏了测试） | 非全树搜，接受 |
| 层序契约 | 26 处设 `z_index`，**20 处走 `LayerConfig`**，裸数字 5 | 接近达标，余 5 处可收 |
| 帧序契约 | 无显式 `FrameOrder`；内核走 `process_physics_priority`（-10/-5/-4/0） | 仍可引入 `FrameOrder` |
| R14/R15 | res:// 运行期写档 **0**（A1：符卡簿 / 音乐解锁改 user:// 覆盖，`test_persistence_paths` 守卫）；中文 `.gd` 文件名 **0**；PascalCase 目录已立豁免、文件层 + 节点层已清 | ✅ |
| R16 | assets **47MB**（最大 11.2MB 字体），无 LFS | 待配 LFS |
| R3 | `@tool` **11**、`_get_configuration_warnings` **2**（NavPage/GameOverMenu，覆盖 7 个菜单页的场景期 `container_path`） | ✅ |
| R12 | `@export=preload` **0** | ✅ |
| R10/R13/R17/R20/R22 | 内核 SoA / `_physics_process` / 数据资源 / 独立子场景 / `##` 注释 | 无系统性违规 |

> **轨道 B（外壳红线对齐）已完成**：autoload **12 → 4**（`GameEvents / GameManager / RNG / AudioManager`）；`grep GameState` **0**；R6 / R4 / R2 收口见上表。逐波记录（W1–W4c / K1–K14）见 **[BEST_PRACTICES_LOG.md](BEST_PRACTICES_LOG.md)**、方案与决策见 `docs/archive/NEW_KERNEL_REFACTOR_PLAN.md`。

## 契约类旁注（从基线正文搬出）

> 原项目现状：无显式 `FrameOrder`，顺序依赖 autoload 的 `_physics_process`（见轨道 B / B5）。
> 原项目现状（K0 实测）：26 处设 `z_index`，其中 **20 处已走 `LayerConfig.*`**，仅 5 处裸数字（`status_toast`/`hitbox_overlay`/`bench_base`/`dialogue_box`·`game_ui` 的相对层）。
> 原项目现状（2026-09-18 复核）：`scripts/**` 中文 `.gd` 文件名 **0**（内容槽中文属合规）。**PascalCase 目录段**已立**明确豁免**；**文件层已清**（`FalseFront`/`TrueFront`/font/`*_YY_jade` → snake）；**节点层已清**（`diffculty`/`front`/`debug`/`jude`/`bar`/`content`/`root` → PascalCase）。`stage03B` 大写按拍板**保留**。
- 命名契约存量清理：状态字段已收敛（`refs`→`entity_registry`、`world`/`bullets`→`bullet_manager`）；局部极短名已清（`sd`→`stage_data`、`st`→`stage`/`behavior_state`、`bm`→`bullet_manager`/`bookmarks`、`bg`→`background`/`stage_background`、`tl`→`timeline`）；工作台自身本地名按决定不动。`tl` 改名连带 `bookmark_extractor` 正则 → `timeline\.at(`。

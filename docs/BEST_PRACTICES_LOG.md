# Godot 最佳实践日志（BEST PRACTICES LOG）

> 本文件是**滚动日志**：记录"为什么这样改 / 当时学到什么 / 踩过的坑"。
> - **反复踩的坑 / 铁律** → 已蒸馏进 `BEST_PRACTICES_BASELINE.md`（改动前必读）；本文件只留**近期**条目。
> - **历史条目** → 归档在 `docs/archive/`（可检索，不作日常阅读）。

---

## 模板（每条可复制）

### YYYY-MM-DD — 子系统名 / 改动名
- **目标**：一句话说明要改什么。
- **为什么**：为什么这样改才算符合最佳实践（对应哪篇文档哪一条）。
- **对照旧项目**：旧版 file.gd:line 哪里不好，我这次刻意没抄什么。
- **新落点**：新文件:行号。
- **验收**：./tools/verify.sh / 对应 GUT 测试结果。

---

## 记录

### 2026-09-19 — 符卡名底衬（AnnounceLabel 可选背景）：同一套 transform，缩回正常后再渐显

- **需求**：符卡名背后加底衬；底衬从名字的大小缩放至正常，**路径与名字一致**（同缩放 / 同轨迹），右缘贴边，之后再渐显。
- **做法（`scripts/components/announce_label.gd`）**：`play(text, parent_size, background := null)` 加可选底衬。底衬 = `TextureRect` **子节点**（`show_behind_parent = true`）—— 随父节点的 position/scale/pivot 一起动，**路径与右缘天然一致**，不用复制一套 tween。贴图**按原始纵横比等比**缩放到名字宽（不拉伸）、右缘对齐、垂直居中。`modulate.a` 初始 0，在 `HOLD` 之后与第一段滑出并行渐显（`BG_FADE = 0.35s`）。
- **接线（`scripts/scenes/boss_ui.gd`）**：`ENEMY_SPELL_NAME_BG = preload(.../enemy_spell_name_background.png)`；玩家符卡（Bomb 名）以后用 `player_spell_name_background.png`（本次只入库，未接线）。
- **素材**：`assets/Textures/ascii/{enemy,player}_spell_name_background.png`（各 400×63 RGBA；敌方红 / 玩家青）。
- **测试**：`test/test_announce_label.gd` +2（夹具 `PlaceholderTexture2D` 400×63）：有底衬 → 挂 `Background` 子节点 + `show_behind_parent` + **等比（不拉伸）** + 右缘贴名字框右缘 + 初始 alpha 0；无底衬 → 不挂。
- **验收**：`./tools/verify.sh` 全绿（**467 / 466 pass + 1 pending，4621 asserts**）。
- **⚠ 待人工验收**：实机看底衬渐显时机 / 等比宽度；不合适先调 `BG_FADE` 或换底衬贴图。

### 2026-09-19 — 修符卡名右缘越界（AnnounceLabel 绕中心 pivot 缩放）

- **现象**：符卡名「音符「定点扩散」」右侧被齐刷刷切掉，收取数只露 `00`。
- **根因**：`AnnounceLabel.play()` 的滑出目标是 `parent_size - size*SHRINK`，但 `SHRINK` 是**绕中心 pivot 缩放**——视觉盒右缘 = 布局框 x + `size.x*(1+SHRINK)/2`，比场地右缘多出名字宽度的 20%（8 个全角字 = 77px）。越界部分被上层不透明 HUD 相框 `assets/Textures/front/false_front.png`（`GameUI` layer 32 的 `Front`，场地内 alpha=0 / HUD 区 alpha=255）盖住 → 看起来像"字被切"。
- **做法**：加 `const VISUAL_HALF := (1.0+SHRINK)/2.0` 与纯函数 `AnnounceLabel.rest_x(parent_w, label_w) = parent_w - label_w*VISUAL_HALF`（让**视觉右缘**贴父容器右缘）；两个滑出目标（右下 → 右上）都改用它，y 同理用 `VISUAL_HALF`。
- **测试**：新增 `test/test_announce_label.gd`（夹具 384×70 / 192×70，不碰真实内容）：视觉右缘贴边、短名不越左、名字越长落点越左。复现探针（真实 `game_scene.tscn` + `false_front`）：`stop=(460.8,0)`、`visual_right=768.0`，名字完整显示到相框边。
- **验收**：`./tools/verify.sh` 全绿（**465 / 464 pass + 1 pending，4614 asserts**）。
- **⚠ 待人工验收**：进游戏打关底符卡，确认名字完整贴住场地右缘、收取数不再被切。

### 2026-09-19 — Timeline.sequence_phases：Boss 阶段按序连打

- **要解决的问题**：`wait` 的一次性 `phase_cleared` 会**同时武装所有** wait 事件，表达不了「P0 打完 → gap → P1 → 打完 → P2」；`stage01.gd` 因此只能打 `phases[0]`。
- **做法**：`Timeline` 加 `sequence_phases(getter, phases, gap)`（排时间点）与 `start_sequence_now(...)`（事件驱动立即起）：
  - 起 `phases[0]`；每次 `phase_cleared`，非最后一张 → `next_at = _elapsed + gap`（`tick` 到点进下一张），最后一张 → 记 `_cursor` + 武装 wait；
  - 空表 → 视作「已打完」，立即武装 wait（避免后续 wait 永不触发）；
  - `start_phase` 抽出 `_arm_waits()`；`reset()` 清序列。
- **接线**：`stage01.gd` 道中 Boss → `sequence_phases(..., phases_for_difficulty(selected), 1.0)`；最终 Boss 在对话 `boss_fight` → `start_sequence_now(...)`（替代只打 `phase(0)`）。不再需要 `SPELL01` const。
- **测试**：`test_timeline_sequence.gd`（合成假 Boss）：按序 + gap、**只有最后一张击破后才武装 wait**、空表立即武装。
- **验收**：verify 全绿（462 / 461 pass + 1 pending，4609 asserts）。

### 2026-09-19 — 练习菜单：无可用难度时不落在锁定项（(II) 严格语义收口）

- **确认语义（(II)）**：每个难度必须自己配阶段（`phases_for_difficulty` 不回退）；未配置的难度在菜单里显示为锁定 `?`，不可练。
- **修 UX**：四个难度槽全锁时（无记录 或 无阶段），`_build_diff_list` 原来把 `_diff_index` 留在 0（Easy 锁定项），按 Z 会在锁定项上警告。改为全锁时 `_diff_index = -1`；`_start_practice` 守卫改成 `_diff_index < 0` → 明确警告「没有任何可用难度」且不开始。
- **测试**：`test_spell_practice_menu` 加「全锁 → `_diff_index = -1`、按 Z 不开始 / 不改选择」。
- **内容提醒**：当前只有 `phases_normal` 有阶段 → 只能练 Normal。要练 Easy/Hard/Lunatic 得在 Boss `.tres` 的 `phases_easy/hard/lunatic` 里填阶段。
- **验收**：verify 全绿（459 / 458 pass + 1 pending，4596 asserts）。

### 2026-09-19 — 练习菜单难度槽解耦：MENU_DIFFS 常量（恢复 4 槽）

- **问题**：`phases → phases_normal` 去回退后，练习菜单的 Easy/Hard/Lunatic 槽消失了 —— 因为 `_candidate_diffs` 拿 `phases_for_difficulty(diff)` 非空来**筛槽位**，旧回退只是掩盖了这层耦合。
- **做法**：菜单难度槽与「该难度有没有阶段」解耦：
  - `const MENU_DIFFS: Array[int] = [0, 1, 2, 3]`（普通面标准集合；未来 EX 面只有 Extra → 按 stage 分支 `[4]`）；
  - 锁定判据 = `无记录 OR 该难度无阶段`（不会出现「解锁了却打不开」）；
  - `_candidate_diffs` 更名 `_configured_diffs`，只服务「全收变蓝」：全部**已配置**难度收齐才算。
- **测试**：`test_spell_practice_menu` 原「只定义 Normal → 1 槽」改为「固定 4 槽，其余因无阶段锁定」。
- **验收**：verify 全绿（458 / 457 pass + 1 pending，4590 asserts）。

### 2026-09-19 — BossData 难度阶段去回退：phases → phases_normal

- **需求**：`phases` 不再充当各难度的默认回退；改名 `phases_normal`。
- **做法**：`BossData.phases` → `phases_normal`（builder `phase()` → `normal_phase()`）；`phases_for_difficulty(diff)` 各难度**直接返回自己的数组**（空即空），只有 `_`（Normal/未知）返回 `phases_normal`。调用点跟进：`BossCatalog`（规范序/归属/收集）、`boss_handle.phase(index)`、`stage_runtime.start_spell_card`、`stage01.gd` 时间线、两个 Boss `.tres` 的 `phases_normal`。
- **测试**：`test_boss_phase` 的「空回落 Normal」反转为「空即空」；`test_spell_practice_menu` 原本断「4 个难度槽」编码的正是旧回退 → 菜单加**可注入 boss**（`info["boss"]`，同 `catalog_root` 思路），5 条改用例改用**合成 Boss**（定义 4 难度 / 只定义 Normal），不再绑真实内容。
- **行为影响（重要）**：现在只有 `phases_normal` 有内容 → **Easy/Hard/Lunatic 的练习菜单只列 Normal、BossUI 难度点数为 0**（实战仍走 `phases_normal`）。要给某难度出卡就往 `phases_<diff>` 填。
- **验收**：verify 全绿（458 / 457 pass + 1 pending，4587 asserts）。

### 2026-09-19 — BossCatalog 名册数据化（A）：BossData/.tres + BossRegistry

- **问题**：`BossCatalog.all()` 是手写 GDScript 名册（每阶段一个 `const preload` + 一句 `.phase()`），符卡多了会堆成 80+ const + 一大坨嵌套构造；而 `BossData` 本就是 `@export` Resource。
- **做法**（与 `StageCatalog` 同构）：
  - `BossData` 加 `@export stage_id` / `order`（boss_index = 同面 order 升序）；
  - 每个 Boss 落 `data/stages/<stage>/boss/*.tres`；新 `BossRegistry`（`@export bosses: Array[BossData]`）+ `data/registry/boss_registry.tres`；
  - `BossCatalog.all()` 读注册表（空则扫 `data/stages/**/boss/*.tres`），按 stage_id 分组、order 排序、缓存；删掉 `KAMORUI/NON_MID01/NON01` 三个 const。
  → **加符卡 = 加 `PhaseData.tres` + 在 Boss 的 `.tres` 里 add 一项，零 GDScript**。
- **测试解耦**：`test_boss_catalog` 去掉「阶段数 = 2 / 具体卡名」，改成名册**自洽**断言（规范序 = phases 扁平拼接、phase_at 与规范序一致、boss_index 在范围）。
- **坑**：一次性 `godot -s` 生成器会把 `.godot/global_script_class_cache.cfg` 写坏（连带后续 GUT 报 `game_events.gd` 编译失败）→ `--import` 重建即恢复；生成 `.tres` 时 BossData 必须**先存后 load**，注册表才会「引用」而不是「内联」。
- **未做（另开）**：`Timeline.wait` 的多阶段连打语义不成立（一次 `phase_cleared` 会同时武装所有 wait 事件）——`stage01.gd` 时间线仍只打 `phases[0]`，多符卡编排需要 Timeline 自己的 `sequence_phases`。
- **验收**：verify 全绿（457 / 456 pass + 1 pending，4583 asserts）。

### 2026-09-19 — 修「清空数据」崩溃 + workbench 测试去内容耦合

- **bug**：`option_menu._refresh_values()` 先读 `item["def"]` 再判类型；动作项「清空数据」没有 `def` → 一进设置菜单就报错。改为 action 先分支（动作项无设置值）。
- **测试解耦**：`CatalogPanel` 内部写死 `CAT.new().scan()`，而 `test_catalog_panel` / `test_content_catalog` 拿**真实内容**断数量（`阶段（7）`）→ 加一张符卡就红。给面板加**可注入** `catalog_root`（默认 `res://data`）；两个测试全部改用**夹具目录**，真实内容只留「不数数量、不写具体路径」的结构冒烟。
- **验收**：用户未入库的新符卡 `spell002.tres` 在场时 verify 仍全绿（454 / 453 pass + 1 pending，4552 asserts）。

> 2026-09-13 ~ 2026-09-16 的内核迁移条目已归档：`docs/archive/LOG_2026-09_kernel_migration.md`。

### 2026-09-19 — 吃道具得分浮字（Item.collect → GameEvents.item_score → ScorePopupLayer）

- **需求**：P 点 / 点被自机吃掉时，在被吃掉位置显示本次得分并渐隐；后续细化到「金色只给过收点线/记忆释放」「点的分随深度递减」。
- **判据**：数字用项目现成的 `NumberSprite`（`ascii.png`），不引入 Label + 新字体；展示层不塞进 Item（R2/R7），走既有信号总线（与 `enemy_killed(score, position)` 同构）；池化复用，不每次 `new`。
- **做法**：
  - **触发**：`Item.collect()` 统一算 `gained`（POWER = `value`；POINT = 深度分），`>0` 时 `GameEvents.item_score.emit(gained, global_position, is_highlight)`。`Item.value` 死字段转正 = P 点吃下给的分（`POWER_SCORE := 10`，+1 火力 +10 分）。
  - **展示**：新 `ScorePopupLayer`（`Node2D`，`game_scene.tscn` 的 `World` 下声明）：池化 `NumberSprite`（ascii.png，`is_left_align`、5 位），`show_score()` 在被吃位置设值、上浮 `RISE` + alpha 1→0（`FADE_TIME`）后回池。`LayerConfig.SCORE_POPUP := 55`（EFFECT=50 之上）。
  - **点的分（深位递减）**：非金色收取时 `roundi(lerpf(max_point, MIN_POINT_SCORE=5000, t))`，`t = clamp((y - 收点线256) / (FIELD_BOTTOM 928 - 256), 0, 1)`；金色收取满分。`PlayerResources.add_max_point(score := -1)` 可传入账分并返回实际入账值，**max_point 恒 +10**。
  - **金色规则**：只给「过收点线」与「记忆释放强收（`force_collect()`，含它炸出的道具）」。`Item` 把合并的 `_auto_collect`（线 or 靠近）拆出 `_is_highlight`：过线 → 两者；靠近吸附/撞上 → 只 `_auto_collect`。`ScorePopupLayer.HIGHLIGHT_COLOR`。
  - **字号**：`NumberSprite` 按贴图像素逐位画、没有字号参数 → 新增 `@export var font_scale` 缩**每个浮字实例**（`ns.scale`），上浮距离同倍率。
- **踩坑**：
  - **别缩 `ScorePopupLayer` 节点**：那会把 `ns.position` 一起缩放、浮字位置跑偏。要改大小只动 `font_scale`。
  - **池复用必须在 `setup()` 归零**：新加的 `_is_highlight` 忘了重置，曾金色收掉的实例回池后被普通掉落复用 → 普通掉落误金色。给池化对象加字段一律在 `setup()` 清零。
- **验收**：`./tools/verify.sh` 全绿（453 / 452 pass + 1 pending，4406 asserts）；`test/test_score_popup.gd` 覆盖：P 点加分+发信号、点按线/中点/框底三档递减、金色贴框底仍满分、撞上/靠近白、过线/强收金、字号倍率、池复用不继承金色。

### 2026-09-19 — 弹雾回归 + 特效统一（A2）：EffectType / 逐行 fx_type / 纯特效行

- **背景**：参考内核（重建版）里「发弹预告」与「消弹消散」本是**同一套** —— `EffectType` + 逐行 `_fx_type` + `spawn_fx()` 纯特效行 + 一个渲染器。主项目原生迁移只搬了 `_fx` 相位（冻结），丢了 `_fx_type` + 纯特效行 + 特效渲染 → 弹雾整个消失，消弹退回宿主 `EnemyBulletClear` 节点 + `create_tween`。
- **判据**：特效是**短命行**不是节点；同一份描述符要能同时表达出生雾与消散；效果必须走 SoA + MultiMesh 批量，不能逐弹 `instantiate + create_tween`。
- **做法**：
  - C++ `DanmakuStore`：加逐行 `_fx_type` 列（`set_fx_type/get_fx_type_indices`）+ `spawn_fx(fx_type, pos, color, faction, life)` —— 纯特效行 `_type=-1`、无速度、寿命=相位；`setup/spawn/spawn_batch/_ensure_capacity/_swap_remove` 同步。
  - C++ `_run_behavior_pass`：补 `if (_fx[i] > 0) continue;` —— **相位内的弹不跑行为**（与参照 `behavior_processor.gd` 一致）。此前 `_fx` 恒 0，该缺口从没暴露；出生雾一开就现形（冻结期行为照跑、速度被改、还会提前 emit）。
  - C++ `DanmakuRenderBridge`：加特效表 `set_fx_table(tex_key/duration/scale_from/to/alpha_from/to/tint_mode)`；`group()` 按行 `fx_type` + 相位把弹与特效**分流**（特效键置高位命名空间，与弹键永不相撞）；新增 `fill_fx()`（带缩放 + alpha 淡出）。
  - `EffectType`：`key`(atlas) → `texture`；加 `alpha_from/alpha_to`。落 `data/fx/enemy_spawn_fx.tres`（弹雾.png，2.0→0.5 / 0.3s）、`data/fx/enemy_clear_fx.tres`（消弹.png，1.0→0.2 / 0.2s）。
  - `BulletType`：加 `is_spawn_fog`（逐弹型开关，默认 true）+ `spawn_fx`（逐弹型覆盖）；`BulletData` 加 `.with_spawn_fog()` / `.no_spawn_fog()`，删死字段 `fog_texture`。
  - `KernelNativeSystem`：`_fx_registry` + `spawn_fx()` + 快照 `_fx_type_index`；`BulletManager._enable_kernel` 里 `set_spawn_fx(ENEMY, 发弹特效)`（阵营默认，改一处全变）。
  - `KernelBulletPhysics`：`_play_clear` 从 `fx_pool.play(EnemyBulletClear)` 改为 `system.spawn_fx(消弹特效)`（提亮 1.5x 保留）；`sweep_enemy_bullets` 改成「先收集 / 回收，再统一发消散」——`spawn_fx` 向池尾追加，边遍历边追加会打乱 swap-with-last 的倒序前提。**雾中的弹同样进清场**（直接从发弹特效切成消散）。
  - `BulletMultiMesh`：弹 / 特效两路建组，共用 `bullet_batch.gdshader`（BLEND 分支的灰度混合 `mix(COLOR.rgb, white, gray)` 就是原雾 shader 的算法，无需新 shader）；特效组 z=`LayerConfig.EFFECT`。
- **删**：`scripts/effect/enemy_bullet_clear.gd`(+.uid)、`scenes/effect/enemy_bullet_clear.tscn`、`gdshader/bullet_fog_blend.gdshader`(+.uid)（`bullet_batch` BLEND 已覆盖）、`BulletData.fog_texture`、`AssetRegistry.FOG_TEXTURE`（纹理改由 `.tres` 直接引用）。
- **语义变化（重要）**：阵营默认打开后 **所有敌弹出生冻结 0.3s**（= 旧项目 `.enemy()` 即 `is_spawn_fog=true` 的原始语义）。不想给某型弹预告就 `is_spawn_fog=false` / `.no_spawn_fog()`。
- **踩坑 · `.enemy()` 覆写开关**：`non_mid01_shoot.gd` 写了 `.no_spawn_fog()` 却仍出雾 —— 链是 `.no_spawn_fog() … .enemy()`，`.enemy()` 里 `is_spawn_fog = true` 静默覆写。修法：把「敌弹默认出雾」从 `.enemy()` 挪到字段默认（`BulletData.is_spawn_fog = true`），`.enemy()` 不再碰它 → 开关与顺序无关；`test_spawn_fx` 加顺序反转守卫。
- **测试影响**：清弹类测试改为统计「真弹」（按 `get_type_indices() >= 0` 排除纯特效行）；`test_native_laser_anchor` 的激光段加 `.no_spawn_fog()`（该用例只验锚点）。新增 `test/test_spawn_fx.gd`（原生冻结/到期、阵营默认 + 逐弹开关、清弹切特效、渲染桥分流）。
- **验收**：`./tools/verify.sh` 全绿（check_syntax 301 / naming 0 / 启动零错；GUT 442 / 441 pass + 1 pending）。

### 2026-09-18 — 关 E1（R3）：场景期依赖自文档（@tool + _get_configuration_warnings）

- **判据**：R3 只覆盖**场景期外部依赖**（运行时注入豁免）。全项目真正的场景期 `@export` 引用只有 2 处：`nav_page.container_path`（空/无效 → 导航静默 no-op）、`game_over_menu.title_label`（null → 标题静默不更新）。
- **硬约束**：`_get_configuration_warnings` **必须 `@tool`** 才在场景停靠栏显示（Godot PR #75591）；`@tool` **不被子类继承**；且 `base_page._ready()` 会在编辑器里 `add_child(Overlay)` 污染 .tscn。
- **改**：
  - `base_page._ready()` 加 `Engine.is_editor_hint()` 守卫。
  - `nav_page.gd`：`@tool` + `_get_configuration_warnings()`（`container_path` 空/解析失败 → 警告）+ `_setup_nav()` 运行时 `push_warning` 响亮兜底。
  - `game_over_menu.gd`：`@tool` + 覆写 `_get_configuration_warnings()`（`title_label == null`）。
  - `character_screen` / `difficulty_screen` / `pause_menu`：仅 `@tool`（无 `_ready` 覆盖）。
  - `main_menu` / `player_data_menu` / `music_room_menu`：`@tool` + 给 `_ready`（及 `main_menu`/`player_data_menu` 的 `_input`、`main_menu`/`music_room_menu` 的 `_exit_tree`）加 `Engine.is_editor_hint()` 守卫，避免编辑器副作用。
- **计数**：`@tool` **3 → 11**；`_get_configuration_warnings` **0 → 2**。基线「🔴」删除 R3 行；审计表 R3 → ✅。
- **验收**：`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
- **待人工**：编辑器里打开 `main_menu.tscn` / 缺 `container_path` 的页面应看到相应警告（`@tool` 行为只有编辑器可见）。
### 2026-09-18 — 关 E2（R12）：唯一 `@export = preload` 拆成 export + 运行时兜底

- **现状**：`scripts/data/enemy_data.gd:9` 是全项目**唯一** `@export … preload`（R12 禁止）。它让「常量 preload」伪装成导出值（永不释放，又暗示可覆盖），且默认特效与 `AssetRegistry.enemy_visuals["death"]` 是**两份同源 preload**。
- **改（方案 A）**：
  - `@export var death_effect: PackedScene`（**无 preload 默认**，可置 null 释放）。
  - `enemy.gd`：`death_effect = data.death_effect if data.death_effect else AssetRegistry.enemy_visuals.get("death")` —— per-data 覆盖保留，**默认单源**收敛到 `AssetRegistry`。
  - 行为不变（无 `.tres` 覆盖该字段；`enemy.gd` 的 `if death_effect:` 兜底照旧）。
- **落点**：基线「🔴 待改进」删除 R12 行；外壳审计表 R12 由「1，待改」→「0，✅」。
- **验收**：`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
### 2026-09-18 — R15/E3 收尾：节点层 PascalCase（diffculty / jude / bar / content + root）

- **节点改名**（`.tscn` 节点名 + 代码引用 + `parent=` 路径）：
  - `scenes/game_scene.tscn`：`front`→`Front`、`diffculty`→`Difficulty`（拼写 + 大小写）、`debug`→`Debug`；`game_ui.gd` 4 处 `$"diffculty"` / `node.name == "diffculty"` 连带。
  - `data/enemy_visual/*_yin_yang_jade.tscn`：`jude`→`Judge`（×4）。
  - `scenes/workbench/creation_station.tscn`：`bar`→`Bar`、`content`→`Content`、`root`→`Root`；`creation_station.gd` 的 `$root/…` 连带。
  - 敌机外观场景根节点 `root`→`Root`（10 场景 + `kamorui`）。
- **结果**：非 addon 场景已无小写节点（`[node name="[a-z]` 归零）。
- **R15 收口**：目录段（`assets/Textures|Music|Sound`）立豁免、`stage03B` 大写保留（拍板）；**文件层 + 节点层已清**；基线「🔴 待改进」删除 R15 行。
- **验收**：`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
### 2026-09-18 — R15（E3）部分落地：文件层 snake_case + assets/* 目录立豁免

- **用户拍板边界**：`stage03B` 大写**保留**；**只改文件名**、**不碰 `.uid`**（Godot 自行刷新）；`YY_jade` = 阴阳玉。
- **文件改名（9 源文件 + 5 个 `.import` 侧车）**：
  - `assets/Textures/front/{False,True}Front{,2}.png` → `false_front{,2}.png` / `true_front{,2}.png`
  - `assets/fonts/SourceHanSerifCN-Medium.otf` → `source_han_serif_cn_medium.otf`
  - `data/enemy_visual/{red,green,blue,purple}_YY_jade.tscn` → `*_yin_yang_jade.tscn`
- **引用连带**：`scenes/game_scene.tscn`（FalseFront 路径）、`themes/ui_theme.tres` + `scripts/workbench/workbench_theme.gd`（字体）、`scripts/asset_registry.gd`（4 视觉 key + preload）、`scripts/data/enemy_data.gd`（4 预设方法 + key）。
- **契约**：`assets/Textures|Music|Sound` 三素材根目录立**明确豁免**（改名 = 3 目录 + ~236 路径 + 全量重导入，收益仅字面；与 `AssetRegistry` 豁免同源）。
- **`.uid` 值未动**；`.import` 的 `path`/`source_file`/`dest_files` 由 `godot --headless --import` 刷新为新文件名（`uid` 行不变）。
- **未做（用户指示「只改文件名」）**：小写节点 `diffculty` / `front` / `debug` / `jude` / `bar` / `content`（R15 节点层待办）。
- **守卫**：`check_naming` 新增 **⑦ 目录/文件名** —— 目录不得 PascalCase（豁免 `assets/Textures|Music|Sound` + `data/stages/stage03B`），文件名不得含 ASCII 大写（豁免 `README-OFL.txt` + `assets/Music/**` 内容槽曲目名）；当前 0。
- **踩坑**：改名后 `verify.sh` 先报 `ui_theme.tres` 找不到字体 —— 根因是 **Godot `uid_cache` 仍把 uid 映射到旧路径**；跑 `--import` 重建缓存后全绿。
- **验收**：`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
### 2026-09-18 — N8 执行（批次 2+3）：清 scripts/data · coroutine · components · enemy · autoload · player · replay · debug · asset_registry · ui_theme

- **批次 2（scripts/data）**：`r`→`record`、`e`→`entry`、`f`→`file_name`、`n`/`d`→`name_value`/`desc_value`、`s`→`text`、`q`→`quote_index`、`p`/`k`→`prop`/`key`、`t`→`type_id`；`bullet_data` 的 `r`→`rect`；`save_data` 的 `s`→`settings`。**保留**：`boss_data`/`enemy_data`/`bullet_data` 的链式 DSL 形参（`v`/`x`/`y`/`c`/`b`/`s`/`p`/`k`，单行）。
- **批次 2c**：`autoload`（`p`→`player`、`s`→`seed_value`）、`player`（`r`→`roll`）、`replay`（`f`→`file`、`d`→`data`）、`debug`（`r`→`radius`）。
- **批次 3**：`components`（`w`/`h`/`s`→`frame_w`/`frame_h`/`sprite`、`t`/`c`→`ratio`/`color`）、`enemy`（`r`→`entity_registry`、`t`→`fade_ratio`/`time_limit`、`e`/`t`→`item_type`、`n`→`new_name`、`v`→`shown`）、`coroutine`（`stage_director` `b`/`h`→`boss_node`/`handle`/`handler`；`boss_handle` 9 处 `b`→`boss`；`marisa_shoot` `s`→`segment`、`b`→`bullet_data`；`timeline` `t`→`event_time`；`player_service`/`stage_objects`/`bullet_service`/`stage_state`/`dialogue_runner`/`dialogue_steps` 全部改名）、`asset_registry`（`r`→`record`、`o`→`override_record`）、`ui_theme`（`t`→`type_name`、`n`→`entry_name`）。
- **踩坑 1**：`content_catalog._apply_meta` 首处替换只覆盖早退分支，回退分支仍用 `e` → 解析失败；补改。
- **踩坑 2**：`content_catalog` 里 `var text := ...` 遮蔽函数形参 `text` → 改 `line_text`。
- **踩坑 3**：`boss.gd` 局部 `registry` 遮蔽类成员 `registry`（warning-as-error）→ 改 `entity_registry`。
- **验收**：`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
- **唯一待续**：`workbench`（152）。
### 2026-09-18 — N8 执行（批次 1）：单字母严格化规则 + check_naming ⑥；清 scripts/scenes

- **规则（入基线）**：单字母只允许 ① 循环索引 `i`/`j`/`k` ② **单行表达式** / 链式 DSL·构建器形参（生命周期不跨行） ③ **热路径**模块（`kernel_bridge/` · `laser/` · `bullet/` · `effect/` · `background/screen_fog_fx|background_sun|decor_manager`）。其余跨行 / 跨函数 / 字段一律全名。消除了旧 §123「除 i/j/k 全禁」与 §128「单行·热循环可用」的矛盾，并换掉过期例子 `bullet_system`（已 vendor）。
- **守卫**：`check_naming` 新增 **⑥ 类字段不得单字母**（当前 0），把「字段一律全名」锁成机械规则。
- **批次 1（`scripts/scenes/`，37 处改名）**：`t`→`tween`、`s`→`sprite`/`text`、`v`→`value`、`r`→`record`、`c`→`child`/`children`、`o`→`option`、`b`→`bubble`、`d`→`difficulty`、`n`→`count`、`k`→`key`、`x`/`y`→`target_x`/`target_y`。保留：索引 `i`、单行循环（`boss_ui` 的 `for d in _dots: ...`）、单语句形参（`diff_name(v)` / `_pad_cn(v)`）。
- **踩坑（重要）**：`for` 循环体比 grep 命中窗口长 —— `game_ui` 的 `s` 还用在 220–224 / 232–236，首轮漏改 → `check_syntax` 报 8 处 `Identifier "s" not declared`。**循环变量的改名必须读完整循环体，不能只看声明行。**
- **验收**：`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
- **待续（批次 2+）**：`workbench`(152) / `scripts/data`(74) / `coroutine`(61) / `components`(15) / `enemy`(11) / `autoload`(7) / `ui_theme`(7) / `debug`(4) / `asset_registry`(4) / `replay`(4) / `player`(3) / `stage`(2) / `item`(1)，约 350 处。
### 2026-09-18 — 关 N14 + N17：门面动词封闭清单；KernelBulletBackend → KernelBulletHost

- **N14 函数动词不统一**：
  - 现状：机制类严格守 `get_*`/`is_*`/`has_*`（`EntityRegistry.get_boss`、`PlayerService.get_player`、`Enemy.is_targetable`…）；偏差全在意图层 —— `ctx.active()`、`ctx.boss.current()/exists()`、`ctx.diff.picked()/at_least()`、`BossHandle.exists()`。
  - 拍板（A）：不强制改机械 `get_`，而是把「**`ctx.*` 门面 + `StageContext` + `BossHandle` 的方法名可用域动词**」写进基线，受**封闭清单**约束（`active`/`current`/`exists`/`picked`/`at_least`），新增须登记。零改名。理由：门面只说意图，且避免 stutter（`ctx.boss.get_boss()`）。
- **N17 `KernelBulletBackend` 命名**：
  - 融合已定（设计 §11「翻译层已删；宿主耦合永久保留」），它不是 bridge，而是**宿主侧内核后端**（持有原生 `KernelNativeSystem`、bomb、behavior host、laser fade、纹理插座）。「暂缓待形状」条件已满足。
  - 拍板（B）：改名 **`KernelBulletBackend` → `KernelBulletHost`**（与 `KernelBehaviorHost` 同族）。连带：类文件 `kernel_bullet_backend.gd` → `kernel_bullet_host.gd`（+`.uid`）、测试 `test_kernel_backend.gd` → `test_kernel_host.gd`（+`.uid`）、字段 `_kernel_bullet_backend` → `_kernel_bullet_host`、节点名字符串、18 个 `.gd` + 4 个当前态文档。
  - **历史不篡改**：`docs/archive/**` 与既有 `BEST_PRACTICES_LOG` 条目里的旧名保留（记录当时状态）。
- **验收**：删除 `.godot/global_script_class_cache.cfg` 触发 `--import` 重建全局类缓存后，`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
### 2026-09-18 — 关 N4：`StageContext` 形参前缀统一（修 `_p_ctx`）+ check_naming 补 `_p_` 检测

- **来源**：`TODO_TEMP` N 组 N4。规则「遮蔽成员用 `p_` / 真不用只用 `_` / 禁止叠加 `_p_`」**早已在基线「标识符命名契约」**；本轮只剩执行。
- **现状核对**：`p_ctx` **19** 个形参声明、`_ctx` **34** 行；唯一叠加违规 `_p_ctx` 在 `scripts/coroutine/player/linear_move.gd:5`（`_tick` 函数体完全不用 ctx）→ 改为 `_ctx`，与基类 `CoroutineScript._tick(_ctx: StageContext)` 对齐。
- **check_naming 补洞**：⑤ 原本只检测「形参名 == 成员名」，`p_ctx`/`_p_ctx` 都不等于 `ctx`，所以注释里写的「禁止叠加 `_p_`」**没被执行**。⑤ 新增 `_p_` 前缀检测 + 独立输出段 + 计入总数（`p_x` 或 `_x` 两种正解都提示）。
- **未做**：`p_ctx` / `_ctx` 的既有分工不动（前者用 ctx、后者只透传/忽略），这两类合规。
- **验收**：`check_naming` 0 条（含新 `_p_` 段）；`./tools/verify.sh` 全绿。
### 2026-09-18 — 关 N2：`ctx.*` 门面命名规律写死（保留 `ctx.bullets`，不改 `bullet_service`）

- **来源**：`TODO_TEMP` N 组 N2（`ctx.bullets` 是否改 `ctx.bullet_service`，待拍板）。
- **判据**：门面 → 类型的实际对应是「**门面=域名词，类型=`<Domain>Service`**」——`ctx.bullets`→`BulletService` 与 `ctx.enemies`→`EnemyService`、`ctx.items`→`ItemService`、`ctx.effects`→`EffectService` 同构。改名 `bullet_service` 会让它成为**唯一带 `_service` 后缀的门面**，反而破坏一致性。
- **既有拍板**：2026-09-13 A2b「`ctx.*` 意图门面是唯一豁免、故意不动」+ A2c「拍板：`ctx.*` 门面不动」；`ctx.bullets` 是 A2b 把 `StageRuntime.bullets` / `BulletService.world` → `bullet_manager` 后**有意保留**的门面名，非漏网。
- **落点**：基线「标识符命名契约」新增一行门面命名规律（含映射示例），把口头拍板变成契约。
- **未做**：不改名（零代码改动）；`test_boss_phase` 的「门面是 `ctx.bullets` 不是 `ctx.bullet_manager`」回归断言继续有效。
- **TODO**：删除 N2。
- **验收**：`./tools/verify.sh` 全绿（纯文档改动）。

### 2026-09-18 — 关 A6：`AssetRegistry` 立「内容槽索引表」契约豁免；E11 迁移绑 F7/S13

- **来源**：`TODO_TEMP` A · 融合审查新增最后一条 A6（替换性瓶颈标注）。A6 本质是**优先级依据**、无独立代码交付物，实体是 E11（+F7/S13）；其「替换性快照」已在 2026-09-14 复核时产出。
- **决定（A6 收回 E11）**：
  - 基线「命名边界契约」新增**明确豁免**：`scripts/asset_registry.gd` = **内容槽的代码侧索引表**（`bullet_configs` / `enemy_visuals` / `sounds` / `FOG_TEXTURE` / `BGM_PATHS`），其 `res://` 与中文 key 属内容槽引用、非机制标识符 → 当前合规。
  - **退役条件写死**：随 S13 图集 + 数据化（F7：打包 + `AtlasLayout` + `BulletType` `.tres`）逐表迁 `data/**`；**迁完一表移除一表豁免**，全迁完豁免终止 —— 「换素材成本最高处」不再靠草稿记账，而有契约与期限。
  - `asset_registry.gd` 文件头注释同步，豁免与退役条件在代码现场可见。
- **数字订正**：`asset_registry.gd` **74 → 75** 条含 `res://`；`scripts/**` **227 → 219** 行。快照与 E11 行同步。
- **TODO**：删除 A6（并入 E11）；E11 改为「契约已立，迁移随 F7/S13」。
- **验收**：`./tools/verify.sh` 全绿（纯文档/注释改动，无行为变化）。

### 2026-09-18 — 落 V13+V14：on_end_call 契约 + host 收窄；target 策略归宿主（V 线收官）

- **V13 `on_end_call` 逃逸口契约化**：
  - `KernelBehaviorHost.backend` 私有化为 `_backend`（全仓 0 处外部访问）→ 内容回调只能经 `host.queue_spawn()` 入队，拿不到整个后端。
  - `bullet_lifecycle.on_end_call` 注释 + `DANMAKU_API §3.4/§9.16` 明确契约：每相位结束最多一次、宿主侧、非热路径；签名 `(pos, boss_pos, has_boss, host)`；用了它描述符不再是唯一行为来源。
- **V14 targetability 策略归宿主**：
  - 参考解释器 `_target_pos(T_NEAREST_ENEMY)` 删除内嵌的「跳过时符 / 未开战 Boss」逻辑，改为对**宿主提供的候选集**取最近；targetability 由 `EntityRegistry.get_targetable_enemies()` → `Enemy.is_targetable()` 决定（已有 `test_boss_targeting` 覆盖），内核不再内嵌过滤。
  - `bullet_lifecycle.T_NEAREST_ENEMY` 注释 + `DANMAKU_API §3.6/§9.17` 写清目标契约：target 是固定枚举，候选集由宿主给。
- **测试**：`test_boss_targeting` 3/3、`test_lifecycle_hooks` 3/3、`test_lifecycle_presets` 8/8、`test_native_executor` 9/9、`test_lifecycle_primitives` 39/39 全过。
- **验收**：`./tools/verify.sh` 全绿（**436 pass + 1 pending / 437 测试 / 4354 断言**）。
- **状态**：V 线（弹幕 VM 原语正交性审查）**全部完成**（V1–V20；V4 被 V18 吸收、V5 先行文档化）。

### 2026-09-18 — 落 V9+V10：emit_variant 独立 op（去掉隐藏分支通道）；RNG 消耗点显式化

- **V9 `_dir_branch` 移除**：`emit_variant` 现在是独立 action op（`OP_A_EMIT_VARIANT=46`），参数 `[action_id, p, hit_dk, hit_tg, hit_angle, miss_dk, miss_tg, miss_angle, speed, at]`；命中 = `toward(target)`、未命中 = `forward(spread)`。内核抽一次定分支、只回传分支号；方向由 op 参数直接算，`_resolve_dir` 不再写隐藏状态。`chance_toward` 仍是 creator 语法，且**只允许**作 `emit_variant` 的 dir（否则 warn + 退化为普通 emit）。
- **V10 RNG 消耗点显式化**：`_resolve_dir` 改为纯函数（多一个 `rnd` 参数，不抽 RNG、无副作用）；新增 `_draw_dir_rnd(dk)`，只有 `RANDOM` / `CHANCE` 方向表达式各抽一次，`emit_variant` 显式抽一次定分支。消耗点与次数写死在 op 语义里，不再藏在方向求值内部。
- **参考解释器**：`A_EMIT_VARIANT` 取未命中分支（参考不模拟随机/分支）；`random_dir` 的原生↔参考 parity 不变。
- **测试（复用既有）**：`test_emit_variant` 6/6、`test_kernel_random` 5/5（多 random_dir 顺序敏感）、`test_probe_descriptor` 4/4、`test_lifecycle_primitives` 39/39、`test_native_executor` 9/9 全过。
- **文档**：`DANMAKU_API §3.4/§3.5/§9.15` 同步（RNG 消耗点、emit_variant 独立 op）。
- **验收**：`./tools/verify.sh` 全绿（**436 pass + 1 pending / 437 测试 / 4354 断言**）。

### 2026-09-18 — 落 V12 + V15：rotate 三模式；set_speed 在 v=0 用朝向

- **V12 `rotate` 拆轴（同一 op 内加 mode）**：
  - `rotate(w, limit=0)` = 同时转速度与朝向（原语义）；`rotate_velocity(w, limit=0)` = 只转速度；`rotate_heading(w, limit=0)` = 只转朝向。三者共用 `M_ROTATE` op（`mode`=ROT_BOTH/VELOCITY/HEADING），参数 `[w, limit, slot, mode]`；都分配 turned 槽，`until_turned()` 对三者通用。
  - 原生 case 3 按 mode 条件转 `v` / `h`；参考解释器无朝向 → mode=2 时速度不动（与原生 heading-only 的「速度不变」一致，parity 保住）。
- **V15 `set_speed` 的 v=0 边界**：`_apply_set_speed` 在 `|v|=0` 时改用**朝向**定方向（零速出生朝向 = (0,1)），不再静默 no-op，与 `set_heading` 对称。参考侧无朝向，用 (0,1) 近似（零速出生一致）。
- **测试（+5）**：`rotate_velocity` / `rotate_heading` parity；`rotate_velocity` 保朝向、`rotate_heading` 保速度的行为测试；`set_speed` 静止弹沿 (0,1) 给速度。`test_lifecycle_primitives` 34→39。
- **文档**：`DANMAKU_API §3.2/§3.6`、`LIFECYCLE_MODEL §3/§11` 同步。
- **验收**：`test_lifecycle_primitives` **39/39（127 断言）**、presets 8/8、native_executor 9/9、heading_state 4/4；`./tools/verify.sh` 全绿（**436 pass + 1 pending / 437 测试 / 4354 断言**）。

### 2026-09-18 — 落 V6+V7+V8：Until 层重整（通用节流 / at_wall 纯谓词 / at 操作数 / 收掉 until_state）

- **V6 通用节流**：条件 op 参数统一为 `[every, every_ticks, p0, p1, …]`；`_check_until` 先做节流（先帧门控 `_ptick % n`，再秒节流 `_pnext`）再分派。builder 加链式 `.every(sec)` / `.every_ticks(n)`，任何 Until 可套；`until_near(target, r)` 去掉 `every/every_ticks` 参数（preset 改用链式）。语义与旧 `near` 节流 1:1（`_ptick` 仍是每弹全局帧计数）。
- **V7 位置操作数 + 纯谓词**：`emit/emit_variant` 第 4 参由 `at_end: bool` 改为 `at: AT_CURRENT|AT_PHASE_END`（与方向表达式对称的位置轴）；`until_at_wall` 只做越界检测并输出「相位结束落点」，`emit(..., at=AT_PHASE_END)` 显式读它。删除未被实现、也没有下墙的 `WALL_BOTTOM` 常量。
- **V8 收掉裸槽 API**：移除公开的 `until_state(slot, cmp, value)`（slot 对创作者不可见，全仓只有 primitive 测试在用）；`until_turned()` 改为健壮——无前置 `rotate` 或 `limit<=0` 时 `push_warning` + 退化为 `until_never`；native/reference 的 `state` 条件加 slot 边界守卫（`slot=-1` 不再读上一颗弹的槽）。
- **测试**：移除 `test_primitive_until_state`（API 已删）；`test_primitive_action_emit` 显式用 `AT_CURRENT`；新增 `test_action_emit_at_phase_end_uses_wall_point`（`AT_PHASE_END` 落点 = 夹到 `FIELD_TOP`）。
- **文档**：`DANMAKU_API §3.3/§3.4/§3.6/§3.7/§3.8/§9.6`、`LIFECYCLE_MODEL §3/§11` 全部同步。
- **验收**：7 套相关测试全过（primitives 34/34、presets 8/8、native_executor 9/9、behavior_batch 3/3、heading_state 4/4、kernel_random 5/5、emit_variant 6/6）；`./tools/verify.sh` 全绿（**431 pass + 1 pending / 432 测试 / 4340 断言**）。

### 2026-09-18 — 落 V11 + V17：Move/Action 瞬时变换去重；RNG 顺序陷阱入档

- **V11（去重）**：原生 `_exec_move` 的 `set_heading`(case 7) / `set_speed`(case 8) 与 `_exec_action` 的 case 43/44 原本**各有一份实现**，语义相同、易漂移。抽出 `DanmakuStore::_apply_set_heading(...)` 与 `_apply_set_speed(...)`，四个 case 都调用；**纯重构、零行为变化**（case 8 从局部 `v` 改为重取 `_vx/_vy`，两者在该点等值）。参考解释器保持不动（冻结 oracle，本次无语义变化）。
- **V17（文档）**：`DANMAKU_API §9` 新增陷阱 15「**RNG 是单通道、按「op 顺序 + 弹行遍历顺序」消耗**：`random_dir` / `chance_toward` 每求值一次抽一次；加/删/重排方向表达式或改发射顺序都会平移之后所有随机序列（回放可复现，但结果会变）」；顺带把陷阱 14 的 `drift` 命名更新为 `position`(PHASE_START)。
- **验收**：`./tools/verify.sh` 全绿 —— check_syntax 301 脚本 0 失败 / check_naming 0 条 / 启动零错误 / GUT **431 pass + 1 pending（432 测试 / 4340 断言）**。

### 2026-09-18 — 落 V19：`render_heading` 拆出独立渲染朝向通道（位置 op 不再写 velocity）

- **来源**：弹幕 VM 原语正交性审查 V19。V18 后唯一残留的「位置 → 速度」泄漏：`position` op 在 `render_heading=true` 时写 `_vx/_vy`（为渲染朝向），却**不写 `_hx/_hy`** → 锚定期 velocity 与 heading 分离（`accel_heading`/`forward` 读旧朝向，渲染读 velocity）。
- **改（独立通道）**：
  - 原生 `DanmakuStore` 新增逐弹 `_render_rot` 列（NAN = 未设）；position op 的 render_heading 改设 `_render_rot = atan2(adir_y, adir_x)`，**不再写 velocity**；`_run_behavior_pass` 每帧重置，只有当前帧的 position op 会设。新增列按「6 处纪律」同步：`setup / _ensure_capacity / spawn / spawn_batch / _swap_remove / behavior_batch`（+ `get_render_rots`）。
  - `DanmakuRenderBridge::group` 增可选 `render_rots`：`follow_dir` 时优先用它，NAN 回退 velocity 角；`dir_offset` 逻辑不变。
  - `KernelNativeSystem` 快照加 `_render_rot`（容量 / swap / pull / getter）；`BulletMultiMesh._sync_native` 透传。
  - 参考解释器 `M_POSITION` 不再写 velocity（无渲染通道，不模拟）。`test_lifecycle_presets._parity` 加 `check_vel`；`marisa_laser` oracle（旧 behavior 仍写 velocity）改为只比位置。
- **视觉等价性**：override 值 = 旧路径 `atan2(v.y,v.x)`（v=dir(angle) 单位向量）→ 渲染 rot 等价；`follow_dir=false` 或未设 override 时完全走旧路径。
- **测试**：新增 `test_position_render_heading_uses_render_channel`（velocity 保持 + `render_rot = -PI/2`）。
- **验收**：相关 6 套件全过（primitives 34/34、presets 8/8、native_executor 9/9、laser_anchor 1/1、behavior_batch 3/3、heading_state 4/4）；`./tools/verify.sh` 全绿（**431 pass + 1 pending / 432 测试 / 4340 断言**）。
- **⚠ 待人工验收**：渲染朝向链路只有人眼能兜（2026-09-13 N4-real 教训）。上线前需实机确认**魔理沙激光段朝向**（render_heading override）与其它 `follow_dir` 弹旋转未变。

### 2026-09-18 — 落 V18：位置来源统一为 `position` op（模式派 + 显式过渡语义）

- **来源**：弹幕 VM 原语正交性审查 V18（上位吸收 V4/V5）。原 `anchor_drift`(op 9) / `drift`(op 10) 是两个 op 表达同一件事，且都以绝对写 `pos` 的方式与速度 op 混在一条轴上。
- **改（模式派）**：
  - 词汇：`drift` / `anchor_drift` 仍是 builder 糖，但都编译成**同一个** `M_POSITION`(op 9)，用 `mode` 区分 `POS_PHASE_START` / `POS_ANCHOR`；**删 op 10**。
  - `OPS_ARGS` / `ARGS` 8 → 12；position 参数 `[mode, anchor_id, off.x, off.y, angle, speed, flags, initial, slot, base_sx, base_sy]`（ANCHOR 用 1 槽；PHASE_START 用 3 槽记起点 + 位移）。加宽对其它 op 只是 padding，无行为变化。
  - 原生 case 9 统一；参考解释器 `M_POSITION` 同步。
- **显式过渡语义（文档化 + 测试）**：
  - 进入 / 切换：首帧 `pos = base + dir(angle)·initial`（位置立即被模式接管）。
  - 模式**只写 `pos`**，`v` / `h` 不受影响 → 释放后按速度轴自由飞（`drift` 后能按出生方向飞出）。
  - 离开模式：`pos` 留在模式最后结果，积分从该点接力。
  - 同相位多个 position op = **模式切换、后写者胜**（不是叠加）；与速度 op 混用会让速度变化在位置上看不见。
- **未做（明确留给 V19）**：`render_heading=true` 仍借道 velocity（渲染用），是唯一残留的「位置 → 速度」泄漏。**本轮不动**：渲染朝向链路（`DanmakuRenderBridge` 用 velocity 算 rot）只有人眼能验收（见 2026-09-13 N4-real 教训），需独立一轮加「per-row render 朝向通道」。
- **测试**：新增 `test_position_op_is_unified`（两种糖 → 同一 op）与 `test_combo_position_mode_preserves_velocity`（模式不碰 v）；既有 drift/anchor_drift/parity/heading 测试全过。
- **验收**：`test_lifecycle_primitives` **33/33（110 断言）**；`./tools/verify.sh` 全绿（**430 pass + 1 pending / 431 测试 / 4337 断言**）。

### 2026-09-18 — 修 V20：状态槽越界守卫（`slots > SLOT_STRIDE` 拒绝注册）

- **来源**：弹幕 VM 原语正交性审查 V20。`_pslots` 按固定 `SLOT_STRIDE=8` 分行索引，`register_program` 的 `slots` 无守卫；`drift` 每实例占 3 槽 → 同相位 3 个 `drift` 即 `slots=9`，`slots[8]` 会**写进下一颗弹的行**（末行真 OOB），静默串行。
- **改（拒绝式守卫）**：
  - 原生 `DanmakuStore::register_program`：`p_slots > SLOT_STRIDE` → `return -1`（**不发引擎消息**）。
  - `BulletLifecycle.compile()`：`slots > MAX_SLOTS(8)` → `push_warning` 早提示；新增 `const MAX_SLOTS := 8` 与原生 `SLOT_STRIDE` 对齐。
  - `KernelNativeSystem._program_for`：`pid < 0` 时**不 append** `_program_data`（否则 native pid 与 `_program_data` 索引错位），报错并缓存 -1。
  - 文档：`DANMAKU_API §3.7 / §9.14`、`LIFECYCLE_MODEL §3` 写明「同相位槽 ≤ 8，超限 program 被拒绝」。
- **测试**：`test_lifecycle_primitives.gd` 新增 `test_combo_slot_budget_overflow_rejected`（3 drift=9 槽 → pid=-1）与 `test_combo_slot_budget_at_limit_ok`（8 rotate=8 槽 → 接受）。
- **踩坑（重要）**：第一版用 `ERR_PRINT` / `push_error` → GUT 报 `Unexpected Errors`；**原生 `WARN_PRINT` 也被 GUT 记为 engine error**。改为原生**静默返回 -1** + GDScript `push_warning` 后通过。
- **验收**：`test_lifecycle_primitives` **31/31（104 断言）**；`./tools/verify.sh` 全绿（**428 pass + 1 pending / 429 测试 / 4331 断言**）。


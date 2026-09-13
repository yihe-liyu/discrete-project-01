# Godot 最佳实践日志（BEST PRACTICES LOG）

> 本文件**随意长**：记录"为什么这样改 / 当时学到什么 / 踩过的坑"。
> 与 BEST_PRACTICES_BASELINE.md（只反映当前状态）分工：**状态更新去 baseline，心得记录来 log。**

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

### 2026-09-13 — D1：拆 SaveData（240 → 128 行；抽出 StageCatalog / PracticeSession / UiTheme）

- **动机**：`SaveData` 240 行 / 6 职责（全局选择 · 关卡目录 · 存档 · 练习 session · 启动装配 · 会话复位），是 38 个文件引用的 god object。
- **拆出**：
  - `StageCatalog`（58 行）：`stage_registry` 加载 + `find` / `scan` / `all` / `background`。
  - `PracticeSession`（43 行）：`is_practice_mode` + 练习载荷（phase / boss_scene / boss_name / stage_id / phase_index / background）+ `start` / `finish` / `clear`。
  - `UiTheme`（24 行）：`apply_ui_theme` → `UiTheme.apply()`（主题不是存档）。
- **保留在 SaveData**：全局选择（难度 / 角色 / 关卡进度）、会话标志（`is_stage_practice` / `restarting`）、存档 / 符卡簿 / 高分、`reset_session` 编排、`apply_settings`。
- **语义保持（关键）**：`reset_all`（每次 load_stage）**只清练习载荷、不碰 `is_stage_practice`** —— 否则 stage 练习中途 `load_stage` 会误清玩法标志；只有 `reset_session` 清 `is_stage_practice`。`PracticeSession.start` 仍先经 `SaveData.reset_session()`。
- **调用点**：脚本化替换 9 个文件（含 4 个测试）；`grep 'SaveData.practice_*' scripts/ data/ test/` = **0**。
- **踩坑（老坑）**：新增 3 个 `class_name` → 必须先 `godot --headless --editor --quit` 重建 `.godot/global_script_class_cache.cfg`，否则 `check_syntax` 报 `Identifier not found`。
- **验收**：check_syntax **194/0**；GUT **322 测试 / 3247 断言**全绿。

### 2026-09-13 — 更正：godot-cpp 的 4.7 前置（实测 GitHub）

- **原判断**（§0.2 / §12）：`godot-cpp` 有无匹配 Godot 4.7 的 branch「未确认」+ 本机缺 `scons`。
- **实测（fetch godot-cpp README / releases）**：godot-cpp **v10（master，Beta）**起版本号与 Godot 独立，README 明确 `api_version` 可选，示例即 `api_version="4.7"`，并写「v10 可 target Godot 4.3+（含 4.6）」。稳定分支/tag 仍停在 `godot-4.5-stable`，最新 release 是 `10.0.0-rc2`（2026-08-25）。
- **结论**：**「支持未确认」不成立** —— v10 可定位 4.7；唯一实际风险变成 **v10 仍 Beta、无 stable 分支**。本机缺的 `scons` 可 `pip install scons`。
- **验收**：纯文档更正；未动代码。

### 2026-09-13 — 桥接收口审计：924 行构成 + 更正「≤300」不可达目标

- **背景**：计划 §16.5 的「融合完成」判据写着 `scripts/kernel_bridge/` **≤ 300 行**。动手"收桥接"前先实测。
- **测量**：总计 **924 行** = 适配器 `kernel_bullet_backend` **236** + 宿主耦合 **688**（行为桥 273 / bomb 160 / 碰撞·擦弹 165 / laser fade 53 / 延后队列 37）。判据**自己要求保留**这 688 行 → **300 不可达**（是写出来时没量过的目标）。
- **剩余"翻译 / 侧表"只剩一处**：`_port_by_sig`（`kernel_port()` duck-typing 的行为绑定缓存）+ 6 处 `kernel_port()`。它是 **VM（N3）的前身** —— `_type_by_sig` / `_damage_by_index` / `_hit_sfx_by_index` 已随 M1/M2 删除；`_texture_by_index` 是 M3 ③ 的渲染插座。**在不上 N3 的前提下，桥接没有可删的行。**
- **更正**：§16.5 去掉行数上限，判据改为结构性（0 类型映射 / 0 内容签名侧表 / 内核 0 宿主引用），行数只作观测；基线同步。
- **教训**：**判据要在写下的当天就量。** 一个从没量过的行数目标，会让人误以为"还有一大坨可删"，实际是一堆判据要求保留的宿主耦合。
- **验收**：纯文档更正。

### 2026-09-13 — M3 拍板：③ 纹理句柄（渲染插座正式化）

- **决定**：M3 走 ③。宿主 `_texture_by_index` / `texture_for_index()` 正式定为**渲染插座（render socket）**；内核 `BulletType.type_index` = **纹理句柄**。**这不是债，是设计好的 seam。**
- **否决**：① 会让 §16.5 的 `_by_index = 0` 判据永不达标；② 提前把渲染塞回内核（触发条件未到，且破坏「内核 0 渲染」的克制）。
- **零内核改动**：不回重建版、不 vendor、不 tag。
- **落点**：plan §16.1 侧表行 / §16.3 M3 段 / §16.5 判据（`_by_index = 0` 收窄为「类型 / 端口 / 伤害侧表」；纹理句柄表按设计保留，N4 原生替换）；`KernelBulletBackend` 注释；基线融合 bullet；决策页 `docs/M3_TEXTURE_OWNERSHIP_DECISION.md`。
- **验收**：check_syntax 191/0；GUT 全绿（纯注释 / 文档，无行为变更）。

### 2026-09-13 — Tier A 收尾：A1 导出阻塞 + A2 测试卫生 + A3–A5 文档失真

- **A1（导出阻塞）**：内容侧 4 处 `ResourceSaver.save` 直接写 `res://`（`spell_book_manager.gd` / `asset_registry.gd` / `music_room_menu.gd:35,150`）→ 导出包只读必失败。改为「**res:// 出厂默认 + user:// 覆盖**」：`SpellBookManager` 加 `SPELL_BOOK_USER_PATH`；`AssetRegistry` 加 `MUSIC_REGISTRY_USER_PATH` + `load_music_registry()` / `save_music_registry()`（音乐档**以出厂目录为基准叠加 user 解锁**，新曲目不会被旧档吞掉）；`music_room_menu` 改走这两个 helper；顺带删 `audio_manager` 里从未使用的重复常量。
- **A1 守卫**：新增 `test/test_persistence_paths.gd` —— 扫 `res://scripts` + `res://data`，断言没有任何 `ResourceSaver.save` 行含 `res://`（`tools/` 是编辑器工具，豁免）。
- **A2（测试卫生）**：`test_boss_encapsulation` 3 + `test_param_validator` 7 个孤儿 Node 未释放 → 加 `autofree`。**orphans 10 → 0**。
- **A3/A4/A5（文档失真）**：基线 R5 `get_node` 计数更正为 **29 个调用点**（生产 14 / 测试 15，原记 19 漏了测试）；基线 R14 更正——`SaveManager` 走 user:// 不代表内容侧不写 res://（A1 那 4 处就是漏报）；`CONTENT_GUIDE` §八的 `StageManager` / `GameState` → `StageRuntime` / `SaveData`。
- **教训**：**"某处达标"不等于"整类达标"** —— R14 只查了 `SaveManager` 就写「0 处」，把内容侧 4 处漏了。审计要按"类"扫，不是按"记得的那个文件"扫。
- **验收**：verify.sh 五步全绿（322 测试 / 3247 断言，orphans 0）。
- **附带**：M3 决策页 `docs/M3_TEXTURE_OWNERSHIP_DECISION.md`（推荐 ③ 纹理句柄，待拍板）。

### 2026-09-13 — 会话状态收口：SaveData.reset_session()（唯一复位入口）

- **背景**：连续两条试玩 bug（练习载荷泄漏、门面误改）都属「跨局 / 跨场景状态没清干净」。做了一次全量 `static var` 审计（谁置位 / 谁复位）。
- **审计结论**：多数平衡（`.current` 各自 `_ready`/`_enter_tree` 置位、`_exit_tree` 清；缓存进程级）；**漏一个**——`current_stage_id` 从不复位。
- **`current_stage_id` 漏**：默认 1，`game_scene._on_stage_cleared` 通关时 `+= 1`，但 `main_menu._start_game_flow` 从不改回 1 → 清关后回标题、再开新游戏会从 stale 关卡号开始。且 `stage_registry` 只有 stage01（`find(2)` 为 null），`+= 1` 后会 `push_error` 卡死（stage01 有结局时触发）。
- **修法（结构性）**：新增 **`SaveData.reset_session()`** —— 唯一复位入口，清 练习载荷 + `current_stage_id` + `restarting` + `is_stage_practice`。`main_menu._start_game_flow` 与 `SaveData.start_practice`（以及 `stage_practice_menu.on_enter`）都先经过它；`_on_stage_cleared` 改为**仅当下一关存在**才 +1，否则视作通关回标题并复位会话。
- **契约**：基线新增「**会话状态契约（per-run static）**」——每个跨场景 static 列出 owner / 置位 / 复位，并规定必经 `reset_session`。
- **回归**：新增 `test/test_session_state.gd`（复位清全部 / 进练习隐含复位 / 幂等）；双向验证 `start_practice` 那条——去掉复位 2/3，恢复 3/3。
- **教训**：**「模式标志」与「模式载荷」要一起清，而且复位点要唯一。** 散落的「各自清一点」迟早漏；把它收成一个入口，测试才有地方钉。
- **验收**：verify.sh 五步全绿（320 测试 / 3244 断言）。

### 2026-09-13 — 修复：练习载荷未清空（先练习、再普通流程会告警 / 误判）

- **现象**：先打一次练习，再进普通流程 → `game_scene.gd:48` 告警「practice_phase 已设置但 is_practice_mode=false —— 练习标志被提前清除，误走普通关卡」。
- **根因**：`SaveData.end_practice()` 只把 `is_practice_mode` 置 false，`practice_phase / practice_boss_scene / practice_name / practice_stage_id / practice_phase_index / practice_background` 六个载荷原封不动；`reset_all()` 同样只清标志。下一局普通开局前就会看到残留，且任何按 `practice_*` 判断的路径都可能误判。
- **修法**：新增 `SaveData._clear_practice()`（清 6 个载荷 + 模式标志），`end_practice()` 与 `reset_all()` 都调它；`end_practice` 仍尊重 `restarting`（重开练习要保留状态）。
- **回归**：`test_practice_mode.test_end_practice_clears_payload` + `test_reset_all_clears_practice_payload`；**双向验证** —— 旧代码 1/3（`practice_phase` / `practice_background` 残留），新代码 3/3。
- **教训**：**「模式标志」和「模式载荷」必须一起清。** 只复位布尔标志，留下的载荷就是下一次进入别的流程时的定时炸弹。静态 `var` 在 GUT 同进程内还会跨用例串味——`test_practice_mode` 原测试就靠 `end_practice()` 收尾。
- **验收**：verify.sh 五步全绿（317 测试 / 3232 断言）。

### 2026-09-13 — 修复：ctx 门面误改（boss.clear_phase 访问 ctx.bullet_manager）

- **现象**：试玩中 Boss 击破报 `Invalid access to property or key 'bullet_manager' on ... StageContext`（boss.gd:298，栈：take_damage → clear_phase）。
- **根因**：A2b 命名收敛把「BulletManager 实例字段」`world`/`bullets` → `bullet_manager`，却**误伤了 `ctx.*` 意图门面** —— StageContext 的门面是 `bullets`，没有 `bullet_manager`。test 没抓到是因为 test_boss_phase 里 `clear_phase` 从不带非 null ctx（`if _stage_context:` 直接跳过）。
- **修法**：`_stage_context.bullets.death_clear(...)`（BulletService 门面；其 `death_clear` 本身 null-safe）。
- **回归**：`test_boss_phase.test_clear_phase_death_clear_via_bullets_facade` 用 `BulletSpy` 记录 `death_clear`；**已双向验证** —— 旧代码 15/16（且打同一条错误），新代码 16/16。
- **全仓排查**：`grep -rn '\.bullet_manager'` 其余 8 处接收者都是 StageRuntime / BulletManager / HitboxOverlay / KernelBomb，合法；仅 boss.gd:298 把 StageContext 当成了 BulletManager。
- **教训**：「`ctx.*` 门面豁免改名」光写文档不够 —— **批量改名必须显式排除门面访问**；且 tests 对「非 null ctx + 门面调用」有覆盖洞（之前全靠 `ctx = null` 的早退分支蒙过）。
- **验收**：verify.sh 五步全绿（315 测试 / 3222 断言）。

### 2026-09-13 — 修复：延后发射队列未快照 per-shot 状态（non_mid01 红弹速度梯度消失）

- **现象**：`non_mid01_bullet.gd:45` 的 `_red_bullet_data.speed(RING_SPEED + i * 50)` 不生效 —— 红弹全按最后一档速度飞。
- **根因**：内核行为循环中途禁止 spawn，故走 `KernelBehaviorHost.queue_spawn` 延后到 flush。旧 `queue_spawn` 存的是 `{data = data}` **活引用**；M2 起内容复用同一 `BulletData` 实例（正是 M2 要求的写法），于是同一帧多次入队全指向同一实例，flush 时才读 `data.velocity` → 被最后一次写入覆盖。`radial_accel_behavior.gd:43` / `bounce_behavior.gd:61` 的 `b.velocity = …` 同样中招（工厂返回缓存实例）。
- **修法（在队列，不在内容）**：`KernelBulletBackend` 拆出 `prepare_shot()`（解析类型 / 速度 / 行为 / 染色 / 贴图，不写池）与 `spawn_prepared()`（写池）；`queue_spawn` 改为**入队瞬间** `prepare_shot` 快照，`flush` 只 `spawn_prepared`。`shoot()` = 两者立即串接，签名不变；`_sync_host_tables` 改收 `texture`。
- **为什么改队列**：`queue_spawn` 原注释要求「传副本」，但 M2 的全部意义就是别每发造新 `BulletData`（否则弹型表膨胀）。把不变量放回队列：内容尽管复用实例、每发改速度，延后机制自己保证正确。
- **回归测试**：`test_queue_spawn_snapshots_per_shot_speed`（通用：同一模板两次不同速度入队，flush 后各保留）+ `test_non_mid_red_ring_keeps_speed_gradient`（内容：Hard 下速度集合 = 400/450/500/550）。
- **教训**：**延后 / 异步机制一旦存引用，就必须在入队瞬间快照「所有 per-shot 字段」**，否则「复用实例」这个性能优化会变成静默串味。断言数 3217 → 3220。
- **验收**：`verify.sh` 五步全绿（313 测试 / 3220 断言）。

### 2026-09-13 — 修复：形参遮蔽成员（4 处，其中一个是静默 no-op）

- **现象**：编辑器脚本 reload 报 4 条 `SHADOWED_VARIABLE` / `CONFUSABLE_LOCAL_USAGE`：`bullet_manager.gd:181/218`、`game_manager.gd:87`、`boss_ui.gd:92`。
- **不是纯警告**：`game_manager.gd:89` 的 `entity_registry = entity_registry` 两侧都解析为**形参** → 自赋值 no-op，`GameManager.entity_registry` 永远是 `null`，`_clear_world()` 从不 `entity_registry.clear()`（切场不清实体）。警告背后是真 bug。
- **修法**（按基线「形参遮蔽成员 → `p_`」）：`inject_entity_registry(p_entity_registry)` / `register_world(..., p_entity_registry)`；`bullet_manager.gd:218` 的 `var entity_registry := entity_registry` 删局部改读属性；`boss_ui._on_boss_defeated(_defeated_boss)`（真不用 → 单 `_` 前缀且不撞成员）。
- **为什么 lint 没抓到**：`check_syntax` 只认 `SCRIPT ERROR`、`verify` 的启动段只 grep `ERROR`——**W 级警告不在门禁里**；而 headless `load()` 走编译缓存，连警告都不打印。只有编辑器 reload 路径才吐。
- **补门禁**：`tools/check_naming.sh` 新增 **⑤ 形参/局部/循环变量遮蔽类成员**（静态扫描，不依赖 Godot reload）；`tools/verify.sh` 升为 5 步，第 2 步跑 `check_naming.sh --fail`，CI 沿用 `verify.sh` 故自动生效。正向 0、负向探针 `--fail` = 1，均实测。
- **回归测试**：`test_composition_root.test_game_scene_binds_stage_runtime` 增断言 `GameManager.entity_registry == rt.entity_registry`——旧代码必失败（断言数 3216→3217）。
- **教训**：编辑器 reload 的 W 级输出要有人看；`x = x` 这种「看起来在赋值」的自赋值只能靠 warning 暴露，且常被当噪音忽略。**可 lint 的规则不要只写进文档。**
- **验收**：`verify.sh` 五步全绿（312 测试 / 3217 断言）；`check_naming` 0（含新 ⑤）。

### 2026-09-13 — M2：词汇合一（BulletData → BulletType，删 type_for/signature_of/_type_by_sig）

- **决定**：走方向 (b) —— `BulletData` 退化成**构造助手**，`to_bullet_type()` 产出并缓存 `BulletType`。
- **删**：`type_for()` / `signature_of()` / `_type_by_sig` 全删；字段映射从桥接搬进 `BulletData._build_bullet_type()`（宿主→内核仍是单向）。桥接 964 → **906** 行。
- **契约收紧（最重要）**：内核弹型缓存在 **BulletData 实例**上 → 内容**必须复用实例**。旧代码靠"内容签名缓存"兜底，所以 `enemy01` 同一实例换贴图、`reimu_shoot` 每发 new 都能跑；现在不行了。改了 13 个内容文件：
  - 每发 new → 成员缓存（`_main_bullet_data` / `_plain_bullet_data` / …）；类型级字段建一次，速度 / params 每发写。
  - `enemy01/02/03` 原用**同一个** BulletData 交替当"普通弹 / 强化弹"（还改 `coroutine_script`）→ 拆成**两个实例**。
  - `radial_accel` / `bounce` 的 `spawn_factory` 原每次返回新对象 → 改为返回缓存实例。
  - `marisa_shoot` 激光段**逐帧换贴图** → 按帧缓存 `Array[BulletData]`。
  - `BulletShell`（工作台）按配置 key 缓存，配置变才换实例。
- **踩坑**：test 锁着旧契约「工厂每次应是新对象」→ 改为「复用同一缓存实例」。
- **命名合同步**：新增私有字段按 `_<限定词>_<类型snake>` → `_main_bullet_data` 等（`check_naming` 仍 0）。
- **验收**：`grep type_for\|signature_of scripts/` = 0；`verify.sh` 全绿（312 测试 / 3216 断言）；`check_naming` 0。
- **文档**：`CONTENT_GUIDE` 增「弹型实例复用」规则；plan §16.1 度量与 M2 段标记完成；基线融合 bullet 更新为「余 M3」。
- **没做**：`_texture_by_index`（M3）+ `_port_by_sig`（端口收口）仍在；桥接仍认识 `BulletData`（理想 0 属后续）。

### 2026-09-13 — 减法批次 A2c：局部极短名收敛（N19）+ ctx 门面拍板保留

- **拍板**：`ctx.*` 意图门面**不动**（契约 §3 的动词域）；N19 的局部极短名**要清**，但工作台自身本地名不动。
- **改名（非工作台）**：`sd`→`stage_data`；`st`→`stage`（关卡号）/ `behavior_state`（内核行为状态）；`bm`→`bullet_manager` / `bookmarks` / `manager`；`bg`→`background` / `stage_background`；`tl`→`timeline`。
- **隐藏契约**：`tl` 是书签提取器 `bookmark_extractor.gd` 正则 `tl\.at(` 的被扫描对象 —— 内容改名必须**连带把正则改为 `timeline\.at(`**，否则书签静默失效。这是唯一必须碰工作台的一处（2 行正则），其余工作台本地名未动。
- **踩坑**：正则替换 `\btl\b` 漏掉了转义字符串里的 `\ttl.at(`（`tl` 前一个字符是 `t`，无词边界）→ `test_bookmark_extractor` 的 fixture 源码没改到，测试失败。**字符串字面量里的标识符要单独处理。**
- **验收**：`check_naming` 0 条；`check_syntax` 191/0；GUT 311 测试 / 3216 断言全绿。
- **写给未来**：用户指出终局是用 GDExtension 实现系统内核 + 弹幕机制 VM —— 届时现在这些宿主侧的改名/适配成本会大幅消失。

### 2026-09-13 — 减法批次 A2b：公开状态字段也不豁免缩写（拍板）

- **决定**：命名契约的缩写白名单**对公开字段同样生效**，不再走「公开字段允许角色名」的旧豁免。
- **改名**：`refs`（所有 EntityRegistry 字段/属性）→ `entity_registry`；`BulletService.world` / `KernelBomb.world` / `KernelBulletBackend.world` → `bullet_manager`；`StageRuntime.bullets` → `bullet_manager`；`BulletManager.world_refs` → `entity_registry`；`inject_world_refs()` → `inject_entity_registry()`（连带 `HitboxOverlay` / `DebugDrawer` 的 `bullets` 字段）。
- **唯一豁免**：`ctx.*` 意图门面（`ctx.bullets` / `ctx.player` / `ctx.audio`…）—— 契约 §3 定义的动词域，不是随手缩写，本批**故意不动**。
- **踩坑**：`.bullets` 的调用点改名后，忘了改声明方（`HitboxOverlay.bullets`）→ 运行期 `Invalid assignment ... on HitboxOverlay`。**全局 replacement 后必须复查"声明方 vs 调用方"配对。**
- **验收**：`check_syntax` 191/0；GUT 311 测试 / 3216 断言全绿。
- **剩余**：局部极短名 `sd`/`st`/`bm`/`bg`/`tl`（TODO N19）——其中 `tl` 与书签提取器正则 `tl\.at(` 有隐藏契约，改名要连带。

### 2026-09-13 — 减法批次 A2：命名收敛（check_naming 91 → 0）

- **动机**：读代码时同一个东西要在脑内查映射表 —— `_refs`/`_world_refs`、`_bullets`/`_kernel`、`p_ctx`/`_ctx`、`hitpoint_display`、`$UI`/`_game_ui`。这是「不明晰」的物理来源。
- **做法**：按基线《标识符命名契约》机械改（一次性脚本 + 占位符，避免 A→B 再被 B→C 连锁替换）：
  - 私有字段 → `_<类型snake>`；同类型多实例用 `_<限定词>_<类型snake>`（`_move_coroutine_runner` / `_final_boss_data`）。
  - `@onready` → `_`+节点名 snake；节点名太弱（`UI`）则改节点为 `GameUI`；非 PascalCase 节点 `logo`/`roll`/`roll2` → `Logo`/`Roll`/`Roll2`。
  - 参数 `sys` → `system`（宿主侧）。
- **修正 linter**（否则契约自相矛盾）：`tools/check_naming.sh` 现在 ① 排除 `scripts/kernel/**`（vendor 快照）；② 接受「限定词_类型snake」；③ 同类型多名称组仅在存在非类型名时报错。
- **踩坑（必须记）**：脚本化重命名**不能只改声明文件** —— `_tl` 被协程子类 `enemy04.gd` 与 `perf_stress/verify_fix.gd` 直接读；`_current_phase`/`_ctx`/`_shoot_script`/`_runner` 被测试白盒访问；`$UI` 的 tscn 子节点 `parent="UI/..."` 漏了一处 → `Memory/OutlineRect` 找不到。**改名 = 改声明 + 全仓 grep 外部私有访问 + tscn NodePath。**
- **验收**：`check_naming` **0 条**（原 91）；`check_syntax` 191/0；`verify.sh` 全绿（311 测试 / 3216 断言）；`main_menu` + `red_YY_jade` 场景 headless 启动零错误。
- **没做（有意）**：公开角色名（`ctx.refs` / `BulletService.world`）按契约保留；内核内部命名（`behavior_processor._system` 等）随重建版走，不在宿主改。

### 2026-09-13 — 减法批次 A1：清考古注释（188 行 / 77 文件）

- **动机**：指标全绿，但读感不干净 —— 代码里写满 `W4a-2 / K4 / S4c-1 / §21.17 / Track A / Strangler` 这类改动史标签，读起来像考古报告，不像「它本来就是这样」。
- **做法**：一次性 Python 脚本，只动 `#` 注释（跳过字符串与 `code span`），删历史 tag / 日期 / § 引用并清残留标点；`scripts/kernel/**`（vendor 快照）**不动**，否则 `vendor_kernel.sh --check` 会报漂移。再人工修 10 处残留（`bullet_multi_mesh` 头注释、`game_scene` 的 `/R21`、`kernel_bullet_backend` 的 `见 docs`、若干测试断言消息里的 tag）。
- **量化**：188 行注释 / 77 文件；非内核脚本历史 tag 归零；`bullet_multi_mesh` 头注释不再描述已删除的第二条数据路径（关闭 TODO N18）。
- **原则**：**注释只描述「现在是什么、为什么」，「改了什么」归本 LOG。** 代码文件不该承担 changelog。
- **验收**：`check_syntax` 191/0；GUT 全绿；未改任何代码行（纯注释）。

### 2026-09-13 — P2：三个 `static var current` 生产侧收口 + 内核 RNG 跟随宿主 seed

- **目标**：让 `BulletManager` / `StageRuntime` / `EntityRegistry` 的 `.current` 静态不再被**游戏运行时**读取，把「当前世界」从隐式全局改为组合根显式登记 / 注入。
- **为什么**：R8 允许 `static var` 替代部分单例，但运行时跨模块读全局会隐藏依赖，并制造「双世界静默抢登记」（C4）；R2 的正确形态是组合根注入（`ctx.stage`）。
- **落点**：
  - `StageContext`：`bullets` / `effects` / `refs` 三个 getter 去掉 `.current` 回退，只认绑定的 `stage`；无 stage 的 ctx（自机射击 / 共享子弹 ctx）改由宿主显式绑 stage。
  - `SaveData.reset_all/reset_practice(refs)`：注册表由组合根显式传入（`PlayerResources` 仍是唯一 owner）。
  - `SceneTransition.change_scene()`：改收 `on_pause_world` / `on_clear_world` / `on_resume_world` 回调；`GameManager` 新增 `register_world/unregister_world` 显式登记 `world_bullets/world_refs`，不再读 `.current`。
  - `StageRuntime._enter_tree`：**首个赢**（`is_instance_valid` 判定，不无条件覆盖）；`_exit_tree` 对称清 `EntityRegistry.current`。
  - **C5**：`RNG` 增 `seed_changed` 信号，成为**唯一随机真源**；`BulletManager` 监听并把 seed 同步给内核 `BulletSystem`（内核自带 RNG = 同 seed 的派生镜像，宿主侧无人调用它）。
- **工作台 / 调试**：benches 改用自己的 `_bullets`；`creation_station` 从 `_view` 取 `_bullets/_stage_runtime`；`hitbox_overlay` / `debug_drawer` 改注入 `bullets/refs`。`.current` 只剩「写 + 工具/测试」用途（注释已标明）。
- **新接口**：`Player.bind_ctx()`、`BulletManager.inject_stage_runtime()`、`GameManager.register_world/unregister_world()`、`RNG.seed_changed`。
- **验收**：`check_syntax` 191/0；GUT **全绿**（新增 `test_kernel_rng_follows_host_seed`）；`vendor_kernel.sh --check` 漂移 0；`game_scene` + 5 个 workbench 场景 headless 启动零错误；`check_naming` 仍 91（无新增）。
- **没做 / 有意保留**：`static var current` 未物理删除 —— 测试（`test_kernel_swap` / `test_creation_station` / `test_laser` …）与工作台仍以它为便捷入口；生产路径已清零。彻底删除需先让这些用例显式持有实例，属后续纯清理。

### 2026-09-13 — M1：内核认数据（damage / hit_sfx 进 BulletType，tag kernel-v2）

- **做了什么**：内核 `BulletType` 增 `Host payload` 组：`damage: float` / `hit_sfx: StringName`（**只存不解释**，规则仍归宿主）→ 原项目删掉 `_damage_by_index` / `_hit_sfx_by_index` 两张侧表与 `damage_for_index()` / `hit_sfx_for_index()`，`KernelBulletPhysics` 改读 `bt.damage` / `bt.hit_sfx`。
- **流程（M 线首次走通）**：重建版改 + `tests/` **46 套 / 689 断言全绿** → tag `kernel-v2`（`4f49df1`）→ `bash tools/vendor_kernel.sh` 同步（只有 `bullet_type.gd` +7 行）→ 原项目适配层改 → `check_syntax` 191/0 + GUT **57 / 310 / 3215 全绿**。
- **踩坑（必须记）**：`signature_of()` 是**「内容签名 → 弹型」的缓存键** —— `damage` / `hit_sfx` 既已成为弹型字段，就**必须进签名**，否则"同贴图同判定、只有伤害不同"的弹会共用同一个缓存弹型 → **伤害串味**。已补 `hash(data.damage)` / `hash(data.hit_sfx)`。
- **量**：内核 1212 → **1219** 行；桥接 979 → **964** 行；`scripts/kernel_bridge/` 里 `_by_index` 只剩 `_texture_by_index`（属 M3）。
- **测试口径同步**：`test_player_bullet_damages_enemy_via_damage_side_table` → `..._via_bullet_type`，断言消息改「伤害应来自 BulletType.damage」——不留与实现不符的测试名。
- **没做**：`out_grace` 仍暂缓（bomb 走宿主节点，用不到）；纹理旁表留到 M3。

### 2026-09-13 — M0：修 vendor 漂移 + 立 vendor 脚本（融合前置）

- **发现**：`scripts/kernel/` 副本与上游（重建版 tag `kernel-v1`）漂移 **4 处**，**全是本地改了、上游没同步**：K1 的 `avoid_player.gd → avoid_player_behavior.gd`（文件名）、K7 的 `FxLayer → FxPool`（注释）、A10 的 `bullet_data → bullet_type`（形参）、A11 的行尾空白。README 担心的「单一真相会烂」**已经在发生** —— 下次 vendor 会把它们覆盖回去，文件名还会变成"两个文件"。
- **M0a**：前 3 处同步回重建版上游并跑其 `tests/`（46 套）全绿；第 4 处不写回上游，交给 vendor 规范化。
- **M0b**：新增 `tools/vendor_kernel.sh` —— 复制上游 + 两处规范化（删 `BulletRenderer` 注入 / 去行尾空白）+ 「内核 0 宿主引用」守卫（去注释后正则；`LayerConfig` 是唯一豁免，不在名单里）+ `--check` 报漂移。`.uid` 属项目本地（`uid://` 指向本工程），不参与 vendor，只清孤儿。
- **坑**：重建版改名后 `behavior_processor_test` 挂 `Could not find script for class "AvoidPlayerBehavior"` —— 全局类缓存 `.godot/global_script_class_cache.cfg` 还指着旧路径；`godot --headless --editor --quit` 重建后全绿（K1 同款教训，已写进 `scripts/kernel/README.md`）。
- **验收**：`bash tools/vendor_kernel.sh --check` → 漂移 0 + 守卫 ✅；重建版 46 套全绿；原项目本轮只加脚本与文档，GUT/语法不受影响。

### 2026-09-13 — 决策：内核融合（M1–M3）—— 结束 Strangler，转向「一套架构」

- **决定**：不再维持「内核冻结 + 宿主侧适配」。进入**融合**；终局按 `scripts/kernel/README.md` 的既定约定 —— **原项目成为内核唯一之家、重建版归档**。
- **度量（为什么是现在）**：`scripts/kernel_bridge/` **979 行 ≈ 内核 1212 行的 80%**；弹型词汇两套（`BulletData` 19 字段 vs `BulletType` 13 字段，**差集恰好是桥接的活**）；5 张侧表；6 个内容脚本手写 `kernel_port()`。桥接现在**同时干两件事** —— 宿主耦合规则 + 词汇翻译 —— **后者才是 979 行的大头**。
- **为什么能反转 A 方案**：S3 选 A（§14.3）是为了保住「内核零改动」这个**可回退前提**；如今 Track A/B 收口、`use_kernel` 与旧池都删了、GUT 57 套兜底 —— 可回退的收益已经兑现，继续冻结的代价超过收益。
- **路线**（详见 §16）：
  - **M1** 内核认数据：`damage` / `hit_sfx` / `out_grace` 进 `BulletType` → 删 `_damage_by_index` / `_hit_sfx_by_index`（**只搬数据不搬规则**，graze / 命中几何仍留宿主）。`out_grace` 正好兑现 §15.5 留的口子。
  - **M2** 词汇合一：`BulletData` ⇄ `BulletType`（(a) `extends` / (b) 退化为构造助手，**待拍板**）→ 删 `type_for()` / `signature_of()` / `_type_by_sig`；`kernel_port()` 降为可选覆盖。
  - **M3** 渲染 / 纹理归属（hybrid vs 内核图集）—— 先决策，不阻塞 M1/M2。
- **流程（硬约束）**：内核改动**必须回重建版做**（那是它的开发环境）→ 跑重建版 `tests/` → 打 tag `kernel-v2` → vendor 回来。**禁止**只改 `scripts/kernel/` 副本（README 明写它只是 vendor 快照，会被覆盖）。
- **融合完成判据**（§16.5，可 lint）：桥接 ≤300 行且无类型映射/侧表、`_by_index` = 0、`kernel_port` = 0、桥接里 `BulletData` 显著下降、内核仍 **0 宿主引用**。
- **不做**：L2 壳合一（把内容搬进重建版）≈ big-bang，决策备忘已否决。
- **前置发现（M0）**：实测 `scripts/kernel/` 副本已与上游漂移 **3 处**，而且**全是本地改了、上游没同步** —— K1 的 `avoid_player.gd → avoid_player_behavior.gd`（文件名）、K7 的 `FxLayer → FxPool`（注释）、A10 的 `bullet_data → bullet_type`（形参）。下次 vendor 会**覆盖回去**（文件名甚至出现两个文件）→ 先做 M0（同步 + 写可复现的 `tools/vendor_kernel.sh`）。
- **对命名的连带影响**：N17（`KernelBulletBackend → KernelBulletBridge`）**暂缓** —— 类名该叫什么取决于融合后它缩成什么样；等 M1/M2 落地再定，避免 42 处白改。

### 2026-09-13 — P0-7：标识符命名契约 + 命名 lint（N15 / N16）

- **背景**：A17 的命名复查发现「同一概念不同名」成片，根因和 A17 一样 —— **基线 / ARCHITECTURE 从未定义代码内标识符的命名规则**（R15 只管文件/文件夹/节点的大小写）。
- **骨架（用户定）**：引用类变量名 **= 类型名 snake**；**节点名与变量名不符 → 有一方要改**；除极常见缩写外**不缩写**。
- **落点**：基线新增「**标识符命名契约**」，与注入契约 / 命名边界契约并列。补了原方案没覆盖的 6 类（集合·映射 / 布尔 / 回调 / preload 常量 / 函数动词 / ``@onready``），并加了**从 lint 结果反推出来的例外**：
  - **公开字段/属性 = 角色名允许**（`ctx.bullets` / `ctx.player` / `ctx.stage`）—— 它们是对外 **API**（ARCHITECTURE §3 意图层）；硬套类名会把 `ctx.bullets.shoot_spread` 变成 `ctx.bullet_service.shoot_spread`，**破坏内容与文档**。判据：**名字出现在内容（`data/**`）或文档里 → 角色名**。
  - 内置基类类型（`Marker2D`）**节点名赢**；只有**私有**字段才套「类型→名」。
- **工具**：`tools/check_naming.sh`（默认只报告，`--fail` 交 CI）四组：① 私有字段名 ≠ `_`+类型snake；② 同类型多个私有字段名；③ ``@onready`` 变量名 ≠ 节点名；④ 节点名 PascalCase。
- **实测**：253 脚本 / 127 自定义类型 → **应改 91 条**（私有字段 67 / 多名称类型 13 / 节点引用 8 / 节点名 3）；公开字段·属性 70 条（角色名，放行）。
- **为什么值得**：这条规则**可机械校验** —— lint 一进 CI 就再也不会漂回「同物不同名」。
- **验收**：`bash tools/check_naming.sh` 报告正常（默认 exit 0）；本轮**未改任何 `.gd`**，check_syntax / GUT 不受影响。

### 2026-09-13 — P0-6：注入契约落进基线 + world_refs 收口（A17）

- **背景**：复查 A17 发现 **基线 / ARCHITECTURE 从未定义「注入槽怎么写」**（R2 只写「依赖由父级/上下文向下注入」），于是长出**三种写法**：方法注入（`setup()`/`inject_*`）、裸 public var、只读属性 + `inject_*`。
- **关键约束（决定方案的那条）**：`.tscn` → ``@export`` 节点引用在 Godot 4.7 **不解析成节点**（K4 实测后回退，LOG:190）→ 「声明式接线」对**节点依赖**不可用；R21 只覆盖**建树**。所以注入只能走代码，不能照搬「Godot 惯用」。
- **落点**：`docs/BEST_PRACTICES_BASELINE.md` 新增「**注入契约（组合根 → 场景节点）**」，与帧序/层序/命名边界契约并列，按「**写入是否需要副作用**」二分：
  - 需要（转发子模块 / 重建装配 / 校验 / 统一断开）→ **只读属性 + `inject_*()` / `setup_*()`**，方法即唯一写入口；
  - 纯赋值 → 允许**裸 public var**，但必须 `##` 注明「组合根注入」。
- **收口**：按规则唯一偏离 = `BulletManager.world_refs`（只被 `inject_world_refs()` 写、且写它有 `_enable_kernel()` 副作用，却仍挂着裸 var 写入口）→ 改 `_world_refs` + 只读属性，与 `fx_pool` 对称。
- **验收**：`check_syntax` 191/0；全量 GUT 57 套 / 310 / 3215 全绿。
- **顺带（命名审计）**：复查命名时发现「**同一概念不同名**」成片（`EntityRegistry` = `refs`×8 vs `world_refs`×1；`BulletManager` 实例 = `world` vs `bullets`；`BulletSystem` = `system`×16 vs `sys`×3；`StageContext` 参数 = `p_ctx`×21 vs `_ctx`×20 vs `_p_ctx`×1；`StageData` = `sd` / `current_stage` / `_stage_data`）→ 已单列为 TODO 的 **N 组**（8 条）。

### 2026-09-13 — P0-5：shoot_spread 定契约 + 删 spawn_bullet（A6）

- **问题**：`BulletService.shoot_spread` 不声明返回类型，三条 return 路径给两样东西（`count==1` → int 行 id；`count>1` / 不活跃 → null），注释还写着已消失的「旧池 = Bullet 节点 / 用前先 `is Bullet` 判断」。
- **实测**：17 个调用点 / 12 个文件，**全部丢弃返回值**（赋值 / return / assert 命中 0）。
- **决定**：改 `-> void` —— 它的语义是「打一波扇形」，不是「取一颗弹」；让 spread 兼职返回单发 id，只会逼调用方**靠 count 猜类型**。将来真要那颗弹的 id，另开语义明确的 `shoot_one(...) -> int`，不要复用 spread。
- **顺带**：删 `StageRuntime.spawn_bullet`（**0 调用者**，注释同样是过期的「旧池 = Bullet」）—— 与 A16 同一种死法。
- **验收**：`check_syntax` 191/0；全量 GUT **57 套 / 310 / 3215 全绿**。

### 2026-09-13 — P0-4：fx_pool 单写入口（setter）/ set_state 去双名 / 行尾空白清零（A3 / A12 / A11）

- **A3**：`BulletManager.fx_pool` 从「public var + `inject_fx_pool()`」双写入口改为**只读属性 + 私有后备**（`_fx_pool` + `var fx_pool: FxPool: get: return _fx_pool`），唯一写入口 = `inject_fx_pool()`；顺带删掉 `_ready` 里那句冗余自注入（`_enable_kernel()` 已把 fx_pool 灌给 `_kernel_physics.fx`）。
  - **为什么是 setter 而不是删 setter**：setter 不只赋值，还要**转发给子模块**（`_kernel_physics.fx`）——删了它，调用方就得知道内部结构；只读属性则让「外部硬写」直接编译不过。
- **A12**：`GameManager.set_state` / `_set_state` 双名合一 —— 删私有壳，函数体搬进 `set_state`，内部 2 处调用改走它。
- **A11**：清掉 `scripts/**` 全部行尾空白（**183 行 / 31 文件**）。**同时更正上一条记录的错误**：`_spawn_fx` / `_render_fade` 本来就是 `Dictionary = {}`（有显式类型、无尾随空格）—— 原判断是我自己 `sed` 过滤掉了 `{}` 造成的误读。
- **为什么**：R5（接口类型化）+ R6（对外接口说实话）+ R19（同一件事只有一个入口）。「同一依赖两种注入风格」会让组合根越写越像约定、而不是机制。
- **验收**：`check_syntax` 191/0；全量 GUT **57 套 / 310 / 3215 全绿**（行尾空白纯机械改动，零行为变化）。
- **已知遗留**：`StageRuntime` 的注入槽（`bullets` / `world` / `miss_layer` / `fx_pool` / `ui_layer`）仍是**裸 public var**（`game_scene.gd` 直接赋值），与 `BulletManager` 的 setter 风格不统一 → 记为 A17（统一前得先定「槽用只读属性还是 inject 方法」）。

### 2026-09-13 — P0-3：删掉无调用者的 return_bullet / re_fire（A16）

- **目标**：A15 类型化后暴露的「typed 但没人调」公开 API 收尾 —— `BulletManager.return_bullet` / `re_fire` 与 `BulletService.return_bullet` / `re_fire` 一起删。
- **为什么**：内核行为走 `KernelBehaviorHost.request_despawn` / `queue_spawn`（延后队列 + `BulletSystem.despawn`），宿主侧「按 handle 回收 / 原地重发」这条 API 已无存在理由；留着只会让人以为别处在用（R19）。
- **验收**：`check_syntax` 191/0；全量 GUT 57 套 / 310 / 3215 全绿；净 -23 行。
- **注**：`docs/NEW_KERNEL_REFACTOR_PLAN.md` §5 的 adapter 清单仍列着这两个名字 —— 那是 Phase 1 的历史设计（当时旧池还在），按「方案/决策不动」原则不回写。

### 2026-09-13 — P0-2：删掉 5 处旧池协程残体 + 类型化 return_bullet/re_fire（A14 / A15）

- **目标**：把卡住 A7/A8 的东西清掉 —— 5 处内容脚本仍留着「旧池 `Bullet` 节点」时代的协程体，把 `Node2D` 传给 `return_bullet` / `re_fire`。
- **做了什么**：
  - `data/stages/stage01/bullet/bounce_bullet.gd`：删 `_tick` / `_bounce_and_split` / `_re_fire` + 死变量 `spawn_tex` / `spawn_color`，只留 `kernel_port` + 工厂。
  - `data/stages/stage01/bullet/radial_accel_bullet.gd`：删 `_tick` / `_spawn_downward` / `_dir`。
  - `data/stages/stage01/phase/non_mid01/non_mid01_bullet.gd`：删 `_tick` / `_tick_travel` / `_tick_flee` / `State` / `_state` / `_flee_dir` / `_skip` / 死常量 `RING_COUNT`。
  - `data/stages/stage03B/phase/spell03/orbit_probe.gd`：删 `_tick` / `_spawn_split` / `State` / `_state` / `_dir0` / `_dist` —— 它**没有**内核端口（§15.1「本轮不做」），现在只剩参数 + 明确的「未映射即直线」说明。
  - `scripts/coroutine/player/marisa_laser_follow.gd`：删 `start()` 覆写 / `FADE_TIME` / `_drift` / `_fading` / `_fade_t`（漂移与渐隐在内核桥接里）。
  - 删 `test/perf_stress/verify_laser.gd` + `.gd.uid` + `.tscn`：它 `start_fast()` 的正是被删的旧 `start()` 体，留着就是「验证一个已经不存在的行为」。
  - **A15**：残体删完后，给 `BulletManager` / `BulletService` 的 `return_bullet` / `re_fire` 参数补 `int`，并删掉 `typeof(bullet) == TYPE_INT` 的后端残渣。
- **为什么**：R19（不留死代码）+ R5（类型化）+「没有第二后端就别演双后端」。死代码的代价不是占行数，而是**掩盖真相** —— 这次就是类型化把 5 处幽灵调用点照了出来。
- **验收**：`check_syntax` **191/0**；全量 GUT **57 套 / 310 测试 / 3215 断言全绿**。
- **踩坑（显示名）**：改头部注释时顺手改了 `non_mid01_bullet` 的首行注释 → `test_content_catalog`「超长名截断带省略号」挂一次。`ContentCatalog._short_name` 的规则是：**取首行注释**，有「：」取冒号后按 18 字符截断，无则整行按 24 字符截断 —— 这类脚本改文档头**必须保留首行**（其余 4 个文件同样按原首行恢复）。
- **顺带发现**：删完 5 处调用点后，`return_bullet` / `re_fire` **已无任何调用者**（内核行为走 `KernelBehaviorHost` 的 `request_despawn` / `queue_spawn`）→ 记为待办 A16（删除，或明确标为公开 API）。

### 2026-09-13 — P0-1：清理"说谎的 API"（A1 / A2 / A4 / A5 / A9 / A10 / A13）

- **目标**：去掉一批「名字或返回值与语义不符」的公共 API（代码体检 P0 组的一部分）。
- **做了什么**：
  - `BulletManager`：三个**函数体完全相同**的 `shoot_bullet` / `shoot_player_bullet` / `shoot_enemy_bullet` 合成一个 `shoot_bullet(data, pos, dir) -> int` —— 阵营本来就由 `data.faction` 决定，**自机弹与敌弹走的是同一条路**（原名字在撒谎）；`clear_enemy_bullets_in_circle` 的 `-> int`（永远 `return 0`）改 `-> void`；删 `refresh_kernel_player()` 别名（0 调用）。
  - `SceneTransition.change_scene`：删死参数 `_on_scene_entered`（收了从不调用，`GameManager` 还把 `scene_entered.emit` 传了进去）；调用方同步。
  - `StageRuntime.spawn_boss`：`-> Node` → `-> Boss`（与 `spawn_enemy_data -> Enemy` 对称，调用方不再需要 `as Boss`）。
  - `BulletSystem._type_registry_index_of`：参数名 `bullet_data`（实际是 `BulletType`）→ `bullet_type`。
  - `EntityRegistry.get_boss`：`enemy.get_script() == BossScript` → `enemy is Boss`（删 `BossScript` preload），返回类型补 `-> Boss`。
  - `shoot_bullet` / `shoot_bomb_bullet` 参数补类型（`data: BulletData` / 返回 `Node`）。
- **为什么**（对应红线）：R5（引用类型化）、R6（对外接口必须说实话）、R19（DRY——重复函数体是复制粘贴）。API 名与语义不一致会让人绕过类型系统，是"看着整齐、其实不干净"的典型。
- **验收**：`check_syntax` **191/0**；全量 GUT **57 套 / 310 测试 / 3215 断言全绿**（与清理前逐字一致 → 零行为改动）。
- **踩坑（阻塞发现）**：给 `return_bullet` / `re_fire` 参数补 `int` 时**编译失败**：`marisa_laser_follow.gd:80` 等 **5 处**仍把 `Node2D` 传进来，而 GDScript 对 `Node2D → int` 是**编译错误**（不是警告）。
  - 这 5 处**不是活代码**：`BulletData.coroutine_script` 现在只用来取 `kernel_port()`，内核路径**从不启动弹的协程**；它们是 W4a-2「删旧池」时漏掉的内容脚本残体（`marisa_laser_follow.start` / `bounce_bullet._re_fire` / `radial_accel_bullet._spawn_downward` / `non_mid01_bullet` 旧体 / `orbit_probe` 旧体）。
  - **教训**：类型化"幽灵 API"会顺手把死代码照出来 —— 先删残体（A14），再类型化（A15）。本轮先回退这两处类型化，避免为了面子留下编译不过的代码。
- **没做什么（刻意）**：`fx_pool` 双入口（A3）、`shoot_spread` 无返回类型（A6）、`_spawn_fx/_render_fade` 空白（A11）、`set_state` 双名（A12）—— 留待后续。

### 2026-09-11 — K14：动作型总闸静默空跑守卫（reset_* 出声）

- **背景**：全项目审计「无日志 guard return」——`scripts/` **449 处**，依赖类 **107**，P0-ish **18**；但绝大多数是合法控制流。真正值得出声的是**「动作型总闸在依赖缺失时空跑」**（K13 教训）。
- **做法**：`SaveData.reset_all` / `reset_practice`：若 `refs != null` 但 `res == null` → `push_warning("…重置空跑")`。
- **刻意不加**：全量 449 处；以及 3 处 P1 —— `asset_registry.get_bgm_title`（返回 `""` 合法）、`audio_manager.play_sfx`（无播放器合法）、`game_ui._update_fragments`（注入前被调正常，会误报）。
- **判据（写进基线）**：P0 动作型空跑 → `push_error/push_warning`；P1 配置缺失可恢复 → `push_warning`；P2 getter 返回 null / 可选服务 / `is_instance_valid` → 不加。
- **验收**：`check_syntax` **191/0**；全量 **57 套 / 310 测试 / 3215 断言全绿**；orphans 10；无告警刷屏。
### 2026-09-11 — K13：练习模式残机/bomb 未归零（reset_* 早于 bind_player）

- **现象**：符卡练习里残机/bomb 不是 0（`PlayerResources.reset_practice` 本应设 `lives=0/bomb=0/power=300`）。
- **根因**：`GameScene._ready` 顺序是 `SaveData.reset_practice()` → `_setup_player()`；而 `reset_*` 经 `EntityRegistry.current.get_player_resources()` 取自机资源，此时 `refs.player` 尚未 `bind_player` → 返回 null → **空跑**。
- **为什么普通关卡没暴露**：新 `game_scene` 每次新建 `Player`（`PlayerResources` 默认 2/3），`reset_all` 空跑也看不出；练习的「0/0」是显式覆盖才暴露。
- **修复**：两个分支都改为**先 `_setup_player()`（绑定自机）再 `reset_*`**。
- **回归测试**：`test_practice_mode.gd` —— `start_practice` 后实例化 `game_scene`，断言 `lives=0 / bomb_count=0 / power_raw=300`。
- **教训**：静态 `reset_*` 经注册表间接取资源，调用顺序必须晚于注入；K10 惰性 `resources` 后更凸显「先绑定后重置」。
- **验收**：`check_syntax` **191/0**；全量 **57 套 / 310 测试 / 3215 断言全绿**；orphans 10。
### 2026-09-11 — K12：符卡练习未启动诊断守卫（纯诊断，不改行为）

- **背景**：符卡练习里 `game_scene._ready` 未走 `_start_practice_game`；已知 `练习: ...` 打印出现（`start_practice` 已执行），故怀疑 `is_practice_mode` 在 `_ready` 前被清。
- **改动**：
  - `spell_practice_menu._start_practice`：3 处静默 `return` 加 `push_warning`（未选阶段 / 难度表空 / 难度未解锁）。
  - `game_scene._ready` 的 `else` 支：若 `practice_phase != null` 却走普通关卡 → `push_warning`（抓「练习标志被提前清除」）。
- **诊断结论（待复现确认）**：`is_practice_mode=true` 时 `_start_practice_game` 必执行（临时 GUT 实测：Boss 生成、标志保持）。
- **验收**：`check_syntax` **191/0**；全量 **56 套 / 309 测试 / 3211 断言全绿**；orphans 10。
### 2026-09-11 — K11：MenuNav 子页面容器改为注入（去 current_scene 名字搜）

- **目标**：`MenuNav._find_or_create_host` 靠 `current_scene` 子节点名字字符串 `"PageHost"` 找容器（R2/R5），并会命令式建节点挂到场景（R21），类型也不安全（`Node`→`Control`、`_parent` 兜底）。
- **做法**：
  - `MenuNav` 新增 `_host` + `set_page_host()/has_page_host()`；`push()` 用注入的 host，未注入 → `push_error` 拒绝；**删掉 `_find_or_create_host`**（连带 `_parent` 类型错误的兜底）。
  - `GameManager.set_page_host()` 转发；`MainMenu._ready` 注入 `%PageHost`，`_exit_tree` 解除。
  - `main_menu.tscn` 的 `PageHost` 标 `unique_name_in_owner`。
  - 新增 `test_menu_nav.gd`：无 host 时 `has_page_host()` false；注入后 push 成功且页面挂在 host 下。
- **度量**：`MenuNav` 里 `current_scene` + 名字遍历 + 运行时建节点 **1 处 → 0**。
- **验收**：`check_syntax` **191/0**；全量 **56 套 / 309 测试 / 3211 断言全绿**；orphans 10。
### 2026-09-11 — K10：Player.resources 惰性属性化（去 _ready 判空自建）

- **目标**：`Player._ready` 里 `if resources == null: resources = PlayerResources.new()` 是「owner 自建 + 允许预注入」的防御分支，但生产从不预注入 → 条件恒真，读起来像有注入却在 `_ready` 才建。
- **做法**：`resources` 改为**惰性属性**（私有后备 `_resources`；getter 首次访问自建，setter 保留预注入）；删 `_ready` 判空自建。
- **顺带**：`_on_enemy_killed` / `_physics_process` 的 `if resources != null` 守卫（惰性属性下恒真）去掉。
- **效果**：`resources` 任何读取都保证非 null（入树前读也安全）；`_ready` 更干净；测试桩预注入仍可用。
- **验收**：`check_syntax` **191/0**；全量 **55 套 / 308 测试 / 3207 断言全绿**；orphans 10。
### 2026-09-11 — K9：PlayerShootScript 资源读取去字符串旁路（R5）

- **目标**：`PlayerShootScript._sync_options` 用 `leader.get("resources")` 字符串访问取火力值，是 `PlayerResources` 唯一不走类型化/总闸的读取。
- **做法**：`_sync_options(leader: Node2D, ...)` → `_sync_options(leader: Player, ...)`（调用方本就传 `Player`：`ctx.player.get_player()`）；`leader.get("resources")` → `leader.resources`（类型化直接读）。
- **效果**：`scripts/**` 里 `.get("resources")` 仅剩 `EntityRegistry.get_player_resources()` 这一个总闸（`entity_registry.gd:43`），旁路**归零**；去掉一处 unsafe 动态属性访问。
- **验收**：`check_syntax` **191/0**；全量 **55 套 / 308 测试 / 3207 断言全绿**；orphans 10。
### 2026-09-11 — K8：Player 机体初始化去重（setup_character 幂等）

- **目标**：`Player._ready` 与 `GameScene._setup_player` 各调一次 `apply_player_data()`（+`reinit_shoot`），选默认机体时白装两遍；收敛成幂等单入口。
- **做法**：新增 `Player.setup_character(data)`（应用数值 + (重)装配射击；`data == player_data and _shoot_script != null` 时跳过）；`_ready` 改调 `setup_character(player_data)`；`GameScene._setup_player` 的 `player_data=; apply_player_data(); reinit_shoot()` 三行改为 `player.setup_character(选中)`。
- **效果**：默认机体（灵梦）**零重复**；非默认机体仍有一次自举浪费（一次 apply + 一套脚本建/拆，无害）。`apply_player_data`+`reinit_shoot` 由「恒成对调用」收成一个公开入口（R19/R6）。
- **为什么之前会两次**：Godot 子 `_ready` 先于父 `_ready`；`Player` 在 `game_scene.tscn` 声明，组合根只能在 `Player._ready` 之后覆盖运行时选中的机体。
- **测试**：`test_player` 加 2 例——同机体 `setup_character` 不重建射击脚本 / 换机体重建且切换 `player_data`。
- **验收**：`check_syntax` **191/0**；全量 **55 套 / 308 测试 / 3207 断言全绿**；orphans 10。
### 2026-09-11 — K7：特效命名消歧（MissCircleLayer / FxPool）

- **目标**：`MissEffectManager` 与 `FxLayer` 名字都带 Effect/Layer，容易被当成重复；按各自**机制**改名消歧。
- **做法**：
  - `FxLayer` → **`FxPool`**（`scripts/effect/fx_pool.gd`）：它是**精灵特效节点池**（世界坐标，池化 `HitEffect`），不只命中——也放消弹/擦弹/敌人死亡。
  - `MissEffectManager` → **`MissCircleLayer`**（`scripts/effect/miss_circle_layer.gd`）：它是**全屏反色圈**（`CanvasLayer` + `miss_circle.gdshader`，屏幕空间），不是通用 miss 管理器。
  - 成员同步：`fx_layer` → `fx_pool`（含 `inject_fx_layer` → `inject_fx_pool`）；`game_scene.tscn` 节点名同步；测试文件改名。
  - 两个文件头各补一句「与对方的分工」。
- **度量**：易混命名 **2 → 0**；旧名在 `scripts`/`scenes`/`test`/`data` 残留 **0**。
- **对照旧项目**：旧 `HitEffectPool` / `MissEffectManager` 两个 autoload 名字都像「所有特效」，实际一个局部精灵池、一个全屏 shader 圈；现在**名字即机制**。
- **验收**：`check_syntax` **191/0**；全量 **55 套 / 306 测试 / 3203 断言全绿**；orphans 10。
### 2026-09-11 — K6：BulletManager 声明式化（R21 收尾）

- **目标**：`game_scene.tscn` 里最后一个在代码中 `new()` 的服务节点（`BulletManager`）改为场景声明，与 `FxLayer`/`StageRuntime`/`ItemPool`/`MissEffectManager` 一致。
- **做法**：
  - `game_scene.tscn`：`World` 下新增 `BulletManager`（`Node2D`）+ `unique_name_in_owner`；新增脚本 `ext_resource`。
  - `game_scene.gd`：`var _bullets` → `@onready var _bullets: BulletManager = %BulletManager`；删 `BulletManager.new()` / `name` / `add_child` 三行（注入逻辑不动）。
  - `test_composition_root.gd`：断言 `World/BulletManager` 存在、`rt.bullets` 与 `BulletManager.current` 均指向它。
- **行为核对**：子节点 `_ready` 先于父 `GameScene._ready`；`BulletManager._ready` 里 `_enable_kernel()` 回退的 `EntityRegistry.current` 已由 `StageRuntime._enter_tree` 设好 → 不空；父 `_ready` 再 `inject_world_refs` 覆盖为精确引用。行为等价。
- **度量**：`game_scene` 的服务节点 **1 个代码建 → 0**（全部 tscn 声明）。
- **没做**：`BulletManager` 内部子模块（`WorldClock`/`LaserEngine`/`MultiMesh`/`KernelBulletBackend`）仍代码创建——非独立子场景；workbench/BenchBase 的 `ensure_bullet_world` 自建逻辑另议。
- **验收**：`check_syntax` **191/0**；全量 **55 套 / 306 测试 / 3203 断言全绿**；orphans 10。
### 2026-09-11 — K0：基线再检查（按代码实测刷新）

- **目标**：把 `BEST_PRACTICES_BASELINE.md` 刷成「当前真值」——清过时引用、补实测数字、删假 TODO。
- **做法**：逐条实测（autoload 4、`grep GameState` 0、`find_child` 0、`has_method("_")` 0、`z_index` 26 处中 20 处走 `LayerConfig`、字符串 `get_node*` 19、gameplay 裸 RNG 0、`@tool` 3、assets 47MB…），据此更新：
  - S 表：S3 注入项 / S6·S12 去 `GameState`；证据改指内核 `KernelBulletPhysics`/`hit_geometry.gd`/`ScreenFogFX`。
  - TODO：删 R14（假：存档已 `user://`）；R3/R15/R16 改实测；新增 R2 残余与 R21。
  - 契约现状：层序「30 处散写」→「26 处 / 20 走 `LayerConfig` / 裸数字 5」；命名「77 中文文件名」→「中文 `.gd` 0；PascalCase 目录 + `diffculty` 5」。
  - 审计表整体重写（2026-09-11 实测），新增 R5/R16/R3/R12 行。
- **度量**：基线过时引用/数字 **~19 条 → 0**。
- **对照旧项目**：旧基线把「自评」当现状；现在每条都带可复现的实测数字。
- **验收**：纯文档改动（无代码变更）；`BEST_PRACTICES_BASELINE.md` + 审计表已刷新。
### 2026-09-11 — K5：workbench 热更新管线收口（R18/R19）

- **目标**：消除三台（弹幕/敌人/阶段）逐字复制的热更新管线（R19），缩小 workbench 上帝对象表面积（R18）。
- **做法**：把整条管线（`HOT_POLL_INTERVAL`/`HOT_DEBOUNCE`、`_watch_paths`/`_watch_mtimes`/`_hot_enabled`/`_hot_poll`/`_hot_dirty_since`、`_on_hot_toggled`/`_rebuild_watch`/`_refresh_watch_mtimes`/`_process_hot_reload`/`_do_hot_reload`、`_toast` 字段）上移到 `BenchBase`；新增三个 hook：`_collect_watch_paths()`（监听路径 + `_with_dir_scripts` 连坐扩展）、`_main_watch_path()`（主脚本）、`_on_hot_reloaded(main_new)`（重载后动作）。
- **度量**：热更新方法定义 **15 份 → 基类 5 + 三组轻量 hook**；workbench 净 **-116 行**（+172 / -288）。
- **对照旧项目**：旧三台各抄一份 mtime 轮询/防抖/连坐重载；现在差异只在「监听谁、重载后干什么」，公共管线单一来源。
- **踩坑**：`_do_hot_reload` 末尾的「已重载」toast 属函数体，收口时一开始漏搬 → `test_bullet_rig` 断言失败；补回后全绿（搬家要连函数尾部的副作用一起搬）。
- **验收**：`check_syntax` **191/0**；全量 **55 套 / 306 测试 / 3200 断言全绿**；orphans 10。
### 2026-09-11 — K3：R4 收口（输入事件驱动，去 _process 轮询）

- **目标**：菜单 / 暂停 / 自机离散键从 `_process`·`_physics_process` 的 `Input.is_action_just_pressed` 轮询改为 `_unhandled_input`（工程红线 R4）。
- **做法**：
  - `NavPage`：删 `_process`，新增 `_unhandled_input` + 可覆写 `_nav_directional`；确认/取消/移动抽成 `_nav_accept/_nav_cancel/_nav_move`（消 3 份复制，R19）。
  - `difficulty_screen` / `music_room_menu`：删各自 `_process`，只覆写 `_nav_directional`（左右 / 上下）。
  - `manual_menu`：`_process` → `_unhandled_input`。
  - `GameManager`：`ui_pause` 从 `_process` → `_unhandled_input`（仅 PLAYING 且无覆盖层）。
  - `Player`：`memory_release` / `cancel&bomb` 从 `_physics_process` 轮询 → `_unhandled_input`。
- **保留**：连续状态读取不算轮询边沿——移动 `get_axis`、focus/shoot 状态、`ReplayRecorder` 每帧记录、`DialogueBox` 长按计时。
- **度量**：`_process`/`_physics_process` 内边沿轮询 **6 → 0**；菜单导航逻辑复制 **3 → 1**。
- **对照旧项目**：旧菜单各页在 `_process` 轮询边沿、底层页被覆盖后仍会响应；现在统一 `_unhandled_input` + `set_input_as_handled()`（顶层页消费即止）。
- **验收**：`check_syntax` **191/0**；全量 **55 套 / 306 测试 / 3200 断言全绿**；orphans 10。
### 2026-09-11 — K4：R2 收口（全树搜 → 组合根注入）

- **目标**：清掉 `find_child()` 全树搜与 `get_node("..")` 字符串路径（工程红线 R2）。
- **做法**：
  - Boss 位置指示器：`Boss.ui_layer` + `StageRuntime.ui_layer` 注入槽；`GameScene` 设 `_game_ui`，`add_enemy_to_scene` 注入；删 `current_scene.get_node_or_null("UI")` + `root.find_child("UI")`。
  - 背景相机：`StageBackground._find_camera()` 只做父级 `Camera3D` 查找（父级是 SubViewport / BgViewport，真机两处都命中）；删 `current_scene.find_child("Camera3D")` 后备；`camera` 可组合根预注入，否则 `_own_camera()` 兜底。
  - 炸弹爆炸贴图：`BulletManager.fx_parent`（组合根注入 World）+ `KernelBomb.fx_parent`（backend 取 `world.fx_parent`）；删 `scene.get_node("World")`。
  - `stage01_decor`：`$".."`/`$"../X"` → `get_parent() as StageBackground` + `bg.get_node("X")`。
- **度量**：`find_child` **2 → 0**；`$".."`/`get_node("..")` **4 → 0**。
- **对照旧项目**：旧实现靠「全树搜名字」（Camera3D / UI / World），多实例 / 多视口下会撞名；现在依赖由组合根向下注入。
- **没做**：`main_menu._container.get_node("Extra Start"/"Spell Practice")` 保持原样——它是**场景内直接子级**查找（非 `".."`、非 `find_child`），不属 R2；曾试 `@export var x: Control` + tscn `NodePath` 声明式装配，但 4.7 下该序列化未解析为节点，遂回退。
- **验收**：`check_syntax` **191/0**；全量 **55 套 / 306 测试 / 3200 断言全绿**；orphans 10。
### 2026-09-11 — K2：R6 收口（私有调用 → 公开虚函数）

- **目标**：清掉生产代码所有**对外**调 `_私有` 与 `has_method("_")`（工程红线 R6）。
- **做法**：
  - 菜单生命周期：`BasePage._on_enter/_on_leave/_on_activate/_on_deactivate` → 公开虚函数 `on_enter/on_leave/on_activate/on_deactivate`（17 个页面覆写同步）；`MenuNav` 页面栈类型化为 `Array[BasePage]`、`_load_page() -> BasePage`，直接调虚函数，删 9 处 `has_method`。
  - 创作台工作区：`BenchBase` 声明公开虚函数 `snapshot/restore/preset_from_entry`，三台覆写；`CreationStation._bench_instances: Array[BenchBase]`，删 3 处 `has_method`。
  - `Player._apply_player_data` → `apply_player_data`；`Player._reinit_shoot` → `reinit_shoot`。
  - `Boss._clear_phase` → `clear_phase`。
  - `LaserBeam._physics_process` 抽公开 `step()`（`_physics_process` 转调）+ `_reset` → `reset`；`LaserEngine` 手动驱动改调 `beam.step()/reset()`。
- **度量**：`has_method("_")` **12 → 0**；生产代码对外 `x._m()` **6 组 → 0**（余 `BubblePanel` 静态工厂调同文件 `_parse_tags`，属同类内调用，非 R6）。
- **对照旧项目**：旧 `MenuNav` 靠 `has_method("_on_enter")` 字符串鸭子类型；现在由 `BasePage` 公开虚函数 + 类型化栈在编译期兜底（漏覆写/拼错直接暴露）。
- **验收**：`check_syntax` **191/0**；全量 **55 套 / 306 测试 / 3200 断言全绿**；orphans 10。
### 2026-09-11 — K1b：目录归属收口（`scripts/autoload/` 只留真 autoload）

- **目标**：把 `scripts/autoload/` 里 4 个**已非 autoload** 的文件搬回语义目录，令目录名实相符。
- **做法**：
  - `autoload/bullet_manager.gd` → `scripts/bullet/bullet_manager.gd`；`autoload/bullet/death_clear.gd` → `scripts/bullet/death_clear.gd`（与 `bullet_multi_mesh.gd` 同组）。
  - `autoload/game/scene_transition.gd` → `scripts/scenes/scene_transition.gd`；`autoload/game/menu_nav.gd` → `scripts/scenes/menu_nav.gd`（与菜单页 / `game_scene.gd` 同组）。
  - 删空的 `autoload/bullet/`、`autoload/game/`；`.gd.uid` 随 `git mv`（uid 不变）。
  - 仅 3 处 `preload` 路径更新：`BulletManager` 的 `DeathClearClass`、`GameManager` 的 `TransClass`/`NavClass`。
- **度量**：`scripts/autoload/` 文件 **8 → 4**（`audio_manager` / `game_events` / `game_manager` / `rng`，全为真 autoload）；旧路径引用 **0**。
- **对照旧项目**：旧目录把「autoload」当杂物间（门面 + 子模块 + 场景过渡都塞）；现在目录名 = 真 autoload 白名单。
- **备注**：W4c 的「文件仍在 `scripts/autoload/`」遗留（见上一条）在本波清除。
- **验收**：`check_syntax` **191/0**；全量 **55 套 / 306 测试 / 3200 断言全绿**；orphans 10。
### 2026-09-11 — K1：脚本命名收口（黑话文件去缩写 + class_name 对齐）

- **目标**：清掉 `scripts/**` 里「文件名 ↔ `class_name` 对不上 / `cs_`·`ov_` 黑话缩写」的命名债；只改名字与路径字符串，不改行为。
- **做法**：
  - 文件改名 9 个：`kernel/behavior/avoid_player.gd` → `avoid_player_behavior.gd`（兄弟均带 `_behavior`）；`coroutine/player/{cs_player,cs_reimu,cs_marisa}.gd` → `{player_shoot_script,reimu_shoot,marisa_shoot}.gd`；`{ov_reimu,ov_marisa}.gd` → `{reimu_option_visual,marisa_option_visual}.gd`；`background/env_preset.gd` → `background_env_preset.gd`；`workbench/{dialog,ui_common}.gd` → `{dialog_host,workbench_ui}.gd`。`.gd.uid` 随 `git mv`（uid 不变）。
  - `class_name` 对齐 1 处：`RigBase` → `BenchBase`（`workbench/` 内 4 个 `bench_*` 是主流词，`RigBase` 是异类；外部 0 引用，仅改声明）。
  - 路径引用更新：3 个 `.tres` 的 `ext_resource path`（`reimu_data`/`marisa_data`/`stage01_env`）+ 2 处 `preload` + 2 处测试 `load` + 若干注释。
- **度量**：语义不一致 **8 → 0**（余 4 处为 acronym 大小写）。
- **对照旧项目**：旧名 `cs_`（character script）/`ov_`（option visual）只能靠记忆猜；现在文件名 = 类名，grep / 跳转直达。
- **没做什么（刻意）**：acronym 大小写（`GameUI`、`ScreenFogFX`、`YYJudeVisual`、`UISeparator`）——Godot 引擎自身也全大写（`HTTPRequest`/`AABB`），且 `FxLayer`(21 引用) 与 `ScreenFogFX` 的一致性问题属纯风格，churn > 收益，留待专波。
- **验收**：`check_syntax` **191/0**；全量 **55 套 / 306 测试 / 3200 断言全绿**；orphans 10。
### 2026-09-11 — W4c：BulletManager 去 autoload（组合根持有的弹幕世界）

- **目标**：`BulletManager` 从 autoload 改为「组合根创建 / 持有的 `class_name` 场景服务」，autoload **5 → 4**。
- **做法**：
  - `BulletManager` 加 `class_name` + `static var current`（R8）；`project.godot` 去 autoload。
  - 生产路径注入：`GameScene` / `Workbench` / `BenchBase` 创建并注入 `StageRuntime.bullets`；`ctx.bullets`（`BulletService`）持 `world`；`KernelBulletBackend` / `KernelBomb` 持 `world`（持续清弹 / 爆炸清弹）；`Player` 炸弹、`MarisaLaserFollow` 回收走 `ctx.bullets`。
  - 跨切面（`SceneTransition`、工作台三台、`HitboxOverlay`、`DebugDrawer`）经 `BulletManager.current`；standalone 工作台用 `BenchBase.ensure_bullet_world()` 自建。
  - 内容脚本 `data/**` 的 `re_fire` / `return_bullet` 走 `ctx.bullets`（`BulletService` 补 `re_fire` / `return_bullet` / `shoot_bomb`）。
- **度量**：autoload **5 → 4**（`GameEvents / GameManager / RNG / AudioManager`）。
- **对照旧项目**：旧 `BulletManager` 是 autoload 门面，实体 / 内容 / 工作台全走全局；现在生产走组合根注入，跨切面用 R8 static。
- **验收**：`check_syntax` 191/0；全量 **55 套 / 306 测试 / 3200 断言全绿**；orphans **10**（自建世界被 autofree，比之前更干净）。
- **备注**：文件仍在 `scripts/autoload/bullet_manager.gd`（名字沿用以减少路径 churn），但已非 autoload。
### 2026-09-11 — W4b-4：GameState → SaveData（去 autoload，验收收口）

- **目标**：把 `GameState`（god object）瘦身为「存档 + 菜单/练习状态」，删掉 autoload；单局资源归 `Player`，运行时实体归 `EntityRegistry`。
- **做法**：
  - 新增 `class_name SaveData extends RefCounted`（纯 `static`、非 autoload）：`selected_*` / `current_stage_id` / `spell_book`/`save_mgr`/高分 / `practice_*` / `is_practice_mode` / `stage_registry` / `restarting`；`boot()`（主题/存档/设置/注册表）；`reset_all`/`reset_practice` 经 `EntityRegistry.current` 重置自机资源。
  - 移出：`enemy_killed → score` 归 `Player._ready` 监听；`memory regen` 归 `Player._physics_process`；`_apply_ui_theme`/`_apply_settings`/加载归 `SaveData.boot()`（`GameManager._ready` 调一次）。
  - 机械改名 31 个 `scripts/**` + 1 个 `data/**` + 测试；`workbench`/`enemy_bench`/`creation_station`/`debug_drawer`/`scene_transition` 的 `get_boss`/`get_active_enemies`/`clear_enemies` 改走 `EntityRegistry.current` / `_stage_runtime.refs`。
  - 删除 `scripts/autoload/game_state.gd`；`project.godot` 去掉 `GameState` autoload。
- **度量**：`grep -rIl "\bGameState\b" scripts` **31 → 0**；**autoload 6 → 5**（`GameEvents / GameManager / BulletManager / RNG / AudioManager`）。
- **对照旧项目**：旧 `GameState` 405 行一身多职（存档 + 运行资源 + 实体引用 + 主题 + 信号）；现拆成 `SaveData`（存档）/ `PlayerResources`（资源）/ `EntityRegistry`（实体），主题/设置在壳入口 `boot()`。
- **踩坑**：`EntityRegistry.player`（`Node2D` 类型）在对象释放后**不会**自动置 null——`PlayerService.get_player` 曾因此抛 `Trying to return a previously freed instance`；所有直接返回 `refs.player` 的地方都要 `is_instance_valid` 兜底。
- **验收**：`check_syntax` 191/0；全量 **55 套 / 306 测试 / 3200 断言全绿**；orphans 12。
### 2026-09-11 — W4b-2b：资源消费者直读 PlayerResources（经 refs.player）

- **目标**：把单局资源读取从 `GameState` 转发推进到 `Player.resources`（方案 A：Player 持有，消费者经注册表/注入读），过渡期同一实例、行为等价。
- **做法**：`EntityRegistry.get_player_resources()`（安全访问器）；内核桥接 `_player_res()` 取它；`cs_player` 用 `leader.get("resources")`；`item` 经 `ItemPool.refs` 注入；`game_ui.resources` 由 `GameScene` 注入；`boss` 增 `registry`（`add_enemy_to_scene` 注入）并用 `_refs()` 取资源/自机；`stage_runtime` 用 `refs.get_player_resources()` 取分数。
- **对照旧项目**：旧资源散在 `GameState`，实体/桥接/UI 全走全局读写；现在统一经「自机持有的 `PlayerResources`」。
- **度量**：`grep -rIl "\bGameState\b" scripts` **35 → 31 文件**（引用 159 → 122），清零：`item/item.gd` / `kernel_bridge/kernel_bullet_physics.gd` / `kernel_bridge/kernel_bullet_backend.gd` / `coroutine/player/base/cs_player.gd`。
- **验收**：`check_syntax` 191/0；全量 **56 套 / 311 测试 / 3212 断言全绿**；orphans 12。
- **踩坑**：`item.gd` 把 `var player := GameState.player` 改成无类型后，`var to_player := ...` / `var dir := ...` 推不出类型 → 必须显式标注 `Vector2`（Godot 「Cannot infer the type」是 Parse Error，会让依赖脚本编译失败）。
### 2026-09-11 — W4b-3b：refs 深注入内核弹幕路径（BulletManager / 桥接 / 激光 / 工作台）

- **目标**：把「自机 / 敌机 / Boss」的读取从 `GameState` 门面推进到注入的 `EntityRegistry`，覆盖内核弹幕后端、碰撞/清弹、桥接行为、激光与工作台覆盖层。
- **做法**：`BulletManager.inject_world_refs(refs)`（组合根调用）→ 传播给 `KernelBulletBackend` / `KernelBulletPhysics` / `LaserEngine`；`KernelBulletBackend.spawn_bomb` 把 `refs` 传给 `KernelBomb`；桥接行为经 `KernelBehaviorHost.get_boss()`（`backend.refs`）；`HitboxOverlay` 由工作台注入 `refs`。无 `refs` 时回退 `EntityRegistry.current`。
- **对照旧项目**：桥接层原来直呼 `GameState.player/get_active_enemies/get_boss`；现在统一经注入的注册表。
- **踩坑（承接 W4b-3a）**：`for enemy: Node2D in <含已释放实例的数组>` 与 `var p: Player = refs.player` 会在**赋值/迭代时**抛 `Trying to assign invalid previously freed instance`——必须先 `is_instance_valid` 再赋给类型化变量；迭代用无类型 `for enemy in ...` + 逐个 `is_instance_valid`。
- **度量**：`grep -rIl "\bGameState\b" scripts` **41 → 35 文件**（引用 172 → 159），清零文件：`autoload/bullet_manager.gd` / `laser/laser_engine.gd` / `kernel_bridge/kernel_bomb.gd` / `kernel_bridge/behavior/bounce_behavior.gd` / `kernel_bridge/behavior/non_mid_flee_behavior.gd` / `workbench/hitbox_overlay.gd`。
- **验收**：`check_syntax` 191/0；全量 **56 套 / 311 测试 / 3212 断言全绿**；orphans 12。
- **顺带**：`bench_base.build_world` 先 `ensure_stage_runtime()`（子弹台原来没有关卡运行时 → 幽灵/注册表注入会落空）。
### 2026-09-11 — W4b-3a：运行时引用抽成 EntityRegistry（StageRuntime 持有 + GameState 过渡门面）

- **目标**：把 `GameState` 的运行时引用（`player` / `active_enemies` / `get_boss`）搬出 god object，改为「组合根持有的 `EntityRegistry`」，为 W4b-4 瘦身 `GameState` 铺路。
- **为什么**：R18（`GameState` 是 god object）+ R2/R9（依赖向下注入，不读全局）。`GameState` 只该管存档/持久化；战场实体（自机 / 敌机 / Boss）是**每关世界**的状态，应随 `StageRuntime` 存亡。
- **对照旧项目**：旧 `GameState.active_enemies` 是全局数组，实体 `_ready` 自注册、`clear_enemies` 遍历 queue_free；现注册表由 `StageRuntime` 持有，`Enemy` 经注入的 `registry` 注册，`stop_stage` 调 `refs.clear()`。
- **做法（strangler）**：新 `scripts/stage/entity_registry.gd`（`class_name EntityRegistry extends RefCounted`：`player` / `enemies` / `register_enemy` / `get_boss` / `clear`）；`StageRuntime.refs` 持有并在 `_enter_tree` `GameState.bind_refs`；`GameState.player` / `active_enemies` / `get_active_enemies` / `get_boss` / `clear_enemies` 改为**转发门面**。已迁直接消费者：`Enemy`（注入 registry）、`PlayerService` / `BossService`（经 `StageContext.refs`）、`MoveHoming`；组合根（`GameScene._setup_player` / `bench_base.build_world` / `workbench._setup_world`）注入自机。
- **踩坑**：`EntityRegistry.player` 起初写成**无类型** Variant → 自机 free 后仍指向已释放实例，门面 getter 返回时报 `previously freed instance`（10 个用例失败）。改成内建 `Node2D` 类型后 Godot 自动置 null，getter 再加 `is_instance_valid` 兜底。教训：宿主实体引用**不要用无类型 Variant 保存**。
- **修复 2（同波，试玩发现）**：被击中不出反色圈——`start_spell_card` 自建 ctx **没设 `stage`**，练习模式 `player.ctx = boss.ctx` 于是拿不到 `miss_layer`；另给 `StageRuntime.current`（当前关卡 static 回退），`ctx.effects` 对无 `stage` 的共享 ctx（射击 / 子弹）也稳。
- **修复 1（同波，试玩发现）**：自机不能射击 / 子机消失——`Player._init_shoot_script` 自建一个**无 `stage`** 的 `StageContext`，而 `ctx.refs` 只从 `stage` 取 → 该 ctx 解析不到自机，`ctx.player.get_player()` 恒 null。加 `EntityRegistry.current`（当前世界 `static var` 回退，R8）+ `StageContext.refs` 优先 `stage`、否则回退 `current`。教训：注入型上下文要把「无 stage 的共享 ctx（射击 / 子弹共享 ctx）」纳进解析链，否则静默失效。
- **度量**：`grep -rIl "\bGameState\b" scripts` **46 → 41 文件**（`enemy` / `player_service` / `boss_service` / `move_homing` / `ghost_player` 摘除），引用 180 → 172。
- **验收**：`test/test_entity_registry.gd`（4 用例）；`check_syntax` 191 脚本 / 0 失败；全量 **56 套 / 307 测试 / 3203 断言全绿**；orphans 12。
- **后续（W4b-3b）**：把 `refs` 注入 `BulletManager` / `KernelBulletBackend` / `KernelBulletPhysics` / `KernelBomb` / 桥接行为 / `LaserEngine`，去掉内核弹幕路径对门面的读取。
### 2026-09-11 — W4a-2 修复：魔理沙激光贴图不旋转

- **现象**：内核唯一后端下，魔理沙非 focus 激光段的贴图不随漂移方向旋转。
- **根因**：内核 `MarisaLaserBehavior` 只 `system.set_position()`，**没设 `velocity`**；渲染桥 `_sync_kernel` 按 `BulletType.rotation_for(velocity)` 算贴图朝向，而 `rotation_for` 在 `velocity == ZERO` 时返回 `0.0` → 贴图永远轴对齐。旧 `marisa_laser_follow._tick` 有 `target.velocity = dir`，内核版漏了。
- **修复**：`marisa_laser_behavior.gd` 补 `system.set_velocity(bullet_id, dir)`；回归断言 `test_marisa_laser_anchors_to_global_position`（velocity != 0 且 angle == -PI/2）。
- **教训**：移植行为时，**凡是渲染/特效依赖的字段（velocity/rotation）都要一起设**——旧路径可能靠 `Bullet.bind` 顺带设了，内核 `set_position` 不会。
- **验收**：全量 **55 套 / 303 测试 / 3193 断言全绿**。

### 2026-09-11 — W4b-2a：Player 注入 PlayerResources（资源引用清零）

- **目标**：把 `PlayerResources` 注入 `Player`，让玩家逻辑直接持有资源真源（为后续消费者迁移铺路）。
- **做法**：`Player.resources`（`_ready` 过渡期取 `GameState.resources` 同一实例）；`player.gd` 的 `use_bomb` / `memory_value` / `reduce_memory` / `add_memory` / `lose_life` 改走 `resources`。
- **验收**：全量 **55 套 / 303 测试 / 3191 断言全绿**。
- **说明**：`GameState` 仍是 owner（组合根注入统一实例）；全量去除 `GameState` 引用需按文件逐个迁移（UI/道具/Boss/桥接/菜单），是后续小步。

### 2026-09-11 — W4b-1：GameState 资源抽成 PlayerResources（转发，零改动）

- **目标**：`GameState` 的单局资源状态（火力/分数/擦弹/残机/雷/碎片/记忆）抽成单一 owner（R18），为后续"消费者直接注入"铺路。
- **为什么**：R18（上帝对象要拆）+ R8（共享状态用 `class_name`）。`GameState` 405 行、186 引用，直接大改风险高——先用**转发属性**把状态搬到 `PlayerResources`，调用点零改动、行为不变。
- **对照旧项目**：旧资源字段散在 `GameState` 里、方法直接改字段；现状态归 `PlayerResources`，对外入口收敛 + `changed` 信号（R7）。
- **新落点**：`scripts/player/player_resources.gd`；`GameState.resources` + 9 个转发属性 + 方法委托；`MEMORY_*` 常量单一来源。
- **验收**：`test/test_player_resources.gd`（4）；全量 **55 套 / 303 测试 / 3191 断言全绿**。
- **注意**：转发是**过渡态**——下一步（W4b-2）把 Player/UI/kernel 改成直接持 `PlayerResources`，再去掉转发属性。
### 2026-09-11 — W4a-2：删旧弹幕池（内核唯一后端）

- **目标**：删除整个旧弹幕子系统，内核成为唯一后端，去掉 strangler 开关（W4a 收口）。
- **为什么**：R9（去单例/开关残留）+ R19（不留死代码）+ 收敛内核合流。
- **对照旧项目**：旧 `BulletManager` 是"双后端门面"（旧 `Bullet` 节点池 ↔ 内核 SoA）。W4a-1 转正后旧池已是回滚备份，试玩确认无回归后即可整体删除。
- **删除**：`bullet_pool.gd` / `bullet_physics.gd` / `bullet.gd` / `spatial_hash.gd` / `bomb_behavior.gd` / `bullet_fog.gd` / `bullet.tscn` + `use_kernel`/F2/`active_bullets`/`use_multi_mech` 全部旧分支。
- **收窄**：`DeathClear` 改调注入的内核扫掠；`BulletMultiMesh` 删 `_sync_nodes`；`LaserEngine` 的 `BulletPhysics` 依赖改为注入 `on_graze` Callable；`player.gd` 去 `bomb_behavior`。
- **验收**：`check_syntax` 190 脚本 / 0 失败；全量 54 套 / 299 测试 / 3181 断言全绿。
- **教训/注意**：`active_bullets` 是旧池专属 API，删除时所有统计要换 `active_count()`、调试叠层要换内核行遍历（`debug_drawer`/`hitbox_overlay` 已改）。
### 2026-09-11 — W4a-1 修复：内核转正暴露"自机引用未刷新"（道中非符逃跑弹失效）

- **现象**：内核转正为默认后，中boss非符的 `non_mid_flee` 逃跑弹不生效（弹丸直线飞、不转向）。
- **根因**：`use_kernel = false` 时 `_enable_kernel()` 是**游戏内按 F2** 才跑，那时自机已存在；转正后它在 autoload `_ready` 跑——**自机尚未生成**（`GameState.player == null`），`BehaviorContext.setup(null, ...)` 把自机缓存成 null，之后再没刷新 → `ctx.get_player_position()` 恒 `Vector2.ZERO` → `non_mid_flee`/`homing` 的"接近自机"判定永不成立。
- **修复**：新增公开 `BulletManager.refresh_kernel_player()`；组合根在自机就绪后调用——`GameScene._setup_player()`、`workbench._setup_world()`、`bench_base.build_world()`。
- **回归测试**：`test_composition_root:test_game_scene_refreshes_kernel_player`（断言 `behavior_ctx.get_player_position()` == 场景自机位置）。
- **教训**：strangler 的"翻默认"会把**原本只在手动开关时才满足的前置条件**（这里是"自机已存在"）暴露成 bug。翻默认后必须跑**真实场景**冒烟——单测（显式 `setup_behaviors(player)`）覆盖不到 autoload 早于场景的时序。

### 2026-09-11 — W4a-1：内核弹幕后端转正（默认 true，旧池回滚）

- **目标**：把 Track A 装好的内核从"开关后备选"变成**默认**，完成 strangler 的"翻开关"步（W4a-1；W4a-2 才删旧池）。
- **为什么**：`use_kernel` 的管道完全封闭在 `BulletManager` + `BulletMultiMesh._sync_kernel` + `test_kernel_swap`，翻默认是低成本的收敛验证；未映射内容的回归风险靠"保留旧池 + F2 回滚 + 试玩"兜住。
- **对照旧项目**：旧默认是旧节点池。若直接删旧池、未映射内容（`kernel_port()` 只有 7 处 vs 17 个内容 CoroutineScript 子类）会退化成直线；故先翻默认、后删。
- **新落点**：`bullet_manager.gd:use_kernel = true`；新增 `active_count()`（双后端统一计数）；旧池专属测试显式 `set_use_kernel(false)`（语义上它们本就测旧路）；bench/工作台统计迁 `active_count()`。
- **验收**：kernel 默认下全量 **63 套 / 337 测试 / 3341 断言全绿**。
- **坑预警**：`active_bullets` 是**旧池专属** API，内核路径恒空——统计/断言必须走 `active_count()`；`hitbox_overlay`/`debug_drawer` 的逐弹遍历在旧池删掉后需补内核遍历。
### 2026-09-11 — W3b：StageManager 去 autoload（StageRuntime 场景节点 + ctx.stage）

- **目标**：autoload 7 → 6（轨道 B / §12 W3b）。
- **为什么**：R9（autoload 只放真全局）+ R2（`add_enemy_to_scene` 全树找 `World`）+ R21（World 下声明式节点）。
- **对照旧项目**：旧 `StageManager` 是 autoload，`add_enemy_to_scene` 里 `get_tree().current_scene.get_node_or_null("World")` 全树找父级——依赖"当前场景恰好有 World"的隐式约定。新 `StageRuntime` 由组合根注入 `world`，不再找。
- **做法（strangler）**：W3b-1 先抽 `StageRuntime` + 薄门面（调用点零改动，commit `c3b4758`）；W3b-2 迁调用点（`ctx.stage`）并删 autoload。
- **新落点**：`scripts/stage/stage_runtime.gd`；`StageContext.stage`；`EnemyData.spawn`/`StageDirector` 走 `ctx.stage`；`game_scene.tscn`/`workbench.tscn` 的 `World` 下声明节点；组合台 `bench_base.ensure_stage_runtime()` 自备，`bookmark_panel.stage_runtime` 由 Workbench 注入。
- **验收**：autoload **7→6**；全量 **63 套 / 337 测试 / 3341 断言全绿**。
- **踩坑①**：`workbench._load_stage()` 的"清 World 残留"循环把新放进 `World` 的 `StageRuntime` 一起 `queue_free` → `_stage_runtime` 变 freed，触发 `previously freed`。**把结构性服务节点放 World 下时，任何"清 World"循环都要排除它。**
- **踩坑②**：`add_enemy_to_scene` 里 `world if is_instance_valid(world) else get_tree().root` → `Node2D` vs `Window` 两分支不兼容，编辑器报 `INCOMPATIBLE_TERNARY`（**warning，headless 测试不拦**）。改显式 `if/else`。**教训：大改后要跑 `godot --headless --editor --quit` 并看输出——之前把 editor 输出丢 `/dev/null` 才漏掉它。**
### 2026-09-11 — W3a：AssetRegistry 去 autoload（class_name 静态表）

- **目标**：autoload 8 → 7（轨道 B / §12 W3a）。
- **为什么**：R9（autoload 只放真全局）+ R8（共享数据/功能用 `class_name`/`static`）。`AssetRegistry` 是一张**只读资源表**，没有节点身份、没有信号、没有生命周期——正是 R8 的适用对象。
- **对照旧项目**：旧作为 autoload 实例，好处只是 `AssetRegistry.xxx` 访问，但代价是一个常驻 Node + 一次 autoload 注册。改 `class_name` 静态表后**访问语法完全一致**，调用点 0 改动。
- **新落点**：`scripts/asset_registry.gd`（`class_name AssetRegistry`）；`_bgm_cache` 改 `static var`，4 个方法改 `static func`。
- **验收**：`test/test_asset_registry.gd` + `test_composition_root.gd:test_removed_autoloads_stay_removed`；全量 **63 套 / 336 测试 / 3337 断言全绿**。
- **暂缓**：`bullet_configs`→`data/atlas/*.tres`（R17）随 S13 图集做。

### 2026-09-11 — W2：StageObjects 去 autoload / HitEffectPool → FxLayer 注入

- **目标**：再降两个"不是真全局"的 autoload，autoload 12 → 8（轨道 B / `NEW_KERNEL_REFACTOR_PLAN.md` §12 W2）。
- **为什么**：R9（autoload 只放真全局）+ R2（依赖向下注入）+ 全树找父级禁令。
- **对照旧项目**：
  - 旧 `HitEffectPool` 作为 autoload，`play()` 里 `Engine.get_main_loop().current_scene.get_node_or_null("World")` **全树找父级**——违反 R2/R9，且依赖"当前场景恰好有个 `World` 子节点"的隐式约定。新 `FxLayer` 由组合根创建、挂 `World` 下、注入到需要它的地方，`play()` 不再找父级。
  - 旧 `StageObjects` 作为 autoload 跨关存活——但它的语义本来就是"帧级作用域"（load_stage 注册、stop 清空）。改成 `StageContext.objects` 后生命周期与关卡对齐，不再有跨关残留。
- **新落点**：
  - `scripts/coroutine/services/stage_objects.gd`：`class_name StageObjects extends RefCounted`；`stage_context.gd:objects` 懒建；`stage_director.gd` 注册/清理；`boss_handle.gd` 持注册表（`_init` 第 4 参，默认 null → 兼容纯逻辑测试）。
  - `scripts/effect/fx_layer.gd`：`class_name FxLayer extends Node2D`；节点在 **`game_scene.tscn` 的 `World` 下声明**（R21 声明式建树，与 `ItemPool` 同规格），`game_scene.gd:_ready` 只做注入（`BulletManager.inject_fx_layer()` + `StageManager.fx_layer`）；`effect_service.gd:play_hit_effect` 走注入的 `fx_layer`。
  - 调用点（`bullet_physics.gd` / `death_clear.gd` / `kernel_bullet_physics.gd` / `bullet_manager.gd`）全部改为注入字段 + `fx == null` 静默守卫（单测/无场景安全）。
- **验收**：`test_composition_root.gd` 增 `test_game_scene_creates_and_injects_fx_layer`；`test_stage_director.gd` 改纯逻辑；新增 `test_fx_layer.gd`（3 用例，池化语义）；全量 GUT **62 套 / 333 测试 / 3327 断言全绿**。
- **踩坑（基线）**：初版 `FxLayer` 在 `game_scene.gd` 里 `FxLayer.new()+add_child` 命令式建树，违反 **R21**（`BEST_PRACTICES_BASELINE.md`）——已改为在 `game_scene.tscn` 的 `World` 下声明；同时把 W1 遗留的 `MissEffectManager`（同样 `new()+add_child`）一并改为 `Main` 下声明式节点。教训：**改前先通读基线**，别只 grep 用到的那一行。
- **踩坑（缓存）**：新增 `class_name` 再次踩缓存——headless 直接报 `Could not find type "StageObjects" / "FxLayer"`，连锁 81 个假失败（`Scripts 61→59`）。跑 `godot --headless --editor --quit` 重建 `.godot/global_script_class_cache.cfg` 即恢复（W1 用 `--import`，本次 `--editor --quit` 同样有效）。
- **边界**：`FxLayer` 是**宿主侧**节点，不是内核服务；`scripts/kernel/**` 零引用。`scripts/kernel_bridge/**` 桥接层允许持注入的 `fx`。
### 2026-09-11 — W1：LayerConfig 去 autoload / MissEffectManager 场景节点化

- **目标**：把两个"不是真全局"的 autoload 降级，autoload 12 → 10（轨道 B / `NEW_KERNEL_REFACTOR_PLAN.md` §12 W1）。
- **为什么**：R9（autoload 只放真全局）+ R8（共享功能用 `class_name` / `static`）+ R2（依赖向下注入）。
- **对照旧项目**：
  - 旧 `LayerConfig` 作为 autoload 只为提供常量——每个 `LayerConfig.XXX` 都要经一个常驻 Node 实例取值；纯常量本可用静态类。
  - 旧 `MissEffectManager` 作为 autoload CanvasLayer，被 `EffectService` 与 `BulletManager.clear_all()` 全局直呼——弹幕门面被迫知道一个 UI 特效存在，是典型 R9 违规。
- **新落点**：
  - `scripts/layer_config.gd`：`class_name LayerConfig`，去掉 `extends Node`。
  - `scripts/effect/miss_effect_manager.gd`：`class_name MissEffectManager`。
  - 注入链：`game_scene.gd:_ready` → `StageManager.miss_layer` → `stage_context.gd:effects` → `effect_service.gd:miss_layer`（空则静默跳过）。
  - `bullet_manager.gd` 删除 `MissEffectManager.clear_all()`。
- **验收**：`test/test_miss_effect.gd`（8 用例）+ `test/test_composition_root.gd`（组合根冒烟 1 用例）；全量 GUT **279/279**，3199 断言。
- **踩坑**：新增 `class_name` 后必须让 Godot 重建 `.godot/global_script_class_cache.cfg`（跑一次 `godot --headless --import`），否则 headless 报 `Identifier "LayerConfig" not declared`——不是代码错，是缓存没刷新。
- **顺带修**：`test_recent_mechanics.gd` 练习记录用例非幂等——历史遗留 `stage=99` 幽灵记录会让 `get_or_create` 命中旧值（实测 attempts=6/captures=3）继续累加造成假失败；已加起始清除并清掉本地 `.tres` 幽灵项。

### 2026-09-11 — S0：内核 vendor（`scripts/kernel/` 自包含接入）

- **目标**：把重建版内核（tag `kernel-v1` / commit `238507a`）整块搬进 `scripts/kernel/`，验证「内核不认识宿主全局」。
- **为什么**：Strangler 第一步——新内核先自包含进来、**不碰任何调用点**；内核要纯净（零宿主引用）才谈得上复用与无头测试。
- **对照旧项目**：旧弹幕 = `BulletPool` 节点池 + `BulletPhysics` + `SpatialHash`；内核 = SoA `BulletSystem` + MultiMesh + uniform grid。
- **新落点**：`scripts/kernel/`（14 `.gd` / 1,221 行：`bullet_system.gd` + `behavior/` + `collision/` + `bullet_type.gd`/`effect_type.gd`）+ `scripts/kernel/README.md`（来源 / 单一真相 / 边界规则）。
  - **唯一 vendoring 改动**：`bullet_system.gd` 删掉 `BulletRenderer` 注入——内核本体不引宿主渲染器类型（R2/R9）。
  - **不带渲染与图集**：继续用原项目 `BulletMultiMesh`（本就按纹理分组、支持独立 PNG 与图集区域）——对应重建版决策备忘 §10.4 的 hybrid 结论。
- **验收**：新增 `test_kernel_vendor.gd`（2 用例）证明内核独立可 `new` / `spawn` / `query_circle` / `hit_test` / `despawn`；全量 GUT **56 套 / 281 测试 / 3208 断言全绿**；`--import` 无撞名 / 解析错误。
- **边界**：`scripts/kernel/**` 唯一允许引用宿主的是 `LayerConfig`；其余零宿主引用。**回退点**：原项目 tag `pre-kernel-adapter`。

### 2026-09-11 — S1：适配层 `KernelBulletBackend`（宿主 `BulletData` → 内核 `BulletType`）

- **目标**：给内核加一个宿主侧桥，把内容 `BulletData` 翻译成内核 `BulletType` + 侧表；S1 只做直线。
- **为什么**：内核不认识 `BulletData`（宿主内容类型）——映射留在桥接层，内核保持零内容依赖。
- **新落点**：`scripts/kernel_bridge/kernel_bullet_backend.gd`。四条语义对齐：
  - **方向 vs 速度**：`direction` 定方向，`data.velocity` 只取长度（对齐旧 `Bullet.bind`）。
  - **圆判定归零**：`shape == CIRCLE` 时把内核 `hitbox_size` 归零，否则每颗圆弹会按默认 `size(8,8)` 变矩形。
  - **按内容签名缓存弹型**：原项目两种用法并存（`enemy01` 复用实例改速度 / `cs_reimu` 每发 `BulletData.new()`）——按实例缓存会让内核弹型表**每发长一个**，故按 `signature_of()` 内容签名缓存。
  - **纹理旁表** `texture_for_index()`：内核 `BulletType` 不含 `Texture2D`，S2 渲染靠它取「哪张图」。
- **未映射计数**：`coroutine_script` / `accel` 未映射时按直线发射并计入 `unmapped_behavior_count`（S4 接线前的覆盖面探针）。
- **验收**：新增 `test_kernel_backend.gd`（6 用例 / 14 断言：签名复用 / 速度语义 / 纹理旁表 / 阵营映射 / 圆矩判定 / 未映射计数）；全量 GUT **57 套 / 287 测试 / 3222 断言全绿**。**仍纯增量**——`BulletManager` 一行未改。

### 2026-09-11 — S2：渲染读内核快照（`BulletMultiMesh` 双数据源）

- **目标**：`BulletMultiMesh` 支持「注入后端就画内核 SoA，否则走旧节点」——不换发射入口先换渲染，独立验证轨迹 / 朝向 / 颜色 / 层次。
- **为什么**：把「画得对不对」与「发得对不对」解耦，是 Strangler 能逐块回退的前提。
- **新落点**：`scripts/bullet/bullet_multi_mesh.gd` 加 `set_backend()` → `_sync_kernel()`（position / velocity / color / faction / type_index / type_registry + `backend.texture_for_index()`）；未注入时 `_sync_nodes()` **逐字保留**；`_group_key()`（纹理 RID + region + 阵营 + tint_mode）两路共用，批次数才可比对。
- **踩坑（阵营顺序）**：内核 `Faction{ENEMY=0, PLAYER=1, NONE=2}` 与原项目 `Bullet.FACTION_PLAYER=0 / ENEMY=1 / BOMB=2` **顺序不同**——`_host_faction()` 必须显式映射，否则敌弹 / 自机弹的 z 层互换。
- **踩坑（headless）**：dummy 渲染器下 `MultiMesh.get_instance_transform_2d()` **读回恒为 0**——逐实例几何不能在 CI 断言；S2 断言只落批次数 / `visible_instance_count` / `z_index` / 材质 / 网格尺寸，画面一致性留给手动试玩。
- **验收**：新增 `test_kernel_render.gd`（5 用例 / 7 断言）；全量 GUT **58 套 / 292 测试 / 3229 断言全绿**。

### 2026-09-11 — S3a：内核路由（`use_kernel` 开关，明确不含碰撞）

- **目标**：让 `BulletManager` 把弹幕整个切到内核池（spawn / 积分 / 渲染 / 剔除 / 暂停 / 清空），**不含碰撞**。
- **为什么**：读全旧 `BulletPhysics` / 内核 `CollisionResolver` 后确认 S3 不是「换发射入口」而是「换整个弹幕运行时」——只换发射会让弹幕变成「只飞不判定」或数值差 10–50 倍；先只切「飞和画」，才有一条可独立回归的线。
- **新落点**：`scripts/bullet/bullet_manager.gd`：`use_kernel` / `_kernel` / `kernel_system()` / `set_use_kernel()` / `_enable_kernel()`；四个发射入口按开关分流；`_physics_process` 的旧碰撞 / 出屏回收整块收进 `if not use_kernel:`。
- **帧序是硬约束**：内核 `BulletSystem.process_physics_priority = -10`（先积分），宿主碰撞节点留在 0——否则碰撞读到**上一帧**位置。
- **开关决定**：`use_kernel` 默认 `false`（Strangler：主流程零改动）；不用 F1（`debug_toggle` 已被 `debug_drawer.gd` / `main_menu.gd` 占用），试玩用 `set_use_kernel(true)`（F2 热切）。
- **验收**：新增 `test_kernel_swap.gd`（4 用例 / 8 断言：路由到内核池 / `cull_rect` 对齐 / 切回清空内核池 / 帧序优先）；全量 GUT **59 套 / 296 测试 / 3237 断言全绿**。
- **诚实的局限**：切过去弹幕会飞会画但**不判定**，且 `bounce / gravity / radial` 等行为变直线——S3a 只验证轨迹 / 朝向 / 颜色 / 层次。

### 2026-09-11 — S3b：敌弹 ↔ 自机（命中 + 擦弹双阈值）

- **目标**：把旧 `BulletPhysics._resolve_enemy_bullets_near_player` 1:1 移植到内核几何上。
- **新落点**：新增 `scripts/kernel_bridge/kernel_bullet_physics.gd`（`KernelBulletPhysics`）；`BulletManager._physics_process` 在**内核积分之后**调 `process()`。候选查询用内核 `CollisionResolver.overlap_ids(.., graze_radius, ENEMY)` → **倒序**逐弹 `hit_test` 精判 → 命中 `player.miss()` + `despawn`，否则按 `graze_radius` 再判 → 擦弹结算（`graze_count` / `add_score(10)` / `add_memory` + 音效）；记忆 ≥50 时按旧公式 `remap(50,100,0.05,0.30)` 随机清弹。
- **关键认知**：内核 `hit_test(id, center, radius)` 内部按 `radius + 弹半径` 判圆（矩形 / 偏移走 `HitGeometry` 统一实现）——**擦弹就是「更大 radius 的同一次判定」**，不需要第二套几何。
- **验收**：新增 `test_kernel_physics.gd`（4 用例 / 7 断言：命中→回收+无敌 / 擦弹→计数不回收 / 擦弹不重复计 / 无敌穿过）；全量 GUT **60 套 / 300 测试 / 3244 断言全绿**。

### 2026-09-11 — S3c：自机弹 ↔ 敌人（`damage` 走宿主侧表）

- **目标**：移植旧 `BulletPhysics._player_vs_enemies` 的规则；**damage 不引入内核**。
- **为什么**：内核 `BulletType` 没有 `damage` 字段，原项目默认 10.0（Bomb 50.0）——直接把原弹幕灌进内核，Boss TTK 会差 ~10×（玩法崩坏）。选择 **A 方案：宿主侧规则移植**，把 `damage` / `hit_sfx` 放桥接侧表。
- **新落点**：`KernelBulletBackend` 增 `_damage_by_index` / `_hit_sfx_by_index`（随 `_sync_host_tables()` 与纹理旁表一起增长）+ `damage_for_index()` / `hit_sfx_for_index()`；`KernelBulletPhysics._player_bullets_vs_enemies()`（倒序、只处理 `Faction.PLAYER`、逐个 `hit_test`、记忆 bonus `1 + remap(memory,0,50,0.15,0.05)`、命中音效 1:1、时符 / 未开战穿过）。**内核零改动**。
- **验收**：新增 `FakeEnemy` 轻量夹具 + damage 侧表用例（`test_kernel_physics` 5 用例 / 9 断言）；全量 GUT **60 套 / 301 测试 / 3246 断言全绿**。
- **A 方案成立的证据**：`damage` 不进内核也能 1:1 保住（侧表 + 宿主规则），内核仍零改动——后续 S4 全部沿此路线。
- **本步仍未接**：`bomb`（依赖 S4）、`out_grace`、行为（`bounce/gravity/radial`）、自机弹记忆变红（后由 S3d / S4 逐项补）。

### 2026-09-11 — S3d：死亡清弹接内核（后端分派收回 BulletManager）

- **目标**：修试玩唯一发现的行为缺失——内核路径下 Boss 击破 / Miss 的展开清弹圈不清弹。
- **为什么**：`DeathClear` 直接摸 `_pool.active_bullets` 是后端泄漏；内核路径下旧池恒空。正确落点是让 `DeathClear` 与后端解耦，双后端分派收回到 `BulletManager`（S3a 起约定）。
- **对照旧项目**：旧实现把“扩张半径”和“清旧池”耦合在一个类里。若整个搬到内核，要么复制一份清弹圈逻辑，要么让 `DeathClear` 认识两个池（两处都要改）。本次只抽一个 `Callable` 注入点，旧循环**一行未改**。
- **新落点**：
  - `scripts/autoload/bullet/death_clear.gd`：`setup()` 增 `p_kernel_sweep`；清弹步骤改 `if not handled:` 包旧循环。
  - `scripts/kernel_bridge/kernel_bullet_physics.gd:sweep_enemy_bullets()`：内核逐弹扫掠（颜色 + 消散特效 + on_clear）。
  - `scripts/autoload/bullet_manager.gd:_kernel_sweep_death_clear()`：按 `use_kernel` 分派。
- **验收**：全量 GUT **60 套 / 305 测试 / 3254 断言全绿**。
- **踩坑**：本想用内核现成 `cancel_bullets()` 驱动清弹圈，读实现后发现不合——(1) 它是一次性全清，死亡清弹是逐帧扩张；(2) 其消散特效发成内核纯特效行，而渲染桥只认 `BulletType` 行，画不出来。改回宿主逐弹扫掠 + `HitEffectPool`。

### 2026-09-11 — S4a：行为管道 + 内容端口契约

- **目标**：把内核 `Behavior` 注册表接到原项目——`use_kernel` 下 `coroutine_script` / `BulletData.accel` 不再一律直线。
- **为什么**：内核早有 `BehaviorProcessor` / `BehaviorContext` / `WorldQuery`，原项目从没装配。端口用 duck-typed `kernel_port()`，**映射留在 `data/**`**，`scripts/**` 不出现内容路径（命名边界）。
- **对照旧项目**：旧是**每弹一个 `CoroutineScript` 协程**；内核是**共享 `Behavior` 实例 + 行内状态**。移植后行为**只 `set_velocity`**，位置由系统积分——自己再 `+= pos` 会双倍。
- **新落点**：`scripts/kernel_bridge/behavior/world_accel_behavior.gd`；`kernel_bullet_backend.gd` 的 `setup_behaviors` / `_port_for` / `shoot`；`bullet_manager.gd:_enable_kernel` 装配；`data/stages/stage01/bullet/gravity_bullet.gd:kernel_port()`。
- **验收**：全量 GUT **61 套 / 312 测试 / 3269 断言全绿**（新 `test_kernel_behavior` 5 用例 + swap 管道用例）。
- **踩坑**：① `_enable_kernel` 原来 `if _kernel != null: return` 早退——首次 enable 若在 `setup_behaviors` 抛异常，后续 enable 全跳过 cull_rect / 行为装配，级联崩 4 个测试；改为「创建块 + 每次刷新行为管道」。② `GameState.player` 在 GUT 里常是上一测试的 **freed 引用**，直接传给 `Node2D` 形参会报 “previously freed”，必须 `is_instance_valid` 守卫。

### 2026-09-11 — S4b：`homing` 行为（灵梦 opt1）

- **目标**：`move_homing` 不再直线——内核路径下追最近敌人。
- **做法**：桥接 `HomingBehavior` 移植旧逻辑（转向限制 + `lerp(min_speed, top_speed, elapsed/accel_time)` + `homing_duration`）；目标查询走内核现成 `WorldQuery`，时符 / 未开战 Boss 的跳过放桥接层（引用宿主 `Boss`）。
- **顺带**：`setup_behaviors` 的 provider 改为**可重复注入**；新增 `test/fixtures/no_port_behavior.gd`，让「未映射计数」测试不再绑定具体内容行为（避免 S4 每步都要改测试）。
- **对照旧项目**：旧 `_apply_homing` 算的 `speed_mult/alignment` 紧接着被 `normalize() * current_speed` 覆盖——**死代码**，复刻反而增乱，故不抄。
- **验收**：全量 GUT **61 套 / 314 测试 / 3274 断言全绿**。

### 2026-09-11 — S4c-1：radial_accel + 延后动作队列

- **目标**：`radial_accel_bullet` 在内核路径下不再直线——沿初方向加速、碰顶边换成向下弹。
- **关键约束**：内核 `BehaviorProcessor` 明确「行为只标记待回收，回收在循环后统一执行」；`swap-with-last` 让循环中途 `despawn/spawn` 会搬行错位。所以不能像旧 `re_fire` 那样就地增删。
- **做法**：新增 `KernelBehaviorHost` 延后队列——行为 `request_despawn(id)` + `queue_spawn(data,pos,dir)`；`KernelBulletBackend._physics_process`（优先级 **-4**，行为 -5 之后、宿主碰撞 0 之前）`flush()`。
- **边界**：行为是桥接层（可引 `GameConfig` / `AssetRegistry` / `AudioManager`），但**替换弹模板 + sfx key 由内容 `kernel_port()` 提供**，`scripts/**` 不出现内容路径。
- **对照旧项目**：旧 `re_fire` 复用同一 `Bullet` 节点（省池 churn）；内核等价 = 回收旧行 + 新发一行（S3 已接受的近似）。模板 `duplicate()` 后才改 `velocity`，不污染缓存。
- **验收**：全量 GUT **61 套 / 316 测试 / 3279 断言全绿**。

### 2026-09-11 — S4c-1 修复：`duplicate()` 丢贴图 → 隐藏弹

- **现象**：内核路径 `radial_accel` 到顶不换弹（看不见向下弹），但端口 / 行为打印正常。
- **根因**：替换弹用 `BulletData.duplicate()` 从模板复制，**`texture` 被丢成 null**；渲染桥 `_sync_kernel` 遇 `tex == null` 直接跳过 → 弹在物理上存在、但完全不画。
- **修法**：内容端口改提供 **`spawn_factory: Callable`**（每次造新 `BulletData`）；后端**保活**探测实例（Callable 绑在它身上，释放即失效）。
- **教训**：`Resource.duplicate()` 对 Resource 字段（`texture`）不可靠；「弹在但看不见」先查贴图旁表。诊断顺序：先确认「行为有没有跑」，再查「跑完之后画没画」。
- **验收**：全量 GUT **61 套 / 319 测试 / 3289 断言全绿**。

### 2026-09-11 — S4c-2：`bounce` 反弹弹

- **目标**：非符1 的反弹弹在内核路径下也能碰框换向。
- **做法**：桥接 `BounceBehavior` 1:1 移植（沿飞行方向加速 + 左/右/上碰框夹回 + 朝 Boss 转 `bounce_angle` + 换直线弹 + 音效）。替换弹走 S4c-1 的 `spawn_factory`（见上条）。
- **边界**：Boss 取 `GameState.get_boss()`（宿主），落在桥接层；内核不碰。
- **对照旧项目**：旧 `spawn_tex` / `spawn_color` 是**死变量**（`_re_fire` 硬编码米弹 / GOLD）——不抄「看起来能配其实没用」的参数。
- **验收**：全量 GUT **61 套 / 321 测试 / 3296 断言全绿**。

### 2026-09-11 — S4c-3：`non_mid01` 弹丸（逃跑 + 散圈）

- **目标**：中boss非符的弹丸在内核路径下也能「靠近自机逃跑、靠近 Boss 散圈消失」。
- **做法**：桥接 `NonMidFleeBehavior` 负责状态机 + 距离检测；**内容相关决策（难度 `diff_pick`、RNG、散圈形状）通过 `on_flee_burst(pos, boss_pos, has_boss, host)` 回调留在 `data/**`**。桥接把 `GameState.get_boss()` 的 `boss_pos / has_boss` 与延后队列 `host` 传给回调。
- **难点**：散圈一次多发，且内核禁止行为循环中途 spawn → 内容 `_kernel_spread` 只 `host.queue_spawn`（内核版 shoot_spread）。
- **边界**：`diff_pick` 原来挂在 `ctx.diff`，这里实测它其实只读全局 `GameState.selected_difficulty`——内容探测实例可直接用，不必假装有 ctx。
- **验收**：全量 GUT **61 套 / 323 测试 / 3302 断言全绿**。

### 2026-09-11 — S4c-4：魔理沙激光（漂移 + 整批渐隐）

- **目标**：内核路径下魔理沙非 focus 激光段能跟着子机漂移、松手整体淡出。
- **漂移**：直接复用内核现成 `LaserFollowBehavior`；内容端口把 `cs_marisa` 的 `anchor_id / drift_speed / angle` 映射过去。
- **渐隐**：新增桥接 `MarisaLaserFade`（= 重建版 `LaserShot` 的极简版）：按住满亮、松手整批 `set_render_fade(LASER, α)` 到 0 后清行；渲染桥 `_sync_kernel` 按 `bt.kind` 应用 fade。
- **为什么整批而不是逐弹 alpha**：内核 SoA 没有 `set_color`，逐弹 alpha 要改内核；整批 fade 是内核本就提供的 `set_render_fade`（重建版同款设计），守住 A 方案「内核零改动」。
- **踩坑**：渐隐控制器起初在「淡完 → 松手仍成立」时又重启一轮「淡出→复位」，测试值停在中途；加 `_spawned` 门（只有生成过激光才启动渐隐）后正确。
- **验收**：全量 GUT **61 套 / 324 测试 / 3306 断言全绿**。

### 2026-09-11 — S4c-4 修复：子机锚点 `global_position`

- **现象**：魔理沙激光不跟子机，跑到屏幕边。
- **根因**：原项目子机是**玩家的兄弟节点**（`leader.get_parent().add_child(opt)`），`position` 相对 World；内核 `LaserFollowBehavior` 读 `node.position` 当作「玩家子节点偏移」→ `玩家 + 子机世界位` 翻倍。
- **修法**：桥接 `MarisaLaserBehavior` 用 `global_position`（旧语义），端口 `move=&"marisa_laser"`。
- **教训**：内核行为的**节点语义假设**（子节点 local）必须与宿主实际层级对齐，否则静默偏移——这类 bug 不报错，只画错。
- **顺带**：端口成员 `port_*` 命名，避开旧 lambda 局部变量 shadow 警告。
- **验收**：全量 GUT **61 套 / 325 测试 / 3308 断言全绿**。

### 2026-09-11 — S4d-1：自机弹记忆变红

- **做法**：旧 `Bullet.bind` 是在**绑定时**按 `memory_value` 把 `sprite.modulate` 往红 lerp 一次——不是每帧。内核桥接在 `shoot()` 里对 PLAYER 弹算同一个 tint 即可，**内核零改动**。
- **教训**：先读旧实现确认「一次性 vs 每帧」，能省掉一整套逐帧调制机制。
- **验收**：全量 GUT **61 套 / 327 测试 / 3310 断言全绿**。

### 2026-09-11 — S4d-2：bomb 宿主节点（B 方案）

- **决策**：bomb 不走内核池，改宿主节点 `KernelBomb`（Node2D）。理由：bomb 需要 `out_grace`（轨道越界不被剔除），而 A 方案下内核 cull 是统一的、没有 per-type grace；bomb 只 8 颗、宿主动作（清弹 / 伤害 / 视觉）多。
- **实现**：1:1 移植 `bomb_behavior.gd`；`shoot_bomb_bullet` 内核分支 → `_kernel.spawn_bomb`；清场路径 `clear_bombs`。
- **踩坑**：`Node2D` **没有** `velocity` 属性（那是旧 `Bullet` 的自定义字段）——宿主节点要自己声明。
- **`out_grace` 决定**：暂缓；将来作为弹幕 / 弹型**属性**接入（正好是 GDExtension 数据属性之一）。出生雾同理暂缓。
- **验收**：全量 GUT **61 套 / 328 测试 / 3314 断言全绿**。

### 2026-09-11 — S4d-3：bomb 弹丸持续清弹

- **反馈**：bomb 原来只在爆炸时清；改成**每颗 bomb 弹丸自己周围持续清**。
- **做法**：`BulletManager.clear_enemy_bullets_in_circle`（双后端：内核 `sweep_enemy_bullets` / 旧池逐弹 `return_bullet`）；`KernelBomb` / `bomb_behavior` 每帧围绕自己清，`clear_radius = 90`（可覆盖），不节流。
- **为什么这个设计**：清弹中心是 bomb 自己 → bomb 在轨道/飞行中把路径上的敌弹一路清掉，比「以自机为中心的圈」更符合反馈，也让绕圈有实际意义。
- **验收**：全量 GUT **61 套 / 329 测试 / 3316 断言全绿**。

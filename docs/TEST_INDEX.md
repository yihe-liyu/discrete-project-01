# 测试索引（改哪里 → 看哪条）

> **这是什么**：116 个测试文件的**地图**。一行一条：它保护什么、属于哪一层、多少个用例、有多白盒。
> **这不是**：规格说明、待办清单、覆盖率报告（本项目**没有**覆盖率度量）。
>
> **怎么用**：改动前扫一眼对应层的表，改动后跑门禁。
>
> **维护约定**：加/删测试文件时**顺手改这一行**。这份索引过期 = 比没有更坏。

## 怎么跑

```bash
./test/run_tests.sh                                  # GUT 全量（~22s）
./test/run_tests.sh -gtest=res://test/test_laser.gd  # 单文件（~1.4s）
./test/run_tests.sh -gtest=res://test/test_x.gd -gtest_func=test_xxx   # 单用例
./tools/check_structure.sh                          # 结构契约（组合台/白盒预算/唯一来源/接线唯一）
./tools/verify.sh                                    # 七步门禁（文档哨兵+语法+命名+结构+启动+GUT+所有权）
```

**现状**：116 脚本 / **744 用例（744 通过 / 0 红 —— ✅ 全绿）/ 6827 断言 / 37.576s** / 19 orphans / **0 pending**。

## 分层

| 层 | 文件 | 用例 | 含义 |
|---|---|---|---|
| **A 元守卫 · 工程契约** | 10 | 35 | 跨层的红线/约定，不属任何功能 |
| **B 内核 · 原生 C++ + 桥接** | 30 | 176 | `gdextension/` + `kernel_bridge/`，含 **parity 套件** |
| **C 宿主 · 运行时系统** | 43 | 340 | `scripts/**` 的实体/系统/服务 |
| **D UI / 菜单** | 15 | 102 | `scenes/ui/**` 与 HUD |
| **E 内容** | 4 | 22 | `data/**` 的形状与合法性 |
| **F 工具 · 开发台** | 12 | 66 | `scripts/workbench/**`、创作站 |
| **G 性能基准** | 2 | 3 | 混在门禁里跑 |

> 「白盒」列 = 私有成员访问次数（`._xxx`，粗计）。**它越高，重构时越容易断。**

---

## A · 元守卫 / 工程契约（10 / 35）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_persistence_paths](../test/test_persistence_paths.gd) | R14：运行期代码不得 `ResourceSaver.save` 写 `res://`（导出包只读必失败） | 2 | 0 |
| [test_layer_config](../test/test_layer_config.gd) | 层序契约：相对顺序正确 + 值唯一（防日后改乱） | 4 | 0 |
| [test_config_validation](../test/test_config_validation.gd) | 配置校验层 | 7 | 0 |
| [test_session_state](../test/test_session_state.gd) | per-run static 必须能被 `SaveData.reset_session()` 一次清干净 | 3 | 0 |
| [test_asset_registry](../test/test_asset_registry.gd) | `AssetRegistry` 去 autoload（→ static 表）后静态访问仍可用 | 2 | 0 |
| [test_sfx_mix](../test/test_sfx_mix.gd) | **音效均衡表**不变量：每个音效都有基准 dB / 整表中心化（均值≈0）/ ±12dB 内 | 3 | 0 |
| [test_native_extension_loads](../test/test_native_extension_loads.gd) | 扩展**已构建**时必须真的注册成功 | 2 | 0 |
| [test_coroutine_start](../test/test_coroutine_start.gd) | `CoroutineScript._on_start()` 时机（start 后、首次 `_tick` 前一次） | 2 | 0 |
| [test_param_validator](../test/test_param_validator.gd) | 参数注入校验：打错键名 / 类型不匹配要**响亮报错** | 5 | 0 |
| [test_atlas_layout](../test/test_atlas_layout.gd) | F7 图集哨兵：每格与 1024² 贴图一致、落在图内、内容表 shape 引用能命中 + **格间余量（外来重叠 0 对 / 互不相干最窄缝 ≥1px，「同一张画」两类豁免）** | 5 | 0 |

## B · 内核 · 原生 C++ + 桥接（30 / 176）

### B1 parity 套件（13 文件 / 93 用例）—— 依赖 `test/reference/` 冻结 oracle

> 这一组是整个套件**最值钱**的部分：原生 C++ 逐帧/逐位对照它取代的那份 GDScript 实现。

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_lifecycle_primitives](../test/test_lifecycle_primitives.gd) | 最小原语覆盖（9 Move / 6 Until / **8 Action** / 出界宽限），每条原语一条最小 lifecycle 逐帧对比 | 46 | 1 |
| [test_lifecycle_presets](../test/test_lifecycle_presets.gd) | 其余 preset 逐帧 parity（见 `docs/LIFECYCLE_MODEL.md` §9） | 7 | 1 |
| [test_lifecycle_model](../test/test_lifecycle_model.gd) | `BulletLifecycle` 描述符 ↔ 参考解释器 parity | 3 | 1 |
| [test_native_executor](../test/test_native_executor.gd) | 原生 `behavior_tick`（packed program）↔ 参考解释器**逐位** parity | 9 | 1 |
| [test_native_integrate](../test/test_native_integrate.gd) | 原生积分器 `integrate_batch` ↔ vendored 参照 | 2 | 8 |
| [test_native_storage](../test/test_native_storage.gd) | 原生 `DanmakuStore` 存储/积分/回收语义 ↔ GDScript 1:1 | 2 | 4 |
| [test_native_collision](../test/test_native_collision.gd) | `set_hitbox` / `hit_test` / `query_circle` / `grazed` ↔ 1:1 | 5 | 0 |
| [test_native_broadphase](../test/test_native_broadphase.gd) | 原生 uniform grid 宽相 ↔ `BulletSystem` 1:1 | 3 | 0 |
| [test_native_overlap_pairs](../test/test_native_overlap_pairs.gd) | 原生批量重叠 `overlap_pairs` ↔ `hit_test` 1:1 | 3 | 0 |
| [test_kernel_despawn_drain](../test/test_kernel_despawn_drain.gd) | 多弹**同帧** `request_despawn` 必须**全部**回收 | 2 | 0 |
| [test_bullet_orientation](../test/test_bullet_orientation.gd) | 弹型朝向契约（F7·B）：`rotation_for` 语义 + 到内核弹型的字段传递 | 3 | 0 |
| [test_reference_oracle](../test/test_reference_oracle.gd) | 冻结参照（oracle）自足性：`test/reference/BulletSystem` 可独立 new / spawn / 查询（不依赖任何 autoload） | 2 | 0 |

### B2 原生行为与桥接（12 文件 / 62 用例）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_kernel_swap](../test/test_kernel_swap.gd) | 内核路由（唯一后端）：内核池 + 渲染数据源 + 行为装配 + bomb 宿主节点 | 9 | 3 |
| [test_kernel_host](../test/test_kernel_host.gd) | `KernelBulletHost`：`BulletData→BulletType` 映射 / 内容签名复用 / 纹理旁表 | 8 | 2 |
| [test_kernel_physics](../test/test_kernel_physics.gd) | `KernelBulletPhysics`：敌弹↔自机（命中+擦弹），与旧规则 1:1 | 7 | 0 |
| [test_kernel_render](../test/test_kernel_render.gd) | `BulletMultiMesh` 的**内核快照**渲染路径 + 分组键 | 5 | 12 |
| [test_spell_backdrop](../test/test_spell_backdrop.gd) | **符卡背景 = 每 Boss 一个场景**：宿主层显隐/淡入淡出/层级/同场景不重建不重播 + 换场景换实例 + 淡出中途折返复用 + 滚动层（速度可调/取模无缝）+ plain 模板可用 | 10 | 0 |
| [test_spell_portrait](../test/test_spell_portrait.gd) | **符卡宣言立绘**：右上角→左下角快慢快→淡出；层级在弹幕之下 | 5 | 0 |
| [test_kernel_random](../test/test_kernel_random.gd) | K1：内核 PRNG 确定性（同种子同结果）+ `random_dir` / `chance_toward` | 5 | 0 |
| [test_kernel_reset](../test/test_kernel_reset.gd) | 内核注册表重置（工作台清场：回收 program / 弹型） | 2 | 5 |
| [test_native_behavior_batch](../test/test_native_behavior_batch.gd) | 无状态 `behavior_batch` ↔ 有状态 `behavior_tick` 1:1 + dead 返回 | 3 | 0 |
| [test_native_event_dispatch](../test/test_native_event_dispatch.gd) | 行为事件必须按**事件自己的 program**（`eprog`）派发 | 1 | 0 |
| [test_native_laser_anchor](../test/test_native_laser_anchor.gd) | 端到端桥接：魔理沙激光段必须贴**子机锚点**而非自机 | 1 | 0 |

| [test_native_reflect](../test/test_native_reflect.gd) | `reflect()` 镜面方向（dk=6）：左右翻 x / 上墙翻 y / 角落原路返回 / `angle` 微散 / 未贴边退化 / 编译成 dk=6（**原生专属**：参照解释器是冻结 vendor，不实现新原语） | 6 | 0 |
### B3 Lifecycle 描述符与发射原语（6 文件 / 27 用例）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_lifecycle_signature](../test/test_lifecycle_signature.gd) | b0：结构签名 —— 同结构共用一个原生 program（防 per-instance 爆炸） | 7 | 3 |
| [test_lifecycle_catalog](../test/test_lifecycle_catalog.gd) | L3.5-2：`LifecycleCatalog` —— move+params → `BulletLifecycle` 的映射与缓存 | 5 | 0 |
| [test_emit_variant](../test/test_emit_variant.gd) | 变体发射：`chance_toward` 概率分支号随 emit 事件回传，宿主据此选模板 | 6 | 0 |
| [test_heading_state](../test/test_heading_state.gd) | K2：弹道「朝向」状态化 —— `accel_heading` 与速度解耦 + `forward()` 糖 | 4 | 0 |
| [test_lifecycle_hooks](../test/test_lifecycle_hooks.gd) | b2b：`LifecycleHooks` 名字注册表 + `on_end_call` 用名字 | 3 | 0 |
| [test_lifecycle_port](../test/test_lifecycle_port.gd) | 预拼描述符入口（`{lifecycle}`）：内容自拼，不经命名 move、不涨 `build()` | 2 | 4 |

> ⚠️ 带 `_available()` 守卫的文件（B 层为主，共 11 文件 / **81 用例**）在扩展缺失时会 **pending**。
> GUT 对 pending **不返回非 0**，所以这条「静默跳过」通道已由 `test/run_tests.sh` 的守卫堵住
> —— 详见「已知的坑」第 1 条。

## C · 宿主 · 运行时系统（43 / 340）

### C1 组合根 / 服务 / 时间线（9 / 52）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_composition_root](../test/test_composition_root.gd) | 组合根冒烟：`GameScene` 应创建 Miss 圈 / 特效层并注入（都不再是 autoload） | 8 | 3 |
| [test_stage_host](../test/test_stage_host.gd) | **舞台世界装配**（S4 唯一实现）：建/接分工 + 四个宿主（真游戏 / 工作台 / 组合台）真的在用它 —— 注册表里有自机 / **运行时显式认领 `player`（B2）** / 内核后端拿到同一张注册表 / fx 挂舞台 / 异常路径只交注册表 | 11 | 0 |
| [test_timeline](../test/test_timeline.gd) | `Timeline` —— 事件触发顺序 / 重复 / wait 语义 / loop | 9 | 0 |
| [test_ctx_services](../test/test_ctx_services.gd) | `ctx.*` 服务纯逻辑：无树，校验查询 / 按难度取值 / 生成容错 | 4 | 0 |
| [test_entity_registry](../test/test_entity_registry.gd) | `EntityRegistry` —— 自机/敌机/Boss 的运行时单一真源 + **B6：资源读取走 `PlayerBase` 类型化接口**（不认 `get("resources")` 字符串键） | 6 | 0 |
| [test_stage_director](../test/test_stage_director.gd) | `BossHandle` 句柄纯逻辑：缺槽 / 容错 / 不崩（含 `defeat()`）+ `StageDirector.finish_stage()` 转达 | 11 | 0 |
| [test_stage_runtime](../test/test_stage_runtime.gd) | 关卡收尾语义：`finish_stage()` 发 `stage_cleared`、`stop_stage()` **不**发（拆场景 ≠ 通关） + **B1：入场景走显式类型化 setter（不按属性名探针）** + **B2：自机由组合根注入（不按 World/Player 名找）** | 6 | 0 |
| [test_timeline_sequence](../test/test_timeline_sequence.gd) | `Timeline.sequence_phases`：按序连打阶段（击破→gap→下一张） | 3 | 0 |
| [test_stage_context_lifecycle](../test/test_stage_context_lifecycle.gd) | `StageContext` 服务弱引用 ctx 后不形成 RefCounted 环 + **B3：`ctx.decor` 取背景声明的 `DecorManager`（不按名字找 / 不动态建）** | 3 | 0 |
| [test_timeline_phase_unfreeze](../test/test_timeline_phase_unfreeze.gd) | B 方案回归：Boss 阶段战斗不再冻结时间轴 | 1 | 0 |

### C2 自机 / 道具 / 资源（5 / 63）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_player_resources](../test/test_player_resources.gd) | `PlayerResources` 数值系统：分数/火力/记忆/残机/Bomb（不经全局转发）+ **`use_bombs(n)` 一次扣多、不足扣光** + **残机碎片/整命的返回值 = 「真的多了一条命」** + **`add_bombs(n)` 直接加雷（绕过碎片、封顶）** | 15 | 0 |
| [test_player](../test/test_player.gd) | `Player`：移动 / focus 低速 / 被弹（扣火力 + **复位两步** + **被弹炸弹窗口**：定格/按 bomb 抵消扣 2 雷/只剩 1 扣 1/没雷不开窗/过期照常结算/**窗口内按暂停也能收尾**）/ 数据应用 / 无敌时长链接 DEATH_MENU_DELAY / 无敌闪烁只闪贴图 / 扇形半径与左右边界契约 + **miss 补偿：直接 +2 雷（碎片不动、封顶、被弹炸弹抵消的不给）** | 26 | 4 |
| [test_item](../test/test_item.gd) | 道具系统：掉落收集 / 类型效果 / 防重复 / **拿到完整残机播 `get_player`**（碎片第 5 片 / 整命道具播；没集满 / 满 8 命不播）/ **miss 扇形爆发**（宽限不被吸附 + 等半径弧 + 均匀 20° + 飞完**竖直下落** + **左右夹进框**） | 17 | 3 |
| [test_practice_mode](../test/test_practice_mode.gd) | 练习模式：残机/bomb 归零、火力拉满（须在自机绑定后生效） | 4 | 0 |
| [test_float_damage](../test/test_float_damage.gd) | 小数伤害累积器 | 2 | 4 |

### C3 激光（2 / 25）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_laser](../test/test_laser.gd) | Laser 2.0：骨架采样 + 生长/持续/收缩状态机 + 判定/擦弹 | 23 | 20 |
| [test_marisa_laser](../test/test_marisa_laser.gd) | 魔理沙分段激光：切片 + 偏移无缝 + 编译加载 | 2 | 4 |

### C4 Boss 战（4 / 34）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_boss_phase](../test/test_boss_phase.gd) | 符卡判定：捕获 / 超时 / 时符 / 防双清 / 掉落表 + **收取回报音真值表**（只正常流程干净收取符卡才播）+ **结算信号 `spell_result`**（符卡才发；带击破/用时/作废） | 34 | 20 |
| [test_spell_bonus](../test/test_spell_bonus.gd) | 符卡奖励分规则：初始值 = 难度权重×面序号×50万（EX 权重 2）、非符 0；时限内均匀衰减到 30%、时符不衰减 | 10 | 0 |
| [test_boss_catalog](../test/test_boss_catalog.gd) | Boss 谱（花名册）+ 符卡集合派生 | 8 | 0 |
| [test_boss_encapsulation](../test/test_boss_encapsulation.gd) | 债 E：Boss 封装 —— hp/`boss_data`/`hitbox_radius` 只读 + `hp_changed` 信号 | 3 | 6 |
| [test_boss_targeting](../test/test_boss_targeting.gd) | 自机诱导弹不该追「还没进入战斗的 Boss」（对话/进场期） | 3 | 0 |

### C5 特效 / 背景 / 表现（9 / 48）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_miss_circle_layer](../test/test_miss_circle_layer.gd) | Miss 圈特效：autoload → 场景节点 + 组合根注入 | 8 | 7 |
| [test_decor_manager](../test/test_decor_manager.gd) | `DecorManager`：静态路径（SCISSOR 层）性能优化后行为不变 | 6 | 1 |
| [test_stage_background](../test/test_stage_background.gd) | 背景环境接线：**父节点 `_ready` 之前应用预设也必须生效**（子节点 `_ready` 先于父节点 ⇒ 旧实现静默 no-op，练习模式改预设不变）+ `build_environment()` 每次全新实例（防「越重跑越暗」）+ **预设必须带真天球且不被 `fog_sky_affect` 洗掉** + **地平线联动真的生效** + **`Sky.radiance_size` 必须压低**（默认 256 ⇒ 每帧重算立方图，实测 8.9 → 44.8 ms）+ **雾色不许是亮灰**（`Color.DARK_GRAY` = CSS #A9A9A9 = 0.663 会把远处洗亮）+ **相机按类型找**（不按名字：改名不再静默改变行为）+ **背景视口必须 `own_world_3d = true`**（否则与根视口共享 World3D，环境被同 world 的另一个 `WorldEnvironment` 抢） + **B3：场景必须声明 `DecorManager` 子节点**（`get_decor_manager()` 按类型解析） | 9 | 0 |
| [test_screen_shake](../test/test_screen_shake.gd) | `ScreenShake`：trauma 按 DECAY 衰减、sustain 保持到清零、强度封顶 1 | 6 | 6 |
| [test_hit_effect](../test/test_hit_effect.gd) | 通用击中特效：一个类驱动所有特效场景（数据驱动验证） | 6 | 0 |
| [test_spawn_fx](../test/test_spawn_fx.gd) | 出生雾 / 消弹消散统一特效模型（`EffectType` + 行 `fx_type`） | 5 | 2 |
| [test_fx_pool](../test/test_fx_pool.gd) | `FxPool` 池化语义（取代 `HitEffectPool` autoload） | 3 | 1 |
| [test_field_filter_layer](../test/test_field_filter_layer.gd) | 场地颜色滤镜：透明色不播；有色时铺满游戏框、从框中心扩圆 + **被弹炸弹窗口的框内整体渐显红滤镜**（定格中也得走 → `ignore_time_scale`；窗口关则渐隐收起） | 5 | 0 |
| [test_fog_texture](../test/test_fog_texture.gd) | 雾纹理无缝性：`fract(q)` 平铺采样 noise | 1 | 1 |

### C6 Bomb / 机制（3 / 17）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_recent_mechanics](../test/test_recent_mechanics.gd) | `out_grace` 真链路（`grace()` → `BulletType` → 原生行）/ `open_reduce`（开局减伤）/ `boss_name`（记录补全） | 7 | 6 |
| [test_bomb_data](../test/test_bomb_data.gd) | `BombData` 家族：基类（外观/编队/无敌）+ 子类 | 5 | 0 |
| [test_mist_bomb](../test/test_mist_bomb.gd) | `KernelMistBomb`：分阶段展开 + 跟随自机 + 椭圆持续伤害/清弹 | 5 | 9 |

### C7 存档 / 回放 / 随机（5 / 21）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_replay_recorder](../test/test_replay_recorder.gd) | `ReplayRecorder` 录输入基础设施 | 7 | 0 |
| [test_rng_seed](../test/test_rng_seed.gd) | RNG 可复现性 —— Replay 系统的基础保证 | 5 | 0 |
| [test_clear_data](../test/test_clear_data.gd) | 「清空数据」：符卡记录 + 高分归零；**设置保留** | 3 | 0 |
| [test_spell_book_debug](../test/test_spell_book_debug.gd) | 调试：一键解锁所有符卡练习（符卡 + 非符） | 4 | 0 |
| [test_enemy_data_serializable](../test/test_enemy_data_serializable.gd) | 债 C 第一步：`EnemyData` 可序列化 + `validate()` | 3 | 0 |

### C8 对话逻辑 / 内容目录（3 / 33）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_dialogue_preview](../test/test_dialogue_preview.gd) | 对话预览交互契约：**默认不自动播**（进场景预选但不播 / 换段只选中并停演出 / 换脚本同理） | 3 | 0 |
| [test_dialogue_steps](../test/test_dialogue_steps.gd) | 对话系统：`StageState` / `DialogueSteps` DSL / `DialogueRunner`（纯逻辑，不进树） | 28 | 0 |
| [test_content_catalog](../test/test_content_catalog.gd) | `ContentCatalog` 目录扫描器（创作台）：角色分类 / 注解覆盖 / 边界 / const META / 引用反查 · **`pre_move_script` 反推角色** · **显示名只认「顶部且隔开」的注释块** · **阶段按 uid 升序（符卡优先、非符路径定序）** · `@role` 补空缺不算冲突 · **角色标签只在敌人脚本里砍、前缀要「标签形状」** | 9 | 0 |
| [test_stage_catalog](../test/test_stage_catalog.gd) | `StageCatalog`：注册表优先 → **嵌套目录扫描兜底**（回归：曾只扫顶层 .tres）+ 显示名回落 `Stage %d` | 3 | 0 |

## D · UI / 菜单（15 / 102）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_score_popup](../test/test_score_popup.gd) | 吃道具得分浮字：`Item.collect` 发事件 → `ScorePopupLayer` 原位显示；**金色只属于「点」**（P 点强收/过线都不金色） | 12 | 9 |
| [test_phase_result_banner](../test/test_phase_result_banner.gd) | **符卡结算横幅**：干净收取 / 失败（超时 / miss·bomb 作废）的文案与分数行显隐 + 渐显→停→渐隐顺序 + 落点（倒计时之下、报幕大字之上 —— 时长因此自由） | 12 | 3 |
| [test_announce_label](../test/test_announce_label.gd) | `AnnounceLabel`：右停落点（视觉盒贴边）+ 场景声明的底衬/Bonus/Capture 子节点 | 12 | 0 |
| [test_boss_hud](../test/test_boss_hud.gd) | `BossHud`：名字文字/显隐 + 阶段进度点显隐 | 10 | 10 |
| [test_spell_practice_menu](../test/test_spell_practice_menu.gd) | 符卡练习菜单：难度槽（锁定 "?"、导航跳过）+ 切 stage 重建二级 + 非符三级不显名字但保持等高 + **舞台名走 `StageCatalog`** + **二级超长开窗滚动 + 滚动提示** + **人物选择：进场取上次选的、从练习返回回到同一个人** | 19 | **45** |
| [test_player_data_menu](../test/test_player_data_menu.gd) | 玩家数据菜单·符卡记录页：**列全部符卡**（来源=花名册）+ **三档显示**（未遇见 ？？？ / 遇见过真名 / 收取过蓝）+ 分页按面板实测 | 4 | 0 |
| [test_dialogue](../test/test_dialogue.gd) | 对话播放层：`DialogueBox` 步骤驱动（台词内联 DSL） | 4 | 7 |
| [test_bgm_hint](../test/test_bgm_hint.gd) | BGM 提示：曲名解析 + 播放时提示显示 | 3 | 0 |
| [test_boss_indicator](../test/test_boss_indicator.gd) | Boss 位置指示器：生成 / 跟随 x / 框外对齐 / 随 Boss 销毁 | 3 | 10 |
| [test_boss_ui](../test/test_boss_ui.gd) | `BossUI` 场景声明式建树（R21）：倒计时与阶段点模板都在 `.tscn` + **符卡结算横幅**：`spell_result` → 出场 / **阶段边界不掐它（与间隔解耦）** / 第二张替换第一张 / 作废不显示分数 | 11 | 0 |
| [test_player_spell_ui](../test/test_player_spell_ui.gd) | `PlayerSpellUI`：订阅 `player_bomb`，非空名字才播大字报 | 2 | 0 |
| [test_option_menu](../test/test_option_menu.gd) | 选项菜单「清空数据」：无 `def` 崩溃回归 + 二次确认 | 2 | 14 |
| [test_dialogue_pause](../test/test_dialogue_pause.gd) | 暂停菜单期间对话 WAIT/auto_advance 计时应冻结 | 1 | 8 |
| [test_menu_nav](../test/test_menu_nav.gd) | `MenuNav` 子页面容器注入契约（R2：不再字符串搜 `PageHost`） + **B4：覆盖层暂停/恢复走显式信号（不再 `set_state.call_deferred` 动态方法名）** + **B5：暂停菜单路径唯一来源常量** | 5 | 0 |
| [test_game_over_menu](../test/test_game_over_menu.gd) | **GameOverMenu 标题不再静默 no-op**：本引擎不解析节点类型 `@export`（`.tscn` 的 `title_label = NodePath(...)` 被丢弃）⇒ 入树一帧后按路径/类型兜底解析出 `title_label` + `set_title()` 真把文字写进那个 `Label` | 2 | 0 |

## E · 内容（4 / 22）

> 只测**形状与合法性**，不测数值。数值该在 Godot 里调，不该在测试里锁。

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_data_validity](../test/test_data_validity.gd) | **内容校验**：遍历全部阶段数据（hp/时限/双脚本槽/uid 全局唯一）+ 舞台显示名（只锁"配了名"，不锁叫什么）+ Boss 符卡背景可加载—— 不写死路径，改名不红、数据违规才红 | 7 | 0 |
| [test_probe_descriptor](../test/test_probe_descriptor.gd) | spell053「哆来咪三符」→ 原生描述符的形状（单相位 / 变体两模板 / 难度分派） | 5 | 1 |
| [test_stage01_dialogue](../test/test_stage01_dialogue.gd) | 第一面战前对话构建：台词/说话者/表情/事件顺序 | 9 | 0 |
| [test_enemy04_move](../test/test_enemy04_move.gd) | enemy04 移动：匀速下移直到离开屏幕（弹幕结束后不中断） | 1 | 0 |

## F · 工具 · 开发台（12 / 66）

> ✅ **这一层已接缝化**（2026-09-30，S1）：原先 26 个用例里 181 处私有成员访问，现在**0**——
> 六个文件全部改走 `BenchBase` / `CreationStation` / `CatalogPanel` 的**公开接口**（见下节）。
>
> ✅ **S2 又抽出一个可无树测试的服务**：`HotReloadService`（防抖 / 连坐 / 失败保旧版 / 基线刷新），
> 于是 `test_hot_reload` 不用 Control 台子就能验这四条规则（6 个用例）。
>
> ✅ **S3 再把"播放状态机"与"书签模型"从 `workbench.gd` 里抽出来**（`Playback` / `Bookmarks`）：
> 暂停 / 速度 / 快进 / 逐帧 / 静音 + 提取 / 持久化 / 合并 全部变成可无树断言的纯决策（31 个用例）。
> 抽的过程中**顺手抓到一个真 bug**：`BookmarkCache.load()` / `has_cache()` 从来没被调用过 ——
> 人工打点只写不读，**重启工作台就全丢**（"可编辑、持久化"名不副实）→ 已修 + 立回归。

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_enemy_rig](../test/test_enemy_rig.gd) | 敌人组合台：壳组装 / 真实生成 / 热重载重演（`load_script` / `spawn_at` / `force_hot_reload`） | 4 | 0 |
| [test_bullet_rig](../test/test_bullet_rig.gd) | 弹幕试验台热更新：重载成功自动重演 / 失败保留旧版（`poll_hot_reload` / `age_watch_mtime` / `param_panel`） | 3 | 0 |
| [test_creation_station](../test/test_creation_station.gd) | 创作台（三合一）：页签切换 / 实例保持 / 运行时清理 / 预设路由切台+装配（`open_slot` / `current_view` / `bench_instance`）· **真点击验页签不被子视图吃掉**（作者报的回归） | 5 | 0 |
| [test_catalog_panel](../test/test_catalog_panel.gd) | `CatalogPanel` 目录树渲染：组头完整 / 重名消歧 / 拖拽 / **搜索真的在筛**（原先那半条是空转的） | 3 | 0 |
| [test_phase_rig](../test/test_phase_rig.gd) | 阶段组合台：壳副本 / 双槽默认 / 开演真实生成（`select_phase` / `hp_value` / `selected_shoot_script` / `play`） | 4 | 0 |
| [test_workbench_align](../test/test_workbench_align.gd) | 工作台坐标一致性：场地 / `BulletManager` / `BenchWorld` 同在画布坐标（`playfield` / `bullet_manager` / `bullet_global_position`） | 1 | 0 |
| [test_bullet_shell](../test/test_bullet_shell.gd) | `BulletShell`（试验台"壳"）：自由方向 + 显示辅助 | 3 | 0 |
| [test_hot_reload](../test/test_hot_reload.gd) | **热更新管线服务**（无树）：防抖要稳够才放行 / 轮询间隔节流 / 没改就静默 / 失败保旧版 / 基线刷新不反复重载 / 连坐同目录 / 关掉即惰性 | 6 | 0 |
| [test_playback](../test/test_playback.gd) | **播放状态机**（无树）：暂停幂等 / 暂停先收快进 / 快进压过档位 / 物理步上限与 BGM 音高 / 到达收尾（含无 runner）/ 慢放音高不脱钩 / 跳转容差 / 逐帧放行物理 + 防重入 / 静音三源 | 20 | 0 |
| [test_bookmarks](../test/test_bookmarks.gd) | **书签模型**（无树）：人工覆盖同刻自动并排序 / adopt 存副本 / 静态提取 / **人工打点重开还在**（只写不读的回归）/ 哈希不符保人工 / 串档不认 / 内容哈希可复现 | 11 | 0 |
| [test_param_panel](../test/test_param_panel.gd) | **参数面板键名列**：不换行 / 不截断 / 悬停看全名 / 列宽放得下最长键名（作者报的 `move_spee`/`d` 断词回归；夹具带长键名哨兵） | 2 | 0 |
| [test_bookmark_extractor](../test/test_bookmark_extractor.gd) | 书签提取器：字面量 + 循环展开 | 4 | 0 |

## G · 性能基准（2 / 3）

| 文件 | 保护什么 | 用例 | 白盒 |
|---|---|---|---|
| [test_perf_laser](../test/test_perf_laser.gd) | 激光性能：100 条激光每帧 step 开销 | 2 | 0 |
| [test_perf_stage_context](../test/test_perf_stage_context.gd) | `StageContext` 创建开销（每颗协程弹 bind 时 new 一次） | 1 | 0 |

---

## ✅ D3 债已还：181 → 0 处私有成员访问（2026-09-30 · S1 接缝化）

原状：`workbench.gd` 是排着要拆的上帝对象（D3：694 行 + 3 个超长 `_build_ui`），
六个测试文件**直接摸它的内部**（`_cur_script` / `_watch_paths` / `_view` / `_divider_y` … **181 处**）
—— 于是"想重构"和"测试会一起断"互相锁死。

**S1 只做一件事：先立公开接缝，把测试抬到接口上。**
- `BenchBase`：把三台重复的那几份状态上移（`_cur_script` / `_cur_script_path` / `_param_panel` /
  `_reload_status` / `_catalog` / `CATALOG`），并公开
  `load_script` / `current_script` / `current_script_path` / `watch_paths` / `set_watch_paths` /
  `age_watch_mtime` / `poll_hot_reload` / `force_hot_reload` / `reload_status_text` / `param_panel` /
  `catalog` / `selected_index` / `stage_runtime` / `bullet_manager` / `playfield`。
- 三台各自补语义接缝：`fire_once` / `set_burst` / `burst_remaining`（弹幕台）、
  `spawn_at` / `select_difficulty`（敌人台）、
  `select_phase` / `play` / `clear_all` / `hp_value` / `time_value` / `move_slot_index` /
  `set_move_slot_index` / `set_shoot_slot_index` / `selected_move_script` / `selected_shoot_script` /
  `move_script_path` / `boss_spawn_pos` / `set_boss_spawn_pos` / `boss_scene`（阶段台）。
- `CreationStation`：`slot_names` / `slot_count` / `current_slot` / `current_view` / `bench_instance` /
  `open_slot` / `route_preset`（原私有 `_route_preset` 正名）。
- `CatalogPanel`：`divider_y` / `split_area_height` / `drag_divider` / `set_search_text` / `tree` /
  `handle_tree_input` / `info_card`。
- `BulletManager.bullet_global_position(id)`：按 id 取全局位置 —— 外面不必再摸内核宿主的私有存储。

> 接缝**不是为测试开的旁路**：`load_script()` 就是"用户在下拉里选一条"、
> `force_hot_reload()` 就是"防抖到点那一次"、`open_slot()` 就是"用户点页签"。
>
> 顺带发现的**空转测试**：`test_catalog_panel` 的搜索那半条以前是假绿 ——
> 直接写给 `_search.text` **不会**触发 `text_changed`，而未筛选的树本来就只有 2 条含"夹具符卡"
> ⇒ 断言恒真。接缝化时补成"真的在筛"（搜到 1 条 / 2 条 / 0 条 / 清空恢复）。

> 全项目白盒 Top（含非 workbench，未动）：`test_spell_practice_menu`(45)、`test_laser`(20)、
> `test_boss_phase`(20)、`test_option_menu`(14)。

### S2 / S3：把"规则"从上帝对象里搬出去（无树可测）

S1 → S2 → S3 是一条链：**先立接缝**（测试抬到接口上）→ **再搬规则**（每搬一块，就给那块规则配上无树用例，
不必借 Control 台子 + 真跑帧）。搬走的两块：

- `hot_reload_service.gd`（152 行）—— 防抖 / 连坐重载 / 失败保旧版 / 基线刷新（6 个用例）。
- `playback.gd`（201 行）—— 暂停 / 速度 / 快进 / 逐帧 / 静音。宿主只剩"下发"：
  `changed` 一次把 `tree.paused` / `Engine.time_scale` / 物理步上限 / BGM 音高 / 总线静音按**投影**写出去。
- `bookmarks.gd`（85 行）—— 自动书签静态提取 + 人工打点持久化 + 合并视图；
  `bookmark_panel.gd` 从"自持一份数据"变成**纯视图**（数据只有一份，在 store 里）。

**诚实记账**：方案里我写的是"`workbench.gd` 695 → ≤200"，**这个估计是错的**（和 S2 那次估错同因）——
S3 实际只把它搬到 **695 → 619 行（-76）**，因为：
① S1 自己加了 ~160 行接缝与文档，起点就不是 695；
② 抽服务的同时宿主多了"下发"这一层（`_apply_playback_runtime` 等 ~40 行，本来散在 6 处副作用里）；
③ 剩下的大头是**装配代码**（`_build_ui` / `_setup_world` / `_load_stage`）—— 那正是 **S4** 的活。
S3 的价值不在行数，在 ①**31 个新用例**（这些规则原先覆盖率是 0）②**抓到一个真 bug**（见下）③播放状态与书签数据各只剩**一份**。

> **S3 顺手抓到的真 bug**：`BookmarkCache.load()` / `has_cache()` 写得挺好的，**但从来没被调用过** ——
> 人工打点只写不读，重启工作台就全丢（面板注释还写着"可编辑，持久化"）。
> 抽 store 时把"读回来"接上，并立 `test_manual_survives_reopen` 回归
> （反向验证过：把读回那行去掉 → 该用例精确红在"人工打点必须读回来"）。

## ⚠️ 已知的坑

1. **「静默跳过」通道（已堵，2026-09-22）**。GUT 对 pending/risky **不返回非 0**，
   于是「其实没跑」会伪装成全绿。11 个文件 / **81 用例**挂在 `ClassDB.class_exists("DanmakuStore")` 上，
   扩展缺失时集体 pending。
   **实测更正**：全量套件在缺扩展时**本来就是红的**（`KernelBulletHost` `push_error` → GUT 判
   Unexpected Errors，退出码 1；`test_native_extension_loads` 也红），`verify.sh` 第 3 步同样会红。
   ——早先「单跑 `run_tests.sh` 会静默全绿」的说法，是只单跑了一个文件就外推，**那个结论是错的**。
   **已加守卫**：`test/run_tests.sh` 现在 **`Risky/Pending` 行出现即失败**（并打印是哪几条）+
   加载失败即失败；已双向验证（造一个 pending → exit 1；撤掉 → exit 0）。
2. **perf 测试混在正确性门禁里**（G 层 2 个）。CI 机器负载抖动时可能误报。
   *建议*：挪到 opt-in（如 `-gdir=res://test/perf_stress` 或按 tag 跳过），让 22s 门禁保持确定性。
3. **无覆盖率度量**（GUT 自带没有）。705 用例 ≠ 覆盖面；`scripts/workbench`(4835 行) / `scenes/**/*.tscn`(2201 行)
   主要靠本层测试 + `verify.sh` 的启动烟测兜底。**在没有覆盖率之前不要按数量删测试**——那是盲删。
4. **退出噪音**：19 orphans + 31452 ObjectDB 泄漏 + 26 resources 仍在使用。
   现在只是噪音，但会掩盖将来真正的泄漏。*建议*：立预算（元测试断言 orphans == 0）。

## 加 / 删测试的判据

> **它断言的，是「改了要警觉」还是「改了无所谓」？** 前者留，后者删。

- ✅ **该测**：跨层引用能否解析、结构契约、相对关系（如 `LayerConfig.EFFECT > ENEMY_BULLET`）、逐位 parity。
- ❌ **不该测**：内容数值（`hp == 4000`、`发弹间隔 == 0.07`）——那是把内容逐字抄进测试，改一次断一次。
- ⚠️ **谨慎**：内容**形状**（如 `act_count == 3`）。它只在形状真的变了时红——红的时候看一眼，是你要的吗。

## 内容绑定契约（2026-09-23 立）

> **测试对内容的依赖，应等于它要验证的内容属性。**
> 机制测试绑内容 = 白交改名税；内容校验不绑内容 = 什么都没验。

| 类别 | 内容依赖 | 写法 | 谁 |
|---|---|---|---|
| **机制测试** | ❌ 零 | **自建夹具**：合成 `PhaseData` / `BulletData`，或用 `test/fixtures/**`；需要"目录"就注入夹具根 | `test_spell_practice_menu`（经 `info["boss"]` 注入）、`test_phase_rig`、`test_workbench_align`、`test_boss_phase`、`test_content_catalog` |
| **内容校验** | ✅ 必须 | 读**真实内容**，但**不写死路径**：遍历目录扫到的全部，断言**不变量** | `test_data_validity`（遍历全部阶段） |
| **内容形状/行为** | ✅ 故意 | 绑具体内容 —— 红了是**信号**（作者复核），不是噪音 | `test_probe_descriptor`、`test_enemy04_move`、`test_stage01_dialogue` |

**可注入的接缝 / 现成夹具（要隔离内容就从这里走）**：

- `test/fixtures/fixture_lib.gd` —— 夹具工厂：`player_data()`（含 SpriteFrames + `PlayerShootScript`）、`effect()`
- `test/fixtures/param_panel_probe.gd` —— 组合台参数面板夹具（float/int/Vector2/Color + 零值陷阱 + **长键名 `radial_spawn_delay` 当键列宽度哨兵，别删**）
- `test/fixtures/player_shoot_probe.gd` —— 机体射击脚本夹具（`Player` 有 `is PlayerShootScript` 断言，必须继承它）
- `test/fixtures/{no,lifecycle}_port_behavior.gd` / `param_probe.gd` —— 通用 `extends CoroutineScript` 替身
- `ContentCatalog.scan(root)` —— 传夹具根目录（已支持）
- `BossCatalog.set_catalog_override({stage: [BossData]})` + `clear_catalog_override()` —— 直接投名册
  （⚠️ static 缓存全局可见，**测完必须 clear**，否则污染后续测试）

**当前仍绑 `res://data/` 的 7 个文件（均为「该绑」类，别去夹具化）**：
`test_data_validity`（内容校验）· `test_dialogue`（profile 遍历校验）· `test_bomb_data`（出货 bomb 类型）·
`test_mist_bomb`（出货 mist bomb 类型）· `test_probe_descriptor`（内容形状）·
`test_enemy04_move` / `test_stage01_dialogue`（内容行为）

**判据一句话**：**测试里出现 `res://data/...` 硬路径之前，先问"我验的是机制还是这批数据？"**
机制 → 换成夹具；数据 → 改成"遍历 + 不变量"，别钉单个文件。

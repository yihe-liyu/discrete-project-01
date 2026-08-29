# 📐 东方星 STG 引擎 — 系统规格书（代码真实现状）
## 版本 2.0 · 2026-06-24
## 基于实际代码逆向整理
## ⚠️ 最后校验：2026-08（同步 8 月目录重组 / 空间哈希 / LaserEngine / 练习单驱动，含 §10 协程约定）

> **维护提示**：本规格书声称描述代码现状，若你改动了架构，请同步更新本文档。
> 检查点：输入映射在 project.godot 而非代码注入；GameState 已拆分出 SpellBookManager/SaveManager。

---

## 1. 总体架构

```
┌─────────────────────────────────────────┐
│            Autoload 层                  │
│  GameManager  GameState  GameEvents     │
│  StageManager  AudioManager  RNG       │
│  BulletManager                          │
│  HitEffectPool  MissEffectManager      │
│  AssetRegistry  LayerConfig            │
├─────────────────────────────────────────┤
│             协程（业务逻辑）             │
│  CoroutineScript  Timeline             │
│  ← 全部通过 StageContext 访问系统       │
├─────────────────────────────────────────┤
│               Scene 层                  │
│  MainMenu → DifficultyScreen           │
│          → CharacterScreen             │
│          → GameScene                   │
├─────────────────────────────────────────┤
│             实体层                       │
│  Player  Enemy  Boss  Bullet           │
│  LaserBeam  Item  ItemPool              │
│  EnemyVisual  HitEffect                │
│  BackgroundStage  BackgroundPlane      │
│  DecorManager  LaserEngine             │
├─────────────────────────────────────────┤
│             数据层                       │
│  StageData  PhaseData  BossData        │
│  EnemyData  BulletData  PlayerData     │
│  StageRegistry                         │
│  SpellRecord  SpellRecordBook          │
│  CharacterProfile                      │
└─────────────────────────────────────────┘
```

### 数据流向规则
```
CoroutineScript → StageContext → 系统 → 实体
      │                   │
      └─ 只读 GameState ──┘

实体 → 系统（碰撞/回收）→ GameState（改状态）
                        → GameEvents（通知 UI）
```

---

## 2. 系统清单

### 2.1 GameManager — Autoload 单例
| 项目 | 内容 |
|------|------|
| **职责** | 应用级状态机 + 模块门面 |
| **状态** | `enum AppState {MENU, PLAYING, PAUSED, TRANSITIONING}` |
| **子模块** | SceneTransition, MenuNav |
| **暴露** | `change_scene(path, target_state)`, `push_page(path)`, `pop_page()`, `push_overlay_menu(menu)`, `pop_overlay_menu(menu)`, `pause_game()`, `resume_game()`, `toggle_pause()` |
| **输入** | `_process` 拦截 ui_pause 推暂停覆盖层；覆盖层开着时不处理 |
| **状态规则** | 通过 `_set_state()` 修改，发出 `game_state_changed` 信号 |
| **场景切换** | `change_scene()` → `_set_state(TRANSITIONING)` → 清页面+覆盖层 → await SceneTransition → 更新 `current_scene_path` → `_set_state(target_state)` |
| **菜单导航** | 所有页面 push/pop 统一走 MenuNav（普通页面 + 覆盖层两层栈） |
| **页面契约** | 页面必须有 `finished(result: Dictionary)` 信号；推荐继承 `BasePage` / `NavPage` |
| **输入映射** | 定义在 `project.godot` 的 `[input]` 节（ui_accept/ui_cancel/ui_pause/ui_*+WASD/memory_release/shoot/focus 等） |

### 2.2 GameState — Autoload 单例
| 项目 | 内容 |
|------|------|
| **职责** | 全局游戏数据 **唯一真源** |
| **拥有** | `current_score`, `lives(bound 0~8)`, `bomb_count(bound 0~8)`, `power_raw(bound 0~300)`, `max_point`, `memory_value(bound 0~100)`, `graze_count`, `selected_difficulty`, `selected_character`, `current_stage_id` |
| **附加** | `active_enemies(Array)`, `player(Player弱引用)`, `spell_book`, `stage_registry`, `high_scores(Dictionary)` |
| **练习模式** | `is_practice_mode`, `is_stage_practice`, `practice_phase(PhaseData)`, `practice_boss_scene(PackedScene)`, `practice_name`, `practice_stage_id`, `practice_phase_index`, `practice_background(PackedScene)`；入口 `start_practice(phase, boss_scene, p_name, stage_id, phase_index)` |
| **读写规则** | 系统通过方法读写（`add_score()`, `add_power()`, `collect_life_fragment()`），不直接改属性 |
| **禁止** | 协程/实体直接改 `current_score` / `lives` / `power_raw` |
| **reset_all()** | 关卡开始时调用，清零运行时数据；`reset_practice()` 设置满P/0命 |
| **memory 系统** | `_process` 每秒恢复 `MEMORY_REGEN=0.05`（仅 PLAYING 时）；影响自机弹染色和伤害 |
| **符卡簿** | `_load_spell_book()` 从 `spell_records.tres` 加载；`unlock_spell(pid)` 见到即记；`record_spell(pid, captured, score, elapsed)` 记录尝试；`record_practice(pid, captured)` 记录练习 |
| **High Score** | 通过 ConfigFile 持久化到 `user://save_data.cfg`；`save_high_score(stage_id, score)` |
| **关卡数据查找** | `_find_stage_data(stage_id)` → 先查 `stage_registry`，回退扫目录 |

### 2.3 StageManager — Autoload 单例
| 项目 | 内容 |
|------|------|
| **职责** | 关卡生命周期 + 敌人生成门面 |
| **流程** | `load_stage(data)` → `GameState.reset_all()` → 创建 CoroutineScript → StageContext → `stage_script.start(ctx)` → 自动启动背景上的 CoroutineScript |
| **背景** | `current_background` 由 GameScene 设置 |
| **停止** | `stop_stage()` 清敌人、清弹幕、清背景引用 |
| **敌人生成** | `spawn_enemy(data, pos)` → instantiate `enemy.tscn` → 挂到 World 下 → `enemy.start()`；`spawn_boss(data, pos, defer, ctx)` → Boss 类 |
| **子弹生成** | `spawn_bullet(data, pos, dir)` → 委托 BulletManager |
| **添加节点** | `add_enemy_to_scene(node)` → 查找当前 Scene 的 World 节点作为父节点 |

### 2.4 BulletManager — Autoload Node2D
| 项目 | 内容 |
|------|------|
| **职责** | 子弹/激光门面 |
| **子模块** | BulletPool, BulletPhysics, LaserEngine, DeathClear |
| **每帧** | `_physics_process`: DeathClear.process → LaserEngine.step → BulletPhysics.process_collisions → 出屏回收 |
| **多网格** | `use_multi_mesh`（默认 true），通过 BulletMultiMesh 批量渲染 |
| **暂停** | `_processing_paused` 时跳过 `_physics_process` |

#### 2.4.1 BulletPool
- 池大小 `POOL_SIZE=4000`，硬上限 `MAX_TOTAL=5000`
- `shoot(data, pos, dir)` → 从池取 → bind → 加入 `active_bullets`
- `return_bullet(bullet)` → 停协程+队列清理 → 入池（或 free 如果池满）
- `_return_to_pool` 清理雾 + 协程 + 信号连接
- `is_offscreen()` 使用 90px 边距扩展判定

#### 2.4.2 BulletPhysics
- 碰撞见 §2.4.2.1（空间哈希）
- 命中检测：圆形（半径和）/ 矩形（OBB 最近点）
- 擦弹：`on_graze()` → graze+1, score+10, memory+`MEMORY_GRAZE=0.25`

#### 2.4.2.1 空间哈希（SpatialHash）
- `SpatialHash`（`scripts/bullet/spatial_hash.gd`）：网格分区，把 O(n×m) 碰撞降到 O(n+k)
- `process_collisions` 每帧重建 `_enemy_hash`（敌人）与 `_bullet_hash`（敌弹），
  玩家弹通过 `_enemy_hash.query(pos, 半径)` 取候选敌人，敌弹通过 `_bullet_hash.query(player, graze_r+8)` 取候选
- 自机为中心一次 `query`，覆盖命中半径（~11px）与擦弹半径（~46px）

#### 2.4.3 LaserEngine
- 池大小 64（`POOL_SIZE`）
- `step(delta)`：激光更新 → 玩家碰撞检测 + 擦弹
- `clear()` 让所有激光立即淡出

#### 2.4.4 DeathClear
- 每帧膨胀圈内消除敌弹
- `start_death_clear(pos, max_radius, duration, start_radius)`

### 2.5 AudioManager — Autoload 单例
| 项目 | 内容 |
|------|------|
| **BGM** | 单路 AudioStreamPlayer；`play_bgm(stream, gap=0.0)` — 同流不重复，无 crossfade |
| **SFX** | 16 路池（`SFX_POOL_SIZE=16`）；`play_sfx(stream, vol_db)` → 同帧同流去重（`_played_this_frame`），全忙时踢最老的 |
| **音量** | `master_volume`, `bgm_volume`, `sfx_volume`（线性 0~1 → dB 转换）|
| **暂停** | 监听 `game_state_changed` → BGM `stream_paused = true/false`（SFX 由 tree.paused 自动处理） |
| **stop_bgm()** | 直接停止，无渐弱 |

### 2.6 RNG — Autoload 单例
| 项目 | 内容 |
|------|------|
| **职责** | 可复现随机数（replay 基础）|
| **所有随机数必须走 RNG** | `RNG.randf()`, `RNG.randi()`, `RNG.randf_range()`, `RNG.randfn()` |
| **禁止** | 全局 `randf()` `randi()` |

### 2.7 HitEffectPool — Autoload 单例
| 项目 | 内容 |
|------|------|
| **职责** | 命中特效对象池，按 PackedScene 分池（每场景 8 实例上限）|
| **play(scene, pos)** | 从池取 → reparent 到 World → 激活 |
| **clear_all_pool()** | 清空所有池实例 |

### 2.8 MissEffectManager — Autoload CanvasLayer
| 项目 | 内容 |
|------|------|
| **职责** | 全屏圆形 Miss 特效（ShaderMaterial）|
| **容量** | 最多 8 圈同时显示 |
| **add_circle(world_pos, duration, max_radius, start_radius, start_delay)** | 添加一个 Miss 圈 |
| **每帧** | `_process` 更新 shader uniform（位置/半径/alpha）→ 过期移除 |
| **clear_all()** | 清空所有 |

### 2.9 Item 系统

#### Item — Area2D (class_name Item)
| 项目 | 内容 |
|------|------|
| **类型枚举** | `enum Type {POWER, POINT, LIFE_FRAGMENT, BOMB_FRAGMENT, LIFE_FULL, BOMB_FULL}` |
| **节点** | Area2D + Sprite2D + CollisionShape2D(Circle) |
| **运动** | 上抛初速(0, -180)px/s → 重力 240px/s² → 终端 180px/s |
| **收集** | 碰撞 Player / 靠近自机 128px（focus 时 192px）/ 自机 y<256px → 自动飞向自机 800px/s |
| **出屏** | y > 960 → `_recycle()` |
| **dead 锁** | `_dead` 标志在所有回调入口检查 |

#### ItemPool — Node
| 项目 | 内容 |
|------|------|
| **池容量** | 64 个 |
| **模式** | 常驻 tree（World/ItemPool），`spawn()/recycle()` 无 queue_free |
| **recycle()** | 已在池中跳过，`_pool` 满时 queue_free |
| **生成** | GameScene._ready 时创建并挂到 World 下 |

#### 掉落配置 (EnemyData / PhaseData)
| 项目 | 内容 |
|------|------|
| `item_power/point/life/bomb` | 各掉几个 |
| `item_life_full/bomb_full` | 完整残机/Bomb 个数 |
| `item_scatter` | 生成位置随机散布范围（默认 50px）|

#### 得分逻辑
| 项目 | 内容 |
|------|------|
| **Point** | `GameState.add_max_point()`: +max_point 分, max_point+=10 |
| **Power** | `GameState.add_power(1)`: power_raw+1，上限 300（4.00 火力）|
| **碎片** | `collect_life_fragment()`/`collect_bomb_fragment()`: 5碎片→1完整 |
| **完整** | `collect_life_full()`/`collect_bomb_full()`: 内部调 5×fragment |
| **上限** | lives≤8, bomb_count≤8 |

### 2.10 CoroutineRunner — Node (class_name)
| 项目 | 内容 |
|------|------|
| **机制** | `run(callable)` → `_physics_process` 每帧调 callable |
| **返回值约定** | `float/int > 0` → 等待秒数 / `true` → 下帧再调 / `false/null` → 结束 |
| **计时** | `_clock` 累积 `_physics_process` 的 delta，tree.paused 时自动冻结 |
| **stop()** | 清全部任务，发 `cancelled` 信号 |
| **run_parallel()** | 追加并行任务，不停止已有 |
| **信号** | `finished()` — 所有任务结束；`cancelled()` — 被 stop |
| **Task** | 内部 RefCounted 类，存 callable + wake_time |

### 2.11 StageContext — RefCounted (class_name)
| 项目 | 内容 |
|------|------|
| **职责** | 协程与系统的唯一桥梁 |
| **持有** | `runner: CoroutineRunner`（弱引用通过 is_instance_valid 检查）|
| **子服务** | `clock`, `bullets`, `player`, `dialogue`, `items`, `audio`（dialogue/items 以 WeakRef 持 ctx，防 RefCounted 环）|
| **active()** | runner 存在且 `is_running` |

**ClockService**
| 方法 | 说明 |
|------|------|
| `wait(seconds)` | 返回 seconds，CoroutineRunner 等待 |
| `wait_frames(count)` | 返回帧等效秒数 |

**BulletService**
| 方法 | 说明 |
|------|------|
| `shoot_spread(data, count, spread_angle, base_dir, at, sfx)` | 扇形散弹 |
| `fire_growing_laser(curve, color, speed, tail, lifetime, tex)` | 曲线生长激光 |
| `fire_line_laser(a, b, color, lifetime, tex)` | 两点直线激光 |
| `fire_fixed_laser(curve, color, lifetime, tex)` | 固定路径瞬间全开 |
| `fire_homing_laser(origin, player_pos, color, bend, length, lifetime)` | 自机导向激光（内部构造贝塞尔曲线） |
| `clear_all_lasers()` | 清激光 |

**PlayerService**
| 方法 | 说明 |
|------|------|
| `get_player()` | 返回 Player 或 null |
| `get_position()` | 返回玩家位置 Vector2 |

**DialogueService**
| 方法 | 说明 |
|------|------|
| `play(lines)` | 播放对话（暂停协程，等完成后继续）|
| `show(char_name, text, pos, portrait)` | 快捷单句对话 |

**ItemService**
| 方法 | 说明 |
|------|------|
| `spawn(type, position)` | 在 World/ItemPool 下生成道具 |

**AudioService**
| 方法 | 说明 |
|------|------|
| `play_bgm(stream, gap)` | 播 BGM |
| `stop_bgm()` | 停 BGM |
| `play_sfx(stream, vol_db)` | 播音效 |

```
便捷属性:
  ctx.decor               → get_decor() 懒加载 DecorManager
  ctx.get_field_rect()    → runner 所在 Viewport 的可见区域
  ctx.play_dialogue(lines)→ dialogue.play 的快捷方式
  ctx.dialogue_show(...)  → 快捷单句对话
  ctx.spawn_item(type, pos) → items.spawn 的快捷方式
```

### 2.12 AssetRegistry — Autoload 单例
| 项目 | 内容 |
|------|------|
| **职责** | 资源注册表 |
| **拥有** | `enemy_visuals(Dictionary)`, `bullet_configs(Dictionary)`, `sounds(Dictionary)`, `BGM_PATHS(Dictionary)`, `FOG_TEXTURE(Texture2D)`, `_bgm_cache`（BGM 懒加载缓存）|
| **子弹配置** | `bullet_configs` 含贴图+判定盒信息；`BulletData.tex(key)` 通过此查找 |
| **敌人视觉** | `enemy_visuals` 存 PackedScene（蓝色/红色/绿色/黄色妖精、玉等）|

### 2.13 LayerConfig — Autoload 单例
| 项目 | 内容 |
|------|------|
| **职责** | 全局 z_index 常量 |
| **值** | `PLAYER_BULLET=-10`, `ITEM=-5`, `PLAYER=0`, `OPTION=6`, `ENEMY=5`, `ENEMY_BULLET=10`, `BOSS=15`, `BOSS_HP_RING=20`, `EFFECT=50`, `BOMB=100`, `GAME_UI=1000`, `UI_TOP=128`, `OVERLAY=2000`, `DEBUG=9999` |

### 2.14 GameEvents — Autoload 单例
| 信号 | 说明 |
|------|------|
| `enemy_killed(score, pos)` | 敌人被击破 |
| `player_death()` | 残机为 0，Game Over |
| `player_missed()` | 每次 miss（中弹掉残机）都发——Boss 按东方规则累计 |
| `boss_spawned(boss)` | Boss 生成 |
| `boss_defeated(boss)` | Boss 被击败 |
| `phase_start(phase_data)` | 阶段开始（非符/符卡）|
| `phase_end(captured, bonus)` | 阶段结束 |
| `phase_bonus_tick(bonus)` | 奖励分每帧递减 |
| `dialogue_event(event)` | 对话事件 |

---

## 3. CoroutineScript — 协程脚本统一基类

### 3.1 概述
项目中**所有协程脚本**统一使用 `CoroutineScript`（继承 `CoroutineRunner`），不再区分 `StageScript / CreateScript / MoveScript / PlayerShootScript / EnemyScript`。

| 属性 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `ctx` | StageContext | null | 运行时上下文，start 时设置 |
| `target` | Node2D | null | 要控制的节点（可选）|
| `auto_stop` | bool | false | true=Timeline 播完自动结束；false=持续运行 |
| `_tl` | Timeline | null | 绑定 Timeline，由 `start_timeline()` 创建 |

| 方法 | 说明 |
|------|------|
| `start(ctx, target=null)` | 启动协程，每帧调 `_tick(ctx)` |
| `start_timeline()` | 创建并返回 Timeline 构建器 |
| `_tick(ctx)` → Variant | 每帧回调；默认走 Timeline；覆写实现自定义逻辑 |
| `diff_pick(arr)` | 根据当前难度从数组取值 |
| `diff_get(dict, key, default)` | 根据当前难度从字典取值 |

### 3.2 使用模式

**敌人弹幕脚本（原 CreateScript）：**
```gdscript
extends CoroutineScript

func _tick(ctx):
    ctx.bullets.shoot_spread(bullet, 3, 0.3, Vector2.DOWN, target.global_position)
    return ctx.clock.wait(0.5)
# auto_stop = true
```

**敌人移动脚本（原 MoveScript）：**
```gdscript
extends CoroutineScript

var target_y: float = 300

func _tick(ctx):
    target.global_position.y = move_toward(target.global_position.y, target_y, 100 * get_physics_process_delta_time())
    if abs(target.global_position.y - target_y) < 1:
        return false
    return true
# auto_stop = true
```

**自机射击脚本：**
```gdscript
extends CoroutineScript

func _tick(ctx):
    if Input.is_action_pressed("shoot"):
        var p := ctx.player.get_player()
        if p: ctx.bullets.shoot_spread(main_shot, 1, 0, Vector2.UP, p.muzzle.global_position)
    return ctx.clock.wait(0.1)
# auto_stop = false
```

**关卡时间线脚本（原 StageScript）：**
```gdscript
extends CoroutineScript

func _tick(ctx):
    if not _tl: _tl = start_timeline()
    return _tl.tick(get_physics_process_delta_time())
# auto_stop = true，播完关卡结束
```

---

## 4. Timeline — 声明式时间线

```gdscript
var tl := Timeline.new(ctx)
tl.at(0.0).do(cb)                  — 单次定时
tl.at(2.0).every(1.5).times(4).do(cb)  — 重复定时
tl.at(5.0).spawn_wave(data, count, spread, dir, pos)  — 弹幕波
tl.at(10.0).spawn_enemy(script, pos)
tl.at(12.0).spawn_boss(data, pos)
tl.at(13.0).play_bgm(stream)
tl.at(14.0).play_dialogue(data)
tl.loop()                          — 循环模式（按所有事件末次触发时刻的最大值循环）
```

| 方法 | 说明 |
|------|------|
| `at(t)` | 设置时间点 |
| `every(interval)` | 设置重复间隔 |
| `times(n)` | 设置重复次数 |
| `do(cb)` | 添加回调事件 |
| `spawn_wave(data, count, spread, dir, at_pos)` | 快捷散弹 |
| `spawn_enemy(script, pos)` | 快捷生成敌人（通过 EnemyData 构造链）|
| `spawn_boss(data, pos)` | 快捷生成 Boss |
| `play_bgm(stream)` | 快捷播 BGM |
| `play_dialogue(data)` | 快捷播对话 |
| `tick(delta)` → bool | 每帧调用，返回是否还有未触发事件 |
| `pause() / resume()` | 暂停/恢复 |
| `reset()` | 重置到初始 |
| `seek(time)` | 跳到指定时间 |
| `loop()` | 循环模式（终点 = max(末次触发时刻)，重置时按 `_loop_start` 重排并恢复 repeat 配置）|

---

## 5. 实体层

### 5.1 Player — Area2D (class_name Player)
| 项目 | 内容 |
|------|------|
| **移动** | `input_vector` + `normal_speed`/`focus_speed`（像素/秒）；`update_move(delta)` 含对角归一化 + clamp 边界 |
| **边界** | x 在 [64+24, 832-24]，y 在 [32+32, 928-32] |
| **判定** | `hitbox_radius=5px`（`HitPointDisplay` 显示受击点）；`graze_radius=40px` |
| **动画** | 状态机：`IDLE ↔ LEFTING ↔ LEFT ↔ RIGHTING ↔ RIGHT`；`LEFTING/RIGHTING` 为一次性过渡动画 |
| **射击** | `_shoot_script: PlayerShootScript`（通过 `PlayerData.shoot_script` 指定）；灵梦用 `cs_reimu.gd`，魔理沙用 `cs_marisa.gd`；通过 `_reinit_shoot()` 切换角色 |
| **无敌** | `is_invincible` + `_invincible_timer` 倒计时（`_physics_process` 递减，不用 await）|
| **Miss** | 5 个 MissEffect 圈 + DeathClear(2048, 3.0s) + `memory+=25` + lives-1 + 无敌 3s；lives==0 → `GameEvents.player_death.emit()` |

### 5.2 Enemy — Area2D (class_name Enemy)
| 属性 | 说明 |
|------|------|
| `enemy_data: EnemyData` | 配置数据 |
| `max_hp / hp` | 生命值 |
| `hitbox_radius` | 判定半径 |
| `score_value` | 击破分数 |
| `death_effect` | 死亡特效 PackedScene |
| `_visual: Node2D` | 外观实例 |

| 方法 | 说明 |
|------|------|
| `_apply_enemy_data(data)` | 应用配置 + CollisionShape2D |
| `start()` | 子类覆写 |
| `take_damage(int)` | 扣血，hp<=0 自动 `die()` |
| `die()` | 播死亡音效+特效 → 掉落Item → `enemy_killed` 信号 → queue_free |
| `_drop_item()` | 从配置读取各类型掉落数，通过 ItemPool.spawn 生成 |

### 5.3 EnemyVisual — AnimatedSprite2D (class_name)
| 项目 | 内容 |
|------|------|
| **职责** | 根据父节点移动速度自动切换动画 |
| **动画状态** | `IDLE`(loop) ↔ `RIGHTING`(一次性) ↔ `RIGHT`(loop) |
| **速度阈值** | `MOVE_THRESHOLD=30px/s`；防抖 `IDLE_HOLD=0.2s` |
| **翻向** | `flip_h` 由 x 方向自动控制 |

### 5.4 Boss — Area2D (class_name Boss)
| 项目 | 内容 |
|------|------|
| **数据** | `boss_data: BossData`（名称 + 视觉场景 + PhaseData 列表）|
| **阶段** | `_phase_index` 递增；`_next_phase()` → HP 从 0 涨到满（1 秒 Tween）→ `_begin_phase()` |
| **碰撞** | Area2D，碰撞层 4，掩码 2 |
| **HP 环** | 子节点 `BossHpRing` |
| **每帧** | `_process`: `_elapsed` 累积 + `_bonus` 递减 tick + 超时检测 |
| **符卡** | `unlock_spell(pid)` 见到即记；`record_spell(pid, captured, bonus, elapsed)` 记录尝试 |
| **时间** | `_elapsed >= time_limit` → `_on_phase_clear(is_timeout_only)` |
| **阶段间间隔** | 由关卡 Timeline 驱动：阶段 `is_phase_cleared` 后 `wait()` 偏移继承 → `start_phase` 进下一阶段（非 Boss 内定时；见 §10）|
| **`_die_boss()`** | 清状态 + `boss_defeated` 信号 + queue_free |
| **练习模式** | 不掉落 Item |

### 5.5 Bullet — Node2D (class_name Bullet)
| 项目 | 内容 |
|------|------|
| **属性** | `faction(0/1/2)`, `damage`, `velocity`, `can_be_canceled`, `hit_effect` |
| **判定** | `hitbox_shape(CIRCLE/RECTANGLE)`, `hitbox_radius`, `hitbox_size`, `hitbox_offset` |
| **运行时** | `is_ready`, `_grazed`, `coroutine_script`, `extra(Dictionary)` |
| **bind(data, dir)** | 从池复用初始化：设贴图/染色/速度/雾 → `_on_fog_ready` 设 `is_ready=true` |
| **物理** | 无协程时 `_physics_process` 中 `position += velocity / ticks_per_second` |
| **雾** | `BulletFog` 子节点；`spawn_fog=true` 时播雾，雾结束才显示子弹 |
| **染色** | 自机弹根据 `memory_value` 染色（<50 时偏红）|

### 5.6 Laser — 激光（LaserEngine / LaserBeam）
| 项目 | 内容 |
|------|------|
| **实体** | 无 `Laser` 类；用 `LaserEngine`（`scripts/laser/laser_engine.gd`，池 64）+ `LaserBeam`（`laser_beam.gd`, class_name LaserBeam）+ `LaserSkeleton` + `LaserPresets` |
| **创建** | `LaserEngine.fire_growing_laser / fire_line_laser / fire_fixed_laser / fire_homing_laser` 四种 |
| **状态** | `ALIVE → FADE(0.15s) → DEAD` |
| **碰撞** | 沿曲线采样做线段最近点检测 |

### 5.7 BackgroundStage — Node (class_name StageBackground)
| 项目 | 内容 |
|------|------|
| **子类** | `BackgroundPlane`（着色器平面）、`BackgroundSun`、`ScreenFogFX`、`EnvPreset` |
| **装饰** | `DecorManager` + `DecorLayer`（MultiMesh 批量渲染）|
| **着色器** | `background_plane.gdshader`, `water_flow.gdshader`, `ground.gdshader`, `sun_sprite.gdshader` 等共 16 个（`gdshader/`）|

---

## 6. 数据类

### 6.1 BulletData — Resource (class_name)
| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| texture | Texture2D | null | 子弹贴图 |
| tint_mode | TintMode | MULTIPLY | 染色模式 |
| tint | Color | WHITE | 贴图染色 |
| damage | int | 10 | 基础伤害 |
| velocity | Vector2 | UP | 速度向量 |
| hit_effect | PackedScene | null | 击中特效 |
| faction | Faction | PLAYER | 阵营(PLAYER/ENEMY/BOMB) |
| can_be_canceled | bool | false | 可被 Bomb 消除 |
| hitbox_shape | HitboxShape | CIRCLE | 判定形状 |
| hitbox_offset/radius/size/rotation | | | 判定参数 |
| spawn_fog | bool | false | 是否播弹雾 |
| fog_texture | Texture2D | null | 弹雾贴图 |
| coroutine_script | Script | null | 移动协程脚本 |

构造链方法：`.tex(key).speed(v).dir(x,y).color(c).enemy().player().blend(b)`

### 6.2 EnemyData — Resource (class_name)
| 字段 | 说明 |
|------|------|
| `visual_scene` | 外观 PackedScene |
| `max_hp / hitbox_radius / score_value` | 基础属性 |
| `death_effect` | 死亡特效（默认 `death_effect.tscn`）|
| `boss_data` | 可选的 BossData |
| `item_power/point/life/bomb/life_full/bomb_full` | 掉落配置 |
| `item_scatter` | 散布范围 |

构造链方法 + 预设模板：`red_little_fairy()`, `blue_middle_fairy()`, `white_huge_fairy()`, `red_YY_jade()` 等 14 种。

`spawn()` 方法：通过 CoroutineScript 在敌人上挂载协程。

### 6.3 PhaseData — Resource (class_name, @export)
| 字段 | 说明 |
|------|------|
| name | 符卡名（空串=非符）|
| uid | 全局唯一符卡编号（0=非符）|
| bonus/time_limit/hp | 奖励分/时限/血量 |
| is_timeout_only | 时符 |
| move_script/shoot_script | 移动/弹幕 CoroutineScript |
| background | 可选换背景 PackedScene |
| item_* | 掉落配置 |

### 6.4 BossData — Resource (class_name)
| 字段 | 说明 |
|------|------|
| boss_name | 名称 |
| visual | 视觉 PackedScene |
| phases | PhaseData 数组 |
| score_value | 击破分数 |

构造链：`.name(v).look(v).phase(p).score(v)`

### 6.5 StageData — Resource (class_name, @export)
| 字段 | 说明 |
|------|------|
| stage_id | 关卡编号 |
| create_script | 关卡 CoroutineScript |
| background_scene | 背景 PackedScene |

> ⚠️ 无 `difficulty` 字段：难度差分由关卡协程脚本运行时用 `diff_pick()/diff_get()` 处理（见 §5 难度差分），不是 StageData 静态字段。

### 6.6 PlayerData — Resource (class_name, @export)
| 字段 | 说明 |
|------|------|
| focus_speed / normal_speed | 低速/常速 像素/秒 |
| animation | SpriteFrames |
| shoot_script | 射击 CoroutineScript |

### 6.7 SpellRecord / SpellRecordBook
| 项目 | 内容 |
|------|------|
| SpellRecord | uid, character, stage, phase_type, phase_number, difficulty, spell_name, attempts, captures, practice_attempts, practice_captures, best_score, best_time, boss_name, boss_index |
| SpellRecordBook | 主键 `(stage_id, phase_index, boss_index, character, difficulty)`（无 uid —— uid 是展示/练习用键，主键按这段元组）|

### 6.8 练习模式配置（CardDef 已废弃）
> ⚠️ 2026-08 起废弃 `CardDef` / `CardRegistry` / `spell_registry.tres`（无此类、无该文件）。
> 练习模式改为**单驱动**：解锁时把战斗配置（`phase_data` + `boss_scene` + `background`）**内联存进符卡记录**
> （`spell_record.gd` 注释"无需 CardDef"）；练习菜单读 `spell_records.tres` 决定"能练哪张"，再 `GameState.start_practice(phase, boss_scene, ...)` 进练习。
> 入口：MainMenu「Spell Practice」在符卡簿为空时锁定。

### 6.9 对话系统（2026-08 步骤化重构，台词内联）

**分层：舞台状态（真相）→ 步骤 DSL（流程+台词）→ DialogueBox（渲染）**

| 类 | 职责 |
|------|------|
| `DialogueSteps` | 流程 DSL：`enter/say/line/exit/move/flip/dim/portrait/bubble/event/wait`；**台词直接内联**（`line()` 延续说话者，`say(profile, text)` 换人） |
| `DialogueLine` / `DialogueBubble` | 一屏数据（内部表示）：bubbles[speaker, text, emotion]、skippable、auto_advance |
| `CharacterProfile` | char_name、portraits(Dictionary)、default_pos、default_flip |
| `StageState` | 运行时唯一真相：actors{char_name → ActorState}；`apply_line` 自动明暗（说话者亮/沉默者暗）+ 表情跟随 |
| `ActorState` | 单个角色状态：position/flip_h/light/visible/emotion/bubble_offset |
| `DialogueRunner` | 步骤解释器（纯逻辑，不进树）：驱动 StageState、`line_shown/state_changed/event_fired/finished` 信号 |
| `DialogueBox` | 渲染层：消费舞台状态画立绘/气泡/表情/明暗，转发 `event_fired → GameEvents.dialogue_event` |

**时序语义**：`event` 是**行间步骤**（`d.event(key)`），时机精确到任意位置；`wait` 步骤做行间停顿。
**入口**：`ctx.play_dialogue_steps(steps)` / `tl.dialogue_steps(steps)`。
**台词组织**：台词在关卡脚本内联（与弹幕编排同构，"代码即真相"）；`docs/DIALOGUE.md` 保留为剧本归档。
**测试**：`test/test_dialogue.gd` + `test/test_dialogue_steps.gd`（状态机/时序/表情）。

#### 对话气泡（BubblePanel）

气泡渲染由独立的 `BubblePanel`（`scripts/scenes/bubble_panel.gd`）负责，与 `DialogueBox` 分离。

| 功能 | 说明 |
|------|------|
| 工厂方法 | `BubblePanel.create(text)` 创建白色圆角气泡 |
| BBCode 解析 | `[shake=N]` 抖动 N 秒；原生 `[color]` 支持 |
| 抖动特效 | `panel.shake(parent)` 在父节点上执行抖动 |
| 扩展点 | 预留了 `typewriter()` 逐字打印接口 |

---

## 7. 生命周期

### 7.1 应用级
```
Boot
  └→ MainMenu（MENU 状态）
       ├→ [Start] → DifficultyScreen
       │              └→ CharacterScreen
       │                   └→ stop_bgm() → GameManager.change_scene("game_scene")
       ├→ [Stage Practice] → StagePracticeMenu
       │              └→ (直接跳 GameScene, is_stage_practice=true)
       ├→ [Spell Practice] → SpellPracticeMenu
       │              └→ (直接跳 GameScene, is_practice_mode=true)
       ├→ [Replay / Player Data / Music Room / Option / Manual]
       └→ [Quit]
```

### 7.2 关卡级（GameScene）
```
GameScene._ready()
  ├ 1. GameManager._set_state(PLAYING)
  ├ 2. 创建 ItemPool → 挂到 World
  ├ 3. 根据 is_practice_mode 分流:
  │     普通: _resolve_stage_data() → _load_background → StageManager.load_stage(data)
  │     练习: _load_background(practice_background) → CoroutineRunner → spawn_boss(单 phase)
  ├ 4. _setup_player()（从 PlayerData 加载角色数据+射击脚本）
  └ 5. 自动开始（StageScript → CoroutineScript._tick → Timeline 驱动）

关卡运行中:
  GameUI HUD 每帧更新
  BulletManager._physics_process 驱动子弹/激光/碰撞

暂停:
  Input "ui_pause" → GameManager.pause_game()
    → MenuNav.push_overlay("pause_menu")
    → _set_state(PAUSED)
    → tree.paused = true（AudioManager 自动 stream_paused）
    → _add_blur()（SubViewport 区域 ColorRect 着色器模糊）

恢复:
  MenuNav.pop_overlay() → tree.paused = false
  → _set_state(PLAYING)
  → _remove_blur()

Miss:
  Player → BulletManager.start_death_clear(pos, 2048, 3.0, 30.0)
    → DeathClear 圈膨胀
    → MissEffectManager 多圈 Shader
    → GameState.add_memory(25.0)
    → GameState.lives -= 1
    → is_invincible = true（3 秒倒计时，_physics_process 自动倒数）
    → lives == 0 → GameEvents.player_death.emit()
      → await 2 秒 → GameManager.push_overlay_menu(game_over_menu)

关卡通关:
  StageManager.stage_cleared 信号
  → is_stage_practice: 跳回主菜单
  → 非练习: current_stage_id += 1, reload_current_scene

场景切换:
  GameManager.change_scene(path, target_state)
    → _set_state(TRANSITIONING)
    → 清页面+覆盖层
    → SceneTransition:
        await fade_out → change_scene_to_file
        → await process_frame → fade_in
    → _set_state(target_state)
    → scene_entered.emit()

GameScene._exit_tree():
  BulletManager.clear_all()
  → HitEffectPool.clear_all_pool()
  → 清理 _background_instance
  → 清理 _practice_runner
  → StageManager.stop_stage()
  → GameState.end_practice()

---

## 8. 协程任务生命周期

```
CoroutineRunner
  ├ run(callable) → stop() (清旧) → 新任务
  ├ run_parallel(callable) → 追加（不停止已有）
  │
  ├ _physics_process(delta):
  │   _clock += delta
  │   for i in range(_tasks.size()-1, -1, -1):
  │     if task.wake_time > _clock: skip
  │     result = task.callable.call()
  │     if result is float/int > 0: wake_time = _clock + result
  │     elif result == true: pass（下帧再调）
  │     else: 移除任务
  │
  └ 所有任务结束 → finished.emit()
```

---

## 9. 子弹生命周期

```
发射:
  BulletPool.shoot(data, pos, dir)
    ├ 池中有 → pop
    ├ 池空 → instantiate（有上限 MAX_TOTAL=5000）
    └ bind(data, dir)
        ├ sprite.texture = data.texture
        ├ faction = data.faction
        ├ velocity = dir.normalized() × data.velocity.length()
        ├ 如果 spawn_fog → 雾播放 → _on_fog_ready → is_ready=true
        ├ 否则 is_ready=true
        └ 如果 coroutine_script → 启动协程

每帧:
  ├ 没有协程的：position += velocity / physics_ticks_per_second
  └ 有协程的：由 CoroutineScript 协程控制

回收:
  ├ 碰撞命中 → return_bullet
  ├ 出屏 → return_bullet
  ├ DeathClear 圈内 → return_bullet
  └ clear_all → 全部 return_bullet

return_bullet:
  ├ 停协程 + queue_free
  ├ fog.visible=false, texture=null, 断信号
  ├ visible=false, process_mode=DISABLED
  ├ 从 active_bullets 移除
  └ 入池（或 free 如果池满 4000）
```

---

## 10. Boss 生命周期

```
Boss.setup(data, ctx) → 环形血条 + 碰撞形状 + 信号连接
Boss.start_boss(defer) → active_enemies 注册 + boss_spawned 信号

NextPhase:
  ├ phase_index++
  ├ HP 从 0 → phase.hp (1 秒 Tween)
  ├ unlock_spell(pid) → 符卡簿记录（见到即记）
  ├ 如果是符卡 → GameEvents.phase_start.emit()
  ├ _begin_phase() → 启动 move/shoot 协程
  ├ 非 is_timeout_only → invincible=false
  └ 时符 → invincible=true, hp=999999

每帧:
  ├ _elapsed += delta
  ├ bonus 递减 tick（max(1, bonus / time_limit * delta)）
  └ 超时 → _on_phase_clear(!is_timeout_only)

PhaseClear:
  ├ 停 move/shoot 协程 + queue_free
  ├ record_spell（普通模式）/ record_practice（练习模式）
  ├ score += bonus（如果收取）
  ├ _drop_items()（练习不掉落）
  ├ 2 秒 gap → _next_phase（或 _die_boss）

DieBoss:
  ├ active_enemies.erase
  ├ boss_defeated.emit
  └ queue_free
```

---

## 11. Item 生命周期

```
ItemPool.spawn(pos, type)
  → _pool.pop_back() 或 instantiate（无上限）
  → Item.setup(type, pos)
    ├ _dead=false, _auto_collect=false
    ├ _velocity=(0,-180) 上抛初速
    └ 设贴图（power/point/life_part/spell_part/life_full/spell_full）

Item._physics_process(delta):
  if _dead: return
  ├ 玩家 y<256 或距离<128px（focus×1.5=192px）→ _auto_collect=true
  ├ auto_collect: 飞向玩家 800px/s
  ├ else: 重力加速 → vy=min(vy+240*dt, 180)
  └ y>960 → _recycle()

Item collect (area_entered → Player):
  → collect(): _dead=true, visible=false, set_physics_process(false)
  → AudioManager.play_sfx(item.wav)
  → 计分/加碎片/加命
  → _recycle()

ItemPool.recycle(item):
  → 已在池中跳过 → _pool.append(item)
  → 池满（64）→ queue_free
```

---

## 12. 数据所有权

| 数据 | 所有者 | 写入者 | 读取者 |
|------|--------|--------|--------|
| score | GameState | add_score(), add_max_point() | GameUI |
| lives | GameState | Player.miss(), collect_life_*() | GameUI |
| bomb_count | GameState | collect_bomb_*() | GameUI |
| power_raw | GameState | add_power(), on_miss_power_penalty() | Player shoot calc, GameUI |
| memory_value | GameState | _process(regen), add_memory(), reduce_memory() | bullet tint, bullet_physics damage |
| graze_count | GameState | bullet_physics.on_graze() | GameUI |
| max_point | GameState | add_max_point() | Item, GameUI |
| difficulty | GameState | DifficultyScreen | 各处 |
| character | GameState | CharacterScreen | GameScene._setup_player() |
| active_enemies | GameState | Enemy._ready/_exit_tree, Boss | StageContext |
| active_bullets | BulletPool | shoot/return_bullet | BulletPhysics, BulletMultiMesh |
| active_lasers | LaserEngine | fire_*/clear | LaserEngine.step |
| item_pool | World/ItemPool | spawn/recycle | Enemy._drop_item, Boss._drop_items |
| current_stage | StageManager | load/stop_stage | 各处只读 |
| current_background | StageManager | GameScene._load_background | StageContext.get_decor() |
| spell_book | GameState | unlock_spell(), record_spell() | SpellPracticeMenu |
| player | GameState | GameScene._setup_player() | PlayerService, Item |

---

## 13. 状态机

### 13.1 GameManager.AppState
```
MENU ──→ PLAYING ──→ PAUSED
  ↑        │  ↑         │
  └────────┘  └─────────┘
      (ESC/返回)  (ESC 暂停/恢复)

TRANSITIONING = 短暂态，场景切换时
```

### 13.2 EnemyVisual 动画状态
```
IDLE ──speed≥30──────→ RIGHTING ──播完──→ RIGHT
  ↑                        │               │
  └──speed<30 持续 0.2s────┘───────────────┘
flip_h 由 x 方向自动控制
```

### 13.3 Player 动画状态
```
IDLE ──press L/R──→ LEFTING/RIGHTING ──播完──→ LEFT/RIGHT
  ↑                      │                        │
  └──release─────────────┘────────────────────────┘
```

---

## 14. 命名 & 文件公约

| 类别 | 约定 | 例 |
|------|------|-----|
| 类名 | PascalCase | `BulletData`, `CoroutineRunner` |
| 文件名 | snake_case | `bullet_data.gd`, `coroutine_runner.gd` |
| 私有成员 | `_prefix` | `_pool`, `_tween` |
| 公共成员 | no prefix | `active_bullets` |
| 信号 | snake_case | `stage_cleared` |
| 信号回调 | `_on_` + 信号名 | `_on_enemy_killed` |
| @export 变量 | snake_case, 写注释 | `@export var focus_speed: int ## 低速移动速度` |
| 常量 | UPPER_SNAKE | `POOL_SIZE`, `FACTION_ENEMY` |
| 枚举 | PascalCase | `Type.POWER`, `HitboxShape.CIRCLE` |

### 变量名避讳
```
❌ range    → ✅ patrol_range / amplitude  (遮蔽内置 range())
❌ dir      → ✅ direction (在 Timeline Event 中作为参数名时注意)
```

### 文件路径结构
```
scripts/
├── autoload/              # Autoload 层
│   ├── bullet/            # 子弹子模块（BulletPool, BulletPhysics, LaserEngine, DeathClear）
│   └── game/              # 游戏模块（SceneTransition, MenuNav）
├── background/            # 背景系统
│   ├── background_plane.gd
│   ├── background_sun.gd
│   ├── stage_background.gd (基类)
│   ├── decor_layer.gd
│   ├── decor_manager.gd
│   ├── env_preset.gd
│   └── screen_fog_fx.gd
├── bullet/                # 子弹实体
│   ├── bullet.gd
│   ├── bullet_fog.gd
│   ├── bullet_multi_mesh.gd
│   └── spatial_hash.gd
├── laser/                 # 激光系统（LaserEngine/LaserBeam/LaserPresets/LaserSkeleton）
├── components/            # 组件
│   ├── number_sprite.gd
│   ├── ui_separator.gd
│   └── rect_outline.gd
├── coroutine/             # 协程系统
│   ├── base/
│   │   ├── coroutine_runner.gd       # CoroutineRunner 基类
│   │   └── coroutine_script.gd       # CoroutineScript 统一脚本
│   ├── player/
│   │   ├── base/
│   │   │   ├── cs_player.gd          # PlayerShootScript 基类
│   │   │   └── option_visual.gd
│   │   ├── cs_reimu.gd
│   │   ├── cs_marisa.gd
│   │   ├── option_follow.gd
│   │   ├── ov_reimu.gd
│   │   └── move_homing.gd
│   ├── services/
│   │   ├── stage_context.gd          # StageContext
│   │   ├── clock_service.gd
│   │   ├── bullet_service.gd
│   │   ├── player_service.gd
│   │   ├── dialogue_service.gd
│   │   ├── item_service.gd
│   │   └── audio_service.gd
│   └── timeline/
│       ├── timeline.gd
│       └── timeline_event.gd
├── data/                  # 数据 Resource 类
├── debug/
├── effect/
├── enemy/
├── item/
├── player/
└── scenes/

data/
├── boss_scripts/          # 可复用 Boss 移动脚本（move/random_dir_move.gd 等，被 PhaseData.tres 显式引用）
├── dialogue/              # 对白 .tres
│   ├── reimu/
│   └── profile/
├── enemy_visual/          # 敌人/Boss 视觉 .tscn
├── player_data/           # 角色数据 .tres + 动画 .tres
├── registry/              # spell_records.tres, music_registry.tres, stage_registry.tres
└── stages/
    └── stage01/
        ├── background/    # 背景场景 + 装饰 + 环境预设
        ├── bullet/        # 弹丸行为脚本（gravity_bullet.gd / radial_accel_bullet.gd）
        ├── enemy/         # 敌人行为脚本（enemy01~04 / fly_away）
        ├── phase/         # Boss 阶段（non01 / non_mid01 / spell01，每个含 .tres + *_move/_shoot.gd）
        ├── stage_data/    # StageData .tres
        └── stage_script/  # 关卡编排脚本（stage01.gd Timeline）
```

---

## 15. API 契约

### 15.1 StageContext — 协程唯一入口
```
✅ 可以做的:
  ctx.clock.wait(2.0)              — 等待 2 秒后再次调用（返回 >0 秒数）
  ctx.clock.wait_frames(5)         — 等待 5 物理帧
  ctx.bullets.shoot_spread(data, count, spread, dir, at, sfx)
  ctx.bullets.fire_growing_laser(curve, color, speed, tail, lifetime, tex)
  ctx.bullets.fire_line_laser(a, b, color, lifetime, tex)
  ctx.bullets.fire_fixed_laser(curve, color, lifetime, tex)
  ctx.bullets.fire_homing_laser(origin, player_pos, color, bend, length, lifetime)
  ctx.bullets.clear_all_lasers()
  ctx.player.get_player()           — 返回 Player 或 null
  ctx.player.get_position()         — 返回 Vector2
  ctx.spawn_item(type, pos)
  ctx.play_dialogue(lines)
  ctx.dialogue_show(char, text, pos, portrait)
  ctx.get_decor()                   — 获取 DecorManager
  ctx.get_field_rect()              — 游戏区域 Rect2
  ctx.active()                      — 协程是否还在跑
  ctx.audio.play_bgm(stream, gap)
  ctx.audio.stop_bgm()
  ctx.audio.play_sfx(stream, vol_db)

❌ 禁止的:
  ctx.clock.wait(0) 或负数           — 用 return true（下帧立即调）
  协程内 await                       — 会撕裂调度器
  直接写 GameState 属性              — 用方法
  直接调 BulletManager 方法（除 StageManager.spawn_bullet）  — 走 ctx
```

### 15.2 CoroutineScript 使用约定
```
start(ctx, target=null):
  启动协程，_tick 每帧被调用
  target 可选，设为要控制的节点（Enemy/Bullet自身）

_tick(ctx) → Variant:
  返回值遵循 CoroutineRunner 约定：
    float/int > 0  → 等待这么秒后再次调用
    true           → 下帧立即再次调用
    false / null   → 结束
  默认实现：走 Timeline.tick()
  如果 auto_stop=true 且 Timeline 播完 → 返回 false 自动结束

覆写 stop() 时:
  注意 run() 内部会调 stop()，不要在 stop() 中做业务逻辑
  如需清理，用 if not is_running: return 保护
```

### 15.3 实体 API
```
Enemy:
  take_damage(int)  → 扣血, hp<=0 自动 die
  die()             → 清状态 + 特效 + emit + queue_free
  EnemyData.spawn() → 构造链生成并挂载到场景

Boss:
  take_damage(int)  → 扣血（invincible 时跳过）, hp<=0 自动清 phase
  current_phase()   → 返回当前 PhaseData
  current_bonus()   → 返回当前剩余奖励分
  begin_battle()    → 手动开始战斗
  start_boss(defer) → 注册并开始

Bullet:
  bind(data, dir)   → 池复用初始化
  ⚠️ 不在外部调 -- 池管理

Player:
  miss()            → 被弹处理
  ⚠️ miss() 不能 await（由碰撞回调同步调用）
  ⚠️ 无敌计时用 _invincible_timer 倒计时（_physics_process 自动减）

Item:
  setup(type, pos)  → 池复用初始化
  collect()         → 收集逻辑
  ⚠️ 不外部实例化，走 ItemPool.spawn()

ItemPool:
  spawn(pos, type)  → 生成 item（池复用优先，不限上限）
  recycle(item)     → 回收入池
```

### 15.4 禁止操作清单
```
❌ 任何脚本直接用全局 randf() / randi()
❌ 任何脚本直接写 GameState.current_score / lives / power_raw
❌ 协程内使用 await
❌ 碰撞回调/物理回调内 await
❌ ctx.active()==false 时调用 StageContext 方法
❌ 直接 instantiate 子弹（走 BulletManager）
❌ Enemy/Boss.die() 外部调用
❌ 场景切换期间读 current_scene 子节点
❌ 直接修改 .uid 文件（由 Godot 维护）
```

---

## 16. 检查清单（新功能/修改前）

```
□ 随机数走了 RNG 吗？
□ GameState 修改走了方法吗？
□ 碰撞/物理回调里没有 await 吗？
□ 协程里没有 await 吗？
□ 新 node 挂到了正确的父节点吗（World / BulletManager / current_background）？
□ 新 StageContext 方法检查了 active() 吗？
□ 新 @export 写了注释吗？
□ 新功能需要考虑暂停时的行为吗？
□ 释放资源了吗（tween, coroutine_script, signal disconnect）？
□ Bullet fog 的信号连接在回收时正确断开吗？
□ Item 的 _dead 标志在所有回调入口检查了吗？
□ Boss phase 切换时 move/shoot 协程正确 stop+queue_free 了吗？
```

---

## 17. 当前项目状态

### ✅ 已实现
- 引擎核心（Autoload 系统全部 12 个模块）
- 弹幕引擎（子弹池 4000/5000、物理、3种激光、死亡清除、MultiMesh、默认弹 \_physics\_process 优化）
- 敌人系统（Enemy + Boss + 14种外观、Boss 防双掉落）
- 玩家系统（灵梦+魔理沙、含射击脚本、Option、双倍速修复）
- 协程框架（CoroutineRunner + CoroutineScript + Timeline）
- 道具系统（6种、对象池、自动收集）
- 特效系统（命中、Miss全屏圈带渐隐、死亡清除回调）
- 背景系统（平面/圆柱着色素、装饰物）
- 音频系统（BGM1路+SFX8路、同帧去重）
- UI系统（主菜单/难度/角色/暂停/GameOver/Option/音乐室/回放/练习/Manual 全菜单、logo跳过）
- 菜单框架（BasePage + NavPage + MenuNav 页面栈）
- 对话系统（DialogueBox + 独立 BubblePanel）
- 记忆释放系统（C 键消弹+道具+渐隐圈+碎片上限+衰减）
- 着色器 16 个
- 数据类全部 Resource
- Stage 1 关卡雏形

### ⏳ 待完善
- **关卡内容**：只有 Stage 1 有数据，缺少 2~6 面（`data/stages/stage03B` 为测试符卡资源，未接入主流程）
- **Boss 战**：框架 + Stage1 Boss（卡摩瑞）就绪，第 3 面测试符卡在 `stage03B`，其余面缺
- **美术资源**：已在用正式图（logo/角色/敌人/背景），部分占位
- **BGM 集成**：音乐文件已导入并串联（`music_registry.tres` + `AssetRegistry.get_bgm` 懒加载）

### 🐛 已知技术债务
| 问题 | 位置 | 严重度 | 状态 |
|------|------|--------|------|
| ~~激光池 clear() queue_free 池对象~~ | laser_engine.gd | 高 | ✅ fixed |
| ~~Boss phase 同帧双掉落~~ | boss.gd | 高 | ✅ fixed |
| ~~默认弹双倍速~~ | bullet.gd | 高 | ✅ fixed |
| ~~StageContext 每弹创建~~ | bullet.gd | 中 | ✅ fixed（2026-08 共享 `get_bullet_ctx()`）|
| ~~Enemy take_damage 缺 negative guard~~ | enemy.gd | 低 | ✅ fixed（hp<=0 判定）|
| ~~.tres 配置无校验~~ | PhaseData 等 | 低 | ✅ fixed（`validate()` + test_config_validation）|
| ~~关卡退出时 RefCounted 残留~~ | 全局 | 低 | ✅ fixed（DialogueService/ItemService 弱引用 ctx + 生命周期回归测试）|
| ~~Timeline loop 重置时间戳~~ | timeline.gd | 低 | ✅ fixed（按 `_loop_start` 重排 + 恢复 repeat 配置）|
| DifficultyScreen 覆写 NavPage 90% | difficulty_screen.gd | 设计 | |
| PauseMenu/GameOverMenu _on_leave 重复 | 两处 | 低 | |

### 🚧 缺失功能
- **Bomb 系统**：FACTION_BOMB 存在，bomb_count 计数已有，但无玩家触发的 bomb 释放（X 键输入 `cancel&bomb` 未接读取）
- **Stage 2~6**：只有 Stage 1
- **Stage Practice**：菜单是占位（`stage_practice_menu.gd` 仅设 is_stage_practice + 标题渐显）
- **Replay 回放**：录制器 `ReplayRecorder` 已写好但有测试、未接 gameplay，无回放播放器（Replay 菜单是空壳）
- **Continue / Result 结算**：GameOver 只有 Retry/Title；通关直回菜单

### 🔮 架构改进方向
- **MenuLogic 拆分**：NavPage 的导航逻辑（选项收集/锁定跳过/冷却）与视觉呈现（modulate颜色/scale脉冲）分离，让自定义菜单只复用逻辑部分。（触发时机：第三个需要大量覆写 NavPage 的菜单出现时）
- **EffectService**：统一特效入口（屏幕震动、Boss出场特效等），协程通过 `ctx.effects` 调用

---

## 附录：v1.2 → v2.0 差异说明

| 项目 | v1.2 (旧) | v2.0 (新/代码真实) |
|------|-----------|-------------------|
| **协程脚本** | StageScript/CreateScript/MoveScript/BackgroundScript/PlayerShootScript/EnemyScript 6 种分别 | CoroutineScript 统一（1 个类，auto_stop 控制行为）|
| **StageContext 子服务** | 有 EnemyService（缺失）| 实际没有 EnemyService，敌人通过 EnemyData.spawn() 和 StageManager.spawn_* 生成 |
| **EnemyScript 一体化** | 有独立设计 | 实际不存在独立 EnemyScript 基类，用 CoroutineScript + EnemyData.spawn() 替代 |
| **BulletManager** | 无 homing_laser | 有 fire_homing_laser（通过贝塞尔曲线 + growing_laser 实现）|
| **AudioManager** | 双路 BGM 交叉渐出 | 实际单路，无 crossfade，gap 参数无用 |
| **Boss HP 增长** | 未详述 | HP 从 0 Tween 到满（1秒），时符 hp=999999 |
| **Item 物理** | 未详述 | 重力 240/s²，终端 180/s，上抛初速 -180px/s |
| **MissEffectManager** | 未详述 | 8 圈上限，Shader 实现，支持延迟/起始半径 |
| **DialogueService** | 未详述 | 通过暂停/恢复 CoroutineRunner.is_running 实现等待 |
| **Timeline** | 有 seek() | 有 seek() |
| **CardDef/CardRegistry** | 未提及 | ⚠️ 曾用于练习模式，**2026-08 已废弃**（改 spell_records.tres 单驱动 + 记录内联战斗配置）|
}
---

## 10. 协程使用约定（2026-07-31 补充）

项目有两套"时序"工具，**边界必须清晰**：

### 10.1 CoroutineRunner / CoroutineScript —— 游戏逻辑时序
**用途（必须用它）**：
- 弹幕射击/移动/等待（敌机、Boss 符卡、自机射击）
- 关卡编排（Timeline）
- 演出性等待（对话冻结等）

**理由**：时钟在 `_physics_process` 累积，**暂停时冻结、可复现**（RNG 种子 replay 基础）。

**返回值约定**：`float/int > 0`=等待秒数；`true`=下帧再调；`false/null`=结束。

### 10.2 原生 await —— 一次性 UI / 过渡
**用途（必须用它）**：
- 菜单动画、页面切换、淡入淡出
- 一次性延迟（如 GameOver 前等 2 秒）
- 等待信号/帧（`await signal`、`await process_frame`）

**理由**：await 是协程语法糖，简单直接；UI 时序不需要暂停冻结/复现。

### 10.3 禁忌
- ❌ 游戏逻辑（弹幕/关卡节奏）用 `await` 做关键等待 —— 暂停/Replay 会乱
- ❌ UI 过渡用 CoroutineRunner —— 过度设计，维护成本高
- ❌ 直接写 `runner.is_running` —— 用 `pause()/resume()`

### 10.4 现状
- `await` 15 处（全部在 UI/过渡/一次性延迟，符合约定）✅
- CoroutineRunner/CoroutineScript 29 处引用（游戏逻辑）✅
- DialogueService 已改用 `pause()/resume()` ✅

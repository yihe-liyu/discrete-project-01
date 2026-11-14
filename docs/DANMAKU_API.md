# 弹幕内核接口（DANMAKU API）

> **一句话**：给一颗弹写飞行规律 = `SpawnSpec.with_behavior(BulletBehaviors.xxx)`；发射 = `ctx.bullets.shoot_spread_spec(...)`。
> 本文是弹幕创作的**唯一权威参考**；教学路径见 `CONTENT_GUIDE.md` §六；原生执行器在 `gdextension/src/danmaku_store.cpp`。
> 读法：新建弹幕看 §1 + §3；查 behavior 看 §3；发射看 §4；踩坑看 §9。

## 0. 心智模型（三层）

```
内容脚本 (CoroutineScript, GDScript 低频)
   │  构造 SpawnSpec（贴图/判定/阵营）+ with_behavior(...)
   ▼
native behavior (C++ pack，固定 float state/params)
   │  逐帧 tick（与积分同一条 native 管线）
   ▼
原生执行 (DanmakuStore, C++ 每帧每弹)
     位置积分 / 行为 / 命中 / 渲染缓冲
```

1. **内容不碰内核状态**：只写 `SpawnSpec` / `BulletBehaviors` / `ctx.*`。
2. **SpawnSpec 实例必须复用**（弹型缓存在实例上）→ §2.3。
3. **GDScript 不进每帧每弹路径**：per-bullet 逻辑一律在 C++ behavior pack。

## 1. 最小可跑示例

```gdscript
extends CoroutineScript
## 从上往下，每 0.4 秒放一扇 5 连小玉

var _spec: SpawnSpec            # 成员：建一次、复用（铁律）

func _tick(p_ctx: StageContext) -> Variant:
	if _spec == null:
		_spec = SpawnSpec.new().tex("小玉").speed(220).color(Color.AQUA).enemy()
	p_ctx.bullets.shoot_spread_spec(_spec, 5, deg_to_rad(40.0), Vector2.DOWN, target.global_position)
	return p_ctx.clock.wait(0.4)
```

- `target` = 宿主注入的节点（敌人 / Boss 自己）。
- 返回值语义见 §5.1；`shoot_spread_spec` 的 `base_dir` 定方向、`spec.velocity.length()` 定速度（§4.1）。

## 2. SpawnSpec（发射描述 + 构造链）

`scripts/data/spawn_spec.gd` ｜ `extends RefCounted, class_name SpawnSpec`

### 2.1 字段

| 字段 | 类型 | 默认 | 说明 |
|---|---|---|---|
| bullet_def | BulletDef | null | `tex(key)` 载入的外形/判定/朝向来源 |
| texture | Texture2D | null | 贴图（用 `tex(key)` 设，别手写） |
| tint | Color | WHITE | 染色 |
| use_blend | bool | true | true=取贴图亮度混 tint（敌弹换色）；false=贴图×tint（自机弹保原色） |
| damage | float | 10.0 | 基础伤害（支持小数，累积到整才扣血） |
| velocity | Vector2 | (0,-1) | **只取长度当速度**；方向由发射时的 direction 决定 |
| faction | Faction | PLAYER | PLAYER / ENEMY |
| kind | BulletType.Kind | POINT | POINT / LASER（激光段供整批淡出） |
| hitbox_shape | HitboxShape | CIRCLE | CIRCLE / RECTANGLE（用 `hitbox_circle/rect` 设） |
| hitbox_radius | float | -1.0 | 圆判定半径；-1 = 沿用 `bullet_def` |
| hitbox_size | Vector2 | ZERO | 矩形判定尺寸；ZERO = 沿用 `bullet_def` |
| hitbox_offset | Vector2 | ZERO | 判定偏移 |
| follow_dir_override | int | -1 | -1 = 用 `bullet_def`；0/1 = 明确覆盖（用 `facing()` 设） |
| dir_offset_override | float | NAN | 朝向补偿（弧度，仅 follow_dir 时生效；素材朝右=0、朝上=+PI/2） |
| hit_effect | PackedScene | null | 命中特效场景 |
| hit_sfx | String | "" | 命中音效 key（`AssetRegistry.sounds`；空=normal_damage） |
| spawn_fog | int | -1 | -1 = 阵营默认；0 = 关闭；1 = 打开 |
| spawn_fx | EffectType | null | 这型的出生特效（null=用阵营默认） |
| out_grace | float | 0.0 | **逐弹出界宽限（秒）**：出界后仍活这么久；0 = 出界立即回收 |
| wrap_mask | int | 0 | 环绕边掩码：1 左 / 2 右 / 4 上 / 8 下 |
| behavior_spec | BehaviorSpec | null | 弹道 behavior（C++ pack） |
| anchor | Variant | null | per-shot 锚点 `{id, offset, use_global}`（激光用） |
| child | SpawnSpec | null | 一层替换弹（可选） |

> `faction` 用 `enemy()` / `player()` 设；`damage` / `hit_sfx` / `kind` 直接赋值。

### 2.2 构造链方法

| 方法 | 作用 |
|---|---|
| `.tex(key)` | 按 key 查 `data/bullets/<key>.tres`（**内容主路**；key 来自 §7.1，拼错会告警但仍用默认判定） |
| `.speed(v)` | 速度大小（`velocity.y = v`，长度 = v） |
| `.direction(x, y)` | 直接设 velocity（方向+速度，仅发射时传 `ZERO` 方向时用） |
| `.color(c)` / `.blend(bool)` | 染色 / 开关 BLEND 换色（默认开） |
| `.enemy()` / `.player()` | 阵营：敌弹 / 自机弹 |
| `.with_spawn_fog(effect)` / `.no_spawn_fog()` | 打开/换出生雾 / 关掉出生雾 |
| `.with_behavior(spec)` | **挂 native behavior**（§3） |
| `.grace(v)` | out_grace |
| `.wrap_around()` / `.wrap_horizontal()` / `.wrap_vertical()` | 四边 / 左右 / 上下环绕 |
| `.wrap_edges(mask)` | 自定义边，mask 用 `SpawnSpec.WrapEdge` |
| `.hitbox_circle(radius, offset)` / `.hitbox_rect(size, offset)` | 覆盖判定 |
| `.facing(follow, offset)` | 覆盖朝向（圆弹 `facing(false)`） |
| `.with_behavior(spec)` | 挂 native behavior（C++ pack） |

> **未知 tex key 会 `push_warning` + 保持默认**（不静默回退，但弹仍会发出去）——只从 §7.1 表取 key。

### 2.3 弹型缓存（实例复用铁律）

- `to_bullet_type()` 在**首次发射**时把类型级字段（贴图/阵营/判定/伤害/命中特效/命中音效）快照到内核弹型，缓存挂在 **SpawnSpec 实例**上。
- **同一实例反复发射 = 共用同一弹型**；每发 `SpawnSpec.new()` 会让内核弹型表膨胀。
- 速度 / tint **不属弹型**，每发可改；类型级字段请在构造时定好，不要运行期改型。
- 构造链 setter 会主动失效缓存；类型级字段请在构造时定好。

## 3. 弹道 behavior（原生 C++ pack）

一颗弹的飞行规律通过 `SpawnSpec.with_behavior()` 挂一个 **native behavior**。
behavior 在 C++ 里逐帧执行，内容侧只提供 id + 固定参数；没有 per-bullet GDScript VM。

```gdscript
_spec.with_behavior(BulletBehaviors.accel(Vector2(0, 200)))
```

### 3.1 约束

- 一颗弹**只有一个** behavior；需要组合时在 C++ pack 里写清楚，不要在内容侧叠多个。
- 参数上限 8 个 float；多余参数会被原生截断，构造器应自己校验。
- behavior 是确定性的：随机只走内核单通道 RNG，回放可复现。
- 行为里可以 `emit` / `play_sfx` / `emit_laser` / `clear_fx` / `despawn`；这些请求由内核在遍历结束后统一落地。

### 3.2 通用 behavior

| builder | 参数 | 语义 |
|---|---|---|
| `linear()` | — | 匀速直线（默认行为） |
| `accel(Vector2)` | ax, ay | 世界方向匀加速 |
| `accel_heading(accel, lifetime=0, clear=false)` | accel, lifetime, clear | 沿当前朝向加速；lifetime>0 到点回收，clear 播消散 |
| `homing(speed, turn, target_mode=0, speed_end=0, speed_ramp=0, turn_ramp=0, dist_weight=0, steer_until=0)` | 8 | 追踪；target_mode=1 追最近敌人；可做速度插值 |
| `bounce_emit(template, child_speed=0, accel=0, angle=0, despawn=true, reflect=false)` | 6 | 撞左/右/上墙时生成子弹出；reflect=true 按镜面反射 |
| `split_after(template_a, template_b, duration, accel, chance, child_speed=0, spread=0)` | 7 | 到时按概率分裂成两个模板之一 |
| `seed_burst(template, duration, speed, count, child_speed, spread)` | 6 | 到时向四周炸开一圈 |
| `spin_accel(spin, accel)` | 2 | 贴图自转 + 沿朝向加速 |
| `anchor_drift(angle, speed, initial=0, render_heading=true)` | 4 | 锚定宿主节点做线性漂移（激光段） |

卡片专属 behavior（`stage01.enemy04.top_emit` / `stage02.enemy02.spin_then_slow` /
`stage03B.mid01.rain_stage` / `stage01.mid01.sonar`）由对应内容直接调用，不要跨卡复用。

### 3.3 激光锚点

激光段需要宿主每帧跟随子机/节点时，用 `anchor_drift`，并在发射前设置 per-shot 锚点：

```gdscript
spec.with_behavior(BulletBehaviors.anchor_drift(angle, 2000.0, 13.333, true))
spec.anchor = {&"id": marker.get_instance_id(), &"offset": Vector2.ZERO, &"use_global": true}
```

`anchor` 的 `id` 失效时宿主退回自机 + offset；`use_global=false` 时用 `player + node.position`。

### 3.4 行为预览

`ctx.telegraph` 的路径预览不再解释描述符，而是调用 `DanmakuStore.preview_behavior()`：
用同一份 C++ tick 在临时状态上跑 N 帧，所以预览与实战同源。
没有 behavior 的弹走直线兜底；预览不生成真弹、不消耗游戏 RNG。

## 4. 发射 API（`ctx.bullets`）

`scripts/coroutine/services/bullet_service.gd`

### 4.1 shoot_spread_spec（唯一弹幕发射入口）

```gdscript
ctx.bullets.shoot_spread_spec(spec: SpawnSpec, count: int, spread_angle: float,
	base_dir: Vector2, at: Vector2, sfx: AudioStream = null) -> void
```

- `count == 1`：一发，方向 = base_dir，忽略 spread_angle。
- `count > 1`：`spread_angle >= TAU` → 铺满一圈，step = spread/count；否则以 base_dir 为中心左右展开，step = spread/(count-1)。
- 每发速度 = `spec.velocity.length()`；方向来自这里，不是 spec.velocity 的方向。
- 想逐发不同速度/颜色：复用实例、每发改 `velocity` / `tint` 后再发射（入队瞬间快照，安全）。
- 需要逐弹稳定句柄（预览 / 调试）时用 [code]shoot_spread_spec_ids_spec[/code]。
- 其他入口：`shoot_spec`（单发）、`shoot_directions_spec`（方向数组）。

### 4.2 激光

```gdscript
ctx.bullets.spawn_laser(skeleton: LaserSkeleton, color: Color, opts := {}) -> LaserBeam
ctx.bullets.fire_growing_laser(curve: Curve2D, color, speed=600, tail=300, lifetime=8, tex=null) -> LaserBeam
ctx.bullets.fire_line_laser(a: Vector2, b: Vector2, color, lifetime=3, tex=null) -> LaserBeam
ctx.bullets.fire_fixed_laser(curve: Curve2D, color, lifetime=3, tex=null) -> LaserBeam
ctx.bullets.fire_homing_laser(origin, player_pos, color, bend=100, length=500, lifetime=5) -> LaserBeam
ctx.bullets.clear_all_lasers()
```

`spawn_laser` / `emit_laser` 的 `opts` 除生长参数外还可以调亮度：

| key | 默认 | 作用 |
|---|---|---|
| core_color | 用 color | 亮核颜色覆盖 |
| glow_color | 用 color 提亮 | 光晕颜色覆盖 |
| glow_alpha | 0.35 | 光晕透明度 |
| glow_width_mult | 2.2 | 光晕宽度倍率 |
| additive | false | core/glow 用加色混合（更亮） |

### 4.3 清弹 / 炸弹

```gdscript
ctx.bullets.death_clear(pos, max_radius, duration, start_radius=30, on_clear=Callable())
ctx.bullets.shoot_bomb(data: BombData, pos, direction, tint=Color.WHITE, spawn_delay=0.0)
```

## 5. 内容脚本契约（CoroutineScript）

`scripts/coroutine/base/coroutine_script.gd`

### 5.1 _tick 返回值

| 返回 | 含义 |
|---|---|
| `ctx.clock.wait(sec)` | 等 sec 秒后再调 |
| `true` | 下一物理帧立即再调 |
| `false` / `null` | 协程结束 |

### 5.2 启动 / 属性

```gdscript
s.auto_stop = true/false     # true: _tick 返回 false 即止；false: 持续运行
s.target: Node2D             # 宿主注入（敌人 / Boss 自己）
s.ctx: StageContext
s.start(ctx)                 # 由宿主调用
s.get_dt() -> float          # 当前物理帧步长（别用 get_physics_process_delta_time()）
s.start_timeline() -> Timeline
```

### 5.3 难度

```gdscript
diff_pick(arr)               # Difficulty.pick(arr, SaveData.selected_difficulty)
diff_get(dict, key, default)  # 缺行 / 非法行走默认值
# 4 项数组只覆盖 Easy~Lunatic；Extra 需要第 5 项，否则报错并回落最后一项。
ctx.diff.picked() / pick(arr) / at_least(n)
```

难度索引：**0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra**。

### 5.4 Timeline（低频排程）

```gdscript
var tl := start_timeline()
tl.at(0.0).do(func(): ...)
tl.at(2.0).every(1.5).times(4).do(_wave)
tl.wait(0.0).do(func(): ...)          # 等上一个阻塞事件（如 Boss 击破）后 N 秒
tl.start_phase(func(): return _boss, phase_data)
tl.loop()
# 在 _tick 里： return tl.tick(get_dt())
```

## 6. ctx 服务总表

| 服务 | 关键方法 |
|---|---|
| `ctx.clock` | `wait(sec)` / `wait_frames(n)` |
| `ctx.bullets` | `shoot_spread_spec` / `fire_*_laser` / `death_clear` / `shoot_bomb` / `clear_enemy_bullets` |
| `ctx.player` | `get_player()` / `get_position()` |
| `ctx.boss` | `current()` / `exists()` |
| `ctx.enemies` | `spawn(data)` / `despawn(enemy)` / `despawn_all()` / `despawn_clear(enemy)` |
| `ctx.diff` | `picked()` / `pick(arr)` / `pick_from(dict, key, def)` / `at_least(n)` |
| `ctx.audio` | `play_bgm(stream, gap=0)` / `stop_bgm()` / `play_sfx(stream, db=AudioManager.SFX_LEVEL_DB)` |
| `ctx.effects` | `add_miss_circle(...)` / `play_hit_effect(scene, pos)` |
| `ctx.items` | `spawn(type, position)` |
| `ctx.dialogue` | `play_steps(steps)`（经 `ctx.play_dialogue_steps` 更常用） |
| `ctx.objects` | `register(key, obj, type)` / `resolve_as(key, type)` / `clear()` |
| `ctx.stage` / `ctx.entity_registry` | 机制层：`bullet_manager` / `entity_registry` / `item_pool` / `fx_pool` / `miss_layer`（内容一般不用直接摸） |

> `ctx.*` 是**意图门面**：内容只说意图，机制在服务/host；无 `stage` 绑定时多数方法静默 no-op（测试友好）。

**场景导演**：`StageDirector`：`bgm(key)` / `boss(key, data, from, to, hide)` / `dialogue(steps)` / `on(event, handler)` / `dispose()`。
`BossHandle`：`enter(to, from, dur=1.5)` / `phase(index=0, idle_only=false)` / `reveal(name)` / `set_name(name)` / `show_name()/hide_name()` / `show_phase_dots()/hide_phase_dots()` / `retreat(to, dur=2.0)` / `resolve()/exists()`。
> 名字节点/进度点默认隐藏；关底想显示就 `reveal(name)` + `show_phase_dots()`。

## 7. 素材与常量表

### 7.1 子弹贴图 key（`SpawnSpec.tex(key)` 唯一来源）

**数据源 = `data/bullets/<key>.tres`**（`BulletDef`：外观 + 碰撞 + 朝向；`BulletCatalog` 扫目录建索引）。
贴图本体 = 1024² 图集 `assets/Textures/bullet/bullet.png`（`laser` 除外）；运行时类型是 `BulletType`（不是内容资源）。

| key | texture_key | 判定 | 备注 |
|---|---|---|---|
| 点弹 | 点弹 | circle 5 | 微型 |
| 点棱弹 | 点棱弹 | circle 4 | 微型 |
| 菌弹 | 菌弹 | circle 5 | 微型 |
| 小玉 | 小玉 | circle 8 | 小型（最常用） |
| 星弹 | 星弹 | circle 6 + offset x−1 | 小型，判定随朝向 |
| 枪弹 | 枪弹 | circle 6 | 小型 |
| 棱弹 | 棱弹 | circle 6 | 小型 |
| 滴弹 | 滴弹 | circle 5 + offset x+4 | 小型，判定随朝向 |
| 环玉 | 环玉 | circle 8 | 小型 |
| 符札 | 符札 | circle 6 | 小型 |
| 米弹 | 米弹 | circle 6 | 小型 |
| 苦无 | 苦无 | circle 5 | 小型 |
| 长菌弹 | 长菌弹 | circle 6 | 小型 |
| 鳞弹 | 鳞弹 | circle 6 | 小型 |
| 刀弹 | 刀弹 | circle 6 | 小型（有向） |
| 箭弹 | 箭弹 | circle 6 + offset x+20 | 中型，判定随朝向 |
| 蝶弹 | 蝶弹 | circle 8 + offset x−3.5 | 中型，判定随朝向 |
| 火弹 | 火弹 | circle 8 + offset x+11 | 中型，判定随朝向 |
| 小光玉 | 小光玉 | circle 16 | 中型 |
| 椭弹 | 椭弹 | circle 12 | 中型（有向） |
| 大星弹 | 大星弹 | circle 16 + offset x−3 | 中型，判定随朝向 |
| 心弹 | 心弹 | circle 20 | 大型 |
| 矩弹 | 矩弹 | circle 20 | 大型（有向） |
| 中玉 | 中玉 | circle 24 | 中型 |
| 光玉 | 光玉 | circle 28 | 大型 |
| 大玉 | 大玉 | circle 36 | 大型 |
| reimu_main | 灵梦自机主弹 | rect 48×24 | 自机弹 |
| reimu_opt1 | 灵梦子机高速弹 | circle 12 | 自机弹 |
| reimu_opt2 | 灵梦子机低速弹 | rect 120×24 | 自机弹 |
| marisa_main | 魔理沙自机主弹 | rect 48×24 | 自机弹 |
| marisa_opt1 | 魔理沙子机高速弹 | rect 32×32 | 激光条（512×32 合体格） |
| marisa_opt2 | 魔理沙子机低速弹 | rect 48×24 | 自机弹 |
| reimu_bomb01 | 灵梦bomb | circle 45 | 自机炸弹 |

> 圆弹可标 `follow_dir=false`（点弹/小玉/菌弹/环玉）；也可构造后 `data.follow_dir = false` 覆盖（须在首次发射前）。
> **新增弹型** = 图集加一格（`data/atlas/bullet_shapes.tres`）+ 新建 `data/bullets/<key>.tres`。
> `laser` **不是弹型**：`AssetRegistry.LASER_TEXTURE`（`assets/Textures/bullet/laser.png`）供 `LaserBeam` 兜底。

### 7.2 音效 key

`ctx.audio.play_sfx(AssetRegistry.sounds[key])` / `sfx()` / `hit_sfx` 可用：

`shoot` `player_shoot` `kira` `enemy_die` `boss_die` `player_die` `graze` `item` `card` `get_card` `get_player` `player_card` `select` `ok` `cancel` `pause` `lazer` `marisa_damage` `msl` `normal_damage`

> 权威表 = `scripts/asset_registry.gd` 的 `sounds`；每个 key 都要在 `SFX_DB` 有音量项（`test_sfx_mix` 会红）。**加 key 时顺手改上面这一行。**
> `get_card` = 干净收取符卡的回报音；`get_player` = 拿到完整残机的回报音。
> 音量走总线 `Master → BGM / SE / UI`（`default_bus_layout.tres`）；SE 有限幅 + 密度压制 + 优先级驱逐；BGM 换曲新曲直入/旧曲淡出 0.6s、同曲只一路。

### 7.3 阵营 / 混合

```gdscript
SpawnSpec.Faction.PLAYER / ENEMY
spec.blend(true)    # 取贴图亮度混 tint（敌弹换色）
spec.blend(false)   # rgb = 贴图 × tint（自机弹保原色）
```

## 8. 文件与接线

### 8.1 阶段目录布局

```
data/stages/<stage>/
  stage_script/*.gd                关卡编排（Timeline）
  enemy/*.gd                       敌人行为（CoroutineScript）
  phase/<阶段名>/*.tres             PhaseData（一个 .tres = 一个阶段）
  phase/<阶段名>/<阶段名>.gd         Boss 弹幕脚本
  phase/<阶段名>/<阶段名>移动.gd     Boss 移动脚本
  background/ stage_data/
```

> 阶段脚本的角色靠 `PhaseData.shoot_script` / `move_script` **引用反推**；新建脚本接进 .tres 前显示「未分类」是正确结果。
> 新建阶段脚本三步：① 写 `<阶段名>.gd`；② `godot --headless --import` 生成 `.uid`；③ 在 `.tres` 加 `ext_resource` 并填 `shoot_script`。

### 8.2 PhaseData（`scripts/data/phase_data.gd`）

| 字段 | 说明 |
|---|---|
| name | 符卡名（空 = 非符） |
| uid | 全局唯一符卡编号（0 = 非符不记） |
| time_limit / hp | 时限 / 血量 |
| is_timeout_only | 时符 |
| move_script / shoot_script | 空 = 本阶段不移动 / 无弹幕（纯演出 / 纯走位合法）；常规卡建议两个都填 |
| pre_move_script | 宣言前走位（会推迟宣言，必须能结束） |
| params | 注入脚本同名属性（`PhaseData.validate` 按三脚本并集查未知键） |
| item_* / open_reduce_* | 掉落 / 开局减伤 |

### 8.3 注释（不再自动索引）

文件头注释仍建议写清「这张卡做什么」；`@name` / `@desc` / `@role` 随创作台退役，不再被工具消费。
命名约定（`*_move.gd` / `*_shoot.gd` / `enemy/` / `stage_script/`）只用于人类阅读。

## 9. 陷阱清单（必读）

1. **SpawnSpec 必须复用实例**（弹型缓存在实例上）；每发 `new()` → 弹型表膨胀。
2. **tex key 拼错会告警，但仍用默认判定**（4px）→ 只从 §7.1 表取 key。
3. **速度来自 `spec.velocity.length()`，方向来自发射参数**；别指望 `spec.velocity` 的方向。
4. **一颗弹只有一个 behavior**；要组合就在 C++ pack 里写，不在内容侧叠多个。
5. **behavior 参数上限 8 个 float**；构造器自己校验，原生会截断多余项。
6. **`emit` 的模板必须先注册**（`numeric_id >= 0`）；否则原生只回事件、宿主无处落地。
7. **`bounce_emit` / `split_after` 的 emit 发生在行为遍历结束后**；不要在行为 tick 里等子弹出。
8. **`homing(target_mode=1)` 没有敌人时只做速度插值、不转向**；不要把它当“必定追踪”。
9. **`anchor_drift` 必须给 `spec.anchor`**；id 失效时宿主退回自机 + offset（静默降级）。
10. **自机弹 tint 会被记忆值往红 lerp**（`prepare_spec`）；内容设的 tint 只是基底。
11. **类型级字段在首次发射时快照**；请在构造时定好，不要在运行期改型。
12. **behavior 的 state/params 是固定 float 槽**；不能在行为里 new 对象 / 存引用。
13. **RNG 单通道、按「弹行遍历顺序」消耗**：增删随机 behavior 会平移后续随机序列（回放仍可复现，但结果会变）。
14. **预览与实战同源，但不模拟 emit 子代**：`BehaviorPreview` 只画父弹路径；子代由 `track_emitted` 单独跟踪。
15. **`homing` 的最近敌人只在宿主候选集里取**；targetability 在 `EntityRegistry` / `Enemy.is_targetable`，不在内核。

## 10. 完整例子

### 10.1 环形铺满（每 1.2 秒一圈）

```gdscript
extends CoroutineScript

var _spec: SpawnSpec

func _tick(p_ctx: StageContext) -> Variant:
	if _spec == null:
		_spec = SpawnSpec.new().tex("小玉").speed(160).color(Color.AQUA).blend(true).enemy() \
			.with_behavior(BulletBehaviors.accel(Vector2(0, 60)))
	p_ctx.bullets.shoot_spread_spec(_spec, 12, TAU, Vector2.RIGHT, target.global_position)
	p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"], -10.0)
	return p_ctx.clock.wait(1.2)
```

### 10.2 减速往返 → 到点分裂

```gdscript
# 两个子弹出模板先注册（EmitTemplate 的 numeric_id 必须 >= 0）
var a := SpawnSpec.new().tex("环玉").color(Color.AQUA).enemy()
var b := SpawnSpec.new().tex("环玉").color(Color.RED).enemy()
var ta := EmitTemplate.new(&"split_aqua", a)
var tb := EmitTemplate.new(&"split_red", b)
ctx.bullets.register_emit_template(ta)
ctx.bullets.register_emit_template(tb)

_spec.with_behavior(BulletBehaviors.split_after(ta, tb, 0.6, -150.0, 0.1, 60.0))
```

## 11. 到这里之后

| 想干什么 | 去哪 |
|---|---|
| 教学 / 由浅入深 | `CONTENT_GUIDE.md` §六 |
| 关卡 / 敌人 / Boss 编排 | `CONTENT_GUIDE.md` 二~四 |
| behavior 设计 / 边界 | 附录 A |
| 原生执行细节（op / 事件 / 同步点） | `docs/archive/GDEXTENSION_KERNEL_DESIGN.md` + `gdextension/src/danmaku_store.cpp` |
| 架构 / 命名契约 | `docs/ARCHITECTURE.md` + `docs/BEST_PRACTICES_BASELINE.md` |

---

## 附录 A · 弹道 behavior 模型（速查）

- 核心：**一个 SpawnSpec 一颗弹 + 一个 C++ behavior pack**；内容只给 id + float 参数。
- behavior 与积分在同一条原生管线里：`integrate` 先动位置，`behavior_tick` 再改速度/位置/动作。
- 需要组合时在 C++ pack 内用普通 `if` / `for` 写，不再维护通用 opcode VM。
- 预览走 `DanmakuStore.preview_behavior()`，与实战共用 tick。

## 附录 B · 一颗弹的完整路径（速查）

```
SpawnSpec（贴图/判定/阵营 + with_behavior）
  → ctx.bullets.shoot_spread_spec
  → KernelBulletHost.prepare_spec / KernelNativeSystem.spawn
  → DanmakuStore.integrate + behavior_tick（原生）
  → 只读快照 → BulletMultiMesh → MultiMesh
  → 判定 KernelBulletPhysics（原生宽相网格）
  → 出界/寿命/despawn 回收
```

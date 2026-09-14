# 🛠️ 东方星 STG 引擎 — 内容制作流程

> 版本：2026-09 · **原生内核版**（关卡/Boss/弹幕全在 Godot 里写代码；**弹幕行为走 `kernel_port()` 端口，原生执行**；工作台只做预览/调试）

---

## 0. 快速上手（加一个弹幕波次 / 一张符卡）

1. 在 Godot 编辑器里打开 `data/stages/stage01/stage_script/stage01.gd`（Timeline 编排）
2. 加 `timeline.at(时刻).do(func(): EnemyData.new().with_script(...).pos(...).spawn(ctx))`
   或经 `_dir.boss(key, data, from, to)` 进 Boss（场景动词），阶段用 `timeline.start_phase(...)`（时轴驱动）或 `handle.phase(n)`（事件驱动）
3. F6 运行工作台 → 命中框/固定种子/逐帧看效果；改完代码**重启工作台**生效
4. Boss 阶段/弹幕脚本（阶段目录下，如 `data/stages/stage01/phase/non_mid01/`）改完同样重启工作台看
5. **改某颗弹的飞行规律** → 见「六 · 弹幕行为接口」（`kernel_port()`：命名 `move + params`，或自定义拼 `{lifecycle}`）

> 工作台**不是编辑器**：不写数据、不热重载，是「跑真实代码看效果」的预览沙盒。
> 数据（关卡/Boss/阶段）全部以代码 + .tres 形式存在，由 AI/人直接写。

---

## 一、总体架构

```
① 关卡编排：stage01.gd（Timeline API，代码声明节奏/Boss/阶段）
② 行为层：  协程脚本 .gd（敌人行为 + Boss 移动/弹幕/入场/退场）
③ 数据层：  .tres 资源（BossData/PhaseData/敌人预设/符卡记录）
④ 预览层：  工作台 = 真实运行时沙盒（幽灵玩家 + 命中框 + 固定种子 + 书签）
```

数据关卡（wave_stage/StageTimeline/波次表）与脚本页/编排页已**移除**（2026-08 决策）：
弹幕的核心是逻辑不是数据，代码直写 + 工作台预览是当前唯一流程。

---

## 二、关卡编排（stage01.gd，Timeline API）

位置：`data/stages/stage01/stage_script/stage01.gd`（`extends CoroutineScript`）

```gdscript
const ENEMY01 = preload("res://data/stages/stage01/enemy/enemy01.gd")
const CAMORUI_MID = BossCatalog.boss(1, 0)   # 道中 Boss 数据（BossCatalog 单源）
const CAMORUI     = BossCatalog.boss(1, 1)   # 关底 Boss 数据（完整阶段链）

var _dir: StageDirector   # 场景导演：bgm/boss/dialogue/on —— 场景动词唯一 owner
var _mid: BossHandle      # 道中 Boss 句柄（reveal/phase/retreat）
var _final: BossHandle    # 关底 Boss 句柄

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	_dir = StageDirector.new(ctx)          # 导演：场景动词 + 事件路由
	var tl := start_timeline(_dir)         # 传导演：Timeline 便捷动词委托给它（单一 owner）
	timeline.at(0.0).play_bgm("stage1")          # 按 key（走 _dir.bgm；_dir 是唯一实现）
	timeline.at(1.0).do(func(): EnemyData.new().with_script(ENEMY01)...
		.pos(Vector2(...)).red_little_fairy().param("target_y", 200).spawn(ctx))
	# Boss 进场：spawn + register + 隐藏名 + tween —— 全在 _dir.boss 里
	timeline.at(35.0).do(func():
		_mid = _dir.boss("boss_mid", CAMORUI_MID, Vector2(-50, 500), Vector2(FIELD_CENTER_X, 250))
	)
	# 时轴驱动的阶段（保留 start_phase 的 wait 偏移继承）
	timeline.at(38.0).start_phase(func(): return _mid.resolve(), CAMORUI_MID.phases[0])  # 非符1
	# 战前对话事件路由（取代 _on_dialogue_event 大 match）：只调动词
	_dir.on("boss_enter",   func(): _final = _dir.boss("boss_final", CAMORUI, Vector2(1000, 500), Vector2(FIELD_CENTER_X, 250)))
	_dir.on("display_name", func(): _final.reveal("卡摩瑞"))
	_dir.on("boss_fight",   func(): _final.phase(0, true))
	super.start(ctx, target)
```

Timeline 链式 API：`at(t)` 绝对时刻 · `wait(n)` 相对上一 blocking 结束 · `do(cb)` 任意逻辑 ·
`start_phase(boss_getter, PhaseData)` 起阶段（保留时符等待：击破后激活后续 wait） · `every(times)` 重复。
**场景动词（bgm/spawn_*/dialogue）由 `StageDirector` 承担**，Timeline 只是薄委托：
`timeline.play_bgm/spawn_boss/spawn_enemy/spawn_wave/dialogue_steps` = `do(func(): _dir.xxx())`，**不用重复实现**。

> ⚠️ start_phase 链注意：`wait()` 后接 `start_phase()` 必须直接链（`timeline.wait(1.0).start_phase(...)`），
> 中间插 `do(pass)` 会破坏 wait 偏移继承（阶段会立即触发）。

---

## 三、敌人

### 敌人数据（构造链硬编码）

`EnemyData` 提供构造链：`red_little_fairy() / blue_middle_fairy() / red_middle_fairy() / ...`
（外观/血量/判定/掉落直接写死，`enemy_presets/*.tres` 已移除——数据即代码）。

### 行为脚本

位置：`data/stages/stage01/enemy/`（enemy01/02/03/04、fly_away 等）。
**直接引用**：关卡脚本 `preload()` 敌人行为，`EnemyData.new().with_script(ENEMY01)...` 构建——
无注册表、无中间层（EnemyTemplateRegistry/BossScriptRegistry 已随编辑器移除，2026-08）。

---

## 四、Boss（阶段数据 + 脚本目录）

### BossData / PhaseData（.tres）

- `BossData`（`data/stages/stage01/phase/` 参照）：`boss_name` / `visual` / `phases`（Normal 组）/ `phases_easy/hard/lunatic` / `enter_script` / `exit_script` / `score_value`
- `PhaseData`：`name`（空串 = 非符）、`uid`（0 = 非符不记；真符卡全局唯一）、`hp` / `time_limit` / `bonus`、`is_timeout_only`、`move_script` / `shoot_script`、掉落 item 系列、`params`

阶段示例（`data/stages/stage03B/phase/spell03/spell055.tres`——黄粱「不可测之梦」）：
```gdscript
[gd_resource type="Resource" script_class="PhaseData" format=3]
...
name = "黄粱「不可测之梦」"
uid = 55
time_limit = 40.0
hp = 4000
move_script = ExtResource("...random_dir_move.gd")
shoot_script = ExtResource("...orbit_spiral.gd")
```

**`params`（阶段级脚本参数覆盖，脚本复用通道）**：`Boss.start_phase` 时把 `params` 注入到该阶段的 move/shoot 脚本**同名属性**（脚本有此 var 才设置）。同一弹幕脚本给多个阶段复用、参数不同时用——不用复制脚本：

```gdscript
# phase/第二符卡.tres（复用 orbit_spiral）
shoot_script = ...orbit_spiral.gd
params = {
	"orbit_speed": 8.0,          # 覆盖脚本里的 var orbit_speed
	"hold_time": 3.0,            # 覆盖 hold_time
	"probe_count": [3, 5, 8, 12],
}
```

> 惯例：参数默认直接写在脚本 var 里（调参即改脚本）；`params` 只用于"同一脚本多形态"的覆盖场景。

### Boss 阶段脚本（协程 .gd + .tres 显式引用）

> ⚠️ 纠正（2026-08 目录重组后）：**没有"目录自动发现"**。阶段脚本由 `PhaseData.tres` 的
> `move_script` / `shoot_script` 字段**显式引用**，脚本与 `.tres` 放同一阶段的目录下就行。
> `data/boss_scripts/` 只是个别可复用移动脚本的存放处，不是自动扫描目录。

**惯例**：每个 Boss 阶段（非符/符卡）一个子目录，含 `.tres` + 它引用的 `*_move.gd` / `*_shoot.gd`（弹丸逻辑用 `bullet/` 或同目录脚本）：

```
data/stages/stage01/phase/
├── non01/           卡摩瑞的非符1
│   └── non01.tres
├── non_mid01/       道中非符1
│   ├── non_mid01.tres
│   ├── non_mid01_move.gd      # move_script
│   ├── non_mid01_shoot.gd     # shoot_script
│   └── non_mid01_bullet.gd    # 弹丸行为（被 shoot 引用）
└── spell01/
    └── spell001.tres
data/stages/stage03B/phase/spell03/      # 测试符卡（3 面 Boss「梦外见/黄粱」）
├── spell053~056.tres
├── orbit_spiral.gd                       # shoot_script（环绕发射器 + 探测弹）
└── orbit_probe.gd                        # 探测弹行为
```

**加新阶段 = 建目录 + 写 .gd + 建 .tres，`.tres` 里用 `move_script=ExtResource(...)` 指脚本**，
再在关卡脚本 `timeline.start_phase(getter, that_tres)`（时轴驱动）或 `handle.phase(index)`（事件驱动）引用。脚本文件即复用单元，跨阶段复用用 `params` 覆盖。

---

## 五、难度差分

- **Boss 阶段**：`BossData` 四组 phases（E/N/H/L），协程脚本里 `diff_pick()` 按难度取
- **敌人强度**：行为脚本内 `diff_pick([1, 3, 5, 8])` 运行时取参
- **UID 规则**：真符卡全局唯一（建议 1 面 100-199、2 面 200-299…）；非符 uid=0；角色共用 UID，SpellRecordBook 主键区分

---

## 六、脚本层约定

> 全部继承 `CoroutineScript`（`scripts/coroutine/base/coroutine_script.gd`）。

### 协程返回值约定

```gdscript
return ctx.clock.wait(2.0)  # 等待 2 秒后再次调用
return true                  # 下物理帧立即再次调用
return false                 # 结束协程
```

### 弹型实例复用（M2 起）

发射弹时**复用 `BulletData` 实例**，不要每发 `BulletData.new()`：内核弹型（`BulletType`）缓存在 `BulletData` **实例**上，每发 new 会让内核弹型表每发长一个。

```gdscript
var _bullet_data: BulletData   # 成员：建一次

func _fire(ctx):
	if _bullet_data == null:
		_bullet_data = BulletData.new().tex("小玉").speed(300).enemy()
	_bullet_data.velocity = Vector2(0, 300 + i * 50)   # 速度 / params 每发写（不属弹型）
	ctx.bullets.shoot_spread(_bullet_data, count, TAU, dir, pos)
```

> 类型级字段（贴图 / 阵营 / 判定 / 伤害 / 命中特效）在**首次发射时快照**；运行期改型需 `invalidate_bullet_type()`。
>
> 通过内核行为端口**延后发射**（`host.queue_spawn` / `on_flee_burst` 等）时，队列会在**入队瞬间**快照速度 / 染色，所以「复用实例 + 每发改速度」是安全的；但别在**入队之后、flush 之前**再改同一实例。

### 脚本文件地图

```
敌人行为   data/stages/stage01/enemy/   enemy01.gd / enemy02.gd / enemy03.gd / enemy04.gd / fly_away.gd（关卡脚本 preload 即用）
弹丸行为   data/stages/stage01/bullet/   gravity_bullet.gd / radial_accel_bullet.gd（被行为脚本 preload）
Boss 阶段  data/stages/?/phase/*/        每阶段一个目录：*.tres + *_{move,shoot,bullet}.gd（.tres 显式引用）
关卡专属   data/stages/stage01/          stage_script(stage01.gd) + phase/ + enemy/ + bullet/ + background/ + stage_data/
```

### 行为脚本示例

```gdscript
extends CoroutineScript
## 红杂鱼: 向下减速 + 自机狙 + 散射

var target_y: float = 300
var heavy_wave: bool = true
var rate: int = 1

func _ready() -> void:
	call_deferred("_init_enemy")

func _init_enemy() -> void:
	var parent := get_parent()
	# 移动 tween + 发弹（ctx.bullets.shoot_spread / ctx.clock.wait / timeline.at ...）
```

### 目录注解（创作台自动索引，2026-08+）

协程脚本会被**自动扫描**进创作台目录（`ContentCatalog`，只扫 `res://data/`、只收 `extends CoroutineScript/CoroutineRunner`）。
角色默认按**路径/命名约定**判定（`*_move.gd`→Boss移动 · `*_shoot.gd`→弹幕发射 · `*_bullet.gd`或`bullet/`→弹丸行为 ·
`enemy/`→敌人行为 · `stage_script/`→关卡编排 · `background/`→背景演出）；约定判不出时按**真实引用**反推（阶段 .tres 的 move/shoot 字段、发射脚本 preload 的弹丸）。

**注解可选，优先级最高**（写在文件头部注释块，与普通描述行混排即可）：

```gdscript
extends CoroutineScript
## 回卷探测弹：飞出→回点→分裂
## @role: bullet           # 角色覆盖（约定判错时才用；打架会出 warning）
## @name: 回卷探测弹        # 目录显示名（默认=注释首行）
## @desc: 描述（默认=其余注释行；@name 存在时=全部注释行）
```

### 弹幕行为接口（`kernel_port` → `move + params`）

弹丸脚本（`*_bullet.gd`）做一件事：把参数翻译成内核**端口**——**命名 `move`**（下表）或 **自定义 `{lifecycle}`**（下节）。**权威真相 = `scripts/kernel_bridge/lifecycle/lifecycle_catalog.gd` 的 `build()`**（下表由此抄出）。

```gdscript
extends CoroutineScript

var accel: float = 0.0
var bounce_angle: float = 0.0

func kernel_port() -> Dictionary:
    return {
        "move": &"bounce",
        "params": {&"accel": accel, &"bounce_angle": bounce_angle, &"sfx": "kira"},
    }
```

| `move` | 参数（括号内为默认） | 说明 |
|---|---|---|
| `world_accel` | `world_accel: Vector2` | 恒定世界加速度 |
| `accel` | `accel: float` | 沿当前方向加速 |
| `curve` | `curve`（角速度）、`curve_limit`（累计转角上限，0=无限） | 边飞边转 |
| `homing` | `homing_angle_per_sec`(720°)、`accel_time`(2)、`min_speed`(500)、`max_speed`(2000)、`homing_duration`(2)、`proximity_boost`(150) | 追踪最近敌人 |
| `radial_accel` | `accel_rate`、`spawn_factory: Callable`、`sfx`、`sfx_db` | 沿初向加速 + 碰顶换向下弹 |
| `bounce` | `accel`、`bounce_angle`、`spawn_speed`(0)、`spawn_factory`、`sfx`("kira")、`sfx_db`(-8) | 碰框朝 Boss 转 `bounce_angle` 后换弹 |
| `avoid_player` | （类型级固定；内容不覆盖） | 靠近自机逃 |
| `non_mid_flee` | `player_proximity`(150)、`boss_radius`、`on_flee_burst: Callable` | 逃 → 近 Boss 散圈（半径由内容按难度传） |
| `marisa_laser` | `anchor_id`、`anchor_offset`、`angle`、`drift_speed`(2000)、`initial_drift` | 子机锚定激光（World 兄弟，用 global） |
| `laser_follow` | 同上 | 自机子节点锚定（用局部 position） |

> - `spawn_factory` 是**换弹工厂**，返回 `BulletData`（内容侧提供；工厂实例要复用，别每发 new）。
> - **未知 `move` → 按直线发射**（计入 `unmapped_behavior_count`）。
> - **新增 `move`** = 在 `LifecycleCatalog.build()` 加分支，**就地用原语拼出组合**（组合唯一在此）；`BulletLifecycle` 的同名 preset 是可选类型化糖。**组合现有 Move/Until/Action 无需改 C++**；只有需要**新原语**才动 `gdextension/src/danmaku_store.cpp`。
> - **只是某一颗弹想要"预设表里没有"的组合** → 不用新增 `move`，见下节 `{lifecycle}`。

---

### 自定义行为（预设表不够时用 `{lifecycle}`）

上表 10 个 `move` 是**常用词汇**。要"预设表里没有"的流程控制组合，**不用新增 `move`**——直接在自己的弹丸脚本里用 `BulletLifecycle`（builder）拼好，端口返回 `{"lifecycle": ...}`：

```gdscript
extends CoroutineScript

var turn: float = 0.5
var accel: float = 300.0

func kernel_port() -> Dictionary:
    var lc := BulletLifecycle.new()
    lc.rotate(2.0, turn)      # 相位1：边飞边转
    lc.until_turned()         # 转满 turn 弧度
    lc.then()                 # ← 流程控制：开下一相位
    lc.accel_heading(accel)   # 相位2：沿当前方向加速
    lc.until_elapsed(1.0)
    lc.despawn()
    return {"lifecycle": lc}
```

可用词汇（**Move / Until / Action 三类**，签名见 `scripts/kernel_bridge/lifecycle/bullet_lifecycle.gd`）：

| 类 | 成员 |
|---|---|
| Move | `accel_world` `accel_heading` `rotate` `steer` `speed_lerp` `scale_speed` `set_heading` `set_speed` `anchor_drift` |
| Until | `until_never` `until_elapsed` `until_near` `until_at_wall` `until_state` `until_turned`；`then()` 开新相位 |
| Action | `sfx` `emit` `despawn` `on_end_heading` `on_end_call` |
| 方向糖 | `heading(angle)` / `toward(target, angle)` / `away(target, angle)` |

锚定激光（用了 `anchor_drift`）再带一个 `anchor`：

```gdscript
return {"lifecycle": lc, "anchor": {"id": anchor_id, "offset": offset, "use_global": true}}
```

> - **用哪个？** 稳定复用 / 有名字 → 上表的命名 `move`；一次性 / 流程控制组合 → `{lifecycle}`。
> - **边界**：固定 schema 描述符，**没有变量 / 表达式 / goto**，相位线性（`then()` 只往下）。超出语言的部分只能用 `emit`（换弹工厂）/ `on_end_call`（回调 GDScript）两个逃生舱，或加新原语（改 C++）。
> - **验证范式**：`test/fixtures/lifecycle_port_behavior.gd` + `test/test_lifecycle_port.gd`。

---

## 七、调试（工作台工具链）

| 工具 | 用法 |
|------|------|
| 固定种子 | 播放区开关：重跑弹幕序列可复现（调参必备） |
| 命中框 | 播放区开关：红=敌弹判定、绿=敌人、青=自机、蓝=擦弹 |
| 逐帧 | 暂停中按 F：精确走 1/60s |
| 跳转 | 点时间轴/书签/←→ = 12x 快进到目标（真实关卡无任意 seek） |
| 书签 | 时间轴右键/快捷键 B 打点；协程关卡静态提取 timeline.at() 时刻 + 人工打点 |
| 幽灵玩家 | 自机狙目标（不攻击，看弹幕用） |

快捷键：`Space` 暂停/继续 · `R` 重跑 · `F` 逐帧 · `1~7` 速度 · `←/→` ±1s（Ctrl ±5s）·
`B` 书签 · `Home` 回开头

> 改代码后**重启工作台**生效（无热重载）。写代码在 Godot 编辑器，看效果在工作台。

---

## 八、挂到游戏

1. MainMenu → Start → 选难度 → 选角色 → `GameManager.change_scene("game_scene")`
2. `GameScene._ready()` → `_resolve_stage_data()` → `StageRuntime.load_stage(data)`
   （`data/registry/stage_registry.tres`：Stage 1 → `stage01.tres` 协程版）
3. 练习模式：从符卡记录（`spell_records.tres` 解锁后内联存的 phase_data + boss_scene）构建单 phase Boss，
   走 `SaveData.start_practice()` → `_start_practice_game()`

---

## 九、符卡练习 / 菜单 / 对话

- **符卡簿**：`data/registry/spell_records.tres`，见到即记（unlock_spell），自动按 UID 记录尝试/捕获/最佳
- **符卡练习（单驱动）**：练习菜单 = 符卡簿记录决定"能练哪张"，记录里**内联存战斗配置**
  （phase_data + boss_scene，见 `spell_record.gd` 注释"无需 CardDef"）。已解锁的符卡可选任意难度进入。
  `CardDef` / `spell_registry.tres` 早已移除（2026-08，放弃"双驱动"）。练习入口默认锁定：
  MainMenu 的 Spell Practice 在符卡簿为空时锁定，有记录（解锁过符卡）才可进入。
- **菜单页**：`scenes/ui/*_menu.tscn` 继承 BasePage（`scripts/scenes/menu_nav.gd` 导航）
- **对话（DSL 台词内联，2026-08 重构）**：`DialogueSteps` 流程 DSL，**台词直接写在代码里**（与弹幕编排同构）：
  `enter/say/line/move/flip/dim/portrait/bubble/event/wait` → `ctx.play_dialogue_steps(steps)`。
  `line()` 延续上一说话者、`say(profile, text)` 换人；`d.event(key)` 是行间事件，时机精确。
  参考：`data/stages/stage01/stage_script/stage01.gd` 战前对话、`docs/DIALOGUE_SYSTEM.md`、剧本归档 `docs/DIALOGUE.md`

---

## 十、已知边界

- 运行时保存 .tres 依赖 res:// 可写（开发模式）；导出包只读，符卡簿保存会失败（待数据迁移方案）
- **弹丸协程脚本**（gravity_bullet.gd 等，被行为脚本 preload）与所有脚本改动都需**重启工作台**生效
- 敌人/Boss 脚本零注册：preload/直接引用即用

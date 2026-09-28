# 东方星尘回 对话系统 - 当前设计说明

> 本文件原为《对话系统重构专项计划》，阶段 0-5 已完成（台词库/.tres/旧 lines 模型已退役）。
> 这里改为当前对话系统的架构与用法说明。对白内容（剧本）见 docs/DIALOGUE.md（归档），
> 实际台词写在 data/dialogue/<角色>/<面>_dialogue.gd 的**构建函数**里（`static`，函数名随内容，如 `战斗前()` / `战斗后()`）。

---

## 一、分层

1. 编排（内容）：data/dialogue/<角色>/<面>_dialogue.gd -> `static <构建函数>()` -> DialogueSteps
   纯逻辑、不碰 ctx；行间事件只作步骤标记，交由 stage 消费
   ⚠️ **必须 `static`**：调用点是 `const INTRO = preload("…/xxx.gd")` + `INTRO.战斗前()` —— 在**脚本类**上调用只认静态函数
   （非 static 会 `Parse Error: Static function "…" not found in base …`）。非要用非静态就得 `INTRO.new().战斗前()`
   （`extends RefCounted` 支持，但纯生产步骤的脚本没有实例状态，白搭一次分配）。
2. 舞台状态（真相）：StageState/ActorState：谁在场/位置/翻转/明暗/表情  <- 唯一真相
   状态「声明即改变，不声明不动」；进/退场/移动/表情全是显式步骤
3. 渲染播放器：DialogueBox（CanvasLayer）+ BubblePanel：只消费状态快照 + 转发事件

## 二、编排（文件化，台词内联）

一个面/一个角色的对话放一个脚本（如 `data/dialogue/stage/stage01_dialogue.gd`），里面按段落放多个构建函数：

    static func 战斗前() -> DialogueSteps:
        var d := DialogueSteps.new()
        var reimu := d.enter(REIMU, Vector2(50, 230))       # ← 返回 ActorHandle（"谁"是接收者）
        reimu.line("啊，什么线索都没有，怎么解决异变啊…")
        d.event("boss_enter")                               # 行间事件（无角色的步骤留在 d 上）
        d.wait(2.0)
        var ka := d.enter(KA, Vector2(550, 230))
        ka.line("而且\n在黑暗中，我可更胜一筹！", {"emotion": "耍帅"})
        ka.portrait("耍帅").move(Vector2(500, 230), 0.6)     # 演出动词可链式
        d.event("boss_fight")
        return d

**多角色同屏**用 `d.screen([[REIMU, "叹气", ""], [KA, "耍帅", "…"]])`（句柄表达不了"一屏多泡"）。
句柄只是**薄委托** —— 低层写法 `d.say(p, …)` / `d.move(p, …)`（收 profile）产物完全一致，可混用
（`test_actor_handle_matches_low_level_verbs` 锁这条）。

关卡脚本只需一行：`_stage_director.dialogue(STAGE01_REIMU.战斗前())`
（**收 `DialogueSteps` 本身**，不是它的 `.steps` 数组 —— 参数有类型，传错在编译期就被拦住；
`stage01.gd` 里就是这么接的；路径现按**角色**分目录：`data/dialogue/<角色>/<面>_dialogue.gd`）。

### 战后对话 / 用对话收尾（推荐写法）

"Boss 打完 → 说几句话 → 关卡结束"**用行间事件收口**（比起用 `wait(秒)` 接更稳）：

```gdscript
# ① 对话文件里（同一个 <角色>/<面>_dialogue.gd 里加第二个 static 构建函数）
static func 战斗后() -> DialogueSteps:
	var d := DialogueSteps.new()
	d.screen([[KA, "叹气", "……"]])
	d.screen([[REIMU, "通常", "……"]])
	d.event("stage_end")        # ← 最后一步：读完这句 → 关卡收尾
	return d

# ② 关卡脚本：注册路由 + 摆时间点（wait 由"最后一张击破"武装）
_stage_director.on("stage_end", _on_stage_end)          # 在 _build()/_on_start() 里注册
...
_timeline.wait(2.0).do(func(): handle.defeat())                                   # 全破演出
_timeline.wait(4.5).do(func(): _stage_director.dialogue(STAGE01_REIMU.战斗后()))
func _on_stage_end() -> void: _stage_director.finish_stage()
```

> **为什么推荐事件收口**（而不是 `wait(6.0) → finish_stage()`）：
> 1. **不依赖实现细节**：对话播放时 `DialogueService.play_steps` 会 `pause()` **宿主 runner**，
>    所以时间轴在对话期间**确实**不推进（`wait` 的事后偏移其实能"顺延"到对话结束）——
>    但这是播放器的内部行为，哪天改掉，`wait` 方案就会**在对话中途收尾**，而且是静默的。
> 2. **偏移是绝对值**：`wait(n)` 都从"最后一张击破"那个游标算起（不是"上一句之后"），
>    所以两个 wait 的先后关系要靠**手算秒数**维持，台词/演出时长一变就要重算。
> 3. **语义直白**：`stage_end` 表达"剧本最后一句 = 这关结束"，与台词长短天然解耦。
> 战前的 `boss_enter` / `boss_fight` 是同一套机制。

## 三、DSL 步骤（DialogueSteps）

**两种等价写法**（句柄是薄委托，产物完全一致，可混用）：

| 句柄（推荐 · 谁做什么） | 低层（收 profile） | 说明 |
|---|---|---|
| `var h := d.enter(profile, pos, opts?)` | 同上 | 登场；**返回 `ActorHandle`**；进场后成为延续说话者 |
| `h.line(text, opts?)` | `d.say(profile, text, opts?)` | 该角色说一句（`opts.emotion` / `auto_advance` / `speaker`） |
| `d.line(text, opts?)` | — | 延续上一说话者（序列级便利） |
| `h.move(pos, dur?)` / `.flip(on)` / `.dim(v)` / `.portrait(key)` / `.bubble(offset)` | `d.move(profile, …)` 等 | 演出版：位置/翻转/明暗/表情/气泡偏移（**可链式**） |
| `h.exit()` | `d.exit(profile)` | 退场（`actor.visible = false`） |
| `d.screen(specs, opts?)` | — | **一屏多泡**（多角色同屏；句柄表达不了） |
| `d.event(key)` / `d.wait(sec)` | — | 行间事件 / 停顿（与角色无关，留在 `d` 上） |

> - **所有"演出版"动词都收 `CharacterProfile`**（与 enter/say 一致）。步骤里最终落的是 **actor key**
>   （= `profile.char_name`，播放器按它查 actor），但那是**内部细节**：内容层不写字符串 key，
>   角色改名不会静默漏掉编排，写错也拼不出"差不多的名字"。
> - 句柄**只在构建期写步骤**（不做运行时解析），动词一律返回 `self` 可链式；
>   `h.exit()` 之后再用同一句柄会**告警一次**（不拦步骤）；
>   `d.enter()` 同一角色连续两次（漏 `exit`）也会告警；`d.has_entered(profile)` 可自检。
> - **情绪：不声明就不动**（"声明即改变"）—— `opts.emotion` / screen 的 emotion 留空 = 保持该角色当前表情；
>   想复位写 `{"emotion": "通常"}`。所以 `h.portrait("笑").line("…")` 与
>   `d.screen([[p, "笑", "…"]])` 等效（前者更适合"先摆姿势再说一串"）。
>   ⚠️ 曾因 `_build_line` 默认写 `"通常"` 把上一步设的表情冲掉（句柄写法暴露的老 bug，已修 + 有回归测试）。

### screen()：数组式一屏多泡

    d.screen([[REIMU, "笑", "A"], [KA, "震惊", ""]])
    # 每项 = [speaker, emotion, text]（也可用 {speaker, emotion, text} 字典）
    # text 空 -> 该角色在场但沉默（自动变暗 0.35，表情照旧）
    # 多泡 -> 同屏多人（齐声/一起在场）

- 显式要求：每屏至少一个真正开口的（text 非空），否则 assert 拦截；纯沉默转场用 wait()。
- 延续说话者 = 最后一个 text 非空的角色（方便后续 line() 继续）。

## 四、行间事件

d.event(key) 在步骤序列任意位置触发 -> DialogueBox 转发 GameEvents.dialogue_event(key) -> 
stage 用 `_stage_director.on(key, handler)` 消费（如 boss_enter 进 Boss、bgm_switch 切歌、
boss_fight 开战、**stage_end 收尾**）。事件即时执行、**事件本身不冻结任何东西**。

> **派发只在关卡存活时发生**：`StageDirector._route` 统一判 `ctx.active()` ——
> 关卡拆掉/未装配后事件一律忽略，所以 **handler 里不必再写 `if ctx.active()`**。

> ⚠️ 别和"对话播放会不会冻结时间轴"混为一谈：**事件**不冻结；
> 但**整段对话播放期间**，`DialogueService.play_steps` 会 `pause()` **宿主 runner**
> （`box.finished` 再 `resume()`）→ 宿主的时间轴在对话期间不推进。两者是两件事。

## 五、播放器 / 可暂停

- DialogueBox 是 PROCESS_MODE_ALWAYS；对话可被暂停（符合设计）。
- 暂停（GameManager PAUSED）时 _process 跳过 _runner.tick（WAIT/auto_advance 计时冻结），_input 也跳过；恢复后从原地继续。
- 去无操作 Tween：位置/明暗/表情/在场未变则不重建 Tween/贴图（last_* 记录上次目标）。
- 气泡偏移默认来自 CharacterProfile.default_bubble_offset（作者不手调魔法数字）。

## 六、测试与预览

**自动化**：test_dialogue_steps.gd（纯逻辑 DSL/状态/Runner）· test_dialogue.gd（播放冒烟/事件/表情）·
test_stage01_dialogue.gd（第一面内容 + **干跑**：整段必须跑得完、事件顺序）· test_dialogue_pause.gd（可暂停性）。
全量：./test/run_tests.sh

**手动预览（不用打关卡）**：`scenes/ui/dialogue_preview.tscn` —— 直接播任意一段构建函数。
**三种用法**（优先级：命令行 > `@export` > 默认）：

```
① 编辑器里：打开该场景 → F5。右侧面板直接换「脚本 / 段落」；也可在 Inspector 里设
   `dialogue_script` / `dialogue_func`（留空 = 默认脚本 / 第一个构建函数）与 `auto_play`
   （**默认关**：进来先看清面板、挑好段再按「▶ 播放」；想"进场景即播"就勾上）
② 窗口内：下拉换段（换脚本自动刷新段落列表）·「▶ 播放」/ R 重播 · Q 退出
   —— **换段只是"选好"**：会停掉当前演出但不自动开新的，要播按 ▶ / R（与 `auto_play` 默认关一致）
③ 命令行（自动化/无头）：
```

> `--script=` / `--func=` 出现即视为"现在就播"（自动化那条路不受 `auto_play` 影响）；
> `--shot=` 只负责**截图当前状态**，本身不触发播放。

```bash
# 列出所有对话脚本 + 可用的构建函数
godot --headless --path . scenes/ui/dialogue_preview.tscn -- --list

# 干跑：不开窗，按顺序打印整段文本/事件（改完台词的最快检查；卡住会点名）
godot --headless --path . scenes/ui/dialogue_preview.tscn -- --func=战斗后 --dry

# 窗口：真 DialogueBox 演出（Z/Enter 下一句 · X 跳过/长按关闭 · R 重播 · Q 退出）
godot --path . scenes/ui/dialogue_preview.tscn -- --func=战斗后

# 截图（看一眼 / 自动化检查）：等首句稳定后存图退出
godot --path . scenes/ui/dialogue_preview.tscn -- --func=战斗后 --shot=/tmp/dlg.png
```

> - `--script` 省略 → 默认 `data/dialogue/stage/stage01_dialogue.gd`；`--func` 省略 → 该脚本的**第一个**构建函数；
>   名字写错 → 告警并回落到第一个（不静默）。
> - 构建函数识别看**元数据**（`static` + 零参数 + 返回 `DialogueSteps`），不靠命名约定。
> - 预览背景只是参照（游戏里立绘画在**全屏** CanvasLayer 上，不受场地框限制）；
>   要连背景一起看就进关卡或用工作台。

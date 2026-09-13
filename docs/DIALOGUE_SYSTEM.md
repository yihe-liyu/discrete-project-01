# 东方星尘回 对话系统 - 当前设计说明

> 本文件原为《对话系统重构专项计划》，阶段 0-5 已完成（台词库/.tres/旧 lines 模型已退役）。
> 这里改为当前对话系统的架构与用法说明。对白内容（剧本）见 docs/DIALOGUE.md（归档），
> 实际台词写在 data/dialogue/<stage>/xxx.gd 的 build() 里。

---

## 一、分层

1. 编排（内容）：data/dialogue/<stage>/xxx.gd -> static build() -> DialogueSteps
   纯逻辑、不碰 ctx；行间事件只作步骤标记，交由 stage 消费
2. 舞台状态（真相）：StageState/ActorState：谁在场/位置/翻转/明暗/表情  <- 唯一真相
   状态「声明即改变，不声明不动」；进/退场/移动/表情全是显式步骤
3. 渲染播放器：DialogueBox（CanvasLayer）+ BubblePanel：只消费状态快照 + 转发事件

## 二、编排（文件化，台词内联）

每个对话段一个独立脚本，如 data/dialogue/stage01/intro.gd：

    static func build() -> DialogueSteps:
        var d := DialogueSteps.new()
        d.enter(REIMU, Vector2(50, 230))
        d.screen([[REIMU, "通常", "啊，什么线索都没有，怎么解决异变啊…"]])
        d.event("boss_enter")           # 行间事件
        d.wait(2.0)
        d.enter(KA, Vector2(550, 230))
        d.screen([[REIMU, "叹气", ""], [KA, "耍帅", "而且\n在黑暗中，我可更胜一筹！"]])
        d.event("boss_fight")
        return d

关卡脚本只需一行：ctx.play_dialogue_steps(STAGE01_INTRO.build().steps)。

## 三、DSL 步骤（DialogueSteps）

- enter(profile, pos, opts?)：登场（可带 flip/dim/emotion）；进场后成为延续说话者
- line(text, opts?)：一句台词，延续上一说话者（opts.speaker 换人）
- say(profile, text, opts?)：指定说话者的台词
- screen(specs, opts?)：一屏多泡（见下）
- move / flip / dim / portrait / bubble：演出版（位置/翻转/明暗/表情/气泡偏移）
- exit(char_name)：退场（actor.visible=false）
- event(key)：行间事件，时机精确
- wait(sec)：停顿（纯沉默转场用这个）

### screen()：数组式一屏多泡

    d.screen([[REIMU, "笑", "A"], [KA, "震惊", ""]])
    # 每项 = [speaker, emotion, text]（也可用 {speaker, emotion, text} 字典）
    # text 空 -> 该角色在场但沉默（自动变暗 0.35，表情照旧）
    # 多泡 -> 同屏多人（齐声/一起在场）

- 显式要求：每屏至少一个真正开口的（text 非空），否则 assert 拦截；纯沉默转场用 wait()。
- 延续说话者 = 最后一个 text 非空的角色（方便后续 line() 继续）。

## 四、行间事件

d.event(key) 在步骤序列任意位置触发 -> DialogueBox 转发 GameEvents.dialogue_event(key) -> 
stage 的 _on_dialogue_event 按 key 消费（如 boss_enter 进 Boss、bgm_switch 切歌、boss_fight 开战）。
事件即时执行、不冻结时间轴。

## 五、播放器 / 可暂停

- DialogueBox 是 PROCESS_MODE_ALWAYS；对话可被暂停（符合设计）。
- 暂停（GameManager PAUSED）时 _process 跳过 _runner.tick（WAIT/auto_advance 计时冻结），_input 也跳过；恢复后从原地继续。
- 去无操作 Tween：位置/明暗/表情/在场未变则不重建 Tween/贴图（last_* 记录上次目标）。
- 气泡偏移默认来自 CharacterProfile.default_bubble_offset（作者不手调魔法数字）。

## 六、测试

test_dialogue_steps.gd（纯逻辑 DSL/状态/Runner）· test_dialogue.gd（播放冒烟/事件/表情）·
test_stage01_dialogue.gd（第一面内容）· test_dialogue_pause.gd（可暂停性）。全量：./test/run_tests.sh

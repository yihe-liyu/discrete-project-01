extends Node
## 全局信号总线 — 信号由其他脚本 emit/connect

@warning_ignore("unused_signal")
signal enemy_killed(score: int, position: Vector2)
@warning_ignore("unused_signal")
signal item_score(score: int, position: Vector2, is_auto_collect: bool)
@warning_ignore("unused_signal")
signal player_death()
@warning_ignore("unused_signal")
signal player_missed()  ## 每次 miss（中弹掉残机）都发——boss 记录东方规则用

@warning_ignore("unused_signal")
signal boss_spawned(boss: Enemy)
@warning_ignore("unused_signal")
signal boss_defeated(boss: Enemy)
@warning_ignore("unused_signal")
signal phase_start(phase: PhaseData)
@warning_ignore("unused_signal")
signal phase_end(captured: bool, bonus: int)
@warning_ignore("unused_signal")
signal phase_bonus_tick(bonus: int)
@warning_ignore("unused_signal")
signal dialogue_event(event: String)

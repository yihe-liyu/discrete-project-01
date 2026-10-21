## 内容协程的 async 风格基类：用 [code]await ctx.clock.delay(...)[/code] 代替 [code]_tick[/code] 的返回值状态机。
##
## 用法：
##   extends AsyncCoroutineScript
##   func run_async(ctx: StageContext) -> void:
##       while ctx.active():
##           RING.new().fire(ctx, p, target.global_position, dir)
##           if not await ctx.clock.delay(0.8):
##               return
##
## 保证：
##   - 时钟仍是 [CoroutineRunner] 的物理时钟 ⇒ pause / 逐帧 / 快进 / tick_manual 一致
##   - 旧 [code]_tick[/code] 脚本完全不受影响；两者可以混用
##   - [code]await[/code] 只应等 [code]ctx.clock.*[/code]（或一次性 UI 信号）；不要用引擎 Timer
##
## 不用于倒带：async 状态不能回退；向后 seek 仍需“重跑 + 快进”。
## 不要让同一个实例 [code]start()[/code] 两次（旧 await 可能复活）；换关请新建脚本实例。
class_name AsyncCoroutineScript
extends CoroutineScript

## 覆写它来写内容。必须包含 await（基类默认只等一帧）。
func run_async(p_ctx: StageContext) -> void:
	await p_ctx.clock.next_tick()


func start(p_ctx: StageContext, p_target: Node2D = null) -> void:
	ctx = p_ctx
	if p_target != null:
		target = p_target
	_on_start()          # 一次性同步初始化（ctx/target 已就绪）
	begin_async()        # 设 is_running / 清 task / 保留 keepalive
	_run_async()         # 故意不 await：让 async 函数跑到第一个 await 后返回


func _run_async() -> void:
	await run_async(ctx)
	end_async()          # 正常返回：停 runner + 发 finished

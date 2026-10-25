extends RefCounted
## 一面对话

const REIMU := preload("res://data/dialogue/profile/reimu_profile.tres")
const MARISA := preload("res://data/dialogue/profile/marisa_profile.tres")
const KA := preload("res://data/dialogue/profile/ka_profile.tres")


static func 灵梦战斗前() -> DialogueSteps:
	var 对话 := DialogueSteps.new()
	var 灵梦 = 对话.enter(REIMU, Vector2(50, 230))
	灵梦.portrait("通常").line("啊，什么线索都没有，怎么解决异变啊…")
	灵梦.portrait("笑").line("除非…\n刚才的小妖怪～")
	对话.event("boss_enter")  # 说完：卡摩瑞本体（Boss 实体）进场
	对话.wait(1.0)
	var 卡摩瑞 = 对话.enter(KA, Vector2(550, 230))
	卡摩瑞.portrait("疑惑").line("哦呀，弱小的人类怎么会在永夜出门？")
	卡摩瑞.portrait("通常").line("快回家去吧。")
	对话.event("display_name")
	卡摩瑞.portrait("耍帅").line("虽然卡摩瑞我只是蝙蝠，但是再不走的话…")
	灵梦.portrait("通常").line("已经是人形了却不好好长眼睛啊。")
	灵梦.portrait("疑惑").line("把日食当夜晚吗？")
	灵梦.portrait("叹气").line("我是巫女，我若是回家了，谁来解决异变呐，小小的蝙蝠哟？")
	卡摩瑞.portrait("震惊").line("啊，竟然遇到巫女了吗？")
	灵梦.portrait("通常").line("唉，肯定没有线索啦。")
	灵梦.portrait("笑").line("所以让开吧？")
	对话.event("bgm_switch")
	卡摩瑞.portrait("震惊").line("不，不行。\n如果真见到了传说中的巫女，怎么能不打一场！")
	灵梦.portrait("叹气")
	卡摩瑞.portrait("耍帅").line("而且\n在黑暗中，我可更胜一筹！")
	对话.event("boss_fight")  # 行间事件：最后一句说完 → Boss 开战
	return 对话


static func 灵梦战斗后() -> DialogueSteps:
	var 对话 := DialogueSteps.new()
	var 灵梦 = 对话.enter(REIMU, Vector2(50, 230))
	var 卡摩瑞 = 对话.enter(KA, Vector2(550, 230))
	灵梦.portrait("通常")
	卡摩瑞.portrait("战败").line("呜……")
	卡摩瑞.portrait("战败").line("真的是巫女啊……")
	灵梦.portrait("叹气").line("明明知道我的厉害还要来妨碍我……")
	卡摩瑞.portrait("战败").line("……")
	对话.exit(KA)
	灵梦.portrait("笑").line("哦？有新的线索出现了～")
	对话.event("stage_end")  # 行间事件：最后一句读完 → 这关结束（关卡脚本 finish_stage）
	return 对话

static func 魔理沙战斗前() -> DialogueSteps:
	var 对话 := DialogueSteps.new()
	var 魔理沙 = 对话.enter(MARISA, Vector2(0, 230))
	魔理沙.portrait("笑").line("啊，应该没有什么人在这种时候还出来吧？")
	魔理沙.portrait("疑惑").line("那该怎么找线索呢？")
	对话.event("boss_enter")
	对话.wait(1.0)
	var 卡摩瑞 = 对话.enter(KA, Vector2(550, 230))
	卡摩瑞.portrait("通常").line("哈哈，你自己不就出来了吗？")
	魔理沙.portrait("尴尬").line("真是同归于尽啊……")
	卡摩瑞.portrait("通常").line("不过既然你已经不聪明到现在还出来了。")
	魔理沙.portrait("通常")
	卡摩瑞.portrait("耍帅").line("那你就快回家去吧，在这样的永夜。")
	魔理沙.portrait("疑惑").line("明明是妖怪耶，就这么放我走了？")
	魔理沙.portrait("笑").line("我还没有问到什么线索呢。")
	卡摩瑞.portrait("疑惑").line("哈？")
	魔理沙.portrait("笑").line("你叫什么名字啊？")
	对话.event("display_name")
	卡摩瑞.line("我叫，卡摩瑞。")
	魔理沙.portrait("通常").line("你知道外面的日食是怎么回事吗？")
	卡摩瑞.line("日食是什么东西？")
	魔理沙.portrait("疑惑").line("就是太阳被月亮遮住，让天变的很黑啊。")
	卡摩瑞.portrait("震惊")
	魔理沙.portrait("通常").line("但是现在太阳一直在被遮住，很奇怪呢。")
	卡摩瑞.line("啊？\n永夜是这么形成的？")
	魔理沙.portrait("叹气").line("看样子你跟我一样，也什么都不知道呢。")
	对话.event("bgm_switch")
	魔理沙.portrait("笑").line("那我们还是先来玩一玩吧？")
	卡摩瑞.portrait("疑惑").line("啊？？？")
	对话.event("boss_fight")
	return 对话

static func 魔理沙战斗后() -> DialogueSteps:
	var 对话 := DialogueSteps.new()
	var 魔理沙 = 对话.enter(MARISA, Vector2(0, 230))
	var 卡摩瑞 = 对话.enter(KA, Vector2(550, 230))
	卡摩瑞.portrait("战败").line("我记得我没做什么坏事啊？")
	卡摩瑞.portrait("战败").line("怎么就被打了一顿呢……")
	魔理沙.portrait("尴尬").line("好像有点暴力了……")
	魔理沙.portrait("通常").line("这家伙是什么妖怪啊？")
	卡摩瑞.portrait("战败").line("我是蝙蝠……")
	魔理沙.portrait("叹气").line("怎么都看不出来啊。")
	卡摩瑞.portrait("战败").line("……")
	魔理沙.portrait("震惊").line("抱歉啊，我看到有新的线索了，我得先走了！")
	对话.event("stage_end")
	return 对话

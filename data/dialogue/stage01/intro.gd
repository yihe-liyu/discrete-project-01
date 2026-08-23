extends RefCounted
## 第一面战前对话编排（台词内联 DSL）—— 独立构建，纯逻辑不碰 ctx/编排。
## "只生产步骤"，行间事件（boss_enter/bgm_switch/boss_fight）留作步骤标记，
## 由 stage 的 _on_dialogue_event 消费（Boss 生成/切歌/开战）。
## 可供 stage 脚本加载、内容测试，以及（如有）独立预览复用。

const REIMU := preload("res://data/dialogue/profile/reimu_profile.tres")
const KA := preload("res://data/dialogue/profile/ka_profile.tres")


static func build() -> DialogueSteps:
	var d := DialogueSteps.new()
	d.enter(REIMU, Vector2(50, 230))
	d.bubble("灵梦", Vector2(-150, 250))
	d.line("啊，什么线索都没有，怎么解决异变啊…")
	d.line("除非…\n刚才的小妖怪～", {"emotion": "笑"})
	d.event("boss_enter")  # ← r2 说完：卡摩瑞本体（Boss 实体）进场
	d.wait(2.0)
	d.enter(KA, Vector2(550, 230))
	d.bubble("卡摩瑞", Vector2(-650, 250))
	d.line("哦呀，弱小的人类怎么会在永夜出门？", {"emotion": "疑惑"})
	d.line("快回家去吧。")
	d.line("虽然卡摩瑞我只是蝙蝠，但是再不走的话…", {"emotion": "耍帅"})
	d.say(REIMU, "已经是人形了却不好好长眼睛啊。")
	d.line("把日食当夜晚吗？", {"emotion": "疑惑"})
	d.line("我是巫女，我若是回家了，谁来解决异变呐，小小的蝙蝠哟？", {"emotion": "叹气"})
	d.say(KA, "啊，竟然遇到巫女了吗？", {"emotion": "震惊"})
	d.say(REIMU, "唉，肯定没有线索啦。")
	d.line("所以让开吧？", {"emotion": "笑"})
	d.say(KA, "不，不行。\n如果真见到了传说中的巫女，怎么能不打一场！", {"emotion": "震惊"})
	d.event("bgm_switch")  # 行间事件：该一句说完 → 切 Boss 主题曲
	d.line("而且\n在黑暗中，我可更胜一筹！", {"emotion": "耍帅"})
	d.event("boss_fight")  # 行间事件：最后一句说完 → Boss 开战
	return d

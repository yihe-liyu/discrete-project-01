extends RefCounted
## 第一面战前对话编排（台词内联 DSL）—— 独立构建，纯逻辑不碰 ctx/编排。
## "只生产步骤"，行间事件（boss_enter/bgm_switch/boss_fight）留作步骤标记，
## 由 stage 的 _on_dialogue_event 消费（Boss 生成/切歌/开战）。
## 可供 stage 脚本加载、内容测试，以及（如有）独立预览复用。
##
## 编排用 screen()：每项 [speaker, emotion, text]（谁 / 什么表情 / 说什么话）。
## text 空 = 该角色在场但沉默（自动暗）；同屏多人就把多项放进同一个 screen。

const REIMU := preload("res://data/dialogue/profile/reimu_profile.tres")
const KA := preload("res://data/dialogue/profile/ka_profile.tres")


static func build() -> DialogueSteps:
	var d := DialogueSteps.new()
	d.enter(REIMU, Vector2(50, 230))
	d.screen([[REIMU, "通常", "啊，什么线索都没有，怎么解决异变啊…"]])
	d.screen([[REIMU, "笑", "除非…\n刚才的小妖怪～"]])
	d.event("boss_enter")  # ← r2 说完：卡摩瑞本体（Boss 实体）进场
	d.wait(2.0)
	d.enter(KA, Vector2(550, 230))
	d.screen([[KA, "疑惑", "哦呀，弱小的人类怎么会在永夜出门？"]])
	d.screen([[KA, "通常", "快回家去吧。"]])
	d.screen([[KA, "耍帅", "虽然卡摩瑞我只是蝙蝠，但是再不走的话…"]])
	d.event("display_name")
	d.screen([[REIMU, "通常", "已经是人形了却不好好长眼睛啊。"]])
	d.screen([[REIMU, "疑惑", "把日食当夜晚吗？"]])
	d.screen([[REIMU, "叹气", "我是巫女，我若是回家了，谁来解决异变呐，小小的蝙蝠哟？"]])
	d.screen([[KA, "震惊", "啊，竟然遇到巫女了吗？"]])
	d.screen([[REIMU, "通常", "唉，肯定没有线索啦。"]])
	d.screen([[REIMU, "笑", "所以让开吧？"]])
	d.screen([[KA, "震惊", "不，不行。\n如果真见到了传说中的巫女，怎么能不打一场！"]])
	d.event("bgm_switch")  # 行间事件：该一句说完 → 切 Boss 主题曲
	d.screen([[REIMU, "叹气", ""],
			  [KA, "耍帅", "而且\n在黑暗中，我可更胜一筹！"]])
	d.event("boss_fight")  # 行间事件：最后一句说完 → Boss 开战
	return d

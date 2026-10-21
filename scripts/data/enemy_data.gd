## 敌人配置：外观、血量、判定、掉落、行为脚本与参数（构造链 + .tres 预设）。
##
## [b]模型[/b][br]
## [codeblock]
## EnemyData.new()
##     .with_script(ENEMY01)
##     .pos(Vector2(...))
##     .red_little_fairy()
##     .param("target_y", 150)
## [/codeblock]
## [StageRuntime] 读取生成位置与参数：实例化行为脚本、用 ParamValidator 严格注入 params、挂到 Enemy 下。
## [br]
## [b]边界[/b][br]
## - [code]pos[/code] 是运行时逐实例数据，不写入 .tres。[br]
## - params 只灌这一个行为脚本；未知键按打错处理（严格）。[br]
## - 构造链方法都改自身并返回 self，同一实例多次生成会共享最后一次写入的值。[br]
## - [method validate] 只查必填项；脚本类型 / 参数键名到生成时再校验。
extends Resource
class_name EnemyData

## 外观场景；空 = Enemy 不挂外观。
@export var visual_scene: PackedScene
## 最大生命。
@export var max_hp: int = 100
## 判定半径（像素）。
@export var hitbox_radius: float = 8.0
## 击破分数。
@export var score_value: int = 100
## 死亡特效；留空 = 用 AssetRegistry.enemy_visuals["death"]。
@export var death_effect: PackedScene
## Boss 数据（可选；当前敌人生成不读它）。
var boss_data: BossData

## 掉落 P 道具数。
@export var item_power: int = 0
## 掉落点道具数。
@export var item_point: int = 0
## 掉落命碎片数。
@export var item_life: int = 0
## 掉落雷碎片数。
@export var item_bomb: int = 0
## 掉落整命数。
@export var item_life_full: int = 0
## 掉落整雷数。
@export var item_bomb_full: int = 0
## 掉落散布范围（像素）。
@export var item_scatter: float = 50.0

# ── 构造链 ──

## 行为脚本（应为 CoroutineScript 子类；可序列化：.tres 可引用）。
@export var behavior_script: Script
## 行为脚本参数覆盖（可序列化；注入脚本同名 var）。
@export var params: Dictionary = {}
# 生成位置（运行时/逐实例，不入 .tres）
var _pos: Vector2 = Vector2.ZERO

## 设行为脚本（CoroutineScript 子类）。
func with_script(s: Script) -> EnemyData:   behavior_script = s; return self
## 设生成位置（运行时逐实例，不写入 .tres）。
func pos(p: Vector2) -> EnemyData:     _pos = p; return self
## 设最大生命。
func hp(v: int) -> EnemyData:          max_hp = v; return self
## 设判定半径（像素）。
func hbox(v: float) -> EnemyData:      hitbox_radius = v; return self
## 设击破分数。
func score(v: int) -> EnemyData:       score_value = v; return self
## 设掉落 P 道具数。
func power(v: int) -> EnemyData:       item_power = v; return self
## 设掉落点道具数。
func point(v: int) -> EnemyData:       item_point = v; return self
## 设掉落命碎片数。
func life(v: int) -> EnemyData:        item_life = v; return self
## 设掉落雷碎片数。
func bomb(v: int) -> EnemyData:        item_bomb = v; return self
## 设掉落整命数。
func life_full(v: int) -> EnemyData:   item_life_full = v; return self
## 设掉落整雷数。
func bomb_full(v: int) -> EnemyData:   item_bomb_full = v; return self
## 设掉落散布范围（像素）。
func scatter(v: float) -> EnemyData:   item_scatter = v; return self
## 设行为脚本参数覆盖；key 对不上脚本同名 var 时生成期严格报错。
func param(k: String, v) -> EnemyData: params[k] = v; return self
## 按 AssetRegistry.enemy_visuals 的 key 设外观；未知 key 回退红小妖精。
func visual(key: String) -> EnemyData:
	visual_scene = AssetRegistry.enemy_visuals.get(key, preload("res://data/enemy_visual/red_little_fairy.tscn"))
	return self

# ── 生成参数（供 StageRuntime 读取） ──

## 是否已配行为脚本。
func has_script() -> bool:            return behavior_script != null
## 取行为脚本（未配 = null）。
func get_enemy_script() -> Script:    return behavior_script
## 取生成位置。
func get_spawn_pos() -> Vector2:      return _pos
## 取行为参数覆盖字典。
func get_params() -> Dictionary:      return params
## 实例化行为脚本；未配 = null。
func make_script() -> CoroutineScript:
	if behavior_script:
		return behavior_script.new()
	return null

## 校验必填项：行为脚本 / max_hp > 0 / hitbox_radius > 0。
## 返回错误列表（空 = 通过）；脚本类型与参数键名在生成时由 StageRuntime + ParamValidator 再校验。
func validate() -> Array[String]:
	var errs: Array[String] = []
	if behavior_script == null:
		errs.append("EnemyData 未设置行为脚本（behavior_script），无法生成")
	if max_hp <= 0:
		errs.append("EnemyData.max_hp 必须 > 0（当前 %d）" % max_hp)
	if hitbox_radius <= 0.0:
		errs.append("EnemyData.hitbox_radius 必须 > 0（当前 %s）" % str(hitbox_radius))
	return errs

# ── 构造链模板 ──

## 红小妖精：HP 45、判定 25、掉落 P2。
func red_little_fairy() -> EnemyData:
	self.visual("red_little_fairy").hbox(25).hp(45).power(2)
	return self

## 蓝小妖精：HP 45、判定 25、掉落点2。
func blue_little_fairy() -> EnemyData:
	self.visual("blue_little_fairy").hbox(25).hp(45).point(2)
	return self

## 绿小妖精：HP 45、判定 25、掉落 P1 + 点1。
func green_little_fairy() -> EnemyData:
	self.visual("green_little_fairy").hbox(25).hp(45).power(1).point(1)
	return self

## 黄小妖精：HP 45、判定 25、掉落 P1 + 点1。
func yellow_little_fairy() -> EnemyData:
	self.visual("yellow_little_fairy").hbox(25).hp(45).power(1).point(1)
	return self

## 红中妖精：HP 200、判定 35、掉落 P7 + 点2。
func red_middle_fairy() -> EnemyData:
	self.visual("red_middle_fairy").hbox(35).hp(200).power(7).point(2)
	return self

## 蓝中妖精：HP 200、判定 35、掉落 P2 + 点7。
func blue_middle_fairy() -> EnemyData:
	self.visual("blue_middle_fairy").hbox(35).hp(200).power(2).point(7)
	return self

## 红大妖精：HP 420、判定 48、掉落 P12 + 点5。
func red_big_fairy() -> EnemyData:
	self.visual("red_big_fairy").hbox(48).hp(420).power(12).point(5)
	return self

## 蓝大妖精：HP 420、判定 48、掉落 P5 + 点12。
func blue_big_fairy() -> EnemyData:
	self.visual("blue_big_fairy").hbox(48).hp(420).power(5).point(12)
	return self

## 白巨大妖精：HP 840、判定 56、掉落 P20 + 点20。
func white_huge_fairy() -> EnemyData:
	self.visual("white_huge_fairy").hbox(56).hp(840).power(20).point(20)
	return self

## 红阴阳玉：HP 90、判定 40、掉落 P4。
func red_yin_yang_jade() -> EnemyData:
	self.visual("red_yin_yang_jade").hbox(40).hp(90).power(4)
	return self

## 绿阴阳玉：HP 90、判定 40、掉落 P2 + 点2。
func green_yin_yang_jade() -> EnemyData:
	self.visual("green_yin_yang_jade").hbox(40).hp(90).power(2).point(2)
	return self

## 蓝阴阳玉：HP 90、判定 40、掉落点4。
func blue_yin_yang_jade() -> EnemyData:
	self.visual("blue_yin_yang_jade").hbox(40).hp(90).point(4)
	return self

## 紫阴阳玉：HP 90、判定 40、掉落 P2 + 点2。
func purple_yin_yang_jade() -> EnemyData:
	self.visual("purple_yin_yang_jade").hbox(40).hp(90).power(2).point(2)
	return self

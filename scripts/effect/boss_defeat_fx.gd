extends HitEffect
class_name BossDefeatFx
## Boss **全破演出**（自足、可池化；一局只播一次，不在逐弹热路径）。
##
## 与 `PlayerBulletHitEffect`（单精灵参数化、零代码加特效）不同：全破要**多层不同节奏**
## （白闪 → 冲击波 → 三层爆点 → 整体淡出），所以用一个薄子类编排；
## 贴图 / 位置 / 缩放仍全部摆在 `scenes/effect/boss_defeat.tscn` 里（R21：结构声明在场景）。

## 白闪收掉 / 冲击波扩完 / 爆点停留 / 爆点淡出 / 整体存活上限（秒）
const FLASH_OUT := 0.18
const RING_OUT := 0.55
const BURST_HOLD := 0.40
const BURST_FADE := 0.70
const LIFE := 1.7

var _tint: Color = Color.WHITE

@onready var _flash: Sprite2D = $Flash
@onready var _ring: Sprite2D = $Ring


func _get_life_limit() -> float:
	return LIFE


func set_tint(color: Color) -> void:
	_tint = color


func _setup() -> void:
	# 池化复用：每次进来都要把上一次淡出的 alpha 复原，否则第二场全破是隐形的
	modulate = Color.WHITE

	# ① 白闪：中心光斑瞬间放大 + 快收（比命中特效亮一档）
	_flash.modulate = Color(_tint.r, _tint.g, _tint.b, 0.95)
	var tw_flash := create_tween()
	tw_flash.set_parallel(true)
	tw_flash.tween_property(_flash, "scale", Vector2(9.0, 9.0), FLASH_OUT * 2.0)
	tw_flash.tween_property(_flash, "modulate:a", 0.0, FLASH_OUT)

	# ② 冲击波：光斑从中心扩出去、同时渐隐（用光点而不是反色圈 —— 那是 miss 语义）
	_ring.modulate = Color(_tint.r, _tint.g, _tint.b, 0.8)
	var tw_ring := create_tween()
	tw_ring.set_parallel(true)
	tw_ring.tween_property(_ring, "scale", Vector2(20.0, 20.0), RING_OUT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_ring.tween_property(_ring, "modulate:a", 0.0, RING_OUT)

	# ③ 爆点：**自动收集场景里所有 AnimatedSprite2D**（加一片 = 场景里加个节点，不用改代码）
	for child in get_children():
		if child is AnimatedSprite2D:
			var burst: AnimatedSprite2D = child
			burst.modulate = Color(_tint.r, _tint.g, _tint.b, 0.9)
			var names := burst.sprite_frames.get_animation_names()
			if names.size() > 0:
				burst.play(names[0])
	# 停留后整体淡出（有层次但不拖泥带水）
	var tw_burst := create_tween()
	tw_burst.tween_interval(BURST_HOLD)
	tw_burst.tween_property(self, "modulate:a", 0.0, BURST_FADE)

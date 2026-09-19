# CharacterScreen.gd — 角色选择子页面
@tool
extends NavPage

@onready var _difficulty_badge: TextureRect = $DifficultyBadge

const FLY_DURATION: float = 0.5
## 难度页面中选项的大小
const DIFF_ITEM_SIZE: Vector2 = Vector2(256, 156)

## 难度贴图路径，按索引 [Easy, Normal, Hard, Lunatic]
const DIFF_TEX_PATHS: Array[String] = [
	"res://assets/Textures/title/rank_easy.png",
	"res://assets/Textures/title/rank_normal.png",
	"res://assets/Textures/title/rank_hard.png",
	"res://assets/Textures/title/rank_lunatic.png",
]


func on_enter() -> void:
	_setup_nav()
	if SaveData.selected_character < _nav_items.size():
		_nav_index = SaveData.selected_character

	# 遮罩淡入
	_fade_overlay_in(0.4)

	# 标题淡入
	var tex: TextureRect = $"TitleTexture"
	tex.modulate.a = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(tex, "modulate:a", 1.0, 0.5)

	# 难度贴图飞入
	var diff_idx := SaveData.selected_difficulty
	if diff_idx >= 0 and diff_idx < DIFF_TEX_PATHS.size():
		var diff_tex := load(DIFF_TEX_PATHS[diff_idx]) as Texture2D
		if diff_tex:
			_fly_to_badge(diff_tex)
			return

	_play_entrance()


## 从难度页面中央位置飞到 DifficultyBadge 节点
func _fly_to_badge(tex: Texture2D) -> void:
	_difficulty_badge.texture = tex

	# 起始位置：难度页面中央，scale 放大到选项大小
	_difficulty_badge.global_position = Vector2(640, 480)

	# 飞到目标位置，同时 scale 缩
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_difficulty_badge, "global_position", Vector2(640 - tex.get_size().x / 4, 800), FLY_DURATION)
	tw.tween_property(_difficulty_badge, "scale", Vector2.ONE / 2, FLY_DURATION)

	_play_entrance()


func on_leave() -> void:
	_is_nav_enabled = false
	_stop_pulse()
	queue_free()


func _on_item_selected(index: int) -> void:
	_is_nav_enabled = false
	_stop_pulse()
	finished.emit({"character": index})


func _on_cancel() -> void:
	_is_nav_enabled = false
	_stop_pulse()
	finished.emit({})

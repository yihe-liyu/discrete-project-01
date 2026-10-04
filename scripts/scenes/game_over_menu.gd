# GameOverMenu.gd — Game Over 覆盖层
@tool
extends NavPage

## 标题 Label 在场景里的声明路径。
## 本引擎**不解析节点类型 @export**（`.tscn` 里写的 `title_label = NodePath(...)` 会被丢弃），
## 故运行时按「路径 + 类型」兜底解析 —— 与 B3/BG6 的「场景声明 + 代码按类型/路径解析」同一风格。
const TITLE_LABEL_PATH: String = "Panel/TitleLabel"

@export var title_label: Label          ## 引擎不解析：留作编辑器声明 + 未来引擎修好后的兼容；运行时靠 _resolve_title_label()
@export var title_text: String = "Game Over"


func _ready() -> void:
	super._ready()
	_resolve_title_label()


## 节点类型 export 解析失败时，按 TITLE_LABEL_PATH 兜底（路径缺失 / 类型不符 → 保持 null）
func _resolve_title_label() -> void:
	if title_label == null:
		title_label = get_node_or_null(TITLE_LABEL_PATH) as Label


## 设置标题文字（唯一写入口；on_enter 与测试都走这里）
func set_title(text_value: String) -> void:
	title_text = text_value
	if title_label:
		title_label.text = title_text


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if title_label == null and get_node_or_null(TITLE_LABEL_PATH) == null:
		warnings.append("GameOverMenu：title_label 未设置（Game Over 标题不会更新）。")
	return warnings


func on_enter() -> void:
	super.on_enter()
	_fade_overlay_in(0.3)
	set_title(title_text)


func on_leave() -> void:
	_is_nav_enabled = false
	_stop_pulse()
	_overlay_leave(_container)


func _on_item_selected(index: int) -> void:
	match index:
		0:
			AudioManager.stop_bgm()
			SaveData.is_restarting = true
			GameManager.reload_current_scene()
		1:
			# 符卡练习里 Game Over → 回**练习菜单**（并还原到第三级），而不是主菜单根
			if PracticeSession.is_practice_mode:
				PracticeSession.restore_menu_on_enter = true
				GameManager.pending_page_path = "res://scenes/ui/spell_practice_menu.tscn"
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _on_cancel() -> void:
	_on_item_selected(1)

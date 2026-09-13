## 全局 UI 主题应用：把 themes/ui_theme.tres 的样式拷进 ThemeDB 默认主题（全局 Control 生效）。
## 从 SaveData 拆出——主题不是存档数据。
class_name UiTheme
extends RefCounted


static func apply() -> void:
	var ui: Theme = load("res://themes/ui_theme.tres")
	if not ui:
		return
	var def: Theme = ThemeDB.get_default_theme()
	for t in ui.get_type_list():
		for n in ui.get_constant_list(t):
			def.set_constant(n, t, ui.get_constant(n, t))
		for n in ui.get_color_list(t):
			def.set_color(n, t, ui.get_color(n, t))
		for n in ui.get_stylebox_list(t):
			def.set_stylebox(n, t, ui.get_stylebox(n, t))
		for n in ui.get_font_list(t):
			def.set_font(n, t, ui.get_font(n, t))
		for n in ui.get_font_size_list(t):
			def.set_font_size(n, t, ui.get_font_size(n, t))
		for n in ui.get_icon_list(t):
			def.set_icon(n, t, ui.get_icon(n, t))

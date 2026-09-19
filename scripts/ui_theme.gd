## 全局 UI 主题应用：把 themes/ui_theme.tres 的样式拷进 ThemeDB 默认主题（全局 Control 生效）。
## 从 SaveData 拆出——主题不是存档数据。
class_name UiTheme
extends RefCounted


static func apply() -> void:
	var ui: Theme = load("res://themes/ui_theme.tres")
	if not ui:
		return
	var def: Theme = ThemeDB.get_default_theme()
	for type_name in ui.get_type_list():
		for entry_name in ui.get_constant_list(type_name):
			def.set_constant(entry_name, type_name, ui.get_constant(entry_name, type_name))
		for entry_name in ui.get_color_list(type_name):
			def.set_color(entry_name, type_name, ui.get_color(entry_name, type_name))
		for entry_name in ui.get_stylebox_list(type_name):
			def.set_stylebox(entry_name, type_name, ui.get_stylebox(entry_name, type_name))
		for entry_name in ui.get_font_list(type_name):
			def.set_font(entry_name, type_name, ui.get_font(entry_name, type_name))
		for entry_name in ui.get_font_size_list(type_name):
			def.set_font_size(entry_name, type_name, ui.get_font_size(entry_name, type_name))
		for entry_name in ui.get_icon_list(type_name):
			def.set_icon(entry_name, type_name, ui.get_icon(entry_name, type_name))

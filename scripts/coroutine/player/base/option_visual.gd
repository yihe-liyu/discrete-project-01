## 子机视觉基类：setup / update_visual 空实现，子类按机体换贴图 / 动画。
extends Node
class_name OptionVisual

func setup(_option: Node2D) -> void:
	pass

func update_visual(_ctx: StageContext, _leader: Node2D) -> void:
	pass

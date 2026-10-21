## 子机视觉基类：setup / update_visual 空实现，子类按机体换贴图 / 动画。
extends Node
class_name OptionVisual

## 子类覆写：绑定子机节点。
func setup(_option: Node2D) -> void:
	pass

## 子类覆写：按 ctx / leader 更新视觉；基类空实现。
func update_visual(_ctx: StageContext, _leader: Node2D) -> void:
	pass

## 符卡背景**宿主层**（`game_scene.tscn` 里 `World` 下那个 Node2D）：
## 「什么时候显示 / 在哪一层 / 怎么淡」由它定；「长什么样」交给 `BossData.spell_background`
## 指向的**场景**（PackedScene）—— 作者在场景里随便放多少层、加 shader、加动画。
##
## 规则：**只在符卡期间**（`phase.uid != 0`）+ 配了场景才显示；非符 / 没配 / 阶段结束都淡出。
## **同一张场景不重播淡入、也不重建**（同 Boss 连打两张符卡不闪）；换场景才换实例。
##
## 坐标约定：宿主在**场地中心** ⇒ 作者场景里 `(0,0)` = 场地正中，
## 768×896 的整幅图放 `(0,0)`（`centered = true`）正好铺满场地。**不做任何裁剪**——
## 想让图只铺场地就照场地尺寸画；想铺满整屏也可以（那是作者的自由）。
class_name SpellBackdropLayer
extends Node2D

## 淡入 / 淡出时长（秒）
const FADE_SEC := 0.4

## 当前挂着的场景 + 其实例（实例是**本节点的子节点**，因此继承宿主的位置/层级/透明度）
var _scene: PackedScene
var _instance: Node
var _tween: Tween


## 该阶段该不该显示符卡背景：**符卡才有**（非符不显示）。
## 「用哪个场景」由调用方解析（当前 Boss 的 / 练习会话载荷的）——本层只管显隐规则。
static func should_show(phase: PhaseData) -> bool:
	return phase != null and phase.uid != 0


## 阶段 + 场景 → 显示 / 隐藏
func apply(phase: PhaseData, p_scene: PackedScene) -> void:
	if should_show(phase) and p_scene != null:
		show_for(p_scene)
	else:
		clear()


## 淡入一张符卡背景场景（同一张已挂着 → 只把透明度拉回来，不重建、不重播）
func show_for(p_scene: PackedScene) -> void:
	if p_scene == null:
		return
	_kill_tween()
	if _scene == p_scene and _instance != null and is_instance_valid(_instance):
		visible = true
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, FADE_SEC)
		return
	_free_instance()
	_scene = p_scene
	_instance = p_scene.instantiate()
	if _instance == null:
		return
	add_child(_instance)
	modulate.a = 0.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_SEC)


## 淡出并隐藏（实例在淡完之后才释放；中途再 `show_for` 同一张会**复用**同一个实例）
func clear() -> void:
	if not visible:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	_tween.tween_callback(_on_faded)


func _on_faded() -> void:
	visible = false
	_free_instance()


func _free_instance() -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	_scene = null


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _ready() -> void:
	# 场地中心：作者场景里的 (0,0) 就是场地正中
	position = Vector2(GameConfig.FIELD_CENTER_X, GameConfig.FIELD_CENTER_Y)
	z_index = LayerConfig.SPELL_BG
	visible = false
	modulate.a = 0.0

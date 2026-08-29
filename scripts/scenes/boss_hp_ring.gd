extends Node2D
## Boss 环形血条，跟随 Boss 位置。**订阅 hp_changed / phase_cleared —— 不轮询**（铁律5：UI 订阅，不拉状态）。
## hp 由 boss 的 _set_hp 统一改并广播；本环只画。

@export var radius: float = 128.0
@export var thickness: float = 5.0
@export var fill_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var edge_color: Color = Color(1.0, 0.0, 0.0, 1.0)

var _boss: Boss
var _max_hp: int = 1
var _hp: int = 1

func setup(p_boss: Boss) -> void:
	_boss = p_boss
	position = Vector2.ZERO
	z_index = LayerConfig.BOSS_HP_RING
	if not _boss.hp_changed.is_connected(_on_hp_changed):
		_boss.hp_changed.connect(_on_hp_changed)
	if not _boss.phase_cleared.is_connected(_on_phase_cleared):
		_boss.phase_cleared.connect(_on_phase_cleared)
	queue_redraw()

func _exit_tree() -> void:
	if _boss and is_instance_valid(_boss):
		if _boss.hp_changed.is_connected(_on_hp_changed):
			_boss.hp_changed.disconnect(_on_hp_changed)
		if _boss.phase_cleared.is_connected(_on_phase_cleared):
			_boss.phase_cleared.disconnect(_on_phase_cleared)

## hp 变了 → 更新并重画（涨血/扣血都由 boss._set_hp 广播）
func _on_hp_changed(new_hp: int, max_hp: int) -> void:
	_hp = new_hp
	_max_hp = max_hp
	queue_redraw()

## 阶段击破 → 阶段间隙隐藏；下次 start_phase 由 Boss 重新显示
func _on_phase_cleared(_captured: bool, _bonus: int) -> void:
	visible = false

func _draw() -> void:
	if _max_hp <= 0: return

	var ratio := clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	var start_angle := -PI / 2.0
	var end_angle := start_angle - TAU * ratio

	# 红色空心环 = 内外两圈细线
	var ring_half := thickness * 0.5 + 1.0
	draw_arc(Vector2.ZERO, radius + ring_half, 0, TAU, 64, edge_color, 2.0, true)
	draw_arc(Vector2.ZERO, radius - ring_half, 0, TAU, 64, edge_color, 2.0, true)

	# 白色 HP 填充
	draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 64, fill_color, thickness)

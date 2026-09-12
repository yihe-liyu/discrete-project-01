extends Node
## StageManager（W3b-1 薄门面，strangler）：把关卡生命周期/生成调用转发到当前 StageRuntime（World 下场景节点）。
## 保留注入槽与信号，调用点零改动；W3b-2 把调用点迁到 ctx.stage / 直接引用后删除本 autoload。
## 组合根（GameScene）与工作台在 _ready 调 bind_runtime() 并注入 world。

signal stage_started()
signal stage_cleared()
signal all_enemies_defeated()

## 注入槽（组合根 GameScene / 工作台设置；W3b-2 迁到 StageRuntime）
var miss_layer: MissEffectManager
var fx_layer: FxLayer
var current_background: StageBackground

var _runtime: StageRuntime


## 绑定当前场景的关卡运行时（组合根/工作台在 _ready 调用）；重复绑定会先断旧信号
func bind_runtime(rt: StageRuntime) -> void:
	if _runtime == rt:
		return
	_disconnect_runtime()
	_runtime = rt
	if is_instance_valid(_runtime):
		_runtime.stage_started.connect(_on_stage_started)
		_runtime.stage_cleared.connect(_on_stage_cleared)
		_runtime.all_enemies_defeated.connect(_on_all_enemies_defeated)


func unbind_runtime() -> void:
	_disconnect_runtime()
	_runtime = null


## 当前绑定的关卡运行时（未绑定 = null）；供组合根/测试读
func runtime() -> StageRuntime:
	return _runtime if is_instance_valid(_runtime) else null


func _disconnect_runtime() -> void:
	if not is_instance_valid(_runtime):
		return
	if _runtime.stage_started.is_connected(_on_stage_started):
		_runtime.stage_started.disconnect(_on_stage_started)
	if _runtime.stage_cleared.is_connected(_on_stage_cleared):
		_runtime.stage_cleared.disconnect(_on_stage_cleared)
	if _runtime.all_enemies_defeated.is_connected(_on_all_enemies_defeated):
		_runtime.all_enemies_defeated.disconnect(_on_all_enemies_defeated)


func _on_stage_started() -> void:
	stage_started.emit()


func _on_stage_cleared() -> void:
	stage_cleared.emit()


func _on_all_enemies_defeated() -> void:
	all_enemies_defeated.emit()


# ═══ 方法转发 ═══

func current_stage_script() -> CoroutineScript:
	return _runtime.current_stage_script() if is_instance_valid(_runtime) else null


func load_stage(data: StageData) -> void:
	if is_instance_valid(_runtime):
		_runtime.load_stage(data, current_background)


func stop_stage() -> void:
	if is_instance_valid(_runtime):
		_runtime.stop_stage()
	current_background = null


func spawn_enemy_data(data: EnemyData, p_ctx: StageContext = null) -> Enemy:
	return _runtime.spawn_enemy_data(data, p_ctx) if is_instance_valid(_runtime) else null


func spawn_enemy(data: EnemyData, position: Vector2, auto_start: bool = true) -> Enemy:
	return _runtime.spawn_enemy(data, position, auto_start) if is_instance_valid(_runtime) else null


func spawn_boss(data: BossData, position: Vector2, p_ctx: StageContext = null) -> Node:
	return _runtime.spawn_boss(data, position, p_ctx) if is_instance_valid(_runtime) else null


func spawn_bullet(data: BulletData, position: Vector2, direction: Vector2):
	return _runtime.spawn_bullet(data, position, direction) if is_instance_valid(_runtime) else null


func start_spell_card(p_phase: PhaseData, boss_scene: PackedScene, boss_name: String, position: Vector2) -> Boss:
	return _runtime.start_spell_card(p_phase, boss_scene, boss_name, position) if is_instance_valid(_runtime) else null

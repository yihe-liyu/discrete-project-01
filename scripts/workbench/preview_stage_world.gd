extends RefCounted
## 整关预览的舞台世界装配（D3：从 Workbench 拆出的第四块）。
##
## 建 BulletManager / 幽灵 Player / HitboxOverlay，并走 StageHost 的唯一接线。
## 只负责“建 + 接”，不管关卡协程/播放/UI；这些仍归 Workbench 与 StageRuntime。

const GHOST_SCRIPT := preload("res://scripts/workbench/ghost_player.gd")
const HITBOX_OVERLAY := preload("res://scripts/workbench/hitbox_overlay.gd")
const REIMU_DATA := preload("res://data/player_data/reimu_data.tres")

var _host: Node
var _world: Node2D
var _stage_runtime: StageRuntime
var _hitbox_layer: Node
var _bullet_manager: BulletManager
var _player: Player
var _hitbox_overlay: Node2D


func setup(host: Node, world: Node2D, runtime: StageRuntime, hitbox_layer: Node) -> void:
	_host = host
	_world = world
	_stage_runtime = runtime
	_hitbox_layer = hitbox_layer


func build() -> void:
	_stage_runtime.world = _world
	_bullet_manager = StageHost.make_bullet_world(_host)
	# Workbench 根是 PROCESS_MODE_ALWAYS；BulletManager 若 INHERIT 会在 tree.paused 时照跑。
	# 预览暂停（Playback → tree.paused）必须冻结弹幕，显式 PAUSABLE。
	_bullet_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	_player = StageHost.make_player(_world, GHOST_SCRIPT, "Player", REIMU_DATA)
	StageHost.wire(_stage_runtime, _bullet_manager, _player, _world)
	_hitbox_overlay = HITBOX_OVERLAY.new()
	_hitbox_overlay.name = "HitboxOverlay"
	_hitbox_overlay.z_index = LayerConfig.HITBOX_OVERLAY
	_hitbox_overlay.entity_registry = _stage_runtime.entity_registry
	_hitbox_overlay.bullet_manager = _bullet_manager
	_hitbox_layer.add_child(_hitbox_overlay)


func bullet_manager() -> BulletManager:
	return _bullet_manager


func player() -> Player:
	return _player


func hitbox_overlay() -> Node2D:
	return _hitbox_overlay


func set_hitbox_enabled(on: bool) -> void:
	if _hitbox_overlay != null:
		_hitbox_overlay.is_enabled = on

## 舞台世界装配（唯一实现）—— 真游戏 / 工作台整关预览 / 三个组合台原先各写一份同一段接线。
##
## 为什么值得抽（2026-09-30，S4）：三处的差别只在"节点从哪来、摆哪儿"，
## 而接线是逐字相同的一段，且每一句漏掉都是隐性 bug：
##   · 少 [code]fx_parent[/code]               → 炸弹爆炸贴图挂错层（旧写法是全树找 World，已删）
##   · 少 [code]inject_stage_runtime[/code]    → 子弹的共享 ctx 回退到全局（切场就串台）
##   · 少 [code]inject_entity_registry[/code]  → 内核后端看不到自机（自机狙全部打空）
##   · 少 [code]player_data[/code]             → [code]Player._ready[/code] 应用不到角色数据（数值全默认）
##
## 分工：节点来源由调用方决定 —— 真游戏按 R21 在 [code]game_scene.tscn[/code] 里声明，
## 工作台与组合台代码建。所以本类只给"建"与"接"两条最小入口：
##   建：[code]make_bullet_world()[/code] / [code]make_player()[/code]（真游戏不用，节点是场景声明的）
##   接：[code]wire_world()[/code] / [code]wire_player()[/code] / [code]wire()[/code]
##
## 放在 [code]scripts/stage/[/code]（核心层）而不是 [code]scripts/workbench/[/code]：真游戏也要用，
## 依赖方向只能是 工具 → 核心。
class_name StageHost
extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player.tscn")


# ═══ 建（代码搭舞台的宿主：工作台 + 三个组合台）═══

## 造弹幕世界并挂到 parent。
## top_level = true 给嵌入页面的宿主（组合台）：世界原点 = 画布原点，
## 不叠页签偏移，否则整场弹幕偏一个页签高度。
static func make_bullet_world(parent: Node, top_level: bool = false) -> BulletManager:
	var bullet_manager := BulletManager.new()
	bullet_manager.name = "BulletManager"
	bullet_manager.top_level = top_level
	parent.add_child(bullet_manager)
	return bullet_manager


## 造自机（[code]player.tscn[/code] + 指定脚本 + [code]PlayerData[/code]）并挂到 parent。
## [code]p_data[/code] 必须给：[code]Player._ready[/code] 会立刻应用角色数据。
## 摆位/走位模式由调用方随后设属性（预览 = 固定路径；组合台 = 鼠标跟随 + 位置 + z）。
static func make_player(parent: Node, p_script: Script, p_name: String, p_data: PlayerData) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.set_script(p_script)
	player.name = p_name
	player.player_data = p_data
	parent.add_child(player)
	return player


# ═══ 接 ═══

## 弹幕世界接上舞台：特效归属 + 运行时认领 + 共享子弹 ctx。
static func wire_world(runtime: StageRuntime, bullet_manager: BulletManager, fx_parent: Node2D) -> void:
	bullet_manager.fx_parent = fx_parent
	runtime.bullet_manager = bullet_manager
	bullet_manager.inject_stage_runtime(runtime)


## 自机接上舞台：显式认领自机引用（[code]_inject_player_ctx[/code] 只认它）+ 实体注册表 + 内核弹幕后端。
## 真游戏在选好机体之后才接（[code]setup_character()[/code] 先跑）——所以这两步与 [code]wire_world[/code] 分开。
static func wire_player(runtime: StageRuntime, player: Player) -> void:
	if not _registry_ready(runtime, "wire_player"):
		return          # 前置没满足就**什么都不做**（不许只绑自机、后端却没接）
	runtime.player = player
	runtime.entity_registry.bind_player(player)
	runtime.bullet_manager.inject_entity_registry(runtime.entity_registry)


## 只把实体注册表交给内核弹幕后端（不绑自机）。
## 给异常路径用：真游戏选机体失败 / 场景里没有 Player 时，注册表仍要交给后端。
## 也不要在调用点直接写 [code]bullet_manager.inject_entity_registry(...)[/code] —— 那正是 S4 要收掉的分叉，
## [code]tools/check_structure.sh[/code] 会检查这类调用只出现在本文件。
static func wire_registry(runtime: StageRuntime) -> void:
	if not _registry_ready(runtime, "wire_registry"):
		return
	runtime.bullet_manager.inject_entity_registry(runtime.entity_registry)


## 注入注册表的前置条件：子弹世界已接上。缺了就响亮报错并让调用方早退（不许绑一半）。
static func _registry_ready(runtime: StageRuntime, who: String) -> bool:
	if runtime.bullet_manager != null:
		return true
	push_error("StageHost.%s：子弹世界还没接上（先调 wire_world）" % who)
	return false


## 一次接完（工作台/组合台：节点刚建好、自机已就位，两步之间没有别的注入）
static func wire(runtime: StageRuntime, bullet_manager: BulletManager, player: Player, fx_parent: Node2D) -> void:
	wire_world(runtime, bullet_manager, fx_parent)
	wire_player(runtime, player)

extends GutTest
## 背景环境接线（`StageBackground` / `BackgroundEnvPreset`）。
##
## 背景：初始环境**唯一来源 = 预设 .tres**（`stage01_env.tres`；`stage01_decor.gd` 的头注释也是这么写的）。
## 但内容脚本 `stage01_decor.gd` 挂在 **`Decor` 子节点**上，而 Godot 里**子节点 `_ready` 先于父节点**
## ⇒ 它 `_ready()` 里那句 `apply_env_preset()` 执行时，父节点还没找到 `WorldEnvironment`，
## 旧实现 `if not world_environment: return` **静默返回** —— **练习模式**（只 `_load_background`、
## 不走 `load_stage` ⇒ 内容脚本的 `start()` 不跑）于是拿场景内联环境，**改预设它不变**。
## 2026-10-02 用哨兵值实测确认过（预设改 0.99 → 实例化后仍是 0.3），见 `BEST_PRACTICES_LOG`。

const BG_PRESET := preload("res://data/stages/stage01/background/stage01_env.tres")


## 回归：**父节点 `_ready` 之前**调用 `apply_env_preset()` 也必须生效（靠 `_env_node()` 懒查找）。
func test_apply_env_preset_works_before_parent_ready():
	var bg := StageBackground.new()
	var env_node := WorldEnvironment.new()
	# ⚠️ 故意**不** add_child(bg) 到树上：这样父节点 `_ready` 不会跑，
	#    正是内容脚本在自己 `_ready` 里调用那一刻的状态。
	bg.add_child(env_node)
	bg.apply_env_preset(BG_PRESET)
	assert_not_null(env_node.environment, "父节点未 `_ready` 时预设也必须生效（懒查找 WorldEnvironment）")
	if env_node.environment != null and BG_PRESET.environment != null:
		assert_almost_eq(env_node.environment.fog_density, BG_PRESET.environment.fog_density, 0.0001,
			"生效的环境应来自预设（fog_density 应与预设一致）")
	bg.free()


## 回归：`build_environment()` 每次都必须是**全新实例** —— 否则重跑/多背景共享同一 Environment，
## 上一轮 tween 改过的雾色残留 ⇒「越重跑越暗」。
func test_env_preset_builds_fresh_environment_each_time():
	var first := BG_PRESET.build_environment()
	var second := BG_PRESET.build_environment()
	assert_not_null(first, "预设应能构建环境")
	assert_not_null(second, "预设应能构建环境")
	assert_ne(first, second, "两次构建必须是两个独立实例（防重跑共享污染）")
	# 改一份不许影响另一份
	first.fog_density = 0.99
	assert_ne(second.fog_density, first.fog_density, "改一份不许串到另一份")

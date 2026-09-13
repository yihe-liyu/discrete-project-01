# Godot 最佳实践基线（BEST PRACTICES BASELINE）

> 本文件只记 **"项目当前状态"**，不记变更历史。
> - 改动 **状态** → 更新本文件对应那一行（✔/✘ 就地改，不追加）。
> - 记录 **心得/为什么这样改/学到什么** → 追加到 docs/BEST_PRACTICES_LOG.md。
> - ✔ = 已达标；✘ = 尚未达标（连同原因写入下方 🔴 TODO 小节，达标后那一行删除）。
> - 目标：本文件随项目成熟 **只收敛、不膨胀**；TODO 小节最终会整体清空。

---

## 1. 场景组织（scene_organization）

| ✔/✘ | 红线 | 当前落点 / 说明 |
|----|------|----------------|
| ✔ | 场景可独立运行，不依赖外部节点/autoload | StageContext 服务层做到了大部分；但 game_ui 仍绑在 game_scene.tscn（见 TODO） |
| ✔ | 依赖由父级/上下文向下注入，而非子节点反向抓取 | StageContext + ctx.bullets/player/audio |
| ✘ | 禁止 get_node("..") / current_scene.find_child() 全树搜索 | stage01_decor.gd:5-8、boss.gd:130、stage_background.gd:53 |
| ✘ | 有外部依赖时用 @tool + _get_configuration_warnings() 让编辑器自文档 | 全项目仅 2 处 @tool、_get_configuration_warnings 零实现 |
| ✔ | 父子关系按"关系树"而非"空间树"判断 | game_scene.tscn World/Player/ItemPool 层级合理 |
| ✘ | 可复用的子系统应拆成独立子场景 | GameUI、PhaseTimer、倒计时均可拆（见 TODO） |

## 2. 场景 vs 脚本（scenes_versus_scripts）

| ✔/✘ | 红线 | 当前落点 |
|----|------|---------|
| ✔ | 本游戏特有、复杂的东西用场景（而非纯脚本+命令式建树） | player/enemy/bullet/item.tscn |
| ✔ | 跨项目复用、给非程序员用的小工具用带 class_name 的脚本 | scripts/** 106 处 class_name |
| ✘ | 节点越大越复杂越该是场景 | boss.gd 于 stage_manager.spawn_boss 用 .new() 纯命令式构建（见 TODO） |

## 3. Autoload vs 普通节点（autoloads_versus_regular_nodes）

| ✔/✘ | 红线 | 当前落点 |
|----|------|---------|
| ✘ | autoload 是最后手段；全局状态/全局访问/全局资源分配是坏味道 | GameState 被 181 处引用、405 行上帝对象（见 TODO） |
| ✔ | 共享功能优先 class_name，共享数据优先 Resource，static var 替代部分单例 | 数据层 BulletData/EnemyData/PhaseData 全为 Resource |
| ✔ | 真需要 autoload 的系统应自管数据、不插手他人 | GameEvents / RNG / LayerConfig（可保留） |

## 4. 别什么都用 Node（node_alternatives）

| ✔/✘ | 红线 | 当前落点 |
|----|------|---------|
| ✔ | 能轻则轻：Object < RefCounted < Resource < Node | StageContext、服务、CoroutineRunner 大量用 RefCounted |
| ✘ | 上万颗子弹不应每个都是 Node2D | bullet.tscn 仍为 Node2D+子节点，虽已用 MultiMesh 但节点本身在（见 TODO） |

## 5. Godot 接口：鸭子类型与引用（godot_interfaces）

| ✔/✘ | 红线 | 当前落点 |
|----|------|---------|
| ✔ | 引用用 @export / %唯一名 / @onready 缓存，避免每帧 get_node(字符串) | 部分正确（%SubViewport、@onready） |
| ✘ | 禁止外部调用 _下划线私有方法 / has_method("_xxx") 反射 | player._apply_player_data()、boss._clear_phase()、creation_station（见 TODO） |
| ✔ | 用信号/分组/显式类型表达"接口"，而非鸭子检测 | BasePage.sfx_requested(kind) 是标准范式 |
| ✔ | 接口断开要明确（_exit_tree 显式 disconnect） | game_scene.gd:81-90 做对，应推广到所有 autoload 连接点 |

## 6. 通知与生命周期（godot_notifications）

| ✔/✘ | 红线 | 当前落点 |
|----|------|---------|
| ✔ | 周期性逻辑用 Timer；运动学用 _physics_process | CoroutineRunner 统一用 _physics_process |
| ✘ | 输入用 _input/_unhandled_input，不在 _process 轮询 Input.is_action_* | nav_page.gd:284-314 及 3 份复制（见 TODO） |
| ✔ | 属性赋值顺序初始值→_init→导出值；先设属性再 add_child | 数据/实体创建遵循 |

## 7. 数据结构（data_preferences）

| ✔/✘ | 红线 | 当前落点 |
|----|------|---------|
| ✔ | 批量迭代用 Array，按键存取用 Dictionary，复杂数据用 Resource/自定义 Object | 弹幕/数据层合理 |
| ✘ | 运行时存档走 user://，不写 res:// | SaveManager 用 user:// ✓，但符卡/音乐仍写 res://（见 TODO） |

## 8. 逻辑取舍（logic_preferences）

| ✔/✘ | 红线 | 当前落点 |
|----|------|---------|
| ✔ | 常量式导入用 preload；可能变化的用 @export/load（可置 null 释放） | 主体正确 |
| ✘ | 禁止 @export var x = preload(...)（导出值会覆盖） | enemy_data.gd:9（见 TODO） |
| ✔ | 大型内容拆小场景 + 按需加载 | stage_data/EnemyData 数据驱动 |

## 9. 项目组织 / 命名 / 版本控制（project_organization / version_control_systems）

| ✔/✘ | 红线 | 当前落点 |
|----|------|---------|
| ✘ | 文件/文件夹 snake_case（小写），节点 PascalCase | 77 个中文文件名、assets/Textures 等 3 个 PascalCase 目录、diffculty/带空格节点名（见 TODO） |
| ✔ | 第三方资源放 addons/ | GUT 在 addons/gut ✓ |
| ✘ | 大二进制资源用 Git LFS，否则仓库膨胀 | 40MB+ 二进制未配 LFS（见 TODO） |
| ✔ | .gitignore 忽略 .godot/、运行时存档 | 已忽略 .godot/，spell_records.tres 也应改走 user:// |
| ✔ | CI 每帧验证（语法+启动+GUT） | .github/workflows/verify.yml + tools/verify.sh |

---

## 🔴 TODO（达标后清空，逐条删）

- [ ] GameState 拆分为 PlayerState/RunState/RecordService/ThemeBootstrap (game_state.gd, 181 处引用)
- [ ] 符卡簿/音乐解锁存档从 res:// 改到 user:// (spell_book_manager.gd:29, asset_registry.gd:149, music_room_menu.gd:35,150)
- [ ] GameUI 抽成独立 game_hud.tscn，用信号订阅而非绑定 game_scene.tscn (game_ui.gd)
- [ ] 移除跨节点私有调用：player._apply_player_data() / boss._clear_phase() / creation_station 的 has_method("_xxx")
- [ ] _process 轮询输入改为 _unhandled_input（nav_page.gd 及 3 份复制）
- [ ] 移除 get_node("..")/find_child 全树搜索（stage01_decor.gd、boss.gd:130、stage_background.gd:53）
- [ ] 铺设 @tool + _get_configuration_warnings() 自文档
- [ ] 修 @export var x = preload(...) (enemy_data.gd:9)
- [ ] 节点/文件命名规范化（snake_case + PascalCase，修 diffculty）
- [ ] 配 Git LFS（40MB+ 二进制）
- [ ] workbench.gd/spell_practice_menu.gd 上帝对象拆分、DRY 去重（见 BEST_PRACTICES_LOG.md 与 REFACTORING_PLAN.md）

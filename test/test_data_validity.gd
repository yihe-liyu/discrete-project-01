extends GutTest
## 数据完整性测试 —— 关卡/Boss/符卡数据的合法性与一致性。
##
## ⚠️ 本文件**故意**绑真实内容（内容校验类）：它验的就是「仓库里这批数据合法」。
## 但**不写死具体路径/文件名** —— 遍历目录扫到的全部内容，改名 / 增删 / 重排都不该让它红，
## **数据违规才该红**。
##
## 反过来说：机制测试请**自建夹具**、别绑内容（见 test_phase_rig / test_workbench_align /
## test_boss_phase）。判据一句话：**测试对内容的依赖，应等于它要验证的内容属性。**

const CAT := preload("res://scripts/data/content_catalog.gd")


## 舞台注册表包含 Stage 1
func test_stage_registry_has_stage1():
	var reg: StageRegistry = load("res://data/registry/stage_registry.tres")
	assert_not_null(reg, "stage_registry.tres 应存在")
	if reg:
		var stages: Array = reg.stages
		assert_gt(stages.size(), 0, "注册表不应为空")
		var has_stage1 := false
		for s in stages:
			if s is StageData and s.stage_id == 1:
				has_stage1 = true
				assert_not_null(s.create_script, "Stage1 需要关卡脚本")
				assert_not_null(s.background_scene, "Stage1 需要背景")
		assert_true(has_stage1, "注册表应包含 Stage 1")


## 全部阶段数据（不数数量、不写死路径）：
## - `hp > 0` / `time_limit > 0`（注意 time_limit 可能走默认值，故不能只查 .tres 文本）
## - 双脚本槽都在（move + shoot）
## - 非符 ⟺ `uid == 0`；真符卡必须有名字，且 **uid 全局唯一**
func test_all_phase_data_valid():
	var phases = CAT.new().scan().by_role("phase")
	assert_gt(phases.size(), 0, "应扫到阶段数据")
	var owner_by_uid := {}
	for e in phases:
		var phase: PhaseData = load(e.path)
		assert_not_null(phase, "%s 应可加载" % e.path)
		if phase == null:
			continue
		assert_gt(phase.hp, 0, "%s hp 应 > 0" % e.path)
		assert_gt(phase.time_limit, 0.0, "%s 时限应 > 0" % e.path)
		assert_not_null(phase.move_script, "%s 需要移动脚本" % e.path)
		assert_not_null(phase.shoot_script, "%s 需要弹幕脚本" % e.path)
		if phase.uid == 0:
			continue   # 非符：不进符卡册，uid 不参与唯一性
		assert_ne(phase.name, "", "%s 真符卡应有名字" % e.path)
		assert_false(owner_by_uid.has(phase.uid),
			"符卡 uid 必须全局唯一：%s 与 %s 都用了 %d" % [e.path, owner_by_uid.get(phase.uid, ""), phase.uid])
		owner_by_uid[phase.uid] = e.path


## 角色数据：灵梦/魔理沙都有射击脚本
func test_player_data_valid():
	for path in ["res://data/player_data/reimu_data.tres", "res://data/player_data/marisa_data.tres"]:
		var pd: PlayerData = load(path)
		assert_not_null(pd, "%s 应存在" % path)
		if pd:
			assert_not_null(pd.shoot_script, "%s 需要射击脚本" % path)
			assert_gt(pd.normal_speed, 0, "%s 常速应 > 0" % path)
			assert_gt(pd.focus_speed, 0, "%s 低速应 > 0" % path)


## 舞台显示名：**id 是记录主键、名字是给人看的** —— 两者解耦。
## 只锁「配了名 → 解析得到，且不等于回落值」；**不锁叫什么**（名字是作者随时会改的内容）。
func test_stage_4_has_display_name():
	var shown := StageCatalog.display_name_of(4)
	assert_ne(shown, "Stage 4", "3B 应配了 display_name（否则会回落成 Stage 4）")
	assert_ne(shown, "", "显示名不应为空")


## 符卡背景（每 Boss 一张）：**若配了**，必须真能加载出图（宽 > 0）。
## 不数数量、不写死路径 —— 改名/新增 Boss 不红，配了个坏引用才红。
func test_boss_spell_backgrounds_resolve():
	var configured := 0
	for stage in BossCatalog.all():
		for boss: BossData in BossCatalog.all()[stage]:
			if boss.spell_background == null:
				continue
			configured += 1
			assert_gt(boss.spell_background.get_width(), 0,
				"%s 的符卡背景应能加载出图" % boss.boss_name)
	assert_gt(configured, 0, "至少应有一个 Boss 配了符卡背景")


## 弹型数据（真实数据源 = data/bullets/*.tres）：玩家主弹/子机贴图引用与判定盒有效
func test_player_bullet_types_valid():
	for key in ["reimu_main", "reimu_opt1", "reimu_opt2", "marisa_main", "marisa_opt2"]:
		var bt: BulletDef = BulletCatalog.find(key)
		assert_not_null(bt, "%s 应有弹型资源" % key)
		if bt == null:
			continue
		assert_true(bt.texture_key != &"", "%s 应有贴图引用" % key)
		assert_true(BulletShapes.BULLET_ATLAS.has_shape(bt.texture_key), "%s 的 texture_key 应在图集中" % key)
		assert_true(bt.hitbox_radius > 0.0 or bt.hitbox_size != Vector2.ZERO, "%s 应有判定" % key)


## 关卡 BGM key：**填了就必须能解析**（防止改名/删曲后练习模式静默没声）
func test_stage_bgm_keys_resolve():
	var checked := 0
	for stage_data in StageCatalog.all():
		if stage_data.bgm_key == "":
			continue
		checked += 1
		assert_not_null(AssetRegistry.get_bgm(stage_data.bgm_key),
			"%s 的 bgm_key '%s' 应能解析" % [stage_data.display_name, stage_data.bgm_key])
	# 3B 不在注册表（无关卡脚本），靠目录扫描 —— 单独确认它也能查到
	var b3: StageData = StageCatalog.find(4)
	assert_not_null(b3, "stage 4（3B）应能从目录扫描查到")
	if b3:
		assert_eq(b3.bgm_key, "stage3B", "3B 的 BGM key")
	assert_gt(checked, 0, "至少应有一个关卡配了 bgm_key")

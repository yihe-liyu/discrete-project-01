extends GutTest
## 音效均衡表（`AssetRegistry.SFX_DB`）：只锁**不变量**，不锁具体 dB
## （数值是作者会调的混音决定；锁死了每次调音量都要改测试）。


## 每个音效都要有基准音量 —— 漏一个就退回"完全由 wav 自身电平决定"的老问题
func test_every_sound_has_base_db():
	for key in AssetRegistry.sounds:
		assert_true(AssetRegistry.SFX_DB.has(key), "音效 %s 应在 SFX_DB 里有基准音量" % key)


## 表必须**中心化**（均值≈0）：调用点原有的 -12.0 才是总电平，表只表达相对关系
func test_table_is_centered():
	assert_gt(AssetRegistry.SFX_DB.size(), 0, "表不应为空")
	var total := 0.0
	for key in AssetRegistry.SFX_DB:
		total += AssetRegistry.SFX_DB[key]
	var mean: float = total / float(AssetRegistry.SFX_DB.size())
	assert_almost_eq(mean, 0.0, 0.5, "整表均值应≈0（中心化，否则总音量会被表整体推高/压低）")


## 基准音量不该离谱（±12 dB 以内 —— 超出说明某个音源电平异常，该去查源文件）
func test_base_db_within_sane_range():
	for key in AssetRegistry.SFX_DB:
		assert_between(AssetRegistry.SFX_DB[key], -12.0, 12.0, "%s 的基准音量应 ±12dB 内" % key)

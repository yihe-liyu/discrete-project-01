extends GutTest
## W3a：AssetRegistry 去 autoload（→ `class_name` 静态表）。验证静态访问仍可用。

func test_no_longer_autoload() -> void:
	assert_false(ProjectSettings.has_setting("autoload/AssetRegistry"),
		"AssetRegistry 应已从 autoload 移除（改为 class_name 静态表）")

func test_static_tables_accessible() -> void:
	assert_gt(AssetRegistry.sounds.size(), 0, "sounds 静态表应可访问")
	assert_gt(AssetRegistry.bullet_configs.size(), 0, "bullet_configs 静态表应可访问")
	assert_not_null(AssetRegistry.get_bullet_tex("小玉"), "get_bullet_tex 静态方法应可访问")
	assert_eq(AssetRegistry.get_bgm_title(null), "", "null 流返回空标题（静态方法可用，无副作用）")

extends GutTest
## AssetRegistry 去 autoload（→ `class_name` 静态表）。验证静态访问仍可用。

func test_no_longer_autoload() -> void:
	assert_false(ProjectSettings.has_setting("autoload/AssetRegistry"),
		"AssetRegistry 应已从 autoload 移除（改为 class_name 静态表）")

func test_static_tables_accessible() -> void:
	assert_gt(AssetRegistry.sounds.size(), 0, "sounds 静态表应可访问")
	assert_gt(BulletCatalog.keys().size(), 0, "BulletCatalog 应能从 data/bullets/*.tres 建表")
	assert_not_null(BulletCatalog.find("小玉"), "小玉 弹型应可查")
	assert_not_null(AssetRegistry.LASER_TEXTURE, "LASER_TEXTURE 静态常量应可访问")
	assert_eq(AssetRegistry.get_bgm_title(null), "", "null 流返回空标题（静态方法可用，无副作用）")

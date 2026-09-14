extends GutTest
## 守卫：扩展**已构建**时必须真的注册成功。
## 起因（2026-09-14）：C++ 大段替换误删函数定义 → .so 含未定义符号 → 加载失败；
## 而所有原生测试只会 pending（"无扩展"），门禁全绿也发现不了。这条让**加载失败**变红。


func test_extension_registers_if_built() -> void:
	var ext := "res://gdextension/danmaku_kernel.gdextension"
	if not FileAccess.file_exists(ext):
		pending("未构建扩展（fresh clone / 未跑 build_gdextension.sh）")
		return
	assert_true(ClassDB.class_exists("DanmakuStore"), "扩展已构建但 DanmakuStore 未注册 —— 加载失败（未定义符号？看启动日志）")
	assert_true(ClassDB.class_exists("DanmakuRenderBridge"), "扩展已构建但 DanmakuRenderBridge 未注册")


func test_extension_api_surface() -> void:
	var ext := "res://gdextension/danmaku_kernel.gdextension"
	if not FileAccess.file_exists(ext):
		pending("未构建扩展")
		return
	var store = ClassDB.instantiate("DanmakuStore")
	for m in ["spawn", "despawn", "integrate", "query_circle", "hit_test", "behavior_tick", "behavior_batch", "register_program", "set_program"]:
		assert_true(store.has_method(m), "原生 API 缺方法：%s" % m)

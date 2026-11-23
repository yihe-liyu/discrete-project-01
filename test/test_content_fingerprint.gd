extends GutTest
## 内容指纹：同一内容稳定，长度固定；Replay 用它拒绝内容变更后的旧录像。

func test_content_fingerprint_is_stable() -> void:
	var a := ContentFingerprint.compute()
	var b := ContentFingerprint.compute()
	assert_ne(a, "")
	assert_eq(a.length(), 64, "SHA-256 hex 应为 64 字符")
	assert_eq(a, b, "同一内容两次扫描必须一致")

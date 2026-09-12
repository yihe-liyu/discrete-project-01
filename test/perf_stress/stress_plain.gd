extends Node
## 基线测试：1500 颗无协程直线弹（纯 Bullet._physics_process）
func _ready():
	# W4c：无 autoload，场景自建弹幕世界
	if BulletManager.current == null:
		var bm := BulletManager.new()
		bm.name = "BulletManager"
		add_child(bm)
	var data: BulletData = BulletData.new().enemy().tex("小玉").speed(20.0).blend(true)
	# 不设 coroutine_script → 直线弹路径
	for i in 1500:
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 1500.0)
		BulletManager.current.shoot_enemy_bullet(data, Vector2(448, 480), dir)
	print("[stress] 已生成 1500 颗无协程直线弹")

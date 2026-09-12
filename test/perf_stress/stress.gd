extends Node
## 协程压力测试：1500 颗带协程的慢速弹丸，测 BulletManager 物理耗时
## 运行：godot --headless --path . res://test/perf_stress/stress.tscn --quit-after 900
const SLOW = preload("res://test/perf_stress/slow_move.gd")

func _ready():
	# W4c：无 autoload，场景自建弹幕世界
	if BulletManager.current == null:
		var bm := BulletManager.new()
		bm.name = "BulletManager"
		add_child(bm)
	var data: BulletData = BulletData.new().enemy().tex("小玉").speed(20.0).blend(true)
	data.coroutine_script = SLOW
	for i in 1500:
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 1500.0)
		BulletManager.current.shoot_enemy_bullet(data, Vector2(448, 480), dir)
	print("[stress] 已生成 1500 颗慢速协程弹")

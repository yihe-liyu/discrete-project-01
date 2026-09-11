extends CoroutineScript

const META := {
	"name": "卡摩瑞道中一非移动",
	"desc": "正弦波左右飘移"
}

var _center: float = 448.0     # 中心 x
var _amplitude: float = 200.0  # 振幅（左右各 200px）
var _period: float = 6.0       # 一个来回的周期（秒）
var _timer: float = 0.0


func _tick(_ctx: StageContext):
	if not target: return true
	
	_timer += get_dt()
	
	# sin: 两端导数最小（慢），中心导数最大（快）= 自然加减速
	target.global_position.x = _center + sin(_timer * TAU / _period) * _amplitude
	
	return true  # 每帧都跑

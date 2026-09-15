extends RefCounted
## 行为钩子注册表（b2b）：名字 → Callable。
## 名字是**唯一键** —— 同名不同义在注册时暴露；因此 program 可只按「结构 + 名字」去重（不含 Callable 身份）。
## 生命周期：内容/宿主显式注册；测试/换场用 clear() 复位。

static var _hooks: Dictionary = {}


static func register(name: StringName, fn: Callable) -> void:
	_hooks[name] = fn


static func resolve(name: StringName) -> Callable:
	return _hooks.get(name, Callable())


static func clear() -> void:
	_hooks.clear()

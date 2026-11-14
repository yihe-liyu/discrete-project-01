## 内容侧的统一发射描述（过渡版）。
## 当前继承 BulletData，先统一“作者只看见 SpawnSpec”的入口；
## 后续再把 BulletData 的字段逐步抽成独立 DTO。
class_name SpawnSpec
extends BulletData

## 可选的一层子弹出描述；不指回 parent，避免模板成环。
var child: SpawnSpec

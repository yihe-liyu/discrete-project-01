# 难度路线（StageRoute）

## 定位

难度链不是五份复制的关卡资源，而是五条**引用同一批 StageData 的路线**。

```text
Route       本局走哪些 StageData、什么顺序
StageData   关卡身份 / 脚本 / 背景 / BGM
diff_pick   同一关内部的难度强度
phase_uid   符卡记录身份
```

## 数据

```gdscript
class_name StageRoute
extends Resource

@export var route_id: StringName
@export var difficulty: int
@export var stages: Array[StageData]
```

路线放在 `data/routes/*.tres`，由 `StageRouteCatalog` 扫描。

同一份 StageData 可以被多条路线引用，不复制资源。

## 运行态

```text
SaveData.current_route_id
SaveData.current_route_index
SaveData.current_stage_id   ← route 当前位置的派生结果
```

推进：

```gdscript
var next_stage := SaveData.advance_route()
```

路线末尾返回 null，不修改当前 stage。

## 记录

符卡 / 高分主键不使用 route：

```text
stage_id
phase_uid
character
difficulty
```

所以调整路线顺序不会丢记录，也不会拆出第二份记录。

## 菜单

- 关卡练习：`StageRouteCatalog.ordered_stages()`，路线成员优先；迁移期未入路线的可玩面追加在末尾。
- 符卡练习：仍走内容目录，不按 route 过滤。

## 冒烟

```text
tools/route_smoke.gd
```

校验每条路线的 StageData / 脚本 / 背景 / BGM 是否可用。

## 不做

```text
为每条路线复制 StageData
用 route_index 当符卡记录主键
用 route 表达弹速 / 密度
```

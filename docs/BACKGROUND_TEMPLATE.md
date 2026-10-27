# 背景模板（BackgroundBase）

`scenes/background/background_base.tscn` 是新建 3D 背景的最小起点。

## 包含

```text
BackgroundBase (StageBackground)
├─ WorldEnvironment
└─ DecorManager
```

不包含：

```text
Camera3D     由 StageBackground._ready() 自建（随背景实例销毁）
Ground       每张背景自己的地面 / 贴图
Sun / Fog    只在需要时声明
```

## 新建背景

1. 新建场景，根节点**继承** `background_base.tscn`。
2. 改根节点的 `env_preset`。
3. 需要地面时加 `BackgroundPlane` 子节点。
4. 需要太阳 / 雾时分别加 `BackgroundSun` / `ScreenFogFX`；它们声明即显示，宿主会自动接线。
5. 把新场景挂到 `StageData.background_scene`。

## 边界

- 不要把模板复制成多份再手接 `DecorManager`；继承即可。
- 模板不提供相机：`StageBackground` 按类型解析外部相机，没有就自建。
- `WorldEnvironment` 是环境动词的落点；没有它，`tween_env_fog` 会静默无效。
- `DecorManager` 是 `ctx.decor` 的来源；没有它，装饰物 API 为 null。

## 当前示例

`data/stages/stage03B/background/stage03b_background.tscn` 继承本模板，只额外添加：

```text
Ground (BackgroundPlane)
Decor  (CoroutineScript，当前为空)
```

并挂到 `StageData.background_scene`。

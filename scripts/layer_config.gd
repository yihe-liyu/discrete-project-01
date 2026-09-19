## 渲染图层常量（R17：不散落魔术数字）——静态常量类，不再是 autoload。
## 用法不变：`LayerConfig.PLAYER_BULLET`。
class_name LayerConfig


# ── 游戏物件 ──
const PLAYER_BULLET := -10  ## 自机子弹
const ITEM          := -5   ## 道具
const PLAYER        := 0    ## 自机
const OPTION        := 6    ## 子机（Option）
const ENEMY         := 5    ## 敌人
const ENEMY_BULLET  := 10   ## 敌弹
const BOSS          := 15   ## Boss
const BOSS_HP_RING  := 20   ## Boss 血量环
const EFFECT        := 50   ## 击中/消弹等特效（弹幕之上）
const SCORE_POPUP   := 55   ## 吃道具得分浮字（特效之上）
const BOMB          := 100  ## 炸弹特效

# ── UI（CanvasLayer layer=32，内部 z 用 UI_* 相对排序）──
const GAME_UI   := 1000   ## UI 容器根（语义层）
const UI_TOP    := 128    ## UI 内部置顶（血条数字/提示等）
const OVERLAY   := 2000   ## 菜单/暂停遮罩
const DEBUG     := 9999

# ── UI 内部相对排序（与游戏物件层不同坐标系；只保证 UI 内相对大小）──
const UI_NORMAL  := 0    ## UI 默认
const UI_SPEAKER := 10   ## 对话讲话者立绘置顶
const UI_TOAST   := 200  ## 浮动状态条（盖住 UI 内容）

# ── 工作台 / 调试 ──
const GHOST_PLAYER   := 30  ## 工作台幽灵自机
const HITBOX_OVERLAY := 60  ## 命中框覆盖层（> 敌弹 10 / 特效 50）

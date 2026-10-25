## 全局游戏常量 —— 场地边界与屏幕尺寸（东方框）
class_name GameConfig
extends RefCounted
##
## 东方传统 4:3 弹幕框：
##   左 64  右 832  上 32  下 928（宽 768 × 高 896）
##   中心 x = 448（对应 laser_demo 注释「左64 右832 上32 下928」）

## 场地（弹幕活动区）边界
const FIELD_LEFT: float = 64.0
const FIELD_RIGHT: float = 832.0
const FIELD_TOP: float = 32.0
const FIELD_BOTTOM: float = 928.0
const FIELD_CENTER_X: float = 448.0
const FIELD_CENTER_Y: float = 480.0

## 自机中心的活动边界（Player clamp 与创作台 ghost 共用，保证“可存在范围”一致）
## 真游戏 Player：x 各内缩 24，y 各内缩 32
const PLAYER_MIN_X: float = 88.0
const PLAYER_MAX_X: float = 808.0
const PLAYER_MIN_Y: float = 64.0
const PLAYER_MAX_Y: float = 896.0
## 真游戏 Player 初始点（game_scene.tscn: position = (448, 840)）
const PLAYER_START: Vector2 = Vector2(448.0, 840.0)

## 屏幕（viewport）尺寸
const VIEW_WIDTH: float = 1280.0
const VIEW_HEIGHT: float = 960.0

## 背景容器相对场地每边外扩多少（over-scan）：震屏时边缘不露底。
## 真游戏（[code]game_scene.tscn[/code]）按这个规格铺背景
## ⇒ 两边容器同为 800×928、相机/fov 相同 ⇒ 预览与真游戏同构图。
## [code]game_scene.tscn[/code] 里是字面量偏移（48/16/848/944），改本常量要同步那边（tscn 引不到常量）。
const BACKGROUND_OVERSCAN: float = 16.0

## 屏幕中心
const SCREEN_CENTER := Vector2(VIEW_WIDTH / 2.0, VIEW_HEIGHT / 2.0)

## ── 流程时序 ──

## 中弹 → 弹出 Game Over 菜单的等待（秒）：留出死亡演出/复活动画的时间。
## 这段窗口内若已被击破 / 通关结算过，[code]GameScene._ending[/code] 闸门会放弃这次弹窗
## （否则 Game Over 会叠在已经切过去的场景上）。
const DEATH_MENU_DELAY: float = 1.5

# Godot 最佳实践日志（BEST PRACTICES LOG）

> 本文件是**滚动日志**：记录"为什么这样改 / 当时学到什么 / 踩过的坑"。
> - **反复踩的坑 / 铁律** → 蒸馏进 `BEST_PRACTICES_BASELINE.md`（改动前必读）。
> - **正文只留最近 2 天**（且不少于 12 条）→ 更早的按**月**归档到 `docs/archive/LOG_<YYYY-MM>.md`
>   （**不删任何东西**；归档内文**时间正序**，越往下越新）。
> - **顶部索引**由工具生成，列**全部**条目（新→旧）：留在正文的直接往下读，归档的给文件链接。
> - 找旧事：先扫索引，或 `grep -n "关键词" docs/BEST_PRACTICES_LOG.md docs/archive/*.md`
>
> 维护：`python3 tools/log_archive.py --check`（体检格式/体积）· `--dry-run`（看会搬走什么）·
> `--index`（只重建索引）· `--archive [--days=7 --keep-min=20]`（归档 + 重建索引）。

---

## 模板（每条可复制）

### YYYY-MM-DD — 子系统名 / 改动名
- **目标**：一句话说明要改什么。
- **为什么**：为什么这样改才算符合最佳实践（对应哪篇文档哪一条）。
- **对照旧项目**：旧版 file.gd:line 哪里不好，我这次刻意没抄什么。
- **新落点**：新文件:行号。
- **验收**：./tools/verify.sh / 对应 GUT 测试结果。

---


## 索引

> 共 102 条（本文件留最近 12 条，其余在 `docs/archive/`；本段由 `tools/log_archive.py` 生成，手改会被覆盖）。

- 2026-10-10 — 音量管理补骨架：**真总线 + SE 密度护栏 + BGM 让位/交叉淡入**
- 2026-10-10 — 补齐 10 个缺失弹型：**重建版的弹型资源在 git 里没丢**
- 2026-10-04 — 清场要看得见：敌人**击破特效** + 弹幕**消弹特效**
- 2026-10-04 — 补「即时清弹」内容动词：`ctx.bullets.clear_enemy_bullets()`
- 2026-10-04 — 敌人回收**动词化**：`ctx.enemies.despawn` / `despawn_all`
- 2026-10-04 — Miss 的雷：从「+2 补偿」改为「−2、下限 3」
- 2026-10-04 — 关卡练习：第 2 面起**满火力**起步
- 2026-10-04 — 修「关卡练习菜单的黑幕没有了」（我的回归）+ 扫同款
- 2026-10-04 — 相机动词改名 + 目标记忆（作者实测「摄像机的 y 角度最后没回到 0」）
- 2026-10-04 — 相机初始姿态改由**背景自己声明**（`override_camera_home`）
- 2026-10-04 — 修「一改太阳 y，黑雾的太阳对准就不准」（投影的是节点，画的是 sprite）
- 2026-10-04 — 废止「记得调用才显示」：背景演出层改**宿主自动接线**（练习模式也开黑雾）
- 2026-10-04 — 太阳也提成节点 + 纹理改 `ImageTexture`（编辑器里终于看得见）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-04 — 蒙眼雾「提成节点」+ 去掉组件里的 `get_parent()`  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-04 — 修 BGA 自身引入的回归：「树和地面的速度不一样了」  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-04 — BGA 第一批：背景接口收口（`ctx.background` / 环境声明化 / 缺件响亮）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-04 — 背景创作工具收口：工作台可切关卡 + 抓图工具认任意面（BGT1–BGT3）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-04 — stage02 背景树纠正 + 背景形状机械守卫（抄背景别抄漏一层）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-04 — 关卡入口收口：注册表只收可玩的 + 关卡练习菜单实装  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-04 — BG 线冻结：整条背景视觉线不再投入（保留现役 3D 背景）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-04 — 卡摩瑞道中一非：开花相位改为每次重抽  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — 修 Game Over 标题静默 no-op：节点类型 @export 在本引擎不解析  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — P1 收口：字符串接口 / 隐藏契约（B1–B6）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — N8 收尾：workbench 单字母清零  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — BG12-fix 落地：三个宿主的背景视口各自持有 World3D  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — BG12 确认：背景 SubViewport 与根视口**共享** World3D（"第二个 WorldEnvironment 被忽略"风险**成立**）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — BG10 拍板：**留 3D 视口**（真机实测背景只花 1.03 ms）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — BG9 文档治理：清单不再"自己变陈"（两条硬规矩 + 机器兜底）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — BG6 接缝化：删 4 组 0 调用点死 API + 相机改**按类型**找  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — 雾色定案：`Color.DARK_GRAY` 是 CSS **亮灰**，一直在把远处"洗亮"  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — 回退「残雾」：我把"加厚"当成了"远处渐淡"（**验收漏看全局量**）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — 作者要"远处渐淡进雾色"：**DEPTH 实测更差**、`fog_density` 是**弱旋钮** ⇒ 落"残雾"  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — 作者报"背景远方出问题"：是 `fog_sky_affect = 0` 的硬边（**BG2 的回归**），不是 BG4 的活  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — BG2+BG3：真配天球（用作者自己的参数）+ 顺手挖出 `radiance_size` 的 5 倍坑  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — BG1 落地：环境**唯一来源 = 预设**（堵掉「练习模式静默用旧环境」）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — BG7 落地：工作台背景纳入真游戏规格 + 画框拆成独立层（预览与真游戏同构图）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — BG7 复核：「工作台/真游戏背景规格不同」**不是笔误，是有意的两种做法**  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — 暂停时停掉背景渲染（BG5 ③）：省 8.7 ms/帧，代价是"雾冻住"（作者要的）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — 背景视口减半分辨率（`stretch_shrink = 2`）：两个宿主各一行，省 ≈40% 背景 GPU  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — 重建背景「截图 + 渲染耗时」工具（先恢复可测量性，再调画面）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — GUT **全绿**了：补完最后 22 个 move_script（复用 `random_dir_move`）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — 「不动的符卡」怎么填 move 槽：`stay_still.gd`（空槽 ≠ 不动）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — 补 15 个缺失的 `shoot_script` 架子（只写架子 + 接线，不写弹幕内容）  ·  [归档](archive/LOG_2026-10.md)
- 2026-10-02 — 目录显示名：「角色标签」只在敌人脚本里砍，且前缀要「标签形状」  ·  [归档](archive/LOG_2026-10.md)
- 2026-09-30 — 给两条敌人脚本补「顶部注释块」：目录警告清零  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-30 — 创作台 ④ 收尾：孤儿脚本按作者判断处理 + `@role` 补空缺不再报"冲突"  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-30 — 阶段列表按 uid 排序（符卡优先 / 非符路径定序）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-30 — 创作台 ③：参数面板键名**从中间断词**（`move_speed` → `move_spee` / `d`）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-30 — 修创作台目录两处「说不清话」：显示名把成员注释当脚本名 / `pre_move_script` 漏了角色反推  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-30 — 工作台 S5：**把纪律变成会自己红的护栏**（`check_structure.sh` 第 4 步 + 文档哨兵看住分段小计）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-30 — 修 bug（作者报）：创作台**「弹幕台 / 整关预览」点不开** —— 被托管的视图把页签横栏的点击吃掉了  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-30 — 工作台 S4：**舞台装配合一**（`StageHost`：真游戏 / 工作台 / 三个组合台共用一条接线）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-30 — 工作台 S3：抽出 `Playback` + `Bookmarks`（播放/书签变**可无树测试**，并抓到「只写不读」的真 bug）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-30 — 工作台 S2：抽出 `HotReloadService`（热更新管线变成**可无树测试**的服务）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-30 — 工作台重构 **S1：先立公开接缝**（私有访问 181 → **0**）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-28 — S13 复核结案（`✘ 判据已过期` → **✔**）+ 本地 TODO 清过期两条  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-28 — 工具 bug：`log_archive.py --index` 会**按滚动窗口截断正文**（本次踩到并修掉）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-28 — 符卡背景从「一张贴图」升级成「一个**场景**」（+ 清掉死字段 `PhaseData.background`）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-28 — 修 bug（作者报）：符卡练习**返回后人物选择没回到同一个人**  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-28 — miss 补偿：**直接 +2 个雷**（不撒掉落物、雷碎片不动）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-28 — 符卡结算横幅：`Bonus Failed` / `Get Spell Card Bonus` + 奖励分 + 击破时间  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-28 — 拿到**完整残机**播 `get_player` 回报音（碎片集满 / 整命道具）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — `get_card` 音量 **+3 dB**（作者："调大一点"）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 正常流程**干净收取一张符卡**播 `get_card` 回报音  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — S2「判定点」那句**改字**（作者："改这行字"）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 中弹无敌**跟着 `DEATH_MENU_DELAY` 联动** + 无敌期**机体闪烁**  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 被弹炸弹补两处：**窗口内按暂停不再卡死** + 窗口期**框内整体渐显红滤镜**  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 被弹炸弹（deathbomb）：被弹瞬间定格几帧，按 bomb 抢命（一次扣 2 个雷）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 约定：临时探针产物放 `.godot/probe/`（不再往项目根建目录，作者已认可）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 吃 P 点**不再变金色**（金色只属于「点」）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — miss 后自机**复位两步**：瞬移到**框下方之外** → 升到 `_respawn_pos`（最后触发）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — miss 的 P 点扇形：**左右不出场地框**（贴墙一侧压扁）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — G8 追加：扇形飞完改**竖直下落**（作者："按弧形移动一会后就竖直向下落"）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — G8 落地：miss 接上火力惩罚 + 撒 10 个 P 点「向上 180° 均匀弧形」（S6 → ✔）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — S6 复核完毕：奖励分"待核"已过期 → 改判；顺带抓出**真缺口**（miss 的火力惩罚未接）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 文档哨兵进 `verify.sh`（第 1 步）+ N2 归档 + TODO_TEMP 去重（作者勾选的三项）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 非归档文档体检：修事实错误 + 给"混装"文档立「性质」栏位（作者："那其他所有除了以归档外的文档呢"）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 项目基线"还原本色"：正文只留规则与状态，证据/审计拆到附录（作者："没有基线那样精简了"）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 最佳实践日志"瘦身 + 可检索"：滚动窗口 + 顶部索引 + 按月归档（作者："太太太大了"）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 修回归：奖励分"作废"后的**早退**掐掉了减伤倒计时与时限判定（作者报）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 符卡记录页改成"**列全部符卡 + 三档显示**"（未遇见只给 uid 与问号，收取过才蓝）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 符卡奖励分"作废"机制：期间 **miss / 用 bomb** → 不给分 + 数字位显示「失败」  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 对话预览加 `@export` + 窗口内选段（作者："要不要加 export 和选择具体对话"）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 对话的"方便测试方法"：**预览场景 + 干跑**（顺带修掉情绪被冲掉的老 bug）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 加 `ActorHandle`：对话"谁做什么"（`enter()` 返回句柄）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — `DialogueSteps` 的六个"演出版"动词改收 `CharacterProfile`（作者："exit 为什么不传 profile？"）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 对话事件 handler 里的 `if` 巡检收口（作者："对句柄的判断是不是太多了"）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — `StageDirector.dialogue` 改收 `DialogueSteps`（作者建议）；并订正"对话不冻结时间轴"的错误说法  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — "Boss 击破后、关卡结束前加对话"：接上战后对话（事件收尾）+ 收尾作者挪文件的断链  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 对话构建函数**必须 static**；顺手修好被"静默跳过"的内容测试 + 补语法门禁盲区  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 全破音效换成专用素材 `boss_die`（替掉借来的 `enemy_die` 占位 key）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 魔理沙子机（focus）发射/命中音效各压 7 dB（两轮；并修 `sfx_db_baseline` 的判定口径）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — 全破反色圈改成**与自机 miss 同一套参数**（作者纠错：同心不等半径不是 miss 的做法）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-27 — Boss「全破」演出 + 关卡收尾动词（`defeat()` / `finish_stage()`）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-26 — 符卡练习 BGM 改成**每 Boss 一首**（道中曲 / Boss 曲可分别配）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-26 — 新增 `reflect()` 镜面方向原语（撞墙反弹不再只能"朝 Boss"）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-26 — 符卡奖励分改为**规则计算**（原作口径：难度权重 × 面序号 × 50 万；时限内均匀衰减到 30%）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-26 — Boss 计分行加说明前缀 + 倒计时再下移（并修掉前缀带出的两处版面 bug）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-26 — Boss 阶段倒计时挪到符卡名**下方**（位置改成场景声明）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-26 — 符卡练习二级列表：超长改为「开窗滚动」（不再膨胀出面板）  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-26 — 符卡记录分页：每页行数从写死 6 → 按面板实测高度算  ·  [归档](archive/LOG_2026-09.md)
- 2026-09-26 — 阶段身份「槽位数」口径：`phases_normal` 长度 → 各难度列最大长度（EX 面解锁）  ·  [归档](archive/LOG_2026-09.md)

## 记录

### 2026-10-10 — 音量管理补骨架：**真总线 + SE 密度护栏 + BGM 让位/交叉淡入**

- **作者报**：「音效的音量管理还是不怎么好」——"还是"说明前面那几轮（`SFX_DB` 均衡表 / 逐流 `min_interval` / `sfx_trim_db` 练习压低）只是**在调数值**，没治结构。
- **实测三处硬伤（探针 `AudioServer` 直读，不是读代码猜的）**：
  1. **总线是假的**：`bus_count = 1`（只有 Master），而 `ProjectSettings` 指的 `res://default_bus_layout.tres` **文件不存在** —— `_find_bus("BGM"/"SFX")` 每次静默回退 Master，所以「BGM/SE 总线」只是两个字符串（挂不了效果器、也没有总线级音量）。
  2. **主音量是半死的旋钮**：`play_sfx` 的算式缺 `master_volume`（只有 BGM 乘了），而且它**没有 UI、不进存档** → 恒等于 1.0。「BGM 滑杆 = BGM×主音量，SE 滑杆 = SE×0 dB」两条路口径都不一样。
  3. **多声叠加没有护栏**：16 路池 + 同帧去重 + 每条流各自的 `min_interval`（`0.05` / `0.03` 写死在调用点），**不同流会叠加**；池满就踢「最老的」= 掐断正在响的声音。
- **A · 真总线**：新增 `default_bus_layout.tres`（`Master → BGM / SE / UI`，用引擎 `generate_bus_layout()` 生成而不是手写格式）；音量**一律走总线**（`AudioServer.set_bus_volume_db`），per-player 只剩均衡偏移 ⇒ 改滑杆当场对所有在响的声音生效；**缺总线响亮告警**（`_require_bus`，只报一次）；`master_volume` 补上对 SE 的作用 + 选项菜单加「主音量」+ 进存档。
  - UI 音独立一条总线（与 SE 共用同一根滑杆）：SE 的密度护栏/限幅不该泵到菜单音。
- **B · 先量再调**：新增 `tools/audio_density_probe.tscn`（跑真实关卡，量每秒起声部数 / 单帧峰值 / 同时在响 / 驱逐 / 去重与节流挡掉多少 / **密度压制动了多少**）。
  - **实测（stage01，按住射击 25s）**：**545 路 / 25s ≈ 21.8 路/秒**，单帧最多 3 路，**同时在响峰值 14 / 16**，驱逐 **0** 次，同帧去重挡掉 93 次。
  - 两个反直觉的结论：① 密度主力是**自机自己的射击音**（~20/s），不是敌弹；② **池根本没满过** ⇒ "踢最老的"不是当下的病根，**响度总和**才是。
  - 据此落三道护栏：**SE 总线挂 `AudioEffectHardLimiter`（ceiling −1 dB，14 路叠加必削波）**；**密度压制** `density_cut_db()`（按**平滑后**的在响声部数，knee 8、每路 0.75 dB、上限 −3 dB，**只压新起的密集音**，正在响的不动 ⇒ 不引入"泵"，重要音不吃）；**优先级驱逐**（池满时踢「最不重要且最老」，而不是「最老」）。
  - 复测：密度与驱逐不变（护栏不丢音），**压制峰值 −3.00 dB / 均值 −0.09 dB** —— 它只在拥挤的瞬间出手，平时一个数都不动。
  - 探针的**诚实边界**：headless 里自机不会躲弹，差不多 35~60s 就 Game Over（75s 那轮实测在 **35.2s** 被"整棵树 paused"截断）⇒ 探针 `process_mode = ALWAYS` + paused 检测，**报告后退出而不是挂死**（第一版就是这么挂到 `timeout 300` 的）；想看 Boss 战的数字得再加「不死」开关。
- **D · 动态混音**：BGM 两路（**新曲满音量直入、旧曲淡出** —— 作者随后拍板"不要淡入"，见 `BGM_FADE_IN`；换曲不再硬切；同一首正在响仍不重头播，工作台重跑照旧）、`stop_bgm` 默认淡出（`fade=0` 才立即停）；**BGM 让位** —— `BGM_DUCK_ON_SFX`（`player_card` / `boss_die`）响起时 BGM 自动压 6 dB、保持 0.9s 再自动回落，调用点不必知道 duck 存在。
- **为什么这样分**：A 是骨架（后面两个都要踩在总线上）、B 治"叠加"（治并发，不是继续压 dB）、D 治"互相抢"（音乐让位给人声/关键音）。**没有动任何已调好的 `SFX_DB` 数值**。
- **⚠️ 同日回归（我造的，作者当场发现）**：作者报「关卡重开后音乐播放会重叠」。
  - 根因：`pause_menu` 的重开是「`stop_bgm()`（**我新改成淡出**）→ 立刻 reload → 新场景又播**同一首**」；
    而 `_play_bgm_at` 判「同一首正在响」用的是 `volume_db > SILENT_DB` —— 淡出中的那一路**不算数**，
    于是它另起一路同曲：**同一首歌自己叠自己**（两路播放位置差 ~0.3s = 合唱/回声）。
  - 修法：新增 `_bgm_stopping` 标记 + `_find_bgm_player_with(stream)` + `_adopt_bgm()` —— **同一首永远只有一路**：
    正在正常播（且不是刚被停）→ 续播；正在淡出 / 被叫起重开 → **复用那一路**从头播，其余各路淡出。
  - 教训：**「淡出」是一种状态**，不能用「音量是否 > −80」反推 —— 状态要用状态变量记，别拿观测量猜。
  - 回归测试先红后绿：`[2] expected to equal [1]`（两路同曲在响）→ 修后 `19/19` 全绿。
- **同日追加（作者拍板）**：**不要淡入** —— 新曲（含重开同一首）**满音量直入**，只有旧曲淡出。
  落成常量 `BGM_FADE_IN := 0.0`（改回 0.6 就恢复渐入），`_play_bgm_at` / `_adopt_bgm` 两处共用。
  新增 2 条回归（刚起就是 0 dB / 重开也是 0 dB），先红（`−79.97 expected to equal 0.0`）后绿 ⇒ `21/21`。
- **验证**：`test_sfx_mix.gd` 从 3 条扩到 21 条（总线存在 / 三段音量各自落地 / 主音量管 SE / 0 = 静音 / per-player 只剩偏移 / UI 独立总线 / 缺总线告警 / 限幅在 SE 上 / 压制随声部起伏且自动归零 / 池满保重要音 / 让位有起落且自动回落 / 关键音自动让位 / 交叉淡入淡出 / 同曲不重播 / 停止淡出 / **重开同一首只允许一路在响**）—— 全量 **802 用例 / 7040 断言**、`./tools/verify.sh` 七步全绿。
  - ⚠️ 用例耗时 +12s（让位/淡出要等真实时间），全量 41s → **53.8s**；这是"测真实时间行为"的代价，没拿 `Engine.time_scale` 取巧。

### 2026-10-10 — 补齐 10 个缺失弹型：**重建版的弹型资源在 git 里没丢**

- **作者报**：「bulletdef 资源数量不对 😭，我之前有个重建版里面的弹幕是全的，但是没有全部拿到主项目来」。
- **实测缺口**：`data/bullets/*.tres` 只有 **23** 个（16 敌弹 + 7 自机），而 `assets/Textures/bullet/` 有 **26** 张敌弹贴图、`data/atlas/bullet_shapes.tres` 有这些格 —— **素材与图集都在，只有数据没来**：
  `光玉 / 刀弹 / 大星弹 / 大玉 / 心弹 / 椭弹 / 火弹 / 矩弹 / 箭弹 / 蝶弹`（正好 10 个，2026-09-20 迁移那次只搬了旧 `bullet_configs` 表里有的 16 个）。
- **重建版在哪**：目录 `1-st-touhou-star-rebuild/` **已被删除**（盘上 / 回收站 / DSH 会话备份都没有），但它的提交**就在本仓库的对象库里**——`git log --all -- '*大玉*'` 命中 `0901249`（2026-09-10，重建版把工程放在仓库根的那一版），`data/bullets/*.tres` 27 个文件（26 敌弹 + `fx_cancel`）一个不少。
  - **教训**：「那个版本没了」先别认命 —— `git log --all -- <特征名>` / `git fsck --lost-found` 常常还在；**内容在 git 里，删的只是工作区**。
- **改动**：`git show 0901249:data/bullets/<名>.tres` 逐个取回，按主项目资源类转写（`BulletType` → `BulletDef`，只留 `id` / `texture_key` / `hitbox_radius` / `hitbox_offset`），判定值**照抄重建版**（如 `大玉` 36 / `光玉` 28 / `矩弹` 20 / `箭弹` 6 + offset x+20）；`follow_dir` 用默认 true —— 与主项目既有 `中玉` / `小光玉` 一致。
  - 注：重建版对**已有的 16 个**给的值与主项目现值**不同**（主项目沿用的是更早的 `bullet_configs`）。作者拍板「**全部对齐重建版**」，同批改掉其中 8 个：`点弹` 4→5、`菌弹` 4→5、`小玉` 6→8、`环玉` 6→8、`苦无` 6→5、`小光玉` 12→16、`星弹` 补 offset x−1、`滴弹` 6→5 补 offset x+4（其余 8 个本就同值）。
  - 连带：`test_bullet_shell.gd` 那条钉死的「小玉判定 6.0」改 8.0 —— 断言口径从「engine 现行为」改成「内容资源 `data/bullets/小玉.tres`」，**钉数据不钉代码**。
- **为什么加测试**：光靠人眼看「数量不对」正是本条发生的原因。新增哨兵 `test_data_validity.test_enemy_bullet_textures_have_defs`：
  **`assets/Textures/bullet/` 下每张弹贴图都必须有同名 `data/bullets/<名>.tres`**；白名单 = 不是弹的四张（图集本体 `bullet`、`laser`、出生雾 `弹雾`、消弹特效 `消弹`）。
- **验证（红→绿）**：先写哨兵跑 → 红且**恰好点出那 10 个名字**（`["光玉","刀弹","大星弹","大玉","心弹","椭弹","火弹","矩弹","箭弹","蝶弹"]`）；补资源后同条转绿。全量 GUT **784 用例 / 6996 断言**；`./tools/verify.sh` 七步全绿。
- **文档同步**：`docs/DANMAKU_API.md` §7.1 弹型表（哨兵按它比对 `data/bullets/*.tres`）、`docs/TEST_INDEX.md`（E 层 4/25）、README 徽章。

### 2026-10-04 — 清场要看得见：敌人**击破特效** + 弹幕**消弹特效**

- **需求（作者）**：「敌人清场要有击破特效，弹幕清场要有消弹特效」。
- **弹幕侧**：我先前包的 `BulletManager.clear_bullets()` 是**裸清**（`system.clear()`：无特效、无事件）。
  而**同一份代码里早有带特效那条路**：`sweep_enemy_bullets(center, radius, on_clear, inside)` 会
  **先收集 `(pos, tint)` → 逐颗 `despawn` → 逐颗 `play_clear_fx`**（同色提亮 1.5×，与死亡清弹圈 / `clear_fx()` **同一套**），
  且**只清 ENEMY 阵营** ✓ ⇒ 新增 `BulletManager.clear_enemy_bullets_with_fx()` = **一次罩住全场的 sweep**
  （圆心 `GameConfig.SCREEN_CENTER`、半径取**场地对角线** ≈1600 ⇒ 比 cull 范围只大不小），`ctx.bullets.clear_enemy_bullets()` 改走它。
  **零原生改动**（不必动 C++ / 不必重编扩展）✓。分工保留：`clear_bullets()` 仍是关卡收尾的裸清（`StageRuntime` 在用）。
- **敌人侧**：`EnemyService` 新增 **`despawn_clear(enemy)`** = `despawn()` + `ctx.effects.play_hit_effect(death_effect, 位置)`
  —— 正好对应子弹那边的 `despawn()` / `despawn_clear()` 之分（静默 vs 看得见）；
  **`despawn_all()` 改为逐只播击破特效**（"清场"本来就是可见事件）；没配 `death_effect` ⇒ 只回收、不报错。
  **仍不算战果**：不掉道具 / 不计分 / 不发 `enemy_killed` / 不播死亡音效（那些是 `die()`）。
- **中途发现的两件事（都直接影响测试写法，值得记）**：
  1. **内核把"纯特效行"和弹放在同一个 store**（特效行 `_type_index = -1`）⇒ **`active_count()` 是"弹 + 特效"的总数**，
     不能当弹数用。`sweep_enemy_bullets` 自己就用 `get_type(i) == null` 区分 ✓ 照抄同一条判据 ⇒ 测试改成「数真弹 + 数特效行」。
  2. **`ctx.effects` 的 getter 每次访问都重刷** `fx_pool = stage.fx_pool`（"每取一次保持最新"）⇒
     **直接往服务里注入特效池会被覆盖**，注入点是 **`stage`**（`StageRuntime.fx_pool`）。测试已按这条改（顺带 `autofree(rt)` 消掉一个孤儿）。
- **回归测试（4 条，都反向验证过会红）**：
  - 弹幕：2 颗弹 ⇒ 清空 + **恰好 2 条消弹特效**（退回裸清 ⇒ 报 `0 vs 2`）；
  - 敌人 `despawn_clear` ⇒ **恰好 1 次**击破特效（位置 = 敌人位置、用它的 `death_effect`）**且仍不发 `enemy_killed`**；
  - 敌人 `despawn_all` ⇒ 2 只杂兵 = 2 次特效、**假 Boss 不播**；
  - 敌人没配 `death_effect` ⇒ 只回收不报错。
- **⚠️ 自查披露（同一个坑第二次，教训升级）**：反向验证后的还原脚本，我用 `'play_hit_effect' not in t` 当守卫 ——
  而那个词**也出现在文档注释里** ⇒ 守卫误判、**敌人那处一度没还原**（是随后跑全量前检查文件状态才发现的）。
  上一轮（README 徽章的 `base_texture = ExtResource` 撞 `texture = ExtResource`）已经踩过同款。
  ⇒ 教训升级为：**还原 / 存在性判据一律用「带缩进的整行代码」，绝不用裸词。**
- **验收**：`./tools/verify.sh` 七步；GUT **118 脚本 / 783 用例 / 6973 断言**全绿。

### 2026-10-04 — 补「即时清弹」内容动词：`ctx.bullets.clear_enemy_bullets()`

- **起因**：作者问「有弹幕清场动词么」。查清**四个层级**：

| 层级 | 动词 | 有动画 | 内容够得着 |
|---|---|---|---|
| 单颗弹 | `BulletLifecycle.despawn()` / `despawn_clear()` | 否 | ✅ |
| 清激光 | `ctx.bullets.clear_all_lasers()` | 否 | ✅ |
| 圈内清弹 | `ctx.bullets.death_clear(...)` | ✅ **膨胀圈** | ✅ |
| **即时全屏** | ❌ **缺** | — | 底层有、内容够不着 |
| 全清（含特效池 / MultiMesh） | `BulletManager.clear_all()` | 否 | ✗ 引擎级 |
| 工具级清场 + 回收内核表 | `BulletManager.reset_world()` | 否 | ✗ 注释写明"**仅工具 / 工作台**用" |

- **缺口的证据**：底层 `clear_bullets()`（只清内核弹 + 炸弹）**存在**，但调用者只有 `stage_runtime.gd:89`（关卡收尾）；
  `clear_enemy_bullets_in_circle/shape` 只有**炸弹**在用（`kernel_bomb.gd:98` / `kernel_mist_bomb.gd:125`）⇒
  内容想"此刻清屏"只能写 `ctx.bullets.bullet_manager.clear_bullets()`，**绕过服务层** —— 与敌人回收**同一个病**。
- **改法（作者选"只加全屏那条"）**：`BulletService.clear_enemy_bullets()` → 直转 `BulletManager.clear_bullets()`。
  - **纯清除**：不给分 / 不给道具（与 `clear_all_lasers()` 一致；要"炸弹式计分清弹"走炸弹那条路）。
  - **只清敌弹**：不动激光（用 `clear_all_lasers()`）、不动特效池（那是 `clear_all()`，内容别碰）。
  - 与 `death_clear()` 的分工写进注释：那个有半径上限 + 分帧扫 + `on_clear`，适合"死亡 / 炸弹的可见冲击"。
- **测试**：**新建 `test/test_bullet_service.gd`** —— `ctx.bullets` 原本**没有专用测试文件**
  （`shoot_spread` / `death_clear` / `clear_all_lasers` 都只有间接覆盖）。两条：
  - 即时全屏 ⇒ 当帧一颗不剩（与距离无关）；
  - **与膨胀圈的语义差**：`death_clear(ZERO, 100, 1s, 30)` 当帧清不到 300px 外的弹，而本动词清得掉。
  - **反向验证**：把本动词临时写成 `start_death_clear(...)` ⇒ **两条断言红**（`2 expected to equal 0`）——
    正是它要防的那种混淆。
- **验收**：`./tools/verify.sh` 七步；GUT **118 脚本 / 781 用例 / 6963 断言**全绿。

### 2026-10-04 — 敌人回收**动词化**：`ctx.enemies.despawn` / `despawn_all`

- **起因**：作者问「敌人的回收怎么调用」。查下来**没有动词**（`StageRuntime`/`StageDirector`/`StageObjects` 全无），
  文档也**一个字没写**，而子弹那边有整套（`DANMAKU_API.md` 的 `despawn()` / `out_grace` + `BULLET_PIPELINE §5 回收`）
  ⇒ 内容只能裸调 `target.queue_free()`（`fly_away.gd` / `enemy04.gd` 两处）。
- **加的两个动词**（落在已有的 `EnemyService` = `ctx.enemies`，与 `spawn()` 对称）：
  - `despawn(enemy) -> bool` —— **静默**：不掉道具、不计分、不发 `enemy_killed`、不播死亡特效
    （对齐子弹 `despawn()` 的口径；"被打死"走 `Enemy.die()`）。
  - `despawn_all() -> int` —— 只收杂兵、**不动 Boss**（`Boss` 是 `Area2D` 的**兄弟类**不是 `Enemy` 子类 ⇒ 天然筛掉），返回数量。
    与 `EntityRegistry.clear()` 的分工：那个是"拆关卡"语义（连 Boss 一起释放 + 清空名单）。
- **实现中途被测试顶出两个真问题（都改了）**：
  1. **签名从 `Enemy` 改成 `Node2D`**：原设计收 `Enemy` ⇒ 内容得写 `target as Enemy`，而 `as` 在**不是** Enemy 时
     **静默变 null**，我的报错会说"敌人为空/已释放"——**误诊**了真正的原因。现在收 `Node2D`
     （= `CoroutineScript.target` 的静态类型 ⇒ 内容直传 `despawn(target)`），类型不对时**响亮报出它到底是什么**。
     ⇒ 教训：**内容侧静态类型是基类时，用 `as` 换"类型安全"会换来更差的诊断**。
  2. **`test_enemy04_move.gd` 原本用 `cs.start(null, tgt)`**（null ctx）⇒ 内容改走 `ctx.enemies` 后当场炸
     `Invalid access to property or key 'enemies' on a base object of type 'Nil'`。真游戏里 `spawn_enemy_data`
     **保证 ctx 非空** ⇒ 那个 null 只是"这条测试恰好只跑到移动"的巧合；已改为提供 ctx + 用真 `Enemy` 当 target。
     ⚠️ **这条只有跑全量才抓到**（单跑该文件是绿的）—— 又一次证明门禁必须跑全量。
- **内容已改走动词**：`data/stages/stage01/enemy/{fly_away,enemy04}.gd` 的裸 `target.queue_free()` → `ctx.enemies.despawn(target)`。
- **回归测试**（`test_ctx_services` +4，**都反向验证过会红**）：
  - 静默 ⇒ 把回收临时写成 `die()` 时，报 `Expected ... to NOT emit signal [enemy_killed]`；
  - **类型守卫** ⇒ 去掉守卫时，3 条断言红（返回 true / 无 push_error / 假 Boss 真被回收了）；
  - 容错（空与已释放**响亮**+false；重复回收静默 false）；
  - 批量（只收杂兵、跳过 Boss 位、返回数量）。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 779 用例 / 6958 断言**全绿。

### 2026-10-04 — Miss 的雷：从「+2 补偿」改为「−2、下限 3」

- **需求（作者）**：「miss 后改为减少 2 个 bomb，减少后如果不足 3 个 bomb 则设置为 3 个 bomb」。
- **这是改既有口径**：原先 miss 是**补偿 +2 个雷**（`Player.MISS_BOMB_GAIN = 2` → `PlayerResources.add_bombs()`，
  到 `MAX_BOMBS` 封顶；当时的理由写作"作者要求：不撒掉落物、雷碎片不动"）。现在改成**惩罚**：
  扣 `MISS_BOMB_PENALTY`(2)，再抬到下限 `MISS_BOMB_FLOOR`(3)。
- **⚠️ 明确记下这条副作用（作者口径，非 bug）**：规则是"**先扣、再把不足的抬到下限**"，**不是**"扣不动" ⇒
  `bomb < 3` 时中弹**反而净增**（1 → 3）。写进代码注释 + 基线文档 + 测试断言三处，
  免得以后有人当 bug"修掉"。
- **落点**：
  - `PlayerResources`：两个常量 + `on_miss_bomb_penalty()`（`changed.emit()` 让 HUD 刷新）；
  - `Player._apply_miss()`：`add_bombs(MISS_BOMB_GAIN)` → `on_miss_bomb_penalty()`；删掉 `MISS_BOMB_GAIN`（全仓已无引用）；
  - **雷碎片那条线不动** ✓（与原口径一致）。
- **同批更新的既有断言与文档**（旧口径散在多处，漏一处就是"文档在骗人"）：
  - `test_player.gd`：两条 `+MISS_BOMB_GAIN` 断言改成"扣 2 / 下限 3 / 满仓不越界"，
    并把两处过时措辞（"不补"、"不发补偿"）改成"不做雷惩罚"；
  - `test_player_resources.gd`：新增纯规则单测（与 `on_miss_power_penalty` 的测法对称）；
  - `docs/BASELINE_EVIDENCE.md`：miss 管线描述改写 + 那条"2026-09-28 补雷补偿"的历史注记改成
    "→ **2026-10-04 改为雷惩罚**"（保留历史，不篡改）。
- **回归测试（反向验证过会红）**：把下限拿掉（`maxi(..., 0)`）⇒ 两个测试文件共 **5 条**断言红，
  报 `2 / 0 / 1 expected to equal 3`。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 775 用例 / 6942 断言**全绿。

### 2026-10-04 — 关卡练习：第 2 面起**满火力**起步

- **需求（作者）**：「让关卡练习除了第一面的其他面都设置火力为满」。
- **现状**：`PlayerResources.reset_practice()`（= **符卡练习**）本来就 `power_raw = 300`（4.00）；
  而**关卡练习**走的是 `reset_all()`（`power_raw = 0` = 1.00）⇒ 练后面几面得从 1.00 攒起，练不到该面的弹幕。
- **改法**：
  - `PlayerResources`：抽出 `const MAX_POWER_RAW := 300`（原先写死 3 处），新增 `set_max_power()`
    （**必须 `changed.emit()`** —— 它是在 `reset_all()` **之后**单独调的，HUD 等不到下一次 reset）；
  - `SaveData`：`const PRACTICE_FULL_POWER_FROM_STAGE := 2` + `practice_starts_at_full_power()`（纯判定）
    + `apply_stage_practice_power(registry)`。⚠️ 判定比的是**面序号**（`StageCatalog.stage_no_of`）而不是 `stage_id`
    —— 3B 面 id=4、EX 面 id=9，"是不是第一面"要按面序号判（`stage_catalog.gd` 专门警告过别混用两套编号）。
  - `StageRuntime.load_stage()`：**紧跟在 `SaveData.reset_all()` 之后**调用它。
- **⚠️ 踩到的坑（第一次接错了位置）**：我最初把调用放在 `game_scene._ready()` 的 `reset_all()` 之后，
  端到端测试报 **`0 expected to equal 300`** —— 因为 `_start_normal_game()` → **`load_stage()` 内部还会
  `SaveData.reset_all()` 一次**，把满火力**冲掉**了。⇒ 落点改到**那次复位之后**（单点、且不吃调用顺序）。
  教训：**"复位"只有一个权威点时，规则要贴在它旁边**，否则会被下一次复位悄悄擦掉。
- **回归测试（3 条，端到端那条反向验证过会红）**：
  - `test_practice_full_power_rule`（纯判定：面 1 不拉满 / 面 2 起拉满 / **普通流程**不拉满）；
  - `test_stage_practice_stage_two_starts_at_full_power`（真场景 ⇒ `power_raw == MAX_POWER_RAW`；
    撤掉落点 ⇒ 报 `0 vs 300`）；
  - `test_stage_practice_stage_one_keeps_normal_power`（第 1 面例外 ⇒ 仍是 0）。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 774 用例 / 6937 断言**全绿。

### 2026-10-04 — 修「关卡练习菜单的黑幕没有了」（我的回归）+ 扫同款

- **症状（作者实测）**：关卡练习菜单的黑幕不见了。
- **根因（我的回归）**：`BasePage._create_overlay()` 会按名字**复用**场景里的 `Overlay` 并把它的
  `modulate.a` **归 0**；HEAD 的 `on_enter()` 会把 `Overlay.modulate.a` 拉回 1（黑幕可见），
  而我重写时改成"整页 `self.modulate` 淡入"、**再没碰过 `Overlay.modulate`** ⇒ 有效 alpha = `0.55 × 0` = **0**。
- **修法**：`on_enter()` 调 **`_fade_overlay_in(0.35)`**（BasePage 自带动词）；遮罩**颜色**归场景
  （`Overlay.color`），代码里那句写死的 `0.55` 删掉 —— 颜色不该有两个来源。
- **⚠️ 顺带修了一句假文档**：`is_auto_overlay` 的注释写着"设为 true 则 on_enter 时**自动淡入**暗色遮罩"，
  但代码**只创建 + 归零、不会淡入** ⇒ 子类不调 `_fade_overlay_in()` 就是黑幕不可见。
  这句承诺很可能就是原作者和我都只写 `self.modulate` 的原因。已改成实话，并注明
  `_fade_overlay_in(duration)` 的默认 `-1.0` **不是** `OVERLAY_FADE_IN`（调用要显式传时长）。
- **扫同款（`extends BasePage` × 5）—— 我的扫描错了两次，值得记**：
  1. 先用正则判"有没有碰 `overlay.modulate`"⇒ **假阳性 `replay_menu`**（它用的变量名是 `ov`，
     而它 `tween_property(ov, "modulate:a", 1.0, 0.5)` 本来就是对的）；
  2. 只查脚本、**漏了场景级 `is_auto_overlay = false`** ⇒ **假阳性 `spell_practice_menu`**
     （它明确关掉了自动遮罩、自己管，从来没坏）。
  ⇒ **最终靠"跑起来量有效 alpha"才定案**（测试的前提断言当场把假阳性顶了出来）。
  教训：**可机械判定的东西不一定适合用正则判**；能跑出数值的就跑数值。
- **回归测试（两条，都反向验证过会红）**：
  - `test_stage_practice_menu::test_overlay_curtain_is_restored_after_enter` —— 去掉 `_fade_overlay_in()`
    ⇒ 报 **`0.0 expected to equal 0.55`**（正是作者看到的"黑幕没有了"）；
  - `test_spell_practice_menu::test_overlay_curtain_stays_visible_with_self_managed_overlay` ——
    守"本场景自己管遮罩"这条：**若有人把 `is_auto_overlay` 打开却不补 `_fade_overlay_in()`，它会红**。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 771 用例 / 6928 断言**全绿。

### 2026-10-04 — 相机动词改名 + 目标记忆（作者实测「摄像机的 y 角度最后没回到 0」）

- **症状**：作者的 `stage02_decor.gd` 里 4 条 Y 旋转（−10/+25/−30/+15，**和 = 0**）跑完后 Y 停在 **+15°**。
- **根因（一对动词两种语义、名字看不出来）**：旧 `rotate_camera` 是**绝对**（`tween_property(camera, "rotation", target_rot)` = 设成它）、
  旧 `pan_camera` 是**相对**（`camera.transform.origin + offset`）。作者按 `pan_camera` 的心智模型写 Y **增量** ⇒ 期望回 0，
  实际"最后一条赢" ⇒ +15°。顺带三个坑：
  1. `rotate_camera` 的注释写着"Euler 角度, **度**"，而它 tween 的是 `camera.rotation`（**弧度**）⇒ **注释是错的**（作者写 `deg_to_rad()` 反而是对的）；
  2. 这些动词各自 `create_tween()`、**不杀旧 tween** ⇒ 重叠时同一属性两条 tween 同时写（谁赢看创建顺序）；
  3. `pan_camera` 读的是**实时** `transform.origin` ⇒ 重叠时以"飞行途中的位置"为基准 ⇒ 漂移。
- **改法（作者选 a+b）**：
  - **(a) 名字自解释**：`rotate_camera` → `set_camera_rotation`（绝对）· `pan_camera` → `move_camera_by`（相对）·
    `move_camera` → `set_camera_position`（绝对）· `tween_env_fov` → `tween_camera_fov`（它 tween 的是**相机 fov**，旧名里的 "env" 是错的）；
    **新增** `rotate_camera_by(delta)`（相对旋转）⇒ 能写"转过去再转回来"。
  - **(b) 目标记忆 + 杀旧 tween**：内部保存"上一条指令的**目标**"（pos/rot/fov），相对动词从**目标**累加（**不是**实时值）；
    每个属性只留一条活动 tween，新指令先 `kill()` 旧的；`reset_camera()` 杀光 tween 并把目标也拉回初始姿态。
    ⚠️ **不改变单条调用的画面**（作者那种不重叠的写法结果一致）⇒ 已冻结的画面线不受影响。
- **作者的脚本按其本意转写**：4 条 `rotate_camera` → `rotate_camera_by`（他只提 Y，但 pitch 也一起成了增量：
  终态 **−15° 俯视**，而不是原来的 **+10° 抬头**）—— 脚本里已写明，想改终态只动最后一行的数。
- **回归测试（两条，都反向验证过会红）**：
  - `test_relative_camera_moves_accumulate_from_target_not_live_value`：两条重叠的相对移动，第二条不得丢掉第一段（退成读实时值 ⇒ 报 `0.0 vs 5.0`）；
  - `test_relative_yaw_deltas_summing_to_zero_return_to_zero`：**把作者的 bug 原样编码** —— Y 增量 −10/+25/−30/+15 ⇒ 必须回到 0
    （退成读实时值 ⇒ 报 **`15.0 expected to equal 0.0`**，正是他的现象）。
- **📌 顺带发现（记进 TODO）**：命名仍轻微不一致 —— `set_camera_position`/`set_camera_rotation` 是**动画**（带 duration），
  而 `set_camera_fov` 是**瞬时**（无 duration）；同一个 `set_` 前缀两种行为。
- **📌 一个教训**：`ctx` 在内容脚本里是**无类型**的 ⇒ 调**不存在**的动词**语法检查抓不到**，只会在运行时报错。
  本次改名是靠**全仓 grep + 测试**兜住的（不是靠门禁）。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 769 用例 / 6921 断言**全绿。

### 2026-10-04 — 相机初始姿态改由**背景自己声明**（`override_camera_home`）

- **起因**：作者问「3D 摄像头的初始值能设置吗」。查明现状：
  - `StageBackground._find_camera()` **只看父节点的子节点**（宿主 SubViewport 里那台）⇒ **背景场景里放自己的 `Camera3D` 会被完全无视**；
  - 初始姿态有**四个来源**：`game_scene.tscn` / `workbench.tscn` 的相机、抓图工具的 `CAM_POS`/`CAM_ROT_DEG`/`CAM_FOV` 常量、以及 `_own_camera()` 里写死的一组字面量 —— **同一组 `(0,10,6)`/`(−30,0,0)`/`90` 抄了四遍**（正是 `check_structure.sh` 规则③「唯一来源常量」要防的漂移）。
- **改法（作者选方案 1）**：`StageBackground` 新增 `@export override_camera_home` + `camera_home_position`/`camera_home_rotation_degrees`/`camera_home_fov`，
  在 `_ready` 里**抓 home 之前**应用到解析到的那台相机 ⇒ `reset_camera()` 天然复位到**声明的**那套。
  两个背景场景都已打开它（值 = 今天的默认 ⇒ **零视觉变化**），于是"每面自己的初始构图"变成**场景里可改的三个数**。
  - 不建第二台相机、不碰 `Camera3D.current`、与宿主那台不冲突 ⇒ 没有"渲染用一台、逻辑动另一台"的错配风险。
- **降险事实（grep 过全仓）**：只有 `screen_fog_fx.gd` 读这台相机（做太阳投影），`game_scene.gd` **零处引用**
  ⇒ 3D 相机纯粹是"背景的画法"，**不影响弹幕 / 判定 / 坐标**。
- **回归测试**：`test_camera_home_override_applies_and_is_the_reset_target` —— 宿主相机故意摆成别的姿态，
  断言入树后是**声明的**姿态、且演出跑过（pan/rotate/zoom）后 `reset_camera()` 回的也是**声明的**。
  反向验证：去掉 `_apply_camera_home_override()` ⇒ 报 `(0,10,6)` vs 期望 `(0,20,-3)`、`−30` vs `−22`、`90` vs `68`。
- **顺带**：抓图工具在 `--headless`（dummy 渲染器）下原先是 `linear_to_srgb` 的**空指针堆栈**；
  现在改成**响亮报错 + 退出**（"本工具需要真实渲染后端"）—— 它每次冒烟测试都在污染输出，而静默继续等于拿假数据当结论。
- **遗留（记进 TODO）**：那组相机值仍写在 4 处；两个背景开了 override 之后，**宿主那两台已冗余**（只剩"没开 override 的场景"用得到）。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 767 用例 / 6918 断言**全绿。

### 2026-10-04 — 修「一改太阳 y，黑雾的太阳对准就不准」（投影的是节点，画的是 sprite）

- **症状（作者实测）**：「我一改太阳的 y 坐标，黑雾的太阳的对准就不准了」。
- **根因**：`ScreenFogFX._update_sun_pos()` 投影的是 **`Sun` 节点**的 `global_position`，而**看得见、拖得动的是它的子节点 `SunSprite`** —— `SunSprite` 带自己的局部位移（stage02 里就有一段）⇒ 两者不是同一个点，**偏移越大、错得越远**。旧实现**恰好**只在"`SunSprite` 位移为零"时对齐。
- **修法**：
  - `BackgroundSun` 新增 `drawn_position()` = **`sprite.global_position`**（没有 sprite 才回落 `global_position`）——
    把"我到底画在哪儿"这件事留给太阳组件自己回答；
  - `ScreenFogFX` 投影时优先用它。**改 `Sun` 的 y 或改 `SunSprite` 的 y 都会对齐**。
- **实测（探针 `.godot/probe/sun_align.gd`）**：两个背景的"雾 `sun_pos` vs sprite 归一化位置"误差 **0.00 px**。
  反向验证：把投影退回 `Sun` 节点 ⇒ 报 `sun_pos.y = -0.0076` vs 期望 `0.0273`（错位 **≈34 px**），正是作者看到的现象。
- **顺带（给作者的量程表）**：`Sun` 在 `z=-500`、`SunSprite` 位移清零时，`Sun.y` → 屏幕归一化 y：
  `0→0.224`、`40→0.170`、`60→0.141`、`80→0.111`、**`87→0.100`**、`100→0.079`、`120→0.046`、`160→-0.027`（出框）。
  ⚠️ 作者当时的 `Sun.y=100` **加** `SunSprite.y=+106` = 全局 206 ⇒ 归一化 **-0.121（顶边外 116 px）** ——
  也就是说**只要把 sprite 位移清零、`Sun.y` 保持 100，太阳就进画面了**（距顶边 7.9%）。
- **回归测试**：`test_fog_aligns_to_the_drawn_sprite_not_the_sun_node` —— 给 `SunSprite` 一个明显的局部位移，
  断言雾写入的 `sun_pos` 等于 **sprite** 的投影、且与 `Sun` 节点的投影差得够远（用例前提自检，防空转）。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 766 用例 / 6912 断言**全绿。

### 2026-10-04 — 废止「记得调用才显示」：背景演出层改**宿主自动接线**（练习模式也开黑雾）

- **起因**：作者问「为什么二面道中**现在**看不见太阳和黑雾」。查明是**我上一轮的设计造的坑**：两个组件在 `_ready()` 里藏起来、只由 `setup()` 显示 ⇒ **场景里声明了、脚本忘了调 = 永远隐形 + 零报错**。作者其实**已经把节点都摆好了**（`Sun`/`SunSprite`/`FogFX`/`FogLayer`/`FogRect`，材质/纹理/`resource_local_to_scene` 都齐，连 `SunSprite` 的局部位移都在编辑器里调过），只是 `stage02_decor.gd` 没调 `setup()`。
- **作者拍板**：**练习模式也开黑雾** ⇒ 「藏起来等 `setup()`」这个机制**连存在理由都没了** ⇒ 整条废止。结果是**删 API**而不是加 API。
- **改法**：
  1. **声明即显示**：`BackgroundSun` 删 `_ready` 隐藏与 `setup()`（`_ready` 只留"缺 `SunSprite` 就响亮"）；`ScreenFogFX` 同样删隐藏，`setup(sun, camera)` → **`bind(camera, sun)`**。
  2. **宿主接线**：`StageBackground._resolve_showcase()` 在 `_ready` 里**按类型**（不按名字 —— 同 `DecorManager`/`WorldEnvironment`）找 `ScreenFogFX`/`BackgroundSun`，并 `fog.bind(camera, sun)` ⇒ **内容脚本一个调用都不需要，也就没有"忘"的机会**。
  3. 两个内容脚本删掉 `setup()` 调用与随之无用的局部变量。
  4. **练习模式一行都不用改**：它走 `_load_background(PracticeSession.background)`（**不调 `load_stage`**），背景一入树就显示 ⇒ 练习自然有黑雾 + 太阳。
- **顺带一个安心结论**：雾层在**背景 SubViewport 内** ⇒ 只压暗背景、**不挡弹幕/自机**（"草地隐约可见"就是这么来的）⇒ 练习模式开它不影响可玩性。
- **回归测试**（`test_stage_background` 16 例）：
  - 新增 `test_host_auto_binds_fog_without_any_content_call` —— 背景入树后 `fog.camera` 已接上、`sun_pos` 已算出、雾层与太阳都可见，**全程零内容调用**。反向验证：去掉 `_resolve_showcase()` ⇒ 报相机为 `<null>` 且 `sun_pos` 停在哨兵。
  - `test_fog_setup_...` → 改名 `test_fog_bind_does_not_need_background_parent`（**注入而非摸爹**这条不变量仍在）。
  - 两条断言从"未 setup 前不显示"翻成"**声明即显示**"；其中一条我**漏翻了** —— 测试立刻报 15/16（`未 setup 前不显示`），补齐后 16/16。
- **教训**：**别把"显示"绑在"记得调用"上**。默认方向应是"声明了就看得见"，要例外就**显式**关（而不是靠漏调）。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 765 用例 / 6910 断言**全绿；抓图工具 `--stage 1` / `--stage 2` 都跑通。

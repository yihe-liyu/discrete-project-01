# 重建版仓库状态（归档登记）

> 2026-09-14 登记。主工程（`1-st-touhou-star-~-broadest-and-narrowest`）的原生弹幕内核已落地（L3.5-4e/4f），
> GDScript 内核从**生产**删除。**重建版仓库**（`1-st-touhou-star-rebuild`）完成历史使命，转为**归档**。

## 重建版是什么

- 内核开发环境（独立 Godot 工程）：曾是主工程 `scripts/kernel/**` 的**上游**，通过 `tools/vendor_kernel.sh` 单向 vendor。
- 主工程 `scripts/kernel/**` 已于 **L3.5-4f 删除**；**冻结参照（oracle）** 现位于主工程 `test/reference/`
  （`BulletSystem` / `HitGeometry` / 参考解释器 / fallback 行为），继续为 parity 测试提供逐位参照。

## 归档时状态

- 路径：`../1-st-touhou-star-rebuild`（相对主工程）
- 分支：`main`
- HEAD：`2466a93`（fix(kernel): despawn drain 改降序——升序会丢大 id）
- tags：`kernel-v1`、`kernel-v2`
- 工作树：clean

## 之后怎么办

- **不再 vendor**：`tools/vendor_kernel.sh` 已删；内核改动改在原生 C++（`gdextension/`）。
- **oracle 维护**：若原生行为语义变更，同步更新 `test/reference/` 的参照实现并重跑 parity
  （`test_native_integrate` / `test_native_storage` / `test_native_executor`）。
- 若要从本仓彻底移除 oracle，可改由重建版仓库跑 parity —— 但那会失去 in-repo 安全网（拍板 A 已否决）。

---

## 2026-09-22 · 归档仓物理退役（历史折入主仓）

> 工作区 `DiscreteProject/` 从 5 个目录收敛为**只剩主工程一个**。重建版历史没有丢，
> 而是折进主仓对象库的命名空间 ref —— 主仓自此是唯一事实源。

### 删了什么

| 原路径 | 体积 | 处置 |
|---|---|---|
| `../1-st-touhou-star-rebuild/` | 26M | 工作树删除（独有提交先 push 进其镜像） |
| `.git-backups/1-st-touhou-star-rebuild.git` | 5.3M | 对象 100% 折入主仓后删 |
| `.git-backups/1-st-touhou-star-original.git` | 100M | 冗余镜像（无本地缺失 ref）→ 删 |
| `.git-backups/` 整体 | 105M | 删；主仓 `backup` remote 一并移除 |

> 附注：重建版工作树里那处未提交改动 `assets/textures/bullet/bullet.png` 与主工程
> `assets/Textures/bullet/bullet.png` **md5 相同**（`209eb3ff…`），属冗余，未单独保留。

### 历史现在住在哪（主仓内）

```
refs/archive/rebuild/heads/main          # 2466a93，67 个提交
refs/archive/rebuild/tags/kernel-v1
refs/archive/rebuild/tags/kernel-v2
refs/archive/rebuild/orphan/orphan-e1a09f9…   # 被 amend 掉的 M1 版本（游离提交，留底）
```

> 刻意**不**占主仓 `refs/tags/` 命名空间（避免与主工程 tag 混淆）；
> 用 `git for-each-ref refs/archive` 查看。

### 要把它导回独立仓库

```bash
git bundle create rebuild.bundle \
  refs/archive/rebuild/heads/main refs/archive/rebuild/tags/*
git clone rebuild.bundle 1-st-touhou-star-rebuild
```

### 遗留

- ✅ **`kernel/s2-swap` 已推 origin（2026-09-22 补推）**：`439cc5e..b238626`（80 个提交）。
  当日先遇 `OpenSSL SSL_read: unexpected eof`，`git push --dry-run` 协商成功但传包被断 ——
  重试即过（**间歇性网络重置，不是配置问题**；pack 仅 1.12 MiB）。
  异地备份缺口已闭合；`backup` remote 不再需要。
- ✅ **两个本地独有分支已处理（2026-09-22）**：`kernel/s0-vendor` 已推 origin（`903871a`）；
  `chinese-rewrite` 按作者决定删除 —— 它相对 `main` 仅 **1 个独有提交** `49a126f`
  （「菜单系统中文化 WIP（半成品）」），删后成为游离对象，可恢复：
  `git branch chinese-rewrite 49a126f90e6ba707d8aaec0b47e0ccba36e1bc3e`（gc 前有效）。
  至此本地分支**全部已上远端**，无本地独有副本。
- `git fsck` 报 2 个缺失 tree，只挂在**无 ref 可达**的游离提交 `abde839`（"命中音效音量 -10 → -14dB"）
  上 —— 属**先前**的局部 prune 残留，与本次目录清理无关（主仓无 `alternates`）；
  4 个本地分支 + 上述归档 ref 的 tree 递归读取**全部完整**。

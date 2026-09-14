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

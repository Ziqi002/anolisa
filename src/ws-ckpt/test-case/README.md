# ws-ckpt 测试用例目录

> 本目录只产出测试文档与一键执行脚本，不修改任何业务代码。

## 目录结构

```
test-case/
├── _lib/
│   └── common.sh                       # 公共 bash 辅助库（断言、环境检测、路径常量）
├── main/
│   ├── 2026-05-20.md                   # 用例说明（同名 .sh 为一键脚本）
│   ├── 2026-05-20.sh
│   ├── 2026-05-25.md
│   ├── 2026-05-25.sh
│   └── run_all.sh                      # 该分支全部日期脚本聚合入口
└── <branch-dir>/                       # 例: feat-ckpt-temp/,只跑该分支领先 commit
```

> 分支目录命名规则：将分支名中的 `/` 替换为 `-`（如 `feat/ckpt/temp` → `feat-ckpt-temp`）

## 命名约定

- 每次添加只产出 **一个 md + 一个 bash**，文件名为日期（如 `2026-05-20`）
- md 内写明覆盖哪些 commit、为什么加、加了什么测试、期待结果
- 新增文件 md 顶部标注 `状态：待审核`，审核通过后移除

## 执行

```bash
# 单分支全部用例
bash test-case/main/run_all.sh

# 单个用例
bash test-case/main/2026-05-20.sh
```

**目标环境**: Linux + btrfs + root + 已安装 ws-ckpt

退出码：0 = 全 PASS/SKIP，1 = 至少一个 FAIL。

## 覆盖范围

- **main**: 全量 `git log main -- src/ws-ckpt/` 历史,按日期增量追加新的 `YYYY-MM-DD.{md,sh}`
- **其它分支**: 仅 `git log main..<branch> -- src/ws-ckpt/` 领先 commit;脚本顶部用 `tc_require_branch` 守卫,分支未合并到 HEAD 时整体 SKIP

## 周期合并规则

- 每周日把本周「已审核通过」的 md + bash 合并为单一 md + bash，避免文件累积（去掉 `状态：待审核` 标注后再合并）。
- 非周日的增量运行只追加当日 `YYYY-MM-DD.{md,sh}`，不做合并。

## 覆盖日志

| 日期 | 分支目录 | 覆盖范围 | 状态 |
|------|----------|----------|------|
| 2026-05-20 | main | v0.1.0~v0.2.x 基线 | 已审核 |
| 2026-05-25 | main | v0.3.0（17 commits） | 待审核 |
| 2026-05-25 | feat-ckpt-temp | 领先 commit | 待审核 |
| 2026-05-27 | feat-ckpt-bug-fix | 5 bug-fix commits | 待审核 |
| 2026-06-02 | main | v0.3.1 + v0.3.2（14 commits） | 待审核 |
| 2026-06-02 | fix-ckpt-bug-fix-615 | 3 领先 commit（含 issue#669 cwd 守卫） | 待审核 |
| 2026-06-03 | main | Hermes adapter runner（1 commit, 99ba08a） | 待审核 |
| 2026-06-03 | fix-ckpt-bug-fix-669 | 4 领先 commit（issue#669 收口 + rollback 守卫回归） | 待审核 |
| 2026-06-03 | fix-ckpt-bug-fix-672 | 1 领先 commit（snapshot id 解析层校验） | 待审核 |

### 2026-06-03 增量说明

- 扫描所有本地分支（忽略 tag 与 ckpt-test）。本次新增覆盖：
  - **main**：自上次（2026-06-02 覆盖到 v0.3.2 / `6efd77a`）以来唯一新落入的 ws-ckpt commit `99ba08a`（Hermes adapter runner：新增只读 `detect-hermes.sh`、manifest/Makefile 登记、`install-hermes.sh` 支持 `HERMES_HOME` 覆盖与 `ANOLISA_DRY_RUN` 干跑）。实跑验证：16 PASS / 0 FAIL / 3 SKIP（DRY-RUN 因 adapter 源不可见而 SKIP）。
  - **fix/ckpt/bug-fix-669**：领先 main 的 4 个 commit，issue#669 cwd 守卫正式收口。实跑验证：22 PASS / 0 FAIL / 1 SKIP（集成测试需 root）。
  - **fix/ckpt/bug-fix-672**：领先 main 的 1 个 commit，checkpoint `-i` 解析层拒绝空白/路径分隔符/`.`/`..` id（issue#672）。实跑验证：5 PASS / 0 FAIL / 1 SKIP（CLI 行为断言需二进制）。
- **旧缺陷已修复（回归确认）**：上一轮 `fix-ckpt-bug-fix-615/2026-06-02` 用例 **3.10** 是有意 FAIL 的探针，指出 rollback 未接入 cwd 守卫。本轮 `fix-ckpt-bug-fix-669/2026-06-03` 用例 **2.2** 在该分支源码上**已转为 PASS**（`snapshot_mgr.rs` rollback 前调用 `guard_cwd_occupants`），证明 issue#669 已把守卫接入 init **和** rollback 双路径。
- **跳过的分支**：
  - `release/ckpt/v0.3.1`：领先 main 的 2 个 ws-ckpt commit（`846c2c6` / `b887fdc`），其中 `846c2c6` 与 main 上 `79fd8d3` 的 ws-ckpt 改动 `git diff` 完全一致（冗余），无独有变更，不单独建用例（沿用 2026-06-02 判定）。
  - 其余分支（`fix/ckpt/bug-fix-672` 之外的 release/* 及 `local-cleanup`）领先 main 的 ws-ckpt commit 数为 0。
- **周期合并**：今天是 2026-06-03（周三），非周日，按规则**不做合并**，仅追加当日增量文件。

### 2026-06-02 增量说明

- 扫描所有本地分支（忽略 tag 与 ckpt-test）。本次新增覆盖：
  - **main**：自 v0.3.0 (577f3ff) 以来落入的 14 个 ws-ckpt commit（v0.3.1 + v0.3.2）。
  - **fix/ckpt/bug-fix-615**：领先 main 的 3 个 commit，核心是 issue#669 的 /proc cwd 占用守卫。
- **release/ckpt/v0.3.1 已跳过（冗余）**：其领先 main 的 ws-ckpt commit（`846c2c6`）与 main 上的 `79fd8d3` 内容完全一致（`git diff` 为空），且该分支整体落后于 main，无独有 ws-ckpt 变更，故不单独建用例。其余 release 分支领先 commit 数为 0。
- **已知缺陷（待开发确认）**：`fix-ckpt-bug-fix-615/2026-06-02` 的用例 **3.10 为有意 FAIL 的缺陷探针** —— commit `5bc4e2a` 声称 cwd 守卫覆盖 `init/rollback`，但 `guard_cwd_occupants` 仅接入 `init`（`workspace_mgr.rs:247`），`rollback` 路径未调用。详见该 md 的「缺陷发现」。


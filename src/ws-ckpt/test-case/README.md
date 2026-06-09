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
| 2026-06-04 | bug-fix-673 | 1 领先 commit（init 失败数据保全 #673） | 待审核 |
| 2026-06-04 | bug-fix-674-685-686 | 3 领先 commit（rsync bail #674 / registry lock-free #685 / seccomp arch #686） | 待审核 |
| 2026-06-04 | fix-ckpt-bug-fix-669 | +1 增量 commit（plugin error mapper 加固 32dd1d8） | 待审核 |
| 2026-06-09 | main | v0.3.3：per-workspace policy override 端到端（含 hermes/openclaw）+ init 数据安全 + 锁粒度收尾 | 待审核 |

### 2026-06-09 增量说明

- 扫描所有本地分支（忽略 tag 与 ckpt-test）。当前本地仅剩 `main` 与 `release/ckpt/v0.3.3` 两个分支——
  此前覆盖过的 bug-fix 分支（`bug-fix-673`/`bug-fix-674-685-686`/`fix/ckpt/bug-fix-669`/`fix/ckpt/bug-fix-672`）
  已合并进 main 并删除，相关改动不重复测。
- 本次新增覆盖：
  - **main**：自上次基线 `99ba08a`（2026-06-03）以来落入的完整 **v0.3.3** 周期。核心是
    `0e04853` + `44607ee` 的 **per-workspace policy override（按工作区粒度清理策略覆盖）**
    端到端新特性，贯穿 common（3 个 versioned JSON schema：`ws-ckpt-policy/v1`、`ws-ckpt-config/v1`、
    `ws-ckpt-overview/v1` + 新 IPC 变体 + `PolicyFieldOp`）、daemon（`lock_wsid` 串行化、recover 清空
    per-ws index dir）、cli（`config -g/-w/--reset/--format json`，scope 互斥与 overview 视图）、
    skill（`SKILL.md` config 段）、plugin（openclaw `config.ts` + hermes `tools.py` 的 parse-error/
    disabled/count/age 辨识联合解析，信任 daemon 预计算 `is_disabled`，严格整数校验）。附加 init 数据安全
    （`b6155bb`/`605a760`/`8952d60`：`.pre-init-bak` rename、`cp --reflink=always`、foreign-backup 安全）
    与锁粒度/原子写收尾（`822bfda`/`3c2f421`/`a60d468`/`d3089d3`）。
  - 实跑验证（main 源码 worktree）：**54 PASS / 0 FAIL / 2 SKIP**（SKIP 为需 `ws-ckpt` 二进制的 version
    与 scope 互斥 CLI 行为，Mac 上无二进制）。
- **跳过的分支**：
  - `release/ckpt/v0.3.3`：领先 main 的 2 个 commit 仅为 `docs(ckpt)`（与 main `e94aba4` 内容一致）
    + `chore(ckpt): release v0.3.3` 打 tag，且整体落后 main 11 个 commit，无独有 ws-ckpt 行为变更，
    不单独建用例（沿用历次 release 分支冗余判定规则）。
- **已合并 bug-fix 提交不重复测**：`591abda`/`fa1bef6`/`f4e6486`/`0f62235`/`cdc839f`/`5002255`/
  `81b4e7a`/`9094baa`/`f29faf3`/`e1f51fa`/`48d878c` 等已在各 bug-fix 分支目录历史用例覆盖。
- **周期合并**：今天是 2026-06-09（周二），**非周日**，按规则不做合并，仅追加当日增量文件。
- 下次扫描基线：main 最新 ckpt commit `3d0a4cf`（release v0.3.3）。

### 2026-06-04 增量说明

- 扫描所有本地分支（忽略 tag 与 ckpt-test）。本次新增覆盖：
  - **main**：自上次（2026-06-03 覆盖到 `99ba08a`）以来仅有 `6e57f5d`(temp) + `7e1f206`(Revert "temp")，net diff 为空，**无需新增用例**。
  - **bug-fix-673**（新分支）：领先 main 的 1 个 commit `dc40b14`，init_workspace 失败时 rename 替代 remove_dir_all 保全用户数据。静态断言 13 项。
  - **bug-fix-674-685-686**（新分支）：领先 main 的 3 个 commit，修复三个独立 daemon 问题（rsync bail / write-lock registry / seccomp TargetArch）。静态断言 15 项。
  - **fix/ckpt/bug-fix-669**（增量）：新增第 5 个 commit `32dd1d8`（plugin error mapper hardening），修复 CwdScanFailed 被误报为 "Snapshot not found" 的优先级 bug。静态断言 10 项。
- **跳过的分支**：
  - `fix/ckpt/bug-fix-672`：commit SHA 因 rebase 变化（`ecc9017`），但改动内容与上次覆盖一致，不重复。
  - `local-cleanup`：仅 1 个 "temp" commit（WIP 大重构），不建用例。
  - `release/ckpt/v0.3.1`：仍冗余（同 2026-06-02 判定）。`release/ckpt/v0.3.2` 领先 commit 数为 0。
- **周期合并**：今天是 2026-06-04（周三），非周日，按规则**不做合并**，仅追加当日增量文件。

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


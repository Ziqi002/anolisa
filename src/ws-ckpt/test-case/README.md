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

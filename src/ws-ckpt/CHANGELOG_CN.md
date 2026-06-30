# 更新日志

## 0.4.0

### 不兼容变更
- **BREAKING** checkpoint 的 `-i`/`--id` 参数替换为 `-s`/`--snapshot`；`-i` 保留为隐藏别名，未来版本可能移除 (#1064)

### 新功能
- 新增 plugin install/uninstall 子命令 (#1005)
- 新增 component.toml 用于 anolisa-cli 适配器发现 (#1005)
- 新增 rollback 预览功能，支持 --preview 参数 (#1103)
- 新增 CLI 操作完成后的耗时显示 (#1075)
- 新增省略 --snapshot 时自动生成快照 ID (#1064)
- 新增 SLS 运维日志输出，用于仪表盘指标 (#1059)
- 新增 diff 可选 -t 参数，支持快照与当前工作区对比 (#848)
- 新增按祖先数回滚及快照 DAG 血缘追踪 (#877)
- 新增基于 cron 的定时 checkpoint 调度 (#819)

### 缺陷修复
- 修复 --snapshot/-s 为主参数，对齐插件参数处理 (#1103, #1064)
- 修复 SKILL.md 与实际 CLI/插件实现不同步问题 (#847)
- 修复 init 和 recover 对被替换的工作区符号链接的防护 (#860)
- 修复 init rsync 去掉 --copy-unsafe-links 参数 (#873)

## 0.3.3

### 新功能
- 新增 per-workspace 策略覆盖，支持 hermes/openclaw 插件 (#721)
- 新增 `/proc` cwd 占用检测，用于 init 和 rollback 防护 (#684)
- 新增 Hermes 适配器运行脚本 (#617)

### 缺陷修复
- 修复写锁竞争和 cwd guard 死锁问题 (#721, #684)
- 修复非 UTF-8 路径和路径遍历快照 ID 的输入校验 (#695, #678)
- 修复 seccomp 架构选择、工作区注册表并发、RPM 打包问题 (#695, #684)

## 0.3.2

### 缺陷修复
- 修复 openclaw 卸载时移除 config 中的工具白名单
- 修复父路径拒绝规则在 skill 和 openclaw 插件中作为工作区级规则生效

## 0.3.1

### 新功能
- 拒绝将 hermes 自身 cwd 或其父路径作为工作区

### 缺陷修复
- 修复插件工作区配置注册和自动加载
- 修复插件工具优先使用显式 workspace 参数而非 config
- 修复 skill delete 必须带 --force 的问题
- 修复 daemon 工作区路径校验和 fswatch 文件描述符泄漏
- 移除无用的 btrfs_ops.rs 模块

## 0.3.0

### 新功能
- 新增 openclaw 插件脚手架
- 新增 hermes 插件脚手架
- 将 ws-ckpt skill 改为 agent 无关，调用时提示指定工作区
- 遵循 `make install` 约定，集成到 build-all 流程
- daemon 改为有状态模式

### 缺陷修复
- 修复 list 和 diff 子命令的缺陷

## 0.2.0

### 新功能
- 新增 auto_cleanup 功能及开关
- 统一通过 TOML 文件修改配置
- 新增全局 CLI 告警：任一工作区快照超 1000 或文件系统使用超 90%
- 移除过时的 fs_warn_threshold_percent 参数

### 缺陷修复
- 修复后端检测和 daemon 状态恢复逻辑
- 修复 image size 配置在 daemon 重启后不生效的问题
- 修复 config.toml 作为示例文件分发

## 0.1.0

### 新功能
- Daemon 架构，Unix Socket IPC + Bincode 二进制协议
- `init` / `checkpoint` / `rollback` / `delete` / `list` / `diff` / `cleanup` / `status` / `config` 命令
- 后台调度：自动清理、健康检查、孤儿恢复
- 多后端支持：btrfs-base / btrfs-loop / overlayfs，自动检测
- TOML 配置持久化，运行时热加载
- systemd 服务，ALinux 4 RPM 打包

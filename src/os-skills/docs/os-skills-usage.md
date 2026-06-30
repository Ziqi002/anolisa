# OS Skills 用户手册

OS Skills 是 ANOLISA（Agentic OS）为 Agent 提供的操作系统说明书，为 AI Agent 提供系统管理、DevOps、安全、云集成等领域的结构化知识与自动化能力。技能以 Markdown 文件为载体，安装后由 Copilot Shell（cosh）、OpenClaw、Hermes、Claude Code、Gemini CLI 等 Agent 运行时自动发现和调用。

## 一、安装

### 1.1 RPM 安装

Agentic OS 内置，也可通过 yum 单独安装：

```bash
sudo yum install os-skills
```

技能安装到 `/usr/share/anolisa/skills/`，Copilot Shell 启动时自动发现。

注：需要配置 yum 仓库，在 `/etc/yum.repos.d/` 新建文件 `AliYunAgentic.repo`，内容如下：

```bash
[alinux4-agentic]
name=alinux4-agentic
baseurl=http://mirrors.cloud.aliyuncs.com/alinux/$releasever/agentic-os/$basearch/os/
enabled=1
gpgcheck=1
gpgkey=http://mirrors.cloud.aliyuncs.com/alinux/$releasever/RPM-GPG-KEY-ALINUX-4
```

### 1.2 手动安装到 Cosh

将技能目录复制到以下搜索路径之一：

| 级别   | 路径                           | 说明                    |
| ------ | ------------------------------ | ----------------------- |
| 项目级 | `.copilot-shell/skills/`     | 仅当前项目可用          |
| 用户级 | `~/.copilot-shell/skills/`   | 当前用户全局可用        |
| 系统级 | `/usr/share/anolisa/skills/` | 所有用户可用（需 root） |

### 1.3 安装到 OpenClaw / Hermes

#### 通过 ANOLISA CLI（推荐）

```bash
anolisa adapter enable os-skills openclaw
anolisa adapter enable os-skills hermes
```

adapter 方式会写入 ANOLISA receipt，后续可通过 `anolisa adapter status` 查看状态、`anolisa adapter disable` 卸载。

#### 手动复制（fallback）

如果 `anolisa` CLI 不可用，可手动复制技能文件：

```bash
mkdir -p ~/.openclaw/skills && cp -r /usr/share/anolisa/skills/* ~/.openclaw/skills/
mkdir -p ~/.hermes/skills && cp -r /usr/share/anolisa/skills/* ~/.hermes/skills/
```

> 手动复制不会写入 ANOLISA receipt，`anolisa adapter status/disable` 不会接管这些技能。如果 OpenClaw 或 Hermes 未安装在默认目录，请替换为实际路径。

---

## 二、技能分类总览

OS Skills 按领域划分为七个分类：

| 分类                 | 目录              | 说明                                                                 |
| -------------------- | ----------------- | -------------------------------------------------------------------- |
| **AI 工具**    | `ai/`           | AI 编程工具安装与配置（Claude Code、OpenClaw、Hermes、QwenPaw、MCP） |
| **系统管理**   | `system-admin/` | systemd 服务、存储扩容、网络、内核升级、Shell 脚本                   |
| **开发运维**   | `devops/`       | GitHub 工作流、内核开发、系统诊断                                    |
| **阿里云**     | `aliyun/`       | ECS 实例生命周期管理                                                 |
| **安全**       | `security/`     | CVE 漏洞查询、合规检查                                               |
| **监控与性能** | `monitor-perf/` | sysAK 诊断、keentune 调优                                            |
| **其他**       | `others/`       | 文档处理、技能市场、产品指南等扩展功能                               |

---

## 三、技能清单与使用示例

| 分类     | 技能                                                                                | 说明                                           |
| -------- | ----------------------------------------------------------------------------------- | ---------------------------------------------- |
| AI 工具  | [install-claude-code](#install-claude-code--安装-claude-code-cli)                      | 安装 Claude Code CLI，支持 DashScope/Qwen 后端 |
| AI 工具  | [install-openclaw](#install-openclaw--安装-openclaw)                                   | 非交互式安装 OpenClaw 并配置百炼模型           |
| AI 工具  | [install-hermes](#install-hermes--安装-hermes-agent)                                   | 部署 Hermes Agent 并配置 LLM Provider          |
| AI 工具  | [install-qwenpaw / qwenpaw-usage](#install-qwenpaw--qwenpaw-usage--qwenpaw-部署与使用) | QwenPaw AI 助手部署与使用指南                  |
| AI 工具  | [setup-mcp](#setup-mcp--配置-mcp-服务器)                                               | 在 Copilot Shell 中配置 MCP 服务器             |
| 系统管理 | [alinux-admin](#alinux-admin--alinux-4-系统管理)                                       | systemd、SSH、firewalld、网络配置              |
| 系统管理 | [shell-scripting](#shell-scripting--shell-脚本编写)                                    | Bash/Zsh 脚本编写与 CLI 自动化                 |
| 系统管理 | [storage-resize](#storage-resize--云磁盘扩容)                                          | 阿里云磁盘在线扩容（XFS/EXT4/Btrfs）           |
| 系统管理 | [backup-restore](#backup-restore--系统备份与恢复)                                      | OS 级和用户级备份恢复                          |
| 系统管理 | [regex-mastery](#regex-mastery--正则表达式指南)                                        | 正则表达式速查参考                             |
| 系统管理 | [upgrade-alinux-kernel](#upgrade-alinux-kernel--alinux-内核升级)                       | ALinux 4 内核升级                              |
| 开发运维 | [github](#github--github-工作流)                                                       | GitHub CLI 操作与 CI/CD 集成                   |
| 开发运维 | [kernel-dev](#kernel-dev--alinux-内核开发)                                             | ALinux 内核编译与模块开发                      |
| 开发运维 | [sysom-agentsight](#sysom-agentsight--ai-agent-可观测)                                 | AI Agent token 消耗与会话监控                  |
| 开发运维 | [sysom-diagnosis](#sysom-diagnosis--系统深度诊断)                                      | 内存/网络/IO/负载深度诊断                      |
| 阿里云   | [aliyun-ecs](#aliyun-ecs--ecs-实例管理)                                                | ECS 实例生命周期管理                           |
| 安全     | [alinux-cve-query](#alinux-cve-query--cve-漏洞查询)                                    | CVE 漏洞查询与修复状态                         |
| 其他     | [clawhub-skill-mng](#clawhub-skill-mng--技能市场管理)                                  | 技能搜索、安装与管理                           |
| 其他     | [humanizer](#humanizer--ai-文本去痕)                                                   | 去除 AI 写作痕迹                               |
| 其他     | [xlsx](#xlsx--excel-文件处理)                                                          | Excel 文件创建、读取、编辑                     |
| 其他     | [pdf-reader](#pdf-reader--pdf-文件读取)                                                | PDF 文件内容提取                               |
| 其他     | [image-gen](#image-gen--图片生成)                                                      | AI 图片生成                                    |
| 其他     | [anolisa-guide](#anolisa-guide--anolisa-产品指南)                                      | ANOLISA 各组件使用指南                         |
| 其他     | [anolisa-register](#anolisa-register--agentic-os-注册管理)                             | Agentic OS 注册与订阅管理                      |
| 其他     | [cosh-guide](#cosh-guide--copilot-shell-使用指南)                                      | Copilot Shell 命令与配置参考                   |

---

### 3.1 AI 工具（`ai/`）

#### install-claude-code — 安装 Claude Code CLI

在 RPM 系 Linux 上安装 Claude Code，支持 DashScope/Qwen API 后端。

**使用示例**：

```
帮我在当前机器上安装 Claude Code CLI，使用 DashScope API 作为后端，
API Key 是 sk-xxx，模型用 qwen-max。
```

Agent 将输出安装方法（npm 或 curl installer）和 `settings.json` 中的 DashScope API 配置。

#### install-openclaw — 安装 OpenClaw

非交互式安装 OpenClaw 并配置阿里云百炼模型。

#### install-hermes — 安装 Hermes Agent

部署 Hermes Agent 并配置 LLM Provider。

**使用示例**：

```
帮我安装 Hermes Agent，并配置阿里云百炼 Qwen 作为 LLM Provider。
```

#### install-qwenpaw / qwenpaw-usage — QwenPaw 部署与使用

部署 QwenPaw AI 助手（支持钉钉集成），以及使用指南。

#### setup-mcp — 配置 MCP 服务器

在 Copilot Shell 中配置 Model Context Protocol 服务器。

**使用示例**：

```
帮我配置一个 filesystem MCP 服务器到 cosh 中，
命令是 npx -y @anthropic/mcp-filesystem，参数是 /home 目录。
```

Agent 将生成 `mcpServers` 配置的 JSON 结构并写入对应的 `settings.json`。

---

### 3.2 系统管理（`system-admin/`）

#### alinux-admin — ALinux 4 系统管理

涵盖 systemd 服务管理、SSH 配置、firewalld 防火墙、NetworkManager 网络配置。

**使用示例**：

```
帮我写一个 systemd service unit 文件，用来管理一个运行在 8080 端口的
Node.js Web 应用，要求失败后自动重启，最多重启 3 次。
```

Agent 将生成包含 `[Unit]`、`[Service]`、`[Install]` 三个 section 的完整 unit 文件，含 `Restart=` 和 `StartLimitBurst=` 等配置项。

#### shell-scripting — Shell 脚本编写

Bash/Zsh 脚本编写、参数解析、错误处理、CLI 自动化。

**使用示例**：

```
帮我写一个 Bash 脚本，支持 --input、--output 和 --verbose 三个参数，
功能是将 input 文件复制到 output 路径，verbose 模式下打印详细信息。
```

Agent 将生成带 `getopts` 或 `case` 参数解析、错误处理和 `usage` 帮助的完整脚本。

#### storage-resize — 云磁盘扩容

阿里云磁盘在线扩容，支持 XFS/EXT4/Btrfs 文件系统。依赖 `aliyun-ecs` 技能。

#### backup-restore — 系统备份与恢复

OS 级和用户级备份恢复方案，含阿里云快照集成。

#### regex-mastery — 正则表达式指南

正则表达式速查参考，覆盖 POSIX ERE/BRE、PCRE 等方言。

#### upgrade-alinux-kernel — ALinux 内核升级

ALinux 4 内核升级流程与注意事项。

---

### 3.3 开发运维（`devops/`）

#### github — GitHub 工作流

GitHub CLI（`gh`）操作、PR 管理、CI/CD 集成。

**使用示例**：

```
如何使用 gh CLI 查看某个 PR 的 CI 检查状态和失败日志？
```

Agent 将输出 `gh pr checks`、`gh run view --log-failed` 等具体命令。

#### kernel-dev — ALinux 内核开发

ALinux 4 内核编译自动化（SRPM 与 Upstream 方式）、内核模块开发。

#### sysom-agentsight — AI Agent 可观测

查看 AI Agent 的 token 消耗、会话中断事件等运行指标。

**使用示例**：

```
帮我查看今天的 AI Agent token 消耗情况，以及是否有会话中断事件。
```

Agent 将调用 `agentsight` 命令查询 token 使用量和会话事件。

#### sysom-diagnosis — 系统深度诊断

通过 `osops` CLI 进行内存/OOM、网络、IO、负载等深度诊断与调优。

**使用示例**：

```
当前系统内存使用率很高，帮我诊断一下内存占用情况。
```

Agent 将使用 `memgraph`、`free`、`top`、`ps` 等命令或 SysOM 诊断工具定位高内存占用的进程。

---

### 3.4 阿里云（`aliyun/`）

#### aliyun-ecs — ECS 实例管理

通过阿里云 CLI 管理 ECS 实例生命周期（创建、查询、启停、释放）。

**使用示例**：

```
帮我用阿里云 CLI 查看当前区域所有运行中的 ECS 实例列表，
并显示实例ID、名称和公网IP。
```

Agent 将输出 `aliyun ecs DescribeInstances` 命令及 `--RegionId`、`Status=Running` 等查询参数。

---

### 3.5 安全（`security/`）

#### alinux-cve-query — CVE 漏洞查询

查询 Alibaba Cloud Linux 的 CVE 漏洞信息（ALAS 公告）及修复状态。

**使用示例**：

```
帮我查询 CVE-2024-6387 是否影响当前系统，以及是否已经修复。
```

Agent 将通过 ALAS API 或本地包管理器查询该 CVE 影响的软件包（如 openssh）及修复状态。

---

### 3.6 其他（`others/`）

#### clawhub-skill-mng — 技能市场管理

通过 `clawhub` CLI 搜索、安装、卸载、更新技能。

**使用示例**：

```
帮我在 clawhub 中搜索与 Docker 相关的 skill，并告诉我如何安装。
```

Agent 将输出 `clawhub search` 和 `clawhub install --dir ... --registry ...` 命令。

#### humanizer — AI 文本去痕

去除 AI 生成文本中的典型写作模式（如 Additionally、Furthermore、delve 等），使文本读起来更自然。

**使用示例**：

```
请帮我改写以下文本，去除 AI 写作痕迹，使其读起来更自然像人写的：
"Additionally, it is crucial to delve into the broader implications..."
```

Agent 将改写文本，消除典型 AI 用词模式。

#### xlsx — Excel 文件处理

创建、读取、编辑、验证 Excel 文件（`.xlsx`），支持公式、格式化、数据分析。

**使用示例**：

```
帮我创建一个 Excel 文件 /tmp/budget.xlsx，包含"月度预算"表格，
有"项目"、"金额"、"备注"三列，填入 3 行示例数据，最后一行是金额合计公式。
```

Agent 将通过内置脚本或 XML 模板生成含 `SUM` 公式的 xlsx 文件。

#### pdf-reader — PDF 文件读取

读取和提取 PDF 文件内容，基于 PyMuPDF。

**使用示例**：

```
帮我读取 /tmp/report.pdf 的内容。
```

Agent 将调用 `read_pdf.py` 脚本提取 PDF 文本内容。

#### image-gen — 图片生成

通过 AI 模型生成图片。

#### anolisa-guide — Anolisa 产品指南

ANOLISA 各组件（Copilot Shell、ws-ckpt、AgentSecCore 等）的使用指南，含自动文档抓取与缓存。

#### anolisa-register — Agentic OS 注册管理

管理 Agentic OS 的注册与订阅状态。

#### cosh-guide — Copilot Shell 使用指南

Copilot Shell 的命令、配置和功能参考。

---

## 四、技能格式说明

每个技能由独立目录组织，至少包含一个 `SKILL.md` 文件：

```
skill-name/
├── SKILL.md              # 必需：技能定义（YAML 前置元数据 + Markdown 正文）
├── scripts/              # 可选：可执行脚本（.sh、.py）
├── reference/            # 可选：参考文档和配置模板
├── templates/            # 可选：文件模板
└── docs/                 # 可选：详细文档
```

### 4.1 SKILL.md 结构

```yaml
---
name: my-skill                    # 必填：技能唯一标识
version: 1.0.0                    # 必填：语义化版本号
description: 技能用途说明           # 必填：自然语言描述，用于意图匹配
tags: [example_1, example_2]      # 可选：分类标签，自定义
platforms: [cosh, claude-code]    # 可选：支持的 Agent 运行时
dependencies: [other-skill]       # 可选：依赖的其他技能
allowed-tools: [Bash, Read]       # 可选：允许使用的工具列表，不写表示不做工具限制。
---

# 技能标题

Markdown 正文，包含使用说明、前置条件和操作步骤。
```

### 4.2 关键字段说明

| 字段              | 必填 | 说明                                                           |
| ----------------- | ---- | -------------------------------------------------------------- |
| `name`          | 是   | 技能唯一标识，全局不可重复                                     |
| `description`   | 是   | Agent 用于意图匹配的自然语言描述，应涵盖触发关键词             |
| `version`       | 否   | 语义化版本号                                                   |
| `platforms`     | 否   | 支持的运行时列表，如 `cosh`、`claude-code`、`gemini-cli` |
| `dependencies`  | 否   | 前置依赖的技能名称列表                                         |
| `allowed-tools` | 否   | 显式声明该技能允许调用的工具                                   |

## 五、常见问题

### 技能没有被 Agent 识别？

1. 确认技能目录位于正确的搜索路径下
2. 确认目录中存在 `SKILL.md` 文件
3. 检查 `SKILL.md` 的 YAML 前置元数据格式是否正确
4. 重启 Agent 运行时（Copilot Shell 可执行 `/extensions reload`）

### 技能之间有依赖关系怎么办？

技能的 `dependencies` 字段声明了前置依赖。例如 `storage-resize` 依赖 `aliyun-ecs`，需确保两个技能都已安装。安装全部技能时依赖自动满足。
